const { GoogleGenerativeAI } = require("@google/generative-ai");
const axios = require("axios");

class GeminiAIService {
  constructor() {
    this.genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    this.model = this.genAI.getGenerativeModel({
      model: "gemini-1.5-flash",
      generationConfig: {
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      },
    });
  }

  // Analyze food images and generate description
  async analyzeFoodImages(images) {
    try {
      const prompt = `
        Analyze these food images and provide:
        1. Detailed description of the food items
        2. Food categories (e.g., vegetarian, non-vegetarian, baked goods, fruits)
        3. Allergens present (nuts, dairy, gluten, etc.)
        4. Dietary classifications (vegan, vegetarian, gluten-free, etc.)
        5. Estimated freshness and safe handling window
        6. Any safety concerns
        
        Format response as JSON:
        {
          "description": "string",
          "categories": ["string"],
          "allergens": ["string"],
          "dietaryInfo": ["string"],
          "freshnessScore": number,
          "safetyWarnings": ["string"],
          "suggestedHandling": "string",
          "estimatedShelfLife": "string"
        }
      `;

      // Convert images to Gemini format
      const imageParts = await Promise.all(
        images.map(async (imageUrl) => {
          const response = await axios.get(imageUrl, {
            responseType: "arraybuffer",
          });
          return {
            inlineData: {
              data: Buffer.from(response.data).toString("base64"),
              mimeType: "image/jpeg",
            },
          };
        })
      );

      const result = await this.model.generateContent([prompt, ...imageParts]);
      const response = await result.response;
      const text = response.text();

      // Extract JSON from response
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
      }

      throw new Error("Invalid AI response format");
    } catch (error) {
      console.error("Gemini AI analysis error:", error);
      throw new Error("Failed to analyze food images");
    }
  }

  // Generate food safety information
  async generateFoodSafetyInfo(foodType, question) {
    const prompt = `
      As a food safety expert, provide accurate information about: ${foodType}
      Question: ${question}
      
      Provide:
      1. Clear, concise answer
      2. Safety guidelines
      3. Storage recommendations
      4. Source references (WHO, FDA guidelines)
      
      Format as JSON:
      {
        "answer": "string",
        "safetyGuidelines": ["string"],
        "storageRecommendations": ["string"],
        "sources": ["string"],
        "additionalTips": ["string"]
      }
    `;

    const result = await this.model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    const jsonMatch = text.match(/\{[\s\S]*\}/);
    return jsonMatch ? JSON.parse(jsonMatch[0]) : null;
  }

  // Generate QR code content for food labels
  async generateQRCodeContent(donationDetails) {
    const prompt = `
      Generate concise handling instructions for food donation:
      Food: ${donationDetails.description}
      Categories: ${donationDetails.categories.join(", ")}
      Allergens: ${donationDetails.allergens.join(", ")}
      
      Create a short label text (max 150 characters) including:
      - Food type
      - Key allergens
      - Handling instructions
      - Expiry timeframe
      
      Make it very concise for QR code display.
    `;

    const result = await this.model.generateContent(prompt);
    const response = await result.response;
    return response.text().trim();
  }
}

module.exports = new GeminiAIService();
