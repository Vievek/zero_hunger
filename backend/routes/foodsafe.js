const express = require("express");
const router = express.Router();
const foodSafeController = require("../controllers/foodSafeController");
const auth = require("../middleware/auth");

router.post("/ask", auth, foodSafeController.askFoodSafetyQuestion);
router.post(
  "/generate-label/:donationId",
  auth,
  foodSafeController.generateFoodLabel
);

module.exports = router;
