#!/bin/bash
# build_upload_monitor.sh - Build, upload firmware, reboot ESP8266, and start serial monitor
# Usage: ./scripts/build_upload_monitor.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# Build firmware
.venv/bin/pio run



# Upload LittleFS data folder
.venv/bin/pio run -t uploadfs
.venv/bin/pio run -t upload




# Kill any process holding the USB serial port after upload
UPLOAD_PORT=$(ls /dev/ttyUSB* 2>/dev/null | head -n1)
if [ -n "$UPLOAD_PORT" ]; then
	echo "Killing any process holding $UPLOAD_PORT..."
	fuser -k "$UPLOAD_PORT" 2>/dev/null || true
	sleep 2
else
	echo "No /dev/ttyUSB* found. Skipping port kill."
fi

# Extra wait to allow port to become available after upload
INITIAL_MONITOR_DELAY=8
echo "Waiting $INITIAL_MONITOR_DELAY seconds for port to become available..."
sleep $INITIAL_MONITOR_DELAY

# Attempt automatic reset using DTR/RTS (if supported)
echo "Attempting automatic reset via DTR/RTS..."
stty -F /dev/ttyUSB0 hupcl || true
sleep 1

# Try to start serial monitor, retry if port is busy
MAX_RETRIES=5
RETRY_DELAY=4
COUNT=0
while [ $COUNT -lt $MAX_RETRIES ]; do
	.venv/bin/pio device monitor -b 74880 && break
	echo "Monitor failed (port busy?), retrying in $RETRY_DELAY seconds... ($((COUNT+1))/$MAX_RETRIES)"
	sleep $RETRY_DELAY
	COUNT=$((COUNT+1))
done

# If still failed, prompt for manual reset and retry once more
if [ $COUNT -eq $MAX_RETRIES ]; then
	echo "Automatic reset failed or port still busy."
	echo "Please manually press the RESET button on your ESP8266, then press [ENTER] to continue."
	read -r
	echo "Retrying to connect serial monitor..."
	.venv/bin/pio device monitor -b 74880 || {
		echo "Failed to start serial monitor after manual reset."
		exit 1
	}
fi
