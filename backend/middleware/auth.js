const jwt = require("jsonwebtoken");
const User = require("../models/User");

const auth = async (req, res, next) => {
  try {
    // Get token from header
    const authHeader = req.header("Authorization");
    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: "No authorization header provided, access denied",
      });
    }

    // Support both "Bearer token" and just "token" formats
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.replace("Bearer ", "")
      : authHeader;

    if (!token) {
      return res.status(401).json({
        success: false,
        message: "No token provided, access denied",
      });
    }

    // Verify token
    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET);
    } catch (jwtError) {
      return res.status(401).json({
        success: false,
        message: "Invalid or expired token",
        error: jwtError.message,
      });
    }

    // Get user from token
    const user = await User.findById(decoded.id).select("-password");
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "User not found for this token",
      });
    }

    // Check if user account is active (you could add suspended status etc.)
    if (user.status === "suspended") {
      return res.status(403).json({
        success: false,
        message: "Account suspended. Please contact support.",
      });
    }

    req.user = user;
    next();
  } catch (error) {
    console.error("Auth middleware error:", error);
    res.status(500).json({
      success: false,
      message: "Server error during authentication",
      error:
        process.env.NODE_ENV === "production"
          ? "Internal server error"
          : error.message,
    });
  }
};

// Optional: Admin middleware
const adminAuth = async (req, res, next) => {
  try {
    await auth(req, res, () => {
      if (req.user && req.user.role === "admin") {
        next();
      } else {
        return res.status(403).json({
          success: false,
          message: "Admin access required",
        });
      }
    });
  } catch (error) {
    console.error("Admin auth middleware error:", error);
    res.status(500).json({
      success: false,
      message: "Server error during admin authentication",
    });
  }
};

// Optional: Role-based middleware generator
const requireRole = (roles) => {
  return async (req, res, next) => {
    try {
      await auth(req, res, () => {
        if (req.user && roles.includes(req.user.role)) {
          next();
        } else {
          return res.status(403).json({
            success: false,
            message: `Access denied. Required roles: ${roles.join(", ")}`,
          });
        }
      });
    } catch (error) {
      console.error("Role-based auth middleware error:", error);
      res.status(500).json({
        success: false,
        message: "Server error during role-based authentication",
      });
    }
  };
};

module.exports = {
  auth,
  adminAuth,
  requireRole,
};
