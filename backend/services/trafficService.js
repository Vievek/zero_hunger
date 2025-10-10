const axios = require("axios");

class TrafficService {
  constructor() {
    this.googleMapsKey = process.env.GOOGLE_MAPS_API_KEY;
    this.cache = new Map();
    this.cacheTimeout = 5 * 60 * 1000; // 5 minutes
  }

  async getTrafficConditions(origin, destination) {
    const cacheKey = `${origin.lat},${origin.lng}-${destination.lat},${destination.lng}`;

    // Check cache first
    const cached = this.cache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
      return cached.data;
    }

    try {
      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/directions/json`,
        {
          params: {
            origin: `${origin.lat},${origin.lng}`,
            destination: `${destination.lat},${destination.lng}`,
            key: this.googleMapsKey,
            departure_time: "now",
            traffic_model: "best_guess",
            alternatives: false,
          },
        }
      );

      const trafficData = this.parseTrafficData(response.data);

      // Cache the result
      this.cache.set(cacheKey, {
        data: trafficData,
        timestamp: Date.now(),
      });

      return trafficData;
    } catch (error) {
      console.error("Traffic service error:", error);
      return this.getFallbackTrafficData();
    }
  }

  parseTrafficData(directionsResponse) {
    if (!directionsResponse.routes || directionsResponse.routes.length === 0) {
      return this.getFallbackTrafficData();
    }

    const route = directionsResponse.routes[0];
    const leg = route.legs[0];

    if (!leg) {
      return this.getFallbackTrafficData();
    }

    // Calculate traffic congestion level
    const normalDuration = leg.duration.value;
    const trafficDuration = leg.duration_in_traffic?.value || normalDuration;
    const trafficRatio = trafficDuration / normalDuration;

    // Analyze traffic conditions from steps
    const trafficConditions = this.analyzeRouteTraffic(route);

    return {
      normalDuration,
      trafficDuration,
      trafficRatio,
      congestionLevel: this.getCongestionLevel(trafficRatio),
      trafficConditions,
      distance: leg.distance.value,
      summary: leg.duration.text,
      trafficSummary: leg.duration_in_traffic?.text || leg.duration.text,
      hasTrafficData: !!leg.duration_in_traffic,
    };
  }

  analyzeRouteTraffic(route) {
    const steps = route.legs[0]?.steps || [];
    let heavyTrafficSteps = 0;
    let moderateTrafficSteps = 0;
    let lightTrafficSteps = 0;

    steps.forEach((step) => {
      // This is a simplified analysis - in production, you'd use more detailed traffic data
      const stepDuration = step.duration.value;
      const stepDistance = step.distance.value;
      const speed = stepDistance / stepDuration; // m/s

      if (speed < 2) {
        // ~7 km/h
        heavyTrafficSteps++;
      } else if (speed < 5) {
        // ~18 km/h
        moderateTrafficSteps++;
      } else {
        lightTrafficSteps++;
      }
    });

    const totalSteps = steps.length;
    return {
      heavyTraffic: totalSteps > 0 ? heavyTrafficSteps / totalSteps : 0,
      moderateTraffic: totalSteps > 0 ? moderateTrafficSteps / totalSteps : 0,
      lightTraffic: totalSteps > 0 ? lightTrafficSteps / totalSteps : 0,
      totalSteps,
    };
  }

  getCongestionLevel(trafficRatio) {
    if (trafficRatio >= 2.0) return "heavy";
    if (trafficRatio >= 1.5) return "moderate";
    if (trafficRatio >= 1.2) return "light";
    return "smooth";
  }

  getFallbackTrafficData() {
    return {
      normalDuration: 0,
      trafficDuration: 0,
      trafficRatio: 1.0,
      congestionLevel: "unknown",
      trafficConditions: {
        heavyTraffic: 0,
        moderateTraffic: 0,
        lightTraffic: 0,
        totalSteps: 0,
      },
      distance: 0,
      summary: "Unknown",
      trafficSummary: "Unknown",
      hasTrafficData: false,
      isFallback: true,
    };
  }

  async getBulkTrafficConditions(routes) {
    const results = [];

    for (const route of routes) {
      try {
        const trafficData = await this.getTrafficConditions(
          route.origin,
          route.destination
        );
        results.push({
          routeId: route.id,
          ...trafficData,
        });
      } catch (error) {
        console.error(`Error getting traffic for route ${route.id}:`, error);
        results.push({
          routeId: route.id,
          ...this.getFallbackTrafficData(),
          error: error.message,
        });
      }
    }

    return results;
  }

  // Predict traffic for future times
  async predictTraffic(origin, destination, departureTime) {
    try {
      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/directions/json`,
        {
          params: {
            origin: `${origin.lat},${origin.lng}`,
            destination: `${destination.lat},${destination.lng}`,
            key: this.googleMapsKey,
            departure_time: departureTime.getTime() / 1000, // Convert to seconds
            traffic_model: "best_guess",
          },
        }
      );

      return this.parseTrafficData(response.data);
    } catch (error) {
      console.error("Traffic prediction error:", error);
      return this.getFallbackTrafficData();
    }
  }

  // Get traffic trends for a route (multiple time predictions)
  async getTrafficTrends(origin, destination) {
    const now = new Date();
    const times = [
      new Date(now.getTime() + 30 * 60 * 1000), // 30 minutes from now
      new Date(now.getTime() + 60 * 60 * 1000), // 1 hour from now
      new Date(now.getTime() + 90 * 60 * 1000), // 1.5 hours from now
    ];

    const trends = [];

    for (const time of times) {
      const traffic = await this.predictTraffic(origin, destination, time);
      trends.push({
        time: time.toISOString(),
        ...traffic,
      });
    }

    return trends;
  }

  // Calculate optimal departure time
  async calculateOptimalDeparture(origin, destination, desiredArrivalTime) {
    const arrival = new Date(desiredArrivalTime);
    const testTimes = [];

    // Test departure times from 30 minutes to 3 hours before desired arrival
    for (let minutes = 180; minutes >= 30; minutes -= 15) {
      testTimes.push(new Date(arrival.getTime() - minutes * 60 * 1000));
    }

    let bestTime = null;
    let bestTrafficRatio = Infinity;

    for (const departureTime of testTimes) {
      const traffic = await this.predictTraffic(
        origin,
        destination,
        departureTime
      );

      if (traffic.trafficRatio < bestTrafficRatio) {
        bestTrafficRatio = traffic.trafficRatio;
        bestTime = departureTime;
      }
    }

    return {
      optimalDeparture: bestTime,
      estimatedTrafficRatio: bestTrafficRatio,
      estimatedDuration:
        bestTrafficRatio * this.getBaseDuration(origin, destination), // You'd need base duration
      recommendation: this.getDepartureRecommendation(bestTrafficRatio),
    };
  }

  getBaseDuration(origin, destination) {
    // This would calculate base duration without traffic
    // For now, return a placeholder
    return 1800; // 30 minutes in seconds
  }

  getDepartureRecommendation(trafficRatio) {
    if (trafficRatio >= 2.0)
      return "Leave much earlier - heavy traffic expected";
    if (trafficRatio >= 1.5) return "Leave earlier - moderate traffic expected";
    if (trafficRatio >= 1.2)
      return "Leave slightly earlier - light traffic expected";
    return "Normal departure time recommended";
  }

  // Clear cache (useful for testing or memory management)
  clearCache() {
    this.cache.clear();
  }

  // Get cache statistics
  getCacheStats() {
    return {
      size: this.cache.size,
      keys: Array.from(this.cache.keys()),
    };
  }
}

module.exports = new TrafficService();
