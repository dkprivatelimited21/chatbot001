#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  start.sh — Boot script for Render (no root/sudo needed)
# ─────────────────────────────────────────────────────────────
set -e

MODEL="${MODEL:-mistral}"
OLLAMA_URL="http://127.0.0.1:11434"
OLLAMA_DIR="$HOME/.local/ollama"
OLLAMA_BIN="$OLLAMA_DIR/bin/ollama"

echo "==> [1/4] Checking Ollama installation..."
if [ -f "$OLLAMA_BIN" ]; then
  echo "    Ollama already installed."
else
  echo "    Downloading Ollama (tar.zst)..."
  mkdir -p "$OLLAMA_DIR"

  # Install zstd if missing
  if ! command -v zstd &> /dev/null; then
    echo "    Installing zstd..."
    apt-get install -y zstd 2>/dev/null || true
  fi

  # Download latest release tarball from GitHub
  OLLAMA_VERSION=$(curl -fsSL "https://api.github.com/repos/ollama/ollama/releases/latest" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
  echo "    Latest version: $OLLAMA_VERSION"

  curl -fsSL "https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" \
    -o /tmp/ollama.tar.zst

  tar -I zstd -xf /tmp/ollama.tar.zst -C "$OLLAMA_DIR"
  rm /tmp/ollama.tar.zst
  chmod +x "$OLLAMA_BIN"
  echo "    Ollama installed at $OLLAMA_BIN"
fi

export PATH="$OLLAMA_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$OLLAMA_DIR/lib/ollama:${LD_LIBRARY_PATH:-}"

echo "==> [2/4] Starting Ollama server in background..."
ollama serve &

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
ollama pull "$MODEL"
echo "    Model ready."

echo "==> [4/4] Starting Express API..."
node server.js
