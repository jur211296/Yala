//
//  RemoteFlagDecisionLogic.swift
//  Yala
//
//  Pure-logic de la decisión de flags remote-config (DIFERIDOS #34, §j.1/§j.2).
//
//  El wire trae PERCENTS de rollout 0-100 por flag (decisión owner 2026-07-17: escalón gradual
//  §j.2 desde el día 1). El cliente computa un bucket ESTABLE por instalación (seed UUID
//  persistido una vez) y queda dentro si `bucket < percent`. `absentDefault` es PARÁMETRO (ajuste
//  A1 del review): los tests corren siempre bajo DEV_BUILD y la rama prod (fail-closed → OFF)
//  debe entrar a la tabla; el valor compile-time lo pasa `CloudRemoteFlags`.
//
//  `nonisolated`: funciones puras sin estado; se leen desde getters de flags en cualquier actor.
//

import Foundation

nonisolated enum RemoteFlagDecisionLogic {

    /// Ventana mínima entre fetches del config (frescura del kill-switch sin spamear la red:
    /// boot + onAppear de las entradas re-verifican como mucho cada 6 h).
    static let refreshMinInterval: TimeInterval = 6 * 60 * 60

    /// Bucket estable 0-99 derivado del seed de instalación. FNV-1a sobre UTF-8 — NUNCA
    /// `hashValue` (randomizado por proceso: movería la cohorte del usuario en cada launch).
    /// La estabilidad cross-launch la garantiza el golden de vectores fijos del test.
    static func stableBucket(seed: String) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return Int(hash % 100)
    }

    /// Decisión de un flag: con percent presente, `bucket < clamp(percent, 0...100)`;
    /// sin percent (snapshot ausente / flag ausente en el wire) → `absentDefault`
    /// (prod: `false` fail-closed; DEV: `true` para no perder superficie de QA sin fetch previo).
    static func isEnabled(percent: Int?, bucket: Int, absentDefault: Bool) -> Bool {
        guard let percent else { return absentDefault }
        let clamped = min(100, max(0, percent))
        return bucket < clamped
    }

    /// ¿Toca re-fetchear el config? `nil` (jamás fetcheado) → sí; `fetchedAt` en el FUTURO
    /// (reloj movido hacia atrás) → sí (futuro = stale; fix del review adversarial — sin esto, un
    /// fetch con el reloj mal adelantado congelaría el kill-switch por el tamaño del error);
    /// si no, min-interval. `now` inyectado (regla del repo: nunca `Date()` en lógica testeada).
    static func shouldRefresh(lastFetchedAt: Date?, now: Date) -> Bool {
        guard let lastFetchedAt else { return true }
        if lastFetchedAt > now { return true }
        return now.timeIntervalSince(lastFetchedAt) >= refreshMinInterval
    }
}
