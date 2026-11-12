//
//  MemoryDiagnosticsLogic.swift
//  Yala
//
//  Qué cuenta la app a Sentry de su memoria y de la pantalla en la que está, sin depender del SDK (testeable en unit).
//
//  Existe por YALA-IOS-B (2026-11-12): un cierre por memoria (WatchdogTermination) llega sin stack, y con la limpieza
//  de antes llegaba además sin un solo dato de qué hacía la app. Con esto, el próximo trae la memoria que usaba, la que
//  le quedaba, el pico, la pestaña y los escalones que fue cruzando. Solo cifras y nombres fijos: nada del usuario.
//

import Foundation

nonisolated enum MemoryDiagnosticsLogic {

    /// Categoría de los rastros de memoria (escalones y avisos de memoria baja).
    static let memoryCategory = "memory"
    /// Categoría del rastro de cambio de pestaña.
    static let tabCategory = "ui.tab"
    /// Clave del contexto que Sentry guarda para el próximo cierre por memoria.
    static let contextKey = "memory"
    /// Etiqueta con la pestaña en la que está la app.
    static let screenTag = "screen"
    /// Mensaje del evento de memoria baja: constante, para que todos caigan en el mismo issue.
    static let lowMemoryMessage = "Aviso de memoria baja"

    /// Escalones de memoria (MB) que dejan un rastro la primera vez que se cruzan en el proceso. Un iPhone de 6 GB cierra
    /// una app en primer plano hacia los 3 GB, y uno de 8 GB algo más arriba: los últimos escalones son la antesala.
    static let footprintStepsMB: [Int] = [256, 512, 768, 1024, 1536, 2048, 2560, 3072, 4096]

    /// Cada cuánto se mide con la app delante.
    static let samplingInterval: Duration = .seconds(10)

    /// Diferencia mínima (MB) para volver a escribir el contexto. El SDK lo guarda en disco en cada cambio.
    static let contextRepublishDeltaMB = 16

    /// Como mucho un evento de memoria baja cada este tiempo: iOS repite el aviso mientras dura la presión.
    static let lowMemoryEventInterval: TimeInterval = 600

    static func megabytes(_ bytes: UInt64) -> Int {
        Int(bytes / 1_048_576)
    }

    /// El escalón más alto entre el pico anterior (excluido) y la medida de ahora (incluida). `nil` si no cruza ninguno.
    static func newlyCrossedStep(previousPeakMB: Int, currentMB: Int) -> Int? {
        footprintStepsMB.last { $0 > previousPeakMB && $0 <= currentMB }
    }

    /// Si toca volver a escribir el contexto: la primera vez, con otra pestaña o con la memoria movida lo bastante.
    static func shouldRepublish(lastPublishedMB: Int?, currentMB: Int, screenChanged: Bool) -> Bool {
        guard let lastPublishedMB, !screenChanged else { return true }
        return abs(currentMB - lastPublishedMB) >= contextRepublishDeltaMB
    }

    /// Si un aviso de memoria baja manda evento. Un reloj que vuelve atrás no lo calla para siempre.
    static func shouldSendLowMemoryEvent(lastSentAt: Date?, now: Date) -> Bool {
        guard let lastSentAt else { return true }
        return now < lastSentAt || now.timeIntervalSince(lastSentAt) >= lowMemoryEventInterval
    }

    /// El contexto `memory`: cifras en MB y la pestaña. `available_mb` falta donde iOS no la da (simulador).
    static func context(footprintMB: Int, availableMB: Int?, peakMB: Int, screen: String?) -> [String: Any] {
        var values: [String: Any] = ["footprint_mb": footprintMB, "peak_mb": peakMB]
        if let availableMB { values["available_mb"] = availableMB }
        if let screen { values["screen"] = screen }
        return values
    }

    /// Los datos de un rastro de memoria. Las mismas claves que conserva la limpieza (`ErrorReportScrubLogic`).
    static func breadcrumbData(footprintMB: Int, availableMB: Int?, stepMB: Int? = nil) -> [String: Any] {
        var values: [String: Any] = ["footprint_mb": footprintMB]
        if let availableMB { values["available_mb"] = availableMB }
        if let stepMB { values["step_mb"] = stepMB }
        return values
    }

    /// Las claves de dato que un rastro de memoria puede llevar a Sentry.
    static let memoryBreadcrumbKeys: Set<String> = ["footprint_mb", "available_mb", "step_mb"]

    /// Nombre fijo de cada pestaña, el que viaja a Sentry. Nunca un título de pantalla: puede llevar el nombre de un
    /// grupo o un importe.
    static let tabNames: Set<String> = [
        "panel", "statistics", "planning", "more", "search", "records", "reports", "groups",
    ]

    @MainActor
    static func tabName(_ tab: AppTab) -> String {
        switch tab {
        case .panel: "panel"
        case .statistics: "statistics"
        case .planning: "planning"
        case .more: "more"
        case .search: "search"
        case .records: "records"
        case .reports: "reports"
        case .groups: "groups"
        }
    }
}
