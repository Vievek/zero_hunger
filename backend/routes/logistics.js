const express = require("express");
const router = express.Router();
const logisticsController = require("../controllers/logisticsController");
const { auth, requireRole } = require("../middleware/auth");

// Apply authentication to all logistics routes
router.use(auth);

// Volunteer task management
router.get(
  "/my-tasks",
  requireRole(["volunteer"]),
  logisticsController.getVolunteerTasks
);

router.put(
  "/:taskId/status",
  requireRole(["volunteer"]),
  logisticsController.updateTaskStatus
);

router.get(
  "/:taskId/route",
  requireRole(["volunteer"]),
  logisticsController.getOptimizedRoute
);

// Volunteer statistics
router.get(
  "/stats/volunteer",
  requireRole(["volunteer"]),
  logisticsController.getVolunteerStats
);

// New enhanced routes
router.put(
  "/location/update",
  requireRole(["volunteer"]),
  logisticsController.updateVolunteerLocation
);

router.get(
  "/tasks/:taskId/details",
  requireRole(["volunteer"]),
  logisticsController.getTaskDetails
);

// Export router
module.exports = router;
