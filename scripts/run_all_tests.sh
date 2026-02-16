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

# Wait for device HTTP server to be up and return HTTP 200
echo
echo "========================================="
echo "Waiting for device HTTP server at:"
echo "  http://$DEVICE_IP/api/v1/status"
echo "========================================="
success=0
for i in $(seq 1 30); do
  http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$DEVICE_IP/api/v1/status" 2>&1)
  if [ "$http_code" = "200" ]; then
    echo "[Attempt $i/30] Device HTTP server is UP (HTTP 200)"
    success=1
    break
  else
    echo "[Attempt $i/30] Not ready (HTTP code: $http_code)"
    sleep 1
  fi
done
if [ "$success" -ne 1 ]; then
  echo
  echo "ERROR: Device HTTP server not responding with HTTP 200 at http://$DEVICE_IP/api/v1/status after 30 attempts."
  exit 1
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
    # Build report-converter image if not present
    if ! docker image inspect report-converter >/dev/null 2>&1; then
      docker build -f report-converter/Dockerfile.report-converter -t report-converter ./report-converter
    fi
    # Use report-converter container to generate HTML report directly from Robot Framework XML output
    docker run --rm \
      -v "$PWD/results":/converter/results \
      -w /converter/results \
      report-converter ctrf-html-reporter combined_output.xml ctrt_report.html;
    echo "HTML report generated at results/ctrt_report.html";
  '
