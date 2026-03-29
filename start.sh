#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  start.sh — Boot script for Render
#  1. Installs Ollama (if not present)
#  2. Starts Ollama in the background
#  3. Pulls the Mistral model (first boot only, ~4GB download)
#  4. Starts the Express API
# ─────────────────────────────────────────────────────────────
set -e

MODEL="${MODEL:-mistral}"
OLLAMA_URL="http://127.0.0.1:11434"

echo "==> [1/4] Checking Ollama installation..."
if ! command -v ollama &> /dev/null; then
  echo "    Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
else
  echo "    Ollama already installed: $(ollama --version)"
fi

echo "==> [2/4] Starting Ollama server in background..."
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready (up to 30s)
echo "    Waiting for Ollama to be ready..."
for i in $(seq 1 30); do
  if curl -sf "$OLLAMA_URL/api/tags" > /dev/null 2>&1; then
    echo "    Ollama is ready!"
    break
  fi
  sleep 1
done

echo "==> [3/4] Pulling model: $MODEL"
# pull is a no-op if already downloaded (Render persists /root/.ollama via disk)
ollama pull "$MODEL"
echo "    Model ready."

echo "==> [4/4] Starting Express API..."
node server.js
