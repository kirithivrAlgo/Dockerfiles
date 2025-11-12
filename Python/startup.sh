#!/bin/bash
set -e
 
export DISPLAY=:99
export XAUTHORITY=/root/.Xauthority
VNC_PORT=5900
NOVNC_PORT=6080
NOVNC_DIR="/opt/noVNC"
APP_DIR="/app"
REPORT_DIR="$APP_DIR/reports"
 
echo "===================================================="
echo "Starting Headless GUI Environment (XFCE + Chrome)"
echo "===================================================="
 
mkdir -p "$REPORT_DIR"/{screenshots,logs,allure,json,temp}
touch "$XAUTHORITY"
 
# Start virtual display
echo "Starting Xvfb on display $DISPLAY ..."
Xvfb "$DISPLAY" -screen 0 1920x1080x24 -ac +extension GLX +render -noreset &
sleep 2
 
# Setup Xauthority
echo "Configuring Xauthority ..."
xauth add "$DISPLAY" . "$(mcookie)"
 
# Start VNC server
echo "Starting x11vnc server on port ${VNC_PORT} ..."
x11vnc -forever -nopw -shared -display "$DISPLAY" -rfbport "$VNC_PORT" -auth "$XAUTHORITY" \
> "$REPORT_DIR/logs/x11vnc.log" 2>&1 &
 
# Start XFCE desktop
echo "Starting XFCE desktop environment ..."
/usr/bin/startxfce4 --replace > "$REPORT_DIR/logs/xfce.log" 2>&1 &
sleep 3
 
# Launch Chrome
echo "Launching Google Chrome ..."
google-chrome --no-sandbox --disable-dev-shm-usage --disable-gpu --start-maximized > "$REPORT_DIR/logs/chrome.log" 2>&1 &
 
# Start noVNC server
echo "Starting noVNC on port ${NOVNC_PORT} ..."
/opt/noVNC/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NOVNC_PORT \
> "$REPORT_DIR/logs/novnc.log" 2>&1 &
 
sleep 3
echo "GUI accessible at: http://localhost:${NOVNC_PORT}/vnc.html"
echo "(No password required; click 'Connect' to access the desktop)"
 
# Run Behave tests if 'features' folder exists
cd "$APP_DIR"
if [ -d "features" ]; then
  echo "Running Behave tests (Allure + Pretty mode)..."
  xfce4-terminal --title="Behave Tests" \
    -e "bash -c 'behave -f allure_behave.formatter:AllureFormatter -o $REPORT_DIR/allure -f pretty $APP_DIR/features 2>&1 | tee $REPORT_DIR/logs/behave.log; exec bash'" &
else
  echo "No 'features' folder found. Opening desktop only."
  xfce4-terminal --title="Desktop Shell" &
fi
 
echo "===================================================="
echo "Container ready — GUI available at: http://localhost:${NOVNC_PORT}/vnc.html"
echo "===================================================="
 
# Keep container running
tail -f /dev/null
