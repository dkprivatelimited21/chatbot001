FROM node:20-slim

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama — binary lands at /usr/local/bin/ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Verify it's there
RUN which ollama && ollama --version

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY server.js ./
COPY start.sh ./
RUN chmod +x start.sh

EXPOSE 3000

CMD ["bash", "start.sh"]
