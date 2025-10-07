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
      businessAddress: String,
      businessType: String,
      registrationNumber: String,
    },
    recipientDetails: {
      organizationName: String,
      address: String,
      capacity: Number,
      dietaryRestrictions: [String],
      verificationStatus: {
        type: String,
        enum: ["pending", "verified", "rejected"],
        default: "pending",
      },
      verifiedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    },
    volunteerDetails: {
      vehicleType: {
        type: String,
        enum: ["bike", "car", "van", "truck", "none"],
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
    },

    contactInfo: {
      phone: String,
      address: String,
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
