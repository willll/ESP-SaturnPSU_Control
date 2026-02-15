#!/bin/sh
# Run all Robot Framework API and UI tests in Docker and generate a CTRF report

set -e

OUTDIR=results
mkdir -p "$OUTDIR"

# Set default DEVICE_IP if not set
: "${DEVICE_IP:=192.168.1.107}"

# Build test image if not present
if ! docker image inspect esp-saturnpsu-test >/dev/null 2>&1; then
  docker build -t esp-saturnpsu-test .
fi

# Start Selenium Chrome if not running
if ! docker ps | grep -q selenium-chrome; then
  docker run -d --name selenium-chrome -p 4444:4444 selenium/standalone-chrome:latest
fi

# Run tests in Docker, mounting scripts and results
# DEVICE_IP and SELENIUM_REMOTE_URL can be set as needed
SELENIUM_REMOTE_URL=${SELENIUM_REMOTE_URL:-http://localhost:4444/wd/hub}

docker run --rm \
  --network host \
  -e DEVICE_IP="$DEVICE_IP" \
  -e SELENIUM_REMOTE_URL="$SELENIUM_REMOTE_URL" \
  -v "$PWD/scripts":/tests/scripts \
  -v "$PWD/results":/tests/results \
  -w /tests \
  esp-saturnpsu-test sh -c '
    robot --outputdir results --output api_output.xml --report NONE --log NONE scripts/test_api.robot &&
    robot --outputdir results --output ui_output.xml --report NONE --log NONE scripts/test_ui.robot &&
    rebot --outputdir results --output combined_output.xml results/api_output.xml results/ui_output.xml &&
    if command -v robotframework-ctrf >/dev/null 2>&1; then
      robotframework-ctrf results/combined_output.xml > results/ctrt_report.json;
      echo "CTRF report generated at results/ctrt_report.json";
    else
      echo "robotframework-ctrf not found. Install with: pip install robotframework-ctrf";
    fi
  '
