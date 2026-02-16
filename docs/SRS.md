- The ON button shall be disabled when D1 is ON, and enabled otherwise.
- The OFF button shall be disabled when D1 is OFF, and enabled otherwise.
## Latch Functionality Requirement

- The latch period is a lockout interval that prevents frequent state changes. When a state change (ON, OFF, TOGGLE) occurs, further changes are blocked for the latch period. After the latch period expires, the relay state remains as set; it does not auto-revert. The latch period can be disabled by setting it to 0 (no lockout). The minimum allowed value for the latch (if enabled) is 1 second. Any attempt to set the latch to a negative value or above the maximum must be rejected.
# Software Requirements Specification (SRS)

## Project: ESP-SaturnPSU_Control

### 1. Introduction
#### 1.1 Purpose
This document specifies the requirements for the ESP-SaturnPSU_Control project, which provides firmware and a web-based user interface for controlling a relay (D1) on an ESP8266-based power supply unit, including REST API access, web UI, and automation support.

#### 1.2 Scope
- Control and monitor the D1 relay via web UI and REST API
- Configure latch timing for relay
- Provide feedback and debug information to the user
- Support automated build, upload, and test workflows

#### 1.3 Definitions
- **D1**: The relay control pin on the ESP8266
- **Latch**: The period (in seconds) during which the D1 status cannot be changed after activation
- **REST API**: HTTP endpoints for remote control
- **Web UI**: Browser-based interface served from the device

### 1.4 Constraints
- The default latch period shall be 5 seconds.
- The minimum latch period shall be 1 second.
- The maximum latch period shall be 3600 seconds (1 hour).
- Latch period values outside this range shall be rejected by the system.
- The system shall initialize with the default latch period on first boot or after a reset.

### 1.5 UI Constraints
- The web UI shall be responsive and usable on both desktop and mobile devices.
- All interactive elements (buttons, inputs) shall be clearly labeled and accessible.
- The ON button shall be green if D1 is 1 (ON), and red otherwise.
- The OFF button shall be red if D1 is 1 (ON), and green otherwise.
- The TOGGLE button shall always be blue.
- The REFRESH button shall always be yellow.
- When the latch is active, the ON, OFF, and TOGGLE buttons shall be disabled.
- The status refresh interval shall be every 200 milliseconds.
- The debug log shall always be visible and update in real time.
- The latch period input shall restrict values to the allowed range (1–3600 seconds).
- The UI shall provide clear feedback for all user actions and errors.
- The UI shall include a link to the project’s GitHub repository in the footer.
- The UI shall not require any external resources at runtime (self-contained).

### 2. Overall Description
#### 2.1 Product Perspective
- Runs on ESP8266 NodeMCU hardware
- Uses PlatformIO for build and deployment
- Web UI is served from LittleFS
- REST API provides programmatic access

#### 2.2 Product Functions
- Turn D1 ON, OFF, or TOGGLE
- Set latch period
- Display current D1 and latch status
- Show debug log in UI
- Visual feedback for D1 state in UI
- Automated build/upload/monitor script

#### 2.3 User Classes
- End User: Controls relay via web UI
- Integrator: Uses REST API for automation
- Developer: Builds, uploads, and tests firmware

#### 2.4 Operating Environment
- ESP8266 NodeMCU
- Modern web browser
- PlatformIO toolchain

### 3. Specific Requirements
#### 3.1 Functional Requirements
- [FR1] The system shall provide a web UI to control D1 (ON/OFF/TOGGLE)
- [FR2] The system shall provide a REST API for D1 control and status
- [FR3] The system shall allow setting the latch period via UI and API
- [FR4] The UI shall display the current D1 state and latch period
- [FR5] The UI shall visually highlight the ON/OFF button matching D1 state
- [FR6] The UI shall show a debug log of recent actions
- [FR7] The UI shall poll the backend for status updates every 200 milliseconds
- [FR8] The system shall provide a link to the GitHub project in the UI footer
- [FR9] The system shall support automated build, upload, and monitor via script

#### 3.2 Non-Functional Requirements
- [NFR1] The UI shall be responsive and mobile-friendly
- [NFR2] The system shall handle API errors gracefully and inform the user
- [NFR3] The firmware and UI shall be self-contained and require no external dependencies at runtime
- [NFR4] The system shall be open source and documented

### 4. External Interface Requirements
#### 4.1 Hardware Interfaces
- ESP8266 NodeMCU with relay on D1

#### 4.2 Software Interfaces
- REST API endpoints: /api/v1/on, /api/v1/off, /api/v1/toggle, /api/v1/status, /api/v1/latch, /api/v1/reset
- Web UI: index.html served from LittleFS

#### 4.3 Communications Interfaces
- HTTP over WiFi

### 5. Other Requirements
- The project repository shall include documentation and automation scripts
- The system shall be validated using automated tests

---
End of SRS
