//
//  CloudSyncFlags.swift
//  Yala
//
//  Feature flags del Modo Nube (épica de sync). Incremento I2 (Identidad de sync).
//
//  Todo el subsistema de identidad se construye DARK: mergeable sin cambio de comportamiento
//  para los usuarios actuales. El único gate en runtime es `identityCaptureEnabled`, y HOY es
//  SIEMPRE `false` — ningún path de producción lo activa. Lo encenderá el propio Modo Nube en un
//  incremento posterior (I12/I14, cuando el pipeline de sync consuma las identidades), nunca antes.
//
//  `nonisolated`: son constantes/flags puros sin relación con el main actor; se leen tanto desde
//  hubs `@MainActor` (creación de entidades) como desde lógica de sync fuera del main actor.
//

import Foundation

/// Flags del Modo Nube. DARK por defecto.
nonisolated enum CloudSyncFlags {

    /// Cuando `true`, los hubs de creación de las 6 entidades sincronizables asignan un `syncID`
    /// (identidad estable de sync) al nacer la fila (born-cloud). HOY es `false` y NUNCA se activa
    /// en producción: la población masiva de identidades para datos preexistentes la hace la
    /// migración (I10, vía `SyncIdentityService.backfillIdentities`), no este flag. Lo encenderá el
    /// Modo Nube en I12/I14. Es una `var` (no `let`) solo para que los tests puedan togglearlo con
    /// `defer { restore }`.
    static var identityCaptureEnabled = false
}
