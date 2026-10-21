//
//  InviteOpeningState.swift
//  Yala
//
//  «Abriendo tu invitación…» (card z81w, 2026-10-20). Estado del PROCESO, no de una vista: lo enciende el enlace al
//  llegar —en frío, antes incluso de que la bienvenida se monte— y lo apaga quien releva a la bienvenida. La decisión
//  pura vive en `InviteOpeningLogic`.
//
//  **Quién lo apaga, y por qué son estos:**
//   · `ContentView.drainContentViewIntents`, al drenar un intent que releva a la bienvenida (firmar, consentir, la hoja o
//     su puerta). Es el final normal.
//   · el enlace que no se puede abrir (`AppBootstrapper.handleInviteLink`): su aviso espera a que la bienvenida se cierre.
//   · el join que sale directo, sin pantalla delante (`GroupBackendInviteEntryHandler.drive`, rama `.join`), y la
//     invitación que no tiene nada que enseñar (`GroupJoinReconciler`: ya es miembro, o el canal está apagado).
//   · el techo (`InviteOpeningLogic.ceiling`), con canario: lo demás no llegó y vuelve la bienvenida normal. **Cuenta
//     desde que la pantalla APARECE** (`screenAppeared`), no desde que llega el enlace: en frío el enlace llega antes del
//     splash y del arranque, y contado desde ahí el techo podía vencer antes de que hubiera bienvenida que tapar (review
//     del 2026-10-20).
//

import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class InviteOpeningState {

    static let shared = InviteOpeningState()

    /// ¿Se está abriendo una invitación con la bienvenida delante?
    private(set) var isOpening = false

    /// Cómo terminó, para el rastro.
    enum Ending: String {
        case handedOver, linkFailed, joinAttempted, nothingToOpen, ceiling
    }

    @ObservationIgnored private var ceilingTask: Task<Void, Never>?
    @ObservationIgnored private var origin = "cold"
    /// Sustituible en tests.
    @ObservationIgnored var ceiling: TimeInterval = InviteOpeningLogic.ceiling

    private static let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    /// Empieza a abrir una invitación. Idempotente: un segundo enlace no cambia nada. El techo aún no corre: empieza con
    /// `screenAppeared`.
    func begin(origin: String) {
        guard !isOpening else { return }
        isOpening = true
        self.origin = origin
        Self.logger.notice("InviteOpening: begin origin=\(origin, privacy: .public)")
    }

    /// La pantalla «Abriendo tu invitación…» apareció: desde aquí cuenta el techo. Idempotente mientras dure la apertura.
    func screenAppeared() {
        guard isOpening, ceilingTask == nil else { return }
        let seconds = ceiling
        ceilingTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            self?.finish(.ceiling)
        }
    }

    /// Termina. Sin efecto si no se estaba abriendo nada.
    func finish(_ ending: Ending) {
        guard isOpening else { return }
        isOpening = false
        ceilingTask?.cancel()
        ceilingTask = nil
        if ending == .ceiling {
            MetricsService.canary(.inviteOpeningCeilingReached, detail: origin)
        }
        Self.logger.notice("InviteOpening: end=\(ending.rawValue, privacy: .public)")
    }

    #if DEBUG
    /// Repone el estado entre tests.
    func _testReset() {
        ceilingTask?.cancel()
        ceilingTask = nil
        isOpening = false
        ceiling = InviteOpeningLogic.ceiling
    }
    #endif
}
