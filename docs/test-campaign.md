# ESP8266 D1 Control Test Campaign

This document describes the recommended test campaign for the ESP8266 D1 Control project. It covers functional, integration, and UI tests to ensure reliability and usability.

## 1. Firmware/REST API Tests

### 1.1. Power-on and WiFi
- [ ] Device boots and connects to WiFi (check serial monitor for IP and status)
- [ ] Handles missing or invalid wifi.json gracefully (error message on serial)

### 1.2. REST API Endpoints
- [ ] `POST /api/on` sets D1 pin HIGH, returns success
- [ ] `POST /api/off` sets D1 pin LOW, returns success
- [ ] `POST /api/toggle` toggles D1 pin, returns new state
- [ ] `GET /api/status` returns current D1 state as JSON
- [ ] `GET /menu` returns plain-text status
- [ ] All endpoints handle errors (invalid method, malformed request)
- [ ] `POST /api/reset` clears latch and sets D1 LOW for test setup

### 1.3. Latch Logic
- [ ] Setting ON or OFF with a latch period reverts state after the correct time
- [ ] Latch period input of 0 disables latch
- [ ] Rapid toggling does not break latch logic

## 2. Web UI Tests

### 2.1. UI Elements
- [ ] ON, OFF, TOGGLE, and Refresh buttons are visible and enabled
- [ ] Latch period input is present and accepts numbers
- [ ] Debug log area is visible, fixed size, and scrolls automatically

### 2.2. UI Behavior
- [ ] Button color reflects D1 state (green for ON, orange for OFF)
- [ ] Status text updates after each action
- [ ] Debug log shows all actions, errors, and API failures
- [ ] Latch period input works as expected
- [ ] UI recovers gracefully from API/network errors

### 2.3. Browser Compatibility
- [ ] UI works in Chrome, Firefox, and Edge (basic test)
- [ ] Mobile browser layout is usable

## 3. Filesystem & Deployment
- [ ] All files in data/ are uploaded to LittleFS (index.html, main.js, style.css, wifi.json)
- [ ] Device serves latest UI after uploadfs

## 4. Documentation
- [ ] README is up to date and clear
- [ ] Screenshots are present in docs/ (if available)
- [ ] Test campaign is included in docs/

---

> Mark each test as complete after verification. Add notes for any failures or unexpected behavior.
