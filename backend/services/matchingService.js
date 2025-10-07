const { HfInference } = require("@huggingface/inference");
const Donation = require("../models/Donation");
const User = require("../models/User");

class MatchingService {
  constructor() {
    this.hf = new HfInference(process.env.HUGGINGFACE_TOKEN);
  }

  // Convert text to embeddings using Sentence Transformers
  async getEmbedding(text) {
    try {
      const response = await this.hf.featureExtraction({
        model: "sentence-transformers/all-MiniLM-L6-v2",
        inputs: text,
      });
      return response;
    } catch (error) {
      console.error("Embedding generation error:", error);
      throw new Error("Failed to generate text embeddings");
    }
  }

  // Calculate cosine similarity between vectors
  cosineSimilarity(vecA, vecB) {
    const dotProduct = vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
    const normA = Math.sqrt(vecA.reduce((sum, a) => sum + a * a, 0));
    const normB = Math.sqrt(vecB.reduce((sum, b) => sum + b * b, 0));
    return dotProduct / (normA * normB);
  }

  // Find best matches for a donation
  async findBestMatches(donationId) {
    const donation = await Donation.findById(donationId).populate("donor");
    if (!donation) throw new Error("Donation not found");

    // Get donation embedding
    const donationText = `${donation.aiDescription} ${donation.categories.join(
      " "
    )} ${donation.tags.join(" ")}`;
    const donationEmbedding = await this.getEmbedding(donationText);

    // Get all verified recipients
    const recipients = await User.find({
      role: "recipient",
      "recipientDetails.verificationStatus": "verified",
    }).populate("recipientDetails");

    const matches = [];

    for (const recipient of recipients) {
      // Check capacity
      const currentLoad = await Donation.countDocuments({
        acceptedBy: recipient._id,
        status: { $in: ["active", "matched", "scheduled"] },
      });

      if (currentLoad >= recipient.recipientDetails.capacity) {
        continue; // Skip if at capacity
      }

      // Calculate semantic match
      const recipientText = `${
        recipient.recipientDetails.organizationName
      } ${recipient.recipientDetails.dietaryRestrictions.join(" ")}`;
      const recipientEmbedding = await this.getEmbedding(recipientText);

      const semanticScore = this.cosineSimilarity(
        donationEmbedding,
        recipientEmbedding
      );

      // Calculate proximity score (simplified - would use actual coordinates)
      const proximityScore = this.calculateProximityScore(
        donation.location,
        recipient.recipientDetails.address
      );

      // Combined score
      const totalScore = semanticScore * 0.6 + proximityScore * 0.4;

      matches.push({
        recipient: recipient._id,
        recipientDetails: recipient.recipientDetails,
        semanticScore,
        proximityScore,
        totalScore,
        currentLoad,
        capacity: recipient.recipientDetails.capacity,
      });
    }

    // Return top 3 matches
    return matches.sort((a, b) => b.totalScore - a.totalScore).slice(0, 3);
  }

  calculateProximityScore(location1, location2) {
    // Simplified - in production, use actual distance calculation
    // Using Haversine formula or Google Distance Matrix API
    return Math.random() * 0.8 + 0.2; // Random score for demo
  }
}

module.exports = new MatchingService();
