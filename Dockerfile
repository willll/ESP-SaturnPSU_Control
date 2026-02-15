# Single-container Dockerfile for Robot Framework API and UI tests with Chrome
FROM python:3.11-slim

# Install system dependencies (minimal)
RUN apt-get update && \
    apt-get install -y wget gnupg unzip curl xvfb git && \
    rm -rf /var/lib/apt/lists/*



# Remove Chrome and ChromeDriver installation (handled by selenium/standalone-chrome)


# Install Robot Framework and libraries
RUN pip install --no-cache-dir robotframework robotframework-requests robotframework-seleniumlibrary

# Ensure robotframework-ctrf CLI is available
RUN ln -s $(python3 -m site --user-base)/bin/robotframework-ctrf /usr/local/bin/robotframework-ctrf || true

# Remove Node.js and ctrf-html-reporter (handled in separate container)

# Set workdir
WORKDIR /tests


# Copy test suites
COPY scripts/test_api.robot ./test_api.robot
COPY scripts/test_ui.robot ./test_ui.robot


# Set default device IP (can be overridden)
ENV DEVICE_IP=192.168.1.107

# Run Xvfb and keep container ready for test execution
CMD Xvfb :99 -screen 0 1920x1080x24 & export DISPLAY=:99 && tail -f /dev/null
