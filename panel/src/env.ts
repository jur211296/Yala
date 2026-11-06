/** Bindings y configuración del Worker del panel. Ver wrangler.toml (vars) y README (secrets). */
export interface Env {
  // --- Binding (wrangler.toml) ---
  /** El resumen diario. Solo agregados por día: ningún identificador de instalación ni de cuenta. */
  PANEL_DB: D1Database;

  // --- Vars ---
  /** "production" | "local". En "local" la página se sirve sin Access (solo `wrangler dev`). */
  ENVIRONMENT: string;
  /** Cuenta de Cloudflare donde viven los datasets de Analytics Engine. */
  CF_ACCOUNT_ID: string;
  /** Dataset de la app y del gateway (`yala_metrics` en producción). */
  METRICS_DATASET: string;
  /** Dataset del uso de IA (`yala_ai_usage` en producción). */
  AI_USAGE_DATASET: string;
  /** Supabase de producción: URL y anon key, públicos. El conteo va con el JWT de máquina `yala_stats`. */
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  /** Cloudflare Access: dominio del equipo (`<equipo>.cloudflareaccess.com`) y AUD de la aplicación del panel. */
  ACCESS_TEAM_DOMAIN?: string;
  ACCESS_AUD?: string;
  /** Correos que pueden ver el panel, separados por comas. */
  ALLOWED_EMAILS: string;

  // --- Secrets (wrangler secret put — nunca en el repo) ---
  /** Token de la API de Cloudflare con un solo permiso: Account Analytics Read. */
  CF_ANALYTICS_TOKEN?: string;
  /** JWT de máquina con `role: yala_stats` (scripts/mint-stats-role-jwt.mjs). Ausente: el panel dice «sin datos de la base». */
  STATS_ROLE_JWT?: string;
}
