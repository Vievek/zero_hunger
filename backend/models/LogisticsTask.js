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

  // Enhanced route information
  pickupLocation: {
    address: String,
    lat: Number,
    lng: Number,
    instructions: String, // Specific pickup instructions
  },
  dropoffLocation: {
    address: String,
    lat: Number,
    lng: Number,
    contactPerson: String, // Recipient contact person
    phone: String, // Recipient contact phone
  },

  // Enhanced route optimization
  optimizedRoute: {
    waypoints: [
      {
        sequence: Number,
        address: String,
        lat: Number,
        lng: Number,
        type: String, // pickup/dropoff
        taskId: mongoose.Schema.Types.ObjectId,
        urgency: String,
      },
    ],
    totalDistance: Number, // meters
    estimatedDuration: Number, // seconds
    estimatedDurationInTraffic: Number, // seconds with traffic
    polyline: String, // Google Maps polyline
    trafficConditions: String, // heavy, moderate, light, smooth
    fuelEstimate: Number, // Estimated fuel consumption
  },

  // Enhanced timing with urgency
  urgency: {
    type: String,
    enum: ["critical", "high", "normal"],
    default: "normal",
  },
  scheduledPickupTime: Date,
  actualPickupTime: Date,
  actualDeliveryTime: Date,
  estimatedDeliveryTime: Date, // Dynamic ETA based on traffic

  // Multi-stop route (for volunteers with multiple tasks)
  routeSequence: Number,

  // Task metadata
  priority: {
    type: Number,
    default: 1,
    min: 1,
    max: 10,
  },
  specialInstructions: String,
  requiredEquipment: [String], // e.g., ["cooler", "dolly"]

  // Performance tracking
  volunteerRating: {
    type: Number,
    min: 1,
    max: 5,
  },
  volunteerFeedback: String,
  completionTime: Number, // Actual time taken in seconds

  // Safety and compliance
  safetyChecklist: [
    {
      item: String,
      completed: Boolean,
      timestamp: Date,
    },
  ],

  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

// Indexes for better performance
taskSchema.index({ volunteer: 1, status: 1 });
taskSchema.index({ status: 1, urgency: -1 });
taskSchema.index({ "pickupLocation.lat": 1, "pickupLocation.lng": 1 });
taskSchema.index({ scheduledPickupTime: 1 });

// Virtual for task duration
taskSchema.virtual("duration").get(function () {
  if (this.actualPickupTime && this.actualDeliveryTime) {
    return (this.actualDeliveryTime - this.actualPickupTime) / 1000; // seconds
  }
  return null;
});

// Pre-save middleware to update timestamps and calculated fields
taskSchema.pre("save", function (next) {
  this.updatedAt = Date.now();

  // Calculate completion time when delivered
  if (
    this.status === "delivered" &&
    this.actualPickupTime &&
    this.actualDeliveryTime
  ) {
    this.completionTime =
      (this.actualDeliveryTime - this.actualPickupTime) / 1000;
  }

  // Update estimated delivery time based on traffic
  if (
    this.optimizedRoute?.estimatedDurationInTraffic &&
    this.actualPickupTime
  ) {
    this.estimatedDeliveryTime = new Date(
      this.actualPickupTime.getTime() +
        this.optimizedRoute.estimatedDurationInTraffic * 1000
    );
  }

  next();
});

// Static method to find tasks by volunteer and status
taskSchema.statics.findByVolunteerAndStatus = function (volunteerId, status) {
  return this.find({ volunteer: volunteerId, status: status })
    .populate("donation")
    .sort({ priority: -1, createdAt: 1 });
};

// Static method to find urgent tasks
taskSchema.statics.findUrgentTasks = function () {
  return this.find({
    status: { $in: ["assigned", "picked_up"] },
    urgency: { $in: ["critical", "high"] },
  })
    .populate("donation volunteer")
    .sort({ urgency: -1, scheduledPickupTime: 1 });
};

// Instance method to check if task is overdue
taskSchema.methods.isOverdue = function () {
  if (this.estimatedDeliveryTime && this.status !== "delivered") {
    return new Date() > this.estimatedDeliveryTime;
  }
  return false;
};

// Instance method to get task progress percentage
taskSchema.methods.getProgress = function () {
  const statusProgress = {
    pending: 0,
    assigned: 25,
    picked_up: 50,
    in_transit: 75,
    delivered: 100,
    cancelled: 0,
  };
  return statusProgress[this.status] || 0;
};

module.exports = mongoose.model("LogisticsTask", taskSchema);
