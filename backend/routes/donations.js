const express = require("express");
const router = express.Router();
const donationController = require("../controllers/donationController");
const auth = require("../middleware/auth");

router.post("/", auth, donationController.createDonation);
router.get("/my-donations", auth, donationController.getDonorDashboard);
router.post("/:donationId/accept", auth, donationController.acceptDonation);

module.exports = router;
