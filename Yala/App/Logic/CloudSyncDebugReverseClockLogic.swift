//
//  CloudSyncDebugReverseClockLogic.swift
//  Yala
//
//  Lo que el panel de depuración de la nube (`CloudSyncDebugView`, DEV_BUILD) pinta del techo de la vuelta a iCloud
//  ANTES del montaje del espejo (ticket `debug-panel-shows-a-counter-the-reverse-no-longer-moves`). Fuera del
//  `#if DEV_BUILD` de la vista a propósito: es lógica pura y los unit tests corren con el scheme `Yala`.
//
//  Desde el 2026-09-21 la vuelta no escribe `verifyNetworkRetries` en ninguna de sus cuatro fases previas al montaje: su
//  red, su sesión caducada y el `blocked` del servidor pasan por el techo de la etapa. El panel seguía diciendo «red 0» de
//  una vuelta parada por red y no enseñaba el reloj que lo sustituye.
//

import Foundation

nonisolated enum CloudSyncDebugReverseClockLogic {

    /// La fila «Contadores». En las cuatro fases previas al montaje de la vuelta el contador de red NO se mueve, así que
    /// ahí no se afirma ninguna cifra: se manda a la fila del techo.
    static func countersLabel(
        phase: MigrationPhase, mismatchRetries: Int, networkRetries: Int, leaderDeviceID: String?, serverSeqCut: Int64
    ) -> String {
        let network = ReversePreMountPhase(phase: phase) == nil
            ? "red \(networkRetries)"
            : "red n/a (vuelta: ver «Techo vuelta»)"
        return "mismatch \(mismatchRetries) · \(network) · leader \(leaderDeviceID ?? "—") · seqCut \(serverSeqCut)"
    }

    /// Lo que la fila «Techo vuelta» necesita del journal.
    struct Clock: Equatable {
        var phase: MigrationPhase
        var sealedPhaseRaw: String?
        var progressAt: Date?
        var causeRaw: String?
        var causeAt: Date?
        var causeAccruedSeconds: Double?
        var definitiveAt: Date?
        var definitiveAccruedSeconds: Double?
    }

    /// La fila «Techo vuelta»: en qué fase se selló el reloj, desde cuándo y cuánto lleva parada, y los dos relojes que
    /// gobiernan el techo corto (el de la causa y el de cualquier motivo definitivo).
    ///
    /// «Cuánto lleva parada» es el mismo cálculo que `MigrationRunner.observeReversePreMountStall`: si el sello es de otra
    /// fase, cambiar de fase ES el avance y la próxima observación empieza en cero; un sello en el futuro (el reloj del
    /// teléfono hacia atrás) también. Un `nil` en la causa no es «sin problema»: la red llega así y PAUSA los relojes.
    static func clockLabel(_ clock: Clock, now: Date) -> String {
        let current = ReversePreMountPhase(phase: clock.phase)
        let sealed = clock.sealedPhaseRaw.flatMap(ReversePreMountPhase.init(rawValue:))
        guard let sealed, let progressAt = clock.progressAt else {
            return current.map { "\($0.rawValue) · sin sello (aún no se observó parada)" } ?? "—"
        }
        var parts: [String] = []
        let since = progressAt.formatted(date: .abbreviated, time: .standard)
        if current != sealed {
            parts.append("sello de \(sealed.rawValue) (fase actual: \(current?.rawValue ?? "fuera de la etapa")) · desde \(since)")
        } else if progressAt > now {
            parts.append("\(sealed.rawValue) · sello en el futuro (\(since)): la próxima observación lo re-sella")
        } else {
            parts.append("\(sealed.rawValue) · parada \(seconds(now.timeIntervalSince(progressAt))) (desde \(since))")
        }
        if let cause = clock.causeRaw {
            let total = accrued(clock.causeAccruedSeconds, openSince: clock.causeAt, now: now)
            parts.append("causa \(cause) \(seconds(total))" + (clock.causeAt == nil ? " (en pausa)" : ""))
        } else {
            parts.append("causa — (red o sin motivo: pausa)")
        }
        if clock.definitiveAt != nil || clock.definitiveAccruedSeconds != nil {
            let total = accrued(clock.definitiveAccruedSeconds, openSince: clock.definitiveAt, now: now)
            parts.append("definitivo \(seconds(total))" + (clock.definitiveAt == nil ? " (en pausa)" : ""))
        }
        return parts.joined(separator: " · ")
    }

    private static func accrued(_ closed: Double?, openSince: Date?, now: Date) -> Double {
        let open = openSince.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return (closed ?? 0) + open
    }

    private static func seconds(_ value: Double) -> String { "\(Int(value.rounded()))s" }
}
