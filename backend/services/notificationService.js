const admin = require("firebase-admin");
const User = require("../models/User");
const Donation = require("../models/Donation");

// Initialize Firebase Admin
if (!admin.apps.length && process.env.FIREBASE_PROJECT_ID) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
      }),
    });
    console.log("Firebase Admin initialized successfully");
  } catch (error) {
    console.error("Firebase Admin initialization error:", error);
  }
}

class NotificationService {
  async sendDonationOffer(recipientId, donationId, matchScore) {
    try {
      const recipient = await User.findById(recipientId);
      const donation = await Donation.findById(donationId).populate("donor");

      if (!recipient || !donation) {
        console.error("Recipient or donation not found for notification");
        return;
      }

      const message = {
        notification: {
          title: "🎉 New Donation Match!",
          body: `You have a ${Math.round(matchScore * 100)}% match: ${
            donation.aiDescription || donation.description
          }`,
        },
        data: {
          type: "DONATION_OFFER",
          donationId: donationId.toString(),
          matchScore: matchScore.toString(),
          donorName: donation.donor.name,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      // Send FCM notification if token available
      if (recipient.fcmToken) {
        message.token = recipient.fcmToken;
        await admin.messaging().send(message);
      }

      // Always store in database for in-app notifications
      await this.storeInAppNotification(
        recipientId,
        "donation_offer",
        `New donation match (${Math.round(matchScore * 100)}%): ${
          donation.aiDescription || donation.description
        }`,
        {
          donationId,
          matchScore,
          donorName: donation.donor.name,
          categories: donation.categories,
        }
      );

      console.log(
        `Donation offer notification sent to recipient ${recipientId}`
      );
    } catch (error) {
      console.error("Donation offer notification error:", error);
      // Don't throw error - notifications shouldn't break main functionality
    }
  }

  async sendTaskAssignment(volunteerId, taskId) {
    try {
      const volunteer = await User.findById(volunteerId);
      const task = await LogisticsTask.findById(taskId).populate("donation");

      if (!volunteer || !task) {
        console.error("Volunteer or task not found for notification");
        return;
      }

      const message = {
        notification: {
          title: "📦 New Delivery Task",
          body: `You've been assigned to deliver: ${
            task.donation.aiDescription || "food donation"
          }`,
        },
        data: {
          type: "TASK_ASSIGNMENT",
          taskId: taskId.toString(),
          donationId: task.donation._id.toString(),
          urgency: task.urgency || "normal",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      if (volunteer.fcmToken) {
        message.token = volunteer.fcmToken;
        await admin.messaging().send(message);
      }

      await this.storeInAppNotification(
        volunteerId,
        "task_assigned",
        `New delivery task: ${task.donation.aiDescription || "food donation"}`,
        {
          taskId,
          donationId: task.donation._id,
          pickupLocation: task.pickupLocation,
          urgency: task.urgency,
        }
      );

      console.log(
        `Task assignment notification sent to volunteer ${volunteerId}`
      );
    } catch (error) {
      console.error("Task notification error:", error);
    }
  }

  async sendStatusUpdate(userId, title, body, data) {
    try {
      const user = await User.findById(userId);

      if (!user) {
        console.error("User not found for status update notification");
        return;
      }

      const message = {
        notification: { title, body },
        data: {
          ...data,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      if (user.fcmToken) {
        message.token = user.fcmToken;
        await admin.messaging().send(message);
      }

      await this.storeInAppNotification(userId, "status_update", body, data);

      console.log(`Status update notification sent to user ${userId}`);
    } catch (error) {
      console.error("Status notification error:", error);
    }
  }

  async sendUrgentAlert(volunteerId, taskId, reason) {
    try {
      const volunteer = await User.findById(volunteerId);
      const task = await LogisticsTask.findById(taskId).populate("donation");

      if (!volunteer || !task) return;

      const message = {
        notification: {
          title: "🚨 Urgent Delivery Update",
          body: `Urgent: ${reason} - ${
            task.donation.aiDescription || "your delivery"
          }`,
        },
        data: {
          type: "URGENT_ALERT",
          taskId: taskId.toString(),
          reason: reason,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      if (volunteer.fcmToken) {
        message.token = volunteer.fcmToken;
        await admin.messaging().send(message);
      }

      await this.storeInAppNotification(
        volunteerId,
        "urgent_alert",
        `URGENT: ${reason}`,
        { taskId, reason }
      );

      console.log(`Urgent alert sent to volunteer ${volunteerId}`);
    } catch (error) {
      console.error("Urgent alert notification error:", error);
    }
  }

  async sendDonationReminder(donorId, donationId) {
    try {
      const donor = await User.findById(donorId);
      const donation = await Donation.findById(donationId);

      if (!donor || !donation) return;

      const message = {
        notification: {
          title: "⏰ Donation Status Reminder",
          body: `Your donation "${
            donation.aiDescription || donation.description
          }" is still active. Consider updating if no matches found.`,
        },
        data: {
          type: "DONATION_REMINDER",
          donationId: donationId.toString(),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      if (donor.fcmToken) {
        message.token = donor.fcmToken;
        await admin.messaging().send(message);
      }

      await this.storeInAppNotification(
        donorId,
        "donation_reminder",
        `Donation reminder: ${donation.aiDescription || donation.description}`,
        { donationId }
      );
    } catch (error) {
      console.error("Donation reminder error:", error);
    }
  }

  async storeInAppNotification(userId, type, message, data) {
    try {
      const Notification = require("../models/Notification");
      await Notification.create({
        user: userId,
        type,
        title: this.getNotificationTitle(type),
        message,
        data,
        read: false,
      });
    } catch (error) {
      console.error("Error storing in-app notification:", error);
    }
  }

  getNotificationTitle(type) {
    const titles = {
      donation_offer: "New Donation Match",
      task_assigned: "Delivery Task Assigned",
      status_update: "Status Updated",
      urgent_alert: "Urgent Alert",
      donation_reminder: "Donation Reminder",
    };
    return titles[type] || "Notification";
  }

  // New method for batch notifications
  async sendBatchNotifications(userIds, title, body, data = {}) {
    try {
      const users = await User.find({ _id: { $in: userIds } });

      for (const user of users) {
        await this.sendStatusUpdate(user._id, title, body, data);
      }

      console.log(`Batch notifications sent to ${users.length} users`);
    } catch (error) {
      console.error("Batch notification error:", error);
    }
  }

  // New method for notification preferences
  async getUserNotificationPreferences(userId) {
    try {
      const user = await User.findById(userId);
      return {
        donationMatches: true,
        taskAssignments: true,
        statusUpdates: true,
        urgentAlerts: true,
        reminders: user.role === "donor", // Only send reminders to donors
      };
    } catch (error) {
      console.error("Error getting notification preferences:", error);
      return {
        donationMatches: true,
        taskAssignments: true,
        statusUpdates: true,
        urgentAlerts: true,
        reminders: true,
      };
    }
  }
}

module.exports = new NotificationService();
