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
//  I10-wiring reemplazará la constante `.notStarted` por la fase journaleada real; los estados de
//  REVERSA (I11) entran al MISMO enum/gate cuando existan (sin tocar el gate — solo `currentPhase`).
//

import Foundation

@MainActor
final class MigrationPhaseStore {

    // MARK: - Singleton

    static let shared = MigrationPhaseStore()

    // MARK: - Storage

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - SSOT de fase

    /// La fase que consultan los gates. Producción: SIEMPRE `.notStarted` (I10-wiring la reemplaza por
    /// el journal real). DEBUG: el override simulado si está presente, si no `.notStarted`.
    var currentPhase: MigrationPhase {
        #if DEBUG
        return simulatedPhase?.migrationPhase ?? .notStarted
        #else
        return .notStarted
        #endif
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
