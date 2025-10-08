const express = require("express");
const router = express.Router();
const adminController = require("../controllers/adminController");
const auth = require("../middleware/auth");

// Admin-only routes
router.get(
  "/verifications/pending",
  auth,
  adminController.getPendingVerifications
);
router.put("/verify-recipient/:userId", auth, adminController.verifyRecipient);
router.get("/stats", auth, adminController.getPlatformStats);

module.exports = router;
