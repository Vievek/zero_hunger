const mongoose = require("mongoose");

const donationSchema = new mongoose.Schema({
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
    amount: Number,
    unit: String,
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
  pickupAddress: String,
  location: {
    lat: Number,
    lng: Number,
    geocoded: Boolean,
  },

  // Enhanced AI Analysis results
  aiAnalysis: {
    foodTypes: [String],
    freshnessScore: Number,
    safetyWarnings: [String],
    suggestedHandling: String,
    confidenceScore: Number,
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
  },

  // Enhanced matching
  matchedRecipients: [
    {
      recipient: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
      matchScore: Number,
      status: {
        type: String,
        enum: ["offered", "accepted", "declined", "expired"],
        default: "offered",
      },
      respondedAt: Date,
      matchingMethod: String, // 'ai' or 'fallback'
      matchReasons: [String], // Why this match was made
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
      completed: Boolean,
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

  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
  expiresAt: { type: Date }, // Auto-expire donations
});

// Indexes for performance
donationSchema.index({ donor: 1, status: 1 });
donationSchema.index({ status: 1, urgency: -1 });
donationSchema.index({ "location.lat": 1, "location.lng": 1 });
donationSchema.index({ categories: 1 });
donationSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

// Pre-save middleware
donationSchema.pre("save", function (next) {
  this.updatedAt = Date.now();

  // Set expiration date based on handling window
  if (this.handlingWindow?.end && !this.expiresAt) {
    this.expiresAt = new Date(
      this.handlingWindow.end.getTime() + 24 * 60 * 60 * 1000
    ); // 24 hours after handling window
  }

  // Auto-expire if past handling window
  if (
    this.handlingWindow?.end &&
    new Date() > this.handlingWindow.end &&
    this.status === "active"
  ) {
    this.status = "expired";
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

// Static method to find active donations by location
donationSchema.statics.findActiveByLocation = function (
  lat,
  lng,
  maxDistance = 50
) {
  return this.find({
    status: "active",
    "location.lat": {
      $gte: lat - maxDistance / 111,
      $lte: lat + maxDistance / 111,
    },
    "location.lng": {
      $gte: lng - maxDistance / (111 * Math.cos((lat * Math.PI) / 180)),
      $lte: lng + maxDistance / (111 * Math.cos((lat * Math.PI) / 180)),
    },
  }).populate("donor", "name contactInfo");
};

// Static method to find donations needing matching
donationSchema.statics.findNeedMatching = function () {
  return this.find({
    status: "active",
    $or: [
      { matchedRecipients: { $size: 0 } },
      {
        matchedRecipients: {
          $not: {
            $elemMatch: { status: { $in: ["accepted", "offered"] } },
          },
        },
      },
    ],
  });
};

// Instance method to check if donation is expiring soon
donationSchema.methods.isExpiringSoon = function (hours = 4) {
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

module.exports = mongoose.model("Donation", donationSchema);
