const mongoose = require("mongoose");

const options = {
  bufferCommands: false,
  maxPoolSize: 5,
  minPoolSize: 1,
  serverSelectionTimeoutMS: 15000,
  socketTimeoutMS: 45000,
  connectTimeoutMS: 15000,
  retryWrites: true,
  retryReads: true,
  waitQueueTimeoutMS: 15000,
};

let cached = global.mongoose;

if (!cached) {
  cached = global.mongoose = { conn: null, promise: null };
}

async function connectDB() {
  if (cached.conn && mongoose.connection.readyState === 1) {
    return cached.conn;
  }

  if (!cached.promise) {
    const MONGODB_URI = process.env.MONGODB_URI;

    if (!MONGODB_URI) {
      throw new Error("Please define the MONGODB_URI environment variable");
    }

    cached.promise = mongoose
      .connect(MONGODB_URI, options)
      .then((mongoose) => {
        console.log("✅ MongoDB connected successfully");
        return mongoose;
      })
      .catch((err) => {
        cached.promise = null;
        console.error("❌ MongoDB connection error:", err);
        throw err;
      });
  }

  cached.conn = await cached.promise;
  return cached.conn;
}

// Handle connection events
mongoose.connection.on("connected", () => {
  console.log("✅ Mongoose connected to MongoDB");
});

mongoose.connection.on("error", (err) => {
  console.error("❌ Mongoose connection error:", err);
});

mongoose.connection.on("disconnected", () => {
  console.log("⚠️ Mongoose disconnected from MongoDB");
});

// Properly handle process termination
process.on("SIGINT", async () => {
  if (mongoose.connection.readyState === 1) {
    await mongoose.connection.close();
    console.log("MongoDB connection closed through app termination");
  }
  process.exit(0);
});

module.exports = connectDB;
