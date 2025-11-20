FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99
ENV LANG=en_US.UTF-8
ENV NO_AT_BRIDGE=1

# -------------------------
# Base Dependencies
# -------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git sudo nano unzip supervisor xvfb \
    xfce4 xfce4-terminal x11vnc novnc websockify \
    dbus-x11 net-tools gnupg2 ca-certificates fonts-liberation \
    libgtk-3-0 libasound2 libxss1 libnss3 libgconf-2-4 libcurl4 \
    && rm -rf /var/lib/apt/lists/*

# -------------------------
# Install Chrome Stable
# -------------------------
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
      | gpg --dearmor -o /usr/share/keyrings/google-linux-key.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux-key.gpg] \
      http://dl.google.com/linux/chrome/deb/ stable main" \
      > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN="/usr/bin/google-chrome"

# -------------------------
# Install ChromeDriver (Auto Match to Chrome for Testing)
# -------------------------
RUN set -eux; \
    VER=$(/usr/bin/google-chrome --version | grep -oP "[0-9]+\.[0-9]+\.[0-9]+"); \
    MAJOR=$(echo "$VER" | cut -d. -f1); \
    DRIVER=$(wget -qO- https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_${MAJOR}); \
    wget -q "https://storage.googleapis.com/chrome-for-testing-public/${DRIVER}/linux64/chromedriver-linux64.zip"; \
    unzip chromedriver-linux64.zip; \
    mv chromedriver-linux64/chromedriver /usr/local/bin/chromedriver; \
    chmod +x /usr/local/bin/chromedriver; \
    rm -rf chromedriver-linux64* chromedriver-linux64.zip

ENV CHROMEDRIVER="/usr/local/bin/chromedriver"

# -------------------------
# Install NodeJS 20
# -------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    node -v && npm -v

# -------------------------
# App Setup
# -------------------------
WORKDIR /app

# Copy package files first for better layer caching
COPY package*.json ./

# Install npm deps (use legacy-peer-deps to be tolerant of peer warnings)
RUN npm install --legacy-peer-deps --no-audit --unsafe-perm

# Copy full project
COPY . /app

# Provide startup script
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

# Expose VNC and noVNC ports (if you want to view the desktop)
EXPOSE 5900 6080

# Default command: start helper and keep container running
CMD ["/startup.sh"]
