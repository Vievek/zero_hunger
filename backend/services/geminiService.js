const { GoogleGenerativeAI } = require("@google/generative-ai");
const axios = require("axios");

class GeminiAIService {
  constructor() {
    this.genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    this.model = this.genAI.getGenerativeModel({
      model: "gemini-1.5-flash",
      generationConfig: {
        temperature: 0.2, // Lower temperature for more factual responses
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

    // Food safety authority knowledge base for chatbot
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

  // Analyze food images and generate description - UNCHANGED
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

  // FIXED: Generate food safety information with authority references (only 2 parameters)
  async generateFoodSafetyInfo(foodType, question) {
    try {
      const prompt = `
        You are a certified food safety expert working with global food safety authorities. 
        Provide accurate, evidence-based food safety information.

        FOOD TYPE: ${foodType}
        QUESTION: ${question}

        CRITICAL FOOD SAFETY PARAMETERS:
        - Temperature Danger Zone: ${this.FOOD_SAFETY_KNOWLEDGE.temperatureDangerZone}
        - Maximum refrigeration time: ${this.FOOD_SAFETY_KNOWLEDGE.maxRefrigerationTime} 
        - Reheating temperature: ${this.FOOD_SAFETY_KNOWLEDGE.reheatingTemperature}

        REQUIREMENTS:
        1. Provide specific, actionable advice
        2. Reference established food safety standards
        3. Include temperature guidelines where applicable
        4. Mention time limits for storage
        5. Address common food safety misconceptions
        6. Be conservative in recommendations (when in doubt, recommend discarding)
        7. Cite specific food safety authorities

        Respond in this EXACT JSON format:
        {
          "answer": "comprehensive answer with specific guidelines and authority references",
          "safetyGuidelines": ["array of 3-5 critical safety rules"],
          "storageRecommendations": ["array of 3-5 storage tips"], 
          "temperatureGuidelines": ["array of temperature rules"],
          "timeLimits": ["array of time-based safety rules"],
          "commonMistakes": ["array of common errors to avoid"],
          "additionalTips": ["array of extra safety considerations"],
          "authorityReferences": ["array of which authorities this follows"]
        }

        Base your response on established food safety science from WHO, FDA, USDA, and other global authorities.
        Be concise but thorough. Prioritize safety over everything.
      `;

      const result = await this.model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      // Enhanced JSON parsing with fallbacks
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new Error("AI response is not valid JSON");
      }

      let safetyInfo = JSON.parse(jsonMatch[0]);

      // Ensure all required fields exist with proper fallbacks
      safetyInfo = {
        answer:
          safetyInfo.answer ||
          "Follow standard food safety practices. Keep foods at safe temperatures and when in doubt, throw it out.",
        safetyGuidelines: safetyInfo.safetyGuidelines || [
          "Keep foods at safe temperatures (below 4°C or above 60°C)",
          "Practice good hygiene and prevent cross-contamination",
          "When in doubt, throw it out - better safe than sorry",
        ],
        storageRecommendations: safetyInfo.storageRecommendations || [
          "Refrigerate promptly within 2 hours",
          "Use airtight containers for storage",
          "Label with dates and contents",
        ],
        temperatureGuidelines: safetyInfo.temperatureGuidelines || [
          "Keep hot foods hot (>60°C/140°F)",
          "Keep cold foods cold (<4°C/40°F)",
          "Reheat leftovers to 74°C/165°F",
        ],
        timeLimits: safetyInfo.timeLimits || [
          "Discard perishables left in danger zone >2 hours",
          "Use refrigerated leftovers within 3-4 days",
          "Follow 'first in, first out' principle",
        ],
        commonMistakes: safetyInfo.commonMistakes || [
          "Tasting food to check if it's spoiled",
          "Ignoring unusual odors or colors",
          "Overcrowding refrigerator",
        ],
        additionalTips: safetyInfo.additionalTips || [
          "Consult local food safety authorities for specific concerns",
          "Follow manufacturer storage instructions when available",
        ],
        authorityReferences:
          safetyInfo.authorityReferences || this.FOOD_SAFETY_KNOWLEDGE.sources,
      };

      // Add the knowledge base sources to ensure they're always included
      safetyInfo.sources = this.FOOD_SAFETY_KNOWLEDGE.sources;

      return safetyInfo;
    } catch (error) {
      console.error("Food safety info generation error:", error);

      // Enhanced fallback response with authority references
      return {
        answer:
          "I'm currently unable to access detailed food safety information. However, based on established food safety guidelines from WHO and FDA:\n\n• Keep hot foods hot (above 60°C/140°F) and cold foods cold (below 4°C/40°F)\n• When in doubt, throw it out - this is the safest approach\n• Wash hands and surfaces often\n• Separate raw and cooked foods\n• Cook to proper temperatures\n• Refrigerate promptly within 2 hours",
        safetyGuidelines: [
          "Keep perishables out of temperature danger zone (4°C-60°C)",
          "Use refrigerated leftovers within 3-4 days",
          "Reheat leftovers to 74°C (165°F)",
          "When in doubt, discard questionable food",
        ],
        storageRecommendations: [
          "Refrigerate at or below 4°C (40°F)",
          "Freeze at or below -18°C (0°F)",
          "Use airtight containers for storage",
          "Label and date all stored foods",
        ],
        temperatureGuidelines: [
          "Keep hot foods above 60°C (140°F)",
          "Keep cold foods below 4°C (40°F)",
          "Reheat to 74°C (165°F) if applicable",
        ],
        timeLimits: [
          "Maximum 2 hours in temperature danger zone",
          "3-4 days for refrigerated leftovers",
          "Follow 'first in, first out' principle",
        ],
        commonMistakes: [
          "Tasting food to check spoilage",
          "Ignoring unusual odors or colors",
          "Overcrowding refrigerator",
        ],
        additionalTips: [
          "Consult local food safety authorities for specific concerns",
          "Follow manufacturer storage instructions when available",
        ],
        authorityReferences: this.FOOD_SAFETY_KNOWLEDGE.sources,
        sources: this.FOOD_SAFETY_KNOWLEDGE.sources,
        confidenceScore: 0.8,
      };
    }
  }

  // ENHANCED: Generate QR code content for food labels with safety focus
  async generateQRCodeContent(donationDetails) {
    try {
      const prompt = `
        Generate EXTREMELY CONCISE food safety handling instructions for a QR code label.
        MAXIMUM 120 characters total.

        Food: ${donationDetails.description}
        Categories: ${donationDetails.categories?.join(", ") || "Various"}
        Allergens: ${donationDetails.allergens?.join(", ") || "None listed"}
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

      return labelText;
    } catch (error) {
      console.error("QR code content generation error:", error);

      // Enhanced safety-focused fallback
      const hasAllergens =
        donationDetails.allergens && donationDetails.allergens.length > 0;
      const allergenWarning = hasAllergens
        ? `Contains: ${donationDetails.allergens.join(", ")}. `
        : "";
      return `${allergenWarning}Refrigerate below 4°C. Use within 24h. Check before use.`;
    }
  }

  // NEW: Generate food safety checklist for different food types
  async generateSafetyChecklist(foodType = "general") {
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
        return JSON.parse(jsonMatch[0]);
      }

      // Enhanced fallback checklist with food safety focus
      return [
        "Verify temperature: Below 4°C or above 60°C",
        "Check for unusual odors, colors, or textures",
        "Inspect packaging for damage or leaks",
        "Confirm storage time within safe limits",
        "Check separation from raw food contamination",
        "Validate handling procedures were followed",
        "Ensure allergen awareness and labeling",
      ];
    } catch (error) {
      console.error("Checklist generation error:", error);

      // Comprehensive fallback checklist
      return [
        "Temperature check: Ensure proper storage temperature",
        "Visual inspection: Look for spoilage signs",
        "Packaging integrity: Check for damage or leaks",
        "Time validation: Confirm within safe time limits",
        "Cross-contamination: Verify separation from raw foods",
        "Allergen check: Review for allergen presence",
        "Handling verification: Ensure proper handling procedures",
      ];
    }
  }
}

module.exports = new GeminiAIService();
