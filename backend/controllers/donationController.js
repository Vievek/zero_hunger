const Donation = require("../models/Donation");
const User = require("../models/User");
const LogisticsTask = require("../models/LogisticsTask");
const geminiService = require("../services/geminiService");
const matchingService = require("../services/matchingService");
const routeOptimizationService = require("../services/routeOptimizationService");
const notificationService = require("../services/notificationService");

exports.createDonation = async (req, res) => {
  try {
    const {
      type,
      images,
      quantity,
      scheduledPickup,
      pickupAddress,
      location,
      expectedQuantity,
    } = req.body;

    // Validate bulk donation requirements
    if (type === "bulk" && !scheduledPickup) {
      return res.status(400).json({
        success: false,
        message: "Scheduled pickup is required for bulk donations",
      });
    }

    const donation = new Donation({
      donor: req.user.id,
      type,
      images,
      quantity,
      expectedQuantity: type === "bulk" ? expectedQuantity : undefined,
      scheduledPickup: type === "bulk" ? scheduledPickup : undefined,
      pickupAddress,
      location,
      status: images && images.length > 0 ? "ai_processing" : "active",
    });

    await donation.save();

    // Process with AI if images provided
    if (images && images.length > 0) {
      try {
        const aiAnalysis = await geminiService.analyzeFoodImages(images);

        donation.aiDescription = aiAnalysis.description;
        donation.categories = aiAnalysis.categories;
        donation.tags = [...aiAnalysis.allergens, ...aiAnalysis.dietaryInfo];
        donation.aiAnalysis = aiAnalysis;

        // Set handling window based on AI analysis
        const handlingWindow = calculateHandlingWindow(
          aiAnalysis.freshnessScore
        );
        donation.handlingWindow = handlingWindow;

        donation.status = "active";
        await donation.save();

        // Start matching process
        await initiateMatching(donation._id);
      } catch (aiError) {
        console.error("AI processing failed:", aiError);
        donation.status = "active";
        donation.aiDescription = "AI analysis failed - manual review needed";
        await donation.save();

        // Start matching even if AI fails
        await initiateMatching(donation._id);
      }
    } else {
      // No images - start matching immediately
      await initiateMatching(donation._id);
    }

    // Populate the response with donation data
    const populatedDonation = await Donation.findById(donation._id)
      .populate("donor", "name email")
      .populate("matchedRecipients.recipient", "name recipientDetails");

    res.status(201).json({
      success: true,
      data: populatedDonation,
      message:
        "Donation created successfully" +
        (images && images.length > 0 ? " - AI processing started" : ""),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Helper function to calculate handling window
function calculateHandlingWindow(freshnessScore) {
  const now = new Date();
  // Convert freshness score (0-1) to hours (4-24 hours)
  const hours = 4 + freshnessScore * 20;
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
        recipient: match.recipient,
        matchScore: match.totalScore,
        status: "offered",
      }));

      await donation.save();

      // Send notifications to matched recipients
      for (const match of matches) {
        await notificationService.sendDonationOffer(
          match.recipient,
          donationId,
          match.matchScore
        );
      }
    }
  } catch (error) {
    console.error("Matching process error:", error);
  }
}

exports.acceptDonation = async (req, res) => {
  try {
    const { donationId } = req.params;

    const donation = await Donation.findById(donationId);
    if (!donation) {
      return res.status(404).json({
        success: false,
        message: "Donation not found",
      });
    }

    // Check if user is in matched recipients
    const recipientMatch = donation.matchedRecipients.find(
      (match) => match.recipient.toString() === req.user.id
    );

    if (!recipientMatch) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to accept this donation",
      });
    }

    // Update donation status
    donation.acceptedBy = req.user.id;
    donation.status = "matched";
    recipientMatch.status = "accepted";
    recipientMatch.respondedAt = new Date();

    await donation.save();

    // Create logistics task
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
          recipient.recipientDetails?.address || recipient.contactInfo?.address,
        lat: recipient.recipientDetails?.location?.lat || donation.location.lat,
        lng: recipient.recipientDetails?.location?.lng || donation.location.lng,
      },
      scheduledPickupTime:
        donation.type === "bulk"
          ? donation.scheduledPickup
          : new Date(Date.now() + 2 * 60 * 60 * 1000), // 2 hours from now
      status: "pending",
    });

    await task.save();

    // Assign volunteer
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
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Helper function to assign volunteer
async function assignVolunteerToTask(taskId) {
  try {
    const task = await LogisticsTask.findById(taskId).populate("donation");
    const availableVolunteers = await User.find({
      role: "volunteer",
      "volunteerDetails.isAvailable": true,
    });

    if (availableVolunteers.length === 0) {
      console.log("No available volunteers");
      return;
    }

    // Simple volunteer assignment (first available)
    // In production, you'd use the GA optimization here
    const assignedVolunteer = availableVolunteers[0];

    task.volunteer = assignedVolunteer._id;
    task.status = "assigned";
    await task.save();

    // Update donation with assigned volunteer
    await Donation.findByIdAndUpdate(task.donation._id, {
      assignedVolunteer: assignedVolunteer._id,
    });

    // Send notification to volunteer
    await notificationService.sendTaskAssignment(assignedVolunteer._id, taskId);
  } catch (error) {
    console.error("Volunteer assignment error:", error);
  }
}

exports.getDonorDashboard = async (req, res) => {
  try {
    const donations = await Donation.find({ donor: req.user.id })
      .populate("acceptedBy", "name recipientDetails.organizationName")
      .populate("assignedVolunteer", "name")
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
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getDonationDetails = async (req, res) => {
  try {
    const { donationId } = req.params;

    const donation = await Donation.findById(donationId)
      .populate("donor", "name contactInfo")
      .populate("acceptedBy", "name recipientDetails")
      .populate("assignedVolunteer", "name volunteerDetails")
      .populate("matchedRecipients.recipient", "name recipientDetails");

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: "Donation not found",
      });
    }

    // Check if user is authorized to view this donation
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
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
