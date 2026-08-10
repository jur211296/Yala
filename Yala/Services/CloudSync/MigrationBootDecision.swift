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
//  Desde D-R1 paso 1 el boot coordinator (`CloudMigrationController`) SÍ se instancia en producción
//  (`CloudBackendConfig.isConfigured` vale `true` en los dos schemes). Lo que lo deja sin trabajo es la
//  fase journaleada: `notStarted` y sin efectos pendientes ⇒ `.none`.
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
    /// C-1: ¿puede arrancar el motor del dominio nube? Exige fase ESTABLE **y** que el par de storage no
    /// declare "el mirror de CloudKit sigue vivo" (`StorageModePersistence.isCloudWithMirrorOn`).
    ///
    /// Por qué hace falta el segundo término: `notStarted` es fase estable (device ADOPTADO, #30), así que un
    /// par a medio escribir —`.cloud` persistido pero mirror-off SIN armar, p.ej. por un kill entre las dos
    /// keys del adopt, o por un cierre de reversa a medias— dejaba pasar este gate con el mirror MONTADO ⇒
    /// motor y mirror escribiendo el mismo store a la vez, sin ningún gate de fase que lo notara. `UserDefaults`
    /// no tiene transacción, así que el invariante no se puede garantizar en el escritor: se enforcea aquí.
    ///
    /// `isDomainStablePhase` queda INTACTO (lo consumen otros sitios) y en `.icloud` el término nuevo es
    /// `false` por construcción ⇒ inerte para 2.x.
    ///
    /// **A3 (D-A7) — TERCER término: `personalMountMismatch`.** El par persistido dice qué modo QUIERE el
    /// device; no dice qué montó ESTE proceso. Un born-cloud escribe el par entero en caliente y hasta el
    /// relanzamiento sigue corriendo sobre el store montado en `.icloud`: ahí `isCloudWithMirrorOn` da
    /// `false` (el par está COMPLETO) y la fase es `notStarted` (ESTABLE) ⇒ los dos términos anteriores
    /// dejaban arrancar el motor con el mirror de CloudKit todavía montado. Es el MISMO desenlace que el
    /// agujero de C-1 por un camino distinto, y por eso el término es aditivo y va aquí: `canRun` es el
    /// único sitio por el que pasa la decisión de arrancar. Es un parámetro SIN default a propósito —
    /// cualquier consumidor futuro está obligado por el compilador a pronunciarse sobre el mount.
    static func canRun(phase: MigrationPhase, cloudWithMirrorOn: Bool, personalMountMismatch: Bool) -> Bool {
        !personalMountMismatch && !cloudWithMirrorOn && isDomainStablePhase(phase)
    }

    /// A3 (D-A7): ¿el modo EFECTIVO dice nube pero este proceso montó el store personal en `.icloud`?
    ///
    /// `personalConfiguration` se evalúa UNA sola vez al construir el container y el testigo
    /// (`SwiftDataConfiguration.personalStoreMountedDecision`) se captura con él, así que **escribir el par
    /// en caliente no remonta nada**: hasta el relanzamiento el proceso sigue con el mirror de CloudKit vivo.
    /// Arrancar el motor del dominio ahí sería motor + mirror escribiendo el mismo store — la doble
    /// escritura que el relanzamiento asistido (P3) existe para evitar.
    ///
    /// Hasta A3 lo único que impedía ese estado era una CONVENCIÓN: el único camino a `.cloud` pasaba por la
    /// máquina de migración, que exige el relanzamiento. El born-cloud abre un segundo camino, y una
    /// convención no es un guard. Con esto, si alguien mañana escribe el par sin relanzar, el motor se queda
    /// quieto en vez de duplicar escrituras.
    ///
    /// **En `.icloud` es `false` por construcción** ⇒ inerte para el 99 % del parque, igual que el término
    /// de C-1. Y cubre también la ventana del ADOPT existente (par escrito por `runAdoptFlow`, proceso
    /// viejo), que hoy depende de que nadie invoque `start()` a mitad de sesión.
    ///
    /// El modo que se pasa es el EFECTIVO (`CloudSyncFlags.storageMode`), no el persistido: es el que
    /// gobierna qué store se sincroniza. En la sesión secundaria OPERATIVA el mount es
    /// `.secondaryCloudSession`, que NO adjunta mirror ⇒ no hay mismatch; su VENTANA DE ENTRADA la corta
    /// antes el guard M1 de `CloudSyncRuntime.canRunDomain`, que tiene su propio canario.
    ///
    /// **R1 (relanzamiento cero): el segundo parámetro es la DECISIÓN de mount, no un `StorageMode`.** La
    /// pregunta que decide es «¿hay un mirror de CloudKit adjunto a este store?», y el `StorageMode` de dos
    /// valores no podía expresarla: colapsaba las cuatro decisiones en dos y hacía imposible declarar un
    /// mount sin mirror que no fuera `.cloudMirrorOff` ni la secundaria. Sigue SIN default a propósito.
    static func isPersonalMountMismatch(persistedMode: StorageMode,
                                        mountedDecision: SwiftDataConfiguration.PersonalStoreDecision) -> Bool {
        persistedMode == .cloud && mountedDecision.attachesCloudKitMirror
    }

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
