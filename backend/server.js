// Load environment variables
require("dotenv").config();

const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const passport = require("passport");

const app = express();

// Enhanced CORS for Flutter frontend
app.use(
  cors({
    origin: process.env.FRONTEND_URL || "*",
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "X-Requested-With",
      "Accept",
      "Origin",
      "Access-Control-Request-Method",
      "Access-Control-Request-Headers",
    ],
  })
);

// Handle preflight requests
app.options("*", cors());

app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

// Passport initialization with error handling
try {
  require("./config/passport")(passport);
  app.use(passport.initialize());
  console.log("✅ Passport initialized");
} catch (error) {
  console.error("❌ Passport initialization failed:", error);
}

// Database connection using optimized config
const connectDB = async () => {
  try {
    if (mongoose.connection.readyState === 1) {
      console.log("✅ Using existing MongoDB connection");
      return true;
    }

    console.log("🔄 Attempting MongoDB connection...");
    const connectDB = require("./config/database");
    await connectDB();

    console.log("✅ MongoDB connected successfully");
    return true;
  } catch (error) {
    console.error("❌ MongoDB connection failed:", error.message);
    return false;
  }
};

// Database connection middleware for API routes
app.use(async (req, res, next) => {
  // Skip database check for health and test endpoints
  if (
    req.path.startsWith("/api/") &&
    !req.path.includes("/health") &&
    !req.path.includes("/test") &&
    !req.path.includes("/debug")
  ) {
    try {
      const dbConnected = await connectDB();
      if (!dbConnected) {
        return res.status(503).json({
          success: false,
          message: "Database temporarily unavailable - please try again",
          timestamp: new Date().toISOString(),
        });
      }
    } catch (error) {
      console.error("Database connection middleware error:", error);
      return res.status(503).json({
        success: false,
        message: "Database connection error",
        timestamp: new Date().toISOString(),
      });
    }
  }
  next();
});

// Route mounting with individual error handling
console.log("🔄 Mounting routes...");

try {
  app.use("/api/auth", require("./routes/auth"));
  console.log("✅ Auth routes mounted");
} catch (error) {
  console.error("❌ Auth routes failed:", error);
  app.use("/api/auth", (req, res) =>
    res.status(503).json({
      success: false,
      message: "Authentication service temporarily unavailable",
    })
  );
}

try {
  app.use("/api/donations", require("./routes/donations"));
  console.log("✅ Donation routes mounted");
} catch (error) {
  console.error("❌ Donation routes failed:", error);
  app.use("/api/donations", (req, res) =>
    res.status(503).json({
      success: false,
      message: "Donation service temporarily unavailable",
    })
  );
}

try {
  app.use("/api/foodsafe", require("./routes/foodsafe"));
  console.log("✅ FoodSafe routes mounted");
} catch (error) {
  console.error("❌ FoodSafe routes failed:", error);
  app.use("/api/foodsafe", (req, res) =>
    res.status(503).json({
      success: false,
      message: "FoodSafe service temporarily unavailable",
    })
  );
}

try {
  app.use("/api/logistics", require("./routes/logistics"));
  console.log("✅ Logistics routes mounted");
} catch (error) {
  console.error("❌ Logistics routes failed:", error);
  app.use("/api/logistics", (req, res) =>
    res.status(503).json({
      success: false,
      message: "Logistics service temporarily unavailable",
    })
  );
}

try {
  app.use("/api/admin", require("./routes/admin"));
  console.log("✅ Admin routes mounted");
} catch (error) {
  console.error("❌ Admin routes failed:", error);
  app.use("/api/admin", (req, res) =>
    res.status(503).json({
      success: false,
      message: "Admin service temporarily unavailable",
    })
  );
}

console.log("✅ All routes mounted successfully");

// Enhanced health check endpoint
app.get("/api/health", async (req, res) => {
  try {
    let dbConnected = false;
    let dbHealthy = false;

    try {
      dbConnected = mongoose.connection.readyState === 1;

      if (dbConnected) {
        // Try to ping the database
        await mongoose.connection.db.admin().ping();
        dbHealthy = true;
      } else {
        // Try to establish a connection
        dbConnected = await connectDB();
        if (dbConnected) {
          await mongoose.connection.db.admin().ping();
          dbHealthy = true;
        }
      }
    } catch (dbError) {
      console.error("Database health check failed:", dbError);
      dbHealthy = false;
    }

    res.json({
      success: true,
      status: dbHealthy ? "healthy" : "degraded",
      message: `Zero Hunger API running - Database ${
        dbHealthy ? "connected" : "disconnected"
      }`,
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || "development",
      database: {
        connected: dbConnected,
        healthy: dbHealthy,
        state: mongoose.connection.readyState,
      },
      version: "1.0.0",
    });
  } catch (error) {
    console.error("Health check error:", error);
    res.status(500).json({
      success: false,
      message: "Health check failed",
      error: error.message,
    });
  }
});

// Test endpoint for basic API functionality
app.get("/api/test", (req, res) => {
  res.json({
    success: true,
    message: "Zero Hunger API test successful - Server is responding",
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || "development",
    frontend: "Flutter",
    version: "1.0.0",
  });
});

// Debug endpoint for database connection testing
app.get("/api/debug/db", async (req, res) => {
  try {
    console.log("🔄 Testing database connection...");
    const dbConnected = await connectDB();

    if (dbConnected) {
      console.log("✅ Database connected successfully");
      // Try a simple query
      try {
        const User = require("./models/User");
        const userCount = await User.countDocuments();

        res.json({
          success: true,
          message: "Database connection and query successful",
          userCount: userCount,
          connectionState: mongoose.connection.readyState,
          timestamp: new Date().toISOString(),
        });
      } catch (queryError) {
        res.json({
          success: true,
          message: "Database connected but query failed",
          connectionState: mongoose.connection.readyState,
          error: queryError.message,
          timestamp: new Date().toISOString(),
        });
      }
    } else {
      res.status(503).json({
        success: false,
        message: "Database connection failed",
        connectionState: mongoose.connection.readyState,
        timestamp: new Date().toISOString(),
      });
    }
  } catch (error) {
    console.error("Database debug error:", error);
    res.status(500).json({
      success: false,
      message: "Database debug failed",
      error: error.message,
      stack: process.env.NODE_ENV === "production" ? undefined : error.stack,
    });
  }
});

// Root endpoint
app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Zero Hunger Backend API is running",
    version: "1.0.0",
    timestamp: new Date().toISOString(),
    frontend: "Flutter Mobile App",
    endpoints: {
      health: "/api/health",
      test: "/api/test",
      debug: "/api/debug/db",
      auth: "/api/auth/*",
      donations: "/api/donations/*",
      foodsafe: "/api/foodsafe/*",
      logistics: "/api/logistics/*",
      admin: "/api/admin/*",
    },
  });
});

// 404 handler
app.use("*", (req, res) => {
  res.status(404).json({
    success: false,
    message: "API endpoint not found",
    requestedPath: req.originalUrl,
    availableEndpoints: [
      "/api/health",
      "/api/test",
      "/api/debug/db",
      "/api/auth/*",
      "/api/donations/*",
      "/api/foodsafe/*",
      "/api/logistics/*",
      "/api/admin/*",
    ],
    timestamp: new Date().toISOString(),
  });
});

// Global error handler
app.use((error, req, res, next) => {
  console.error("🚨 Global error handler:", error);

  // Mongoose timeout error
  if (
    error.name === "MongooseError" &&
    error.message.includes("buffering timed out")
  ) {
    return res.status(503).json({
      success: false,
      message: "Database connection timeout - please try again",
      error: "Database timeout",
      timestamp: new Date().toISOString(),
    });
  }

  // JWT errors
  if (error.name === "JsonWebTokenError") {
    return res.status(401).json({
      success: false,
      message: "Invalid authentication token",
      error: "Authentication failed",
      timestamp: new Date().toISOString(),
    });
  }

  // Default error
  res.status(500).json({
    success: false,
    message: "Internal server error",
    error:
      process.env.NODE_ENV === "production"
        ? "Internal server error"
        : error.message,
    timestamp: new Date().toISOString(),
  });
});

// Only start server if not in Vercel
if (process.env.VERCEL !== "1") {
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, async () => {
    console.log(`🚀 Zero Hunger Server running on port ${PORT}`);
    console.log(`🌍 Environment: ${process.env.NODE_ENV || "development"}`);
    console.log(`📱 Frontend: Flutter Mobile App`);

    // Try to connect to DB but don't block server start
    connectDB().then((connected) => {
      if (connected) {
        console.log("✅ Database connected on startup");
      } else {
        console.log(
          "⚠️ Database not connected - will connect on first request"
        );
      }
    });
  });
}

module.exports = app;
