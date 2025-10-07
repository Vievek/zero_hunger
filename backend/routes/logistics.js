const express = require("express");
const router = express.Router();
const logisticsController = require("../controllers/logisticsController");
const auth = require("../middleware/auth");

router.get("/my-tasks", auth, logisticsController.getVolunteerTasks);
router.put("/:taskId/status", auth, logisticsController.updateTaskStatus);
router.get("/:taskId/route", auth, logisticsController.getOptimizedRoute);

module.exports = router;
