/*
 * Smart Kitchen Automated Replenishment System
 * ESP8266 Firmware for Container Weight Sensor
 * 
 * Hardware: ESP8266 + HX711 Load Cell Amplifier + Load Cell
 * 
 * Features:
 * - WiFi connection with stored credentials
 * - Self-provisioning with server token
 * - Periodic weight/percentage readings
 * - Token refresh handling (access token expires every 7 days)
 * - Auto-reprovision when required
 * - Deep sleep between readings for battery optimization
 */

#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>
#include <EEPROM.h>

// ======================== CONFIGURATION ========================

// WiFi credentials (can be set via provisioning tool or hardcoded)
String wifiSSID = "";
String wifiPassword = "";

// Backend server URL (change to your server IP/domain)
const char *serverURL = "http://192.168.1.100:3000"; // Change to your server IP
String serverToken = "smart_kitchen_server_token_2024"; // from .env SERVER_TOKEN

// HX711 Load Cell Pins
#define HX711_DT  D2  // Data pin
#define HX711_SCK D1  // Clock pin
#define HX711_DOUT D3 // DOUT/DOUT pin (alternative)

// Container configuration
float containerCapacityKg = 1.0; // Default, updated after provisioning
float currentWeightKg = 0.0;
float percentRemaining = 100.0;

// EEPROM addresses for persistent storage
#define EEPROM_SIZE 512
#define ADDR_DEVICE_ID    0
#define ADDR_ACCESS_TOKEN 50
#define ADDR_REFRESH_TOKEN 200
#define ADDR_WIFI_SSID    350
#define ADDR_WIFI_PASS    400
#define ADDR_CAPACITY     450

// Timing (in milliseconds)
#define READ_INTERVAL_MS      300000  // 5 minutes between readings
#define TOKEN_REFRESH_INTERVAL_MS 600000 // 10 minutes (refresh before 7-day expiry)
#define WIFI_TIMEOUT_MS       10000   // 10 seconds to connect WiFi

// ======================== GLOBALS ========================

String deviceID = "";
String accessToken = "";
String refreshToken = "";
unsigned long lastReadTime = 0;
unsigned long lastRefreshAttempt = 0;
bool dataSent = false;

// ======================== EEPROM HELPERS ========================

void saveToEEPROM(int startAddr, String data) {
  for (int i = 0; i < data.length(); i++) {
    EEPROM.write(startAddr + i, data[i]);
  }
  EEPROM.write(startAddr + data.length(), '\0');
  EEPROM.commit();
}

String readFromEEPROM(int startAddr) {
  String data = "";
  char ch;
  int i = startAddr;
  while ((ch = EEPROM.read(i)) != '\0' && i < EEPROM_SIZE) {
    data += ch;
    i++;
  }
  return data;
}

// ======================== HX711 LOAD CELL ========================

// Simple HX711 read function (no library needed for basic operation)
bool readLoadCell(float &weightKg) {
  // NOTE: In production, use the HX711 library by bogde:
  // https://github.com/bogde/HX711
  // #include "HX711.h"
  // HX711 scale;
  // scale.begin(HX711_DT, HX711_SCK);
  // scale.set_scale(calibration_factor);
  // scale.tare();
  // weightKg = scale.get_units(5); // average of 5 readings
  
  // For now, simulate a reading (replace with actual HX711 code)
  // Simulated: random weight between 0.1 and capacity
  weightKg = random(100, (int)(containerCapacityKg * 1000)) / 1000.0;
  
  // Simulate that weight decreases over time for testing
  static float simulatedWeight = containerCapacityKg * 0.8;
  simulatedWeight -= 0.05; // Decrease by 50g each read
  if (simulatedWeight < 0.1) simulatedWeight = containerCapacityKg; // Reset
  
  weightKg = simulatedWeight;
  
  Serial.print("[Sensor] Weight: ");
  Serial.print(weightKg);
  Serial.println(" kg");
  
  return true;
}

// ======================== WIFI ========================

bool connectToWiFi() {
  if (wifiSSID.length() == 0) {
    Serial.println("[WiFi] No SSID saved. Need provisioning.");
    return false;
  }

  Serial.print("[WiFi] Connecting to ");
  Serial.print(wifiSSID);
  Serial.print("...");

  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());

  unsigned long startTime = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    if (millis() - startTime > WIFI_TIMEOUT_MS) {
      Serial.println("\n[WiFi] Connection timeout!");
      return false;
    }
  }

  Serial.println(" CONNECTED!");
  Serial.print("[WiFi] IP: ");
  Serial.println(WiFi.localIP());
  return true;
}

// ======================== HTTP HELPERS ========================

String httpGet(String url) {
  if (WiFi.status() != WL_CONNECTED) {
    return "";
  }

  WiFiClient client;
  HTTPClient http;
  http.begin(client, url);
  http.setTimeout(5000);

  int httpCode = http.GET();
  String response = "";

  if (httpCode > 0) {
    response = http.getString();
    Serial.printf("[HTTP] GET %d: %s\n", httpCode, url.c_str());
  } else {
    Serial.printf("[HTTP] Failed: %s\n", http.errorToString(httpCode).c_str());
  }

  http.end();
  return response;
}

// ======================== PROVISIONING ========================

bool provisionDevice() {
  Serial.println("[Provision] Starting device provisioning...");

  String mac = WiFi.macAddress();
  mac.replace(":", "-");

  String url = String(serverURL) + "/provision?serverToken=" + serverToken + "&mac=" + mac;
  Serial.print("[Provision] URL: ");
  Serial.println(url);

  String response = httpGet(url);
  if (response.length() == 0) {
    Serial.println("[Provision] No response from server");
    return false;
  }

  Serial.println("[Provision] Response: " + response);

  DynamicJsonDocument doc(2048);
  DeserializationError error = deserializeJson(doc, response);

  if (error) {
    Serial.println("[Provision] JSON parse error!");
    return false;
  }

  const char *status = doc["status"];
  const char *token = doc["access_token"];
  const char *refToken = doc["refresh_token"];
  const char *devId = doc["device"]["id"];

  if (strcmp(status, "Success") == 0 && token != nullptr && refToken != nullptr) {
    accessToken = String(token);
    refreshToken = String(refToken);
    deviceID = String(devId);

    Serial.println("[Provision] ✅ Success!");
    Serial.print("  Device ID: "); Serial.println(deviceID);
    Serial.print("  Access Token: "); Serial.println(accessToken.substring(0, 20) + "...");
    Serial.print("  Refresh Token: "); Serial.println(refreshToken.substring(0, 20) + "...");

    // Save to EEPROM
    saveToEEPROM(ADDR_DEVICE_ID, deviceID);
    saveToEEPROM(ADDR_ACCESS_TOKEN, accessToken);
    saveToEEPROM(ADDR_REFRESH_TOKEN, refreshToken);

    return true;
  }

  Serial.println("[Provision] ❌ Failed. Status: " + String(status));
  return false;
}

// ======================== SEND DATA ========================

bool sendSensorData() {
  if (accessToken.length() == 0) {
    Serial.println("[Send] No access token available");
    return false;
  }

  // Format: "weight=0.75&percent=75.0"
  String payload = "weight=" + String(currentWeightKg, 3) + "&percent=" + String(percentRemaining, 1);
  
  String url = String(serverURL) + "/send?token=" + accessToken + "&data=" + payload;
  Serial.print("[Send] Sending: ");
  Serial.println(payload);

  String response = httpGet(url);
  if (response.length() == 0) return false;

  Serial.println("[Send] Response: " + response);

  DynamicJsonDocument doc(1024);
  DeserializationError error = deserializeJson(doc, response);

  if (!error) {
    const char *status = doc["status"];
    
    if (strcmp(status, "Success") == 0) {
      Serial.println("[Send] ✅ Data sent successfully");
      return true;
    }
    
    if (strcmp(status, "Expired") == 0) {
      Serial.println("[Send] ⚠️ Access token expired. Attempting refresh...");
      if (refreshAccessToken()) {
        // Retry with new token
        return sendSensorData();
      }
    }
  }

  return false;
}

// ======================== TOKEN REFRESH ========================

bool refreshAccessToken() {
  if (refreshToken.length() == 0) {
    Serial.println("[Refresh] No refresh token available");
    return false;
  }

  String url = String(serverURL) + "/refresh?refresh_token=" + refreshToken;
  Serial.println("[Refresh] Attempting token refresh...");

  String response = httpGet(url);
  if (response.length() == 0) return false;

  Serial.println("[Refresh] Response: " + response);

  DynamicJsonDocument doc(1024);
  DeserializationError error = deserializeJson(doc, response);

  if (!error) {
    const char *status = doc["status"];

    if (strcmp(status, "Success") == 0) {
      const char *newToken = doc["access_token"];
      if (newToken != nullptr) {
        accessToken = String(newToken);
        saveToEEPROM(ADDR_ACCESS_TOKEN, accessToken);
        Serial.println("[Refresh] ✅ New access token saved");
        return true;
      }
    }

    if (strcmp(status, "Reprovision") == 0) {
      Serial.println("[Refresh] ⚠️ Device needs reprovisioning!");
      // Clear tokens and reprovision
      accessToken = "";
      refreshToken = "";
      deviceID = "";
      saveToEEPROM(ADDR_ACCESS_TOKEN, "");
      saveToEEPROM(ADDR_REFRESH_TOKEN, "");
      
      if (provisionDevice()) {
        Serial.println("[Refresh] ✅ Reprovisioned successfully");
        return true;
      }
    }
  }

  return false;
}

// ======================== SETUP ========================

void setup() {
  Serial.begin(115200);
  delay(100);
  EEPROM.begin(EEPROM_SIZE);

  Serial.println();
  Serial.println("========================================");
  Serial.println("  Smart Kitchen Container Sensor");
  Serial.println("  Automated Replenishment System");
  Serial.println("========================================");

  // Read stored credentials
  deviceID = readFromEEPROM(ADDR_DEVICE_ID);
  accessToken = readFromEEPROM(ADDR_ACCESS_TOKEN);
  refreshToken = readFromEEPROM(ADDR_REFRESH_TOKEN);
  wifiSSID = readFromEEPROM(ADDR_WIFI_SSID);
  wifiPassword = readFromEEPROM(ADDR_WIFI_PASS);

  // Read stored capacity
  String capStr = readFromEEPROM(ADDR_CAPACITY);
  if (capStr.length() > 0) {
    containerCapacityKg = capStr.toFloat();
  }

  Serial.print("[Config] Device ID: ");
  Serial.println(deviceID.length() > 0 ? deviceID : "Not set");
  Serial.print("[Config] WiFi: ");
  Serial.println(wifiSSID.length() > 0 ? wifiSSID : "Not set");
  Serial.print("[Config] Capacity: ");
  Serial.print(containerCapacityKg);
  Serial.println(" kg");

  // Connect to WiFi
  if (wifiSSID.length() > 0) {
    connectToWiFi();
    
    if (WiFi.status() == WL_CONNECTED) {
      // Provision if needed
      if (deviceID.length() == 0 || accessToken.length() == 0) {
        Serial.println("[Setup] No credentials found. Provisioning...");
        if (provisionDevice()) {
          Serial.println("[Setup] ✅ Provisioning complete!");
        } else {
          Serial.println("[Setup] ❌ Provisioning failed!");
        }
      } else {
        Serial.println("[Setup] ✅ Device already provisioned");
      }
    }
  }
}

// ======================== LOOP ========================

void loop() {
  unsigned long now = millis();

  // Ensure WiFi is connected
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Loop] WiFi disconnected. Reconnecting...");
    if (!connectToWiFi()) {
      delay(5000); // Wait 5 seconds before retry
      return;
    }
  }

  // Periodic token refresh (every 10 minutes)
  if (now - lastRefreshAttempt > TOKEN_REFRESH_INTERVAL_MS) {
    lastRefreshAttempt = now;
    if (accessToken.length() > 0 && refreshToken.length() > 0) {
      refreshAccessToken();
    }
  }

  // Periodic sensor reading and data send
  if (now - lastReadTime > READ_INTERVAL_MS) {
    lastReadTime = now;

    // Read load cell
    if (readLoadCell(currentWeightKg)) {
      percentRemaining = (currentWeightKg / containerCapacityKg) * 100.0;
      if (percentRemaining > 100.0) percentRemaining = 100.0;
      if (percentRemaining < 0.0) percentRemaining = 0.0;

      Serial.printf("[Sensor] %.3f kg / %.3f kg = %.1f%% remaining\n",
        currentWeightKg, containerCapacityKg, percentRemaining);

      // Send to server
      bool sent = false;
      int retries = 0;
      while (!sent && retries < 3) {
        sent = sendSensorData();
        if (!sent) {
          retries++;
          Serial.printf("[Loop] Retry %d/3...\n", retries);
          delay(1000);
        }
      }

      if (sent) {
        Serial.println("[Loop] ✅ Data sent. Going to deep sleep...");
        // Deep sleep until next reading interval
        // ESP.deepSleep(READ_INTERVAL_MS * 1000); // microseconds
        // For now, just delay (remove deep sleep comment for production)
        delay(READ_INTERVAL_MS);
        return;
      }
    }
  }

  delay(100); // Small delay to prevent watchdog issues
}