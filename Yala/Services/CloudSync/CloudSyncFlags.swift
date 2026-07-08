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

/// Modo de almacenamiento del store personal (SSOT del enrutado de quiescencia y de las redes de
/// arranque/teardown del motor). `nonisolated`: es un valor puro leído tanto desde el main actor
/// (bootstrap) como desde la lógica pura de enrutado (`StorageModeSignalRouter`).
///
/// - `.icloud`: el store personal lo espeja NSPersistentCloudKitContainer (comportamiento de HOY,
///   SIEMPRE). La quiescencia la manda `iCloudSyncService.isImportQuiescent`.
/// - `.cloud`: el store personal lo sincroniza el propio motor Modo Nube (CKit apagado). La
///   quiescencia la manda el `SyncQuiescenceCoordinator` del motor. NO alcanzable en I9 — la
///   persistencia real del modo + su transición llegan en I10/I14.
nonisolated enum StorageMode: String {
    case icloud
    case cloud
}

/// Flags del Modo Nube. DARK por defecto.
nonisolated enum CloudSyncFlags {

    /// Cuando `true`, los hubs de creación de las 6 entidades sincronizables asignan un `syncID`
    /// (identidad estable de sync) al nacer la fila (born-cloud). HOY es `false` y NUNCA se activa
    /// en producción: la población masiva de identidades para datos preexistentes la hace la
    /// migración (I10, vía `SyncIdentityService.backfillIdentities`), no este flag. Lo encenderá el
    /// Modo Nube en I12/I14. Es una `var` (no `let`) solo para que los tests puedan togglearlo con
    /// `defer { restore }`.
    static var identityCaptureEnabled = false

    /// Gate ÚNICO del wiring runtime del motor (I9). Cuando `false` (default, PRODUCCIÓN HOY) el
    /// `CloudSyncRuntime` no arranca ninguna cadencia, no toca la red y no muta el store: el
    /// comportamiento es EXACTAMENTE el de antes de I9. Lo encenderá el Modo Nube en un incremento
    /// posterior. `var` (no `let`) solo para que los tests lo togglean con `defer { restore }`.
    static var syncRuntimeEnabled = false

    /// SSOT PROVISIONAL del modo de almacenamiento. HOY es SIEMPRE `.icloud` y ningún path de
    /// producción lo cambia — la persistencia real (leer/escribir el modo elegido en onboarding/
    /// migración) llega en I10/I14. `var` para que los tests ejerciten el enrutado `.cloud`.
    static var storageMode: StorageMode = .icloud

    /// SUB-flag de la purga de SwiftData History tras un ciclo completo del runtime (sigue DOBLE-DARK:
    /// exige además `syncRuntimeEnabled`, hoy `false` → la purga NO corre en producción todavía).
    /// `true` desde el veredicto del spike device S2 (owner, 2026-07-08, iPhone real con datos +
    /// grupo activo): una purga de 6284 transacciones de History inmediatamente después de un import
    /// inicial completo NO invalidó el token del mirror personal de NSPersistentCloudKitContainer
    /// (export incremental limpio post-purga, cero re-import) NI afectó al CKSyncEngine de Grupos
    /// (round-trip de systemFields aceptado post-purga; CKSyncEngine no consume History — es
    /// storage-agnóstico, los records se los damos a mano). Veredicto completo en
    /// MODO-NUBE-SPIKES-I0 §S2 (matiz: verificado single-device + análisis de código). El corte de
    /// `purgeHistoryOnce` sigue siendo conservador (`deleteHistorySafeCut`: nunca por delante de la
    /// fila outbox sin-2xx más vieja). `var` solo para tests (`defer { restore }`).
    static var historyPurgeEnabled = true
}
