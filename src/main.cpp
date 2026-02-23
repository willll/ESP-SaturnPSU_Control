/**
 * @brief Helper: Clears latch if expired
 */
static void clearExpiredLatch()
{
  if (latchTimerExpiry > 0 && millis() > latchTimerExpiry)
  {
    latchTimerExpiry = 0;
  }
}

/**
 * @file main.cpp
 * @brief ESP8266 D1 Control Firmware
 *
 * Main firmware file for ESP8266 relay control project.
 *
 * Features:
 *   - Web UI & REST API for relay (D1) control
 *   - Latch logic to prevent rapid toggling
 *   - Physical push button (D2) for manual toggle
 *   - WiFi config from LittleFS
 *   - Debug serial output
 */

#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ArduinoJson.h>
#include <LittleFS.h>

/**
 * @section Globals
 * @brief Pin assignments, server, state, and config
 */
/**
 * @struct WifiConfig
 * @brief WiFi configuration loaded from LittleFS
 */
/**
 * @brief GPIO pin for relay control (D1)
 */
static const uint8_t kD1Pin = D1;

/**
 * @brief GPIO pin for NO push button (D2)
 */
static const uint8_t kD2Pin = D2;

/**
 * @brief Tracks last state of D2 push button
 */
static bool lastD2State = false;

/**
 * @brief HTTP server instance on port 80
 */
static ESP8266WebServer server(80);

/**
 * @brief Last WiFi error message for diagnostics
 */
static String lastWifiError;

/**
 * @brief Latch period in milliseconds (default 5s)
 */
static uint32_t latchPeriodMs = 5000;

/**
 * @brief Latch timer expiry timestamp (millis)
 */
static uint32_t latchTimerExpiry = 0;

/**
 * @brief Test mode flag (enabled by /test_mode file)
 */
static bool testMode = false;

// === Structs ===
struct WifiConfig
{
  String ssid;
  String pass;
  String hostname;
  uint32_t connectTimeoutMs = 20000;
};

/**
 * @section Helpers
 * @brief Utility functions for latch, WiFi, and status
 */
/**
 * @section HardwareLogic
 * @brief Functions to control relay (D1) state and toggling
 */
/**
 * @section APIHandlers
 * @brief HTTP endpoint handlers for REST API and web UI
 */
/**
 * @section ArduinoMain
 * @brief setup(): hardware, WiFi, and HTTP server initialization
 *        loop(): main event loop, handles HTTP, button, and latch
 */
/**
 * @brief Clears latch if expired (helper for latch logic)
 */
static void clearExpiredLatch()
{
  if (latchTimerExpiry > 0 && millis() > latchTimerExpiry)
  {
    latchTimerExpiry = 0;
  }
}

/**
 * @brief Returns true if latch timer is active (not expired)
 * @return true if latch is active, false otherwise
 */
static bool isLatchActive()
{
  return latchTimerExpiry > 0 && ((int32_t)(latchTimerExpiry - millis()) > 0);
}

/**
 * @brief Returns true if latch timer has expired but not yet cleared (test mode)
 * @return true if expired but not cleared
 */
static bool isLatchExpiredButNotCleared()
{
  return latchTimerExpiry > 0 && ((int32_t)(millis() - latchTimerExpiry) >= 0);
}

/**
 * @brief Load WiFi configuration from LittleFS (/wifi.json)
 * @param[out] cfg Populated with loaded config if successful
 * @return true if config loaded, false on error
 */
static bool loadWifiConfig(WifiConfig &cfg)
{
  if (!LittleFS.begin())
  {
    Serial.println("LittleFS mount failed");
    lastWifiError = "LittleFS mount failed";
    return false;
  }
  if (!LittleFS.exists("/wifi.json"))
  {
    Serial.println("/wifi.json not found (copy wifi_replace_me.json and rename)");
    lastWifiError = "/wifi.json not found";
    return false;
  }
  File file = LittleFS.open("/wifi.json", "r");
  if (!file)
  {
    Serial.println("Failed to open /wifi.json");
    lastWifiError = "Failed to open /wifi.json";
    return false;
  }
  DynamicJsonDocument doc(384);
  DeserializationError err = deserializeJson(doc, file);
  file.close();
  if (err)
  {
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
  if (cfg.ssid.length() == 0)
  {
    Serial.println("Invalid WiFi config: ssid is empty");
    lastWifiError = "Invalid WiFi config: ssid is empty";
    return false;
  }
  return true;
}

/**
 * @brief Convert WiFi status code to human-readable string
 * @param status wl_status_t code
 * @return const char* description
 */
static const char *wifiStatusToString(wl_status_t status)
{
  int code = static_cast<int>(status);
  if (code == 3)
    return "Connected";
  switch (status)
  {
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

/**
 * @brief Build status menu text for serial output
 * @param cfg WiFi config
 * @return String status text
 */
static String buildMenuText(const WifiConfig &cfg)
{
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
  if (lastWifiError.length() > 0)
  {
    text += "\nLast error: ";
    text += lastWifiError;
  }
  text += "\nCommands: m or ? to show this menu\n";
  return text;
}

/**
 * @brief Print status menu to serial
 * @param cfg WiFi config
 */
static void printMenu(const WifiConfig &cfg)
{
  Serial.println("\n" + buildMenuText(cfg));
}

// === Hardware Logic ===
/**
 * @brief Set D1 relay ON and start latch timer
 */
void setD1On()
{
  digitalWrite(kD1Pin, HIGH);
  latchTimerExpiry = millis() + latchPeriodMs;
}

/**
 * @brief Set D1 relay OFF and start latch timer
 */
void setD1Off()
{
  digitalWrite(kD1Pin, LOW);
  latchTimerExpiry = millis() + latchPeriodMs;
}

/**
 * @brief Toggle D1 relay state and update latch timer
 */
void toggleD1()
{
  int current = digitalRead(kD1Pin);
  if (current == LOW)
  {
    setD1On();
  }
  else
  {
    setD1Off();
  }
}

// === API Handlers ===
/**
 * @brief Send current D1 state and latch period as JSON (API response)
 */
static void sendJsonStatus()
{
  const char *state = digitalRead(kD1Pin) ? "1" : "0";
  bool latchActive = isLatchActive();
  String payload = String("{\"d1\":") + state +
                   ",\"latch\":" + latchPeriodMs / 1000 +
                   ",\"latch_timer_active\":" + (latchActive ? "true" : "false") +
                   ",\"latch_timer_expiry\":" + latchTimerExpiry +
                   ",\"millis\":" + millis() + "}";
  server.send(200, "application/json", payload);
}

/**
 * @brief Handle /menu endpoint (plain text status)
 */
static void handleMenu()
{
  WifiConfig cfg;
  loadWifiConfig(cfg);
  server.send(200, "text/plain", buildMenuText(cfg));
}

/**
 * @brief Handle /api/v1/latch GET/POST: get or set latch period
 */
static void handleLatch()
{
  if (server.method() == HTTP_GET)
  {
    String payload = String("{\"latch\":") + (latchPeriodMs / 1000) + "}";
    server.send(200, "application/json", payload);
    return;
  }
  if (server.method() == HTTP_POST)
  {
    if (!server.hasArg("plain"))
    {
      server.send(400, "application/json", "{\"error\":\"Missing body\"}");
      return;
    }
    DynamicJsonDocument doc(64);
    DeserializationError err = deserializeJson(doc, server.arg("plain"));
    if (err)
    {
      server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
      return;
    }
    int seconds = doc["latch"] | 0;
    if (seconds < 1)
      seconds = 1;
    if (seconds > 3600)
      seconds = 3600;
    latchPeriodMs = seconds * 1000;
    server.send(200, "application/json", String("{\"latch\":") + seconds + "}");
  }
}

/**
 * @brief Serve index.html from LittleFS at root
 */
static void handleIndex()
{
  File file = LittleFS.open("/index.html", "r");
  if (!file)
  {
    server.send(404, "text/plain", "index.html not found");
    return;
  }
  server.streamFile(file, "text/html");
  file.close();
}

/**
 * @brief Handle /api/v1/on: set D1 HIGH, start latch timer
 */
static void handleOn()
{
  Serial.print("[API] POST /api/v1/on at millis=");
  Serial.println(millis());
  clearExpiredLatch();
  if (isLatchActive())
  {
    server.send(423, "application/json", "{\"error\":\"Latch active\"}");
    return;
  }
  if (testMode && isLatchExpiredButNotCleared())
  {
    server.send(202, "application/json", "{\"info\":\"Latch expired, wait for clear\"}");
    return;
  }
  setD1On();
  sendJsonStatus();
}

/**
 * @brief Handle /api/v1/off: set D1 LOW, start latch timer
 */
static void handleOff()
{
  Serial.print("[API] POST /api/v1/off at millis=");
  Serial.println(millis());
  clearExpiredLatch();
  if (isLatchActive())
  {
    server.send(423, "application/json", "{\"error\":\"Latch active\"}");
    return;
  }
  if (testMode && isLatchExpiredButNotCleared())
  {
    server.send(202, "application/json", "{\"info\":\"Latch expired, wait for clear\"}");
    return;
  }
  setD1Off();
  sendJsonStatus();
}

/**
 * @brief Handle /api/v1/toggle: toggle D1, start latch timer
 */
static void handleToggle()
{
  Serial.print("[API] POST /api/v1/toggle at millis=");
  Serial.println(millis());
  clearExpiredLatch();
  if (isLatchActive())
  {
    server.send(423, "application/json", "{\"error\":\"Latch active\"}");
    return;
  }
  if (testMode && isLatchExpiredButNotCleared())
  {
    server.send(202, "application/json", "{\"info\":\"Latch expired, wait for clear\"}");
    return;
  }
  if (LittleFS.begin() && LittleFS.exists("/test_mode"))
  {
    testMode = true;
  }
  toggleD1();
  sendJsonStatus();
}

// === Arduino Setup & Loop ===

/**
 * @brief Helper: Returns true if latch timer has expired but main loop has not yet cleared the latch.
 * Used in test mode to signal a race window for robust test automation.
 */
static bool isLatchExpiredButNotCleared()
{
  return latchTimerExpiry > 0 && ((int32_t)(millis() - latchTimerExpiry) >= 0);
}

/**
 * @struct WifiConfig
 * @brief WiFi configuration structure
 */
struct WifiConfig
{
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
static bool loadWifiConfig(WifiConfig &cfg)
{
  if (!LittleFS.begin())
  {
    Serial.println("LittleFS mount failed");
    lastWifiError = "LittleFS mount failed";
    return false;
  }
  if (!LittleFS.exists("/wifi.json"))
  {
    Serial.println("/wifi.json not found (copy wifi_replace_me.json and rename)");
    lastWifiError = "/wifi.json not found";
    return false;
  }
  File file = LittleFS.open("/wifi.json", "r");
  if (!file)
  {
    Serial.println("Failed to open /wifi.json");
    lastWifiError = "Failed to open /wifi.json";
    return false;
  }
  DynamicJsonDocument doc(384);
  DeserializationError err = deserializeJson(doc, file);
  file.close();
  if (err)
  {
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
  if (cfg.ssid.length() == 0)
  {
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
static const char *wifiStatusToString(wl_status_t status)
{
  int code = static_cast<int>(status);
  if (code == 3)
  {
    return "Connected";
  }
  switch (status)
  {
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
static String buildMenuText(const WifiConfig &cfg)
{
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
  if (lastWifiError.length() > 0)
  {
    text += "\nLast error: ";
    text += lastWifiError;
  }
  text += "\nCommands: m or ? to show this menu\n";
  return text;
}

/**
 * @brief Print status menu to serial
 * @param cfg WiFi config
 */
static void printMenu(const WifiConfig &cfg)
{
  Serial.println("\n" + buildMenuText(cfg));
}

// Handle /menu endpoint (plain text status)
/**
 * Handle /menu endpoint (plain text status)
 */
static void handleMenu()
{
  WifiConfig cfg;
  loadWifiConfig(cfg);
  server.send(200, "text/plain", buildMenuText(cfg));
}

// Send current D1 state and latch period as JSON
/**
 * @brief Send current D1 state and latch period as JSON
 * @endpoint /api/v1/status (GET)
 */
static void sendJsonStatus()
{
  // Compose status JSON with D1 state, latch period, and timer info
  const char *state = digitalRead(kD1Pin) ? "1" : "0";
  bool latchActive = latchTimerExpiry > 0 && ((int32_t)(latchTimerExpiry - millis()) > 0);
  String payload = String("{\"d1\":") + state +
                   ",\"latch\":" + latchPeriodMs / 1000 +
                   ",\"latch_timer_active\":" + (latchActive ? "true" : "false") +
                   ",\"latch_timer_expiry\":" + latchTimerExpiry +
                   ",\"millis\":" + millis() + "}";
  server.send(200, "application/json", payload);
}

// GET returns {"latch": seconds}, POST sets latch period (seconds)
/**
 * Handle /api/v1/latch GET/POST: get or set latch period
 * @endpoint /api/v1/latch (GET, POST)
 */
static void handleLatch()
{
  // GET: Return current latch period (seconds)
  if (server.method() == HTTP_GET)
  {
    String payload = String("{\"latch\":") + (latchPeriodMs / 1000) + "}";
    server.send(200, "application/json", payload);
    return;
  }
  // POST: Set new latch period (seconds, clamped 1-3600)
  if (server.method() == HTTP_POST)
  {
    if (!server.hasArg("plain"))
    {
      server.send(400, "application/json", "{\"error\":\"Missing body\"}");
      return;
    }
    DynamicJsonDocument doc(64);
    DeserializationError err = deserializeJson(doc, server.arg("plain"));
    if (err)
    {
      server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
      return;
    }
    int seconds = doc["latch"] | 0;
    if (seconds < 1)
      seconds = 1;
    if (seconds > 3600)
      seconds = 3600;
    latchPeriodMs = seconds * 1000;
    server.send(200, "application/json", String("{\"latch\":") + seconds + "}");
  }
}

// Serve index.html from LittleFS at root
/**
 * @brief Serve index.html from LittleFS at root
 * @endpoint / (GET)
 */
static void handleIndex()
{
  File file = LittleFS.open("/index.html", "r");
  if (!file)
  {
    server.send(404, "text/plain", "index.html not found");
    return;
  }
  server.streamFile(file, "text/html");
  file.close();
}

// Handle /api/v1/on: set D1 HIGH, start latch timer
/**
 * @brief Handle /api/v1/on: set D1 HIGH, start latch timer
 * @endpoint /api/v1/on (POST)
 */
static bool isLatchActive()
{
  // Returns true if latch timer is active (not expired)
  return latchTimerExpiry > 0 && ((int32_t)(latchTimerExpiry - millis()) > 0);
}

void setD1On()
{
  digitalWrite(kD1Pin, HIGH);
  latchTimerExpiry = millis() + latchPeriodMs;
}

void setD1Off()
{
  digitalWrite(kD1Pin, LOW);
  latchTimerExpiry = millis() + latchPeriodMs;
}

void toggleD1()
{
  int current = digitalRead(kD1Pin);
  if (current == LOW)
  {
    setD1On();
  }
  else
  {
    setD1Off();
  }
}

static void handleOn()
{
  Serial.print("[API] POST /api/v1/on at millis=");
  Serial.println(millis());
  clearExpiredLatch();
  if (isLatchActive())
  {
    server.send(423, "application/json", "{\"error\":\"Latch active\"}");
    return;
  }
  if (testMode && isLatchExpiredButNotCleared())
  {
    server.send(202, "application/json", "{\"info\":\"Latch expired, wait for clear\"}");
    return;
  }
  setD1On();
  sendJsonStatus();
}

// Handle /api/v1/off: set D1 LOW, start latch timer
/**
 * @brief Handle /api/v1/off: set D1 LOW, start latch timer
 * @endpoint /api/v1/off (POST)
 */
static void handleOff()
{
  Serial.print("[API] POST /api/v1/off at millis=");
  Serial.println(millis());
  clearExpiredLatch();
  if (isLatchActive())
  {
    server.send(423, "application/json", "{\"error\":\"Latch active\"}");
    return;
  }
  if (testMode && isLatchExpiredButNotCleared())
  {
    server.send(202, "application/json", "{\"info\":\"Latch expired, wait for clear\"}");
    return;
  }
  setD1Off();
  sendJsonStatus();
}

// Handle /api/v1/toggle: toggle D1, start latch timer
/**
 * @brief Handle /api/v1/toggle: toggle D1, start latch timer
 * @endpoint /api/v1/toggle (POST)
 */
// Handle /api/v1/toggle: toggle D1, using ON/OFF logic and latch respect
/**
 * @brief Handle /api/v1/toggle: toggle D1, using ON/OFF logic and latch respect
 * @endpoint /api/v1/toggle (POST)
 */
static void handleToggle()
{
  Serial.print("[API] POST /api/v1/toggle at millis=");
  Serial.println(millis());
  clearExpiredLatch();
  if (isLatchActive())
  {
    server.send(423, "application/json", "{\"error\":\"Latch active\"}");
    return;
  }
  if (testMode && isLatchExpiredButNotCleared())
  {
    server.send(202, "application/json", "{\"info\":\"Latch expired, wait for clear\"}");
    return;
  }
  // Enable test mode if /test_mode file exists
  if (LittleFS.begin() && LittleFS.exists("/test_mode"))
  {
    testMode = true;
  }
  toggleD1();
  sendJsonStatus();
}

// Arduino setup: initialize hardware, WiFi, and HTTP server
/**
 * @brief Arduino setup: initialize hardware, WiFi, and HTTP server
 */
/**
 * @brief Arduino setup function. Initializes serial, hardware, WiFi, and HTTP server.
 */
void setup()
{
  /**
   * @brief Arduino setup function. Initializes serial, hardware, WiFi, and HTTP server.
   */
  Serial.begin(74880);
  Serial.setDebugOutput(false);
  delay(800);

  pinMode(kD1Pin, OUTPUT);
  digitalWrite(kD1Pin, LOW);
  pinMode(kD2Pin, INPUT_PULLUP);
  lastD2State = digitalRead(kD2Pin);

  WifiConfig cfg;
  if (!loadWifiConfig(cfg))
  {
    Serial.println("WiFi config missing or invalid; add /wifi.json and reboot");
  }
  else
  {
    WiFi.mode(WIFI_STA);
    if (cfg.hostname.length() > 0)
      WiFi.hostname(cfg.hostname);
    WiFi.begin(cfg.ssid.c_str(), cfg.pass.c_str());
    uint32_t start = millis();
    wl_status_t lastStatus = WiFi.status();
    while (WiFi.status() != WL_CONNECTED && millis() - start < cfg.connectTimeoutMs)
    {
      delay(250);
      wl_status_t status = WiFi.status();
      if (status != lastStatus)
      {
        Serial.print("\nWiFi status: ");
        Serial.println(wifiStatusToString(status));
        lastStatus = status;
      }
      else
      {
        Serial.print(".");
      }
    }
    if (WiFi.status() == WL_CONNECTED)
    {
      Serial.print("\nConnected, IP: ");
      Serial.println(WiFi.localIP());
      lastWifiError = "";
    }
    else
    {
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
  server.on("/api/v1/status", HTTP_GET, sendJsonStatus);
  server.on("/api/v1/on", HTTP_POST, handleOn);
  server.on("/api/v1/off", HTTP_POST, handleOff);
  server.on("/api/v1/toggle", HTTP_POST, handleToggle);
  server.on("/menu", HTTP_GET, handleMenu);
  server.on("/api/v1/latch", HTTP_GET, handleLatch);
  server.on("/api/v1/latch", HTTP_POST, handleLatch);
  server.on("/api/v1/reset", HTTP_POST, []()
            {
    latchTimerExpiry = 0;
    digitalWrite(kD1Pin, LOW);
    server.send(200, "application/json", "{\"reset\":true}"); });
  server.begin();
  Serial.println("HTTP server started");
}

// Arduino main loop: handle HTTP requests and latch timer
/**
 * @brief Arduino main loop: handle HTTP requests and latch timer
 */
/**
 * @brief Arduino main loop. Handles HTTP requests, D2 button, latch timer, and serial menu.
 */
void loop()
{
  /**
   * @brief Arduino main loop. Handles HTTP requests, D2 button, latch timer, and serial menu.
   */
  server.handleClient();

  // D2 push button: toggles D1 on press, respects latch
  bool d2State = digitalRead(kD2Pin);
  if (!d2State && lastD2State)
  { ///< Button pressed (falling edge)
    Serial.print("[D2] Button pressed at millis=");
    Serial.println(millis());
    if (!isLatchActive())
    {
      Serial.println("[D2] Toggling D1");
      toggleD1();
    }
    else
    {
      Serial.println("[D2] Latch active, toggle ignored");
    }
  }
  if (d2State != lastD2State)
  {
    Serial.print("[D2] Button state changed: ");
    Serial.println(d2State ? "RELEASED" : "PRESSED");
  }
  lastD2State = d2State;

  // Latch timer: clear expired latch to allow new toggles
  clearExpiredLatch();

  // Serial menu: print status if 'm', 'M', or '?' received
  if (Serial.available() > 0)
  {
    int c = Serial.read();
    if (c == 'm' || c == 'M' || c == '?')
    {
      WifiConfig cfg;
      loadWifiConfig(cfg);
      printMenu(cfg);
    }
  }
}
