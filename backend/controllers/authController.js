const User = require("../models/User");
const jwt = require("jsonwebtoken");

const generateToken = (userId) => {
  return jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    expiresIn: "7d",
  });
};

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

    // Enhanced validation
    if (!name || !email || !password || !role) {
      return res.status(400).json({
        success: false,
        message:
          "Please provide all required fields: name, email, password, role",
      });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "User already exists with this email",
      });
    }

    // Enhanced user creation with validation
    const userData = {
      name,
      email,
      password,
      role,
      contactInfo: { phone, address },
      profileCompleted: true,
    };

    // Add role-specific details with validation
    if (role === "donor" && donorDetails) {
      userData.donorDetails = donorDetails;
    } else if (role === "recipient" && recipientDetails) {
      userData.recipientDetails = {
        ...recipientDetails,
        verificationStatus: "pending",
      };

      // Validate recipient organization details
      if (!recipientDetails.organizationName) {
        return res.status(400).json({
          success: false,
          message: "Organization name is required for recipients",
        });
      }
    } else if (role === "volunteer" && volunteerDetails) {
      userData.volunteerDetails = {
        ...volunteerDetails,
        isAvailable: true,
      };
    }

    const user = new User(userData);
    await user.save();

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
    console.error("Registration error:", error);
    res.status(500).json({
      success: false,
      message: "Server error during registration",
      error:
        process.env.NODE_ENV === "production"
          ? "Internal server error"
          : error.message,
    });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Please provide email and password",
      });
    }

    const user = await User.findOne({ email }).select("+password");
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    const isPasswordValid = await user.correctPassword(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    // Update last login timestamp
    user.lastLogin = new Date();
    await user.save();

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
    console.error("Login error:", error);
    res.status(500).json({
      success: false,
      message: "Server error during login",
      error:
        process.env.NODE_ENV === "production"
          ? "Internal server error"
          : error.message,
    });
  }
};

exports.getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

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
        lastLogin: user.lastLogin,
      },
    });
  } catch (error) {
    console.error("Get user error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error:
        process.env.NODE_ENV === "production"
          ? "Internal server error"
          : error.message,
    });
  }
};

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
      contactInfo: { phone, address },
      profileCompleted: true,
    };

    // Enhanced role-specific validation
    if (role === "donor" && donorDetails) {
      if (!donorDetails.businessName) {
        return res.status(400).json({
          success: false,
          message: "Business name is required for donors",
        });
      }
      updateData.donorDetails = donorDetails;
    } else if (role === "recipient" && recipientDetails) {
      if (!recipientDetails.organizationName) {
        return res.status(400).json({
          success: false,
          message: "Organization name is required for recipients",
        });
      }
      updateData.recipientDetails = {
        ...recipientDetails,
        verificationStatus: "pending",
      };
    } else if (role === "volunteer" && volunteerDetails) {
      updateData.volunteerDetails = {
        ...volunteerDetails,
        isAvailable: true,
      };
    }

    const user = await User.findByIdAndUpdate(userId, updateData, {
      new: true,
      runValidators: true,
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

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
    console.error("Profile completion error:", error);
    res.status(500).json({
      success: false,
      message: "Server error during profile completion",
      error:
        process.env.NODE_ENV === "production"
          ? "Internal server error"
          : error.message,
    });
  }
};

exports.updateProfile = async (req, res) => {
  try {
    const {
      name,
      phone,
      address,
      donorDetails,
      recipientDetails,
      volunteerDetails,
    } = req.body;
    const userId = req.user.id;

    const updateData = {
      name,
      contactInfo: { phone, address },
    };

    // Update role-specific details
    if (donorDetails) updateData.donorDetails = donorDetails;
    if (recipientDetails) updateData.recipientDetails = recipientDetails;
    if (volunteerDetails) updateData.volunteerDetails = volunteerDetails;

    const user = await User.findByIdAndUpdate(userId, updateData, {
      new: true,
      runValidators: true,
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

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
    console.error("Update profile error:", error);
    res.status(500).json({
      success: false,
      message: "Server error during profile update",
      error:
        process.env.NODE_ENV === "production"
          ? "Internal server error"
          : error.message,
    });
  }
};
