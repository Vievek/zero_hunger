const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    password: { type: String },
    role: {
      type: String,
      enum: ["donor", "recipient", "volunteer", "admin"],
      required: true,
    },
    googleId: { type: String },
    profileCompleted: { type: Boolean, default: false },

    // Role-specific fields
    donorDetails: {
      businessName: String,
      businessType: String,
      businessAddress: String,
      foodTypes: [String],
      registrationNumber: String,
      isActive: { type: Boolean, default: true },
    },
    recipientDetails: {
      organizationName: {
        type: String,
        required: function () {
          return this.role === "recipient";
        },
      },
      organizationType: {
        type: String,
        enum: [
          "shelter",
          "community_kitchen",
          "food_bank",
          "religious",
          "other",
        ],
        required: function () {
          return this.role === "recipient";
        },
      },
      address: String,
      location: {
        lat: Number,
        lng: Number,
      },
      capacity: {
        type: Number,
        default: 50,
        min: 1,
        required: function () {
          return this.role === "recipient";
        },
      },
      dietaryRestrictions: [String],
      preferredFoodTypes: [String],
      verificationStatus: {
        type: String,
        enum: ["pending", "verified", "rejected"],
        default: "pending",
      },
      verifiedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
      verificationNotes: String,
      operatingHours: {
        start: String,
        end: String,
      },
      isActive: { type: Boolean, default: true },
      currentLoad: { type: Number, default: 0 }, // Track current donations
    },
    volunteerDetails: {
      vehicleType: {
        type: String,
        enum: ["bike", "car", "van", "truck", "none"],
        default: "none",
      },
      contactNumber: String,
      availability: [
        {
          day: String,
          startTime: String,
          endTime: String,
        },
      ],
      currentLocation: {
        lat: Number,
        lng: Number,
      },
      lastLocationUpdate: Date,
      isAvailable: { type: Boolean, default: true },
      maxDistance: { type: Number, default: 20 },
      capacity: { type: Number, default: 10 },
      currentTasks: { type: Number, default: 0 }, // Track current tasks
      volunteerMetrics: {
        completedDeliveries: { type: Number, default: 0 },
        totalDistance: { type: Number, default: 0 }, // in km
        averageRating: { type: Number, default: 0 },
        lastDelivery: Date,
        reliabilityScore: { type: Number, default: 100 }, // percentage
      },
    },

    contactInfo: {
      phone: String,
      address: String,
      location: {
        lat: Number,
        lng: Number,
      },
    },

    // Status and tracking
    status: {
      type: String,
      enum: ["active", "suspended", "inactive"],
      default: "active",
    },
    lastLogin: Date,
    fcmToken: String, // For push notifications
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

userSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();

  if (this.password) {
    this.password = await bcrypt.hash(this.password, 12);
  }
  next();
});

userSchema.methods.correctPassword = async function (
  candidatePassword,
  userPassword
) {
  if (!candidatePassword || !userPassword) return false;
  return await bcrypt.compare(candidatePassword, userPassword);
};

// NEW: Instance method to check if recipient can accept more donations
userSchema.methods.canAcceptDonation = async function (donationQuantity = 1) {
  if (this.role !== "recipient") return false;

  const Donation = mongoose.model("Donation");
  const currentLoad = await Donation.countDocuments({
    acceptedBy: this._id,
    status: { $in: ["active", "matched", "scheduled", "picked_up"] },
  });

  const capacity = this.recipientDetails?.capacity || 50;
  return currentLoad + donationQuantity <= capacity;
};

// NEW: Instance method to get current load
userSchema.methods.getCurrentLoad = async function () {
  if (this.role !== "recipient") return 0;

  const Donation = mongoose.model("Donation");
  return await Donation.countDocuments({
    acceptedBy: this._id,
    status: { $in: ["active", "matched", "scheduled", "picked_up"] },
  });
};

// NEW: Instance method to check if volunteer can accept more tasks
userSchema.methods.canAcceptTask = async function (taskSize = "medium") {
  if (this.role !== "volunteer") return false;

  try {
    const LogisticsTask = mongoose.model("LogisticsTask");
    const currentTasks = await LogisticsTask.countDocuments({
      volunteer: this._id,
      status: { $in: ["assigned", "picked_up", "in_transit"] },
    });

    const volunteerCapacity = this.volunteerDetails?.capacity || 5;

    // Consider task size in capacity calculation
    const sizeMultipliers = {
      small: 0.5,
      medium: 1,
      large: 2,
      xlarge: 3,
    };

    const taskWeight = sizeMultipliers[taskSize] || 1;
    const effectiveLoad = currentTasks + taskWeight;

    return effectiveLoad <= volunteerCapacity;
  } catch (error) {
    console.error("Capacity check error:", error);
    return false;
  }
};

// NEW: Instance method to get volunteer current tasks
userSchema.methods.getCurrentTasks = async function () {
  if (this.role !== "volunteer") return 0;

  try {
    const LogisticsTask = mongoose.model("LogisticsTask");
    return await LogisticsTask.countDocuments({
      volunteer: this._id,
      status: { $in: ["assigned", "picked_up", "in_transit"] },
    });
  } catch (error) {
    console.error("Current tasks count error:", error);
    return 0;
  }
};

// NEW: Instance method to get volunteer performance metrics
userSchema.methods.getPerformanceMetrics = async function () {
  if (this.role !== "volunteer") return null;

  try {
    const LogisticsTask = mongoose.model("LogisticsTask");

    const metrics = await LogisticsTask.aggregate([
      {
        $match: {
          volunteer: this._id,
          status: { $in: ["delivered", "cancelled"] },
        },
      },
      {
        $group: {
          _id: "$status",
          count: { $sum: 1 },
          totalDuration: {
            $sum: {
              $cond: [
                { $eq: ["$status", "delivered"] },
                { $subtract: ["$actualDeliveryTime", "$actualPickupTime"] },
                0,
              ],
            },
          },
          totalDistance: {
            $sum: {
              $cond: [
                { $eq: ["$status", "delivered"] },
                "$optimizedRoute.totalDistance",
                0,
              ],
            },
          },
        },
      },
    ]);

    const delivered = metrics.find((m) => m._id === "delivered") || {
      count: 0,
      totalDuration: 0,
      totalDistance: 0,
    };
    const cancelled = metrics.find((m) => m._id === "cancelled") || {
      count: 0,
    };

    const totalTasks = delivered.count + cancelled.count;
    const completionRate =
      totalTasks > 0 ? (delivered.count / totalTasks) * 100 : 0;
    const avgDuration =
      delivered.count > 0 ? delivered.totalDuration / delivered.count : 0;
    const totalDistanceKm =
      delivered.totalDistance > 0 ? delivered.totalDistance / 1000 : 0;

    // Calculate reliability score (completion rate minus cancellation penalty)
    const cancellationPenalty = cancelled.count * 5; // 5% penalty per cancellation
    const reliabilityScore = Math.max(0, completionRate - cancellationPenalty);

    return {
      totalTasks,
      completed: delivered.count,
      cancelled: cancelled.count,
      completionRate: Math.round(completionRate),
      averageDuration: Math.round(avgDuration / 60000), // Convert to minutes
      totalDistance: Math.round(totalDistanceKm * 100) / 100, // Round to 2 decimal places
      reliability:
        completionRate > 90
          ? "excellent"
          : completionRate > 80
          ? "high"
          : completionRate > 60
          ? "medium"
          : "low",
      reliabilityScore: Math.round(reliabilityScore),
    };
  } catch (error) {
    console.error("Performance metrics error:", error);
    return null;
  }
};

// NEW: Instance method to update volunteer metrics after task completion
userSchema.methods.updateVolunteerMetrics = async function (task) {
  if (this.role !== "volunteer") return;

  try {
    const metrics = await this.getPerformanceMetrics();

    if (metrics) {
      this.volunteerDetails.volunteerMetrics = {
        completedDeliveries: metrics.completed,
        totalDistance: metrics.totalDistance,
        averageRating:
          this.volunteerDetails.volunteerMetrics?.averageRating || 0,
        lastDelivery: new Date(),
        reliabilityScore: metrics.reliabilityScore,
      };

      await this.save();
    }
  } catch (error) {
    console.error("Update volunteer metrics error:", error);
  }
};

// NEW: Instance method to check if volunteer is within range of location
userSchema.methods.isWithinRange = function (location, maxDistanceKm = 5) {
  if (!this.volunteerDetails?.currentLocation || !location) return false;

  const volunteerLocation = this.volunteerDetails.currentLocation;
  return calculateDistance(volunteerLocation, location) <= maxDistanceKm;
};

// NEW: Instance method to get volunteer availability status
userSchema.methods.getAvailabilityStatus = function () {
  if (this.role !== "volunteer") return "not_volunteer";

  if (!this.volunteerDetails?.isAvailable) return "unavailable";

  // Check if volunteer has set availability hours
  if (
    this.volunteerDetails.availability &&
    this.volunteerDetails.availability.length > 0
  ) {
    const now = new Date();
    const currentDay = now
      .toLocaleString("en-us", { weekday: "long" })
      .toLowerCase();
    const currentTime = now.toTimeString().slice(0, 5); // HH:MM format

    const todayAvailability = this.volunteerDetails.availability.find(
      (slot) => slot.day.toLowerCase() === currentDay
    );

    if (todayAvailability) {
      return currentTime >= todayAvailability.startTime &&
        currentTime <= todayAvailability.endTime
        ? "available"
        : "off_hours";
    }
  }

  return this.volunteerDetails.isAvailable ? "available" : "unavailable";
};

// Virtual for donor stats
userSchema.virtual("donorStats").get(function () {
  if (this.role !== "donor") return null;

  return {
    businessName: this.donorDetails?.businessName,
    businessType: this.donorDetails?.businessType,
    isActive: this.donorDetails?.isActive !== false,
  };
});

// Virtual for recipient stats
userSchema.virtual("recipientStats").get(function () {
  if (this.role !== "recipient") return null;

  return {
    organizationName: this.recipientDetails?.organizationName,
    organizationType: this.recipientDetails?.organizationType,
    capacity: this.recipientDetails?.capacity || 50,
    currentLoad: this.recipientDetails?.currentLoad || 0,
    availableCapacity: Math.max(
      0,
      (this.recipientDetails?.capacity || 50) -
        (this.recipientDetails?.currentLoad || 0)
    ),
    verificationStatus: this.recipientDetails?.verificationStatus || "pending",
    isActive: this.recipientDetails?.isActive !== false,
  };
});

// Virtual for volunteer stats
userSchema.virtual("volunteerStats").get(function () {
  if (this.role !== "volunteer") return null;

  return {
    vehicleType: this.volunteerDetails?.vehicleType || "none",
    isAvailable: this.volunteerDetails?.isAvailable !== false,
    availabilityStatus: this.getAvailabilityStatus(),
    capacity: this.volunteerDetails?.capacity || 10,
    currentTasks: this.volunteerDetails?.currentTasks || 0,
    availableCapacity: Math.max(
      0,
      (this.volunteerDetails?.capacity || 10) -
        (this.volunteerDetails?.currentTasks || 0)
    ),
    maxDistance: this.volunteerDetails?.maxDistance || 20,
    metrics: this.volunteerDetails?.volunteerMetrics || {
      completedDeliveries: 0,
      totalDistance: 0,
      averageRating: 0,
      lastDelivery: null,
      reliabilityScore: 100,
    },
  };
});

// Helper function to calculate distance (Haversine formula)
function calculateDistance(point1, point2) {
  if (!point1.lat || !point1.lng || !point2.lat || !point2.lng) {
    return Infinity; // Return large distance if coordinates are missing
  }

  const R = 6371; // Earth's radius in km
  const dLat = toRad(point2.lat - point1.lat);
  const dLon = toRad(point2.lng - point1.lng);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(point1.lat)) *
      Math.cos(toRad(point2.lat)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(degrees) {
  return degrees * (Math.PI / 180);
}

// Indexes for better performance

userSchema.index({ role: 1 });
userSchema.index({ "recipientDetails.verificationStatus": 1 });
userSchema.index({ "volunteerDetails.isAvailable": 1 });
userSchema.index({ "donorDetails.isActive": 1 });
userSchema.index({ "volunteerDetails.currentLocation": "2dsphere" });
userSchema.index({ "recipientDetails.location": "2dsphere" });
userSchema.index({ "contactInfo.location": "2dsphere" });

module.exports = mongoose.model("User", userSchema);
