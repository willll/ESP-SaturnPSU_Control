/**
 * @file main.cpp
 * @brief ESP8266 D1 Control Firmware
 *
 * Provides REST API and web UI for D1 pin control with latch logic.
 */

#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ArduinoJson.h>
#include <LittleFS.h>

// GPIO pin for relay control
/**
 * @brief GPIO pin for relay/relay control (D1)
 */
static const uint8_t kD1Pin = D1;

// HTTP server on port 80
/**
 * @brief HTTP server on port 80
 */
static ESP8266WebServer server(80);
// Last WiFi error message for diagnostics
/**
 * @brief Last WiFi error message for diagnostics
 */
static String lastWifiError;

// Latch period (ms), timer expiry, and last state for auto-revert
/**
 * @brief Latch period (ms), timer expiry, and last state for auto-revert
 */
static uint32_t latchPeriodMs = 5000; ///< Default: 5 seconds
static uint32_t latchTimerExpiry = 0;
static int lastLatchedState = -1;

// WiFi configuration structure
/**
 * @struct WifiConfig
 * @brief WiFi configuration structure
 */
struct WifiConfig {
  String ssid;
  String pass;
  String hostname;
  uint32_t connectTimeoutMs = 20000;
};

// Load WiFi configuration from LittleFS (/wifi.json)
/**
 * @brief Load WiFi configuration from LittleFS (/wifi.json)
 * @param[out] cfg Populated with loaded config if successful
 * @return true if config loaded, false on error
 */
static bool loadWifiConfig(WifiConfig &cfg) {
  if (!LittleFS.begin()) {
    Serial.println("LittleFS mount failed");
    lastWifiError = "LittleFS mount failed";
    return false;
  }
  if (!LittleFS.exists("/wifi.json")) {
    Serial.println("/wifi.json not found (copy wifi_replace_me.json and rename)");
    lastWifiError = "/wifi.json not found";
    return false;
  }
  File file = LittleFS.open("/wifi.json", "r");
  if (!file) {
    Serial.println("Failed to open /wifi.json");
    lastWifiError = "Failed to open /wifi.json";
    return false;
  }
  DynamicJsonDocument doc(384);
  DeserializationError err = deserializeJson(doc, file);
  file.close();
  if (err) {
    Serial.print("Failed to parse /wifi.json: ");
    Serial.println(err.c_str());
    lastWifiError = "Failed to parse /wifi.json";
    return false;
  }
  cfg.ssid = String(doc["ssid"] | "");
  cfg.pass = String(doc["password"] | "");
  cfg.hostname = String(doc["hostname"] | "");
  cfg.connectTimeoutMs = doc["connect_timeout_ms"] | 20000;
  cfg.ssid.trim();
  cfg.pass.trim();
  cfg.hostname.trim();
  if (cfg.ssid.length() == 0) {
    Serial.println("Invalid WiFi config: ssid is empty");
    lastWifiError = "Invalid WiFi config: ssid is empty";
    return false;
  }
  return true;
}

// Convert WiFi status code to human-readable string
/**
 * @brief Convert WiFi status code to human-readable string
 * @param status wl_status_t code
 * @return const char* description
 */
static const char *wifiStatusToString(wl_status_t status) {
  int code = static_cast<int>(status);
  if (code == 3) {
    return "Connected";
  }
  switch (status) {
    case WL_CONNECTED:
      return "Connected";
    case WL_NO_SSID_AVAIL:
      return "SSID not found";
    case WL_CONNECT_FAILED:
      return "Connect failed";
    case WL_WRONG_PASSWORD:
      return "Wrong password";
    case WL_DISCONNECTED:
      return "Disconnected";
    case WL_IDLE_STATUS:
      return "Idle";
    case WL_CONNECTION_LOST:
      return "Connection lost";
    default:
      return "Unknown";
  }
}

// Build status menu text for serial output
/**
 * @brief Build status menu text for serial output
 * @param cfg WiFi config
 * @return String status text
 */
static String buildMenuText(const WifiConfig &cfg) {
  String text;
  text.reserve(256);
  text += "=== ESP8266 Status ===\n";
  text += "SSID: ";
  text += cfg.ssid.length() > 0 ? cfg.ssid : "(not set)";
  text += "\nHostname: ";
  text += cfg.hostname.length() > 0 ? cfg.hostname : "(not set)";
  text += "\nWiFi status: ";
  text += wifiStatusToString(WiFi.status());
  text += " (WL_ code ";
  text += String(static_cast<int>(WiFi.status()));
  text += ")\nIP address: ";
  text += WiFi.localIP().toString();
  if (lastWifiError.length() > 0) {
    text += "\nLast error: ";
    text += lastWifiError;
  }
  text += "\nCommands: m or ? to show this menu\n";
  return text;
}

// Print status menu to serial
/**
 * @brief Print status menu to serial
 * @param cfg WiFi config
 */
static void printMenu(const WifiConfig &cfg) {
  Serial.println("\n" + buildMenuText(cfg));
}

// Handle /menu endpoint (plain text status)
/**
 * @brief Handle /menu endpoint (plain text status)
 */
static void handleMenu() {
  WifiConfig cfg;
  loadWifiConfig(cfg);
  server.send(200, "text/plain", buildMenuText(cfg));
}


// Send current D1 state and latch period as JSON
/**
 * @brief Send current D1 state and latch period as JSON
 * @endpoint /api/status (GET)
 */
static void sendJsonStatus() {
  const char *state = digitalRead(kD1Pin) ? "1" : "0";
  String payload = String("{\"d1\":") + state + ",\"latch\":" + latchPeriodMs/1000 + "}";
  server.send(200, "application/json", payload);
}

// GET returns {"latch": seconds}, POST sets latch period (seconds)
// Handle /api/latch GET/POST: get or set latch period
/**
 * @brief Handle /api/latch GET/POST: get or set latch period
 * @endpoint /api/latch (GET, POST)
 */
static void handleLatch() {
  if (server.method() == HTTP_GET) {
    String payload = String("{\"latch\":") + (latchPeriodMs/1000) + "}";
    server.send(200, "application/json", payload);
    return;
  }
  if (server.method() == HTTP_POST) {
    if (!server.hasArg("plain")) {
      server.send(400, "application/json", "{\"error\":\"Missing body\"}");
      return;
    }
    DynamicJsonDocument doc(64);
    DeserializationError err = deserializeJson(doc, server.arg("plain"));
    if (err) {
      server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
      return;
    }
    int seconds = doc["latch"] | 0;
    // Clamp to 0 (disable) or [1, 3600]
    if (seconds < 0) seconds = 0;
    if (seconds > 0) {
      if (seconds < 1) seconds = 1;
      if (seconds > 3600) seconds = 3600;
    }
    latchPeriodMs = seconds * 1000;
    server.send(200, "application/json", String("{\"latch\":") + seconds + "}");
  }
}

// Serve index.html from LittleFS at root
/**
 * @brief Serve index.html from LittleFS at root
 * @endpoint / (GET)
 */
static void handleIndex() {
  File file = LittleFS.open("/index.html", "r");
  if (!file) {
    server.send(404, "text/plain", "index.html not found");
    return;
  }

  server.streamFile(file, "text/html");
  file.close();
}


// Start or clear the latch timer for auto-revert
/**
 * @brief Start or clear the latch timer for auto-revert
 * @param revertState State to revert to after latch period
 */
static void startLatchTimer(int revertState) {
  if (latchPeriodMs > 0) {
    latchTimerExpiry = millis() + latchPeriodMs;
    lastLatchedState = revertState;
  } else {
    latchTimerExpiry = 0;
    lastLatchedState = -1;
  }
}

// Handle /api/on: set D1 HIGH, start latch timer
/**
 * @brief Handle /api/on: set D1 HIGH, start latch timer
 * @endpoint /api/on (POST)
 */
static bool isLatchActive() {
  return latchTimerExpiry > 0 && ((int32_t)(latchTimerExpiry - millis()) > 0);
}

static void handleOn() {
  if (isLatchActive()) {
    server.send(423, "application/json", "{\"error\":\"Latch active\"}");
    return;
  }
  digitalWrite(kD1Pin, HIGH);
  startLatchTimer(LOW);
  sendJsonStatus();
}

// Handle /api/off: set D1 LOW, start latch timer
/**
 * @brief Handle /api/off: set D1 LOW, start latch timer
 * @endpoint /api/off (POST)
 */
static void handleOff() {
  if (isLatchActive()) {
    server.send(423, "application/json", "{\"error\":\"Latch active\"}");
    return;
  }
  digitalWrite(kD1Pin, LOW);
  startLatchTimer(HIGH);
  sendJsonStatus();
}

// Handle /api/toggle: toggle D1, start latch timer
/**
 * @brief Handle /api/toggle: toggle D1, start latch timer
 * @endpoint /api/toggle (POST)
 */
static void handleToggle() {
  if (isLatchActive()) {
    server.send(423, "application/json", "{\"error\":\"Latch active\"}");
    return;
  }
  int newState = !digitalRead(kD1Pin);
  digitalWrite(kD1Pin, newState);
  startLatchTimer(newState ? LOW : HIGH);
  sendJsonStatus();
}

// Arduino setup: initialize hardware, WiFi, and HTTP server
/**
 * @brief Arduino setup: initialize hardware, WiFi, and HTTP server
 */
void setup() {
  Serial.begin(74880);
  Serial.setDebugOutput(false);
  delay(800);

  pinMode(kD1Pin, OUTPUT);
  digitalWrite(kD1Pin, LOW);

  WifiConfig cfg;
  if (!loadWifiConfig(cfg)) {
    Serial.println("WiFi config missing or invalid; add /wifi.json and reboot");
  } else {
    WiFi.mode(WIFI_STA);
    if (cfg.hostname.length() > 0) {
      WiFi.hostname(cfg.hostname);
    }

    WiFi.begin(cfg.ssid.c_str(), cfg.pass.c_str());

    uint32_t start = millis();
    wl_status_t lastStatus = WiFi.status();
    while (WiFi.status() != WL_CONNECTED && millis() - start < cfg.connectTimeoutMs) {
      delay(250);
      wl_status_t status = WiFi.status();
      if (status != lastStatus) {
        Serial.print("\nWiFi status: ");
        Serial.println(wifiStatusToString(status));
        lastStatus = status;
      } else {
        Serial.print(".");
      }
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.print("\nConnected, IP: ");
      Serial.println(WiFi.localIP());
      Serial.print("IPv4 Address: ");
      Serial.println(WiFi.localIP());
      lastWifiError = "";
    } else {
      wl_status_t finalStatus = WiFi.status();
      Serial.print("\nWiFi connect failed: ");
      Serial.print(wifiStatusToString(finalStatus));
      Serial.print(" (WL_ code ");
      Serial.print(static_cast<int>(finalStatus));
      Serial.println(")");
      Serial.println("Check SSID, password, and signal strength");
      lastWifiError = String("WiFi connect failed: ") + wifiStatusToString(finalStatus);
    }
  }

  printMenu(cfg);

  server.on("/", HTTP_GET, handleIndex);
  server.on("/api/status", HTTP_GET, sendJsonStatus);
  server.on("/api/on", HTTP_POST, handleOn);
  server.on("/api/off", HTTP_POST, handleOff);
  server.on("/api/toggle", HTTP_POST, handleToggle);

  server.on("/menu", HTTP_GET, handleMenu);
  server.on("/api/latch", HTTP_GET, handleLatch);
  server.on("/api/latch", HTTP_POST, handleLatch);

  server.begin();
  Serial.println("HTTP server started");
}

// Arduino main loop: handle HTTP requests and latch timer
/**
 * @brief Arduino main loop: handle HTTP requests and latch timer
 */
void loop() {
  server.handleClient();
  // Latch timer logic
  if (latchTimerExpiry > 0 && millis() > latchTimerExpiry && lastLatchedState != -1) {
    digitalWrite(kD1Pin, lastLatchedState);
    latchTimerExpiry = 0;
    lastLatchedState = -1;
  }
  if (Serial.available() > 0) {
    int c = Serial.read();
    if (c == 'm' || c == 'M' || c == '?') {
      WifiConfig cfg;
      loadWifiConfig(cfg);
      printMenu(cfg);
    }
  }
}
