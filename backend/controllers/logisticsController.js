const LogisticsTask = require("../models/LogisticsTask");
const User = require("../models/User");
const Donation = require("../models/Donation");
const routeOptimizationService = require("../services/routeOptimizationService");
const notificationService = require("../services/notificationService");

// NEW: Get available tasks within 5km of volunteer
exports.getAvailableTasks = async (req, res) => {
  try {
    console.log("🔍 Finding available tasks for volunteer:", req.user.id);

    const volunteer = await User.findById(req.user.id);
    if (!volunteer || volunteer.role !== "volunteer") {
      return res.status(403).json({
        success: false,
        message: "Only volunteers can access available tasks",
      });
    }

    const volunteerLocation =
      volunteer.volunteerDetails?.currentLocation ||
      volunteer.contactInfo?.location;

    if (!volunteerLocation) {
      return res.status(400).json({
        success: false,
        message: "Volunteer location not set. Please update your location.",
      });
    }

    // Find tasks without volunteers within 5km radius
    const tasks = await LogisticsTask.find({
      volunteer: { $exists: false },
      status: "pending",
    }).populate("donation");

    // Filter tasks within 5km radius
    const availableTasks = tasks.filter((task) => {
      if (!task.pickupLocation.lat || !task.pickupLocation.lng) return false;

      const distance = calculateDistance(volunteerLocation, {
        lat: task.pickupLocation.lat,
        lng: task.pickupLocation.lng,
      });

      return distance <= 5; // 5km radius
    });

    console.log(`📦 Found ${availableTasks.length} available tasks within 5km`);

    res.json({
      success: true,
      data: {
        tasks: availableTasks,
        total: availableTasks.length,
        volunteerLocation,
      },
    });
  } catch (error) {
    console.error("Get available tasks error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// NEW: Accept a task manually
exports.acceptTask = async (req, res) => {
  try {
    const { taskId } = req.params;
    console.log(`✅ Volunteer ${req.user.id} accepting task: ${taskId}`);

    const task = await LogisticsTask.findById(taskId).populate("donation");
    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Task not found",
      });
    }

    // Check if task is already assigned
    if (task.volunteer) {
      return res.status(400).json({
        success: false,
        message: "Task already assigned to another volunteer",
      });
    }

    // Check if volunteer can accept more tasks
    const volunteer = await User.findById(req.user.id);
    const taskSize = await task.getTaskSize();
    const canAccept = await volunteer.canAcceptTask(taskSize);

    if (!canAccept) {
      return res.status(400).json({
        success: false,
        message:
          "You have reached your task limit. Complete current tasks first.",
      });
    }

    // Check distance (within 5km)
    const volunteerLocation =
      volunteer.volunteerDetails?.currentLocation ||
      volunteer.contactInfo?.location;

    if (
      volunteerLocation &&
      task.pickupLocation.lat &&
      task.pickupLocation.lng
    ) {
      const distance = calculateDistance(volunteerLocation, {
        lat: task.pickupLocation.lat,
        lng: task.pickupLocation.lng,
      });

      if (distance > 5) {
        return res.status(400).json({
          success: false,
          message:
            "Task is too far from your current location (must be within 5km)",
        });
      }
    }

    // Assign volunteer to task
    task.volunteer = req.user.id;
    task.status = "assigned";
    await task.save();

    // Update donation status
    await Donation.findByIdAndUpdate(task.donation._id, {
      assignedVolunteer: req.user.id,
      status: "scheduled",
    });

    // Send notification to donor
    await notificationService.sendStatusUpdate(
      task.donation.donor,
      "Volunteer Assigned! 🚗",
      `A volunteer has accepted your donation delivery task.`,
      { taskId: task._id, volunteerId: req.user.id }
    );

    console.log(`✅ Task ${taskId} accepted by volunteer ${req.user.id}`);

    const updatedTask = await LogisticsTask.findById(taskId)
      .populate("donation")
      .populate("volunteer", "name volunteerDetails");

    res.json({
      success: true,
      data: updatedTask,
      message: "Task accepted successfully!",
    });
  } catch (error) {
    console.error("Accept task error:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

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
    const { status, currentLocation, notes } = req.body;

    console.log("🔄 Updating task status:", taskId, "to:", status);

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

    // VALIDATE status transition
    const validTransitions = {
      assigned: ["picked_up", "cancelled"],
      picked_up: ["in_transit", "cancelled"],
      in_transit: ["delivered", "cancelled"],
    };

    const allowedNextStatuses = validTransitions[task.status];
    if (!allowedNextStatuses || !allowedNextStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Invalid status transition from ${task.status} to ${status}`,
      });
    }

    // UPDATE volunteer current location if provided
    if (currentLocation) {
      await User.findByIdAndUpdate(req.user.id, {
        "volunteerDetails.currentLocation": currentLocation,
        "volunteerDetails.lastLocationUpdate": new Date(),
      });
    }

    // UPDATE task status with timestamps
    const now = new Date();
    task.status = status;

    if (status === "picked_up" && !task.actualPickupTime) {
      task.actualPickupTime = now;

      // Update donation status
      await Donation.findByIdAndUpdate(task.donation._id, {
        status: "picked_up",
        pickupTime: now,
      });

      // Send pickup notification
      await notificationService.sendStatusUpdate(
        task.donation.donor,
        "Donation Picked Up! 📦",
        `Your donation has been picked up by the volunteer and is on its way.`,
        { taskId: task._id, status }
      );
    } else if (status === "in_transit") {
      // Update ETA when starting transit
      await task.updateETA();
    } else if (status === "delivered" && !task.actualDeliveryTime) {
      task.actualDeliveryTime = now;

      // Update donation status
      await Donation.findByIdAndUpdate(task.donation._id, {
        status: "delivered",
        deliveryTime: now,
      });

      // Calculate completion time
      if (task.actualPickupTime) {
        task.completionTime = (now - task.actualPickupTime) / 1000;
      }

      // Send delivery notifications
      await notificationService.sendStatusUpdate(
        task.donation.donor,
        "Donation Delivered! 🎉",
        `Your donation has been successfully delivered to the recipient.`,
        { taskId: task._id, status }
      );

      if (task.donation.acceptedBy) {
        await notificationService.sendStatusUpdate(
          task.donation.acceptedBy,
          "Donation Delivered! 🎉",
          `Your donation has been delivered and is ready for distribution.`,
          { taskId: task._id, status }
        );
      }

      // Update volunteer metrics
      await updateVolunteerMetrics(req.user.id);
    } else if (status === "cancelled") {
      // Handle task cancellation
      await handleTaskCancellation(task, notes);
    }

    await task.save();

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

// Helper function to calculate distance (Haversine formula)
function calculateDistance(point1, point2) {
  const R = 6371; // Earth's radius in km
  const dLat = toRad(point2.lat - point1.lat);
  const dLon = toRad(point2.lng - point1.lng);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(point1.lat)) *
      Math.cos(toRad(point2.lat)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(degrees) {
  return degrees * (Math.PI / 180);
}

// Helper function to update volunteer metrics
async function updateVolunteerMetrics(volunteerId) {
  try {
    const completedTasks = await LogisticsTask.countDocuments({
      volunteer: volunteerId,
      status: "delivered",
    });

    await User.findByIdAndUpdate(volunteerId, {
      "volunteerMetrics.completedDeliveries": completedTasks,
      "volunteerMetrics.lastDelivery": new Date(),
    });
  } catch (error) {
    console.error("Update volunteer metrics error:", error);
  }
}

// Helper function to handle task cancellation
async function handleTaskCancellation(task, notes) {
  try {
    // Reset task assignment
    task.volunteer = null;
    task.status = "pending";
    task.cancellationNotes = notes;
    task.cancelledAt = new Date();

    // Reset donation status
    await Donation.findByIdAndUpdate(task.donation._id, {
      assignedVolunteer: null,
      status: "available",
    });

    // Send cancellation notification
    await notificationService.sendStatusUpdate(
      task.donation.donor,
      "Delivery Cancelled ❌",
      `The volunteer has cancelled the delivery task. ${notes || ""}`,
      { taskId: task._id, status: "cancelled" }
    );
  } catch (error) {
    console.error("Task cancellation handling error:", error);
    throw error;
  }
}
