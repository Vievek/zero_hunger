const User = require("../models/User");
const jwt = require("jsonwebtoken");

// Generate JWT Token
const generateToken = (userId) => {
  return jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    expiresIn: "7d",
  });
};

// Register User
exports.register = async (req, res) => {
  try {
    const {
      name,
      email,
      password,
      role,
      phone,
      address,
      donorDetails,
      recipientDetails,
      volunteerDetails,
    } = req.body;

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "User already exists with this email",
      });
    }

    // Create new user
    const user = new User({
      name,
      email,
      password,
      role,
      contactInfo: {
        phone,
        address,
      },
      profileCompleted: true,
      donorDetails: role === "donor" ? donorDetails : undefined,
      recipientDetails: role === "recipient" ? recipientDetails : undefined,
      volunteerDetails: role === "volunteer" ? volunteerDetails : undefined,
    });

    await user.save();

    // Generate token
    const token = generateToken(user._id);

    res.status(201).json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.contactInfo.phone,
        address: user.contactInfo.address,
        profileCompleted: user.profileCompleted,
        donorDetails: user.donorDetails,
        recipientDetails: user.recipientDetails,
        volunteerDetails: user.volunteerDetails,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Server error during registration",
      error: error.message,
    });
  }
};

// Login User
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Check if email and password are provided
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Please provide email and password",
      });
    }

    // Find user and include password
    const user = await User.findOne({ email }).select("+password");
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    // Check password
    const isPasswordValid = await user.correctPassword(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    // Generate token
    const token = generateToken(user._id);

    res.json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.contactInfo.phone,
        address: user.contactInfo.address,
        profileCompleted: user.profileCompleted,
        donorDetails: user.donorDetails,
        recipientDetails: user.recipientDetails,
        volunteerDetails: user.volunteerDetails,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Server error during login",
      error: error.message,
    });
  }
};

// Get Current User
exports.getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.contactInfo.phone,
        address: user.contactInfo.address,
        profileCompleted: user.profileCompleted,
        donorDetails: user.donorDetails,
        recipientDetails: user.recipientDetails,
        volunteerDetails: user.volunteerDetails,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
};

// Complete Profile (for Google sign-in users)
exports.completeProfile = async (req, res) => {
  try {
    const {
      role,
      phone,
      address,
      donorDetails,
      recipientDetails,
      volunteerDetails,
    } = req.body;
    const userId = req.user.id;

    const updateData = {
      role,
      contactInfo: {
        phone,
        address,
      },
      profileCompleted: true,
    };

    // Add role-specific details
    if (role === "donor" && donorDetails) {
      updateData.donorDetails = donorDetails;
    } else if (role === "recipient" && recipientDetails) {
      updateData.recipientDetails = recipientDetails;
    } else if (role === "volunteer" && volunteerDetails) {
      updateData.volunteerDetails = volunteerDetails;
    }

    const user = await User.findByIdAndUpdate(userId, updateData, {
      new: true,
    });

    res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.contactInfo.phone,
        address: user.contactInfo.address,
        profileCompleted: user.profileCompleted,
        donorDetails: user.donorDetails,
        recipientDetails: user.recipientDetails,
        volunteerDetails: user.volunteerDetails,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Server error during profile completion",
      error: error.message,
    });
  }
};
