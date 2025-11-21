#!/bin/bash
set -e

export DISPLAY=:99
export XAUTHORITY=/root/.Xauthority
APP_DIR="/app"
LOG_DIR="$APP_DIR/logs"

VNC_PORT=5900
NOVNC_PORT=6080
NOVNC_DIR="/opt/noVNC"

mkdir -p "$LOG_DIR"
touch "$XAUTHORITY"

echo "Starting Xvfb..."
Xvfb :99 -screen 0 1920x1080x24 -ac >"$LOG_DIR/xvfb.log" 2>&1 &
sleep 3

echo "Starting dbus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork >"$LOG_DIR/dbus.log" 2>&1 || true
sleep 1

echo "Starting x11vnc..."
x11vnc -display :99 -forever -nopw -shared -rfbport $VNC_PORT >"$LOG_DIR/x11vnc.log" 2>&1 &
sleep 2

echo "Starting XFCE..."
startxfce4 >"$LOG_DIR/xfce.log" 2>&1 &
sleep 7

echo "Starting noVNC..."
$NOVNC_DIR/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NOVNC_PORT >"$LOG_DIR/novnc.log" 2>&1 &
sleep 3

# -------------------------------
# 🟢 OPEN TERMINAL + RUN TESTS AUTO
# -------------------------------
CS_PROJ=$(find "$APP_DIR" -name "*.csproj" | head -n 1)

echo "Opening Terminal + starting feature execution..."

xfce4-terminal --title="Feature Execution" \
  --geometry=120x30 \
  -e "bash -c '
      echo Building project...;
      dotnet build $CS_PROJ -c Release;
      echo Running Feature Files...;
      dotnet test $CS_PROJ --logger:\"trx;LogFileName=test_results.trx\";
      echo ALL TESTS FINISHED!;
      exec bash
  '" &
sleep 3

echo "Environment ready. Access GUI → http://localhost:${NOVNC_PORT}/vnc.html"

tail -f /dev/null
