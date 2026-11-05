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

/// Un evento en la cola con su identidad LOCAL. La identidad no viaja (el wire es `MetricsEvent`): solo sirve para que la
/// purga tras un envío retire exactamente lo que viajó (ticket
/// `metrics-drain-purge-drops-unsent-events-when-the-spool-is-full`).
nonisolated struct MetricsSpoolEntry: Codable, Equatable {
    var id: UUID
    var event: MetricsEvent
}

nonisolated enum MetricsSpool {

    static let pendingKey = "metrics.pendingEvents"
    static let capacity = 50

    /// Los eventos pendientes, en orden. Para LEER; quien vaya a purgar lo enviado usa `pendingEntries`.
    static func pending(_ defaults: UserDefaults = .standard) -> [MetricsEvent] {
        pendingEntries(defaults).map(\.event)
    }

    /// Los pendientes con su identidad. Lee también el formato de antes (`[MetricsEvent]` sin identidad, hasta 2.3): le
    /// pone una a cada evento en memoria y la escribe en el primer `enqueue` o purga, así una actualización no tira la cola.
    static func pendingEntries(_ defaults: UserDefaults = .standard) -> [MetricsSpoolEntry] {
        guard let data = defaults.data(forKey: pendingKey) else { return [] }
        do {
            return try JSONDecoder().decode([MetricsSpoolEntry].self, from: data)
        } catch {
            // No es el formato actual: puede ser el de antes. El error real, si lo hay, lo da el decode de abajo.
        }
        do {
            let legacy = try JSONDecoder().decode([MetricsEvent].self, from: data)
            let entries = legacy.map { MetricsSpoolEntry(id: UUID(), event: $0) }
            write(entries, defaults: defaults)
            return entries
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
        var queue = pendingEntries(defaults)
        queue.append(MetricsSpoolEntry(id: UUID(), event: event))
        if queue.count > capacity {
            queue.removeFirst(queue.count - capacity)
        }
        write(queue, defaults: defaults)
    }

    /// Retira los eventos que un envío acaba de entregar (o el servidor rechazó), POR IDENTIDAD. Hasta el 2026-11-05 se
    /// retiraban por posición (`removeFirst(batch.count)`), con la premisa «lo que se encola durante el envío va al
    /// final». Con la cola en su tope era falsa: `enqueue` recorta por el frente —justo lo que estaba en vuelo— y la purga
    /// cortaba después desde la cabeza NUEVA, llevándose canarios que no habían salido nunca. Lo que ya no está (lo recortó
    /// el tope durante el envío, o la cola se descartó por corrupta) simplemente no se encuentra.
    static func remove(ids: Set<UUID>, defaults: UserDefaults = .standard) {
        guard !ids.isEmpty else { return }
        let queue = pendingEntries(defaults)
        let kept = queue.filter { !ids.contains($0.id) }
        guard kept.count != queue.count else { return }
        write(kept, defaults: defaults)
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: pendingKey)
    }

    private static func write(_ queue: [MetricsSpoolEntry], defaults: UserDefaults) {
        do {
            defaults.set(try JSONEncoder().encode(queue), forKey: pendingKey)
        } catch {
            #if DEBUG
            print("MetricsSpool: pending no codifica: \(error)")
            #endif
        }
    }
}
