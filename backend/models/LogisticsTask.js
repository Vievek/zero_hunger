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

  // Cancellation fields
  cancellationNotes: String,
  cancelledAt: Date,

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
  if (this.status === "delivered" || this.status === "cancelled") {
    return false;
  }

  if (this.estimatedDeliveryTime) {
    const now = new Date();
    const overdueTime = now - this.estimatedDeliveryTime;

    // Consider 15-minute grace period
    return overdueTime > 15 * 60 * 1000;
  }

  return false;
};

// Instance method to get task progress percentage
taskSchema.methods.getProgress = function () {
  const statusProgress = {
    pending: 0,
    assigned: 20,
    picked_up: 50,
    in_transit: 80,
    delivered: 100,
    cancelled: 0,
  };

  let progress = statusProgress[this.status] || 0;

  // Add time-based progress for in-transit tasks
  if (this.status === "in_transit" && this.estimatedDeliveryTime) {
    const now = new Date();
    const totalTime = this.estimatedDeliveryTime - this.actualPickupTime;
    const elapsedTime = now - this.actualPickupTime;

    if (totalTime > 0 && elapsedTime > 0) {
      const timeProgress = (elapsedTime / totalTime) * 30; // Max 30% from time
      progress = Math.min(80 + timeProgress, 95); // Cap at 95% until delivered
    }
  }

  return Math.round(progress);
};

// NEW: Calculate task size based on donation
taskSchema.methods.getTaskSize = async function () {
  try {
    await this.populate("donation");
    const donation = this.donation;

    if (!donation || !donation.quantity) return "medium";

    const quantity = donation.quantity.amount || 0;

    if (quantity <= 5) return "small";
    if (quantity <= 20) return "medium";
    if (quantity <= 50) return "large";
    return "xlarge";
  } catch (error) {
    return "medium";
  }
};

// NEW: Check if volunteer can handle this task
taskSchema.methods.canVolunteerHandle = async function (volunteerId) {
  try {
    const User = mongoose.model("User");
    const volunteer = await User.findById(volunteerId);

    if (!volunteer || volunteer.role !== "volunteer") {
      return false;
    }

    const taskSize = await this.getTaskSize();
    return await volunteer.canAcceptTask(taskSize);
  } catch (error) {
    console.error("Volunteer capability check error:", error);
    return false;
  }
};

// NEW: Update ETA based on current conditions
taskSchema.methods.updateETA = async function () {
  if (this.status !== "in_transit" || !this.actualPickupTime) {
    return;
  }

  try {
    const routeOptimizationService = require("../services/routeOptimizationService");

    const currentRoute = await routeOptimizationService.getRealTimeRoute(
      this.pickupLocation,
      this.dropoffLocation
    );

    if (currentRoute && currentRoute.estimatedDuration) {
      this.estimatedDeliveryTime = new Date(
        this.actualPickupTime.getTime() + currentRoute.estimatedDuration * 1000
      );

      if (this.optimizedRoute) {
        this.optimizedRoute.estimatedDuration = currentRoute.estimatedDuration;
        this.optimizedRoute.trafficConditions = currentRoute.trafficConditions;
      }

      await this.save();
      console.log(`🔄 Updated ETA for task ${this._id}`);
    }
  } catch (error) {
    console.error("ETA update error:", error);
  }
};

module.exports = mongoose.model("LogisticsTask", taskSchema);
