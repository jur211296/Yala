/** Bindings y configuración del Worker. Ver wrangler.toml (vars/bindings) y README (secrets). */
export interface Env {
  // --- Bindings (wrangler.toml) ---
  DB: D1Database;
  KV: KVNamespace;
  RATE_LIMITER: DurableObjectNamespace;
  // Telemetría propia mínima (POST /metrics, 2026-07-17): Workers Analytics Engine. Opcional a
  // propósito: ausente (tests / env sin configurar) → el handler acepta y descarta (no-op logueado).
  METRICS?: AnalyticsEngineDataset;

  // --- Vars (wrangler.toml [vars]) ---
  ENVIRONMENT: string; // "staging" | "production"
  ENFORCE: string; // "observe" | "enforce"
  APPLE_TEAM_ID: string;
  APPLE_BUNDLE_IDS: string; // CSV de bundle IDs aceptados (rpId)
  ATTEST_ENV: string; // "development" | "production"
  TRUST_ATTESTED_AS_PRO?: string; // SOLO staging: "true" → device atestado = Pro (QA sin suscripción)

  // --- Modo Nube (Supabase) — públicos (no secretos): URL del proyecto + anon/publishable key ---
  SUPABASE_URL: string; // p.ej. https://fostjbbwstyuunmmefuk.supabase.co
  SUPABASE_ANON_KEY: string; // apikey de PostgREST; el JWT del USUARIO va en Authorization (RLS activa)

  // --- Remote-config del cliente (GET /config, DIFERIDOS #34) — percents de rollout 0-100 (§j.1/§j.2).
  // Kill-switch sin release del cliente: flip = editar la var + `wrangler deploy`. Ausente/inválido → 0
  // (fail-closed). staging sirve 100 (QA/dogfooding no pierde superficie); prod arranca en 0.
  CLOUD_MODE_ROLLOUT_PERCENT?: string;
  CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT?: string;
  GROUPS_BACKEND_ROLLOUT_PERCENT?: string;
  // Sesión secundaria (M1 multi-cuenta en el mismo iPhone). Gatea SOLO la ENTRADA: una sesión ya
  // activa se monta y se limpia por su descriptor, pase lo que pase con este percent — bajarlo NUNCA
  // brickea a quien ya está dentro. Hasta el chip M2 este feature no tenía percent propio y tomaba
  // prestado el kill-switch de CLOUD_MODE; el AND con CLOUD_MODE se conserva (doble kill-switch).
  SECONDARY_SESSION_ROLLOUT_PERCENT?: string;
  // Forzado de actualización (min-version): build de CFBundleVersion por debajo del cual el cliente
  // muestra la pantalla bloqueante. Ausente/inválido → 0 (desactivado). Flip = editar var + deploy.
  MIN_SUPPORTED_BUILD?: string;

  // --- APNs (spike G0 Grupos→backend) — ausentes hasta configurar; /v1/debug/push responde 503 ---
  APNS_KEY_ID?: string; // Var (wrangler.toml): Key ID de 10 chars. NO es secreto (viaja en el header kid del JWT).
  APNS_AUTH_KEY?: string; // Secret (wrangler secret put): contenido PEM del AuthKey_<KEYID>.p8.

  // --- Sign in with Apple (B1, gate §12 — revoke 5.1.1(v)): canje del authorization_code + revoke ---
  // Ausentes → /account/siwa/exchange y /account/siwa/revoke responden 503 yala_siwa_not_configured.
  SIWA_KEY_ID?: string; // Var (wrangler.toml): Key ID de la .p8 de SIWA (PQ53RQ5D3G). NO es secreto (viaja en el kid).
  SIWA_AUTH_KEY?: string; // Secret (wrangler secret put): PEM de la .p8 de SIWA (~/Secrets/yala-siwa/). JAMÁS en el repo.

  // --- Secrets (wrangler secret put — NUNCA en el repo) ---
  OPENAI_API_KEY: string;
  EXCHANGE_RATE_API_KEY: string;
  JWT_SIGNING_SECRET: string;
  DEV_SHARED_SECRET: string; // bypass de dev/test; solo honrado en staging
  APP_STORE_API_KEY?: string; // App Store Server API / webhook
  // Grupos→backend G7 (pgcrypto): llave simétrica del cifrado at-rest de columnas † de grupos. Viaja como
  // ARGUMENTO de request a los RPCs de grupos (p_key) — JAMÁS a URL/query. Ausente → 503 tipado en los CUATRO
  // caminos que la inyectan (pull, merkle, push y los RPCs de RPC_NEEDS_ENC_KEY); guard único en groups/encKey.ts.
  // staging y PROD llevan llaves DISTINTAS; la de prod la genera el owner. `.dev.vars` (gitignored) para dev local.
  GROUPS_ENC_KEY?: string;
  // Grupos→backend G8-3 (credencial de máquina `yala_push`): JWT HS256 firmado con el LEGACY secret del
  // proyecto, con claim `role: yala_push` → PostgREST hace SET ROLE yala_push, el ÚNICO rol con EXECUTE sobre
  // get_group_push_tokens / prune_push_token (revocados de authenticated en g8_02). El fan-out lo usa en vez del
  // JWT del autor. exp 10 años; se acuña con gateway/scripts/mint-push-role-jwt.mjs → `wrangler secret put
  // PUSH_ROLE_JWT`. Ausente → el fan-out es no-op silencioso (log 1 vez, junto al de APNs). ⚠️ si el owner
  // revoca el legacy secret (rotación de firmas), el fan-out muere en silencio (401) → re-acuñar. NUNCA a URL.
  PUSH_ROLE_JWT?: string;
}

/** true solo en el entorno no-prod, donde se acepta el bypass de dev/test. */
export function allowsDevBypass(env: Env): boolean {
  return env.ENVIRONMENT !== "production";
}

/** Bundle IDs aceptados para la validación de rpId de App Attest. */
export function acceptedBundleIDs(env: Env): string[] {
  return env.APPLE_BUNDLE_IDS.split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}
