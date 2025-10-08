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
    ],
    default: "pending",
  },

  // Food details
  images: [String],
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

  // Location
  pickupAddress: String,
  location: {
    lat: Number,
    lng: Number,
  },

  // AI Analysis results
  aiAnalysis: {
    foodTypes: [String],
    freshnessScore: Number,
    safetyWarnings: [String],
    suggestedHandling: String,
    confidenceScore: Number,
  },

  // Matching
  matchedRecipients: [
    {
      recipient: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
      matchScore: Number,
      status: {
        type: String,
        enum: ["offered", "accepted", "declined"],
        default: "offered",
      },
      respondedAt: Date,
    },
  ],

  acceptedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  assignedVolunteer: { type: mongoose.Schema.Types.ObjectId, ref: "User" },

  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Donation", donationSchema);
