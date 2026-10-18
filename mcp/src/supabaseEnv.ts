/**
 * Lo mínimo del entorno para leer Supabase: dónde está y su clave pública. Sin imports a propósito: lo usan `egress.ts`,
 * `data.ts` y `toolCore.ts`, que también importa el gateway de Yala (ver la cabecera de `toolCore.ts`). El `Env`
 * completo del conector (`env.ts`) lo cumple sin declararlo.
 */
export interface SupabaseEnv {
  /** https://<ref>.supabase.co — sin barra final. */
  SUPABASE_URL: string;
  /** Clave pública (anon). No es un secreto: RLS y el token del usuario son el control. */
  SUPABASE_ANON_KEY: string;
}
