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

    // Validate role
    const validRoles = ["donor", "recipient", "volunteer", "admin"];
    if (!validRoles.includes(role)) {
      return res.status(400).json({
        success: false,
        message:
          "Invalid role. Must be one of: donor, recipient, volunteer, admin",
      });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "User already exists with this email",
      });
    }

    // Enhanced user creation with proper field mapping
    const userData = {
      name,
      email,
      password,
      role,
      contactInfo: {
        phone: phone || "",
        address: address || "",
      },
      profileCompleted: true,
    };

    // ✅ ADD THIS: Include location in contactInfo if provided in recipientDetails
    if (role === "recipient" && recipientDetails?.contactInfo?.location) {
      userData.contactInfo.location = recipientDetails.contactInfo.location;
    }

    // Add role-specific details with proper validation
    if (role === "donor") {
      if (!donorDetails?.businessName) {
        return res.status(400).json({
          success: false,
          message: "Business name is required for donors",
        });
      }
      userData.donorDetails = {
        businessName: donorDetails.businessName,
        businessType: donorDetails.businessType || "",
        businessAddress: donorDetails.businessAddress || address || "",
        foodTypes: donorDetails.foodTypes || [],
        registrationNumber: donorDetails.registrationNumber || "",
        isActive: true,
      };
    } else if (role === "recipient") {
      if (!recipientDetails?.organizationName) {
        return res.status(400).json({
          success: false,
          message: "Organization name is required for recipients",
        });
      }

      userData.recipientDetails = {
        organizationName: recipientDetails.organizationName,
        organizationType: recipientDetails.organizationType || "other",
        address: recipientDetails.address || address || "",
        capacity: recipientDetails.capacity || 50,
        dietaryRestrictions: recipientDetails.dietaryRestrictions || [],
        preferredFoodTypes: recipientDetails.preferredFoodTypes || [],
        verificationStatus: "pending",
        isActive: true,
        currentLoad: 0,
      };

      // ✅ ADD THIS: Include location if provided
      if (recipientDetails.location) {
        userData.recipientDetails.location = recipientDetails.location;
      }

      // ✅ ALSO ADD: Include contactInfo location
      if (recipientDetails.contactInfo?.location) {
        userData.contactInfo.location = recipientDetails.contactInfo.location;
      }
    } else if (role === "volunteer") {
      userData.volunteerDetails = {
        vehicleType: volunteerDetails?.vehicleType || "none",
        contactNumber: volunteerDetails?.contactNumber || phone || "",
        availability: volunteerDetails?.availability || [],
        isAvailable: true,
        maxDistance: volunteerDetails?.maxDistance || 20,
        capacity: volunteerDetails?.capacity || 10,
        currentTasks: 0,
        volunteerMetrics: {
          completedDeliveries: 0,
          totalDistance: 0,
          averageRating: 0,
          reliabilityScore: 100,
        },
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
      error: error.message,
    });
  }
};

exports.login = async (req, res) => {
  console.log("Login endpoint hit");
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
