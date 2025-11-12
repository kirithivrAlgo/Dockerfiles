#!/bin/bash
set -euo pipefail

APP_DIR=/app
LOG_DIR="$APP_DIR/logs"
NOVNC_DIR="$APP_DIR/novnc"
export DISPLAY=:99
export PATH=$PATH:/usr/local/bin:/usr/bin:/opt/websockify-venv/bin
export CHROME_BIN=/usr/bin/google-chrome
mkdir -p "$LOG_DIR"

echo "===================================================="
echo "Starting Universal GUI (XFCE + Chrome + noVNC)"
echo "===================================================="

# 1. Start Xvfb (virtual display)
echo "Starting Xvfb..."
Xvfb :99 -screen 0 1920x1080x24 >"$LOG_DIR/xvfb.log" 2>&1 &
sleep 2
echo "Xvfb started"

# 2. Start dbus if missing
if [ ! -f /usr/share/dbus-1/system.conf ]; then
  mkdir -p /usr/share/dbus-1
  cat > /usr/share/dbus-1/system.conf <<'EOF'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>system</type>
  <listen>unix:path=/var/run/dbus/system_bus_socket</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
  </policy>
</busconfig>
EOF
fi
mkdir -p /var/run/dbus
dbus-daemon --system --fork >"$LOG_DIR/dbus.log" 2>&1 || true
sleep 1
echo "dbus running"

# 3. Start VNC + noVNC
echo "Starting x11vnc..."
x11vnc -display :99 -forever -nopw -rfbport 5900 -shared >"$LOG_DIR/x11vnc.log" 2>&1 &
sleep 2
echo "x11vnc ready (port 5900)"

echo "Starting noVNC..."
"$NOVNC_DIR/utils/novnc_proxy" --vnc localhost:5900 --listen 6080 >"$LOG_DIR/novnc.log" 2>&1 &
sleep 3
echo "noVNC available at http://localhost:6080"

# 4. Start XFCE desktop
echo "Starting XFCE..."
export $(dbus-launch | sed 's/; /\n/g')
startxfce4 >"$LOG_DIR/xfce.log" 2>&1 &
sleep 6
echo "XFCE started"

# 5. Launch Chrome automatically
echo "Launching Chrome..."
google-chrome --no-sandbox --disable-dev-shm-usage --start-maximized --new-window "about:blank" >"$LOG_DIR/chrome.log" 2>&1 &
sleep 4
echo "Chrome launched"

# 6. Detect test command (npm or playwright)
TEST_CMD=""
if [ -f "$APP_DIR/package.json" ]; then
  if grep -q '"test"' "$APP_DIR/package.json"; then
    TEST_CMD="npm run test"
  elif grep -q '"playwright"' "$APP_DIR/package.json"; then
    TEST_CMD="npx playwright test"
  fi
fi

if [ -z "$TEST_CMD" ]; then
  TEST_CMD="echo 'No test command found in package.json'; bash"
fi

# 7. Open terminal and execute test
echo "Opening XFCE Terminal to run tests..."
xfce4-terminal --disable-server --command "bash -c 'cd $APP_DIR && echo \"Running: $TEST_CMD\" && $TEST_CMD; echo \"Tests Finished.\"; exec bash'" >"$LOG_DIR/terminal.log" 2>&1 &
sleep 3
echo "Terminal running (visible in GUI)"

echo "----------------------------------------------------"
echo "Access GUI via: http://localhost:6080"
echo "Default view: Chrome + Terminal + Test Execution"
echo "----------------------------------------------------"

# Keep container alive
tail -f /dev/null
