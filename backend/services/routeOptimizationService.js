const axios = require("axios");
const User = require("../models/User");
const LogisticsTask = require("../models/LogisticsTask");
const trafficService = require("./trafficService");

class RouteOptimizationService {
  constructor() {
    this.googleMapsKey = process.env.GOOGLE_MAPS_API_KEY;
    this.useRealTimeTraffic = !!this.googleMapsKey;
    this.assignmentCache = new Map();
    this.cacheTimeout = 2 * 60 * 1000; // 2 minutes
  }

  // SIMPLIFIED: Rule-based volunteer assignment
  async findOptimalVolunteer(
    pickupLocation,
    availableVolunteers,
    urgency = "normal"
  ) {
    const cacheKey = `assignment_${pickupLocation.lat}_${pickupLocation.lng}_${availableVolunteers.length}`;
    const cached = this.assignmentCache.get(cacheKey);

    if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
      return cached.result;
    }

    try {
      console.log(
        `🔍 Assigning volunteer from ${availableVolunteers.length} candidates`
      );

      if (availableVolunteers.length === 0) {
        throw new Error("No available volunteers");
      }

      if (availableVolunteers.length === 1) {
        const volunteer = availableVolunteers[0];
        const canAccept = await volunteer.canAcceptTask();
        return canAccept ? volunteer : null;
      }

      // Enhanced scoring with practical factors
      const scoredVolunteers = await Promise.all(
        availableVolunteers.map(async (volunteer) => {
          try {
            const score = await this.calculatePracticalScore(
              volunteer,
              pickupLocation,
              urgency
            );
            return { volunteer, score };
          } catch (error) {
            console.error(`Error scoring volunteer ${volunteer._id}:`, error);
            return { volunteer, score: 0 };
          }
        })
      );

      // Filter out volunteers who can't accept tasks
      const validVolunteers = [];
      for (const { volunteer, score } of scoredVolunteers) {
        const canAccept = await volunteer.canAcceptTask();
        if (canAccept && score > 0) {
          validVolunteers.push({ volunteer, score });
        }
      }

      if (validVolunteers.length === 0) {
        console.log("⛔ No suitable volunteers found after capacity check");
        return null;
      }

      // Sort by score and return best
      validVolunteers.sort((a, b) => b.score - a.score);
      const bestVolunteer = validVolunteers[0].volunteer;

      console.log(
        `✅ Assigned volunteer ${
          bestVolunteer._id
        } with score ${validVolunteers[0].score.toFixed(2)}`
      );

      // Cache result
      this.assignmentCache.set(cacheKey, {
        result: bestVolunteer,
        timestamp: Date.now(),
      });

      return bestVolunteer;
    } catch (error) {
      console.error("Volunteer assignment error:", error);
      return null;
    }
  }

  // PRACTICAL scoring based on real-world factors
  async calculatePracticalScore(volunteer, pickupLocation, urgency) {
    let score = 0;
    const maxScore = 100;

    try {
      // 1. PROXIMITY (40 points max)
      const proximityScore = await this.calculateProximityScore(
        volunteer,
        pickupLocation
      );
      score += proximityScore * 40;

      // 2. AVAILABILITY & CAPACITY (30 points max)
      const capacityScore = await this.calculateCapacityScore(volunteer);
      score += capacityScore * 30;

      // 3. VEHICLE SUITABILITY (20 points max)
      const vehicleScore = this.calculateVehicleScore(volunteer);
      score += vehicleScore * 20;

      // 4. URGENCY BONUS (10 points max)
      const urgencyBonus = this.calculateUrgencyBonus(urgency);
      score += urgencyBonus;

      // 5. RELIABILITY BONUS (historical performance)
      const reliabilityBonus = await this.calculateReliabilityBonus(volunteer);
      score += reliabilityBonus;

      console.log(
        `📊 Volunteer ${
          volunteer._id
        } scores: proximity=${proximityScore.toFixed(
          2
        )}, capacity=${capacityScore.toFixed(
          2
        )}, vehicle=${vehicleScore.toFixed(2)}, total=${score.toFixed(2)}`
      );

      return Math.min(score, maxScore);
    } catch (error) {
      console.error(
        `Score calculation error for volunteer ${volunteer._id}:`,
        error
      );
      return 0;
    }
  }

  // REAL proximity calculation with fallback
  async calculateProximityScore(volunteer, pickupLocation) {
    try {
      const volunteerLocation =
        volunteer.volunteerDetails?.currentLocation ||
        volunteer.contactInfo?.location;

      if (!volunteerLocation || !pickupLocation) {
        return 0.5; // Neutral score if locations missing
      }

      // Use real distance calculation if API available, else use simple distance
      let distance;
      if (this.useRealTimeTraffic) {
        const distanceData = await this.calculateRealDistance(
          volunteerLocation,
          pickupLocation
        );
        distance = distanceData.distance;
      } else {
        distance = this.calculateSimpleDistance(
          volunteerLocation,
          pickupLocation
        );
      }

      // Convert to score: closer = higher score
      // Assume 50km max distance for scoring
      const maxDistance = 50000; // meters
      const distanceScore = Math.max(0, 1 - distance / maxDistance);

      return Math.min(distanceScore, 1.0);
    } catch (error) {
      console.error("Proximity calculation error:", error);
      return 0.3; // Default low score
    }
  }

  // REAL distance calculation using Google Distance Matrix
  async calculateRealDistance(origin, destination) {
    try {
      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/distancematrix/json`,
        {
          params: {
            origins: `${origin.lat},${origin.lng}`,
            destinations: `${destination.lat},${destination.lng}`,
            key: this.googleMapsKey,
          },
          timeout: 5000, // 5 second timeout
        }
      );

      if (response.data.rows[0]?.elements[0]?.status === "OK") {
        const element = response.data.rows[0].elements[0];
        return {
          distance: element.distance.value, // meters
          duration: element.duration.value, // seconds
          status: "success",
        };
      }
    } catch (error) {
      console.error("Real distance API error:", error.message);
    }

    // Fallback to simple distance
    const simpleDistance = this.calculateSimpleDistance(origin, destination);
    return {
      distance: simpleDistance * 100000, // Convert to approximate meters
      duration: simpleDistance * 3600, // Convert to approximate seconds
      status: "fallback",
    };
  }

  calculateSimpleDistance(loc1, loc2) {
    // Haversine distance in kilometers
    const R = 6371; // Earth's radius in km
    const dLat = this.toRad(loc2.lat - loc1.lat);
    const dLon = this.toRad(loc2.lng - loc1.lng);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(loc1.lat)) *
        Math.cos(this.toRad(loc2.lat)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  toRad(degrees) {
    return degrees * (Math.PI / 180);
  }

  // REAL capacity scoring
  async calculateCapacityScore(volunteer) {
    try {
      const currentTasks = await LogisticsTask.countDocuments({
        volunteer: volunteer._id,
        status: { $in: ["assigned", "picked_up", "in_transit"] },
      });

      const volunteerCapacity = volunteer.volunteerDetails?.capacity || 5;
      const utilization = currentTasks / volunteerCapacity;

      // Score based on utilization
      if (utilization >= 1.0) return 0; // Full
      if (utilization >= 0.8) return 0.2; // Very busy
      if (utilization >= 0.6) return 0.5; // Busy
      if (utilization >= 0.4) return 0.7; // Moderate
      if (utilization >= 0.2) return 0.9; // Light
      return 1.0; // Available
    } catch (error) {
      console.error("Capacity calculation error:", error);
      return 0.5;
    }
  }

  // ENHANCED vehicle scoring
  calculateVehicleScore(volunteer) {
    const vehicle = volunteer.volunteerDetails?.vehicleType || "none";

    const vehicleScores = {
      truck: 1.0, // Best for large donations
      van: 0.9, // Good for medium donations
      car: 0.7, // Standard
      bike: 0.4, // Limited capacity
      none: 0.2, // Walking
    };

    return vehicleScores[vehicle] || 0.5;
  }

  calculateUrgencyBonus(urgency) {
    const urgencyScores = {
      critical: 10,
      high: 6,
      normal: 0,
    };
    return urgencyScores[urgency] || 0;
  }

  async calculateReliabilityBonus(volunteer) {
    try {
      // Calculate based on historical task completion
      const completedTasks = await LogisticsTask.countDocuments({
        volunteer: volunteer._id,
        status: "delivered",
      });

      const totalTasks = await LogisticsTask.countDocuments({
        volunteer: volunteer._id,
      });

      if (totalTasks === 0) return 2; // New volunteer bonus

      const completionRate = completedTasks / totalTasks;
      return completionRate * 5; // Max 5 points for reliability
    } catch (error) {
      return 0;
    }
  }

  // SIMPLIFIED route optimization
  async optimizeMultiStopRoute(tasks) {
    try {
      if (tasks.length <= 1) {
        return this.createBasicRoute(tasks);
      }

      // Group by task and use simple optimization
      const optimizedTasks = this.optimizeTaskSequence(tasks);

      if (this.useRealTimeTraffic) {
        return await this.enhanceRouteWithTraffic(optimizedTasks);
      } else {
        return this.createBasicRoute(optimizedTasks);
      }
    } catch (error) {
      console.error("Route optimization error:", error);
      return this.createBasicRoute(tasks);
    }
  }

  // SIMPLE task sequence optimization (Nearest Neighbor)
  optimizeTaskSequence(tasks) {
    if (tasks.length <= 1) return tasks;

    const optimized = [tasks[0]];
    const remaining = [...tasks.slice(1)];
    let currentLocation = tasks[0].pickupLocation;

    while (remaining.length > 0) {
      let nearestIndex = 0;
      let nearestDistance = Infinity;

      for (let i = 0; i < remaining.length; i++) {
        const distance = this.calculateSimpleDistance(
          currentLocation,
          remaining[i].pickupLocation
        );
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestIndex = i;
        }
      }

      const nearestTask = remaining[nearestIndex];
      optimized.push(nearestTask);
      currentLocation = nearestTask.dropoffLocation;
      remaining.splice(nearestIndex, 1);
    }

    return optimized;
  }

  async enhanceRouteWithTraffic(tasks) {
    try {
      if (tasks.length === 0) return this.createBasicRoute(tasks);

      const waypoints = tasks.map((task) => ({
        location: task.pickupLocation,
        stopover: true,
      }));

      const response = await axios.post(
        `https://routes.googleapis.com/directions/v2:computeRoutes`,
        {
          origin: waypoints[0].location,
          destination: waypoints[waypoints.length - 1].location,
          intermediates: waypoints.slice(1, -1),
          travelMode: "DRIVE",
          optimizeWaypointOrder: true,
          routingPreference: "TRAFFIC_AWARE",
        },
        {
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": this.googleMapsKey,
            "X-Goog-FieldMask":
              "routes.optimizedIntermediateWaypointIndex,routes.duration,routes.distanceMeters,routes.polyline",
          },
          timeout: 10000,
        }
      );

      if (response.data.routes && response.data.routes.length > 0) {
        const route = response.data.routes[0];
        return {
          waypoints: this.applyOptimizedOrder(
            tasks,
            route.optimizedIntermediateWaypointIndex
          ),
          totalDistance: route.distanceMeters,
          estimatedDuration: route.duration,
          polyline: route.polyline,
          optimized: true,
          trafficAware: true,
        };
      }
    } catch (error) {
      console.error("Traffic-enhanced routing failed:", error.message);
    }

    return this.createBasicRoute(tasks);
  }

  applyOptimizedOrder(tasks, optimizedOrder) {
    if (!optimizedOrder || optimizedOrder.length !== tasks.length) {
      return tasks.map((task, index) => ({ ...task, sequence: index }));
    }

    return optimizedOrder.map((originalIndex, sequence) => ({
      ...tasks[originalIndex],
      sequence: sequence,
    }));
  }

  createBasicRoute(tasks) {
    const totalDistance = tasks.reduce((sum, task) => {
      if (task.pickupLocation && task.dropoffLocation) {
        return (
          sum +
          this.calculateSimpleDistance(
            task.pickupLocation,
            task.dropoffLocation
          ) *
            1000
        );
      }
      return sum;
    }, 0);

    const estimatedDuration = (totalDistance / 1000) * 120; // Assume 50km/h average

    return {
      waypoints: tasks.map((task, index) => ({ ...task, sequence: index })),
      totalDistance: totalDistance,
      estimatedDuration: estimatedDuration,
      polyline: null,
      optimized: false,
      trafficAware: false,
    };
  }

  // Clear cache (useful for testing)
  clearCache() {
    this.assignmentCache.clear();
  }
}

module.exports = new RouteOptimizationService();
