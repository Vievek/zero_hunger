const axios = require("axios");

class RouteOptimizationService {
  constructor() {
    this.googleMapsKey = process.env.GOOGLE_MAPS_API_KEY;
  }

  // Genetic Algorithm for volunteer assignment
  async assignVolunteerWithGA(tasks, availableVolunteers) {
    const populationSize = 50;
    const generations = 100;
    const mutationRate = 0.1;

    // Initialize population
    let population = this.initializePopulation(
      tasks,
      availableVolunteers,
      populationSize
    );

    for (let gen = 0; gen < generations; gen++) {
      // Evaluate fitness
      const fitnessScores = await Promise.all(
        population.map((individual) => this.calculateFitness(individual))
      );

      // Selection
      const selected = this.selection(population, fitnessScores);

      // Crossover and mutation
      population = this.createNewPopulation(selected, mutationRate);
    }

    // Return best individual
    const finalFitness = await Promise.all(
      population.map((individual) => this.calculateFitness(individual))
    );
    const bestIndex = finalFitness.indexOf(Math.max(...finalFitness));

    return population[bestIndex];
  }

  initializePopulation(tasks, volunteers, size) {
    const population = [];
    for (let i = 0; i < size; i++) {
      const assignment = {};
      tasks.forEach((task) => {
        const randomVolunteer =
          volunteers[Math.floor(Math.random() * volunteers.length)];
        assignment[task._id] = randomVolunteer._id;
      });
      population.push(assignment);
    }
    return population;
  }

  async calculateFitness(assignment) {
    let totalFitness = 0;

    for (const [taskId, volunteerId] of Object.entries(assignment)) {
      const task = await LogisticsTask.findById(taskId);
      const volunteer = await User.findById(volunteerId);

      // Calculate distance cost
      const distance = await this.calculateDistance(
        volunteer.volunteerDetails.currentLocation,
        task.pickupLocation
      );

      // Calculate time compatibility
      const timeScore = this.calculateTimeCompatibility(volunteer, task);

      // Vehicle suitability
      const vehicleScore = this.calculateVehicleSuitability(volunteer, task);

      totalFitness += (1 / distance) * timeScore * vehicleScore;
    }

    return totalFitness;
  }

  async calculateDistance(location1, location2) {
    try {
      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/distancematrix/json`,
        {
          params: {
            origins: `${location1.lat},${location1.lng}`,
            destinations: `${location2.lat},${location2.lng}`,
            key: this.googleMapsKey,
          },
        }
      );

      return response.data.rows[0].elements[0].distance.value; // meters
    } catch (error) {
      console.error("Distance calculation error:", error);
      return 10000; // Fallback large distance
    }
  }

  calculateTimeCompatibility(volunteer, task) {
    // Check if volunteer is available at task time
    const taskTime = new Date(task.scheduledPickupTime);
    const dayOfWeek = taskTime
      .toLocaleDateString("en", { weekday: "long" })
      .toLowerCase();

    const availability = volunteer.volunteerDetails.availability.find(
      (avail) => avail.day.toLowerCase() === dayOfWeek
    );

    if (!availability) return 0;

    const taskHour = taskTime.getHours();
    const availableStart = parseInt(availability.startTime.split(":")[0]);
    const availableEnd = parseInt(availability.endTime.split(":")[0]);

    return taskHour >= availableStart && taskHour <= availableEnd ? 1 : 0.5;
  }

  calculateVehicleSuitability(volunteer, task) {
    const vehicle = volunteer.volunteerDetails.vehicleType;
    const quantity = task.donation.quantity.amount;

    // Simple suitability scoring
    const suitability = {
      bike: quantity <= 5 ? 1 : 0.2,
      car: quantity <= 20 ? 1 : 0.5,
      van: quantity <= 50 ? 1 : 0.8,
      truck: 1,
    };

    return suitability[vehicle] || 0.1;
  }

  selection(population, fitnessScores) {
    // Tournament selection
    const selected = [];
    const tournamentSize = 5;

    for (let i = 0; i < population.length; i++) {
      const tournament = [];
      for (let j = 0; j < tournamentSize; j++) {
        tournament.push(Math.floor(Math.random() * population.length));
      }
      const bestInTournament = tournament.reduce((best, current) =>
        fitnessScores[current] > fitnessScores[best] ? current : best
      );
      selected.push(population[bestInTournament]);
    }

    return selected;
  }

  createNewPopulation(selected, mutationRate) {
    const newPopulation = [];

    while (newPopulation.length < selected.length) {
      const parent1 = selected[Math.floor(Math.random() * selected.length)];
      const parent2 = selected[Math.floor(Math.random() * selected.length)];

      const child = this.crossover(parent1, parent2);
      this.mutate(child, mutationRate);

      newPopulation.push(child);
    }

    return newPopulation;
  }

  crossover(parent1, parent2) {
    const child = {};
    const tasks = Object.keys(parent1);

    tasks.forEach((taskId) => {
      child[taskId] = Math.random() > 0.5 ? parent1[taskId] : parent2[taskId];
    });

    return child;
  }

  mutate(individual, mutationRate) {
    Object.keys(individual).forEach((taskId) => {
      if (Math.random() < mutationRate) {
        // Randomly reassign task
        const volunteers = Object.values(individual);
        individual[taskId] =
          volunteers[Math.floor(Math.random() * volunteers.length)];
      }
    });
  }

  // Optimize multi-stop route
  async optimizeMultiStopRoute(waypoints) {
    try {
      const response = await axios.post(
        `https://routes.googleapis.com/directions/v2:computeRoutes`,
        {
          origin: waypoints[0],
          destination: waypoints[waypoints.length - 1],
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
        }
      );

      return response.data.routes[0];
    } catch (error) {
      console.error("Route optimization error:", error);
      throw new Error("Failed to optimize route");
    }
  }
}

module.exports = new RouteOptimizationService();
