const Donation = require("../models/Donation");
const User = require("../models/User");

exports.getRecipientDashboard = async (req, res) => {
  try {
    const recipient = await User.findById(req.user.id);

    // Get accepted donations
    const acceptedDonations = await Donation.find({
      acceptedBy: req.user.id,
    })
      .populate("donor", "name contactInfo")
      .populate("assignedVolunteer", "name")
      .sort({ createdAt: -1 });

    // Get stats
    const stats = {
      totalAccepted: await Donation.countDocuments({ acceptedBy: req.user.id }),
      pendingPickup: await Donation.countDocuments({
        acceptedBy: req.user.id,
        status: { $in: ["matched", "scheduled"] },
      }),
      delivered: await Donation.countDocuments({
        acceptedBy: req.user.id,
        status: "delivered",
      }),
    };

    res.json({
      success: true,
      data: {
        recipient,
        acceptedDonations,
        stats,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.updateRecipientProfile = async (req, res) => {
  try {
    const {
      organizationName,
      organizationType,
      address,
      capacity,
      dietaryRestrictions,
      operatingHours,
    } = req.body;

    const recipient = await User.findByIdAndUpdate(
      req.user.id,
      {
        recipientDetails: {
          organizationName,
          organizationType,
          address,
          capacity,
          dietaryRestrictions,
          operatingHours,
        },
      },
      { new: true }
    );

    res.json({
      success: true,
      data: recipient,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
