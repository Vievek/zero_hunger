const geminiService = require("../services/geminiService");
const QRCode = require("qrcode");

exports.askFoodSafetyQuestion = async (req, res) => {
  try {
    const { question, foodType } = req.body;

    const response = await geminiService.generateFoodSafetyInfo(
      foodType,
      question
    );

    res.json({
      success: true,
      data: response,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.generateFoodLabel = async (req, res) => {
  try {
    const { donationId } = req.params;

    // In practice, you'd fetch donation details from database
    const donationDetails = {
      description: req.body.description,
      categories: req.body.categories,
      allergens: req.body.allergens,
    };

    const labelText = await geminiService.generateQRCodeContent(
      donationDetails
    );

    // Generate QR code
    const qrCodeDataUrl = await QRCode.toDataURL(labelText);

    res.json({
      success: true,
      data: {
        labelText,
        qrCode: qrCodeDataUrl,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
