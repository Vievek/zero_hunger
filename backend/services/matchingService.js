const { HfInference } = require("@huggingface/inference");
const Donation = require("../models/Donation");
const User = require("../models/User");
const fallbackMatchingService = require("./fallbackMatchingService");

class MatchingService {
  constructor() {
    this.hf = process.env.HUGGINGFACE_TOKEN
      ? new HfInference(process.env.HUGGINGFACE_TOKEN)
      : null;
    this.useAIMatching = !!process.env.HUGGINGFACE_TOKEN;
  }

  async getEmbedding(text) {
    if (!this.useAIMatching) {
      throw new Error("AI matching disabled - no HuggingFace token");
    }

    try {
      const response = await this.hf.featureExtraction({
        model: "sentence-transformers/all-MiniLM-L6-v2",
        inputs: text,
      });
      return response;
    } catch (error) {
      console.error("Embedding generation error:", error);
      throw new Error("AI embedding service unavailable");
    }
  }

  cosineSimilarity(vecA, vecB) {
    if (!vecA || !vecB || vecA.length !== vecB.length) return 0;

    const dotProduct = vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
    const normA = Math.sqrt(vecA.reduce((sum, a) => sum + a * a, 0));
    const normB = Math.sqrt(vecB.reduce((sum, b) => sum + b * b, 0));

    if (normA === 0 || normB === 0) return 0;
    return dotProduct / (normA * normB);
  }

  async findBestMatches(donationId) {
    try {
      const donation = await Donation.findById(donationId).populate("donor");
      if (!donation) throw new Error("Donation not found");

      let aiMatches = [];
      let usingFallback = false;

      // Attempt AI-powered matching first if available
      if (this.useAIMatching) {
        try {
          const donationText = `${
            donation.description || donation.aiDescription
          } ${donation.categories.join(" ")} ${donation.tags.join(" ")}`;
          const donationEmbedding = await this.getEmbedding(donationText);

          aiMatches = await this.calculateAIMatches(
            donation,
            donationEmbedding
          );
          console.log(
            `AI matching found ${aiMatches.length} potential matches`
          );
        } catch (aiError) {
          console.error("AI matching failed, using fallback:", aiError.message);
          usingFallback = true;
        }
      } else {
        usingFallback = true;
        console.log("AI matching disabled, using fallback matching");
      }

      let finalMatches = [];

      // If AI failed or no good matches, use fallback
      if (usingFallback || aiMatches.length === 0) {
        console.log("Using fallback matching service");
        finalMatches = await fallbackMatchingService.findMatches(donation);
      } else {
        finalMatches = aiMatches;
      }

      // Return top 3 matches sorted by score
      const bestMatches = finalMatches
        .sort((a, b) => b.totalScore - a.totalScore)
        .slice(0, 3);

      console.log(
        `Final matching results: ${bestMatches.length} matches found for donation ${donationId}`
      );
      return bestMatches;
    } catch (error) {
      console.error("Matching error:", error);
      // Always return some fallback matches
      const donation = await Donation.findById(donationId);
      return await fallbackMatchingService.findMatches(donation);
    }
  }

  async calculateAIMatches(donation, donationEmbedding) {
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

        if (currentLoad >= (recipient.recipientDetails.capacity || 50)) {
          continue;
        }

        // Calculate semantic match
        const recipientText = `${
          recipient.recipientDetails.organizationName
        } ${(recipient.recipientDetails.dietaryRestrictions || []).join(" ")} ${
          recipient.recipientDetails.organizationType || ""
        }`;
        const recipientEmbedding = await this.getEmbedding(recipientText);

        const semanticScore = this.cosineSimilarity(
          donationEmbedding,
          recipientEmbedding
        );

        // Calculate other scores
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
          recipient.recipientDetails.capacity
        );

        // Enhanced combined score with weights
        const totalScore =
          semanticScore * 0.35 +
          proximityScore * 0.25 +
          dietaryScore * 0.25 +
          capacityScore * 0.15;

        if (totalScore > 0.3) {
          // Minimum threshold
          matches.push({
            recipient: recipient,
            semanticScore,
            proximityScore,
            dietaryScore,
            capacityScore,
            totalScore,
            currentLoad,
            capacity: recipient.recipientDetails.capacity,
            matchingMethod: "ai",
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

    return matches;
  }

  async calculateProximityScore(donationLocation, recipient) {
    try {
      const recipientLocation =
        recipient.recipientDetails?.location || recipient.contactInfo?.location;

      if (!donationLocation || !recipientLocation) {
        return 0.5; // Default score if locations not available
      }

      // Calculate simple distance (in production, use proper geospatial queries)
      const distance = Math.sqrt(
        Math.pow(donationLocation.lat - recipientLocation.lat, 2) +
          Math.pow(donationLocation.lng - recipientLocation.lng, 2)
      );

      // Convert to proximity score (closer = higher score)
      // Assuming coordinates are in degrees, this is a simplified approach
      const maxDistance = 0.5; // ~55km in degrees
      return Math.max(0, 1 - distance / maxDistance);
    } catch (error) {
      console.error("Proximity calculation error:", error);
      return 0.5;
    }
  }

  calculateDietaryCompatibility(donation, recipient) {
    const recipientRestrictions =
      recipient.recipientDetails?.dietaryRestrictions || [];
    const donationTags = donation.tags || [];
    const donationCategories = donation.categories || [];

    if (recipientRestrictions.length === 0) return 1.0;

    let compatibility = 1.0;

    // Enhanced dietary conflict detection
    const conflictRules = {
      vegetarian: ["meat", "poultry", "seafood", "fish"],
      vegan: ["meat", "poultry", "seafood", "fish", "dairy", "eggs", "honey"],
      halal: ["pork", "alcohol"],
      kosher: ["pork", "shellfish", "mixing-meat-dairy"],
      "gluten-free": ["wheat", "barley", "rye", "gluten"],
      "dairy-free": ["dairy", "milk", "cheese", "butter"],
    };

    for (const restriction of recipientRestrictions) {
      const conflicts = conflictRules[restriction] || [];

      // Check for conflicts in tags and categories
      const hasConflict = conflicts.some(
        (conflict) =>
          donationTags.includes(conflict) ||
          donationCategories.includes(conflict)
      );

      if (hasConflict) {
        compatibility *= 0.1; // Severe penalty for dietary conflicts
      }
    }

    return compatibility;
  }

  calculateCapacityScore(currentLoad, capacity) {
    if (!capacity || capacity === 0) return 0.5;

    const utilization = currentLoad / capacity;

    // Prefer recipients with lower utilization (more capacity)
    if (utilization >= 1.0) return 0.0; // No capacity
    if (utilization >= 0.8) return 0.2; // Very limited capacity
    if (utilization >= 0.5) return 0.5; // Moderate capacity
    return 1.0; // Plenty of capacity
  }
}

module.exports = new MatchingService();
