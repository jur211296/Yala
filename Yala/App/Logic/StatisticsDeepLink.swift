//
//  StatisticsDeepLink.swift
//  Yala
//
//  UX 2.2 · L11-2. Tocar el informe por notificación llevaba a Estadísticas sin elegir pestaña ni período: se abría en
//  la última que se usó y con el período que hubiera, y el número del aviso no estaba en pantalla. Y el enlace
//  `yala://statistics/trends` no abría Tendencias: solo se entendían `records` y `categories`.
//
//  Ahora el aviso lleva la pestaña y el período de los que habla (`statistics/insights/last7Days`), y los enlaces
//  aceptan las cuatro pestañas. El molde es el de `AlertDeepLinkTarget` (L10-13): el destino del router sigue siendo
//  `.statistics` —que ya sabe esperar al arranque en frío— y la petición espera aquí hasta que la ventana que lo drena
//  la aplica. El período vale para esa visita (`SessionState.applyVisitPeriod`).
//

import Foundation
import Observation

/// Qué pide abrir un enlace de Estadísticas. Sin estado: lo leen el servicio de avisos y el parseo del toque.
nonisolated enum StatisticsDeepLink: Sendable {

    enum Tab: String, Sendable, CaseIterable {
        case insights
        case trends
        case categories
        case records
    }

    /// Los períodos de los que habla un informe.
    enum Period: String, Sendable, CaseIterable {
        /// El diario: hoy.
        case today
        /// El semanal del domingo: los últimos 7 días.
        case last7Days
        /// El semanal del lunes: la semana de lunes a domingo que acaba de cerrar (UX 2.2 · L11-12).
        case lastWeek
        /// El mensual del día 1: el mes que acaba de cerrar.
        case lastMonth
        /// El mensual del último día: el mes en curso.
        case thisMonth
    }

    struct Request: Equatable, Sendable {
        let tab: Tab?
        let period: Period?
    }

    static let prefix = "statistics/"

    /// `statistics/<pestaña>[/<período>]`.
    static func deepLink(tab: Tab, period: Period?) -> String {
        guard let period else { return prefix + tab.rawValue }
        return prefix + tab.rawValue + "/" + period.rawValue
    }

    /// La petición de `statistics/<pestaña>[/<período>]`, o `nil` si el enlace no es de Estadísticas o no trae una
    /// pestaña conocida. «statistics» a secas (los avisos que ya estaban programados con la versión anterior) no trae
    /// petición: abre Estadísticas como siempre.
    static func request(fromDeepLink link: String) -> Request? {
        guard link.hasPrefix(prefix) else { return nil }
        return request(fromComponents: link.dropFirst(prefix.count).split(separator: "/").map(String.init))
    }

    /// La petición de las partes de la ruta de una URL (`yala://statistics/trends` → `["trends"]`).
    static func request(fromComponents components: [String]) -> Request? {
        let parts = components.filter { $0 != "/" && !$0.isEmpty }
        guard let first = parts.first, let tab = Tab(rawValue: first) else { return nil }
        let period = parts.dropFirst().first.flatMap(Period.init(rawValue:))
        return Request(tab: tab, period: period)
    }

    /// La pestaña y el período de un informe, con los mismos días que cuenta su texto
    /// (`ReportNotificationService.getIntervalForReportType`): el diario abre Registros con hoy; el semanal y el
    /// mensual, el Resumen con su período.
    static func reportRequest(type: NotificationType, dayPreference: ReportDayPreference) -> Request {
        if type == .dailyReport { return Request(tab: .records, period: .today) }
        switch dayPreference {
        case .sunday: return Request(tab: .insights, period: .last7Days)
        case .monday: return Request(tab: .insights, period: .lastWeek)
        case .firstDay: return Request(tab: .insights, period: .lastMonth)
        case .lastDay: return Request(tab: .insights, period: .thisMonth)
        }
    }

    static func reportDeepLink(type: NotificationType, dayPreference: ReportDayPreference) -> String {
        let request = reportRequest(type: type, dayPreference: dayPreference)
        return deepLink(tab: request.tab ?? .insights, period: request.period)
    }
}

extension StatisticsDeepLink.Tab {
    var detailTab: DetailViewTab {
        switch self {
        case .insights: return .insights
        case .trends: return .trends
        case .categories: return .categories
        case .records: return .records
        }
    }
}

extension StatisticsDeepLink.Period {
    /// El período de Estadísticas que le corresponde. «Hoy» no tiene uno fijo: es un rango de un día.
    func selection(now: Date = .now, calendar: Calendar = userConfiguredCalendar()) -> PeriodStepLogic.Selection {
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)
                .flatMap { calendar.date(byAdding: .second, value: -1, to: $0) } ?? now
            return PeriodStepLogic.Selection(period: .custom, customRange: DateInterval(start: start, end: end))
        case .last7Days: return PeriodStepLogic.Selection(period: .last7Days, customRange: nil)
        case .lastWeek:
            // Los mismos días que cuenta el aviso: no hay un período fijo «semana pasada», así que es un rango.
            let week = ReportNotificationService.closedWeek(before: now, calendar: calendar)
            return PeriodStepLogic.Selection(period: .custom, customRange: week)
        case .lastMonth: return PeriodStepLogic.Selection(period: .lastMonth, customRange: nil)
        case .thisMonth: return PeriodStepLogic.Selection(period: .thisMonth, customRange: nil)
        }
    }
}

/// La petición de un enlace de Estadísticas, esperando a la ventana que drene `.statistics`.
@MainActor
@Observable
final class StatisticsDeepLinkTarget {
    static let shared = StatisticsDeepLinkTarget()

    private(set) var pending: StatisticsDeepLink.Request?
    private var requestedAt: Date?

    /// Una petición que nadie recoge no puede cambiar el período horas después.
    static let maxAge: TimeInterval = 10 * 60

    func request(_ request: StatisticsDeepLink.Request, now: Date = .now) {
        pending = request
        requestedAt = now
    }

    /// La devuelve una sola vez, y nada si lleva más de `maxAge` esperando.
    func consume(now: Date = .now) -> StatisticsDeepLink.Request? {
        defer {
            pending = nil
            requestedAt = nil
        }
        guard let pending, let requestedAt, now.timeIntervalSince(requestedAt) <= Self.maxAge else { return nil }
        return pending
    }
}
