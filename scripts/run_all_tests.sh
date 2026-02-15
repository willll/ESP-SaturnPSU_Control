#!/bin/sh
# Entrypoint: run API and UI tests using Selenium remote Chrome in Docker

set -e

OUTDIR=results
# Empty the results directory before running tests
rm -rf "$OUTDIR"/*
mkdir -p "$OUTDIR"

: "${DEVICE_IP:=192.168.1.107}"
SELENIUM_REMOTE_URL=${SELENIUM_REMOTE_URL:-http://localhost:4444/wd/hub}

# Start Selenium Chrome if not running
if ! docker ps | grep -q selenium-chrome; then
  docker run -d --name selenium-chrome -p 4444:4444 selenium/standalone-chrome:latest
fi

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
      if command -v ctrf-html-reporter >/dev/null 2>&1; then
        ctrf-html-reporter results/ctrt_report.json results/ctrt_report.html;
        echo "HTML report generated at results/ctrt_report.html";
      else
        echo "ctrf-html-reporter not found. Install with: npm install -g ctrf-html-reporter";
      fi
    else
      echo "robotframework-ctrf not found. Install with: pip install robotframework-ctrf";
    fi
  '
