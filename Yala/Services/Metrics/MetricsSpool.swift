//
//  MetricsSpool.swift
//  Yala
//
//  Cola persistida de eventos de telemetría propia pendientes de envío. Los canarios
//  son el gate operativo de Modo Nube — no pueden ser fire-and-forget puro (directiva
//  no-diferir): un fallo de red los deja aquí y el próximo trigger (boot/foreground)
//  los drena. Cap con drop-oldest: la telemetría jamás crece sin límite.
//
//  Semántica de las keys `metrics.*` (DEVICE-GLOBAL, decisión 2026-07-17): viven en
//  `UserDefaults.standard` y NO las barre ni el sweep de sign-out
//  (`DataWipeService.removeUserPreferenceKeys` es una lista explícita de keys de
//  preferencias) ni la purga de frontera M1 (superficies enumeradas) — mismo
//  razonamiento que `cloudSync.*`/bucketSeed: no contienen datos de usuario (solo
//  nombres de eventos + slugs sin PII) y el install-hash es por instalación, no por
//  cuenta. `-uitest-reset` sí las limpia (higiene de corridas).
//

import Foundation

nonisolated enum MetricsSpool {

    static let pendingKey = "metrics.pendingEvents"
    static let capacity = 50

    static func pending(_ defaults: UserDefaults = .standard) -> [MetricsEvent] {
        guard let data = defaults.data(forKey: pendingKey) else { return [] }
        do {
            return try JSONDecoder().decode([MetricsEvent].self, from: data)
        } catch {
            // Spool corrupto (bit-rot/schema viejo) → se descarta; eventos nuevos lo repueblan.
            #if DEBUG
            print("MetricsSpool: pending no decodifica (se descarta): \(error)")
            #endif
            defaults.removeObject(forKey: pendingKey)
            return []
        }
    }

    /// Encola al final; si supera el cap, cae el MÁS VIEJO (los canarios recientes
    /// valen más que los antiguos — el gate mira "ahora", no historia).
    static func enqueue(_ event: MetricsEvent, defaults: UserDefaults = .standard) {
        var queue = pending(defaults)
        queue.append(event)
        if queue.count > capacity {
            queue.removeFirst(queue.count - capacity)
        }
        write(queue, defaults: defaults)
    }

    /// Retira los primeros `count` (los que un drain acaba de entregar). Los appends
    /// concurrentes van al final, así que retirar por prefijo es seguro.
    static func removeFirst(_ count: Int, defaults: UserDefaults = .standard) {
        var queue = pending(defaults)
        queue.removeFirst(min(count, queue.count))
        write(queue, defaults: defaults)
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: pendingKey)
    }

    private static func write(_ queue: [MetricsEvent], defaults: UserDefaults) {
        do {
            defaults.set(try JSONEncoder().encode(queue), forKey: pendingKey)
        } catch {
            #if DEBUG
            print("MetricsSpool: pending no codifica: \(error)")
            #endif
        }
    }
}
