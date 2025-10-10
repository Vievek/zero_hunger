// Load environment variables
require("dotenv").config();

const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const passport = require("passport");

const app = express();

// Basic middleware
app.use(
  cors({
    origin: process.env.FRONTEND_URL || "*",
    credentials: true,
  })
);

app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

// Passport
require("./config/passport")(passport);
app.use(passport.initialize());

// Simple database connection
const connectDB = async () => {
  try {
    if (mongoose.connection.readyState === 1) {
      return true;
    }

    await mongoose.connect(process.env.MONGODB_URI, {
      bufferCommands: false,
      maxPoolSize: 10,
    });
    console.log("✅ MongoDB connected");
    return true;
  } catch (error) {
    console.error("❌ MongoDB connection failed:", error.message);
    return false;
  }
};

// Simple route mounting - remove all complex logic
try {
  app.use("/api/auth", require("./routes/auth"));
  app.use("/api/donations", require("./routes/donations"));
  app.use("/api/foodsafe", require("./routes/foodsafe"));
  app.use("/api/logistics", require("./routes/logistics"));
  app.use("/api/admin", require("./routes/admin"));
  console.log("✅ All routes mounted successfully");
} catch (error) {
  console.error("❌ Route mounting failed:", error);
}

// Simple health check
app.get("/api/health", async (req, res) => {
  const dbConnected = mongoose.connection.readyState === 1;

  res.json({
    success: true,
    status: dbConnected ? "healthy" : "degraded",
    message: `Server running, database ${
      dbConnected ? "connected" : "disconnected"
    }`,
    timestamp: new Date().toISOString(),
  });
});

// Root endpoint
app.get("/", (req, res) => {
  res.json({
    message: "Zero Hunger API is running",
    version: "1.0.0",
    timestamp: new Date().toISOString(),
  });
});

// 404 handler
app.use("*", (req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found",
  });
});

// Global error handler
app.use((error, req, res, next) => {
  console.error("Error:", error);
  res.status(500).json({
    success: false,
    message: "Internal server error",
  });
});

// Start server only if not in Vercel
if (process.env.VERCEL !== "1") {
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, async () => {
    console.log(`Server running on port ${PORT}`);
    // Try to connect to DB but don't block server start
    connectDB().then((connected) => {
      if (connected) {
        console.log("✅ Database connected on startup");
      }
    });
  });
}

module.exports = app;
