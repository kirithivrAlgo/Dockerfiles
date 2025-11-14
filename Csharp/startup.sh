#!/bin/bash
set -e

APP_DIR=/app
export DISPLAY=:99
export PATH=$PATH:/usr/local/bin:/usr/bin

echo "-------------------------------------------------"
echo "Starting Virtual Display (Xvfb)"
echo "-------------------------------------------------"
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset > $APP_DIR/xvfb.log 2>&1 &
sleep 2

echo "-------------------------------------------------"
echo "Starting dbus"
echo "-------------------------------------------------"
mkdir -p /var/run/dbus
dbus-daemon --system --address=unix:path=/var/run/dbus/system_bus_socket \
  --nofork --nopidfile > $APP_DIR/dbus.log 2>&1 &
sleep 1

echo "-------------------------------------------------"
echo "Starting x11vnc"
echo "-------------------------------------------------"
x11vnc -display :99 -forever -nopw -shared -rfbport 5900 > $APP_DIR/x11vnc.log 2>&1 &
sleep 2

echo "-------------------------------------------------"
echo "Starting noVNC"
echo "-------------------------------------------------"
nohup /opt/noVNC/utils/novnc_proxy \
  --vnc localhost:5900 \
  --listen 6080 > $APP_DIR/novnc.log 2>&1 &
sleep 3

echo "-------------------------------------------------"
echo "Starting XFCE Desktop"
echo "-------------------------------------------------"
nohup startxfce4 > $APP_DIR/xfce.log 2>&1 &
sleep 12

echo "-------------------------------------------------"
echo "Starting XFCE Terminal with single WDIO execution"
echo "-------------------------------------------------"

# Run tests ONLY inside terminal (one time)
xfce4-terminal --hold -e "bash -c '
    cd /app;

    echo \"Running WebdriverIO / Cucumber Tests...\";
    echo \"----------------------------------------------\";

    # Run WDIO only once
    if [ -f wdio.conf.js ]; then
        npx wdio run wdio.conf.js;
    else
        npm run test;
    fi

    echo \"----------------------------------------------\";
    echo \"Tests Completed — Logs visible above\";
    echo \"----------------------------------------------\";

    exec bash
'" &

sleep 3

echo "-------------------------------------------------"
echo "GUI Ready — Single WDIO test execution only"
echo "Open in browser: http://localhost:6080/vnc.html"
echo "-------------------------------------------------"

tail -f /dev/null
