const express = require("express");
const passport = require("passport");
const jwt = require("jsonwebtoken");
const {
  register,
  login,
  getMe,
  completeProfile,
  updateProfile,
} = require("../controllers/authController");
const { auth } = require("../middleware/auth");

const router = express.Router();

// Local authentication routes
router.post("/register", register);
router.post("/login", login);
router.get("/me", auth, getMe);
router.post("/complete-profile", auth, completeProfile);
router.put("/update-profile", auth, updateProfile);

// Google OAuth routes (only if configured)
if (process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET) {
  router.get(
    "/google",
    passport.authenticate("google", { scope: ["profile", "email"] })
  );

  router.get(
    "/google/callback",
    passport.authenticate("google", { session: false }),
    (req, res) => {
      try {
        // Generate token
        const token = jwt.sign({ id: req.user._id }, process.env.JWT_SECRET, {
          expiresIn: "7d",
        });

        // For web: redirect to a success page
        // For mobile: you'll need to set up deep linking
        res.send(`
                    <html>
                        <body>
                            <h1>Authentication Successful!</h1>
                            <p>You can close this window and return to the app.</p>
                            <script>
                                // For mobile app deep linking
                                window.location.href = 'yourapp://auth?token=${token}&profileCompleted=${req.user.profileCompleted}';
                            </script>
                        </body>
                    </html>
                `);
      } catch (error) {
        res.status(500).send(`
                    <html>
                        <body>
                            <h1>Authentication Failed</h1>
                            <p>Please try again.</p>
                        </body>
                    </html>
                `);
      }
    }
  );
} else {
  // Placeholder routes if Google OAuth is not configured
  router.get("/google", (req, res) => {
    res.status(501).json({
      success: false,
      message: "Google OAuth is not configured",
    });
  });

  router.get("/google/callback", (req, res) => {
    res.status(501).json({
      success: false,
      message: "Google OAuth is not configured",
    });
  });
}

module.exports = router;
