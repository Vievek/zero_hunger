const mongoose = require("mongoose");

// Global cache for serverless environments
let cached = global.mongoose;

if (!cached) {
  cached = global.mongoose = { conn: null, promise: null };
}

// Optimized options for serverless environments
const options = {
  bufferCommands: false,
  maxPoolSize: 1, // Reduced for serverless
  minPoolSize: 1,
  serverSelectionTimeoutMS: 30000, // Reduced from 60s
  socketTimeoutMS: 45000,
  connectTimeoutMS: 30000, // Reduced from 60s
  family: 4, // Force IPv4
  keepAlive: true,
  keepAliveInitialDelay: 300000,
  retryWrites: true,
  retryReads: true,
};

async function connectDB() {
  // Return cached connection if available
  if (cached.conn) {
    console.log("Using cached MongoDB connection");
    return cached.conn;
  }

  // If no connection promise exists, create one
  if (!cached.promise) {
    console.log("Creating new MongoDB connection...");

    const opts = {
      ...options,
      bufferMaxEntries: 0,
      useNewUrlParser: true,
      useUnifiedTopology: true,
    };

    cached.promise = mongoose
      .connect(process.env.MONGODB_URI, opts)
      .then((mongoose) => {
        console.log("✅ MongoDB connected successfully");
        return mongoose;
      })
      .catch((error) => {
        console.error("❌ MongoDB connection failed:", error.message);
        cached.promise = null; // Reset on failure
        throw error;
      });
  }

  try {
    cached.conn = await cached.promise;
    return cached.conn;
  } catch (error) {
    cached.promise = null;
    throw error;
  }
}

// Connection event handlers
mongoose.connection.on("connected", () => {
  console.log("Mongoose connected to MongoDB");
});

mongoose.connection.on("error", (err) => {
  console.error("Mongoose connection error:", err);
});

mongoose.connection.on("disconnected", () => {
  console.log("Mongoose disconnected from MongoDB");
});

// Handle serverless function shutdown
if (process.env.NODE_ENV === "production") {
  process.on("SIGTERM", async () => {
    console.log("SIGTERM received, closing MongoDB connection");
    try {
      await mongoose.connection.close();
      console.log("MongoDB connection closed");
    } catch (error) {
      console.error("Error closing MongoDB connection:", error);
    }
    process.exit(0);
  });
}

module.exports = connectDB;
