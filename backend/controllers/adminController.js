const User = require("../models/User");
const Donation = require("../models/Donation");

// Controller functions
const getPendingVerifications = async (req, res) => {
  try {
    console.log("Fetching pending verifications");

    const pendingRecipients = await User.find({
      role: "recipient",
      "recipientDetails.verificationStatus": "pending",
    }).select("-password");

    res.json({
      success: true,
      data: pendingRecipients,
    });
  } catch (error) {
    console.error("Get pending verifications error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const verifyRecipient = async (req, res) => {
  try {
    const { userId } = req.params;
    const { status, notes } = req.body;

    console.log(`Verifying recipient ${userId} with status: ${status}`);

    const user = await User.findById(userId);
    if (!user || user.role !== "recipient") {
      return res.status(404).json({
        success: false,
        message: "Recipient not found",
      });
    }

    user.recipientDetails.verificationStatus = status;
    user.recipientDetails.verifiedBy = req.user.id;
    user.recipientDetails.verificationNotes = notes;

    await user.save();

    res.json({
      success: true,
      data: user,
      message: `Recipient ${status} successfully`,
    });
  } catch (error) {
    console.error("Verify recipient error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const getPlatformStats = async (req, res) => {
  try {
    console.log("Fetching platform statistics");

    const totalUsers = await User.countDocuments();
    const totalDonations = await Donation.countDocuments();
    const completedDonations = await Donation.countDocuments({
      status: "delivered",
    });
    const activeDonations = await Donation.countDocuments({
      status: { $in: ["active", "matched", "scheduled"] },
    });

    const userStats = await User.aggregate([
      {
        $group: {
          _id: "$role",
          count: { $sum: 1 },
        },
      },
    ]);

    const donationStats = await Donation.aggregate([
      {
        $group: {
          _id: "$status",
          count: { $sum: 1 },
        },
      },
    ]);

    res.json({
      success: true,
      data: {
        totalUsers,
        totalDonations,
        completedDonations,
        activeDonations,
        userStats,
        donationStats,
      },
    });
  } catch (error) {
    console.error("Get platform stats error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Export functions properly
module.exports = {
  getPendingVerifications,
  verifyRecipient,
  getPlatformStats,
};
