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

// NEW: Accept a donation offer
exports.acceptDonationOffer = async (req, res) => {
  try {
    const { donationId } = req.params;
    console.log(
      `✅ Recipient ${req.user.id} accepting donation: ${donationId}`
    );

    const donation = await Donation.findById(donationId);
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
      matchedRecipients: donation.matchedRecipients.map((match) => ({
        recipient: match.recipient.toString(),
        status: match.status,
      })),
      currentUser: req.user.id,
    });

    // Check if this donation is offered to the recipient
    const recipientMatch = donation.matchedRecipients.find(
      (match) =>
        match.recipient.toString() === req.user.id && match.status === "offered"
    );

    console.log("🔍 Found recipient match:", recipientMatch);

    if (!recipientMatch) {
      // More detailed error message
      const availableMatches = donation.matchedRecipients.filter(
        (m) => m.recipient.toString() === req.user.id
      );
      console.log("❌ Available matches for user:", availableMatches);

      return res.status(403).json({
        success: false,
        message:
          "This donation is not offered to you or has expired. Available matches: " +
          JSON.stringify(availableMatches),
      });
    }

    // ... rest of your existing code
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
