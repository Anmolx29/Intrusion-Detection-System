#include <ESP8266WiFi.h>
#include <Firebase_ESP_Client.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include <TimeLib.h>  // For formatting time

// include secrets (pw and credentials)
#include "secret.h"

// PIR sensor pin
#define PIR_SENSOR_PIN D5

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Time (NTP)
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", 19800, 60000); // +5:30 IST offset

// Track motion state
bool lastMotionState = LOW;
unsigned long lastUpdateTime = 0;
const unsigned long cooldown = 5000; // 5 seconds debounce
unsigned long lastHeartbeat = 0;
const unsigned long heartbeatInterval = 10000; // 10s heartbeat
bool wasConnected = false;  // Track Wi-Fi state

// 🔹 Get formatted timestamp
String getFormattedTimestamp() {
  timeClient.update();
  unsigned long epochTime = timeClient.getEpochTime();
  setTime(epochTime);

  char buffer[25];
  int hour12 = hourFormat12();
  sprintf(buffer, "%04d-%02d-%02d %02d:%02d:%02d %s",
          year(), month(), day(),
          hour12, minute(), second(),
          isAM() ? "AM" : "PM");

  return String(buffer);
}

void setup() {
  Serial.begin(115200);
  pinMode(PIR_SENSOR_PIN, INPUT);

  // Connect Wi-Fi using credentials from secret.h
  Serial.print("Connecting to Wi-Fi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long wifiConnectStart = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    // add a simple timeout to avoid infinite loop if SSID/password wrong
    if (millis() - wifiConnectStart > 30000) {
      Serial.println();
      Serial.println("Failed to connect to Wi-Fi within 30s. Restarting...");
      ESP.restart();
    }
  }
  Serial.println("\n✅ Connected to Wi-Fi!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
  wasConnected = true;

  // Start time client
  timeClient.begin();

  // Firebase setup using credentials from secret.h
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.println("Signing in to Firebase...");
  unsigned long signStart = millis();
  // Wait for a token OR timeout after 15s
  while (auth.token.uid == "") {
    Serial.print(".");
    delay(500);
    if (millis() - signStart > 15000) {
      Serial.println();
      Serial.println("Firebase sign-in timeout — continuing (will retry in background).");
      break;
    }
  }
  Serial.println("\n✅ Firebase setup done (if credentials valid).");

  // 🔹 Mark device as ONLINE (guarded)
  if (WiFi.status() == WL_CONNECTED) {
    if (Firebase.RTDB.setString(&fbdo, "/device_status", "online")) {
      Firebase.RTDB.setString(&fbdo, "/last_active", getFormattedTimestamp());
    } else {
      Serial.println("Warning: could not set device_status on startup: " + fbdo.errorReason());
    }
  }
}

void loop() {
  bool currentMotionState = digitalRead(PIR_SENSOR_PIN);
  unsigned long currentTime = millis();

  // 🔹 Wi-Fi status monitoring
  if (WiFi.status() != WL_CONNECTED && wasConnected) {
    Serial.println("⚠️ Wi-Fi lost, setting device offline...");
    // best-effort update
    Firebase.RTDB.setString(&fbdo, "/device_status", "offline");
    wasConnected = false;
  }
  else if (WiFi.status() == WL_CONNECTED && !wasConnected) {
    Serial.println("✅ Wi-Fi reconnected, setting device online...");
    Firebase.RTDB.setString(&fbdo, "/device_status", "online");
    Firebase.RTDB.setString(&fbdo, "/last_active", getFormattedTimestamp());
    wasConnected = true;
  }

  // 🔹 Motion detection with debounce
  if (currentMotionState != lastMotionState && (currentTime - lastUpdateTime > cooldown)) {
    lastUpdateTime = currentTime;
    lastMotionState = currentMotionState;

    String status = (currentMotionState == HIGH) ? "Motion Detected" : "No Motion";
    String timestamp = getFormattedTimestamp();

    // Update "motion" node
    FirebaseJson motionData;
    motionData.set("status", status);
    motionData.set("timestamp", timestamp);
    if (Firebase.RTDB.setJSON(&fbdo, "/motion", &motionData)) {
      Serial.println("✅ Motion node updated: " + status + " at " + timestamp);
    } else {
      Serial.println("❌ Motion update failed: " + fbdo.errorReason());
    }

    // Push into "logs"
    FirebaseJson logData;
    logData.set("status", status);
    logData.set("timestamp", timestamp);
    if (Firebase.RTDB.pushJSON(&fbdo, "/logs", &logData)) {
      Serial.println("✅ Log entry added");
    } else {
      Serial.println("❌ Log push failed: " + fbdo.errorReason());
    }
  }

  // 🔹 Heartbeat every 10s → update last_active (only if online)
  if (WiFi.status() == WL_CONNECTED && millis() - lastHeartbeat > heartbeatInterval) {
    lastHeartbeat = millis();
    Firebase.RTDB.setString(&fbdo, "/last_active", getFormattedTimestamp());
    Serial.println("🔄 Heartbeat: updated last_active");
  }

  delay(100);
}
