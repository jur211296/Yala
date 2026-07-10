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
//  `currentPhase` ya NO es una constante. Precedencia: override DEBUG (S7) > journal real > `.notStarted`.
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
    func configure(container: ModelContainer) {
        self.container = container
        if Self.isIdentityCaptureWindow(journaledPhase(container: container)) {
            CloudSyncFlags.identityCaptureEnabled = true
        }
        // w8 (DIFERIDOS #30): el drenaje único iKV→outbox del cutover se dispara AQUÍ porque configure
        // corre post-journal (el gate líder-only necesita la fase real) y antes de cualquier ciclo de
        // prefs del runtime. Internamente re-verifica todo (storageMode/fase/userID/sentinel) → no-op
        // total en producción (.icloud) y en cualquier device que no sea el líder post-relaunch.
        PreferenceSyncService.shared.drainiKVToOutboxOnceIfNeeded()
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
        }
    }

    // MARK: - SSOT de fase

    /// La fase que consultan los gates. Precedencia: override DEBUG (S7) > journal real (`MigrationState`,
    /// sync-meta) > `.notStarted`. Sin `configure` (tests puros / pre-boot) → override DEBUG o `.notStarted`.
    var currentPhase: MigrationPhase {
        #if DEBUG
        if let simulated = simulatedPhase?.migrationPhase { return simulated }
        #endif
        guard let container else { return .notStarted }
        return journaledPhase(container: container)
    }

    /// Lee la fase journaleada single-row del store sync-meta (lectura barata — sin import CloudKit).
    /// SOLO lectura: NO crea la fila (a diferencia de `loadOrCreate`). Sin fila / decode-fallback →
    /// `.notStarted` (+ breadcrumb RUIDOSO en el decode-fallback, coherente con el runner).
    private func journaledPhase(container: ModelContainer) -> MigrationPhase {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<MigrationState>()
        descriptor.fetchLimit = 1
        do {
            guard let state = try context.fetch(descriptor).first else { return .notStarted }
            let (phase, decodeFailed) = state.readPhase()
            if decodeFailed { CloudSyncBreadcrumb.migrationPhaseDecodeFailed() }
            return phase
        } catch {
            #if DEBUG
            print("MigrationPhaseStore: fetch(MigrationState) falló: \(error)")
            #endif
            return .notStarted
        }
    }

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
