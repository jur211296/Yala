/** Bindings y configuración del Worker. Ver wrangler.toml (vars/bindings) y README (secrets). */
export interface Env {
  // --- Bindings (wrangler.toml) ---
  DB: D1Database;
  KV: KVNamespace;
  RATE_LIMITER: DurableObjectNamespace;

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

  // --- Secrets (wrangler secret put — NUNCA en el repo) ---
  OPENAI_API_KEY: string;
  EXCHANGE_RATE_API_KEY: string;
  JWT_SIGNING_SECRET: string;
  DEV_SHARED_SECRET: string; // bypass de dev/test; solo honrado en staging
  APP_STORE_API_KEY?: string; // App Store Server API / webhook
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
