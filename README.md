# 🤖 SmartChat API — Self-Hosted, Zero AI Costs

> Conversational AI API running **Mistral 7B locally via Ollama**.  
> No OpenAI. No Anthropic. No per-token fees. Your model, your server, your revenue.

---

## How It Works

```
RapidAPI Customer
       │  (API key)
       ▼
  Render Server
  ┌─────────────────────┐
  │  Express API        │  ← your business logic, auth, rate limits
  │         │           │
  │  Ollama (local)     │  ← Mistral 7B running on-machine
  └─────────────────────┘
```

No external AI calls. Everything runs on your Render server. You pay only for compute.

---

## Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | None | Render health check + model status |
| GET | `/` | None | API info |
| POST | `/chat` | ✅ | Stateless single-turn chat |
| POST | `/session` | ✅ | Create conversation session |
| POST | `/session/:id/chat` | ✅ | Multi-turn chat with memory |
| GET | `/session/:id` | ✅ | Get session history |
| DELETE | `/session/:id` | ✅ | Delete session |

---

## Quick Start (Local)

### Prerequisites
- [Node.js 18+](https://nodejs.org)
- [Ollama](https://ollama.com) installed

```bash
# 1. Clone & install
git clone https://github.com/YOUR_USERNAME/smartchat-api.git
cd smartchat-api
npm install

# 2. Pull Mistral (one-time, ~4GB)
ollama pull mistral

# 3. Configure
cp .env.example .env
# Edit .env → set DIRECT_API_KEY=anything for local testing

# 4. Start (in separate terminals)
ollama serve          # terminal 1
npm run api-only      # terminal 2

# 5. Test
curl -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-secret-key-here" \
  -d '{"message": "Hello! What can you help me with today?"}'
```

---

## API Reference

### POST `/chat` — Stateless Chat

**Headers:**
```
Authorization: Bearer <key>            # direct access
# OR
X-RapidAPI-Proxy-Secret: <secret>     # via RapidAPI
```

**Request:**
```json
{
  "message": "What are your business hours?",
  "systemPrompt": "You are a support agent for AcmeCo. Be brief and helpful."
}
```

**Response:**
```json
{
  "reply": "Our business hours are Monday to Friday, 9am–6pm IST.",
  "usage": {
    "prompt_tokens": 38,
    "completion_tokens": 18,
    "duration_ms": 1240
  }
}
```

---

### POST `/session` — Create Session

```json
// Request body
{ "systemPrompt": "You are Maya, a helpful assistant for Bloom Florist." }

// Response
{ "sessionId": "3f2a1b4c-...", "expiresInMinutes": 60 }
```

---

### POST `/session/:id/chat` — Multi-turn Chat

```json
// Request
{ "message": "Do you have red roses in stock?" }

// Response
{
  "reply": "Yes, we have fresh red roses! Bouquets start at ₹499.",
  "sessionId": "3f2a1b4c-...",
  "turnCount": 1,
  "usage": { "prompt_tokens": 90, "completion_tokens": 22, "duration_ms": 980 }
}
```

---

## Deploy on Render

### ⚠️ Plan Requirement

| Plan | RAM | Works? | Cost |
|------|-----|--------|------|
| Free | 512MB | ❌ Too small | $0 |
| Starter | 512MB | ❌ Too small | $7/mo |
| **Standard** | **2GB** | **✅ Recommended** | **$25/mo** |
| Pro | 4GB | ✅ Faster | $85/mo |

Mistral 7B Q4 quantized needs ~4GB RAM to load but runs inference in ~2GB.  
**Standard plan is the minimum.** You'll recoup this easily from RapidAPI subscribers.

### Deploy Steps

1. **Push to GitHub**
   ```bash
   git init && git add . && git commit -m "init"
   git remote add origin https://github.com/YOUR_USERNAME/smartchat-api.git
   git push -u origin main
   ```

2. **Create Render Service**
   - Go to [render.com](https://render.com) → **New** → **Blueprint**
   - Connect your GitHub repo (Render reads `render.yaml` automatically)
   - Or manually: New Web Service → Build: `npm install` → Start: `bash start.sh`

3. **Add Persistent Disk** (critical — saves re-downloading 4GB on every deploy)
   - Render dashboard → your service → **Disks** → Add Disk
   - Mount path: `/root/.ollama` | Size: 10GB

4. **Set Environment Variables** in Render dashboard:
   - `RAPIDAPI_PROXY_SECRET` → (fill after RapidAPI setup below)
   - `DIRECT_API_KEY` → any random secret for your own testing

5. **Deploy** — first deploy takes 5–10 minutes (Ollama installs + Mistral downloads).  
   Subsequent deploys are fast (model cached on disk).

6. **Verify:**
   ```bash
   curl https://your-app.onrender.com/health
   # { "status": "ok", "model": "mistral", "modelReady": true }
   ```

---

## List on RapidAPI

1. [rapidapi.com/provider](https://rapidapi.com/provider) → **Add New API**
2. **Base URL**: `https://your-app.onrender.com`
3. Add endpoints: `/chat`, `/session`, `/session/{id}/chat`, `/session/{id}`
4. **Security tab** → copy **Proxy Secret** → paste into Render as `RAPIDAPI_PROXY_SECRET` → redeploy
5. **Pricing** — suggested tiers:

| Tier | Price | Requests/mo | Target Customer |
|------|-------|-------------|-----------------|
| Free | $0 | 50 | Try it out |
| Starter | $9/mo | 2,000 | Small websites |
| Business | $29/mo | 10,000 | Growing teams |
| Pro | $79/mo | Unlimited | Agencies |

6. **Publish** and share your RapidAPI listing URL.

---

## Switching Models

Edit `MODEL` env var on Render (or `.env` locally). Options:

| Model | Size | Speed (CPU) | Best For |
|-------|------|-------------|----------|
| `mistral` | 4.1GB | ⭐⭐⭐ | Default, great balance |
| `llama3:8b` | 4.7GB | ⭐⭐⭐ | Slightly better reasoning |
| `phi3` | 2.3GB | ⭐⭐⭐⭐ | Fastest, smaller RAM |
| `gemma:7b` | 5GB | ⭐⭐ | Good for structured output |
| `llama3:70b` | 40GB | ⭐ | GPU server only |

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `MODEL` | ✅ | Ollama model name (default: `mistral`) |
| `OLLAMA_URL` | ✅ | Ollama server address (default: `http://127.0.0.1:11434`) |
| `RAPIDAPI_PROXY_SECRET` | RapidAPI | From RapidAPI provider dashboard |
| `DIRECT_API_KEY` | Optional | For direct access outside RapidAPI |
| `RATE_LIMIT_RPM` | Optional | Requests per user per minute (default: 20) |
| `PORT` | Auto | Set by Render automatically |

---

## Scaling Up

- **GPU**: Upgrade to RunPod or Hetzner GPU VPS for 10x faster inference
- **Better model**: Switch to `llama3:70b` on a GPU for GPT-4 level quality  
- **Redis sessions**: Replace in-memory `Map` with Upstash Redis for multi-instance
- **Streaming**: Add Server-Sent Events using Ollama's `stream: true` for real-time UX
- **Per-key analytics**: Log usage per RapidAPI user to a SQLite/Postgres DB

---

## License

MIT
