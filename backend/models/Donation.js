const mongoose = require("mongoose");

const donationSchema = new mongoose.Schema(
  {
    donor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    type: {
      type: String,
      enum: ["normal", "bulk"],
      required: true,
    },
    status: {
      type: String,
      enum: [
        "pending",
        "ai_processing",
        "active",
        "matched",
        "scheduled",
        "picked_up",
        "delivered",
        "cancelled",
        "expired",
      ],
      default: "pending",
    },

    // Enhanced food details
    images: [String],
    description: String,
    aiDescription: String,
    categories: [String],
    tags: [String],
    quantity: {
      amount: { type: Number, required: true, min: 1 },
      unit: { type: String, required: true, default: "units" },
    },
    handlingWindow: {
      start: Date,
      end: Date,
    },

    // Bulk donation specific
    scheduledPickup: Date,
    expectedQuantity: String,
    eventDetails: {
      eventName: String,
      eventType: String,
      attendees: Number,
    },

    // Enhanced location
    pickupAddress: { type: String, required: true },
    location: {
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
      geocoded: { type: Boolean, default: false },
    },

    // Enhanced AI Analysis results
    aiAnalysis: {
      foodTypes: [String],
      freshnessScore: { type: Number, min: 0, max: 1 },
      safetyWarnings: [String],
      suggestedHandling: String,
      confidenceScore: { type: Number, min: 0, max: 1 },
      urgency: {
        type: String,
        enum: ["critical", "high", "normal"],
        default: "normal",
      },
      nutritionalInfo: {
        calories: Number,
        protein: Number,
        carbs: Number,
        fats: Number,
      },
      allergens: [String],
      dietaryInfo: [String],
      estimatedShelfLife: String,
    },

    // Enhanced matching
    matchedRecipients: [
      {
        recipient: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
          required: true,
        },
        matchScore: {
          type: Number,
          required: true,
          min: 0,
          max: 1,
        },
        status: {
          type: String,
          enum: ["offered", "accepted", "declined", "expired"],
          default: "offered",
        },
        respondedAt: Date,
        declineReason: String,
        matchingMethod: String,
        matchReasons: [String],
        createdAt: { type: Date, default: Date.now },
      },
    ],

    acceptedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
    assignedVolunteer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },

    // Enhanced metadata
    urgency: {
      type: String,
      enum: ["critical", "high", "normal"],
      default: "normal",
    },
    priority: {
      type: Number,
      default: 1,
      min: 1,
      max: 10,
    },

    // Food safety compliance
    safetyChecklist: [
      {
        item: String,
        completed: { type: Boolean, default: false },
        verifiedBy: String,
        timestamp: Date,
      },
    ],

    // Feedback and ratings
    donorRating: {
      type: Number,
      min: 1,
      max: 5,
    },
    donorFeedback: String,
    recipientRating: {
      type: Number,
      min: 1,
      max: 5,
    },
    recipientFeedback: String,

    // Analytics
    views: {
      type: Number,
      default: 0,
    },
    offersSent: {
      type: Number,
      default: 0,
    },

    // Timestamps
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now },
    expiresAt: { type: Date },

    // Delivery tracking
    pickupTime: Date,
    deliveryTime: Date,

    // Matching process tracking
    matchingStartedAt: Date,
    matchingCompletedAt: Date,
  },
  {
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Indexes for performance
donationSchema.index({ donor: 1, status: 1 });
donationSchema.index({ status: 1, urgency: -1 });
donationSchema.index({ "location.lat": 1, "location.lng": 1 });
donationSchema.index({ categories: 1 });
donationSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
donationSchema.index({ acceptedBy: 1, status: 1 });
donationSchema.index({ "matchedRecipients.recipient": 1 });
donationSchema.index({ "matchedRecipients.status": 1 });
donationSchema.index({ createdAt: -1 });

// Pre-save middleware
donationSchema.pre("save", function (next) {
  this.updatedAt = Date.now();

  // Set expiration date based on handling window
  if (this.handlingWindow?.end && !this.expiresAt) {
    this.expiresAt = new Date(
      this.handlingWindow.end.getTime() + 24 * 60 * 60 * 1000
    );
  }

  // Auto-expire if past handling window
  if (
    this.handlingWindow?.end &&
    new Date() > this.handlingWindow.end &&
    this.status === "active"
  ) {
    this.status = "expired";
  }

  // Update offers sent count
  if (this.isModified("matchedRecipients")) {
    this.offersSent = this.matchedRecipients.length;
  }

  next();
});

// Virtual for time remaining
donationSchema.virtual("timeRemaining").get(function () {
  if (this.handlingWindow?.end) {
    const now = new Date();
    const end = new Date(this.handlingWindow.end);
    return Math.max(0, end - now);
  }
  return null;
});

// Virtual for match rate
donationSchema.virtual("matchRate").get(function () {
  if (this.matchedRecipients.length === 0) return 0;
  const accepted = this.matchedRecipients.filter(
    (m) => m.status === "accepted"
  ).length;
  return (accepted / this.matchedRecipients.length) * 100;
});

// Virtual for isExpiringSoon
donationSchema.virtual("isExpiringSoon").get(function () {
  if (!this.handlingWindow?.end) return false;
  const timeRemaining = this.timeRemaining;
  return timeRemaining > 0 && timeRemaining <= 4 * 60 * 60 * 1000; // 4 hours
});

// NEW: Static method to find donations by recipient
donationSchema.statics.findByRecipient = function (recipientId, options = {}) {
  const { status, includeOffered = false } = options;

  let query = {
    $or: [
      { acceptedBy: recipientId },
      { "matchedRecipients.recipient": recipientId },
    ],
  };

  if (status) {
    query.status = status;
  }

  if (!includeOffered) {
    query["matchedRecipients.status"] = { $ne: "offered" };
  }

  return this.find(query)
    .populate("donor", "name email contactInfo donorDetails")
    .populate("acceptedBy", "name email recipientDetails")
    .populate("assignedVolunteer", "name email volunteerDetails")
    .populate("matchedRecipients.recipient", "name email recipientDetails")
    .sort({ createdAt: -1 });
};

// NEW: Static method to find available donations for recipient
donationSchema.statics.findAvailableForRecipient = function (recipientId) {
  return this.find({
    status: "active",
    $or: [
      { "matchedRecipients.recipient": recipientId },
      {
        // Also show donations that could potentially match
        "matchedRecipients.recipient": { $ne: recipientId },
        expiresAt: { $gt: new Date() },
      },
    ],
  })
    .populate("donor", "name email contactInfo donorDetails")
    .sort({ urgency: -1, createdAt: -1 });
};

// NEW: Static method to get donor statistics
donationSchema.statics.getDonorStats = function (donorId) {
  return this.aggregate([
    {
      $match: { donor: donorId },
    },
    {
      $group: {
        _id: "$status",
        count: { $sum: 1 },
        totalQuantity: { $sum: "$quantity.amount" },
      },
    },
  ]);
};

// NEW: Static method to get recipient statistics
donationSchema.statics.getRecipientStats = function (recipientId) {
  return this.aggregate([
    {
      $match: {
        $or: [
          { acceptedBy: recipientId },
          { "matchedRecipients.recipient": recipientId },
        ],
      },
    },
    {
      $group: {
        _id: "$status",
        count: { $sum: 1 },
        totalQuantity: { $sum: "$quantity.amount" },
      },
    },
  ]);
};

// Instance method to check if donation is expiring soon
donationSchema.methods.checkIfExpiringSoon = function (hours = 4) {
  if (this.handlingWindow?.end) {
    const now = new Date();
    const timeRemaining = this.handlingWindow.end - now;
    return timeRemaining > 0 && timeRemaining <= hours * 60 * 60 * 1000;
  }
  return false;
};

// Instance method to get best match
donationSchema.methods.getBestMatch = function () {
  const accepted = this.matchedRecipients.filter(
    (m) => m.status === "accepted"
  );
  if (accepted.length > 0) {
    return accepted.sort((a, b) => b.matchScore - a.matchScore)[0];
  }

  const offered = this.matchedRecipients.filter((m) => m.status === "offered");
  if (offered.length > 0) {
    return offered.sort((a, b) => b.matchScore - a.matchScore)[0];
  }

  return null;
};

// Instance method to find and store matches
donationSchema.methods.findAndStoreMatches = async function () {
  try {
    const matchingService = require("../services/matchingService");
    console.log(`🔍 Starting matching process for donation: ${this._id}`);

    const matches = await matchingService.findBestMatches(this._id);

    if (matches && matches.length > 0) {
      this.matchedRecipients = matches.map((match) => ({
        recipient: match.recipient._id,
        matchScore: match.totalScore,
        status: "offered",
        matchingMethod: match.matchingMethod || "ai",
        matchReasons: match.matchReasons || [],
      }));

      this.matchingCompletedAt = new Date();
      await this.save();

      console.log(
        `✅ Stored ${matches.length} matches for donation: ${this._id}`
      );

      // Send notifications
      const notificationService = require("../services/notificationService");
      for (const match of matches) {
        await notificationService.sendDonationOffer(
          match.recipient._id,
          this._id,
          match.totalScore
        );
      }
    } else {
      console.log(`❌ No matches found for donation: ${this._id}`);
    }
  } catch (error) {
    console.error(
      `💥 Error in findAndStoreMatches for donation ${this._id}:`,
      error
    );
  }
};

module.exports = mongoose.model("Donation", donationSchema);
