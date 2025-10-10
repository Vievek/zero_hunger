const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    password: { type: String },
    role: {
      type: String,
      enum: ["donor", "recipient", "volunteer", "admin"],
      required: true,
    },
    googleId: { type: String },
    profileCompleted: { type: Boolean, default: false },

    // Role-specific fields
    donorDetails: {
      businessName: String,
      businessType: String,
      businessAddress: String,
      foodTypes: [String], // Types of food typically donated
      registrationNumber: String,
    },
    recipientDetails: {
      organizationName: String,
      organizationType: {
        type: String,
        enum: [
          "shelter",
          "community_kitchen",
          "food_bank",
          "religious",
          "other",
        ],
      },
      address: String,
      location: {
        lat: Number,
        lng: Number,
      },
      capacity: { type: Number, default: 50 }, // People served per day
      dietaryRestrictions: [String],
      verificationStatus: {
        type: String,
        enum: ["pending", "verified", "rejected"],
        default: "pending",
      },
      verifiedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
      verificationNotes: String,
      operatingHours: {
        start: String,
        end: String,
      },
    },
    volunteerDetails: {
      vehicleType: {
        type: String,
        enum: ["bike", "car", "van", "truck", "none"],
        default: "none",
      },
      contactNumber: String,
      availability: [
        {
          day: String,
          startTime: String,
          endTime: String,
        },
      ],
      currentLocation: {
        lat: Number,
        lng: Number,
      },
      isAvailable: { type: Boolean, default: true },
      maxDistance: { type: Number, default: 20 }, // km
      capacity: { type: Number, default: 10 }, // kg or items
    },

    contactInfo: {
      phone: String,
      address: String,
      location: {
        lat: Number,
        lng: Number,
      },
    },
  },
  { timestamps: true }
);

userSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  this.password = await bcrypt.hash(this.password, 12);
  next();
});

userSchema.methods.correctPassword = async function (
  candidatePassword,
  userPassword
) {
  return await bcrypt.compare(candidatePassword, userPassword);
};

module.exports = mongoose.model("User", userSchema);
