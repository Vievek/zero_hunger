const User = require("../models/User");
const jwt = require("jsonwebtoken");

// Generate JWT Token
const generateToken = (userId) => {
  return jwt.sign({ id: userId }, process.env.JWT_SECRET || "your-secret-key", {
    expiresIn: "7d",
  });
};

// @desc    Handle Google OAuth callback
// @route   GET /api/auth/google/callback
// @access  Public
exports.googleCallback = async (req, res) => {
  try {
    if (!req.user) {
      return res.redirect(`yourapp://auth?error=Authentication failed`);
    }

    const token = generateToken(req.user._id);

    // Redirect to app with token
    res.redirect(
      `yourapp://auth?token=${token}&profileCompleted=${req.user.profileCompleted}`
    );
  } catch (error) {
    res.redirect(`yourapp://auth?error=Authentication failed`);
  }
};

// @desc    Find or create user from Google profile
// @route   (Internal - Passport strategy)
// @access  Public
exports.findOrCreateUser = async (accessToken, refreshToken, profile, done) => {
  try {
    // Check if user exists with googleId
    let user = await User.findOne({ googleId: profile.id });

    if (user) {
      return done(null, user);
    }

    // Check if user exists with email
    user = await User.findOne({ email: profile.emails[0].value });

    if (user) {
      // Link Google account to existing user
      user.googleId = profile.id;
      user.avatar = profile.photos[0].value;
      await user.save();
      return done(null, user);
    }

    // Create new user
    user = await User.create({
      googleId: profile.id,
      name: profile.displayName,
      email: profile.emails[0].value,
      avatar: profile.photos[0].value,
      profileCompleted: false,
      role: "donor", // Default role, can be changed later
    });

    done(null, user);
  } catch (error) {
    done(error, null);
  }
};
