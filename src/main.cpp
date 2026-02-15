#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ArduinoJson.h>
#include <LittleFS.h>

static const uint8_t kD1Pin = D1;
static ESP8266WebServer server(80);
static String lastWifiError;

struct WifiConfig {
  String ssid;
  String pass;
  String hostname;
  uint32_t connectTimeoutMs = 20000;
};

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

static void printMenu(const WifiConfig &cfg) {
  Serial.println("\n" + buildMenuText(cfg));
}

static void handleMenu() {
  WifiConfig cfg;
  loadWifiConfig(cfg);
  server.send(200, "text/plain", buildMenuText(cfg));
}

static void sendJsonStatus() {
  const char *state = digitalRead(kD1Pin) ? "1" : "0";
  String payload = String("{\"d1\":") + state + "}";
  server.send(200, "application/json", payload);
}

static void handleIndex() {
  File file = LittleFS.open("/index.html", "r");
  if (!file) {
    server.send(404, "text/plain", "index.html not found");
    return;
  }

  server.streamFile(file, "text/html");
  file.close();
}

static void handleOn() {
  digitalWrite(kD1Pin, HIGH);
  sendJsonStatus();
}

static void handleOff() {
  digitalWrite(kD1Pin, LOW);
  sendJsonStatus();
}

static void handleToggle() {
  digitalWrite(kD1Pin, !digitalRead(kD1Pin));
  sendJsonStatus();
}

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

  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();
  if (Serial.available() > 0) {
    int c = Serial.read();
    if (c == 'm' || c == 'M' || c == '?') {
      WifiConfig cfg;
      loadWifiConfig(cfg);
      printMenu(cfg);
    }
  }
}
