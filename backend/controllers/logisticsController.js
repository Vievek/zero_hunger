const LogisticsTask = require("../models/LogisticsTask");
const User = require("../models/User");
const routeOptimizationService = require("../services/routeOptimizationService");
const notificationService = require("../services/notificationService");

exports.getVolunteerTasks = async (req, res) => {
  try {
    const tasks = await LogisticsTask.find({ volunteer: req.user.id })
      .populate("donation")
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      data: tasks,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.updateTaskStatus = async (req, res) => {
  try {
    const { taskId } = req.params;
    const { status } = req.body;

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
        message: "Not authorized to update this task",
      });
    }

    task.status = status;

    // Set timestamps based on status
    const now = new Date();
    if (status === "picked_up" && !task.actualPickupTime) {
      task.actualPickupTime = now;
    } else if (status === "delivered" && !task.actualDeliveryTime) {
      task.actualDeliveryTime = now;
    }

    await task.save();

    // Send notification to donor and recipient
    await notificationService.sendStatusUpdate(
      task.donation.donor,
      "Delivery Status Updated",
      `Your donation status has been updated to: ${status}`,
      { taskId: task._id, status }
    );

    res.json({
      success: true,
      data: task,
      message: "Task status updated successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getOptimizedRoute = async (req, res) => {
  try {
    const { taskId } = req.params;

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
        task.pickupLocation,
        task.dropoffLocation,
      ]);

      optimizedRoute = await routeOptimizationService.optimizeMultiStopRoute(
        waypoints
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
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
