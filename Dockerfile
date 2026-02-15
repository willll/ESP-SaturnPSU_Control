# Single-container Dockerfile for Robot Framework API and UI tests with Chrome
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && \
    apt-get install -y wget gnupg unzip curl xvfb libxi6 libgconf-2-4 libnss3 libxss1 libappindicator3-1 fonts-liberation libatk-bridge2.0-0 libgtk-3-0 && \
    rm -rf /var/lib/apt/lists/*

# Install Google Chrome
RUN wget -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get update && \
    apt-get install -y /tmp/chrome.deb && \
    rm /tmp/chrome.deb

# Install ChromeDriver (matching Chrome version)
RUN CHROME_VERSION=$(google-chrome --version | awk '{print $3}' | cut -d. -f1) && \
    DRIVER_VERSION=$(curl -sS https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$CHROME_VERSION) && \
    wget -O /tmp/chromedriver.zip https://chromedriver.storage.googleapis.com/${DRIVER_VERSION}/chromedriver_linux64.zip && \
    unzip /tmp/chromedriver.zip -d /usr/local/bin/ && \
    rm /tmp/chromedriver.zip

# Install Robot Framework and libraries
RUN pip install --no-cache-dir robotframework robotframework-requests robotframework-seleniumlibrary robotframework-ctrf

# Set workdir
WORKDIR /tests

# Copy test suites and runner
COPY scripts/test_api.robot ./test_api.robot
COPY scripts/test_ui.robot ./test_ui.robot
COPY scripts/run_robot_tests.sh ./run_robot_tests.sh
RUN chmod +x ./run_robot_tests.sh

# Set default device IP (can be overridden)
ENV DEVICE_IP=192.168.1.107

# Run Xvfb and all tests
CMD Xvfb :99 -screen 0 1920x1080x24 & \
    export DISPLAY=:99 && \
    ./run_robot_tests.sh
