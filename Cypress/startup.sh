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
TERMINAL_HOLD=${TERMINAL_HOLD:-true}

# -------------------------
# Start Virtual Display
# -------------------------
echo "------------------------------------------------"
echo "Starting Virtual Display (Xvfb)"
echo "------------------------------------------------"
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset > /tmp/xvfb.log 2>&1 &
sleep 2

# -------------------------
# Start dbus
# -------------------------
echo "------------------------------------------------"
echo "Starting dbus"
echo "------------------------------------------------"
mkdir -p /var/run/dbus
dbus-daemon --system --fork --print-pid > /tmp/dbus.log 2>&1 || true
sleep 1

# -------------------------
# Start XFCE Desktop (optional)
# -------------------------
echo "------------------------------------------------"
echo "Starting XFCE Desktop"
echo "------------------------------------------------"
# startxfce4 may return immediately; run in background
startxfce4 > /tmp/xfce.log 2>&1 &
sleep 6

# -------------------------
# Start x11vnc & noVNC
# -------------------------
echo "------------------------------------------------"
echo "Starting x11vnc (5900) and noVNC (6080)"
echo "------------------------------------------------"
# start x11vnc with no password (bind to all addresses inside container)
x11vnc -display :99 -forever -nopw -shared -rfbport 5900 > /tmp/x11vnc.log 2>&1 &
sleep 2
# start websockify/noVNC (web files should be provided by installed package)
websockify --web=/usr/share/novnc/ 6080 localhost:5900 > /tmp/novnc.log 2>&1 &
sleep 2

# -------------------------
# Launch Chrome (optional)
# -------------------------
if [ "$LAUNCH_BROWSER" = "true" ]; then
    echo "------------------------------------------------"
    echo "Launching Chrome (for manual observation)"
    echo "------------------------------------------------"
    google-chrome \
        --no-sandbox \
        --disable-gpu \
        --disable-dev-shm-usage \
        --disable-software-rasterizer \
        --disable-extensions \
        --no-first-run \
        --window-size=1280,1024 \
        "$APP_URL" >/dev/null 2>&1 &
fi

# -------------------------
# Check Chrome & ChromeDriver
# -------------------------
echo "------------------------------------------------"
echo "Checking Chrome & ChromeDriver"
echo "------------------------------------------------"
google-chrome --version || true
chromedriver --version || echo "Chromedriver Missing"

# -------------------------
# Run tests in terminal (Cypress via npm test)
# -------------------------
if [ "$RUN_TESTS" = "true" ] && [ -f "$APP_DIR/package.json" ]; then
    echo "------------------------------------------------"
    echo "Running npm test in terminal"
    echo "------------------------------------------------"
    # attempt to open a terminal window and run tests; if xfce terminal isn't available, fallback to background run
    if command -v xfce4-terminal >/dev/null 2>&1 && [ "$TERMINAL_HOLD" = "true" ]; then
        xfce4-terminal --hold -e "bash -c 'cd $APP_DIR && npm test; exec bash'" &
    else
        # fallback: run tests in background and write logs to file
        (cd "$APP_DIR" && npm test > /tmp/npm_test.log 2>&1) &
    fi
fi

# -------------------------
# Auto open latest HTML report (after a delay)
# -------------------------
(
    sleep 30
    latest_report=$(find "$APP_DIR" -maxdepth 5 -type f \
        \( -iname "index.html" -o -iname "report.html" -o -iname "cucumber-report.html" \
           -o -iname "overview-features.html" -o -iname "mochawesome.html" \) | head -1)
    if [ -n "$latest_report" ]; then
        echo "Opening report: $latest_report"
        google-chrome --no-sandbox "file://$latest_report" >/dev/null 2>&1 || true
    fi
) &

# -------------------------
# Container ready message
# -------------------------
echo "==================================================="
echo "Container Ready!"
echo "noVNC URL: http://localhost:6080  (if running locally)"
echo "Chrome and Terminal Launched (if configured)"
echo "Logs: /tmp/xvfb.log /tmp/x11vnc.log /tmp/novnc.log /tmp/npm_test.log"
echo "==================================================="

# Keep container running
tail -f /dev/null
