const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const passport = require("passport");
require("dotenv").config();

// Import routes
const authRoutes = require("./routes/auth");
const donationRoutes = require("./routes/donations");
const foodSafeRoutes = require("./routes/foodsafe");
const logisticsRoutes = require("./routes/logistics");
const adminRoutes = require("./routes/admin");

const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true }));

// Passport config
require("./config/passport")(passport);
app.use(passport.initialize());

// Routes
app.use("api/auth", authRoutes);
app.use("api/donations", donationRoutes);
app.use("api/foodsafe", foodSafeRoutes);
app.use("api/logistics", logisticsRoutes);
app.use("api/admin", adminRoutes);

// Health check endpoint
app.get("api/health", (req, res) => {
  res.json({
    success: true,
    message: "Server is running",
    timestamp: new Date().toISOString(),
  });
});
app.get("/", (req, res) => {
  res.json({ message: "API is running" });
});

// Database connection
mongoose
  .connect(process.env.MONGODB_URI || "mongodb://localhost:27017/foodlink", {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => console.log("MongoDB connected"))
  .catch((err) => console.log(err));

// Export the app for Vercel serverless handler
module.exports = app;

// Start server locally only (not on Vercel)
if (process.env.NODE_ENV !== "production" && !process.env.VERCEL) {
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
}
