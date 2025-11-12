# =========================================================
# 🧱 UNIVERSAL PYTHON SELENIUM GUI DOCKERFILE (Behave + Allure)
# Works on Linux, Windows Docker Desktop, and macOS
# Access GUI via http://localhost:6080
# =========================================================

FROM --platform=$BUILDPLATFORM python:3.11-slim-bullseye

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
ENV DISPLAY=:99
ENV NO_AT_BRIDGE=1
ENV PATH="$PATH:/usr/local/bin:/usr/bin"
ENV CHROME_BIN="/usr/bin/google-chrome"
ENV CHROMEDRIVER="/usr/local/bin/chromedriver"

# ----------------------
# 1️⃣ System Dependencies
# ----------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl unzip git gnupg2 ca-certificates xauth \
    python3-dev build-essential pkg-config \
    xvfb x11vnc x11-utils dbus-x11 \
    xfce4 xfce4-terminal fonts-liberation \
    libappindicator3-1 libasound2 libatk-bridge2.0-0 libcups2 \
    libnspr4 libnss3 libxcomposite1 libxdamage1 libxfixes3 \
    libxrandr2 libxtst6 xdg-utils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ----------------------
# 2️⃣ Google Chrome
# ----------------------
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-linux-signing-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/google-linux-signing-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
      > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y google-chrome-stable && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ----------------------
# 3️⃣ ChromeDriver (Auto-match to Chrome)
# ----------------------
RUN set -eux; \
    CHROME_VERSION=$(google-chrome --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0"); \
    MAJOR_VERSION=$(echo "$CHROME_VERSION" | cut -d. -f1); \
    DRIVER_VERSION=$(curl -sSfL "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_${MAJOR_VERSION}" || true); \
    if [ -z "$DRIVER_VERSION" ]; then DRIVER_VERSION=$(curl -sSfL https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE); fi; \
    wget -q "https://storage.googleapis.com/chrome-for-testing-public/${DRIVER_VERSION}/linux64/chromedriver-linux64.zip" -O /tmp/chromedriver.zip; \
    unzip -q /tmp/chromedriver.zip -d /usr/local/bin/; \
    mv /usr/local/bin/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver; \
    chmod +x /usr/local/bin/chromedriver; rm -rf /tmp/*

# ----------------------
# 4️⃣ Install noVNC + websockify
# ----------------------
RUN git clone --depth=1 https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone --depth=1 https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

# ----------------------
# 5️⃣ Python Dependencies
# ----------------------
COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel && \
    if [ -f requirements.txt ]; then pip install -r requirements.txt; \
    else pip install selenium==4.23.1 allure-behave behave; fi

# ----------------------
# 6️⃣ Copy Project
# ----------------------
COPY . .

# ----------------------
# 7️⃣ Startup Script
# ----------------------
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

# ----------------------
# 8️⃣ Ports
# ----------------------
EXPOSE 6080 5900

# ----------------------
# 9️⃣ CMD
# ----------------------
CMD ["/startup.sh"]
