//
//  RouterHoldCanary.swift
//  Yala
//
//  Canario D4 del gate Clase D (RouterConsumerGateLogic): un intent retenido
//  por hold es normal mientras dura el cover que tapa (segundos); un hold
//  SOSTENIDO delata un flag publicado pegado (shellModalBlocker /
//  isMainTabModalVisible / hasActivePresentation stale) — el único modo de
//  fallo nuevo que introduce el gate, invisible sin este evento.
//
//  Diseño: un deadline por intent al primer hold; al vencer, reporta SOLO si
//  el intent sigue en cola (drenado o dropeado en background = no-reporte).
//  Una vez por intent por sesión. Dependencias inyectables para tests
//  (el shared usa AppRouter + MetricsService reales).
//

import Foundation

@MainActor
final class RouterHoldCanary {

    static let shared = RouterHoldCanary()

    /// 45s: ningún cover legítimo del boot retiene tanto sin interacción;
    /// un paywall abierto minutos es decisión del usuario, pero entonces el
    /// intent sigue legítimamente en cola — el reporte sigue siendo señal
    /// útil de "hold largo", no un falso positivo destructivo (counts-only).
    private let threshold: Duration
    private let stillQueued: @MainActor (String) -> Bool
    private let report: @MainActor (_ blocker: String, _ consumer: String) -> Void

    private var deadlines: [String: Task<Void, Never>] = [:]
    private var reported: Set<String> = []

    init(
        threshold: Duration = .seconds(45),
        stillQueued: @escaping @MainActor (String) -> Bool = { id in
            AppRouter.shared.contains { $0.id == id }
        },
        report: @escaping @MainActor (_ blocker: String, _ consumer: String) -> Void = { blocker, consumer in
            MetricsService.routingDrainHoldSustained(blocker: blocker, consumer: consumer)
        }
    ) {
        self.threshold = threshold
        self.stillQueued = stillQueued
        self.report = report
    }

    /// Llamar en cada decisión de hold. Idempotente: el primer hold de un
    /// intent arma su deadline; los siguientes no lo re-arman.
    func noteHold(intentID: String, blocker: String, consumer: String) {
        guard deadlines[intentID] == nil, !reported.contains(intentID) else { return }
        deadlines[intentID] = Task { [weak self, threshold] in
            try? await Task.sleep(for: threshold)
            guard let self, !Task.isCancelled else { return }
            self.deadlines[intentID] = nil
            guard self.stillQueued(intentID), !self.reported.contains(intentID) else { return }
            self.reported.insert(intentID)
            self.report(blocker, consumer)
        }
    }

    /// Llamar al drenar el intent: cancela el deadline y libera el id
    /// (un intent futuro con el mismo id — p.ej. otro trialExpired en otra
    /// sesión de cola — vuelve a vigilarse).
    func noteDrained(intentID: String) {
        deadlines[intentID]?.cancel()
        deadlines[intentID] = nil
        reported.remove(intentID)
    }
}
