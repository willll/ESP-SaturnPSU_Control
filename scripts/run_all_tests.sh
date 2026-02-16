#!/bin/sh
# Entrypoint: run API and UI tests using Selenium remote Chrome in Docker

set -e


OUTDIR=results
# Empty the results directory before running tests
rm -rf "$OUTDIR"/*
mkdir -p "$OUTDIR"

# Build test image if not present
if ! docker image inspect esp-saturnpsu-test >/dev/null 2>&1; then
  docker build -t esp-saturnpsu-test .
fi

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
    robot --outputdir results --output api_output.xml --report NONE --log NONE scripts/test_api.robot || true
    robot --outputdir results --output ui_output.xml --report NONE --log NONE scripts/test_ui.robot || true
    rebot --outputdir results --output combined_output.xml results/api_output.xml results/ui_output.xml || true
    if command -v robotframework-ctrf >/dev/null 2>&1; then
      robotframework-ctrf results/combined_output.xml > results/ctrt_report.json;
      echo "CTRF report generated at results/ctrt_report.json";
      # Build report-converter image if not present
      if ! docker image inspect report-converter >/dev/null 2>&1; then
        docker build -f report-converter/Dockerfile.report-converter -t report-converter ./report-converter
      fi
      # Use report-converter container to generate HTML report
      docker run --rm \
        -v "$PWD/results":/converter/results \
        -w /converter/results \
        report-converter ctrf-html-reporter ctrt_report.json ctrt_report.html;
      echo "HTML report generated at results/ctrt_report.html";
    else
      echo "robotframework-ctrf not found. Install with: pip install robotframework-ctrf";
    fi
  '
