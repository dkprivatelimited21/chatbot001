const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const morgan = require("morgan");
const { v4: uuidv4 } = require("uuid");

const app = express();
const PORT = process.env.PORT || 3000;

// Ollama runs locally on the same machine (started via start.sh)
const OLLAMA_URL = process.env.OLLAMA_URL || "http://127.0.0.1:11434";
const MODEL = process.env.MODEL || "mistral";

// ─── Middleware ────────────────────────────────────────────────────────────────
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: "10kb" }));
app.use(morgan("combined"));

// ─── In-Memory Session Store (1hr TTL) ───────────────────────────────────────
const sessions = new Map();
const SESSION_TTL_MS = 60 * 60 * 1000;

function getSession(id) {
  const s = sessions.get(id);
  if (!s) return null;
  if (Date.now() - s.createdAt > SESSION_TTL_MS) {
    sessions.delete(id);
    return null;
  }
  return s;
}

function createSession(config = {}) {
  const id = uuidv4();
  sessions.set(id, {
    id,
    messages: [],
    systemPrompt:
      config.systemPrompt ||
      "You are a helpful, concise assistant for a small business. Be friendly and professional.",
    createdAt: Date.now(),
  });
  return id;
}

// ─── API Key Auth ─────────────────────────────────────────────────────────────
function validateApiKey(req, res, next) {
  // RapidAPI sends this header — validate it server-side
  const rapidSecret = req.headers["x-rapidapi-proxy-secret"];
  const rapidUser   = req.headers["x-rapidapi-user"];

  if (rapidSecret) {
    if (rapidSecret !== process.env.RAPIDAPI_PROXY_SECRET) {
      return res.status(401).json({ error: "Invalid RapidAPI proxy secret" });
    }
    req.user = rapidUser || "rapidapi-user";
    return next();
  }

  // Direct access (for testing / non-RapidAPI clients)
  const auth = req.headers["authorization"] || "";
  if (!auth.startsWith("Bearer ")) {
    return res.status(401).json({
      error: "Unauthorized",
      hint: "Send Authorization: Bearer <your-key> or subscribe via RapidAPI",
    });
  }
  const token = auth.slice(7);
  if (!process.env.DIRECT_API_KEY || token !== process.env.DIRECT_API_KEY) {
    return res.status(401).json({ error: "Invalid API key" });
  }
  req.user = "direct";
  next();
}

// ─── Rate Limiter ─────────────────────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_RPM || "20"),
  keyGenerator: (req) => req.headers["x-rapidapi-user"] || req.ip,
  message: { error: "Rate limit exceeded. Please wait." },
  standardHeaders: true,
  legacyHeaders: false,
});

// ─── Ollama Chat Helper ───────────────────────────────────────────────────────
async function ollamaChat({ systemPrompt, messages, stream = false }) {
  // Build Ollama-format message array
  const ollamaMessages = [
    { role: "system", content: systemPrompt },
    ...messages,
  ];

  const response = await fetch(`${OLLAMA_URL}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: MODEL,
      messages: ollamaMessages,
      stream: false,         // keep false for simple JSON response
      options: {
        temperature: 0.7,
        num_predict: 512,    // max tokens to generate
      },
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Ollama error ${response.status}: ${err}`);
  }

  const data = await response.json();
  return {
    reply: data.message?.content || "",
    prompt_tokens: data.prompt_eval_count || 0,
    completion_tokens: data.eval_count || 0,
    duration_ms: Math.round((data.total_duration || 0) / 1e6),
  };
}

// ─── Routes ───────────────────────────────────────────────────────────────────

// Health — no auth, used by Render health checks
app.get("/health", async (req, res) => {
  try {
    const r = await fetch(`${OLLAMA_URL}/api/tags`);
    const data = await r.json();
    const modelLoaded = data.models?.some((m) => m.name.startsWith(MODEL));
    res.json({
      status: "ok",
      model: MODEL,
      modelReady: modelLoaded,
      timestamp: new Date().toISOString(),
    });
  } catch {
    res.status(503).json({ status: "ollama_unavailable" });
  }
});

// API info
app.get("/", (req, res) => {
  res.json({
    name: "SmartChat API",
    version: "1.0.0",
    model: MODEL,
    description: "Self-hosted conversational AI — no third-party AI costs.",
    endpoints: {
      "POST /chat": "Stateless single-turn chat",
      "POST /session": "Create a session (multi-turn with memory)",
      "POST /session/:id/chat": "Continue a conversation",
      "GET  /session/:id": "Get session history",
      "DELETE /session/:id": "Delete session",
    },
  });
});

/**
 * POST /chat
 * Stateless, single-turn chat. No session needed.
 * Body: { message, systemPrompt? }
 */
app.post("/chat", validateApiKey, limiter, async (req, res) => {
  const { message, systemPrompt } = req.body;

  if (!message || typeof message !== "string" || message.trim().length === 0) {
    return res.status(400).json({ error: "message is required and must be a non-empty string" });
  }
  if (message.length > 4000) {
    return res.status(400).json({ error: "message must be under 4000 characters" });
  }

  try {
    const result = await ollamaChat({
      systemPrompt: systemPrompt || "You are a helpful assistant for a small business.",
      messages: [{ role: "user", content: message }],
    });

    res.json({
      reply: result.reply,
      usage: {
        prompt_tokens: result.prompt_tokens,
        completion_tokens: result.completion_tokens,
        duration_ms: result.duration_ms,
      },
    });
  } catch (err) {
    console.error("Chat error:", err.message);
    res.status(502).json({ error: "Model error", message: err.message });
  }
});

/**
 * POST /session
 * Create a named conversation session.
 * Body: { systemPrompt? }
 */
app.post("/session", validateApiKey, (req, res) => {
  const { systemPrompt } = req.body || {};
  const sessionId = createSession({ systemPrompt });
  res.status(201).json({
    sessionId,
    message: "Session created. POST /session/:id/chat to chat.",
    expiresInMinutes: 60,
  });
});

/**
 * POST /session/:id/chat
 * Multi-turn chat — bot remembers conversation history.
 * Body: { message }
 */
app.post("/session/:id/chat", validateApiKey, limiter, async (req, res) => {
  const session = getSession(req.params.id);
  if (!session) {
    return res.status(404).json({
      error: "Session not found or expired",
      hint: "Create a new session via POST /session",
    });
  }

  const { message } = req.body;
  if (!message || typeof message !== "string" || message.trim().length === 0) {
    return res.status(400).json({ error: "message is required" });
  }

  session.messages.push({ role: "user", content: message });

  // Keep last 10 turns (20 messages) to avoid memory bloat on CPU
  const recentMessages = session.messages.slice(-20);

  try {
    const result = await ollamaChat({
      systemPrompt: session.systemPrompt,
      messages: recentMessages,
    });

    session.messages.push({ role: "assistant", content: result.reply });

    res.json({
      reply: result.reply,
      sessionId: session.id,
      turnCount: Math.floor(session.messages.length / 2),
      usage: {
        prompt_tokens: result.prompt_tokens,
        completion_tokens: result.completion_tokens,
        duration_ms: result.duration_ms,
      },
    });
  } catch (err) {
    session.messages.pop(); // rollback on failure
    console.error("Session chat error:", err.message);
    res.status(502).json({ error: "Model error", message: err.message });
  }
});

/**
 * GET /session/:id
 * Fetch session metadata and full message history.
 */
app.get("/session/:id", validateApiKey, (req, res) => {
  const session = getSession(req.params.id);
  if (!session) return res.status(404).json({ error: "Session not found or expired" });

  res.json({
    sessionId: session.id,
    systemPrompt: session.systemPrompt,
    turnCount: Math.floor(session.messages.length / 2),
    history: session.messages,
    createdAt: new Date(session.createdAt).toISOString(),
  });
});

/**
 * DELETE /session/:id
 */
app.delete("/session/:id", validateApiKey, (req, res) => {
  if (!sessions.has(req.params.id)) {
    return res.status(404).json({ error: "Session not found" });
  }
  sessions.delete(req.params.id);
  res.json({ message: "Session deleted" });
});

// 404
app.use((req, res) => res.status(404).json({ error: "Endpoint not found" }));

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: "Internal server error" });
});

app.listen(PORT, () => console.log(`SmartChat API on port ${PORT} | model: ${MODEL}`));
module.exports = app;
