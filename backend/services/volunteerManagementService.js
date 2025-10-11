const User = require("../models/User");
const LogisticsTask = require("../models/LogisticsTask");

class VolunteerManagementService {
  constructor() {
    this.volunteerCache = new Map();
    this.cacheTimeout = 5 * 60 * 1000; // 5 minutes
  }

  // Get available volunteers with proper filtering
  async getAvailableVolunteers(centerPoint, maxDistance = 50) {
    const cacheKey = `volunteers_${centerPoint.lat}_${centerPoint.lng}_${maxDistance}`;
    const cached = this.volunteerCache.get(cacheKey);

    if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
      return cached.volunteers;
    }

    try {
      console.log(`🔍 Finding available volunteers within ${maxDistance}km`);

      const volunteers = await User.find({
        role: "volunteer",
        "volunteerDetails.isAvailable": true,
        status: "active",
      })
        .select("name email volunteerDetails contactInfo")
        .lean();

      // Filter by distance if center point provided
      let filteredVolunteers = volunteers;
      if (centerPoint) {
        filteredVolunteers = volunteers.filter((volunteer) => {
          const volunteerLocation =
            volunteer.volunteerDetails?.currentLocation ||
            volunteer.contactInfo?.location;
          if (!volunteerLocation) return false;

          const distance = this.calculateDistance(
            centerPoint,
            volunteerLocation
          );
          return distance <= maxDistance;
        });
      }

      console.log(`✅ Found ${filteredVolunteers.length} available volunteers`);

      // Cache result
      this.volunteerCache.set(cacheKey, {
        volunteers: filteredVolunteers,
        timestamp: Date.now(),
      });

      return filteredVolunteers;
    } catch (error) {
      console.error("Volunteer search error:", error);
      return [];
    }
  }

  // Calculate distance between two points (Haversine formula)
  calculateDistance(point1, point2) {
    const R = 6371; // Earth's radius in km
    const dLat = this.toRad(point2.lat - point1.lat);
    const dLon = this.toRad(point2.lng - point1.lng);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(point1.lat)) *
        Math.cos(this.toRad(point2.lat)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  toRad(degrees) {
    return degrees * (Math.PI / 180);
  }

  // Update volunteer availability
  async updateVolunteerAvailability(volunteerId, isAvailable, reason = "") {
    try {
      const volunteer = await User.findByIdAndUpdate(
        volunteerId,
        {
          "volunteerDetails.isAvailable": isAvailable,
          "volunteerDetails.lastStatusUpdate": new Date(),
          "volunteerDetails.availabilityReason": reason,
        },
        { new: true }
      );

      if (volunteer) {
        console.log(
          `✅ Volunteer ${volunteerId} availability updated to: ${isAvailable}`
        );

        // Clear cache to reflect changes
        this.clearCache();

        return volunteer;
      }
    } catch (error) {
      console.error("Volunteer availability update error:", error);
      throw error;
    }
  }

  // Get volunteer performance report
  async getVolunteerPerformanceReport(volunteerId, period = "month") {
    try {
      const volunteer = await User.findById(volunteerId);
      if (!volunteer || volunteer.role !== "volunteer") {
        throw new Error("Volunteer not found");
      }

      const dateFilter = this.getDateFilter(period);

      const performanceData = await LogisticsTask.aggregate([
        {
          $match: {
            volunteer: volunteer._id,
            status: { $in: ["delivered", "cancelled"] },
            createdAt: { $gte: dateFilter },
          },
        },
        {
          $group: {
            _id: "$status",
            count: { $sum: 1 },
            totalDistance: { $sum: "$optimizedRoute.totalDistance" },
            totalDuration: {
              $sum: {
                $cond: [
                  { $eq: ["$status", "delivered"] },
                  "$completionTime",
                  0,
                ],
              },
            },
          },
        },
      ]);

      const delivered = performanceData.find((d) => d._id === "delivered") || {
        count: 0,
        totalDistance: 0,
        totalDuration: 0,
      };
      const cancelled = performanceData.find((d) => d._id === "cancelled") || {
        count: 0,
      };

      const totalTasks = delivered.count + cancelled.count;
      const completionRate =
        totalTasks > 0 ? (delivered.count / totalTasks) * 100 : 0;
      const avgDistance =
        delivered.count > 0 ? delivered.totalDistance / delivered.count : 0;
      const avgDuration =
        delivered.count > 0 ? delivered.totalDuration / delivered.count : 0;

      return {
        volunteer: {
          name: volunteer.name,
          vehicle: volunteer.volunteerDetails?.vehicleType,
          capacity: volunteer.volunteerDetails?.capacity,
          isAvailable: volunteer.volunteerDetails?.isAvailable,
        },
        performance: {
          period: period,
          totalTasks: totalTasks,
          completed: delivered.count,
          cancelled: cancelled.count,
          completionRate: Math.round(completionRate),
          averageDistance: Math.round(avgDistance / 1000), // Convert to km
          averageDuration: Math.round(avgDuration / 60), // Convert to minutes
          totalDistance: Math.round(delivered.totalDistance / 1000),
          efficiency: this.calculateEfficiencyScore(
            completionRate,
            avgDuration,
            cancelled.count
          ),
        },
        rating: this.calculateVolunteerRating(
          completionRate,
          cancelled.count,
          totalTasks
        ),
      };
    } catch (error) {
      console.error("Performance report error:", error);
      throw error;
    }
  }

  getDateFilter(period) {
    const now = new Date();
    switch (period) {
      case "week":
        return new Date(now.setDate(now.getDate() - 7));
      case "month":
        return new Date(now.setMonth(now.getMonth() - 1));
      case "quarter":
        return new Date(now.setMonth(now.getMonth() - 3));
      default:
        return new Date(0); // All time
    }
  }

  calculateEfficiencyScore(completionRate, avgDuration, cancellations) {
    let score = completionRate;

    // Penalize for cancellations
    if (cancellations > 0) {
      score -= cancellations * 5;
    }

    // Reward for faster deliveries (assuming 2 hours is average)
    if (avgDuration > 0) {
      const efficiency = (120 / (avgDuration / 60)) * 10; // 2 hours = 120 minutes
      score += Math.min(efficiency, 20); // Max 20 points for speed
    }

    return Math.max(0, Math.round(score));
  }

  calculateVolunteerRating(completionRate, cancellations, totalTasks) {
    if (totalTasks === 0) return "new";

    let baseRating = completionRate / 20; // Convert to 5-star scale

    // Penalize for cancellations
    const cancellationPenalty = (cancellations / totalTasks) * 2;
    baseRating = Math.max(0, baseRating - cancellationPenalty);

    // Convert to star rating
    if (baseRating >= 4.5) return "excellent";
    if (baseRating >= 4.0) return "very-good";
    if (baseRating >= 3.5) return "good";
    if (baseRating >= 3.0) return "satisfactory";
    return "needs-improvement";
  }

  // Clear cache
  clearCache() {
    this.volunteerCache.clear();
  }
}

module.exports = new VolunteerManagementService();
