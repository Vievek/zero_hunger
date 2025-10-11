const Donation = require("../models/Donation");
const User = require("../models/User");
const notificationService = require("../services/notificationService");

// NEW: Get recipient dashboard with comprehensive data
exports.getRecipientDashboard = async (req, res) => {
  try {
    console.log("🔍 Fetching recipient dashboard for:", req.user.id);

    // Validate user is actually a recipient
    if (req.user.role !== "recipient") {
      return res.status(403).json({
        success: false,
        message: "Access denied. User is not a recipient.",
      });
    }

    const recipient = await User.findById(req.user.id);
    if (!recipient) {
      return res.status(404).json({
        success: false,
        message: "Recipient not found",
      });
    }

    // Safely calculate current load with error handling
    let currentLoad = 0;
    try {
      currentLoad = await recipient.getCurrentLoad();
    } catch (loadError) {
      console.error("❌ Error calculating current load:", loadError);
      currentLoad = recipient.recipientDetails?.currentLoad || 0;
    }

    console.log(
      "📊 Loading recipient data for:",
      recipient.recipientDetails?.organizationName
    );

    // Use Promise.allSettled to prevent one failed query from breaking everything
    const [acceptedResult, matchedResult, availableResult, statsResult] =
      await Promise.allSettled([
        Donation.find({ acceptedBy: req.user.id })
          .populate("donor", "name contactInfo donorDetails")
          .populate("assignedVolunteer", "name volunteerDetails")
          .sort({ createdAt: -1 }),

        Donation.find({
          "matchedRecipients.recipient": req.user.id,
          "matchedRecipients.status": { $in: ["offered", "accepted"] },
          status: { $in: ["active", "matched"] },
        })
          .populate("donor", "name contactInfo donorDetails")
          .sort({ createdAt: -1 }),

        Donation.findAvailableForRecipient(req.user.id),

        this.calculateRecipientStats(req.user.id),
      ]);

    // Handle results safely
    const acceptedDonations =
      acceptedResult.status === "fulfilled" ? acceptedResult.value : [];
    const matchedDonations =
      matchedResult.status === "fulfilled" ? matchedResult.value : [];
    const availableDonations =
      availableResult.status === "fulfilled" ? availableResult.value : [];
    const stats = statsResult.status === "fulfilled" ? statsResult.value : {};

    res.json({
      success: true,
      data: {
        recipient: {
          id: recipient._id,
          name: recipient.name,
          email: recipient.email,
          organizationName: recipient.recipientDetails?.organizationName,
          organizationType: recipient.recipientDetails?.organizationType,
          capacity: recipient.recipientDetails?.capacity,
          currentLoad: currentLoad,
          verificationStatus: recipient.recipientDetails?.verificationStatus,
          dietaryRestrictions: recipient.recipientDetails?.dietaryRestrictions,
          preferredFoodTypes: recipient.recipientDetails?.preferredFoodTypes,
          isActive: recipient.recipientDetails?.isActive,
        },
        acceptedDonations,
        matchedDonations,
        availableDonations,
        stats,
      },
    });
  } catch (error) {
    console.error("💥 Recipient dashboard error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to load recipient dashboard",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

// NEW: Calculate comprehensive recipient stats
exports.calculateRecipientStats = async (recipientId) => {
  try {
    const Donation = mongoose.model("Donation");

    const [totalAccepted, pendingPickup, delivered, activeOffers, totalImpact] =
      await Promise.all([
        Donation.countDocuments({ acceptedBy: recipientId }),
        Donation.countDocuments({
          acceptedBy: recipientId,
          status: { $in: ["matched", "scheduled", "picked_up"] },
        }),
        Donation.countDocuments({
          acceptedBy: recipientId,
          status: "delivered",
        }),
        Donation.countDocuments({
          "matchedRecipients.recipient": recipientId,
          "matchedRecipients.status": "offered",
          status: "active",
        }),
        Donation.aggregate([
          {
            $match: {
              acceptedBy: mongoose.Types.ObjectId(recipientId),
              status: "delivered",
            },
          },
          {
            $group: {
              _id: null,
              totalQuantity: { $sum: "$quantity.amount" },
              totalDonations: { $sum: 1 },
            },
          },
        ]),
      ]);

    const impactResult =
      totalImpact.length > 0
        ? totalImpact[0]
        : { totalQuantity: 0, totalDonations: 0 };

    return {
      totalAccepted,
      pendingPickup,
      delivered,
      activeOffers,
      totalQuantity: impactResult.totalQuantity,
      totalMeals: Math.round(impactResult.totalQuantity * 2.5),
      acceptanceRate:
        totalAccepted > 0 ? Math.round((delivered / totalAccepted) * 100) : 0,
    };
  } catch (error) {
    console.error("Stats calculation error:", error);
    return {
      totalAccepted: 0,
      pendingPickup: 0,
      delivered: 0,
      activeOffers: 0,
      totalQuantity: 0,
      totalMeals: 0,
      acceptanceRate: 0,
    };
  }
};

// NEW: Get all available donations for recipient (including non-matched)
exports.getAllAvailableDonations = async (req, res) => {
  try {
    console.log(
      "🔍 Fetching all available donations for recipient:",
      req.user.id
    );

    const { page = 1, limit = 20, categories, search, maxDistance } = req.query;
    const skip = (page - 1) * limit;

    let query = {
      status: "active",
      $or: [
        { "matchedRecipients.recipient": req.user.id },
        {
          // Also show donations that could potentially match this recipient
          "matchedRecipients.recipient": { $ne: req.user.id },
          expiresAt: { $gt: new Date() },
        },
      ],
    };

    // Category filter
    if (categories) {
      const categoryList = categories.split(",");
      query.categories = { $in: categoryList };
    }

    // Search filter
    if (search) {
      query.$or = [
        { description: { $regex: search, $options: "i" } },
        { aiDescription: { $regex: search, $options: "i" } },
        { categories: { $in: [new RegExp(search, "i")] } },
      ];
    }

    const [donations, total] = await Promise.all([
      Donation.find(query)
        .populate("donor", "name contactInfo donorDetails")
        .populate("matchedRecipients.recipient", "name recipientDetails")
        .sort({ urgency: -1, createdAt: -1 })
        .limit(parseInt(limit))
        .skip(skip),
      Donation.countDocuments(query),
    ]);

    console.log(
      `📦 Found ${donations.length} available donations out of ${total} total`
    );

    res.json({
      success: true,
      data: {
        donations,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(total / limit),
          totalDonations: total,
          hasNext: page * limit < total,
          hasPrev: page > 1,
        },
      },
    });
  } catch (error) {
    console.error("💥 Available donations error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to load available donations: " + error.message,
    });
  }
};

// NEW: Get matched donations for recipient
exports.getMatchedDonations = async (req, res) => {
  try {
    console.log("🔍 Fetching matched donations for recipient:", req.user.id);

    const { status = "offered" } = req.query;

    let matchQuery = {
      "matchedRecipients.recipient": req.user.id,
      "matchedRecipients.status": status,
    };

    // If status is 'accepted', also check if recipient actually accepted it
    if (status === "accepted") {
      matchQuery.acceptedBy = req.user.id;
    }

    const donations = await Donation.find(matchQuery)
      .populate("donor", "name contactInfo donorDetails")
      .populate("acceptedBy", "name recipientDetails")
      .populate("assignedVolunteer", "name volunteerDetails")
      .sort({ createdAt: -1 });

    console.log(`🤝 Found ${donations.length} ${status} donations`);

    res.json({
      success: true,
      data: {
        donations,
        matchStatus: status,
        total: donations.length,
      },
    });
  } catch (error) {
    console.error("💥 Matched donations error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to load matched donations: " + error.message,
    });
  }
};


exports.acceptDonationOffer = async (req, res) => {
  try {
    const { donationId } = req.params;
    console.log(`✅ ${req.user.role} ${req.user.id} accepting donation: ${donationId}`);

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

// NEW: Decline a donation offer
exports.declineDonationOffer = async (req, res) => {
  try {
    const { donationId } = req.params;
    const { reason } = req.body;

    console.log(
      `❌ Recipient ${req.user.id} declining donation: ${donationId}`
    );

    const donation = await Donation.findById(donationId);
    if (!donation) {
      return res.status(404).json({
        success: false,
        message: "Donation not found",
      });
    }

    const recipientMatch = donation.matchedRecipients.find(
      (match) =>
        match.recipient.toString() === req.user.id && match.status === "offered"
    );

    if (!recipientMatch) {
      return res.status(403).json({
        success: false,
        message: "This donation is not offered to you",
      });
    }

    recipientMatch.status = "declined";
    recipientMatch.respondedAt = new Date();

    // Add decline reason if provided
    if (reason) {
      recipientMatch.declineReason = reason;
    }

    await donation.save();

    console.log(`❌ Donation ${donationId} declined by ${req.user.id}`);

    res.json({
      success: true,
      message: "Donation offer declined",
    });
  } catch (error) {
    console.error("💥 Decline donation error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to decline donation: " + error.message,
    });
  }
};

// NEW: Update recipient profile
exports.updateRecipientProfile = async (req, res) => {
  try {
    const {
      organizationName,
      organizationType,
      address,
      capacity,
      dietaryRestrictions,
      preferredFoodTypes,
      operatingHours,
      isActive,
    } = req.body;

    console.log(`🔧 Updating recipient profile for: ${req.user.id}`);

    const updateData = {
      recipientDetails: {
        organizationName,
        organizationType,
        address,
        capacity,
        dietaryRestrictions,
        preferredFoodTypes,
        operatingHours,
        isActive,
      },
    };

    const recipient = await User.findByIdAndUpdate(req.user.id, updateData, {
      new: true,
      runValidators: true,
    });

    if (!recipient) {
      return res.status(404).json({
        success: false,
        message: "Recipient not found",
      });
    }

    console.log(
      `✅ Recipient profile updated: ${recipient.recipientDetails?.organizationName}`
    );

    res.json({
      success: true,
      data: {
        id: recipient._id,
        name: recipient.name,
        organizationName: recipient.recipientDetails?.organizationName,
        organizationType: recipient.recipientDetails?.organizationType,
        capacity: recipient.recipientDetails?.capacity,
        dietaryRestrictions: recipient.recipientDetails?.dietaryRestrictions,
        preferredFoodTypes: recipient.recipientDetails?.preferredFoodTypes,
        isActive: recipient.recipientDetails?.isActive,
        verificationStatus: recipient.recipientDetails?.verificationStatus,
      },
      message: "Profile updated successfully",
    });
  } catch (error) {
    console.error("💥 Update recipient profile error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to update profile: " + error.message,
    });
  }
};

// NEW: Get recipient statistics
exports.getRecipientStats = async (req, res) => {
  try {
    console.log(`📊 Getting stats for recipient: ${req.user.id}`);

    const stats = await this.calculateRecipientStats(req.user.id);

    res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    console.error("💥 Get recipient stats error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to load statistics: " + error.message,
    });
  }
};
