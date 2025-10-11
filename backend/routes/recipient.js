const express = require("express");
const router = express.Router();
const recipientController = require("../controllers/recipientController");
const { auth, requireRole } = require("../middleware/auth");

console.log("🔧 Loading Recipient routes...");

// Debug middleware
router.use((req, res, next) => {
  console.log("🔐 Recipient route accessed by:", req.user.id, req.user.role);
  console.log("📋 Request path:", req.path);
  next();
});
// Apply authentication and role check to all routes
router.use(auth);
router.use(requireRole(["recipient"]));

// Recipient dashboard
router.get("/dashboard", recipientController.getRecipientDashboard);

// Donation management
router.get(
  "/donations/available",
  recipientController.getAllAvailableDonations
);
router.get("/donations/matched", recipientController.getMatchedDonations);
router.post(
  "/donations/:donationId/accept",
  recipientController.acceptDonationOffer
);
router.post(
  "/donations/:donationId/decline",
  recipientController.declineDonationOffer
);

// Profile management
router.put("/profile", recipientController.updateRecipientProfile);

// Statistics
router.get("/stats", recipientController.getRecipientStats);

console.log("✅ Recipient routes loaded successfully");

module.exports = router;
