# ---------------------------------------------------------------
# UNIVERSAL WDIO + CUCUMBER + CHROME + GUI (NOVNC)
# Works for ANY JS/TS WebdriverIO project
# ---------------------------------------------------------------

FROM node:20-bullseye

MAINTAINER CHENNAKESAVULU
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------
# 1) Install system deps, GUI stack, XFCE, Chrome libs
# ---------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl unzip git gnupg2 ca-certificates \
    xvfb x11vnc x11-utils xfce4 xfce4-terminal openbox dbus-x11 \
    supervisor net-tools xdg-utils \
    libappindicator3-1 libasound2 libatk-bridge2.0-0 libcups2 \
    libnspr4 libnss3 libxcomposite1 libxdamage1 libxfixes3 \
    libxrandr2 libxtst6 fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------
# 2) Install Google Chrome Stable
# ---------------------------------------------------------------
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor -o /usr/share/keyrings/google-linux-signing-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux-signing-keyring.gpg] \
    http://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------
# 3) Install noVNC + Websockify
# ---------------------------------------------------------------
RUN git clone https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify

# ---------------------------------------------------------------
# 4) Auto-match ChromeDriver version
# ---------------------------------------------------------------
RUN set -eux; \
    RAW=$(google-chrome --version); \
    echo "Detected Chrome: $RAW"; \
    VER=$(echo "$RAW" | grep -oE "[0-9]+" | head -1); \
    echo "Chrome major version = $VER"; \
    DRIVER_VERSION=$(curl -sSfL "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_${VER}" || true); \
    if [ -z "$DRIVER_VERSION" ]; then \
        echo "Fallback: latest driver"; \
        DRIVER_VERSION=$(curl -sSfL https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE); \
    fi; \
    echo "Installing ChromeDriver $DRIVER_VERSION"; \
    wget -q https://storage.googleapis.com/chrome-for-testing-public/${DRIVER_VERSION}/linux64/chromedriver-linux64.zip; \
    unzip chromedriver-linux64.zip; \
    mv chromedriver-linux64/chromedriver /usr/local/bin/chromedriver; \
    chmod +x /usr/local/bin/chromedriver; \
    rm -rf chromedriver-linux64* chromedriver-linux64.zip

# ---------------------------------------------------------------
# 5) Environment variables
# ---------------------------------------------------------------
ENV CHROME_BIN=/usr/bin/google-chrome
ENV CHROMEDRIVER=/usr/local/bin/chromedriver
ENV DISPLAY=:99
ENV NO_AT_BRIDGE=1

# ---------------------------------------------------------------
# 6) Copy project
# ---------------------------------------------------------------
WORKDIR /app
COPY . /app

# ---------------------------------------------------------------
# 7) Install Node dependencies (universal)
# ---------------------------------------------------------------
RUN npm config set fund false && \
    npm config set update-notifier false && \
    npm install --legacy-peer-deps || npm install --force && \
    mkdir -p reports && chmod -R 777 reports

# ---------------------------------------------------------------
# 8) Add startup script
# ---------------------------------------------------------------
COPY startup.sh /app/startup.sh
RUN chmod +x /app/startup.sh

# ---------------------------------------------------------------
# 9) Expose VNC + noVNC ports
# ---------------------------------------------------------------
EXPOSE 5900 6080

# ---------------------------------------------------------------
# 10) Entrypoint
# ---------------------------------------------------------------
CMD ["/app/startup.sh"]
