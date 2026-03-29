#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  start.sh — Boot script for Render
#  Installs Ollama manually (no sudo/root needed)
# ─────────────────────────────────────────────────────────────
set -e

MODEL="${MODEL:-mistral}"
OLLAMA_URL="http://127.0.0.1:11434"
OLLAMA_BIN="$HOME/.local/bin/ollama"

echo "==> [1/4] Checking Ollama installation..."
if [ -f "$OLLAMA_BIN" ]; then
  echo "    Ollama already installed."
else
  echo "    Downloading Ollama binary directly (no root needed)..."
  mkdir -p "$HOME/.local/bin"

  # Download the official Linux amd64 binary directly — no installer script
  curl -fsSL "https://ollama.com/download/ollama-linux-amd64" -o "$OLLAMA_BIN"
  chmod +x "$OLLAMA_BIN"
  echo "    Ollama installed at $OLLAMA_BIN"
fi

# Make sure it's on PATH
export PATH="$HOME/.local/bin:$PATH"

echo "==> [2/4] Starting Ollama server in background..."
OLLAMA_MODELS="${HOME}/.ollama/models" ollama serve &

# Wait for Ollama to be ready (up to 60s)
echo "    Waiting for Ollama to be ready..."
for i in $(seq 1 60); do
  if curl -sf "$OLLAMA_URL/api/tags" > /dev/null 2>&1; then
    echo "    Ollama is ready! (took ${i}s)"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "    ERROR: Ollama didn't start in time."
    exit 1
  fi
  sleep 1
done

echo "==> [3/4] Pulling model: $MODEL"
# No-op if already on persistent disk
ollama pull "$MODEL"
echo "    Model ready."

echo "==> [4/4] Starting Express API..."
node server.js
