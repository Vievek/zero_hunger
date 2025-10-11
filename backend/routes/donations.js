const express = require("express");
const multer = require("multer");
const router = express.Router();
const donationController = require("../controllers/donationController");
const { auth, requireRole } = require("../middleware/auth");

// Configure multer for image uploads with enhanced settings
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
    files: 5, // Maximum 5 files
  },
  fileFilter: (req, file, cb) => {
    // Accept common image formats
    const allowedMimes = [
      "image/jpeg",
      "image/jpg",
      "image/png",
      "image/gif",
      "image/bmp",
      "image/webp",
      "image/svg+xml",
    ];

    if (
      file.mimetype.startsWith("image/") ||
      allowedMimes.includes(file.mimetype)
    ) {
      cb(null, true);
    } else {
      cb(new Error("Only image files are allowed!"), false);
    }
  },
});

// Enhanced error handling for file uploads
const handleUploadErrors = (error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === "LIMIT_FILE_SIZE") {
      return res.status(400).json({
        success: false,
        message: "File too large. Maximum size is 10MB.",
      });
    }
    if (error.code === "LIMIT_FILE_COUNT") {
      return res.status(400).json({
        success: false,
        message: "Too many files. Maximum 5 images allowed.",
      });
    }
  }

  if (error.message === "Only image files are allowed!") {
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }

  next(error);
};

// Apply authentication to all donation routes
router.use(auth);

// Create donation with enhanced validation
router.post("/", donationController.createDonation);

// Get donor's donations with pagination
router.get(
  "/my-donations",
  requireRole(["donor"]),
  donationController.getDonorDashboard
);

// Get available donations for recipients
router.get(
  "/available",
  requireRole(["recipient"]),
  donationController.getAvailableDonations
);

// Accept donation
router.post(
  "/:donationId/accept",
  requireRole(["recipient"]),
  donationController.acceptDonation
);

// Get donation details
router.get("/:donationId", donationController.getDonationDetails);

// Upload images with enhanced error handling
router.post(
  "/upload-images",
  upload.array("images", 5),
  handleUploadErrors,
  donationController.uploadImages
);

// AI image analysis endpoint
router.post("/analyze-images", donationController.analyzeFoodImages);

// Update donation status
router.patch(
  "/:donationId/status",
  requireRole(["donor"]),
  donationController.updateDonationStatus
);

// Get donation statistics
router.get("/stats/overview", donationController.getDonationStats);

// Search donations
router.get(
  "/search/available",
  requireRole(["recipient"]),
  donationController.searchAvailableDonations
);

// Export router
module.exports = router;
