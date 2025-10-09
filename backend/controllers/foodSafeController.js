const geminiService = require("../services/geminiService");
const QRCode = require("qrcode");
const Donation = require("../models/Donation");

// Curated food safety knowledge base
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
};

exports.askFoodSafetyQuestion = async (req, res) => {
  try {
    const { question, foodType = "general" } = req.body;

    // Validate input
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
      FOOD_SAFETY_KNOWLEDGE_BASE
    );

    // Add curated sources to response
    response.sources = FOOD_SAFETY_KNOWLEDGE_BASE.sources;
    response.timestamp = new Date().toISOString();
    response.confidenceScore = 0.95; // High confidence for food safety info

    res.json({
      success: true,
      data: response,
    });
  } catch (error) {
    console.error("FoodSafe AI Error:", error);

    // Fallback response with basic food safety info
    const fallbackResponse = {
      answer:
        "I'm currently unable to access detailed food safety information. However, here are essential food safety practices:\n\n• Keep hot foods hot (above 60°C/140°F) and cold foods cold (below 4°C/40°F)\n• When in doubt, throw it out\n• Wash hands and surfaces often\n• Separate raw and cooked foods\n• Cook to proper temperatures\n• Refrigerate promptly within 2 hours",
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
      sources: FOOD_SAFETY_KNOWLEDGE_BASE.sources,
      additionalTips: [
        "Consult local food safety authorities for specific concerns",
        "Follow manufacturer storage instructions when available",
      ],
      confidenceScore: 0.7,
    };

    res.status(200).json({
      success: true,
      data: fallbackResponse,
      note: "Using fallback food safety information",
    });
  }
};

exports.generateFoodLabel = async (req, res) => {
  try {
    const { donationId } = req.params;
    const { description, categories, allergens, handlingInstructions } =
      req.body;

    // Try to fetch donation details if donationId is provided
    let donationDetails = {
      description: description || "Food Donation",
      categories: categories || ["general"],
      allergens: allergens || [],
      handlingInstructions: handlingInstructions,
    };

    if (donationId && donationId !== "undefined") {
      try {
        const donation = await Donation.findById(donationId);
        if (donation) {
          donationDetails = {
            description: donation.aiDescription || donationDetails.description,
            categories:
              donation.categories.length > 0
                ? donation.categories
                : donationDetails.categories,
            allergens:
              donation.aiAnalysis?.allergens || donationDetails.allergens,
            handlingInstructions:
              donation.aiAnalysis?.suggestedHandling ||
              donationDetails.handlingInstructions,
          };
        }
      } catch (dbError) {
        console.log("Could not fetch donation details, using provided data");
      }
    }

    const labelData = await geminiService.generateQRCodeContent(
      donationDetails
    );

    // Generate QR code with enhanced data
    const qrCodeData = {
      type: "food_safety_label",
      description: donationDetails.description,
      categories: donationDetails.categories,
      allergens: donationDetails.allergens,
      handling: donationDetails.handlingInstructions,
      generatedAt: new Date().toISOString(),
      safetyInfo: "Handle with food safety precautions",
    };

    const qrCodeDataUrl = await QRCode.toDataURL(JSON.stringify(qrCodeData));

    // Generate printable label content
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
        "Keep refrigerated below 4°C (40°F)",
        "Consume within 24 hours",
        "Reheat to 74°C (165°F) if applicable",
        "When in doubt, throw it out",
      ],
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

    // Fallback label
    const fallbackLabel = {
      labelText:
        "Food Donation - Keep refrigerated. Consume within 24 hours. Check for allergens.",
      qrCode: await QRCode.toDataURL(
        "Basic food safety: Keep refrigerated, consume quickly"
      ),
      printableLabel: {
        title: "Food Safety Label",
        description: "Food Donation",
        handlingInstructions: "Keep refrigerated. Consume within 24 hours.",
        safetyGuidelines: [
          "Keep refrigerated",
          "Consume quickly",
          "When in doubt, throw it out",
        ],
      },
    };

    res.status(200).json({
      success: true,
      data: fallbackLabel,
      note: "Generated basic safety label",
    });
  }
};

// New endpoint to get food safety checklist
exports.getSafetyChecklist = async (req, res) => {
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
          "WHO Food Safety",
          "US FDA Food Code",
          "HACCP Principles",
        ],
      },
    });
  } catch (error) {
    console.error("Checklist Generation Error:", error);

    res.json({
      success: true,
      data: {
        checklist: [
          "Check temperature: Keep below 4°C (40°F) or above 60°C (140°F)",
          "Verify packaging integrity",
          "Check for unusual odors or colors",
          "Ensure proper separation from raw foods",
          "Confirm consumption timeframe",
        ],
        sources: FOOD_SAFETY_KNOWLEDGE_BASE.sources,
        note: "Basic safety checklist",
      },
    });
  }
};
