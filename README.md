
# ESP8266 D1 HTTP Control

[YouTube Demo: ESP8266 D1 Control Device](https://www.youtube.com/watch?v=zFmUQA3u5PM)

This project runs on an ESP8266 NodeMCU (ESP-12E, CP2102) and exposes a web page plus a REST API to control the D1 pin (GPIO5).

**Vibe coded project for learning purpose only.**

## Hardware Features
- **D1 (GPIO5):** Relay control output (active HIGH)
- **D2 (GPIO4):** Physical NO push button for manual D1 toggle (debounced, respects latch period)
- **Optional:** 10kΩ pull-up resistor for D2 (use only if internal pull-up is insufficient)
- **Relay:** Omron G6B-1114P-US or compatible
- **See:** `hw/BOM_ESP8266_Relay_Control.txt` for full parts list

## Requirements
- PlatformIO (recommended)
- ESP8266 NodeMCU (ESP-12E)
- Python 3.8+ with pip

## Install PlatformIO CLI (Linux)

### Option A: pipx (isolated install, recommended)
1) Install pipx

```bash
python3 -m pip install --user pipx
```

2) Ensure your shell can find pipx

```bash
python3 -m pipx ensurepath
```

3) Install PlatformIO

```bash
pipx install platformio
```

4) Open a new terminal and verify

```bash
pio --version
```

### Option B: pip (user install)
If you prefer not to use pipx:

```bash
python3 -m pip install --user platformio
```

Then verify:

```bash
pio --version
```

### Option C: system packages
Some distros ship a PlatformIO package (may be older). If you use it, ensure `pio --version` shows a recent release.

## USB serial permissions (Linux)
If upload or monitor fails with permission errors, add your user to the serial group and re-login:

```bash
sudo usermod -a -G dialout "$USER"
```

After logging out and back in, confirm access:

```bash
groups
```

Typical device nodes for CP2102 are `/dev/ttyUSB0` or `/dev/ttyUSB1`.

## Regenerate venv and build tools
This project includes a small bootstrap script and `requirements.txt` to recreate the local Python virtual environment and prefetch PlatformIO build tools.

Files:
- `requirements.txt`: Python dependencies for the local venv (includes PlatformIO CLI)
- `scripts/bootstrap.sh`: Creates `.venv`, installs dependencies, and downloads PlatformIO packages

Clean start (optional):

```bash
rm -rf .venv .pio
```

If you also want to wipe globally cached PlatformIO packages (not required):

```bash
rm -rf ~/.platformio
```

Run the bootstrap script:

```bash
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
```

After bootstrap, build as usual:

```bash
./.venv/bin/pio run
```

## WiFi configuration
WiFi credentials are loaded from an unencrypted JSON file on LittleFS.

1. Copy data/wifi_replace_me.json to data/wifi.json
2. Edit data/wifi.json with your credentials
3. Upload the filesystem (see below)

### JSON schema
- `ssid` (string, required): WiFi network name
- `password` (string, required): WiFi password (can be empty for open networks)
- `hostname` (string, optional): Device hostname shown by the router
- `connect_timeout_ms` (number, optional): Max time to wait for WiFi connect; default is 20000
- `notes` (array of strings, optional): Any extra notes; ignored by firmware

Example (wifi_replace_me.json):

```json
{
	"ssid": "your-ssid",
	"password": "your-password",
	"hostname": "esp8266-d1",
	"connect_timeout_ms": 20000,
	"notes": [
		"Replace ssid/password with your network",
		"Extra fields are ignored by the firmware"
	]
}
```

Upload the filesystem before flashing the firmware:

```bash
pio run -t uploadfs
```

## mDNS (Multicast DNS) Support

The device automatically registers on your local network using mDNS, making it accessible via a friendly hostname instead of IP address.

### How to Access

**Web UI:**
```
http://<hostname>.local
```

**REST API:**
```
http://<hostname>.local/api/v1/status
```

**Example:** If your wifi.json has `"hostname": "saturnpsu"`, access it at:
```
http://saturnpsu.local
```

### Test mDNS Connectivity

From any device on the same network, ping the device to verify mDNS registration:

```bash
ping saturnpsu.local
```

**Expected output:**
```
64 bytes from 192.168.1.106: seq=0 ttl=255 time=2.230 ms
```

### mDNS Requirements

- Device and client must be on the **same WiFi network**
- Client device needs **mDNS support** (built-in on macOS, Linux, Windows 10+)
- Hostname must be set in `wifi.json` (see WiFi configuration section above)
- If hostname is empty, mDNS responder is disabled

### Hostname Configuration

Edit `data/wifi.json`:

```json
{
  "hostname": "saturnpsu"
}
```

After changing the hostname, re-upload the filesystem:

```bash
pio run -t uploadfs
```

Reboot the device or power cycle to apply.

## Build and upload

```bash
pio run -t upload
```

Open serial monitor at 74880 to see the device IP and boot logs:

```bash
pio device monitor -b 74880
```
If you are using VS Code tasks, run:
- PlatformIO: Monitor


## Web UI Features

Visit the device IP in a browser to open the control page. The web UI provides:

- **ON/OFF/TOGGLE Buttons:** Instantly control the D1 pin state. Button color reflects the current state (green for ON, red for OFF). Buttons are disabled while the latch is active or if the action is not allowed.
- **Latch Period Input:** Set the latch period (in seconds) to prevent rapid toggling. The input is for user entry only and is not auto-refreshed from device status. Allowed range: 1–3600 seconds.
- **Status Display:** Shows the current D1 state and latch period, updates in real time (every 200ms).
- **Debug Log:** Scrollable area below the controls displays recent debug messages, actions, and API errors. Auto-scrolls as new messages arrive.
- **No Refresh Button:** The UI auto-updates status and disables the Refresh button (removed in latest version).

### Example UI

![Web UI Screenshot 1](docs/screenshot1.png)
*Main control panel with ON/OFF/TOGGLE, latch input, and debug log.*

> **Tip:** If you see 'Status: ERROR' or debug messages about API failures, check your device connection and network.


## Physical Push Button (D2)

- **D2 (GPIO4):** Connect a normally open (NO) push button between D2 and GND.
- **Behavior:** Pressing the button toggles D1, subject to the latch period (cannot toggle if latch is active). Input is debounced in firmware.
- **Optional:** Add a 10kΩ pull-up resistor if needed (firmware uses INPUT_PULLUP).

## REST API

### REST API Endpoints

| Method | Path           | Description                                                      | Status | Response           |
|--------|----------------|------------------------------------------------------------------|---------|--------------------|
| GET    | /              | Web UI (HTML page)                                               | 200   | (HTML)                     |
| GET    | /api/v1/status | Get current relay status and latch info                          | 200   | See example below |
| POST   | /api/v1/on     | Set D1 HIGH (ON), starts latch timer if set                      | 200/423 | `{ "relay_status": "ON", ... }`              |
| POST   | /api/v1/off    | Set D1 LOW (OFF), starts latch timer if set                      | 200/423 | `{ "relay_status": "OFF", ... }`              |
| POST   | /api/v1/toggle | Toggle D1 state, starts latch timer if set                       | 200/423 | `{ "relay_status": "ON\|OFF", ... }` |
| GET    | /api/v1/latch  | Get current latch period (seconds)                               | 200   | `{ "latch": 5 }`           |
| POST   | /api/v1/latch  | Set latch period (1-3600 seconds, constraints enforced)          | 200/400 | `{ "latch": 10 }`          |
| GET    | /menu          | Plain-text status menu (for legacy/CLI use)                      | 200   | (text)                     |
| POST   | /api/v1/reset  | Clear latch, set D1 LOW (test setup/reset)                       | 200   | `{ "reset": true }`         |
| GET    | /openapi.yaml  | OpenAPI 3.0 specification of this API                            | 200   | (YAML)                     |

### Status Endpoint Response Format

```json
{
  "relay_status": "ON",
  "latch": 5,
  "latch_timer_active": false,
  "latch_timer_expiry": 0,
  "millis": 1234567
}
```

| Field | Type | Description |
|-------|------|-------------|
| `relay_status` | string | Current relay state: `"ON"` or `"OFF"` |
| `latch` | number | Latch period in seconds (1–3600, or clamped) |
| `latch_timer_active` | boolean | True if latch is currently active and preventing changes |
| `latch_timer_expiry` | number | Milliseconds when latch expires (0 if not active) |
| `millis` | number | Device uptime in milliseconds (for sync reference) |

### HTTP Status Codes

| Code | Meaning | Example |
|------|---------|---------|
| **200** | Success | Any control or status request succeeded |
| **400** | Bad Request | Invalid JSON in POST body or missing required fields |
| **423** | Locked | Latch is active; state change blocked until latch expires |
| **404** | Not Found | Endpoint doesn't exist |
| **500** | Server Error | Firmware error (rare) |

### Usage Examples

#### Get Current Status
```bash
curl http://saturnpsu.local/api/v1/status
```

**Response:**
```json
{
  "relay_status": "OFF",
  "latch": 5,
  "latch_timer_active": false,
  "latch_timer_expiry": 0,
  "millis": 42325
}
```

#### Turn Relay ON
```bash
curl -X POST http://saturnpsu.local/api/v1/on
```

**Response (200):**
```json
{
  "relay_status": "ON",
  "latch": 5,
  "latch_timer_active": true,
  "latch_timer_expiry": 47325,
  "millis": 42325
}
```

**Response if latch active (423):**
```json
{
  "error": "Latch active"
}
```

#### Set Latch Period
```bash
curl -X POST http://saturnpsu.local/api/v1/latch \
  -H "Content-Type: application/json" \
  -d '{"latch": 10}'
```

**Response (200):**
```json
{
  "latch": 10
}
```

**Invalid constraints (auto-clamped to 1-3600):**
```bash
# Request: latch = 0 (below minimum)
curl -X POST http://saturnpsu.local/api/v1/latch \
  -H "Content-Type: application/json" \
  -d '{"latch": 0}'
# Response: {"latch": 1}  (clamped to min)

# Request: latch = 9999 (above maximum)
curl -X POST http://saturnpsu.local/api/v1/latch \
  -H "Content-Type: application/json" \
  -d '{"latch": 9999}'
# Response: {"latch": 3600}  (clamped to max)
```

#### Toggle Relay
```bash
curl -X POST http://saturnpsu.local/api/v1/toggle
```

#### Get Latch Period
```bash
curl http://saturnpsu.local/api/v1/latch
```

**Response:**
```json
{
  "latch": 5
}
```

#### Reset (Clear latch, set D1 LOW)
```bash
curl -X POST http://saturnpsu.local/api/v1/reset
```

**Response:**
```json
{
  "reset": true
}
```

### API Behavior Notes

- **Latch Constraints:** Latch period is automatically clamped to 1–3600 seconds. Values of 0 or below are set to 1; values above 3600 are set to 3600.
- **Latch Behavior:** When a control endpoint (on/off/toggle) executes successfully, a latch timer starts. Any subsequent control requests return **423 Locked** until the timer expires.
- **No Auto-Revert:** After the latch expires, the relay **remains in its set state** (does not auto-revert).
- **Idempotent:** All endpoints are safe to call repeatedly; duplicate requests are harmless.
- **mDNS Support:** Endpoints are accessible via `http://<hostname>.local/api/v1/...` on any client on the same network.

### OpenAPI Specification

Full OpenAPI 3.0 specification available at:
```
GET /openapi.yaml
```

Serve in [SwaggerUI](https://swagger.io/tools/swagger-ui/) or [ReDoc](https://redoc.ly/) for interactive exploration.


#### Details

- **/api/v1/on, /api/v1/off, /api/v1/toggle:** All return the new D1 state as JSON. If the latch is active, state changes are rejected with `{ "error": "Latch active" }` and HTTP 423.
- **/api/v1/latch:** GET returns current latch period; POST sets a new period (range: 1–3600 seconds). Returns new value as JSON. Setting to 0 disables the latch.
- **/api/v1/reset:** For test setup. Immediately disables latch and sets D1 LOW. Always returns `{ "reset": true }`.
- **/api/v1/status:** Returns current D1 state and latch timer (if active).
- **/menu:** Returns a plain-text status summary for CLI/legacy use.

##### Example: /api/v1/status
```json
{"relay_status":"ON", "latch":0}
```

##### Example: /api/v1/latch (POST)
Request:
```json
{"latch": 10}
```
Response:
```json
{"latch": 10}
```
*Note: Latch period must be between 1 and 3600 seconds. 0 disables latch. See SRS for details.*

##### Example: /api/v1/reset
Request:
```bash
curl -X POST http://<device-ip>/api/v1/reset
```
Response:
```json
{"reset":true}
```

## Automated Testing

This project includes automated and manual test suites for firmware, REST API, web UI, and hardware features:

- **Robot Framework API tests** (recommended, runs in Docker):
	- Location: `scripts/test_api.robot`
	- Run with Docker:
		```bash
		docker build -t esp8266-robot-tests .
		docker run --rm -e DEVICE_IP=192.168.1.107 esp8266-robot-tests
		```
		(Replace the IP as needed.)
	- See `scripts/robot_test_README.md` for details.

- **Python API test script** (optional):
	- Location: `scripts/test_api.py`
	- Run with:
		```bash
		python3 scripts/test_api.py 192.168.1.107
		```

- **Manual Hardware/UI Tests:**
	- See `docs/test-campaign.md` for a full checklist, including:
		- D2 push button toggles D1, respects latch period, and is debounced
		- UI disables ON/OFF/TOGGLE during latch
		- Latch input is input-only (not auto-refreshed)
		- No Refresh button (UI auto-updates)
		- All REST API and UI features

Test results are shown in the terminal or browser. The Robot Framework suite covers all REST API endpoints and device logic.


## Test Campaign

See `docs/test-campaign.md` for a full manual and automated test checklist covering:
- Firmware and REST API
- Web UI (including D2 push button and latch logic)
- Hardware wiring and deployment
- Documentation completeness


## Hardware Images

### Device Front View 1
![Device Front 1](docs/Front_1.jpg)

### Device Front View 2
![Device Front 2](docs/Front_2.jpg)


## Notes
- D1 corresponds to GPIO5 (relay control output)
- D2 corresponds to GPIO4 (NO push button input)
- The control output is active HIGH by default
- Latch period prevents rapid toggling; minimum 1s, maximum 3600s
- D2 input is debounced and respects latch lockout
- UI disables ON/OFF/TOGGLE during latch; latch input is not auto-refreshed
- See SRS and test campaign for full requirements