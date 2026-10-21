//
//  ICloudZoneScan.swift
//  Yala
//
//  **El recorrido de las zonas del espejo, con plazo SIN AVANCE** (card blqa del QA guiado del TF19, 2026-10-20).
//
//  Las tres revisiones de iCloud que hace la app sin adjuntar el espejo —la de la puerta privada y «Activar Yala completo»
//  (`ICloudPersonalCorpusProbe.measureFromCloudKit`), la del adopt (`findAdoptRelevantRecord`) y la de la vuelta a iCloud
//  (`scanForeignCorpus`)— cortaban con un plazo TOTAL (25 s, 25 s y 60 s). Con un iCloud con mucho historial la
//  revisión seguía avanzando página a página y aun así se cortaba: medido en el iPhone de QA, «No pudimos conectarnos a
//  iCloud · Puede ser la conexión» tres veces seguidas, sin un solo error de CloudKit en la consola. Es el mismo molde
//  que el borrado de «Empezar sin ellos» tenía hasta el #564.
//
//  **Avanzar es que llegue una página, traiga lo que traiga** (registros, solo borrados o nada). Se corta solo si una
//  espera —la lista de zonas o una página— pasa del plazo. Como en el #564, una petición colgada la acota el propio
//  CloudKit: el plazo se mira cuando la página vuelve. Y no hay plazo total: las pantallas que esperan esta revisión
//  tienen su «Volver».
//
//  Puro sobre `ICloudZoneScanIO`: los tests le dan páginas fabricadas y su propio reloj (no hay CloudKit en el
//  simulador ni en CI).
//

import CloudKit
import Foundation

/// Una página de `recordZoneChanges`, ya traducida.
nonisolated struct ICloudZoneScanPage<Cursor> {
    /// Los registros de la página; `nil` en el sitio de uno que CloudKit no dejó leer (fallo parcial).
    let records: [CKRecord?]
    /// Cuántos borrados trajo. No cuentan para nada más que el rastro: son la sospecha de la card.
    let deletions: Int
    let cursor: Cursor
    let moreComing: Bool
}

/// Lo que el recorrido necesita de CloudKit. `Cursor` es el `CKServerChangeToken` en producción (sin init público) y
/// cualquier cosa en los tests.
struct ICloudZoneScanIO<Cursor> {
    var zoneIDs: @MainActor () async throws -> [CKRecordZone.ID]
    /// La página de `zone` que sigue a `cursor`, o `nil` si la zona ya no existe y hay que saltarla.
    var page: @MainActor (_ zone: CKRecordZone.ID, _ cursor: Cursor?) async throws -> ICloudZoneScanPage<Cursor>?
    /// Reloj MONOTÓNICO en producción: cambiar la hora a mitad no puede adelantar ni alargar el corte.
    var now: @MainActor () -> Date
}

/// Cómo terminó un recorrido.
nonisolated enum ICloudZoneScanEnd: Equatable, Sendable {
    /// Recorrió todas las zonas.
    case finished
    /// El llamador pidió parar (ya sabe lo que quería: un registro relevante, el tope de registros).
    case stopped
    /// Una espera pasó del plazo sin avance. Lo leído hasta aquí no es una respuesta.
    case stalled
    /// Un registro que CloudKit no dejó leer. No se salta: contar de menos es decir «vacío» sin saberlo.
    case partialRecordFailure

    /// El motivo que viaja en `.failed(...)` y en los canarios cuando el recorrido se queda sin avance. Era
    /// `scanDeadline` mientras el plazo fue total: el valor cambia con el significado.
    static let stalledReason = "scanStalled"
}

/// Lo recorrido, para el rastro del dispositivo.
nonisolated struct ICloudZoneScanStats: Equatable, Sendable {
    var pages = 0
    var records = 0
    var deletions = 0
}

nonisolated struct ICloudZoneScanOutcome: Equatable, Sendable {
    let end: ICloudZoneScanEnd
    let stats: ICloudZoneScanStats
}

@MainActor
enum ICloudZoneScan {

    /// Recorre las zonas en orden y entrega cada página entera a `onPage`, que devuelve `true` para parar.
    ///
    /// - Los errores de la lista de zonas o de una página se PROPAGAN: cada llamador los clasifica a su manera.
    /// - `onPage` solo recibe páginas sin fallos parciales; una con alguno termina en `.partialRecordFailure`.
    static func run<Cursor>(
        io: ICloudZoneScanIO<Cursor>,
        stallLimit: TimeInterval,
        onPage: ([CKRecord]) -> Bool
    ) async throws -> ICloudZoneScanOutcome {
        var stats = ICloudZoneScanStats()
        var lastProgressAt = io.now()
        /// ¿La espera que acaba de terminar pasó del plazo? Se mira cuando la respuesta llega, antes de contarla.
        func waitedTooLong() -> Bool { io.now().timeIntervalSince(lastProgressAt) > stallLimit }

        let zones = try await io.zoneIDs()
        if waitedTooLong() { return ICloudZoneScanOutcome(end: .stalled, stats: stats) }
        lastProgressAt = io.now()

        for zone in zones {
            var cursor: Cursor?
            var moreComing = true
            while moreComing {
                let answer = try await io.page(zone, cursor)
                // «La zona ya no existe» también es una respuesta: cuenta como avance, o su espera se sumaría a la de la
                // página siguiente.
                let late = waitedTooLong()
                lastProgressAt = io.now()
                guard let page = answer else {
                    if late { return ICloudZoneScanOutcome(end: .stalled, stats: stats) }
                    break
                }
                stats.pages += 1
                stats.deletions += page.deletions
                let records = page.records.compactMap { $0 }
                guard records.count == page.records.count else {
                    return ICloudZoneScanOutcome(end: .partialRecordFailure, stats: stats)
                }
                stats.records += records.count
                // **Una página que llega tarde se le enseña igual al llamador** (review del 2026-10-20): si con ella ya sabe
                // lo que quería —el adopt encontró un registro relevante—, esa respuesta vale. Si no, el recorrido se rinde:
                // el resto llegaría igual de despacio.
                if onPage(records) { return ICloudZoneScanOutcome(end: .stopped, stats: stats) }
                if late { return ICloudZoneScanOutcome(end: .stalled, stats: stats) }
                cursor = page.cursor
                moreComing = page.moreComing
            }
        }
        return ICloudZoneScanOutcome(end: .finished, stats: stats)
    }
}
