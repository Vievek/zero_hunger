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
      console.log(`🔍 Starting matching process for donation: ${donationId}`);
      const donation = await Donation.findById(donationId).populate("donor");
      if (!donation) throw new Error("Donation not found");

      let aiMatches = [];
      let usingFallback = false;

      // Attempt AI-powered matching first if available
      if (this.useAIMatching) {
        try {
          const donationText = `${
            donation.description || donation.aiDescription || "food donation"
          } ${donation.categories.join(" ")} ${donation.tags.join(" ")}`;
          console.log(`🤖 AI Matching: Processing donation text`);
          const donationEmbedding = await this.getEmbedding(donationText);

          aiMatches = await this.calculateAIMatches(
            donation,
            donationEmbedding
          );
          console.log(
            `🤖 AI matching found ${aiMatches.length} potential matches`
          );
        } catch (aiError) {
          console.error(
            "🤖 AI matching failed, using fallback:",
            aiError.message
          );
          usingFallback = true;
        }
      } else {
        usingFallback = true;
        console.log("🤖 AI matching disabled, using fallback matching");
      }

      let finalMatches = [];

      // If AI failed or no good matches, use fallback
      if (usingFallback || aiMatches.length === 0) {
        console.log("🔄 Using fallback matching service");
        finalMatches = await fallbackMatchingService.findMatches(donation);
      } else {
        finalMatches = aiMatches;
      }

      // Return top 5 matches sorted by score (increased from 3)
      const bestMatches = finalMatches
        .sort((a, b) => b.totalScore - a.totalScore)
        .slice(0, 5);

      console.log(
        `✅ Final matching results: ${bestMatches.length} matches found for donation ${donationId}`
      );

      // Prepare matches for database storage
      const matchesForDB = bestMatches.map((match) => ({
        recipient: match.recipient._id,
        matchScore: match.totalScore,
        status: "offered",
        matchingMethod: match.matchingMethod,
        matchReasons: this.generateMatchReasons(match),
      }));

      // Update donation with matches
      await Donation.findByIdAndUpdate(donationId, {
        $set: { matchedRecipients: matchesForDB },
      });

      return bestMatches;
    } catch (error) {
      console.error("❌ Matching error:", error);
      // Always return some fallback matches
      const donation = await Donation.findById(donationId);
      return await fallbackMatchingService.findMatches(donation);
    }
  }

  async calculateAIMatches(donation, donationEmbedding) {
    const recipients = await User.find({
      role: "recipient",
      "recipientDetails.verificationStatus": "verified",
      "recipientDetails.isActive": true,
    }).populate("recipientDetails");

    const matches = [];
    console.log(`🔍 Checking ${recipients.length} verified recipients`);

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

        // Check if recipient has capacity
        if (currentLoad >= capacity) {
          console.log(
            `⛔ Recipient ${recipient._id} at capacity: ${currentLoad}/${capacity}`
          );
          continue;
        }

        // Calculate semantic match
        const recipientText = `${
          recipient.recipientDetails.organizationName
        } ${(recipient.recipientDetails.dietaryRestrictions || []).join(" ")} ${
          recipient.recipientDetails.organizationType || ""
        } ${(recipient.recipientDetails.preferredFoodTypes || []).join(" ")}`;

        let semanticScore = 0.5; // Default score
        try {
          const recipientEmbedding = await this.getEmbedding(recipientText);
          semanticScore = this.cosineSimilarity(
            donationEmbedding,
            recipientEmbedding
          );
        } catch (embeddingError) {
          console.log(
            `⚠️ Embedding failed for recipient ${recipient._id}, using default score`
          );
        }

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
          capacity
        );
        const preferenceScore = this.calculatePreferenceScore(
          donation,
          recipient
        );

        // Enhanced combined score with weights
        const totalScore =
          semanticScore * 0.3 +
          proximityScore * 0.25 +
          dietaryScore * 0.2 +
          capacityScore * 0.15 +
          preferenceScore * 0.1;

        console.log(
          `📊 Recipient ${
            recipient._id
          } scores: semantic=${semanticScore.toFixed(
            2
          )}, proximity=${proximityScore.toFixed(
            2
          )}, dietary=${dietaryScore.toFixed(
            2
          )}, capacity=${capacityScore.toFixed(
            2
          )}, preference=${preferenceScore.toFixed(
            2
          )}, total=${totalScore.toFixed(2)}`
        );

        if (totalScore > 0.3) {
          matches.push({
            recipient: recipient,
            semanticScore,
            proximityScore,
            dietaryScore,
            capacityScore,
            preferenceScore,
            totalScore,
            currentLoad,
            capacity,
            matchingMethod: "ai",
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

    return matches;
  }

  // NEW: Calculate preference score based on preferred food types
  calculatePreferenceScore(donation, recipient) {
    const preferredFoodTypes =
      recipient.recipientDetails?.preferredFoodTypes || [];
    const donationCategories = donation.categories || [];

    if (preferredFoodTypes.length === 0) return 0.5; // Neutral if no preferences

    let matchCount = 0;
    donationCategories.forEach((category) => {
      if (preferredFoodTypes.includes(category)) {
        matchCount++;
      }
    });

    return matchCount / Math.max(donationCategories.length, 1);
  }

  // FIXED: Enhanced capacity score calculation
  calculateCapacityScore(currentLoad, capacity) {
    if (!capacity || capacity === 0) return 0.5;

    const utilization = currentLoad / capacity;

    // More granular capacity scoring
    if (utilization >= 1.0) return 0.0; // No capacity
    if (utilization >= 0.9) return 0.1; // Almost full
    if (utilization >= 0.8) return 0.3; // Very limited
    if (utilization >= 0.6) return 0.5; // Limited
    if (utilization >= 0.4) return 0.7; // Moderate
    if (utilization >= 0.2) return 0.9; // Good capacity
    return 1.0; // Plenty of capacity
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
          donationTags.some((tag) =>
            tag.toLowerCase().includes(conflict.toLowerCase())
          ) ||
          donationCategories.some((cat) =>
            cat.toLowerCase().includes(conflict.toLowerCase())
          )
      );

      if (hasConflict) {
        compatibility *= 0.1; // Severe penalty for dietary conflicts
        console.log(
          `⚠️ Dietary conflict: ${restriction} for recipient ${recipient._id}`
        );
      }
    }

    return compatibility;
  }

  // NEW: Generate human-readable match reasons
  generateMatchReasons(match) {
    const reasons = [];

    if (match.semanticScore > 0.7) {
      reasons.push("High semantic match");
    }

    if (match.proximityScore > 0.8) {
      reasons.push("Close proximity");
    }

    if (match.dietaryScore > 0.9) {
      reasons.push("Excellent dietary compatibility");
    }

    if (match.capacityScore > 0.8) {
      reasons.push("Good capacity availability");
    }

    if (match.preferenceScore > 0.7) {
      reasons.push("Matches preferred food types");
    }

    if (reasons.length === 0) {
      reasons.push("Good overall match");
    }

    return reasons;
  }
}

module.exports = new MatchingService();
