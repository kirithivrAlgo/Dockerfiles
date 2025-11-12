# =========================================================
# UNIVERSAL PYTHON SELENIUM GUI DOCKERFILE (Behave + Allure)
# Works on Linux, Windows Docker Desktop, and macOS
# Access GUI via http://localhost:6080
# =========================================================
 
FROM --platform=$BUILDPLATFORM python:3.11-slim-bullseye
 
LABEL maintainer="chennakesavulu"
 
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99
ENV NO_AT_BRIDGE=1
ENV PATH="$PATH:/usr/local/bin:/usr/bin"
ENV CHROME_BIN="/usr/bin/google-chrome"
ENV CHROMEDRIVER="/usr/local/bin/chromedriver"
 
WORKDIR /app
 
# ---------------------------------------------------------
# 1. Install system dependencies
# ---------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl unzip git gnupg2 ca-certificates xauth dbus-x11 \
    python3-dev build-essential pkg-config \
    xvfb x11vnc x11-utils xfce4 xfce4-terminal \
    fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 \
    libcups2 libnspr4 libnss3 libxcomposite1 libxdamage1 libxfixes3 \
    libxrandr2 libxtst6 xdg-utils novnc websockify \
&& apt-get clean && rm -rf /var/lib/apt/lists/*
 
# ---------------------------------------------------------
# 2. Install Google Chrome browser
# ---------------------------------------------------------
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | \
    gpg --dearmor -o /usr/share/keyrings/google-linux-signing-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/google-linux-signing-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
> /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y google-chrome-stable && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
 
# ---------------------------------------------------------
# 3. Install ChromeDriver (matching browser version)
# ---------------------------------------------------------
RUN set -eux; \
    CHROME_VERSION=$(google-chrome --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0"); \
    MAJOR_VERSION=$(echo "$CHROME_VERSION" | cut -d. -f1); \
    DRIVER_VERSION=$(curl -sSfL "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_${MAJOR_VERSION}" || true); \
    if [ -z "$DRIVER_VERSION" ]; then DRIVER_VERSION=$(curl -sSfL https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE); fi; \
    wget -q "https://storage.googleapis.com/chrome-for-testing-public/${DRIVER_VERSION}/linux64/chromedriver-lin… -O /tmp/chromedriver.zip; \
    unzip -q /tmp/chromedriver.zip -d /usr/local/bin/; \
    mv /usr/local/bin/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver; \
    chmod +x /usr/local/bin/chromedriver; rm -rf /tmp/*
 
# ---------------------------------------------------------
# 4. Install noVNC and Websockify for browser-based GUI
# ---------------------------------------------------------
RUN git clone --depth=1 https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone --depth=1 https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html
 
# ---------------------------------------------------------
# 5. Install Python dependencies
# ---------------------------------------------------------
COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel && pip install -r requirements.txt
 
# ---------------------------------------------------------
# 6. Copy application code into the container
# ---------------------------------------------------------
COPY . .
 
# ---------------------------------------------------------
# 7. Copy and configure startup script
# ---------------------------------------------------------
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh
 
# ---------------------------------------------------------
# 8. Expose VNC and noVNC ports
# ---------------------------------------------------------
EXPOSE 6080 5900
 
# ---------------------------------------------------------
# 9. Default command to run on container start
# ---------------------------------------------------------
CMD ["/startup.sh"]
