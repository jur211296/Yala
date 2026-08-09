//
//  CloudBackendConfig.swift
//  Yala
//
//  Configuración del backend del Modo Nube (Supabase Auth). Espeja el patrón de `ProxyConfig`:
//  commiteada, per-scheme, SIN secretos. La `anonKey` de Supabase es PÚBLICA por diseño (ya viaja
//  commiteada en los e2e / goldens del gateway) — es una JWT de rol `anon` que RLS gobierna; NUNCA
//  la `service_role`.
//
//  PRODUCCIÓN CABLEADA (D-R1 paso 1, 2026-07-30). Las dos ramas `#else` apuntan al proyecto
//  `yala-modo-nube-production` (ref `kefvaiymtgytemwbltlz`, us-east-1) — los MISMOS valores que ya
//  sirve `[env.production.vars]` de `gateway/wrangler.toml` ⇒ `isConfigured == true` en los dos
//  schemes. Esto NO enciende el Modo Nube: vuelve VERIFICABLE lo que hasta hoy se configuró a
//  ciegas (sign-in real con Apple y con Google, Authorized Client IDs, schema desplegado, el
//  `revoke` de `migrate_group`) y abre el fetch de `GET /config`, que es donde vive el aviso de
//  versión obligatoria (`ForceUpdateDecisionLogic`; el gateway sirve `MIN_SUPPORTED_BUILD = "0"`).
//
//  Estado del encendido (D-R1 COMPLETO, 30–31-jul-2026): el paso 2 flipeó
//  `groupsBackendCompiledDefault = true` y el paso 3 subió `GROUPS_BACKEND_ROLLOUT_PERCENT` a 100 —
//  el canal de Grupos corre contra el backend en producción (e2e device-verified 2026-08-02).
//  `CLOUD_MODE_ROLLOUT_PERCENT = 100` es permanente (migración opt-in silenciosa desde Ajustes) y
//  `CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT = 0` mantiene apagada la card born-cloud del onboarding.
//  Por qué un usuario de 2.x no nota nada en su store personal: el modo persistido es `.icloud`,
//  así que el gate de dominio corta el runtime antes de red o mutación; `CloudRemoteFlags` sigue
//  fail-closed (`absentDefault == false` en producción) para todo snapshot ausente.
//
//  Por qué el JWT legacy `anon` y no la publishable moderna (el proyecto tiene las dos): SIMETRÍA
//  con staging. `CloudAuthService` manda la clave en `Authorization: Bearer` y en `apikey`
//  (`:178-179`), y el `Bearer` con un JWT es exactamente lo que ya funciona en staging — si algo
//  falla aquí, la única variable debe ser "producción vs staging". Migrar AMBAS ramas a publishable
//  es trabajo aparte.
//

import Foundation

enum CloudBackendConfig {

    /// URL base del proyecto Supabase (sin `/auth/v1` — lo añade `CloudAuthService`).
    /// - `DEV_BUILD` → staging (mismo proyecto que `CloudSyncE2EStagingTests` / los goldens del gateway).
    /// - `#else` → producción (`yala-modo-nube-production`; el mismo `SUPABASE_URL` del gateway).
    nonisolated static var supabaseURL: URL? {
        #if DEV_BUILD
        return URL(string: "https://fostjbbwstyuunmmefuk.supabase.co")
        #else
        return URL(string: "https://kefvaiymtgytemwbltlz.supabase.co")
        #endif
    }

    /// Anon key (JWT de rol `anon`) — PÚBLICA por diseño, una por proyecto. Gobernada por RLS; la
    /// `service_role` NO entra en el cliente por ninguna vía.
    nonisolated static var anonKey: String {
        #if DEV_BUILD
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg"
        #else
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtlZnZhaXltdGd5dGVtd2JsdGx6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3OTg0MDYsImV4cCI6MjA5OTM3NDQwNn0.H8P3-kNUjeK8CTNZHwhfkqwqeflrNXLGvNa7OGGXkAk"
        #endif
    }

    /// Gate de construcción del subsistema de auth. `true` SOLO si hay URL de proyecto Y anon key.
    /// Desde D-R1 paso 1 es `true` en AMBOS schemes: el subsistema se CONSTRUYE en producción. Lo
    /// que decide si el usuario VE algo no es este gate, sino `CloudRemoteFlags` (fail-closed) y el
    /// modo de almacenamiento persistido (`.icloud` para todo el parque de 2.x).
    nonisolated static var isConfigured: Bool {
        supabaseURL != nil && !anonKey.isEmpty
    }
}
