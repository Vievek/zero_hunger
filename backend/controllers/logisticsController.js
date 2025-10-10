const LogisticsTask = require("../models/LogisticsTask");
const User = require("../models/User");
const Donation = require("../models/Donation");
const routeOptimizationService = require("../services/routeOptimizationService");
const notificationService = require("../services/notificationService");

exports.getVolunteerTasks = async (req, res) => {
  try {
    console.log("Fetching volunteer tasks for user:", req.user.id);

    const tasks = await LogisticsTask.find({ volunteer: req.user.id })
      .populate("donation")
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      data: tasks,
    });
  } catch (error) {
    console.error("Get volunteer tasks error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.updateTaskStatus = async (req, res) => {
  try {
    const { taskId } = req.params;
    const { status, currentLocation } = req.body;

    console.log("Updating task status:", taskId, "to:", status);

    const task = await LogisticsTask.findById(taskId).populate("donation");
    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Task not found",
      });
    }

    // Check if volunteer owns this task
    if (task.volunteer.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to update this task",
      });
    }

    task.status = status;

    // Update volunteer current location if provided
    if (currentLocation) {
      await User.findByIdAndUpdate(req.user.id, {
        "volunteerDetails.currentLocation": currentLocation,
      });
    }

    // Set timestamps based on status
    const now = new Date();
    if (status === "picked_up" && !task.actualPickupTime) {
      task.actualPickupTime = now;

      // Update donation status
      await Donation.findByIdAndUpdate(task.donation._id, {
        status: "picked_up",
      });
    } else if (status === "delivered" && !task.actualDeliveryTime) {
      task.actualDeliveryTime = now;

      // Update donation status
      await Donation.findByIdAndUpdate(task.donation._id, {
        status: "delivered",
      });
    }

    await task.save();

    // Send notification to donor and recipient
    await notificationService.sendStatusUpdate(
      task.donation.donor,
      "Delivery Status Updated",
      `Your donation status has been updated to: ${status}`,
      { taskId: task._id, status }
    );

    if (task.donation.acceptedBy) {
      await notificationService.sendStatusUpdate(
        task.donation.acceptedBy,
        "Delivery Status Updated",
        `Your donation delivery status has been updated to: ${status}`,
        { taskId: task._id, status }
      );
    }

    res.json({
      success: true,
      data: task,
      message: "Task status updated successfully",
    });
  } catch (error) {
    console.error("Update task status error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getOptimizedRoute = async (req, res) => {
  try {
    const { taskId } = req.params;

    console.log("Getting optimized route for task:", taskId);

    const task = await LogisticsTask.findById(taskId);
    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Task not found",
      });
    }

    // Check if volunteer owns this task
    if (task.volunteer.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to view this route",
      });
    }

    // Get all tasks for this volunteer to optimize multi-stop route
    const volunteerTasks = await LogisticsTask.find({
      volunteer: req.user.id,
      status: { $in: ["assigned", "picked_up"] },
    }).populate("donation");

    let optimizedRoute = null;

    if (volunteerTasks.length > 1) {
      const waypoints = volunteerTasks.flatMap((task) => [
        {
          ...task.pickupLocation,
          type: "pickup",
          taskId: task._id,
          urgency: task.urgency,
        },
        {
          ...task.dropoffLocation,
          type: "dropoff",
          taskId: task._id,
          urgency: task.urgency,
        },
      ]);

      optimizedRoute = await routeOptimizationService.optimizeMultiStopRoute(
        waypoints
      );
    } else {
      // Single task route with real-time traffic
      optimizedRoute = await routeOptimizationService.getRealTimeRoute(
        task.pickupLocation,
        task.dropoffLocation
      );
    }

    res.json({
      success: true,
      data: {
        taskRoute: {
          pickup: task.pickupLocation,
          dropoff: task.dropoffLocation,
        },
        optimizedRoute: optimizedRoute,
        trafficConditions: optimizedRoute?.trafficConditions || "normal",
      },
    });
  } catch (error) {
    console.error("Get optimized route error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getVolunteerStats = async (req, res) => {
  try {
    const volunteerId = req.user.id;
    console.log("Fetching volunteer stats for user:", volunteerId);

    const tasks = await LogisticsTask.find({ volunteer: volunteerId });
    const completedTasks = tasks.filter((task) => task.status === "delivered");
    const inProgressTasks = tasks.filter((task) =>
      ["assigned", "picked_up", "in_transit"].includes(task.status)
    );

    const stats = {
      totalTasks: tasks.length,
      completedTasks: completedTasks.length,
      inProgressTasks: inProgressTasks.length,
      totalDistance: completedTasks.reduce(
        (sum, task) => sum + (task.optimizedRoute?.totalDistance || 0),
        0
      ),
      totalDeliveries: completedTasks.length,
      rating: 4.8, // Would calculate from feedback in real implementation
    };

    res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    console.error("Get volunteer stats error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Additional controller functions for the enhanced routes
exports.updateVolunteerLocation = async (req, res) => {
  try {
    const { lat, lng, address } = req.body;
    console.log("Updating volunteer location for user:", req.user.id);

    await User.findByIdAndUpdate(req.user.id, {
      "volunteerDetails.currentLocation": { lat, lng },
      "volunteerDetails.lastLocationUpdate": new Date(),
    });

    res.json({
      success: true,
      message: "Location updated successfully",
    });
  } catch (error) {
    console.error("Update location error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getTaskDetails = async (req, res) => {
  try {
    const { taskId } = req.params;
    console.log("Fetching task details:", taskId);

    const task = await LogisticsTask.findById(taskId)
      .populate("donation")
      .populate("volunteer", "name volunteerDetails");

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Task not found",
      });
    }

    // Check ownership
    if (task.volunteer._id.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to view this task",
      });
    }

    // Enhanced task details
    const enhancedTask = {
      ...task.toObject(),
      progress: task.getProgress(),
      isOverdue: task.isOverdue(),
      timeRemaining: task.estimatedDeliveryTime
        ? Math.max(0, task.estimatedDeliveryTime - new Date())
        : null,
      safetyChecklist: task.safetyChecklist || [
        { item: "Check vehicle condition", completed: false },
        { item: "Verify food temperature", completed: false },
        { item: "Confirm recipient details", completed: false },
        { item: "Review handling instructions", completed: false },
      ],
    };

    res.json({
      success: true,
      data: enhancedTask,
    });
  } catch (error) {
    console.error("Get task details error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
