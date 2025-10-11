const Donation = require("../models/Donation");
const User = require("../models/User");
const LogisticsTask = require("../models/LogisticsTask");
const geminiService = require("../services/geminiService");
const matchingService = require("../services/matchingService");
const routeOptimizationService = require("../services/routeOptimizationService");
const notificationService = require("../services/notificationService");
const cloudinary = require("../config/cloudinary");
const mongoose = require("mongoose");

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
    console.log(`🔄 Starting matching process for donation: ${donationId}`);

    const donation = await Donation.findById(donationId);
    if (!donation) {
      console.error(`❌ Donation not found: ${donationId}`);
      return;
    }

    // Update donation status to indicate matching started
    donation.matchingStartedAt = new Date();
    await donation.save();

    // Use the instance method to find and store matches
    await donation.findAndStoreMatches();

    console.log(`✅ Matching process completed for donation: ${donationId}`);
  } catch (error) {
    console.error(
      `💥 Matching process error for donation ${donationId}:`,
      error
    );
    // Don't fail the donation creation if matching fails
  }
}


// ENHANCED volunteer assignment with proper error handling
async function assignVolunteerToTask(taskId) {
  try {
    console.log(`🔍 Assigning volunteer to task: ${taskId}`);
    
    const task = await LogisticsTask.findById(taskId).populate("donation");
    if (!task) {
      console.error(`❌ Task not found: ${taskId}`);
      return;
    }

    // Get ACTIVE volunteers with proper filtering
    const availableVolunteers = await User.find({
      role: "volunteer",
      "volunteerDetails.isAvailable": true,
      status: "active",
    }).select("name email volunteerDetails contactInfo");

    console.log(`👥 Found ${availableVolunteers.length} available volunteers`);

    if (availableVolunteers.length === 0) {
      console.log("⛔ No available volunteers found");
      
      // Schedule retry in 5 minutes
      setTimeout(() => {
        console.log(`🔄 Retrying volunteer assignment for task: ${taskId}`);
        assignVolunteerToTask(taskId);
      }, 5 * 60 * 1000);
      
      return;
    }

    // Use simplified assignment logic
    const assignedVolunteer = await routeOptimizationService.findOptimalVolunteer(
      task.pickupLocation,
      availableVolunteers,
      task.urgency
    );

    if (assignedVolunteer) {
      // DOUBLE CHECK capacity
      const canAccept = await assignedVolunteer.canAcceptTask();
      if (!canAccept) {
        console.log(`⛔ Volunteer ${assignedVolunteer._id} cannot accept more tasks`);
        
        // Try next best volunteer recursively
        await retryWithNextVolunteer(taskId, availableVolunteers, assignedVolunteer._id);
        return;
      }

      // UPDATE task with volunteer assignment
      task.volunteer = assignedVolunteer._id;
      task.status = "assigned";
      await task.save();

      // UPDATE donation with volunteer assignment
      await Donation.findByIdAndUpdate(task.donation._id, {
        assignedVolunteer: assignedVolunteer._id,
        status: "scheduled"
      });

      // SEND notification
      await notificationService.sendTaskAssignment(
        assignedVolunteer._id,
        taskId
      );

      console.log(`✅ Volunteer ${assignedVolunteer._id} assigned to task: ${taskId}`);
    } else {
      console.log("⛔ No suitable volunteer found for task:", taskId);
      
      // Schedule retry
      setTimeout(() => {
        console.log(`🔄 Retrying volunteer assignment for task: ${taskId}`);
        assignVolunteerToTask(taskId);
      }, 10 * 60 * 1000); // Retry in 10 minutes
    }
  } catch (error) {
    console.error("💥 Volunteer assignment error:", error);
    
    // Emergency fallback - assign to any available volunteer
    await emergencyVolunteerAssignment(taskId);
  }
}

// NEW: Retry with next best volunteer
async function retryWithNextVolunteer(taskId, availableVolunteers, excludedVolunteerId) {
  try {
    const remainingVolunteers = availableVolunteers.filter(
      v => v._id.toString() !== excludedVolunteerId.toString()
    );

    if (remainingVolunteers.length === 0) {
      console.log("⛔ No alternative volunteers available");
      return;
    }

    const task = await LogisticsTask.findById(taskId);
    const nextVolunteer = await routeOptimizationService.findOptimalVolunteer(
      task.pickupLocation,
      remainingVolunteers,
      task.urgency
    );

    if (nextVolunteer) {
      const canAccept = await nextVolunteer.canAcceptTask();
      if (canAccept) {
        task.volunteer = nextVolunteer._id;
        task.status = "assigned";
        await task.save();

        await Donation.findByIdAndUpdate(task.donation._id, {
          assignedVolunteer: nextVolunteer._id,
          status: "scheduled"
        });

        await notificationService.sendTaskAssignment(nextVolunteer._id, taskId);
        console.log(`✅ Alternative volunteer ${nextVolunteer._id} assigned to task: ${taskId}`);
      }
    }
  } catch (error) {
    console.error("Retry volunteer assignment error:", error);
  }
}

// NEW: Emergency fallback assignment
async function emergencyVolunteerAssignment(taskId) {
  try {
    console.log(`🚨 Emergency volunteer assignment for task: ${taskId}`);
    
    const task = await LogisticsTask.findById(taskId);
    const emergencyVolunteers = await User.find({
      role: "volunteer",
      status: "active",
    })
    .select("name email volunteerDetails")
    .limit(5); // Limit to prevent overloading

    for (const volunteer of emergencyVolunteers) {
      try {
        const canAccept = await volunteer.canAcceptTask();
        if (canAccept) {
          task.volunteer = volunteer._id;
          task.status = "assigned";
          await task.save();

          await Donation.findByIdAndUpdate(task.donation._id, {
            assignedVolunteer: volunteer._id,
            status: "scheduled"
          });

          await notificationService.sendTaskAssignment(volunteer._id, taskId);
          console.log(`🚨 EMERGENCY: Volunteer ${volunteer._id} assigned to task: ${taskId}`);
          return;
        }
      } catch (volunteerError) {
        console.error(`Emergency assignment error for volunteer ${volunteer._id}:`, volunteerError);
        continue;
      }
    }

    console.log("🚨 CRITICAL: No emergency volunteers available");
  } catch (error) {
    console.error("💥 CRITICAL: Emergency assignment failed:", error);
  }
}

exports.createDonation = async (req, res) => {
  try {
    console.log("🔄 Creating donation for user:", req.user.id);

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

    // Validate quantity
    if (!quantity || !quantity.amount || quantity.amount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Valid quantity amount is required",
      });
    }

    const donation = new Donation({
      donor: req.user.id,
      type,
      images: images || [],
      description: description || "",
      quantity: {
        amount: quantity.amount,
        unit: quantity.unit || "units",
      },
      expectedQuantity: type === "bulk" ? expectedQuantity : undefined,
      scheduledPickup: type === "bulk" ? scheduledPickup : undefined,
      pickupAddress,
      location: {
        lat: location.lat,
        lng: location.lng,
        geocoded: location.geocoded || false,
      },
      categories: categories || [],
      tags: tags || [],
      urgency,
      status: "pending", // Start as pending, will be updated after AI processing
    });

    await donation.save();
    console.log("✅ Donation created with ID:", donation._id);

    // Process with AI if images provided
    if (images && images.length > 0) {
      try {
        console.log("🔍 Processing images with AI...");
        donation.status = "ai_processing";
        await donation.save();

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

        donation.status = "active"; // Activate donation after AI processing
        await donation.save();
        console.log("✅ AI processing completed for donation:", donation._id);
      } catch (aiError) {
        console.error("❌ AI processing failed:", aiError);
        // Continue with manual description if AI fails
        donation.status = "active";
        await donation.save();
      }
    } else {
      // No images, activate immediately
      donation.status = "active";
      await donation.save();
    }

    // Start matching process asynchronously
    initiateMatching(donation._id).catch((error) => {
      console.error(`💥 Matching failed for donation ${donation._id}:`, error);
    });

    const populatedDonation = await Donation.findById(donation._id)
      .populate("donor", "name email contactInfo donorDetails")
      .populate("matchedRecipients.recipient", "name recipientDetails");

    res.status(201).json({
      success: true,
      data: populatedDonation,
      message:
        "Donation created successfully" +
        (images && images.length > 0 ? " - AI processing completed" : "") +
        " - Matching process started",
    });
  } catch (error) {
    console.error("💥 Donation creation error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to create donation: " + error.message,
    });
  }
};

exports.acceptDonationOffer = async (req, res) => {
  try {
    const { donationId } = req.params;
    console.log(`✅ ${req.user.role} ${req.user.id} accepting donation: ${donationId} in donationController`);

    const donation = await Donation.findById(donationId);
    console.log("🔍 Donation fetched:", donation ? donation._id : "Not found");
    if (!donation) {
      return res.status(404).json({
        success: false,
        message: "Donation not found",
      });
    }

    // DEBUG: Log donation details
    console.log("🔍 Donation details:", {
      donationId: donation._id,
      status: donation.status,
      matchedRecipients: donation.matchedRecipients?.map((match) => ({
        recipient: match.recipient?.toString(),
        status: match.status,
      })),
      currentUser: req.user.id,
    });

    // Check if donation is available for acceptance
    if (donation.status !== 'active') {
      return res.status(400).json({
        success: false,
        message: `Donation is not available for acceptance. Current status: ${donation.status}`,
      });
    }

    // Check if recipient can accept more donations
    const recipient = await User.findById(req.user.id);
    const canAccept = await recipient.canAcceptDonation(donation.quantity.amount);

    if (!canAccept) {
      return res.status(400).json({
        success: false,
        message: "You have reached your capacity limit. Cannot accept more donations at this time.",
      });
    }

    // Check if this donation is already offered to the recipient
    const existingMatch = donation.matchedRecipients?.find(
      (match) => match.recipient?.toString() === req.user.id
    );

    let recipientMatch;

    if (existingMatch) {
      // If already in matchedRecipients, update the status
      recipientMatch = existingMatch;
      
      if (recipientMatch.status === 'offered') {
        recipientMatch.status = 'accepted';
        recipientMatch.respondedAt = new Date();
        console.log(`🔄 Updated existing match to accepted for donation: ${donationId}`);
      } else {
        console.log(`ℹ️ Recipient already has match with status: ${recipientMatch.status}`);
      }
    } else {
      // If not in matchedRecipients, create a new match entry
      recipientMatch = {
        recipient: req.user.id,
        matchScore: 0.7, // Good score for manual acceptance
        status: "accepted",
        respondedAt: new Date(),
        matchingMethod: "manual_acceptance",
        matchReasons: ["Manually accepted by recipient"],
        createdAt: new Date()
      };
      
      donation.matchedRecipients.push(recipientMatch);
      console.log(`🆕 Created new match entry for manual acceptance`);
    }

    // Update donation status and acceptedBy
    donation.acceptedBy = req.user.id;
    donation.status = "matched";
    donation.updatedAt = new Date();

    // Decline other pending offers for this donation
    if (donation.matchedRecipients && donation.matchedRecipients.length > 0) {
      donation.matchedRecipients.forEach((match) => {
        if (
          match.recipient?.toString() !== req.user.id &&
          match.status === "offered"
        ) {
          match.status = "declined";
          match.respondedAt = new Date();
          match.declineReason = "Another recipient accepted the donation";
        }
      });
    }

    await donation.save();
    console.log(`💾 Donation ${donationId} saved with accepted status`);

    // Create logistics task
    const donor = await User.findById(donation.donor);
    const taskData = {
      donation: donationId,
      pickupLocation: {
        address: donation.pickupAddress,
        lat: donation.location.lat,
        lng: donation.location.lng,
        instructions: `Pick up from ${donor?.name || 'Donor'}`
      },
      dropoffLocation: {
        address: recipient.recipientDetails?.address || recipient.contactInfo?.address || donation.pickupAddress,
        lat: recipient.recipientDetails?.location?.lat || recipient.contactInfo?.location?.lat || donation.location.lat,
        lng: recipient.recipientDetails?.location?.lng || recipient.contactInfo?.location?.lng || donation.location.lng,
        contactPerson: recipient.recipientDetails?.organizationName || recipient.name,
        phone: recipient.contactInfo?.phone
      },
      scheduledPickupTime: donation.type === 'bulk' && donation.scheduledPickup 
        ? donation.scheduledPickup 
        : new Date(Date.now() + 2 * 60 * 60 * 1000), // 2 hours from now
      status: "pending",
      urgency: donation.urgency || "normal",
      specialInstructions: donation.aiAnalysis?.suggestedHandling || "Handle with care"
    };

    console.log("📦 Creating logistics task:", taskData);

    const LogisticsTask = require("../models/LogisticsTask");
    const task = new LogisticsTask(taskData);
    await task.save();
    console.log("✅ Logistics task created:", task._id);

    // Assign volunteer asynchronously (don't wait for it)
    const donationController = require('./donationController');
    donationController.assignVolunteerToTask(task._id).catch(error => {
      console.error("❌ Volunteer assignment failed:", error);
      // Continue even if volunteer assignment fails
    });

    // Send notifications asynchronously
    const notificationService = require('../services/notificationService');
    notificationService.sendStatusUpdate(
      donation.donor,
      "Donation Accepted! 🎉",
      `Your donation "${donation.aiDescription || donation.description || 'Food Donation'}" has been accepted by ${recipient.recipientDetails?.organizationName || recipient.name}`,
      { donationId: donation._id, recipientId: req.user.id }
    ).catch(error => {
      console.error("❌ Notification failed:", error);
    });

    // Populate and return the updated donation
    const populatedDonation = await Donation.findById(donationId)
      .populate("donor", "name contactInfo donorDetails")
      .populate("acceptedBy", "name recipientDetails")
      .populate("assignedVolunteer", "name volunteerDetails")
      .populate("matchedRecipients.recipient", "name recipientDetails");

    console.log(`🎉 Donation ${donationId} successfully accepted by ${req.user.id}`);

    res.json({
      success: true,
      data: { 
        donation: populatedDonation, 
        task: {
          id: task._id,
          status: task.status,
          scheduledPickupTime: task.scheduledPickupTime
        }
      },
      message: "Donation accepted successfully! A volunteer will be assigned for pickup soon."
    });

  } catch (error) {
    console.error("💥 Accept donation error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to accept donation: " + error.message,
    });
  }
};

exports.getAvailableDonations = async (req, res) => {
  try {
    const { page = 1, limit = 10, categories, distance } = req.query;
    console.log("🔍 Fetching available donations for user:", req.user.id);

    let query = {
      status: "active",
      "matchedRecipients.recipient": req.user.id,
      "matchedRecipients.status": "offered",
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
    console.error("💥 Get available donations error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.uploadImages = async (req, res) => {
  try {
    console.log("📤 Uploading images...");
    console.log("Files received:", req.files?.length || 0);

    if (!req.files || req.files.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No images provided",
      });
    }

    // Validate each file
    for (let i = 0; i < req.files.length; i++) {
      const file = req.files[i];
      console.log(`File ${i + 1}:`, {
        mimetype: file.mimetype,
        size: file.size,
        originalname: file.originalname,
      });

      // Check if it's actually an image
      if (!file.mimetype.startsWith("image/")) {
        return res.status(400).json({
          success: false,
          message: `File ${file.originalname} is not a valid image file`,
        });
      }

      // Check file size (10MB limit)
      if (file.size > 10 * 1024 * 1024) {
        return res.status(400).json({
          success: false,
          message: `File ${file.originalname} is too large. Maximum size is 10MB`,
        });
      }
    }

    const uploadPromises = req.files.map((file, index) => {
      return new Promise((resolve, reject) => {
        cloudinary.uploader
          .upload_stream(
            {
              resource_type: "image",
              folder: "zero_hunger/donations",
              transformation: [
                { quality: "auto:good" },
                { fetch_format: "auto" },
                { width: 1200, height: 1200, crop: "limit" },
              ],
            },
            (error, result) => {
              if (error) {
                console.error(`❌ Upload error for file ${index + 1}:`, error);
                reject(error);
              } else {
                console.log(`✅ File ${index + 1} uploaded successfully`);
                resolve(result.secure_url);
              }
            }
          )
          .end(file.buffer);
      });
    });

    const imageUrls = await Promise.all(uploadPromises);
    console.log("✅ All images uploaded successfully:", imageUrls.length);

    res.json({
      success: true,
      data: {
        images: imageUrls,
      },
      message: `Successfully uploaded ${imageUrls.length} image(s)`,
    });
  } catch (error) {
    console.error("💥 Image upload error:", error);
    res.status(500).json({
      success: false,
      message: `Upload failed: ${error.message}`,
    });
  }
};

exports.getDonorDashboard = async (req, res) => {
  try {
    console.log("📊 Fetching donor dashboard for user:", req.user.id);

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
    console.error("💥 Donor dashboard error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getDonationDetails = async (req, res) => {
  try {
    const { donationId } = req.params;
    console.log("🔍 Fetching donation details:", donationId);

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
    console.error("💥 Get donation details error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.updateDonationStatus = async (req, res) => {
  try {
    const { donationId } = req.params;
    const { status } = req.body;
    console.log("🔄 Updating donation status:", donationId, "to:", status);

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
    console.error("💥 Update donation status error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getDonationStats = async (req, res) => {
  try {
    const userId = req.user.id;

    // Simple approach using Mongoose find()
    const donations = await Donation.find({ donor: userId });

    const stats = {
      total: donations.length,
      active: donations.filter((d) =>
        ["active", "matched", "scheduled"].includes(d.status)
      ).length,
      completed: donations.filter((d) => d.status === "delivered").length,
      pending: donations.filter((d) =>
        ["pending", "ai_processing"].includes(d.status)
      ).length,
      totalQuantity: donations.reduce(
        (sum, d) => sum + (d.quantity?.amount || 0),
        0
      ),
      totalImpact: donations
        .filter((d) => d.status === "delivered")
        .reduce((sum, d) => sum + (d.quantity?.amount || 0), 0),
    };

    res.json({ success: true, data: stats });
  } catch (error) {
    console.error("💥 Get donation stats error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.searchAvailableDonations = async (req, res) => {
  try {
    const { query, categories, maxDistance = 50 } = req.query;
    console.log(
      "🔍 Searching donations for user:",
      req.user.id,
      "query:",
      query
    );

    const recipient = await User.findById(req.user.id);
    const recipientLocation =
      recipient.recipientDetails?.location || recipient.contactInfo?.location;

    let searchCriteria = {
      status: "active",
      "matchedRecipients.recipient": req.user.id,
      "matchedRecipients.status": "offered",
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
    console.error("💥 Search donations error:", error);
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

    console.log("🔍 Analyzing food images with AI...");

    // Call Gemini AI service for analysis
    const aiAnalysis = await geminiService.analyzeFoodImages(images);

    res.json({
      success: true,
      data: aiAnalysis,
      message: "AI analysis completed successfully",
    });
  } catch (error) {
    console.error("💥 Image analysis error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to analyze images: " + error.message,
    });
  }
};
