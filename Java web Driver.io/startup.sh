#!/bin/bash
set -e

APP_DIR=/app
export DISPLAY=:99

echo "-------------------------------------------------"
echo "Starting Virtual Display (Xvfb)"
echo "-------------------------------------------------"
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset &
sleep 2

echo "Starting dbus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork >/dev/null 2>&1 || true
sleep 1

echo "Starting x11vnc on port 5900"
x11vnc -display :99 -forever -nopw -shared -rfbport 5900 > $APP_DIR/x11vnc.log 2>&1 &
sleep 2

echo "Starting noVNC on http://localhost:6080"
nohup /opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 6080 \
    > $APP_DIR/novnc.log 2>&1 &
sleep 3

echo "Starting XFCE Desktop Environment"
nohup startxfce4 > $APP_DIR/xfce.log 2>&1 &
sleep 10

echo "-------------------------------------------------"
echo "Running WebdriverIO / Cucumber Tests"
echo "-------------------------------------------------"

if npm run test --if-present; then
    echo "Tests executed using npm run test"
elif npx wdio run wdio.conf.js; then
    echo "Tests executed using npx wdio"
elif npx cucumber-js; then
    echo "Tests executed using cucumber-js"
else
    echo "No known test command found."
    echo "Make sure your package.json contains:"
    echo "  \"test\": \"wdio run wdio.conf.js\""
fi

echo "-------------------------------------------------"
echo "All processes started successfully"
echo "GUI: http://localhost:6080"
echo "Reports in /app/reports"
echo "-------------------------------------------------"

tail -f /dev/null
