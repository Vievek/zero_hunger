const geminiService = require("../services/geminiService");
const QRCode = require("qrcode");
const Donation = require("../models/Donation");

// Enhanced food safety knowledge base
const FOOD_SAFETY_KNOWLEDGE_BASE = {
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

    response.sources = FOOD_SAFETY_KNOWLEDGE_BASE.sources;
    response.timestamp = new Date().toISOString();
    response.confidenceScore = response.confidenceScore || 0.95;

    if (FOOD_SAFETY_KNOWLEDGE_BASE.criticalTemperatures[foodType]) {
      response.criticalTemperature =
        FOOD_SAFETY_KNOWLEDGE_BASE.criticalTemperatures[foodType];
    }

    res.json({
      success: true,
      data: response,
    });
  } catch (error) {
    console.error("FoodSafe AI Error:", error);

    const fallbackResponse = {
      answer:
        "I'm currently unable to access detailed food safety information. However, based on established food safety guidelines:\n\n• Keep hot foods hot (above 60°C/140°F) and cold foods cold (below 4°C/40°F)\n• When in doubt, throw it out - this is always the safest approach\n• Wash hands and surfaces thoroughly and often\n• Separate raw and cooked foods to prevent cross-contamination\n• Cook foods to proper internal temperatures\n• Refrigerate promptly within 2 hours (1 hour if above 32°C/90°F)",
      safetyGuidelines: [
        "Keep perishables out of temperature danger zone (4°C-60°C)",
        "Use refrigerated leftovers within 3-4 days",
        "Reheat leftovers to 74°C (165°F) throughout",
        "When in doubt, discard questionable food immediately",
      ],
      storageRecommendations: [
        "Refrigerate at or below 4°C (40°F)",
        "Freeze at or below -18°C (0°F)",
        "Use airtight containers for storage",
        "Label and date all stored foods clearly",
      ],
      temperatureGuidelines: [
        "Keep hot foods above 60°C (140°F)",
        "Keep cold foods below 4°C (40°F)",
        "Reheat to 74°C (165°F) if applicable",
      ],
      sources: FOOD_SAFETY_KNOWLEDGE_BASE.sources,
      additionalTips: [
        "Consult local food safety authorities for specific concerns",
        "Follow manufacturer storage instructions when available",
        "Trust your senses - unusual odors, colors, or textures indicate spoilage",
      ],
      confidenceScore: 0.7,
    };

    res.status(200).json({
      success: true,
      data: fallbackResponse,
      note: "Using enhanced fallback food safety information",
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
      criticalTemperature:
        FOOD_SAFETY_KNOWLEDGE_BASE.criticalTemperatures[
          donationDetails.foodType
        ],
    };

    const qrCodeDataUrl = await QRCode.toDataURL(JSON.stringify(qrCodeData));

    const printableLabel = {
      title: "FoodSafe AI Handling Instructions",
      description: donationDetails.description,
      categories: donationDetails.categories.join(", "),
      allergens:
        donationDetails.allergens.length > 0
          ? `Contains: ${donationDetails.allergens.join(", ")}`
          : "No major allergens detected",
      handlingInstructions: labelData,
      safetyGuidelines: [
        "Keep refrigerated below 4°C (40°F) unless otherwise specified",
        "Consume within recommended timeframe",
        "Reheat to 74°C (165°F) if applicable",
        "When in doubt, throw it out - safety first",
      ],
      criticalInfo: FOOD_SAFETY_KNOWLEDGE_BASE.criticalTemperatures[
        donationDetails.foodType
      ]
        ? `Safe cooking temperature: ${
            FOOD_SAFETY_KNOWLEDGE_BASE.criticalTemperatures[
              donationDetails.foodType
            ]
          }`
        : "Follow standard food safety practices",
      qrCode: qrCodeDataUrl,
      generatedAt: new Date().toLocaleString(),
      sources: FOOD_SAFETY_KNOWLEDGE_BASE.sources,
    };

    res.json({
      success: true,
      data: {
        labelText: labelData,
        qrCode: qrCodeDataUrl,
        printableLabel: printableLabel,
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
      printableLabel: {
        title: "Food Safety Label",
        description: "Food Donation",
        handlingInstructions: fallback,
        safetyGuidelines: [
          "Keep refrigerated below 4°C (40°F)",
          "Consume within 24 hours",
          "Check for allergens before consumption",
          "When in doubt, throw it out",
        ],
      },
    };

    res.status(200).json({
      success: true,
      data: fallbackLabel,
      note: "Generated enhanced safety label",
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
        sources: FOOD_SAFETY_KNOWLEDGE_BASE.sources,
        applicableStandards: [
          "WHO Food Safety Guidelines",
          "US FDA Food Code",
          "USDA Food Safety",
          "HACCP Principles",
          "Local Food Safety Regulations",
        ],
        criticalPoints: FOOD_SAFETY_KNOWLEDGE_BASE.criticalTemperatures[
          foodType
        ]
          ? [
              `Cooking Temperature: ${FOOD_SAFETY_KNOWLEDGE_BASE.criticalTemperatures[foodType]}`,
            ]
          : ["Maintain safe temperatures throughout handling"],
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
        sources: FOOD_SAFETY_KNOWLEDGE_BASE.sources,
        note: "Enhanced safety checklist",
      },
    });
  }
};

const getQuickReference = async (req, res) => {
  try {
    const { foodType } = req.query;

    const quickRef = {
      temperatureDangerZone: FOOD_SAFETY_KNOWLEDGE_BASE.temperatureDangerZone,
      maxRefrigerationTime: FOOD_SAFETY_KNOWLEDGE_BASE.maxRefrigerationTime,
      reheatingTemperature: FOOD_SAFETY_KNOWLEDGE_BASE.reheatingTemperature,
      criticalTemperatures: FOOD_SAFETY_KNOWLEDGE_BASE.criticalTemperatures,
      generalGuidelines: [
        "Wash hands and surfaces often",
        "Separate raw and cooked foods",
        "Cook to proper temperatures",
        "Refrigerate promptly",
        "When in doubt, throw it out",
      ],
    };

    if (foodType && FOOD_SAFETY_KNOWLEDGE_BASE.criticalTemperatures[foodType]) {
      quickRef.specificGuidance = {
        safeTemperature:
          FOOD_SAFETY_KNOWLEDGE_BASE.criticalTemperatures[foodType],
        storageTime: "Varies by food type - consult specific guidelines",
        handlingNotes: "Follow specific food type safety protocols",
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

// Export all functions properly
module.exports = {
  askFoodSafetyQuestion,
  generateFoodLabel,
  getSafetyChecklist,
  getQuickReference,
};
