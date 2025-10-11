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
      console.log(
        `🔄 Starting fallback matching for donation: ${donation._id}`
      );

      const recipients = await User.find({
        role: "recipient",
        "recipientDetails.verificationStatus": "verified",
        "recipientDetails.isActive": true,
      }).populate("recipientDetails");

      const matches = [];
      console.log(
        `🔍 Checking ${recipients.length} recipients for fallback matching`
      );

      for (const recipient of recipients) {
        try {
          // FIXED: Enhanced capacity calculation
          const currentLoad = await Donation.countDocuments({
            acceptedBy: recipient._id,
            status: { $in: ["active", "matched", "scheduled", "picked_up"] },
          });

          const capacity = recipient.recipientDetails?.capacity || 50;

          console.log(
            `📊 Recipient ${recipient._id} capacity: ${currentLoad}/${capacity}`
          );

          if (currentLoad >= capacity) {
            console.log(
              `⛔ Recipient ${recipient._id} at capacity: ${currentLoad}/${capacity}`
            );
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
          const preferenceScore = this.calculatePreferenceScore(
            donation,
            recipient
          );

          // Combined score with weights
          const totalScore =
            keywordScore * 0.25 +
            proximityScore * 0.25 +
            dietaryScore * 0.2 +
            capacityScore * 0.15 +
            organizationScore * 0.1 +
            preferenceScore * 0.05;

          console.log(
            `📊 Fallback scores for ${
              recipient._id
            }: keyword=${keywordScore.toFixed(
              2
            )}, proximity=${proximityScore.toFixed(
              2
            )}, dietary=${dietaryScore.toFixed(
              2
            )}, capacity=${capacityScore.toFixed(
              2
            )}, org=${organizationScore.toFixed(
              2
            )}, preference=${preferenceScore.toFixed(
              2
            )}, total=${totalScore.toFixed(2)}`
          );

          if (totalScore > 0.3) {
            // Minimum threshold
            matches.push({
              recipient: recipient,
              keywordScore,
              proximityScore,
              dietaryScore,
              capacityScore,
              organizationScore,
              preferenceScore,
              totalScore,
              currentLoad,
              capacity,
              matchingMethod: "fallback",
            });
          }
        } catch (recipientError) {
          console.error(
            `❌ Error processing recipient ${recipient._id}:`,
            recipientError
          );
          continue;
        }
      }

      console.log(
        `✅ Fallback matching found ${matches.length} potential matches for donation ${donation._id}`
      );
      return matches;
    } catch (error) {
      console.error("❌ Fallback matching error:", error);
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
      if (
        this.hasDietaryConflict(donationTags, restriction) ||
        this.hasDietaryConflict(donationCategories, restriction)
      ) {
        score *= 0.1; // Severe penalty for dietary conflicts
        console.log(`⚠️ Dietary conflict in fallback: ${restriction}`);
      }
    }

    // Normalize score
    const normalizedScore = totalPossible > 0 ? score / totalPossible : 0.5;

    // Boost score if we have good keyword matches
    const matchRatio = totalPossible > 0 ? matchedKeywords / totalPossible : 0;
    const keywordBoost = matchRatio * 0.3;

    return Math.min(1.0, normalizedScore + keywordBoost);
  }

  // NEW: Calculate preference score
  calculatePreferenceScore(donation, recipient) {
    const preferredFoodTypes =
      recipient.recipientDetails?.preferredFoodTypes || [];
    const donationCategories = donation.categories || [];

    if (preferredFoodTypes.length === 0) return 0.5;

    let matchCount = 0;
    donationCategories.forEach((category) => {
      if (preferredFoodTypes.includes(category)) {
        matchCount++;
      }
    });

    return matchCount / Math.max(donationCategories.length, 1);
  }

  hasDietaryConflict(items, restriction) {
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
      items.some((item) => item.toLowerCase().includes(conflict.toLowerCase()))
    );
  }

  async calculateProximityScore(donationLocation, recipient) {
    try {
      const recipientLocation =
        recipient.recipientDetails?.location || recipient.contactInfo?.location;

      if (!donationLocation || !recipientLocation) {
        return 0.5; // Default score if locations not available
      }

      // Calculate simple distance
      const distance = this.calculateSimpleDistance(
        donationLocation,
        recipientLocation
      );

      // Convert to proximity score (closer = higher score)
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
    const preferredFoodTypes =
      recipient.recipientDetails?.preferredFoodTypes || [];
    for (const foodType of preferredFoodTypes) {
      if (
        donationTags.includes(foodType) ||
        donationCategories.includes(foodType)
      ) {
        compatibility *= 1.2; // Small boost for preferred food types
      }
    }

    return Math.min(1.0, compatibility);
  }

  calculateCapacityScore(currentLoad, capacity) {
    if (!capacity || capacity === 0) return 0.5;

    const utilization = currentLoad / capacity;

    // Enhanced capacity scoring
    if (utilization >= 1.0) return 0.0; // No capacity
    if (utilization >= 0.9) return 0.1; // Almost full
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
          match.keywordScore * 0.15 +
          match.dietaryScore * 0.1 +
          match.organizationScore * 0.05,
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
          match.keywordScore * 0.2 +
          match.proximityScore * 0.15 +
          match.organizationScore * 0.15 +
          match.dietaryScore * 0.1,
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
        preference: scores.preferenceScore,
        total: scores.totalScore,
      },
      factors: {
        categories: donation.categories,
        tags: donation.tags,
        recipientRestrictions: recipient.recipientDetails?.dietaryRestrictions,
        recipientPreferences: recipient.recipientDetails?.preferredFoodTypes,
        currentLoad: scores.currentLoad,
        capacity: scores.capacity,
        organizationType: recipient.recipientDetails?.organizationType,
      },
    };
  }
}

module.exports = new FallbackMatchingService();
