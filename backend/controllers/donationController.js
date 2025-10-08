const Donation = require("../models/Donation");
const User = require("../models/User");
const LogisticsTask = require("../models/LogisticsTask");
const geminiService = require("../services/geminiService");
const matchingService = require("../services/matchingService");
const routeOptimizationService = require("../services/routeOptimizationService");
const notificationService = require("../services/notificationService");

exports.createDonation = async (req, res) => {
  try {
    const { type, images, quantity, scheduledPickup, pickupAddress, location } =
      req.body;

    const donation = new Donation({
      donor: req.user.id,
      type,
      images,
      quantity,
      scheduledPickup: type === "bulk" ? scheduledPickup : undefined,
      pickupAddress,
      location,
      status: "ai_processing",
    });

    await donation.save();

    // Process with AI if images provided
    if (images && images.length > 0) {
      try {
        const aiAnalysis = await geminiService.analyzeFoodImages(images);

        donation.aiDescription = aiAnalysis.description;
        donation.categories = aiAnalysis.categories;
        donation.tags = [...aiAnalysis.allergens, ...aiAnalysis.dietaryInfo];
        donation.aiAnalysis = aiAnalysis;

        // Set handling window based on AI analysis
        const handlingWindow = calculateHandlingWindow(
          aiAnalysis.freshnessScore
        );
        donation.handlingWindow = handlingWindow;

        donation.status = "active";
        await donation.save();

        // Start matching process
        initiateMatching(donation._id);
      } catch (aiError) {
        console.error("AI processing failed:", aiError);
        donation.status = "active"; // Continue without AI data
        await donation.save();
      }
    }

    res.status(201).json({
      success: true,
      data: donation,
      message: "Donation created successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Helper function to initiate matching
async function initiateMatching(donationId) {
  try {
    const matches = await matchingService.findBestMatches(donationId);
    const donation = await Donation.findById(donationId);

    // Update donation with matches
    donation.matchedRecipients = matches.map((match) => ({
      recipient: match.recipient,
      matchScore: match.totalScore,
    }));

    await donation.save();

    // Send notifications to matched recipients
    for (const match of matches) {
      await notificationService.sendDonationOffer(
        match.recipient,
        donationId,
        match.matchScore
      );
    }
  } catch (error) {
    console.error("Matching process error:", error);
  }
}

exports.acceptDonation = async (req, res) => {
  try {
    const { donationId } = req.params;

    const donation = await Donation.findById(donationId);
    if (!donation) {
      return res.status(404).json({
        success: false,
        message: "Donation not found",
      });
    }

    // Update donation status
    donation.acceptedBy = req.user.id;
    donation.status = "matched";

    // Update the specific recipient's status
    const recipientMatch = donation.matchedRecipients.find(
      (match) => match.recipient.toString() === req.user.id
    );
    if (recipientMatch) {
      recipientMatch.status = "accepted";
      recipientMatch.respondedAt = new Date();
    }

    await donation.save();

    // Create logistics task
    const donor = await User.findById(donation.donor);
    const recipient = await User.findById(req.user.id);

    const task = new LogisticsTask({
      donation: donationId,
      pickupLocation: {
        address: donation.pickupAddress,
        lat: donation.location.lat,
        lng: donation.location.lng,
      },
      dropoffLocation: {
        address: recipient.recipientDetails?.address || recipient.address,
        lat: recipient.recipientDetails?.location?.lat || 0,
        lng: recipient.recipientDetails?.location?.lng || 0,
      },
      scheduledPickupTime:
        donation.type === "bulk"
          ? donation.scheduledPickup
          : new Date(Date.now() + 2 * 60 * 60 * 1000), // 2 hours from now
    });

    await task.save();

    // Assign volunteer using GA
    await assignVolunteerToTask(task._id);

    res.json({
      success: true,
      data: { donation, task },
      message: "Donation accepted successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Helper function to assign volunteer
async function assignVolunteerToTask(taskId) {
  try {
    const task = await LogisticsTask.findById(taskId).populate("donation");
    const availableVolunteers = await User.find({
      role: "volunteer",
      "volunteerDetails.isAvailable": true,
    });

    if (availableVolunteers.length === 0) {
      console.log("No available volunteers");
      return;
    }

    // Get all pending tasks for route optimization
    const pendingTasks = await LogisticsTask.find({
      status: "pending",
      volunteer: { $exists: false },
    }).populate("donation");

    // Use GA to assign volunteers (simplified for demo)
    const assignment = await routeOptimizationService.assignVolunteerWithGA(
      [task, ...pendingTasks],
      availableVolunteers
    );

    // Update task with assigned volunteer
    task.volunteer = assignment[task._id];
    task.status = "assigned";
    await task.save();

    // Send notification to volunteer
    await notificationService.sendTaskAssignment(assignment[task._id], taskId);

    // Optimize route if volunteer has multiple tasks
    await optimizeVolunteerRoute(assignment[task._id]);
  } catch (error) {
    console.error("Volunteer assignment error:", error);
  }
}

// Helper function to optimize volunteer route
async function optimizeVolunteerRoute(volunteerId) {
  try {
    const tasks = await LogisticsTask.find({
      volunteer: volunteerId,
      status: { $in: ["assigned", "picked_up"] },
    }).populate("donation");

    if (tasks.length <= 1) return;

    const waypoints = tasks.flatMap((task) => [
      task.pickupLocation,
      task.dropoffLocation,
    ]);

    const optimizedRoute =
      await routeOptimizationService.optimizeMultiStopRoute(waypoints);

    // Update tasks with optimized sequence
    tasks.forEach((task, index) => {
      task.routeSequence = index;
      task.optimizedRoute = optimizedRoute;
    });

    await Promise.all(tasks.map((task) => task.save()));
  } catch (error) {
    console.error("Route optimization error:", error);
  }
}

exports.getDonorDashboard = async (req, res) => {
  try {
    const donations = await Donation.find({ donor: req.user.id })
      .populate("acceptedBy", "name recipientDetails.organizationName")
      .populate("assignedVolunteer", "name")
      .sort({ createdAt: -1 });

    const stats = {
      total: donations.length,
      active: donations.filter((d) => ["active", "matched"].includes(d.status))
        .length,
      completed: donations.filter((d) => ["delivered"].includes(d.status))
        .length,
      pending: donations.filter((d) =>
        ["pending", "ai_processing"].includes(d.status)
      ).length,
    };

    res.json({
      success: true,
      data: { donations, stats },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Helper function to calculate handling window
function calculateHandlingWindow(freshnessScore) {
  const now = new Date();
  const hours = freshnessScore * 24; // Scale to 24 hours max

  return {
    start: now,
    end: new Date(now.getTime() + hours * 60 * 60 * 1000),
  };
}
