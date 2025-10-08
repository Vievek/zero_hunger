const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true,
  },
  type: {
    type: String,
    enum: ["donation_offer", "task_assigned", "status_update", "system"],
    required: true,
  },
  title: String,
  message: {
    type: String,
    required: true,
  },
  data: mongoose.Schema.Types.Mixed,
  read: {
    type: Boolean,
    default: false,
  },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Notification", notificationSchema);
