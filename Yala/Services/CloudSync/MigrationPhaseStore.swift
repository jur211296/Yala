//
//  MigrationPhaseStore.swift
//  Yala
//
//  SSOT de "fase de migración actual PARA LOS GATES" (§i.9). HOY devuelve la CONSTANTE `.notStarted`
//  en producción — el journal real que la alimentará es I10-wiring (bloqueado por los spikes device
//  S5/S6/S7). Este store existe DESDE YA para que el gate §i.9 de los BGTasks (`BGTaskMigrationGate`)
//  quede cableado LIVE con comportamiento IDÉNTICO al actual (toda fase estable → correr NORMAL) y para
//  que el spike S7 pueda SIMULAR una fase transitoria vía un override DEBUG y probar que el gate
//  suspende/difiere sin crashear el `mainContext` a medio hidratar.
//
//  Override DEBUG: persistido en `UserDefaults` key `spikeS7.simulatedPhase` como el rawValue de un
//  enum espejo PLANO de 6 opciones (`SimulatedPhase`). El `MigrationPhase` real lleva un associated
//  value en `cutover` → NO se serializa directo; el espejo mapea el único sub-estado transitorio que el
//  spike necesita (`cutover(.localModeSet)`). Ausencia de la key ⇒ sin override ⇒ `.notStarted`
//  (comportamiento de producción). SOLO el panel S7 escribe el override.
//
//  I10-wiring (w6): `configure(container:)` conecta el journal REAL (`MigrationState`, store sync-meta) →
//  `currentPhaseRead` ya NO es una constante. Precedencia: override DEBUG (S7) > journal real > `.notStarted`.
//  Los estados de REVERSA (I11) entran al MISMO enum/gate cuando existan (sin tocar el gate — solo la
//  lectura del journal).
//

import Foundation
import SwiftData

@MainActor
final class MigrationPhaseStore {

    // MARK: - Singleton

    static let shared = MigrationPhaseStore()

    // MARK: - Storage

    private let defaults: UserDefaults

    /// Container del journal (store sync-meta) — lo inyecta `configure(container:)` desde
    /// `BackgroundTaskManager.setModelContainer`. `nil` (tests puros / pre-boot) → sin journal → `.notStarted`.
    private var container: ModelContainer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Wiring del journal (I10-wiring w6)

    /// Conecta el journal real y deriva el gate PERMANENTE de captura de identidad al boot (§g.3): si la
    /// fase journaleada está en la ventana de captura (≥ `assigningIdentity`, no terminal), enciende
    /// `identityCaptureEnabled` para que sobreviva al relaunch (todo save nuevo acuña `syncID`). Llamado
    /// desde `BackgroundTaskManager.setModelContainer` (SIN tocar AppBootstrapper).
    ///
    /// **Un journal que no se deja leer no decide la ventana, ni hacia un lado ni hacia el otro** (ticket
    /// `an-unreadable-migration-journal-reads-as-never-started`). Encender la captura «por si acaso» contradice que no se
    /// enciende globalmente (I14), y un arranque prewarm —el store aún protegido— la encendería en medio parque. Dejarla
    /// apagada pierde la identidad de lo que se cree dentro de la ventana, porque el flag vive en memoria y solo se deriva
    /// aquí. Así que se APLAZA: la primera lectura buena de `currentPhaseRead` hace la derivación que aquí no se pudo, y
    /// cada primer plano la provoca (`deriveDeferredIdentityCaptureIfNeeded`).
    func configure(container: ModelContainer) {
        self.container = container
        deriveIdentityCapture(from: journaledPhaseRead(container: container))
        // w8 (DIFERIDOS #30): el drenaje único iKV→outbox del cutover se dispara AQUÍ porque configure
        // corre post-journal (el gate líder-only necesita la fase real) y antes de cualquier ciclo de
        // prefs del runtime. Internamente re-verifica todo (storageMode/fase/userID/sentinel) → no-op
        // total en producción (.icloud) y en cualquier device que no sea el líder post-relaunch.
        PreferenceSyncService.shared.drainiKVToOutboxOnceIfNeeded()
    }

    /// **R4 · seam del swap de persona in-process.** Suelta el container del journal. Sin `nil` aquí, el
    /// `ModelContainer` viejo sobrevive dentro de este singleton y el release verificado aborta — este
    /// store no cuelga de ninguna vista, así que desmontar la jerarquía no lo alcanza.
    ///
    /// **NO apaga `identityCaptureEnabled`**, y esa asimetría con `configure` es deliberada: ese flag es
    /// una decisión sobre la MIGRACIÓN de este device, derivada de una fase journaleada que el wipe del
    /// cierre de sesión acaba de destruir junto con el store de sync-meta. El re-bootstrap lo re-deriva del
    /// journal nuevo (vacío ⇒ `notStarted` ⇒ fuera de la ventana), que es la única fuente legítima.
    func releaseContainerForSwap() {
        container = nil
        identityCaptureDerivationPending = false
    }

    /// `configure` no pudo leer el journal y la ventana de captura quedó sin derivar. Lo consume la primera lectura buena.
    private(set) var identityCaptureDerivationPending = false

    /// Reintenta la derivación que `configure` no pudo hacer, si quedó alguna. Lo llama cada primer plano
    /// (`AppBootstrapper.handleBecameActive`), y no es un cinturón: en `.icloud` —toda la ventana de captura salvo el
    /// final del cutover— el motor, el remap y el drenaje de preferencias no llegan a leer la fase, así que sin esto la
    /// «primera lectura buena» esperaba a que iOS programara un BGTask (lo cazaron dos lentes de la review). Un prewarm con
    /// el store aún protegido deja el pendiente, y el primer `.active` lo resuelve antes de que la persona cree nada.
    func deriveDeferredIdentityCaptureIfNeeded() {
        guard identityCaptureDerivationPending else { return }
        _ = currentPhaseRead
    }

    /// Deriva el gate de captura de identidad de una lectura del journal, o lo aplaza si no se pudo leer. Solo ENCIENDE:
    /// apagarlo no es de esta función (ver la asimetría de `releaseContainerForSwap`).
    private func deriveIdentityCapture(from read: JournaledPhaseRead) {
        switch read {
        case .phase(let phase):
            identityCaptureDerivationPending = false
            if Self.isIdentityCaptureWindow(phase) {
                CloudSyncFlags.identityCaptureEnabled = true
            }
        case .unreadable:
            identityCaptureDerivationPending = true
        }
    }

    /// La ventana en que el gate permanente de captura de identidad debe estar ON (§g.3): desde que se
    /// asignó identidad hasta que la migración termina (done) o revierte (failedRollback). NO incluye las
    /// fases previas al backfill (notStarted/dryRun/consent/authenticating/waitingForLeader/claimingMigration).
    static func isIdentityCaptureWindow(_ phase: MigrationPhase) -> Bool {
        switch phase {
        case .assigningIdentity, .uploadingSnapshot, .verifying, .cutover:
            return true
        case .notStarted, .dryRun, .consent, .authenticating, .waitingForLeader,
             .claimingMigration, .done, .failedRollback:
            return false
        // Reversa (I11-1) → false: la ventana de captura era de la IDA; en `.cloud` el engine acuña
        // syncIDs por su camino y post-reversa no hay sync (misma clasificación que `done`).
        case .reverseConfirm, .reverseClaimLeader, .reverseDrainAll, .reverseVerify,
             .reverseFreezeBackend, .reverseMountMirror, .reverseReconcile, .reverseUpload,
             .icloudActive, .reverseFailedRollback:
            return false
        }
    }

    // MARK: - SSOT de fase

    /// La fase que consultan los gates, como LECTURA: `.unreadable` si el journal no se deja leer. Precedencia:
    /// override DEBUG (S7) > journal real (`MigrationState`, sync-meta) > `.notStarted`. Sin `configure` (tests puros /
    /// pre-boot) → override DEBUG o `.notStarted`.
    ///
    /// **Devuelve una lectura y no una `MigrationPhase` a propósito** (ticket
    /// `an-unreadable-migration-journal-reads-as-never-started`). Hasta ese ticket se llamaba `currentPhase` y el
    /// `catch` del fetch devolvía `.notStarted`, fase ESTABLE: el motor arrancaba, los BGTasks corrían sin gate y el
    /// remap de identidad se emitía, todo sobre un journal que no se había leído. Con el tipo nuevo cada consumidor
    /// está obligado por el compilador a decidir qué hace sin fase, y los siete deciden hacia el lado que no concede.
    var currentPhaseRead: JournaledPhaseRead {
        #if DEBUG
        if let simulated = simulatedPhase?.migrationPhase { return .phase(simulated) }
        #endif
        guard let container else { return .phase(.notStarted) }
        let read = journaledPhaseRead(container: container)
        if identityCaptureDerivationPending { deriveIdentityCapture(from: read) }
        return read
    }

    /// Lee la fase journaleada single-row del store sync-meta (lectura barata — sin import CloudKit).
    /// SOLO lectura: NO crea la fila (a diferencia de `loadOrCreate`).
    private func journaledPhaseRead(container: ModelContainer) -> JournaledPhaseRead {
        let context = ModelContext(container)
        return Self.phaseRead {
            if _testJournalFetchThrows { throw MigrationJournalSeamError.fetchFailed }
            var descriptor = FetchDescriptor<MigrationState>()
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        }
    }

    /// El núcleo de la lectura, separado del `ModelContext` para poder medir su `catch`: `ModelContext` es una
    /// `final class` de SwiftData sin protocolo detrás. Sin fila → `.phase(.notStarted)`. Un fetch que lanza →
    /// `.unreadable` + breadcrumb, **nunca `.notStarted`**. Una fila que se lee pero no se ENTIENDE (fase o pendientes
    /// que este build no decodifica, `isJournalUndecodable`) → `.unreadable` también, con su propio rastro (ticket
    /// `an-undecodable-migration-phase-reads-as-never-started`): hasta ese ticket salía el `.notStarted` de relleno de
    /// `readPhase()`, la fase estable más ancha.
    static func phaseRead(fetch: () throws -> MigrationState?) -> JournaledPhaseRead {
        do {
            guard let state = try fetch() else { return .phase(.notStarted) }
            guard !state.isJournalUndecodable else {
                CloudSyncBreadcrumb.migrationJournalUndecodable(reader: "phase-store")
                return .unreadable
            }
            return .phase(state.readPhase().phase)
        } catch {
            #if DEBUG
            print("MigrationPhaseStore: fetch(MigrationState) falló: \(error)")
            #endif
            CloudSyncBreadcrumb.migrationJournalUnreadable(reader: "phase-store")
            return .unreadable
        }
    }

    /// Hace que el fetch del journal LANCE — monta «el journal no se deja leer» sin tocar el store (molde de
    /// `MigrationWorkExecutor._testOutboxFetchThrowsFromCall`). SOLO tests.
    var _testJournalFetchThrows = false

    // MARK: - Override DEBUG (spike S7)

    #if DEBUG

    /// Espejo PLANO de las 6 opciones del picker → mapea a `MigrationPhase`. El associated value de
    /// `cutover` en el enum real es la razón de no serializar `MigrationPhase` directo.
    enum SimulatedPhase: String, CaseIterable {
        case notStarted
        case assigningIdentity
        case uploadingSnapshot
        case verifying
        case cutoverLocalModeSet
        case done

        var migrationPhase: MigrationPhase {
            switch self {
            case .notStarted:          return .notStarted
            case .assigningIdentity:   return .assigningIdentity
            case .uploadingSnapshot:   return .uploadingSnapshot
            case .verifying:           return .verifying
            case .cutoverLocalModeSet: return .cutover(.localModeSet)
            case .done:                return .done
            }
        }

        /// Etiqueta para el picker: marca estable/transitorio explícitamente (evita confusión en device).
        var label: String {
            switch self {
            case .notStarted:          return "notStarted · ESTABLE"
            case .assigningIdentity:   return "assigningIdentity · transitorio"
            case .uploadingSnapshot:   return "uploadingSnapshot · transitorio"
            case .verifying:           return "verifying · transitorio"
            case .cutoverLocalModeSet: return "cutover.localModeSet · transitorio"
            case .done:                return "done · ESTABLE"
            }
        }
    }

    private static let overrideKey = "spikeS7.simulatedPhase"

    /// El override actual (nil = sin override = comportamiento de producción `.notStarted`).
    var simulatedPhase: SimulatedPhase? {
        guard let raw = defaults.string(forKey: Self.overrideKey) else { return nil }
        return SimulatedPhase(rawValue: raw)
    }

    /// Escribe/limpia el override (persiste para sobrevivir a relaunch, como el journal real).
    func setSimulatedPhase(_ phase: SimulatedPhase?) {
        if let phase {
            defaults.set(phase.rawValue, forKey: Self.overrideKey)
        } else {
            defaults.removeObject(forKey: Self.overrideKey)
        }
    }

    #endif
}

/// El error que lanzan los dos seams del fetch del journal: `MigrationPhaseStore._testJournalFetchThrows` (unit) y
/// `UITestHooks.migrationJournalUnreadable` (XCUITest, en `CloudMigrationController`). SOLO tests.
nonisolated enum MigrationJournalSeamError: Error {
    case fetchFailed
}
