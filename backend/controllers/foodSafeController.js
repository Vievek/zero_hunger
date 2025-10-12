const geminiService = require("../services/geminiService");
const QRCode = require("qrcode");
const Donation = require("../models/Donation");

// Controller functions
const askFoodSafetyQuestion = async (req, res) => {
  try {
    const { question, foodType = "general", context } = req.body;

    if (!question || question.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: "Question is required",
      });
    }

    if (question.length > 500) {
      return res.status(400).json({
        success: false,
        message: "Question too long. Maximum 500 characters.",
      });
    }

    console.log(`FoodSafe AI Question: ${foodType} - ${question}`);

    const response = await geminiService.generateFoodSafetyInfo(
      foodType,
      question,
      context
    );

    // Add timestamp to response
    response.timestamp = new Date().toISOString();

    res.json({
      success: true,
      data: response,
    });
  } catch (error) {
    console.error("FoodSafe AI Error:", error);

    const fallbackResponse = {
      answer:
        "I'm currently unable to access food safety information. Please try again later or consult local food safety authorities for immediate concerns.",
      timestamp: new Date().toISOString(),
    };

    res.status(200).json({
      success: true,
      data: fallbackResponse,
    });
  }
};

const generateFoodLabel = async (req, res) => {
  try {
    const { donationId } = req.params;
    const {
      description,
      categories,
      allergens,
      handlingInstructions,
      foodType,
    } = req.body;

    let donationDetails = {
      description: description || "Food Donation",
      categories: categories || ["general"],
      allergens: allergens || [],
      handlingInstructions: handlingInstructions,
      foodType: foodType || "general",
    };

    if (donationId && donationId !== "undefined") {
      try {
        const donation = await Donation.findById(donationId);
        if (donation) {
          donationDetails = {
            description:
              donation.aiDescription ||
              donation.description ||
              donationDetails.description,
            categories:
              donation.categories.length > 0
                ? donation.categories
                : donationDetails.categories,
            allergens:
              donation.aiAnalysis?.allergens || donationDetails.allergens,
            handlingInstructions:
              donation.aiAnalysis?.suggestedHandling ||
              donationDetails.handlingInstructions,
            foodType: donation.categories[0] || donationDetails.foodType,
          };
        }
      } catch (dbError) {
        console.log("Could not fetch donation details, using provided data");
      }
    }

    const labelData = await geminiService.generateQRCodeContent(
      donationDetails
    );

    const qrCodeData = {
      type: "food_safety_label",
      description: donationDetails.description,
      categories: donationDetails.categories,
      allergens: donationDetails.allergens,
      handling: donationDetails.handlingInstructions,
      foodType: donationDetails.foodType,
      generatedAt: new Date().toISOString(),
      safetyInfo: "Handle with food safety precautions",
    };

    const qrCodeDataUrl = await QRCode.toDataURL(JSON.stringify(qrCodeData));

    res.json({
      success: true,
      data: {
        labelText: labelData,
        qrCode: qrCodeDataUrl,
        donationId: donationId,
      },
    });
  } catch (error) {
    console.error("Food Label Generation Error:", error);

    const hasAllergens =
      donationDetails.allergens && donationDetails.allergens.length > 0;
    const allergenWarning = hasAllergens
      ? `Contains: ${donationDetails.allergens.join(", ")}. `
      : "";
    const fallback = `${allergenWarning}Refrigerate below 4°C. Use within 24h. Check before use.`;

    const fallbackLabel = {
      labelText: fallback,
      qrCode: await QRCode.toDataURL(
        "Food Safety: Keep refrigerated, consume quickly, check allergens"
      ),
    };

    res.status(200).json({
      success: true,
      data: fallbackLabel,
    });
  }
};

const getSafetyChecklist = async (req, res) => {
  try {
    const { foodType } = req.query;

    const checklist = await geminiService.generateSafetyChecklist(
      foodType || "general"
    );

    res.json({
      success: true,
      data: {
        checklist,
      },
    });
  } catch (error) {
    console.error("Checklist Generation Error:", error);

    res.json({
      success: true,
      data: {
        checklist: [
          "Check temperature: Keep below 4°C (40°F) or above 60°C (140°F)",
          "Verify packaging integrity and cleanliness",
          "Check for unusual odors, colors, or textures",
          "Ensure proper separation from raw foods",
          "Confirm consumption timeframe is appropriate",
          "Validate handling procedures were followed",
          "Check allergen information and labeling",
        ],
      },
    });
  }
};

const getQuickReference = async (req, res) => {
  try {
    const { foodType } = req.query;

    const quickRef = {
      temperatureDangerZone: "4°C to 60°C (40°F to 140°F)",
      maxRefrigerationTime: "2 hours for perishables above danger zone",
      reheatingTemperature: "74°C (165°F) for leftovers",
      criticalTemperatures: {
        poultry: "74°C (165°F)",
        groundMeat: "71°C (160°F)",
        beefSteaks: "63°C (145°F)",
        pork: "63°C (145°F)",
        fish: "63°C (145°F)",
        eggs: "71°C (160°F)",
        leftovers: "74°C (165°F)",
      },
    };

    if (foodType && quickRef.criticalTemperatures[foodType]) {
      quickRef.specificGuidance = {
        safeTemperature: quickRef.criticalTemperatures[foodType],
      };
    }

    res.json({
      success: true,
      data: quickRef,
    });
  } catch (error) {
    console.error("Quick reference error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to generate quick reference",
    });
  }
};

const clearAICache = async (req, res) => {
  try {
    const result = await geminiService.clearCache();

    res.json({
      success: true,
      message: "AI cache cleared successfully",
      data: result,
    });
  } catch (error) {
    console.error("Clear cache error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to clear AI cache",
      error: error.message,
    });
  }
};

const getCacheStats = async (req, res) => {
  try {
    const result = await geminiService.getCacheStats();

    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error("Get cache stats error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to get cache statistics",
      error: error.message,
    });
  }
};

// Export all functions properly
module.exports = {
  askFoodSafetyQuestion,
  generateFoodLabel,
  getSafetyChecklist,
  getQuickReference,
  clearAICache,
  getCacheStats,
};
