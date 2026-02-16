FROM python:3.11-slim

# Install minimal system dependencies
RUN apt-get update \
    && apt-get install -y wget gnupg unzip curl xvfb git \
    && rm -rf /var/lib/apt/lists/*

# Install Robot Framework and required libraries
RUN pip install --no-cache-dir robotframework robotframework-requests robotframework-seleniumlibrary selenium

WORKDIR /tests

COPY scripts/test_api.robot ./test_api.robot
COPY scripts/test_ui.robot ./test_ui.robot

ENV DEVICE_IP=192.168.1.107

CMD Xvfb :99 -screen 0 1920x1080x24 & export DISPLAY=:99 && tail -f /dev/null
