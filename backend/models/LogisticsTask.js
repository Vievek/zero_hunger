const mongoose = require("mongoose");

const taskSchema = new mongoose.Schema({
  donation: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Donation",
    required: true,
  },
  volunteer: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
  },
  status: {
    type: String,
    enum: [
      "pending",
      "assigned",
      "picked_up",
      "in_transit",
      "delivered",
      "cancelled",
    ],
    default: "pending",
  },

  // Route information
  pickupLocation: {
    address: String,
    lat: Number,
    lng: Number,
  },
  dropoffLocation: {
    address: String,
    lat: Number,
    lng: Number,
  },

  // Route optimization
  optimizedRoute: {
    waypoints: [
      {
        sequence: Number,
        address: String,
        lat: Number,
        lng: Number,
        type: String, // pickup/dropoff
      },
    ],
    totalDistance: Number, // meters
    estimatedDuration: Number, // seconds
    polyline: String, // Google Maps polyline
  },

  // Timing
  scheduledPickupTime: Date,
  actualPickupTime: Date,
  actualDeliveryTime: Date,

  // Multi-stop route (for volunteers with multiple tasks)
  routeSequence: Number,

  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("LogisticsTask", taskSchema);
