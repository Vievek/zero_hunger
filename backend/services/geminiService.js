const { GoogleGenerativeAI } = require("@google/generative-ai");
const axios = require("axios");
const crypto = require("crypto");
const cacheManager = require("../utils/cacheManager");

class GeminiAIService {
  constructor() {
    this.genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    this.model = this.genAI.getGenerativeModel({
      model: "gemini-2.0-flash-exp",
      generationConfig: {
        temperature: 0.2,
        topK: 20,
        topP: 0.8,
        maxOutputTokens: 1024,
      },
      safetySettings: [
        {
          category: "HARM_CATEGORY_HARASSMENT",
          threshold: "BLOCK_MEDIUM_AND_ABOVE",
        },
        {
          category: "HARM_CATEGORY_HATE_SPEECH",
          threshold: "BLOCK_MEDIUM_AND_ABOVE",
        },
      ],
    });

    this.FOOD_SAFETY_KNOWLEDGE = {
      sources: [
        "World Health Organization (WHO) - Food Safety Guidelines",
        "US FDA - Food Code and Safety Standards",
        "USDA - Food Safety and Inspection Service",
        "European Food Safety Authority (EFSA)",
        "Food Standards Australia New Zealand (FSANZ)",
        "CDC - Food Safety Guidelines",
      ],
      temperatureDangerZone: "4°C to 60°C (40°F to 140°F)",
      maxRefrigerationTime: "2 hours for perishables above danger zone",
      reheatingTemperature: "74°C (165°F) for leftovers",
    };
  }

  async analyzeFoodImages(images) {
    // Create a unique cache key using hash of image data
    const imagesHash = crypto
      .createHash("sha256")
      .update(JSON.stringify(images))
      .digest("hex")
      .substring(0, 16);
    const cacheKey = `food_analysis_${imagesHash}`;
    const cached = await cacheManager.get(cacheKey);
    if (cached) return cached;

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
        9. Recommended urgency level (critical, high, normal)

        JSON Format:
        {
          "description": "string describing all food items in detail",
          "categories": ["array of categories"],
          "allergens": ["array of allergens"],
          "dietaryInfo": ["array of dietary classifications"],
          "freshnessScore": number between 0.1 and 1.0,
          "safetyWarnings": ["array of warnings or empty array"],
          "suggestedHandling": "string with handling instructions",
          "estimatedShelfLife": "string describing shelf life",
          "urgency": "critical|high|normal"
        }

        Be accurate and conservative in your assessments, especially for food safety.
      `;

      const imageParts = await Promise.all(
        images.map(async (imageUrl) => {
          try {
            if (imageUrl.startsWith("data:")) {
              const [header, base64Data] = imageUrl.split(",");
              const mimeType = header.match(/:(.*?);/)[1];

              return {
                inlineData: {
                  data: base64Data,
                  mimeType: mimeType || "image/jpeg",
                },
              };
            } else {
              const response = await axios.get(imageUrl, {
                responseType: "arraybuffer",
                timeout: 30000,
              });

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

      // Set default urgency if not provided
      if (!analysisResult.urgency) {
        analysisResult.urgency =
          analysisResult.freshnessScore > 0.7
            ? "normal"
            : analysisResult.freshnessScore > 0.4
            ? "high"
            : "critical";
      }

      await cacheManager.set(cacheKey, analysisResult, 3600); // Cache for 1 hour
      return analysisResult;
    } catch (error) {
      console.error("Gemini AI analysis error:", error);

      // Enhanced fallback analysis
      const fallback = {
        description: "Food items - manual description required",
        categories: ["other"],
        allergens: [],
        dietaryInfo: [],
        freshnessScore: 0.5,
        safetyWarnings: [
          "AI analysis unavailable - manual inspection recommended",
        ],
        suggestedHandling:
          "Handle with standard food safety precautions. Keep refrigerated and consume quickly.",
        estimatedShelfLife: "4-6 hours",
        urgency: "normal",
      };

      await cacheManager.set(cacheKey, fallback, 600); // Cache fallback for 10 minutes
      return fallback;
    }
  }

  async generateFoodSafetyInfo(foodType, question, context = {}) {
    // Create a unique cache key using full question hash instead of truncated base64
    const questionHash = crypto
      .createHash("sha256")
      .update(question)
      .digest("hex")
      .substring(0, 16);
    const contextHash = crypto
      .createHash("sha256")
      .update(JSON.stringify(context))
      .digest("hex")
      .substring(0, 8);
    const cacheKey = `safety_info_${foodType}_${questionHash}_${contextHash}`;
    const cached = await cacheManager.get(cacheKey);
    if (cached) return cached;

    try {
      const prompt = `
        You are a certified food safety expert. Provide a CONCISE, direct answer to the user's question.
        Focus only on what the user specifically asked for.

        FOOD TYPE: ${foodType}
        QUESTION: ${question}
        CONTEXT: ${JSON.stringify(context)}

        REQUIREMENTS:
        1. Answer directly and concisely - maximum 2-3 sentences
        2. Provide only the essential information the user needs
        3. No lists, no guidelines, no additional tips
        4. Just answer the specific question
        5. If temperature is relevant, include only the critical temperature
        6. If time is relevant, include only the critical time limit

        Return ONLY a simple JSON with the answer:
        {
          "answer": "Your concise answer here"
        }

        Do NOT include any other fields. Just the answer.
      `;

      const result = await this.model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new Error("AI response is not valid JSON");
      }

      let safetyInfo = JSON.parse(jsonMatch[0]);

      // Ensure we only have the answer field
      const cleanResponse = {
        answer:
          safetyInfo.answer || this.getSimpleFallbackAnswer(foodType, question),
      };

      await cacheManager.set(cacheKey, cleanResponse, 1800); // Cache for 30 minutes
      return cleanResponse;
    } catch (error) {
      console.error("Food safety info generation error:", error);

      const fallback = {
        answer: this.getSimpleFallbackAnswer(foodType, question),
      };

      await cacheManager.set(cacheKey, fallback, 600); // Cache fallback for 10 minutes
      return fallback;
    }
  }

  getSimpleFallbackAnswer(foodType, question) {
    return `For ${
      foodType || "food safety"
    }, keep hot foods above 60°C and cold foods below 4°C. Refrigerate within 2 hours. When in doubt, throw it out.`;
  }

  async generateQRCodeContent(donationDetails) {
    // Create a unique cache key using hash of donation details
    const detailsHash = crypto
      .createHash("sha256")
      .update(JSON.stringify(donationDetails))
      .digest("hex")
      .substring(0, 16);
    const cacheKey = `qr_content_${detailsHash}`;
    const cached = await cacheManager.get(cacheKey);
    if (cached) return cached;

    try {
      const prompt = `
        Generate EXTREMELY CONCISE food safety handling instructions for a QR code label.
        MAXIMUM 120 characters total.

        Food: ${donationDetails.description}
        Categories: ${donationDetails.categories?.join(", ") || "Various"}
        Allergens: ${donationDetails.allergens?.join(", ") || "None listed"}
        Food Type: ${donationDetails.foodType || "General"}
        Special Instructions: ${
          donationDetails.handlingInstructions || "Standard handling"
        }

        FOCUS ON:
        - Critical safety instructions only
        - Temperature requirements
        - Time limits
        - Allergen warnings if present

        Format: Very short, action-oriented instructions.
        Include only the most essential safety information.

        Return ONLY the label text, no JSON, no explanations.
      `;

      const result = await this.model.generateContent(prompt);
      const response = await result.response;

      let labelText = response.text().trim();

      // Ensure character limit and basic safety message
      if (labelText.length > 120) {
        labelText = labelText.substring(0, 117) + "...";
      }

      // Enhanced fallback with safety focus
      if (!labelText || labelText.length < 10) {
        const hasAllergens =
          donationDetails.allergens && donationDetails.allergens.length > 0;
        const allergenWarning = hasAllergens
          ? `Contains: ${donationDetails.allergens.join(", ")}. `
          : "";
        labelText = `${allergenWarning}Keep refrigerated <4°C. Use within 24h. When in doubt, discard.`;
      }

      await cacheManager.set(cacheKey, labelText, 86400); // Cache for 24 hours
      return labelText;
    } catch (error) {
      console.error("QR code content generation error:", error);

      const hasAllergens =
        donationDetails.allergens && donationDetails.allergens.length > 0;
      const allergenWarning = hasAllergens
        ? `Contains: ${donationDetails.allergens.join(", ")}. `
        : "";
      const fallback = `${allergenWarning}Refrigerate below 4°C. Use within 24h. Check before use.`;

      await cacheManager.set(cacheKey, fallback, 86400);
      return fallback;
    }
  }

  async generateSafetyChecklist(foodType = "general") {
    const cacheKey = `checklist_${foodType}`;
    const cached = await cacheManager.get(cacheKey);
    if (cached) return cached;

    try {
      const prompt = `
        Create a specific food safety checklist for: ${foodType}
        
        Provide 5-7 critical checklist items that focus on:
        - Visual inspection criteria
        - Temperature verification  
        - Packaging and storage assessment
        - Time and handling factors
        - Specific risks for this food type

        Be specific and actionable. Format as JSON array:
        ["checklist item 1", "checklist item 2", ...]
        
        Base on established food safety practices from WHO and FDA.
      `;

      const result = await this.model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      const jsonMatch = text.match(/\[[\s\S]*\]/);
      if (jsonMatch) {
        const checklist = JSON.parse(jsonMatch[0]);
        await cacheManager.set(cacheKey, checklist, 86400); // Cache for 24 hours
        return checklist;
      }

      throw new Error("Invalid checklist format");
    } catch (error) {
      console.error("Checklist generation error:", error);

      const fallback = this.getFallbackChecklist(foodType);
      await cacheManager.set(cacheKey, fallback, 86400);
      return fallback;
    }
  }

  getFallbackChecklist(foodType) {
    return [
      "Verify temperature: Below 4°C or above 60°C",
      "Check for unusual odors, colors, or textures",
      "Inspect packaging for damage or leaks",
      "Confirm storage time within safe limits",
      "Check separation from raw food contamination",
      "Validate handling procedures were followed",
      "Ensure allergen awareness and labeling",
    ];
  }

  // Method to clear all AI-related cache entries
  async clearCache() {
    try {
      await cacheManager.flush();
      console.log("AI service cache cleared successfully");
      return { success: true, message: "Cache cleared successfully" };
    } catch (error) {
      console.error("Error clearing AI service cache:", error);
      return {
        success: false,
        message: "Failed to clear cache",
        error: error.message,
      };
    }
  }

  // Method to get cache statistics
  async getCacheStats() {
    try {
      const stats = await cacheManager.getStats();
      return { success: true, stats };
    } catch (error) {
      console.error("Error getting cache stats:", error);
      return {
        success: false,
        message: "Failed to get cache stats",
        error: error.message,
      };
    }
  }
}

module.exports = new GeminiAIService();
