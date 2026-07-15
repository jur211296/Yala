import { Hono } from "hono";
import type { Env } from "./env";
import { jsonError } from "./errors";
import { handleAssert, handleChallenge, handleDevToken, handleRegister } from "./attest/routes";
import { handleAudioTranscriptions, handleChatCompletions } from "./proxy/openai";
import { handleRatesLive, handleRatesTimeframe } from "./proxy/rates";
import { handleAppStoreWebhook } from "./proxy/webhook";
import {
  handleAttestBind,
  handlePrefsPull,
  handlePrefsPush,
  handleSyncMerkle,
  handleSyncPull,
  handleSyncPush,
} from "./sync/routes";
import { handleAccountClaim, handleAccountDelete, handleAccountExists, handleAccountMigration } from "./sync/account";
import { handleGroupsMerkle, handleGroupsPull, handleGroupsPush } from "./groups/routes";
import { handleGroupsRpc } from "./groups/rpc";
import { handleDebugPush } from "./push/routes";

/**
 * Yala Gateway — entrada del Worker.
 *
 * Superficie OpenAI-compatible (/v1/*) para que el SDK MacPaw apunte aquí cambiando host/basePath.
 * Las API keys reales se inyectan server-side; nunca viajan al cliente. NO se loguean bodies.
 *
 * Estado: scaffold (task #1). Los handlers reales llegan en tasks #2-#5; hoy responden 501
 * con envelope OpenAI-compatible para que el contrato de errores sea testeable end-to-end.
 */
const app = new Hono<{ Bindings: Env }>();

app.get("/healthz", (c) =>
  c.json({ ok: true, environment: c.env.ENVIRONMENT ?? "unknown", enforce: c.env.ENFORCE ?? "observe" }),
);

// --- App Attest (task #2) ---
app.post("/v1/attest/challenge", handleChallenge);
app.post("/v1/attest/register", handleRegister);
app.post("/v1/attest/assert", handleAssert);
app.post("/v1/attest/dev", handleDevToken); // bypass dev/test (solo staging + DEV_SHARED_SECRET)

// --- Push (spike G0 Grupos→backend): prueba de APNs desde el Worker — mismo gate que /v1/attest/dev ---
app.post("/v1/debug/push", handleDebugPush);

// --- Proxy OpenAI (task #5): chat + vision + transcripción ---
app.post("/v1/chat/completions", handleChatCompletions);
app.post("/v1/audio/transcriptions", handleAudioTranscriptions);

// --- Tasas de cambio (task #5): exchangerate.host con key server-side + Cache API ---
app.get("/rates/live", handleRatesLive);
app.get("/rates/timeframe", handleRatesTimeframe);

// --- App Store Server Notifications V2 (task #5) ---
app.post("/webhooks/appstore", handleAppStoreWebhook);

// --- Modo Nube (I6): JWT del usuario (Supabase) + App Attest + PATCH por-unidad contra PostgREST ---
app.post("/sync/push", handleSyncPush);
app.get("/sync/pull", handleSyncPull);
app.get("/sync/merkle", handleSyncMerkle); // 501 hasta I8 (codec canon c1)
app.post("/attest/bind", handleAttestBind);
app.post("/prefs/push", handlePrefsPush);
app.get("/prefs/pull", handlePrefsPull);

// --- Cuenta (I7a): gate de identidad §f.1 — corre tras el sign-in, ANTES de todo save() de onboarding ---
app.post("/account/claim", handleAccountClaim); // reserva atómica; estado de 3 valores
app.get("/account/exists", handleAccountExists); // hint de encaminamiento (no la garantía anti-doble-siembra)
app.post("/account/migration", handleAccountMigration); // cutover/complete §g.4 + reverse_* §h + heartbeat I14-pre (guard líder)
app.post("/account/delete", handleAccountDelete); // G5-D1: borrado GDPR del corpus personal (requireUserAndAttest — asimetría documentada)

// --- Grupos->backend (G2): canal de sync de grupos (apply_group_delta SECURITY INVOKER; RLS por membership) ---
app.post("/groups/push", handleGroupsPush);
app.get("/groups/pull", handleGroupsPull);
app.get("/groups/merkle", handleGroupsMerkle);

// --- Grupos->backend (G3): RPCs de membresía (allowlist de 9; params filtrados por fn; RLS arbitra) ---
app.post("/groups/rpc/:fn", handleGroupsRpc);

app.notFound(() => jsonError("yala_bad_request", "Not found", 404));

export default app;
export { RateLimiter } from "./rate_limiter";
