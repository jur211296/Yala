//
//  CloudBackendConfig.swift
//  Yala
//
//  Configuración del backend del Modo Nube (Supabase Auth). Espeja el patrón de `ProxyConfig`:
//  commiteada, per-scheme, SIN secretos. La `anonKey` de Supabase es PÚBLICA por diseño (ya viaja
//  commiteada en los e2e / goldens del gateway) — es una JWT de rol `anon` que RLS gobierna; NUNCA
//  la `service_role`.
//
//  DARK-ness (I7c): en producción el proyecto Supabase de producción todavía NO existe → los valores
//  son PLACEHOLDER vacíos y `isConfigured == false`. Con `isConfigured == false` NADA del subsistema
//  de auth se construye (ni AuthClient, ni observer de revocación, ni provider vivo) y el runtime del
//  Modo Nube conserva el `NoopCloudSessionProvider` de I9: cero cambio de comportamiento.
//

import Foundation

enum CloudBackendConfig {

    /// URL base del proyecto Supabase (sin `/auth/v1` — lo añade `CloudAuthService`).
    /// - `DEV_BUILD` → staging (mismo proyecto que `CloudSyncE2EStagingTests` / los goldens del gateway).
    /// - `#else` → producción PLACEHOLDER vacío (el proyecto de producción no existe aún).
    nonisolated static var supabaseURL: URL? {
        #if DEV_BUILD
        return URL(string: "https://fostjbbwstyuunmmefuk.supabase.co")
        #else
        return nil
        #endif
    }

    /// Anon key (JWT de rol `anon`) — PÚBLICA por diseño. Vacía en producción (placeholder).
    nonisolated static var anonKey: String {
        #if DEV_BUILD
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg"
        #else
        return ""
        #endif
    }

    /// Gate de construcción del subsistema de auth. `true` SOLO si hay URL de proyecto Y anon key.
    /// En producción HOY (placeholder) es `false` → toda la superficie de auth queda inerte (DARK).
    nonisolated static var isConfigured: Bool {
        supabaseURL != nil && !anonKey.isEmpty
    }
}
