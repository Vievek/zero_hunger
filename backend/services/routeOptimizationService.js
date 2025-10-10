const axios = require("axios");
const User = require("../models/User");
const LogisticsTask = require("../models/LogisticsTask");
const trafficService = require("./trafficService");

class RouteOptimizationService {
  constructor() {
    this.googleMapsKey = process.env.GOOGLE_MAPS_API_KEY;
    this.useRealTimeTraffic = !!this.googleMapsKey;
  }

  // Enhanced Genetic Algorithm for volunteer assignment with urgency consideration
  async findOptimalVolunteer(
    pickupLocation,
    availableVolunteers,
    urgency = "normal"
  ) {
    if (availableVolunteers.length === 0) {
      throw new Error("No available volunteers");
    }

    if (availableVolunteers.length === 1) {
      return availableVolunteers[0];
    }

    const populationSize = Math.min(20, availableVolunteers.length * 2);
    const generations = 50;
    const mutationRate = 0.1;

    let population = this.initializePopulation(
      availableVolunteers,
      populationSize
    );

    for (let gen = 0; gen < generations; gen++) {
      const fitnessScores = await Promise.all(
        population.map((volunteer) =>
          this.calculateEnhancedFitness(volunteer, pickupLocation, urgency)
        )
      );

      population = this.evolvePopulation(
        population,
        fitnessScores,
        mutationRate,
        availableVolunteers
      );
    }

    // Return best volunteer
    const finalFitness = await Promise.all(
      population.map((volunteer) =>
        this.calculateEnhancedFitness(volunteer, pickupLocation, urgency)
      )
    );
    const bestIndex = finalFitness.indexOf(Math.max(...finalFitness));

    return population[bestIndex];
  }

  async calculateEnhancedFitness(volunteer, pickupLocation, urgency) {
    try {
      const volunteerLocation =
        volunteer.volunteerDetails?.currentLocation ||
        volunteer.contactInfo?.location;

      if (!volunteerLocation) {
        return 0.1; // Low fitness if no location
      }

      // Calculate enhanced distance with traffic consideration
      const distanceData = await this.calculateEnhancedDistance(
        volunteerLocation,
        pickupLocation
      );
      const distance = distanceData.distance;
      const trafficMultiplier = distanceData.trafficMultiplier || 1.0;

      // Vehicle suitability with fuel efficiency
      const vehicleScore = this.calculateEnhancedVehicleSuitability(volunteer);

      // Availability score
      const availabilityScore = volunteer.volunteerDetails?.isAvailable ? 1 : 0;

      // Current workload penalty
      const currentTasks = await LogisticsTask.countDocuments({
        volunteer: volunteer._id,
        status: { $in: ["assigned", "picked_up", "in_transit"] },
      });
      const workloadPenalty = Math.max(0, 1 - currentTasks * 0.2);

      // Urgency multiplier
      const urgencyMultipliers = {
        critical: 1.5, // Perishable foods
        high: 1.3, // Prepared meals
        normal: 1.0, // Non-perishables
      };
      const urgencyScore = urgencyMultipliers[urgency] || 1.0;

      // Fuel efficiency score
      const fuelScore = this.calculateFuelEfficiency(volunteer, distance);

      // Enhanced fitness calculation with traffic consideration
      const distanceScore = 1 / (1 + (distance * trafficMultiplier) / 1000);

      return (
        distanceScore * 0.25 +
        vehicleScore * 0.2 +
        availabilityScore * 0.15 +
        workloadPenalty * 0.15 +
        urgencyScore * 0.1 +
        fuelScore * 0.1 +
        (1 - trafficMultiplier) * 0.05 // Prefer routes with less traffic
      );
    } catch (error) {
      console.error("Enhanced fitness calculation error:", error);
      return 0.1;
    }
  }

  async calculateEnhancedDistance(origin, destination) {
    try {
      if (this.useRealTimeTraffic) {
        const response = await axios.get(
          `https://maps.googleapis.com/maps/api/distancematrix/json`,
          {
            params: {
              origins: `${origin.lat},${origin.lng}`,
              destinations: `${destination.lat},${destination.lng}`,
              key: this.googleMapsKey,
              departure_time: "now",
              traffic_model: "best_guess",
            },
          }
        );

        if (response.data.rows[0]?.elements[0]?.status === "OK") {
          const element = response.data.rows[0].elements[0];
          const distance = element.distance.value; // meters
          const durationInTraffic =
            element.duration_in_traffic?.value || element.duration.value;
          const normalDuration = element.duration.value;

          const trafficMultiplier = durationInTraffic / normalDuration;

          return {
            distance,
            duration: durationInTraffic,
            trafficMultiplier: Math.min(trafficMultiplier, 3.0), // Cap at 3x
            trafficLevel: this.getTrafficLevel(trafficMultiplier),
          };
        }
      }

      // Fallback to basic distance calculation
      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/distancematrix/json`,
        {
          params: {
            origins: `${origin.lat},${origin.lng}`,
            destinations: `${destination.lat},${destination.lng}`,
            key: this.googleMapsKey,
          },
        }
      );

      if (response.data.rows[0]?.elements[0]?.status === "OK") {
        return {
          distance: response.data.rows[0].elements[0].distance.value,
          duration: response.data.rows[0].elements[0].duration.value,
          trafficMultiplier: 1.0,
          trafficLevel: "unknown",
        };
      }

      return {
        distance: 10000,
        duration: 3600,
        trafficMultiplier: 1.0,
        trafficLevel: "unknown",
      };
    } catch (error) {
      console.error("Enhanced distance calculation error:", error);
      return {
        distance: 10000,
        duration: 3600,
        trafficMultiplier: 1.0,
        trafficLevel: "unknown",
      };
    }
  }

  getTrafficLevel(trafficMultiplier) {
    if (trafficMultiplier >= 2.0) return "heavy";
    if (trafficMultiplier >= 1.5) return "moderate";
    if (trafficMultiplier >= 1.2) return "light";
    return "smooth";
  }

  calculateEnhancedVehicleSuitability(volunteer) {
    const vehicle = volunteer.volunteerDetails?.vehicleType || "none";

    const suitability = {
      bike: { base: 0.6, capacity: 5, range: 10 },
      car: { base: 0.8, capacity: 50, range: 100 },
      van: { base: 0.9, capacity: 200, range: 150 },
      truck: { base: 1.0, capacity: 500, range: 200 },
      none: { base: 0.3, capacity: 10, range: 5 },
    };

    return suitability[vehicle]?.base || 0.5;
  }

  calculateFuelEfficiency(volunteer, distance) {
    const vehicle = volunteer.volunteerDetails?.vehicleType || "none";

    const efficiency = {
      bike: 1.0, // Most efficient
      none: 0.9, // Walking
      car: 0.7, // Moderate
      van: 0.5, // Less efficient
      truck: 0.3, // Least efficient
    };

    const baseEfficiency = efficiency[vehicle] || 0.5;

    // Adjust based on distance (longer distances are less efficient for some vehicles)
    let distanceFactor = 1.0;
    if (vehicle === "bike" && distance > 5000) distanceFactor = 0.7;
    if (vehicle === "none" && distance > 2000) distanceFactor = 0.5;

    return baseEfficiency * distanceFactor;
  }

  initializePopulation(volunteers, size) {
    const population = [];
    for (let i = 0; i < size; i++) {
      const randomVolunteer =
        volunteers[Math.floor(Math.random() * volunteers.length)];
      population.push(randomVolunteer);
    }
    return population;
  }

  evolvePopulation(
    population,
    fitnessScores,
    mutationRate,
    availableVolunteers
  ) {
    const newPopulation = [];

    // Elitism: keep best individual
    const bestIndex = fitnessScores.indexOf(Math.max(...fitnessScores));
    newPopulation.push(population[bestIndex]);

    // Create rest of population through selection and mutation
    while (newPopulation.length < population.length) {
      const parent1 = this.tournamentSelection(population, fitnessScores);
      const parent2 = this.tournamentSelection(population, fitnessScores);

      let child = Math.random() > 0.5 ? parent1 : parent2;

      // Mutation
      if (Math.random() < mutationRate) {
        child =
          availableVolunteers[
            Math.floor(Math.random() * availableVolunteers.length)
          ];
      }

      newPopulation.push(child);
    }

    return newPopulation;
  }

  tournamentSelection(population, fitnessScores, tournamentSize = 3) {
    let best = null;
    let bestFitness = -1;

    for (let i = 0; i < tournamentSize; i++) {
      const randomIndex = Math.floor(Math.random() * population.length);
      if (fitnessScores[randomIndex] > bestFitness) {
        best = population[randomIndex];
        bestFitness = fitnessScores[randomIndex];
      }
    }

    return best;
  }

  async optimizeMultiStopRoute(waypoints) {
    try {
      if (waypoints.length <= 1) {
        return {
          waypoints: waypoints,
          totalDistance: 0,
          estimatedDuration: 0,
          trafficConditions: "normal",
        };
      }

      if (this.useRealTimeTraffic) {
        // Use Google Routes API for optimization with traffic
        const response = await axios.post(
          `https://routes.googleapis.com/directions/v2:computeRoutes`,
          {
            origin: waypoints[0],
            destination: waypoints[waypoints.length - 1],
            intermediates: waypoints.slice(1, -1),
            travelMode: "DRIVE",
            optimizeWaypointOrder: true,
            routingPreference: "TRAFFIC_AWARE",
            computeAlternativeRoutes: false,
          },
          {
            headers: {
              "Content-Type": "application/json",
              "X-Goog-Api-Key": this.googleMapsKey,
              "X-Goog-FieldMask":
                "routes.optimizedIntermediateWaypointIndex,routes.duration,routes.distanceMeters,routes.polyline,routes.travelAdvisory",
            },
          }
        );

        if (response.data.routes && response.data.routes.length > 0) {
          const route = response.data.routes[0];
          return {
            waypoints: waypoints.map((wp, index) => ({
              ...wp,
              sequence: route.optimizedIntermediateWaypointIndex
                ? route.optimizedIntermediateWaypointIndex.indexOf(index)
                : index,
            })),
            totalDistance: route.distanceMeters,
            estimatedDuration: route.duration,
            polyline: route.polyline,
            trafficConditions:
              route.travelAdvisory?.trafficConditions || "normal",
          };
        }
      }

      // Fallback: return tasks in original order
      return {
        waypoints: waypoints.map((wp, index) => ({ ...wp, sequence: index })),
        totalDistance: 0,
        estimatedDuration: 0,
        trafficConditions: "unknown",
      };
    } catch (error) {
      console.error("Route optimization error:", error);
      // Fallback: return tasks in original order
      return {
        waypoints: waypoints.map((wp, index) => ({ ...wp, sequence: index })),
        totalDistance: 0,
        estimatedDuration: 0,
        trafficConditions: "unknown",
      };
    }
  }

  async getRealTimeRoute(origin, destination) {
    try {
      if (!this.useRealTimeTraffic) {
        return await this.getBasicRoute(origin, destination);
      }

      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/directions/json`,
        {
          params: {
            origin: `${origin.lat},${origin.lng}`,
            destination: `${destination.lat},${destination.lng}`,
            key: this.googleMapsKey,
            alternatives: false,
            traffic_model: "best_guess",
            departure_time: "now",
          },
        }
      );

      if (response.data.routes && response.data.routes.length > 0) {
        const route = response.data.routes[0];
        return {
          polyline: route.overview_polyline?.points,
          totalDistance: route.legs[0]?.distance?.value || 0,
          estimatedDuration: route.legs[0]?.duration?.value || 0,
          estimatedDurationInTraffic:
            route.legs[0]?.duration_in_traffic?.value ||
            route.legs[0]?.duration?.value ||
            0,
          trafficConditions: this.analyzeRouteTraffic(route),
          steps:
            route.legs[0]?.steps?.map((step) => ({
              instruction: step.html_instructions,
              distance: step.distance?.value,
              duration: step.duration?.value,
            })) || [],
        };
      }

      return await this.getBasicRoute(origin, destination);
    } catch (error) {
      console.error("Real-time route error:", error);
      return await this.getBasicRoute(origin, destination);
    }
  }

  async getBasicRoute(origin, destination) {
    try {
      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/directions/json`,
        {
          params: {
            origin: `${origin.lat},${origin.lng}`,
            destination: `${destination.lat},${destination.lng}`,
            key: this.googleMapsKey,
          },
        }
      );

      if (response.data.routes && response.data.routes.length > 0) {
        const route = response.data.routes[0];
        return {
          polyline: route.overview_polyline?.points,
          totalDistance: route.legs[0]?.distance?.value || 0,
          estimatedDuration: route.legs[0]?.duration?.value || 0,
          trafficConditions: "unknown",
          steps:
            route.legs[0]?.steps?.map((step) => ({
              instruction: step.html_instructions,
              distance: step.distance?.value,
              duration: step.duration?.value,
            })) || [],
        };
      }

      return null;
    } catch (error) {
      console.error("Basic route error:", error);
      return null;
    }
  }

  analyzeRouteTraffic(route) {
    // Simple traffic analysis based on duration differences
    const legs = route.legs || [];
    if (legs.length === 0) return "unknown";

    const leg = legs[0];
    const normalDuration = leg.duration?.value || 0;
    const trafficDuration = leg.duration_in_traffic?.value || normalDuration;

    const trafficRatio = trafficDuration / normalDuration;

    if (trafficRatio >= 2.0) return "heavy";
    if (trafficRatio >= 1.5) return "moderate";
    if (trafficRatio >= 1.2) return "light";
    return "smooth";
  }

  // New method for dynamic route updates
  async updateRouteForTask(taskId, currentLocation) {
    try {
      const task = await LogisticsTask.findById(taskId);
      if (!task) throw new Error("Task not found");

      const updatedRoute = await this.getRealTimeRoute(
        currentLocation,
        task.dropoffLocation
      );

      if (updatedRoute) {
        task.optimizedRoute = updatedRoute;
        await task.save();

        return updatedRoute;
      }

      return null;
    } catch (error) {
      console.error("Route update error:", error);
      return null;
    }
  }
}

module.exports = new RouteOptimizationService();
