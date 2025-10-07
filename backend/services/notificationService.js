const admin = require("firebase-admin");
const User = require("../models/User");

// Initialize Firebase Admin (you'll need to set up Firebase)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
    }),
  });
}

class NotificationService {
  async sendDonationOffer(recipientId, donationId, matchScore) {
    try {
      const recipient = await User.findById(recipientId);
      const donation = await Donation.findById(donationId).populate("donor");

      const message = {
        notification: {
          title: "New Donation Match!",
          body: `You have a ${Math.round(matchScore * 100)}% match: ${
            donation.aiDescription
          }`,
        },
        data: {
          type: "DONATION_OFFER",
          donationId: donationId.toString(),
          matchScore: matchScore.toString(),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        token: recipient.fcmToken, // You'd store FCM tokens for users
      };

      await admin.messaging().send(message);

      // Also store in database for in-app notifications
      await this.storeInAppNotification(
        recipientId,
        "donation_offer",
        `New donation match: ${donation.aiDescription}`,
        { donationId, matchScore }
      );
    } catch (error) {
      console.error("Notification send error:", error);
    }
  }

  async sendTaskAssignment(volunteerId, taskId) {
    try {
      const volunteer = await User.findById(volunteerId);
      const task = await LogisticsTask.findById(taskId).populate("donation");

      const message = {
        notification: {
          title: "New Delivery Task",
          body: `You've been assigned to deliver: ${task.donation.aiDescription}`,
        },
        data: {
          type: "TASK_ASSIGNMENT",
          taskId: taskId.toString(),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        token: volunteer.fcmToken,
      };

      await admin.messaging().send(message);

      await this.storeInAppNotification(
        volunteerId,
        "task_assigned",
        `New delivery task assigned`,
        { taskId }
      );
    } catch (error) {
      console.error("Task notification error:", error);
    }
  }

  async sendStatusUpdate(userId, title, body, data) {
    try {
      const user = await User.findById(userId);

      const message = {
        notification: { title, body },
        data: {
          ...data,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        token: user.fcmToken,
      };

      await admin.messaging().send(message);
      await this.storeInAppNotification(userId, "status_update", body, data);
    } catch (error) {
      console.error("Status notification error:", error);
    }
  }

  async storeInAppNotification(userId, type, message, data) {
    // Store notification in database
    const Notification = require("../models/Notification"); // You'd create this model
    await Notification.create({
      user: userId,
      type,
      message,
      data,
      read: false,
    });
  }
}

module.exports = new NotificationService();
