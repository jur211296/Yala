//
//  SubcategoryDedupGate.swift
//  Yala
//
//  Pure-logic que decide SI conviene correr el dedup ahora, según el estado del
//  sync de CloudKit. Evita borrar copias mientras CloudKit aún importa oleadas
//  (estado parcial) y evita thrashing si llegan ráfagas seguidas.
//
//  Devuelve la RAZÓN (no solo un Bool) para que el caller pueda programar un
//  retry diferido cuando el bloqueo es por falta de quiescencia — así el trailing
//  edge del observer (3 s) no se "pierde" cuando la ventana de silencio es mayor.
//

import Foundation

enum SubcategoryDedupGate {

    enum Decision: Equatable {
        case run
        case syncing                              // import/export en curso → esperar otro trigger
        case throttled                            // corrió hace poco → no repetir
        case waitQuiescence(retryAfter: TimeInterval)  // import reciente → reintentar tras la ventana
    }

    /// - quietWindow: silencio mínimo desde el último import para considerar convergido (default 8 s).
    /// - minInterval: intervalo mínimo entre pases para no thrashear (default 60 s).
    static func decide(
        now: Date,
        lastImportDate: Date?,
        isSyncing: Bool,
        lastDedupRunAt: Date?,
        quietWindow: TimeInterval = 8,
        minInterval: TimeInterval = 60
    ) -> Decision {
        if isSyncing { return .syncing }

        if let last = lastDedupRunAt, now.timeIntervalSince(last) < minInterval {
            return .throttled
        }

        if let imported = lastImportDate {
            let elapsed = now.timeIntervalSince(imported)
            if elapsed < quietWindow {
                return .waitQuiescence(retryAfter: quietWindow - elapsed)
            }
        }
        // Sin import previo (p. ej. sin cuenta iCloud) y sin sync: nada que esperar.
        return .run
    }
}
