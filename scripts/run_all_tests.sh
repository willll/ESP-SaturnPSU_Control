#!/bin/sh
# Entrypoint: run API and UI tests using Selenium remote Chrome

# Start Selenium Chrome in background (if not already running)
# (In multi-container setups, Selenium should be started separately)

# Run API tests
robot --variable DEVICE_IP:$DEVICE_IP test_api.robot

# Run UI tests, using Selenium remote
robot --variable DEVICE_IP:$DEVICE_IP --variable SELENIUM_REMOTE_URL:$SELENIUM_REMOTE_URL test_ui.robot
