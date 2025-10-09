const express = require("express");
const router = express.Router();
const foodSafeController = require("../controllers/foodSafeController");
const auth = require("../middleware/auth");

// Food safety Q&A
router.post("/ask", auth, foodSafeController.askFoodSafetyQuestion);

// Generate QR code labels
router.post(
  "/generate-label/:donationId",
  auth,
  foodSafeController.generateFoodLabel
);

// Get safety checklists
router.get("/checklist", auth, foodSafeController.getSafetyChecklist);

module.exports = router;
