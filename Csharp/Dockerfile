# =========================================================
# 🌐 UNIVERSAL C# SELENIUM GUI DOCKERFILE (noVNC + Chrome)
# Supports NUnit / SpecFlow / ExtentReports
# =========================================================

FROM mcr.microsoft.com/dotnet/sdk:9.0

LABEL maintainer="CHENNAKESAVULU"

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99
ENV NO_AT_BRIDGE=1
ENV PATH="$PATH:/usr/local/bin:/usr/bin"
ENV CHROME_BIN="/usr/bin/google-chrome"
ENV CHROMEDRIVER="/usr/local/bin/chromedriver"

WORKDIR /app

# ----------------------
# 1️⃣ Base Dependencies
# ----------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl unzip git xvfb x11vnc x11-utils dbus-x11 \
    xfce4 xfce4-terminal xdg-utils fonts-liberation \
    libnss3 libxss1 libappindicator3-1 libasound2 libxrandr2 \
    libxcomposite1 libxcursor1 libxi6 libxtst6 libglib2.0-0 \
    ca-certificates gnupg2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ----------------------
# 2️⃣ Install Google Chrome
# ----------------------
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-linux-signing-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/google-linux-signing-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
      > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y google-chrome-stable && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ----------------------
# 3️⃣ noVNC + websockify
# ----------------------
RUN mkdir -p /opt && \
    git clone --depth=1 https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone --depth=1 https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

# ----------------------
# 4️⃣ ChromeDriver (auto-matching)
# ----------------------
RUN set -eux; \
    CHROME_VERSION=$(google-chrome --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1); \
    MAJOR_VERSION=$(echo "$CHROME_VERSION" | cut -d. -f1); \
    DRIVER_VERSION=$(curl -sSfL "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_${MAJOR_VERSION}" || true); \
    if [ -z "$DRIVER_VERSION" ]; then DRIVER_VERSION=$(curl -sSfL https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE); fi; \
    wget -q "https://storage.googleapis.com/chrome-for-testing-public/${DRIVER_VERSION}/linux64/chromedriver-linux64.zip" -O /tmp/chromedriver.zip; \
    unzip -q /tmp/chromedriver.zip -d /usr/local/bin/; \
    mv /usr/local/bin/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver; \
    chmod +x /usr/local/bin/chromedriver; \
    rm -rf /tmp/*

# ----------------------
# 5️⃣ Copy project files
# ----------------------
COPY . .

# ----------------------
# 6️⃣ Ports
# ----------------------
EXPOSE 6080 5900

# ----------------------
# 7️⃣ Startup Script
# ----------------------
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

# ----------------------
# 🏁 Default CMD
# ----------------------
CMD ["/startup.sh"]
