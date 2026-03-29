#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  start.sh — runs inside Docker container on Render
#  Ollama is already installed in the image via Dockerfile
# ─────────────────────────────────────────────────────────────
set -e

MODEL="${MODEL:-mistral}"
OLLAMA_URL="http://127.0.0.1:11434"

echo "==> [1/3] Starting Ollama server..."
ollama serve &

echo "    Waiting for Ollama to be ready..."
for i in $(seq 1 60); do
  if curl -sf "$OLLAMA_URL/api/tags" > /dev/null 2>&1; then
    echo "    Ollama ready! (${i}s)"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "ERROR: Ollama didn't start."
    exit 1
  fi
  sleep 1
done

echo "==> [2/3] Pulling model: $MODEL"
ollama pull "$MODEL"
echo "    Model ready."

echo "==> [3/3] Starting Express API..."
node server.js
