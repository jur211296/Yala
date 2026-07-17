//
//  MigrationBootDecision.swift
//  Yala
//
//  Lógica PURA de arranque del Modo Nube (I14, P0/P4). Dos piezas independientes y testeables sin
//  `ModelContext`/red/`Date`:
//
//   - `MigrationRuntimeGate.isDomainStablePhase(_:)` — el gate de fase que `CloudSyncRuntime.start()`
//     consulta (P0): el runtime del DOMINIO solo corre en `.cloud` cuando la migración NO está en vuelo
//     (fase estable post-nube). En una fase transicional quien conduce es el `MigrationRunner`; el
//     coordinator de boot re-arranca el runtime al terminar.
//   - `MigrationBootDecision.decide(phase:hasPendingEffects:)` — qué debe hacer el boot con el journal
//     journaleado (P4): retomar una migración matada a medias (`resume`), sondear al líder
//     (`pollLeader`), o nada (`none`). Un EFECTO pendiente (p.ej. `.adoptBackendAccount` con fase
//     `notStarted`) fuerza `.resume` aunque la fase sea estable (AJUSTE review #3). Los terminales de
//     FALLO NO auto-resumen (es una decisión del usuario vía la UI).
//
//  DARK hasta que `CloudBackendConfig.isConfigured` (staging/DEV): en producción placeholder el boot
//  coordinator (`CloudMigrationController`) ni se instancia.
//

import Foundation

// MARK: - Gate de fase del runtime del dominio (P0)

/// El gate PURO de "¿puede el runtime del dominio correr en esta fase?" que `CloudSyncRuntime.start()`
/// consulta (P0). Estable = post-nube sin migración en vuelo. `nonisolated`: valor puro.
nonisolated enum MigrationRuntimeGate {

    /// ¿La fase journaleada es ESTABLE para el runtime del dominio? Solo `done` (líder migrado) y
    /// `notStarted` (device ADOPTADO, #30 — su journal queda `notStarted` tras `adoptBackendAccount`).
    /// Cualquier otra fase (cutover/reversa/adopt en vuelo, o un terminal de fallo que ya es `.icloud`)
    /// deja el runtime `.idle`: en `.cloud` con fase transicional quien conduce es el `MigrationRunner`.
    static func isDomainStablePhase(_ phase: MigrationPhase) -> Bool {
        switch phase {
        case .done, .notStarted:
            return true
        case .dryRun, .consent, .authenticating, .waitingForLeader, .claimingMigration,
             .assigningIdentity, .uploadingSnapshot, .verifying, .cutover, .failedRollback,
             .reverseConfirm, .reverseClaimLeader, .reverseDrainAll, .reverseVerify,
             .reverseFreezeBackend, .reverseMountMirror, .reverseReconcile, .reverseUpload,
             .icloudActive, .reverseFailedRollback:
            return false
        }
    }
}

// MARK: - Decisión de boot (P4)

/// Qué hacer al arrancar con un journal de migración journaleado (P4). `nonisolated`: lógica pura.
nonisolated enum MigrationBootDecision {

    enum Decision: Equatable {
        /// Retomar el trabajo (fase transicional, dryRun a normalizar, o efectos pendientes residuales).
        case resume
        /// Sondear al líder (fase `waitingForLeader`).
        case pollLeader
        /// Nada que hacer (terminal estable sin efectos pendientes, o terminal de FALLO — el usuario
        /// decide vía la UI).
        case none
    }

    /// Decide a partir de `(phase, hasPendingEffects)`. Un efecto pendiente FUERZA `.resume` aunque la
    /// fase sea estable (AJUSTE review #3): p.ej. un `.adoptBackendAccount` journaleado con fase
    /// `notStarted` debe ejecutarse. `dryRun` → `.resume` (la máquina la normaliza a su origen). Los
    /// terminales de fallo (`failedRollback`/`reverseFailedRollback`) NO auto-resumen.
    static func decide(phase: MigrationPhase, hasPendingEffects: Bool) -> Decision {
        if hasPendingEffects { return .resume }
        switch phase {
        case .waitingForLeader:
            return .pollLeader
        case .notStarted, .done, .icloudActive, .failedRollback, .reverseFailedRollback:
            return .none
        case .dryRun, .consent, .authenticating, .claimingMigration, .assigningIdentity,
             .uploadingSnapshot, .verifying, .cutover,
             .reverseConfirm, .reverseClaimLeader, .reverseDrainAll, .reverseVerify,
             .reverseFreezeBackend, .reverseMountMirror, .reverseReconcile, .reverseUpload:
            return .resume
        }
    }
}

// MARK: - Re-kick de foreground (#36, H1 corrida I14)

/// ¿Hay una migración/reversa APARCADA que el foreground debe re-kickear? (#36: el resume de boot era
/// one-shot — quiescencia vencida o un push transient a mitad de página dejaban la migración aparcada
/// EN SILENCIO hasta que el usuario tocara "Retomar"). Reusa `MigrationBootDecision.decide` — mismo
/// contrato del boot: transicionales/efectos pendientes → resume; `waitingForLeader` → pollLeader;
/// terminales estables y de FALLO → nada (el usuario decide en la UI). `isWorking=true` (controller
/// ya conduciendo, p.ej. la pre-espera del boot-resume en vuelo) → jamás re-kickear encima.
/// `nonisolated`: lógica pura, testeable por tabla.
nonisolated enum MigrationForegroundRekick {

    static func shouldRekick(phase: MigrationPhase, hasPendingEffects: Bool, isWorking: Bool) -> Bool {
        guard !isWorking else { return false }
        return MigrationBootDecision.decide(phase: phase, hasPendingEffects: hasPendingEffects) != .none
    }
}
