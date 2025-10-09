const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const passport = require("passport");
require("dotenv").config();

// Import database connection
const connectDB = require("./config/database");

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

// Database connection middleware for Vercel
app.use(async (req, res, next) => {
  try {
    await connectDB();
    next();
  } catch (error) {
    console.error("Database connection failed:", error);
    res.status(500).json({
      success: false,
      message: "Database connection failed",
      error:
        process.env.NODE_ENV === "production"
          ? "Database error"
          : error.message,
    });
  }
});

// Routes
app.use("/auth", authRoutes);
app.use("/donations", donationRoutes);
app.use("/foodsafe", foodSafeRoutes);
app.use("/logistics", logisticsRoutes);
app.use("/admin", adminRoutes);

// Health check endpoint (updated)
app.get("/health", async (req, res) => {
  try {
    const connectionState = mongoose.connection.readyState;

    const dbStatus = {
      connected: connectionState === 1,
      status: connectionState === 1 ? "connected" : "disconnected",
      readyState: connectionState,
    };

    const overallStatus = connectionState === 1 ? "healthy" : "degraded";

    res.json({
      success: true,
      status: overallStatus,
      message:
        overallStatus === "healthy"
          ? "Server and database are running"
          : "Server running but database disconnected",
      timestamp: new Date().toISOString(),
      database: dbStatus,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      status: "unhealthy",
      message: "Health check failed",
      timestamp: new Date().toISOString(),
      error:
        process.env.NODE_ENV === "production"
          ? "Internal server error"
          : error.message,
    });
  }
});

app.get("/", (req, res) => {
  res.json({ message: "API is running" });
});

// Remove the direct mongoose.connect from server.js since we're using connectDB

// Export the app for Vercel serverless handler
module.exports = app;
