const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/auth");

console.log("🔧 Loading Admin routes...");

// Debug: Check if controller loads properly
try {
  const adminController = require("../controllers/adminController");
  console.log("✅ Admin controller loaded successfully");

  // Admin-only routes
  router.get(
    "/verifications/pending",
    auth,
    adminController.getPendingVerifications
  );

  router.put(
    "/verify-recipient/:userId",
    auth,
    adminController.verifyRecipient
  );

  router.get("/stats", auth, adminController.getPlatformStats);

  console.log("✅ All Admin routes defined");
} catch (error) {
  console.error("❌ Admin controller load error:", error.message);
  // Fallback routes for debugging
  router.get("/verifications/pending", auth, (req, res) =>
    res.json({ success: false, message: "Admin controller not loaded" })
  );
  router.put("/verify-recipient/:userId", auth, (req, res) =>
    res.json({ success: false, message: "Admin controller not loaded" })
  );
  router.get("/stats", auth, (req, res) =>
    res.json({ success: false, message: "Admin controller not loaded" })
  );
}

console.log("✅ Admin router created");

module.exports = router;
