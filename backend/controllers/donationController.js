const Donation = require("../models/Donation");
const User = require("../models/User");
const LogisticsTask = require("../models/LogisticsTask");
const geminiService = require("../services/geminiService");
const matchingService = require("../services/matchingService");
const routeOptimizationService = require("../services/routeOptimizationService");
const notificationService = require("../services/notificationService");
const cloudinary = require("../config/cloudinary");

// Helper function to calculate handling window
function calculateHandlingWindow(freshnessScore, urgency) {
  const now = new Date();
  let hours = 4 + freshnessScore * 20;

  // Adjust based on urgency
  if (urgency === "critical") hours *= 0.7; // Shorter window for critical items
  if (urgency === "high") hours *= 0.85;

  return {
    start: now,
    end: new Date(now.getTime() + hours * 60 * 60 * 1000),
  };
}

// Helper function to initiate matching
async function initiateMatching(donationId) {
  try {
    const matches = await matchingService.findBestMatches(donationId);
    const donation = await Donation.findById(donationId);

    if (matches && matches.length > 0) {
      donation.matchedRecipients = matches.map((match) => ({
        recipient: match.recipient._id,
        matchScore: match.totalScore,
        status: "offered",
      }));

      await donation.save();

      // Send notifications to matched recipients
      for (const match of matches) {
        await notificationService.sendDonationOffer(
          match.recipient._id,
          donationId,
          match.totalScore
        );
      }
    } else {
      console.log("No suitable matches found for donation:", donationId);
    }
  } catch (error) {
    console.error("Matching process error:", error);
    // Don't fail the donation creation if matching fails
  }
}

// Helper function to assign volunteer to task
async function assignVolunteerToTask(taskId) {
  try {
    const task = await LogisticsTask.findById(taskId).populate("donation");
    const availableVolunteers = await User.find({
      role: "volunteer",
      "volunteerDetails.isAvailable": true,
    });

    if (availableVolunteers.length === 0) {
      console.log("No available volunteers");
      // Schedule retry or notify admin
      return;
    }

    // Use enhanced GA for volunteer assignment with urgency consideration
    const assignedVolunteer =
      await routeOptimizationService.findOptimalVolunteer(
        task.pickupLocation,
        availableVolunteers,
        task.urgency
      );

    if (assignedVolunteer) {
      task.volunteer = assignedVolunteer._id;
      task.status = "assigned";
      await task.save();

      await Donation.findByIdAndUpdate(task.donation._id, {
        assignedVolunteer: assignedVolunteer._id,
      });

      await notificationService.sendTaskAssignment(
        assignedVolunteer._id,
        taskId
      );
    } else {
      console.log("No suitable volunteer found for task:", taskId);
    }
  } catch (error) {
    console.error("Volunteer assignment error:", error);
  }
}

// Controller functions
exports.createDonation = async (req, res) => {
  try {
    console.log("Creating donation for user:", req.user.id);

    const {
      type,
      images,
      description,
      quantity,
      scheduledPickup,
      pickupAddress,
      location,
      expectedQuantity,
      categories = [],
      tags = [],
      urgency = "normal",
    } = req.body;

    // Validate required fields
    if (!type || !pickupAddress || !location) {
      return res.status(400).json({
        success: false,
        message: "Missing required fields: type, pickupAddress, location",
      });
    }

    if (type === "bulk" && !scheduledPickup) {
      return res.status(400).json({
        success: false,
        message: "Scheduled pickup is required for bulk donations",
      });
    }

    const donation = new Donation({
      donor: req.user.id,
      type,
      images: images || [],
      description: description || "",
      quantity: quantity || { amount: 0, unit: "units" },
      expectedQuantity: type === "bulk" ? expectedQuantity : undefined,
      scheduledPickup: type === "bulk" ? scheduledPickup : undefined,
      pickupAddress,
      location,
      categories: categories || [],
      tags: tags || [],
      urgency,
      status: "active",
    });

    await donation.save();
    console.log("Donation created with ID:", donation._id);

    // Process with AI if images provided
    if (images && images.length > 0) {
      try {
        console.log("Processing images with AI...");
        const aiAnalysis = await geminiService.analyzeFoodImages(images);

        donation.aiDescription = aiAnalysis.description;
        donation.categories = [
          ...new Set([
            ...(donation.categories || []),
            ...(aiAnalysis.categories || []),
          ]),
        ];
        donation.tags = [
          ...new Set([
            ...(donation.tags || []),
            ...(aiAnalysis.allergens || []),
            ...(aiAnalysis.dietaryInfo || []),
          ]),
        ];
        donation.aiAnalysis = aiAnalysis;

        const handlingWindow = calculateHandlingWindow(
          aiAnalysis.freshnessScore,
          urgency
        );
        donation.handlingWindow = handlingWindow;

        await donation.save();
        console.log("AI processing completed for donation:", donation._id);
      } catch (aiError) {
        console.error("AI processing failed:", aiError);
        // Continue with manual description if AI fails
      }
    }

    // Start matching process immediately with enhanced error handling
    await initiateMatching(donation._id);

    const populatedDonation = await Donation.findById(donation._id)
      .populate("donor", "name email")
      .populate("matchedRecipients.recipient", "name recipientDetails");

    res.status(201).json({
      success: true,
      data: populatedDonation,
      message:
        "Donation created successfully" +
        (images && images.length > 0 ? " - AI processing completed" : ""),
    });
  } catch (error) {
    console.error("Donation creation error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to create donation: " + error.message,
    });
  }
};

exports.acceptDonation = async (req, res) => {
  try {
    const { donationId } = req.params;
    console.log("Accepting donation:", donationId, "by user:", req.user.id);

    const donation = await Donation.findById(donationId);
    if (!donation) {
      return res.status(404).json({
        success: false,
        message: "Donation not found",
      });
    }

    const recipientMatch = donation.matchedRecipients.find(
      (match) => match.recipient.toString() === req.user.id
    );

    if (!recipientMatch) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to accept this donation",
      });
    }

    donation.acceptedBy = req.user.id;
    donation.status = "matched";
    recipientMatch.status = "accepted";
    recipientMatch.respondedAt = new Date();

    await donation.save();

    // Create logistics task with urgency consideration
    const donor = await User.findById(donation.donor);
    const recipient = await User.findById(req.user.id);

    const task = new LogisticsTask({
      donation: donationId,
      pickupLocation: {
        address: donation.pickupAddress,
        lat: donation.location.lat,
        lng: donation.location.lng,
      },
      dropoffLocation: {
        address:
          recipient.recipientDetails?.address ||
          recipient.contactInfo?.address ||
          donation.pickupAddress,
        lat: recipient.recipientDetails?.location?.lat || donation.location.lat,
        lng: recipient.recipientDetails?.location?.lng || donation.location.lng,
      },
      scheduledPickupTime:
        donation.type === "bulk"
          ? donation.scheduledPickup
          : new Date(Date.now() + 2 * 60 * 60 * 1000),
      status: "pending",
      urgency: donation.urgency || "normal",
    });

    await task.save();
    console.log("Logistics task created:", task._id);

    // Assign volunteer using enhanced GA
    await assignVolunteerToTask(task._id);

    const populatedDonation = await Donation.findById(donationId)
      .populate("acceptedBy", "name recipientDetails")
      .populate("assignedVolunteer", "name");

    res.json({
      success: true,
      data: { donation: populatedDonation, task },
      message: "Donation accepted successfully",
    });
  } catch (error) {
    console.error("Donation acceptance error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getAvailableDonations = async (req, res) => {
  try {
    const { page = 1, limit = 10, categories, distance } = req.query;
    console.log("Fetching available donations for user:", req.user.id);

    let query = {
      status: "active",
      "matchedRecipients.recipient": req.user.id,
    };

    if (categories) {
      query.categories = { $in: categories.split(",") };
    }

    const donations = await Donation.find(query)
      .populate("donor", "name contactInfo donorDetails")
      .sort({ createdAt: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit);

    const total = await Donation.countDocuments(query);

    res.json({
      success: true,
      data: {
        donations,
        totalPages: Math.ceil(total / limit),
        currentPage: page,
        total,
      },
    });
  } catch (error) {
    console.error("Get available donations error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.uploadImages = async (req, res) => {
  try {
    console.log("Uploading images...");

    if (!req.files || req.files.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No images provided",
      });
    }

    const uploadPromises = req.files.map((file) => {
      return new Promise((resolve, reject) => {
        cloudinary.uploader
          .upload_stream(
            {
              resource_type: "image",
              folder: "zero_hunger/donations",
            },
            (error, result) => {
              if (error) reject(error);
              else resolve(result.secure_url);
            }
          )
          .end(file.buffer);
      });
    });

    const imageUrls = await Promise.all(uploadPromises);
    console.log("Images uploaded successfully:", imageUrls.length);

    res.json({
      success: true,
      data: {
        images: imageUrls,
      },
    });
  } catch (error) {
    console.error("Image upload error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getDonorDashboard = async (req, res) => {
  try {
    console.log("Fetching donor dashboard for user:", req.user.id);

    const donations = await Donation.find({ donor: req.user.id })
      .populate("acceptedBy", "name recipientDetails.organizationName")
      .populate("assignedVolunteer", "name")
      .populate("matchedRecipients.recipient", "name recipientDetails")
      .sort({ createdAt: -1 });

    const stats = {
      total: donations.length,
      active: donations.filter((d) =>
        ["active", "matched", "scheduled"].includes(d.status)
      ).length,
      completed: donations.filter((d) => d.status === "delivered").length,
      pending: donations.filter((d) =>
        ["pending", "ai_processing"].includes(d.status)
      ).length,
    };

    res.json({
      success: true,
      data: { donations, stats },
    });
  } catch (error) {
    console.error("Donor dashboard error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getDonationDetails = async (req, res) => {
  try {
    const { donationId } = req.params;
    console.log("Fetching donation details:", donationId);

    const donation = await Donation.findById(donationId)
      .populate("donor", "name contactInfo donorDetails")
      .populate("acceptedBy", "name recipientDetails")
      .populate("assignedVolunteer", "name volunteerDetails")
      .populate("matchedRecipients.recipient", "name recipientDetails");

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: "Donation not found",
      });
    }

    if (
      donation.donor._id.toString() !== req.user.id &&
      donation.acceptedBy?._id.toString() !== req.user.id &&
      !donation.matchedRecipients.some(
        (match) => match.recipient._id.toString() === req.user.id
      )
    ) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to view this donation",
      });
    }

    res.json({
      success: true,
      data: donation,
    });
  } catch (error) {
    console.error("Get donation details error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// New controller functions for the additional routes
exports.updateDonationStatus = async (req, res) => {
  try {
    const { donationId } = req.params;
    const { status } = req.body;
    console.log("Updating donation status:", donationId, "to:", status);

    const donation = await Donation.findById(donationId);

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: "Donation not found",
      });
    }

    // Check ownership
    if (donation.donor.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to update this donation",
      });
    }

    donation.status = status;
    await donation.save();

    res.json({
      success: true,
      message: "Donation status updated successfully",
      data: donation,
    });
  } catch (error) {
    console.error("Update donation status error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getDonationStats = async (req, res) => {
  try {
    const userId = req.user.id;
    console.log("Fetching donation stats for user:", userId);

    const stats = await Donation.aggregate([
      {
        $match: {
          donor: mongoose.Types.ObjectId.createFromHexString(userId),
        },
      },
      {
        $group: {
          _id: null,
          totalDonations: { $sum: 1 },
          totalQuantity: { $sum: "$quantity.amount" },
          activeDonations: {
            $sum: {
              $cond: [
                { $in: ["$status", ["active", "matched", "scheduled"]] },
                1,
                0,
              ],
            },
          },
          completedDonations: {
            $sum: { $cond: [{ $eq: ["$status", "delivered"] }, 1, 0] },
          },
          totalImpact: {
            $sum: {
              $cond: [{ $eq: ["$status", "delivered"] }, "$quantity.amount", 0],
            },
          },
        },
      },
    ]);

    const result = stats[0] || {
      totalDonations: 0,
      totalQuantity: 0,
      activeDonations: 0,
      completedDonations: 0,
      totalImpact: 0,
    };

    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error("Get donation stats error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.searchAvailableDonations = async (req, res) => {
  try {
    const { query, categories, maxDistance = 50 } = req.query;
    console.log("Searching donations for user:", req.user.id, "query:", query);

    const recipient = await User.findById(req.user.id);
    const recipientLocation =
      recipient.recipientDetails?.location || recipient.contactInfo?.location;

    let searchCriteria = {
      status: "active",
      "matchedRecipients.recipient": req.user.id,
    };

    // Text search
    if (query) {
      searchCriteria.$or = [
        { description: { $regex: query, $options: "i" } },
        { aiDescription: { $regex: query, $options: "i" } },
        { categories: { $in: [new RegExp(query, "i")] } },
        { tags: { $in: [new RegExp(query, "i")] } },
      ];
    }

    // Category filter
    if (categories) {
      searchCriteria.categories = { $in: categories.split(",") };
    }

    // Location-based filtering (simplified)
    if (recipientLocation && maxDistance) {
      // This is a simplified approach - in production, use geospatial queries
      searchCriteria["location.lat"] = {
        $gte: recipientLocation.lat - maxDistance / 111,
        $lte: recipientLocation.lat + maxDistance / 111,
      };
      searchCriteria["location.lng"] = {
        $gte:
          recipientLocation.lng -
          maxDistance /
            (111 * Math.cos((recipientLocation.lat * Math.PI) / 180)),
        $lte:
          recipientLocation.lng +
          maxDistance /
            (111 * Math.cos((recipientLocation.lat * Math.PI) / 180)),
      };
    }

    const donations = await Donation.find(searchCriteria)
      .populate("donor", "name contactInfo donorDetails")
      .sort({ createdAt: -1 })
      .limit(50);

    res.json({
      success: true,
      data: donations,
    });
  } catch (error) {
    console.error("Search donations error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.analyzeFoodImages = async (req, res) => {
  try {
    const { images } = req.body;

    if (!images || images.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No images provided for analysis",
      });
    }

    console.log("Analyzing food images with AI...");

    // Call Gemini AI service for analysis
    const aiAnalysis = await geminiService.analyzeFoodImages(images);

    res.json({
      success: true,
      data: aiAnalysis,
      message: "AI analysis completed successfully",
    });
  } catch (error) {
    console.error("Image analysis error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to analyze images: " + error.message,
    });
  }
};
