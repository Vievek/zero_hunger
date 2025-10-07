const passport = require("passport");
const GoogleStrategy = require("passport-google-oauth20").Strategy;
const User = require("../models/User");

// Only initialize Google strategy if credentials are provided
if (process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET) {
  passport.use(
    new GoogleStrategy(
      {
        clientID: process.env.GOOGLE_CLIENT_ID,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET,
        callbackURL: "/api/auth/google/callback",
      },
      async (accessToken, refreshToken, profile, done) => {
        try {
          console.log("Google profile received:", profile.id);

          // Check if user exists with googleId
          let user = await User.findOne({ googleId: profile.id });

          if (user) {
            console.log("User found by googleId:", user.email);
            return done(null, user);
          }

          // Check if user exists with email
          user = await User.findOne({ email: profile.emails[0].value });

          if (user) {
            console.log(
              "User found by email, linking Google account:",
              user.email
            );
            // Link Google account to existing user
            user.googleId = profile.id;
            user.avatar = profile.photos[0].value;
            await user.save();
            return done(null, user);
          }

          // Create new user
          console.log("Creating new user for:", profile.emails[0].value);
          user = await User.create({
            googleId: profile.id,
            name: profile.displayName,
            email: profile.emails[0].value,
            avatar: profile.photos[0].value,
            profileCompleted: false,
            role: "donor", // Default role
          });

          done(null, user);
        } catch (error) {
          console.error("Error in Google strategy:", error);
          done(error, null);
        }
      }
    )
  );
} else {
  console.warn(
    "Google OAuth credentials not found. Google login will be disabled."
  );
}

passport.serializeUser((user, done) => {
  done(null, user.id);
});

passport.deserializeUser(async (id, done) => {
  try {
    const user = await User.findById(id);
    done(null, user);
  } catch (error) {
    done(error, null);
  }
});

module.exports = passport;
