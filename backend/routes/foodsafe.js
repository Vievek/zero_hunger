const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/auth");

console.log("🔧 Loading FoodSafe routes...");

// Apply authentication to all food safe routes
router.use(auth);

// Debug: Check if controller loads properly
try {
  const foodSafeController = require("../controllers/foodSafeController");
  console.log("✅ FoodSafe controller loaded successfully");

  // Food safety Q&A
  router.post("/ask", foodSafeController.askFoodSafetyQuestion);

  // Generate QR code labels
  router.post(
    "/generate-label/:donationId",
    foodSafeController.generateFoodLabel
  );

  // Get safety checklists
  router.get("/checklist", foodSafeController.getSafetyChecklist);

  // Get quick reference
  router.get("/quick-reference", foodSafeController.getQuickReference);

  // Cache management endpoints (for debugging)
  router.post("/clear-cache", foodSafeController.clearAICache);
  router.get("/cache-stats", foodSafeController.getCacheStats);

  console.log("✅ All FoodSafe routes defined");
} catch (error) {
  console.error("❌ FoodSafe controller load error:", error.message);
  // Fallback routes for debugging
  router.post("/ask", (req, res) =>
    res.json({ success: false, message: "FoodSafe controller not loaded" })
  );
  router.post("/generate-label/:donationId", (req, res) =>
    res.json({ success: false, message: "FoodSafe controller not loaded" })
  );
  router.get("/checklist", (req, res) =>
    res.json({ success: false, message: "FoodSafe controller not loaded" })
  );
  router.get("/quick-reference", (req, res) =>
    res.json({ success: false, message: "FoodSafe controller not loaded" })
  );
}

console.log("✅ FoodSafe router created");

module.exports = router;
