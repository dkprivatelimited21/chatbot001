#!/usr/bin/env bash
set -e

MODEL="${MODEL:-mistral}"
OLLAMA_URL="http://127.0.0.1:11434"

# Ollama is installed at /usr/local/bin/ollama by the Dockerfile
export PATH="/usr/local/bin:$PATH"

echo "==> Ollama binary: $(which ollama || echo 'NOT FOUND')"
echo "==> Ollama version: $(ollama --version 2>&1 || echo 'ERROR')"

echo "==> [1/3] Starting Ollama server..."
/usr/local/bin/ollama serve &

echo "    Waiting for Ollama to be ready..."
for i in $(seq 1 90); do
  if curl -sf "$OLLAMA_URL/api/tags" > /dev/null 2>&1; then
    echo "    Ollama ready! (${i}s)"
    break
  fi
  if [ "$i" -eq 90 ]; then
    echo "ERROR: Ollama didn't start in 90s. Check logs above."
    exit 1
  fi
  sleep 1
done

echo "==> [2/3] Pulling model: $MODEL"
/usr/local/bin/ollama pull "$MODEL"
echo "    Model ready."

echo "==> [3/3] Starting Express API on port ${PORT:-3000}..."
node server.js
