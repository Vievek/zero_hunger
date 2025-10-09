const { GoogleGenerativeAI } = require("@google/generative-ai");
const axios = require("axios");

class GeminiAIService {
  constructor() {
    this.genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    this.model = this.genAI.getGenerativeModel({
      model: "gemini-1.5-flash",
      generationConfig: {
        temperature: 0.4, // Lower temperature for more consistent results
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
        You are a food safety and analysis expert. Analyze these food images thoroughly and provide accurate information in JSON format.

        IMPORTANT: Return ONLY valid JSON, no other text.

        Analyze and provide:
        1. Detailed description of all visible food items (be specific about quantities, types, preparation)
        2. Food categories (choose from: prepared-meal, fruits, vegetables, baked-goods, dairy, meat, seafood, grains, beverages, other)
        3. Allergens present (choose from: nuts, dairy, gluten, eggs, soy, shellfish, fish, other)
        4. Dietary classifications (choose from: vegan, vegetarian, gluten-free, dairy-free, nut-free, other)
        5. Freshness assessment (score from 0.1 to 1.0, where 1.0 is freshest)
        6. Safety warnings if any (spoilage signs, improper storage, etc.)
        7. Suggested handling instructions
        8. Estimated shelf life in hours

        JSON Format:
        {
          "description": "string describing all food items in detail",
          "categories": ["array of categories"],
          "allergens": ["array of allergens"],
          "dietaryInfo": ["array of dietary classifications"],
          "freshnessScore": number between 0.1 and 1.0,
          "safetyWarnings": ["array of warnings or empty array"],
          "suggestedHandling": "string with handling instructions",
          "estimatedShelfLife": "string describing shelf life"
        }

        Be accurate and conservative in your assessments, especially for food safety.
      `;

      // Convert images to Gemini format
      const imageParts = await Promise.all(
        images.map(async (imageUrl) => {
          try {
            // Handle both URLs and base64 data
            if (imageUrl.startsWith("data:")) {
              // Base64 image data
              const [header, base64Data] = imageUrl.split(",");
              const mimeType = header.match(/:(.*?);/)[1];

              return {
                inlineData: {
                  data: base64Data,
                  mimeType: mimeType || "image/jpeg",
                },
              };
            } else {
              // URL - fetch the image
              const response = await axios.get(imageUrl, {
                responseType: "arraybuffer",
                timeout: 30000,
              });

              // Detect mime type from response or default to jpeg
              const mimeType = response.headers["content-type"] || "image/jpeg";

              return {
                inlineData: {
                  data: Buffer.from(response.data).toString("base64"),
                  mimeType: mimeType,
                },
              };
            }
          } catch (error) {
            console.error("Error processing image:", error);
            throw new Error(`Failed to process image: ${error.message}`);
          }
        })
      );

      const result = await this.model.generateContent([prompt, ...imageParts]);
      const response = await result.response;
      const text = response.text();

      // Clean the response and extract JSON
      const cleanedText = text.trim();
      const jsonMatch = cleanedText.match(/\{[\s\S]*\}/);

      if (!jsonMatch) {
        throw new Error("AI response is not valid JSON");
      }

      const analysisResult = JSON.parse(jsonMatch[0]);

      // Validate required fields
      const requiredFields = [
        "description",
        "categories",
        "allergens",
        "dietaryInfo",
        "freshnessScore",
      ];
      for (const field of requiredFields) {
        if (!analysisResult[field]) {
          throw new Error(`AI response missing required field: ${field}`);
        }
      }

      // Ensure freshnessScore is within valid range
      analysisResult.freshnessScore = Math.max(
        0.1,
        Math.min(1.0, analysisResult.freshnessScore)
      );

      return analysisResult;
    } catch (error) {
      console.error("Gemini AI analysis error:", error);

      // Return a fallback analysis if AI fails
      return {
        description: "Food items - manual description required",
        categories: ["other"],
        allergens: [],
        dietaryInfo: [],
        freshnessScore: 0.5,
        safetyWarnings: [
          "AI analysis unavailable - manual inspection recommended",
        ],
        suggestedHandling: "Handle with standard food safety precautions",
        estimatedShelfLife: "4-6 hours",
      };
    }
  }

  // Generate food safety information
  async generateFoodSafetyInfo(foodType, question) {
    try {
      const prompt = `
        As a food safety expert, provide accurate information about: ${foodType}
        Specific question: ${question}
        
        Provide response in JSON format:
        {
          "answer": "clear, concise answer to the question",
          "safetyGuidelines": ["array of specific safety guidelines"],
          "storageRecommendations": ["array of storage recommendations"],
          "sources": ["array of credible sources like WHO, FDA, USDA"],
          "additionalTips": ["array of additional safety tips"]
        }

        Be factual and reference established food safety guidelines.
      `;

      const result = await this.model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      const jsonMatch = text.match(/\{[\s\S]*\}/);
      return jsonMatch
        ? JSON.parse(jsonMatch[0])
        : {
            answer:
              "Unable to provide specific food safety information at this time.",
            safetyGuidelines: [
              "When in doubt, throw it out",
              "Keep hot foods hot and cold foods cold",
            ],
            storageRecommendations: [
              "Refrigerate promptly",
              "Use airtight containers",
            ],
            sources: ["General food safety guidelines"],
            additionalTips: [
              "Consult local food safety authorities for specific concerns",
            ],
          };
    } catch (error) {
      console.error("Food safety info generation error:", error);
      throw new Error("Failed to generate food safety information");
    }
  }

  // Generate QR code content for food labels
  async generateQRCodeContent(donationDetails) {
    try {
      const prompt = `
        Generate very concise handling instructions for food donation label (MAX 150 characters):
        
        Food: ${donationDetails.description}
        Categories: ${donationDetails.categories?.join(", ") || "Unknown"}
        Allergens: ${donationDetails.allergens?.join(", ") || "None detected"}
        
        Include: Food type, key allergens, basic handling instructions.
        Be extremely concise for QR code display.
        
        Return only the label text, no JSON.
      `;

      const result = await this.model.generateContent(prompt);
      const response = await result.response;

      let labelText = response.text().trim();

      // Ensure it's within character limit
      if (labelText.length > 150) {
        labelText = labelText.substring(0, 147) + "...";
      }

      return labelText;
    } catch (error) {
      console.error("QR code content generation error:", error);
      return `Food: ${donationDetails.description}. Handle with care. Check allergens.`;
    }
  }
}

module.exports = new GeminiAIService();
