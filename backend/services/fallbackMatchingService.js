const User = require("../models/User");
const Donation = require("../models/Donation");

class FallbackMatchingService {
  constructor() {
    this.keywordWeights = {
      // Food type keywords
      "prepared-meal": 1.0,
      fruits: 0.8,
      vegetables: 0.8,
      "baked-goods": 0.9,
      dairy: 0.7,
      meat: 0.6,
      seafood: 0.6,
      grains: 0.7,
      beverages: 0.5,

      // Dietary keywords
      vegetarian: 0.9,
      vegan: 0.9,
      "gluten-free": 0.8,
      "dairy-free": 0.8,
      "nut-free": 0.7,
      halal: 0.8,
      kosher: 0.8,
    };
  }

  async findMatches(donation) {
    try {
      console.log(`Starting fallback matching for donation: ${donation._id}`);

      const recipients = await User.find({
        role: "recipient",
        "recipientDetails.verificationStatus": "verified",
      }).populate("recipientDetails");

      const matches = [];

      for (const recipient of recipients) {
        try {
          // Check capacity first
          const currentLoad = await Donation.countDocuments({
            acceptedBy: recipient._id,
            status: { $in: ["active", "matched", "scheduled"] },
          });

          const capacity = recipient.recipientDetails.capacity || 50;
          if (currentLoad >= capacity) {
            continue;
          }

          // Calculate match scores using multiple strategies
          const keywordScore = this.calculateKeywordScore(donation, recipient);
          const proximityScore = await this.calculateProximityScore(
            donation.location,
            recipient
          );
          const dietaryScore = this.calculateDietaryCompatibility(
            donation,
            recipient
          );
          const capacityScore = this.calculateCapacityScore(
            currentLoad,
            capacity
          );
          const organizationScore = this.calculateOrganizationTypeScore(
            donation,
            recipient
          );

          // Combined score with weights
          const totalScore =
            keywordScore * 0.3 +
            proximityScore * 0.25 +
            dietaryScore * 0.2 +
            capacityScore * 0.15 +
            organizationScore * 0.1;

          if (totalScore > 0.3) {
            // Minimum threshold
            matches.push({
              recipient: recipient,
              keywordScore,
              proximityScore,
              dietaryScore,
              capacityScore,
              organizationScore,
              totalScore,
              currentLoad,
              capacity,
              matchingMethod: "fallback",
            });
          }
        } catch (recipientError) {
          console.error(
            `Error processing recipient ${recipient._id}:`,
            recipientError
          );
          continue;
        }
      }

      console.log(
        `Fallback matching found ${matches.length} potential matches for donation ${donation._id}`
      );
      return matches;
    } catch (error) {
      console.error("Fallback matching error:", error);
      return []; // Return empty array instead of throwing
    }
  }

  calculateKeywordScore(donation, recipient) {
    let score = 0;
    let matchedKeywords = 0;
    let totalPossible = 0;

    // Check donation categories against recipient preferences
    const donationCategories = donation.categories || [];
    const donationTags = donation.tags || [];
    const recipientRestrictions =
      recipient.recipientDetails?.dietaryRestrictions || [];
    const recipientFoodTypes =
      recipient.recipientDetails?.preferredFoodTypes || [];

    // Score based on category matches
    for (const category of donationCategories) {
      totalPossible++;
      if (recipientFoodTypes.includes(category)) {
        score += this.keywordWeights[category] || 0.5;
        matchedKeywords++;
      }
    }

    // Score based on dietary compatibility (inverse - avoid mismatches)
    for (const restriction of recipientRestrictions) {
      if (this.hasDietaryConflict(donationTags, restriction)) {
        score *= 0.1; // Severe penalty for dietary conflicts
      }
    }

    // Normalize score
    const normalizedScore = totalPossible > 0 ? score / totalPossible : 0.5;

    // Boost score if we have good keyword matches
    const matchRatio = totalPossible > 0 ? matchedKeywords / totalPossible : 0;
    const keywordBoost = matchRatio * 0.3;

    return Math.min(1.0, normalizedScore + keywordBoost);
  }

  hasDietaryConflict(donationTags, restriction) {
    const conflictMap = {
      vegetarian: ["meat", "poultry", "seafood", "fish"],
      vegan: ["meat", "poultry", "seafood", "fish", "dairy", "eggs", "honey"],
      halal: ["pork", "alcohol"],
      kosher: ["pork", "shellfish"],
      "gluten-free": ["wheat", "barley", "rye", "gluten"],
      "dairy-free": ["dairy", "milk", "cheese", "butter"],
      "nut-free": ["nuts", "peanuts", "almonds", "walnuts"],
    };

    const conflicts = conflictMap[restriction] || [];
    return conflicts.some((conflict) =>
      donationTags.some((tag) =>
        tag.toLowerCase().includes(conflict.toLowerCase())
      )
    );
  }

  async calculateProximityScore(donationLocation, recipient) {
    try {
      const recipientLocation =
        recipient.recipientDetails?.location || recipient.contactInfo?.location;

      if (!donationLocation || !recipientLocation) {
        return 0.5; // Default score if locations not available
      }

      // Calculate simple distance (in production, use proper geospatial queries)
      const distance = this.calculateSimpleDistance(
        donationLocation,
        recipientLocation
      );

      // Convert to proximity score (closer = higher score)
      // Assuming coordinates are in degrees, this is a simplified approach
      const maxDistance = 0.5; // ~55km in degrees
      const proximity = Math.max(0, 1 - distance / maxDistance);

      // Apply distance-based scoring curve
      if (proximity > 0.8) return 1.0; // Very close
      if (proximity > 0.6) return 0.8; // Close
      if (proximity > 0.4) return 0.6; // Moderate distance
      if (proximity > 0.2) return 0.4; // Far
      return 0.2; // Very far
    } catch (error) {
      console.error("Proximity calculation error:", error);
      return 0.5;
    }
  }

  calculateSimpleDistance(loc1, loc2) {
    // Simple Euclidean distance (in degrees)
    // In production, use Haversine formula for real distances
    return Math.sqrt(
      Math.pow(loc1.lat - loc2.lat, 2) + Math.pow(loc1.lng - loc2.lng, 2)
    );
  }

  calculateDietaryCompatibility(donation, recipient) {
    const recipientRestrictions =
      recipient.recipientDetails?.dietaryRestrictions || [];
    const donationTags = donation.tags || [];
    const donationCategories = donation.categories || [];

    if (recipientRestrictions.length === 0) return 1.0;

    let compatibility = 1.0;

    // Check for dietary conflicts
    for (const restriction of recipientRestrictions) {
      if (
        this.hasDietaryConflict(donationTags, restriction) ||
        this.hasDietaryConflict(donationCategories, restriction)
      ) {
        compatibility *= 0.1; // Severe penalty for conflicts
      }
    }

    // Check for positive matches (if recipient has preferred diets)
    const preferredDiets = recipient.recipientDetails?.preferredDiets || [];
    for (const diet of preferredDiets) {
      if (donationTags.includes(diet) || donationCategories.includes(diet)) {
        compatibility *= 1.2; // Small boost for preferred diets
      }
    }

    return Math.min(1.0, compatibility);
  }

  calculateCapacityScore(currentLoad, capacity) {
    if (!capacity || capacity === 0) return 0.5;

    const utilization = currentLoad / capacity;

    // Prefer recipients with lower utilization (more capacity)
    if (utilization >= 1.0) return 0.0; // No capacity
    if (utilization >= 0.8) return 0.2; // Very limited capacity
    if (utilization >= 0.6) return 0.4; // Limited capacity
    if (utilization >= 0.4) return 0.6; // Moderate capacity
    if (utilization >= 0.2) return 0.8; // Good capacity
    return 1.0; // Plenty of capacity
  }

  calculateOrganizationTypeScore(donation, recipient) {
    const orgType = recipient.recipientDetails?.organizationType;
    const donationType = donation.type;
    const categories = donation.categories || [];

    // Different organization types might prefer different donation types
    const orgPreferences = {
      shelter: {
        preferredTypes: ["normal", "bulk"],
        preferredCategories: ["prepared-meal", "baked-goods"],
      },
      community_kitchen: {
        preferredTypes: ["normal"],
        preferredCategories: ["prepared-meal", "vegetables", "grains"],
      },
      food_bank: {
        preferredTypes: ["bulk", "normal"],
        preferredCategories: ["grains", "canned-goods", "beverages"],
      },
      religious: {
        preferredTypes: ["normal", "bulk"],
        preferredCategories: ["prepared-meal", "baked-goods"],
      },
      other: { preferredTypes: ["normal", "bulk"], preferredCategories: [] },
    };

    const preferences = orgPreferences[orgType] || orgPreferences["other"];

    let score = 0.5; // Base score

    // Check donation type preference
    if (preferences.preferredTypes.includes(donationType)) {
      score += 0.2;
    }

    // Check category preferences
    const matchingCategories = categories.filter((cat) =>
      preferences.preferredCategories.includes(cat)
    );
    if (matchingCategories.length > 0) {
      score += (matchingCategories.length / categories.length) * 0.3;
    }

    return Math.min(1.0, score);
  }

  // Enhanced matching for specific scenarios
  async findUrgentMatches(donation) {
    // For urgent donations, prioritize proximity and capacity over other factors
    const allMatches = await this.findMatches(donation);

    return allMatches
      .map((match) => ({
        ...match,
        // Recalculate score with different weights for urgency
        totalScore:
          match.proximityScore * 0.4 +
          match.capacityScore * 0.3 +
          match.keywordScore * 0.2 +
          match.dietaryScore * 0.1,
      }))
      .sort((a, b) => b.totalScore - a.totalScore);
  }

  async findBulkMatches(donation) {
    // For bulk donations, prioritize organizations with higher capacity
    const allMatches = await this.findMatches(donation);

    return allMatches
      .map((match) => ({
        ...match,
        // Recalculate score with capacity focus
        totalScore:
          match.capacityScore * 0.4 +
          match.keywordScore * 0.25 +
          match.proximityScore * 0.2 +
          match.organizationScore * 0.15,
      }))
      .sort((a, b) => b.totalScore - a.totalScore);
  }

  // Debug method to analyze matching decisions
  analyzeMatchingDecision(donation, recipient, scores) {
    return {
      donationId: donation._id,
      recipientId: recipient._id,
      recipientName: recipient.recipientDetails?.organizationName,
      scores: {
        keyword: scores.keywordScore,
        proximity: scores.proximityScore,
        dietary: scores.dietaryScore,
        capacity: scores.capacityScore,
        organization: scores.organizationScore,
        total: scores.totalScore,
      },
      factors: {
        categories: donation.categories,
        tags: donation.tags,
        recipientRestrictions: recipient.recipientDetails?.dietaryRestrictions,
        currentLoad: scores.currentLoad,
        capacity: scores.capacity,
        organizationType: recipient.recipientDetails?.organizationType,
      },
    };
  }
}

module.exports = new FallbackMatchingService();
