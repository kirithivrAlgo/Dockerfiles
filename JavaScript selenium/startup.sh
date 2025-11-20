#!/bin/bash
set -e

# -------------------------
# Environment
# -------------------------
export DISPLAY=:99
export PATH=$PATH:/usr/local/bin:/usr/bin
export CHROME_BIN=/usr/bin/google-chrome
export CHROMEDRIVER=/usr/local/bin/chromedriver
APP_DIR=/app
APP_URL=${APP_URL:-https://demowebshop.tricentis.com/}
RUN_TESTS=${RUN_TESTS:-true}
LAUNCH_BROWSER=${LAUNCH_BROWSER:-true}

# -------------------------
# Start Virtual Display
# -------------------------
echo "------------------------------------------------"
echo "Starting Virtual Display (Xvfb)"
echo "------------------------------------------------"
Xvfb :99 -screen 0 1920x1080x24 & 
sleep 2

# -------------------------
# Start dbus
# -------------------------
echo "------------------------------------------------"
echo "Starting dbus"
echo "------------------------------------------------"
mkdir -p /var/run/dbus
dbus-daemon --system --fork --print-pid > $APP_DIR/dbus.log 2>&1 || true
sleep 1

# -------------------------
# Start XFCE Desktop
# -------------------------
echo "------------------------------------------------"
echo "Starting XFCE Desktop"
echo "------------------------------------------------"
startxfce4 > $APP_DIR/xfce.log 2>&1 &
sleep 10

# -------------------------
# Start x11vnc & noVNC
# -------------------------
echo "------------------------------------------------"
echo "Starting x11vnc (5900) and noVNC (6080)"
echo "------------------------------------------------"
x11vnc -display :99 -forever -nopw -shared -rfbport 5900 > $APP_DIR/x11vnc.log 2>&1 &
sleep 2
websockify --web=/usr/share/novnc/ 6080 localhost:5900 > $APP_DIR/novnc.log 2>&1 &
sleep 2

# -------------------------
# Launch Chrome
# -------------------------
if [ "$LAUNCH_BROWSER" = "true" ]; then
    echo "------------------------------------------------"
    echo "Launching Chrome"
    echo "------------------------------------------------"
    google-chrome \
        --no-sandbox \
        --disable-gpu \
        --disable-dev-shm-usage \
        --disable-software-rasterizer \
        --disable-extensions \
        --no-first-run \
        "$APP_URL" >/dev/null 2>&1 &
fi

# -------------------------
# Check Chrome & ChromeDriver
# -------------------------
echo "------------------------------------------------"
echo "Checking Chrome & ChromeDriver"
echo "------------------------------------------------"
google-chrome --version
chromedriver --version || echo "Chromedriver Missing"

# -------------------------
# Run tests in a single terminal
# -------------------------
if [ "$RUN_TESTS" = "true" ] && [ -f "$APP_DIR/package.json" ]; then
    echo "------------------------------------------------"
    echo "Running npm test in terminal"
    echo "------------------------------------------------"
    xfce4-terminal --hold -e "bash -c 'cd $APP_DIR && npm test; exec bash'" &
fi

# -------------------------
# Auto open latest HTML report
# -------------------------
(
    sleep 40
    latest_report=$(find "$APP_DIR" -maxdepth 5 -type f \
        \( -name "index.html" -o -name "report.html" -o -name "cucumber-report.html" \
           -o -name "overview-features.html" \) | head -1)
    if [ -n "$latest_report" ]; then
        google-chrome --no-sandbox "file://$latest_report" &
    fi
) &

# -------------------------
# Finished
# -------------------------
echo "==================================================="
echo "Container Ready!"
echo "noVNC URL: http://localhost:6080"
echo "Chrome and Terminal Launched"
echo "==================================================="

tail -f /dev/null
