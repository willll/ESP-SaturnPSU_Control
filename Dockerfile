# Dockerfile for ESP8266 D1 Control Robot Framework API tests
FROM python:3.11-slim

# Install Robot Framework and RequestsLibrary
RUN pip install --no-cache-dir robotframework robotframework-requests

# Set workdir
WORKDIR /tests

# Copy test suite
COPY scripts/test_api.robot ./test_api.robot

# Set default device IP (can be overridden)
ENV DEVICE_IP=192.168.1.107

# Run tests (override DEVICE_IP with -e if needed)
CMD ["sh", "-c", "robot --variable DEVICE_IP:$DEVICE_IP test_api.robot"]
