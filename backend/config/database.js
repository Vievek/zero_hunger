const mongoose = require("mongoose");

// Serverless-optimized connection for Vercel + Flutter
const options = {
  bufferCommands: false,
  bufferMaxEntries: 0,
  maxPoolSize: 1, // Essential for serverless
  minPoolSize: 1,
  serverSelectionTimeoutMS: 15000, // Increased timeout
  socketTimeoutMS: 45000,
  connectTimeoutMS: 15000,
  retryWrites: true,
  retryReads: true,
  waitQueueTimeoutMS: 15000,
};

// Global cache for serverless environments
let cached = global.mongoose;

if (!cached) {
  cached = global.mongoose = { conn: null, promise: null };
}

async function connectDB() {
  // If we have a cached connection and it's connected, return it
  if (cached.conn && mongoose.connection.readyState === 1) {
    console.log("✅ Using cached MongoDB connection");
    return cached.conn;
  }

  // If no connection promise exists, create one
  if (!cached.promise) {
    console.log("🔄 Creating new MongoDB connection...");

    const opts = {
      ...options,
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
    console.error("❌ Database connection error:", error);
    throw error;
  }
}

// Enhanced connection event handlers
mongoose.connection.on("connected", () => {
  console.log("✅ Mongoose connected to MongoDB");
});

mongoose.connection.on("error", (err) => {
  console.error("❌ Mongoose connection error:", err);
});

mongoose.connection.on("disconnected", () => {
  console.log("⚠️ Mongoose disconnected from MongoDB");
});

// Handle application termination
process.on("SIGINT", async () => {
  await mongoose.connection.close();
  console.log("MongoDB connection closed through app termination");
  process.exit(0);
});

module.exports = connectDB;
