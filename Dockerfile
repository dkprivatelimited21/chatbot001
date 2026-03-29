# ─────────────────────────────────────────────────────────────
#  Dockerfile — SmartChat API + Ollama (Mistral 7B)
#  Render will use this automatically when it finds a Dockerfile
# ─────────────────────────────────────────────────────────────
FROM node:20-slim

# Install curl + Ollama system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama (as root, inside Docker — no permission issues)
RUN curl -fsSL https://ollama.com/install.sh | sh

WORKDIR /app

# Install Node dependencies
COPY package*.json ./
RUN npm install --omit=dev

# Copy app code
COPY server.js ./
COPY start.sh ./
RUN chmod +x start.sh

EXPOSE 3000

CMD ["bash", "start.sh"]
