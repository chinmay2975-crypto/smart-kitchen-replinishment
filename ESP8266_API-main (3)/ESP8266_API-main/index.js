const express = require("express");
const cors = require("cors");
const app = express();
const PORT = process.env.PORT || 3000;
const jwt = require("jsonwebtoken");
const mysql = require("mysql2");
const cron = require("node-cron");
const bcrypt = require("bcryptjs");

// CORS
app.use(cors());
app.use(express.json());

// .env config
require("dotenv").config();

const db = mysql.createConnection({
  host: process.env.DB_HOST || "localhost",
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASS || "password",
  database: process.env.DB_NAME || "esp8266",
});

db.connect((err) => {
  if (err) {
    console.error("DB connection error:", err);
    process.exit(1);
  }
  console.log("MySQL connected");
});

// ---- SERVERTABLE ----
app.get("/servertable", (req, res) => {
  const sql = "SELECT * FROM servertable";
  db.query(sql, (err, data) => {
    if (err) return res.json(err);
    return res.json(data);
  });
});

// ---- PROVISION ENDPOINT ----
app.get("/provision", (req, res) => {
  const { serverToken, mac } = req.query;
  if (!serverToken || !mac) {
    return res.status(400).send("Missing serverToken or mac");
  }
  if (serverToken !== process.env.SERVER_TOKEN) {
    return res.status(403).send("Invalid server token");
  }
  const checkSql = "SELECT * FROM devices WHERE mac_address = ?";
  db.query(checkSql, [mac], (err, results) => {
    if (err) return res.status(500).send("DB error");
    if (results.length > 0) {
      const device = results[0];
      const accessToken = jwt.sign(
        { device_id: device.id, mac_address: device.mac_address, type: "device_access" },
        process.env.JWT_SECRET,
        { expiresIn: "7d" }
      );
      const refreshToken = jwt.sign(
        { device_id: device.id, mac_address: device.mac_address, type: "device_refresh" },
        process.env.JWT_SECRET,
        { expiresIn: "180d" }
      );
      return res.json({
        status: "Re-provisioned",
        device_id: device.id,
        access_token: accessToken,
        refresh_token: refreshToken,
      });
    }
    const insertSql = "INSERT INTO devices (mac_address) VALUES (?)";
    db.query(insertSql, [mac], (err, result) => {
      if (err) return res.status(500).send("DB insert error");
      const deviceId = result.insertId;
      const accessToken = jwt.sign(
        { device_id: deviceId, mac_address: mac, type: "device_access" },
        process.env.JWT_SECRET,
        { expiresIn: "7d" }
      );
      const refreshToken = jwt.sign(
        { device_id: deviceId, mac_address: mac, type: "device_refresh" },
        process.env.JWT_SECRET,
        { expiresIn: "180d" }
      );
      res.json({
        status: "Provisioned",
        device_id: deviceId,
        access_token: accessToken,
        refresh_token: refreshToken,
      });
    });
  });
});

// ---- SEND ENDPOINT ----
app.get("/send", (req, res) => {
  const { token, data } = req.query;
  if (!token) return res.status(400).send("Missing token");
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.type !== "device_access") {
      return res.status(403).send("Invalid token type");
    }
    const deviceId = decoded.device_id;
    const sql = "INSERT INTO device_data (device_id, data, created_at) VALUES (?, ?, NOW())";
    db.query(sql, [deviceId, data || ""], (err) => {
      if (err) return res.status(500).send("DB insert error");
      db.query(
        "UPDATE devices SET last_active = NOW() WHERE id = ?",
        [deviceId],
        (err) => {
          if (err) console.error("Update last_active error:", err);
        }
      );
      res.json({ status: "OK", message: "Data received", device_id: deviceId });
    });
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      return res.status(401).json({ status: "Expired", message: "Access token expired" });
    }
    return res.status(403).send("Invalid token");
  }
});

// ---- REFRESH ENDPOINT ----
app.get("/refresh", (req, res) => {
  const { refresh_token } = req.query;
  if (!refresh_token) return res.status(400).send("Missing refresh_token");
  try {
    const decoded = jwt.verify(refresh_token, process.env.JWT_SECRET);
    if (decoded.type !== "device_refresh") {
      return res.status(403).send("Invalid token type");
    }
    const newAccessToken = jwt.sign(
      { device_id: decoded.device_id, mac_address: decoded.mac_address, type: "device_access" },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );
    const newRefreshToken = jwt.sign(
      { device_id: decoded.device_id, mac_address: decoded.mac_address, type: "device_refresh" },
      process.env.JWT_SECRET,
      { expiresIn: "180d" }
    );
    res.json({
      status: "OK",
      access_token: newAccessToken,
      refresh_token: newRefreshToken,
    });
  } catch (err) {
    return res.status(403).send("Invalid refresh token");
  }
});

// ---- DEVICES LIST ----
app.get("/devices", (req, res) => {
  db.query("SELECT * FROM devices ORDER BY created_at DESC", (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});

// ---- HEALTH ----
app.get("/health", (req, res) => {
  res.json({ status: "OK", service: "ESP8266 API" });
});

// ---- START ----
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});