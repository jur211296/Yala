//
//  L10n+UXAudit22Lote11Decididas.swift
//  Yala
//
//  Textos de las decisiones de Jürgen sobre el lote 11 de la auditoría UX 2.2 (Estadísticas), implementadas el
//  2026-10-18. Van en su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func l11d(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

extension L10n {
    enum UXL11D {

        // MARK: - Fechas dentro de una frase

        /// Idiomas que escriben los días y los meses en minúscula dentro de la frase. `DateFormatter` devuelve
        /// «Octubre» con mayúscula en `es_PE` (medido el 2026-10-18), y en mitad de una frase va en minúscula.
        private static let lowercaseDateNames: Set<String> = ["es", "fr", "it", "pt", "nl", "pl"]

        private static func formatted(_ date: Foundation.Date, template: String) -> String {
            let locale = AppLocale.current
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate(template)
            let text = formatter.string(from: date)
            guard let language = locale.language.languageCode?.identifier, lowercaseDateNames.contains(language)
            else { return text }
            return text.lowercased(with: locale)
        }

        /// «octubre».
        static func monthName(of date: Foundation.Date) -> String { formatted(date, template: "MMMM") }
        /// «lunes».
        static func weekdayName(of date: Foundation.Date) -> String { formatted(date, template: "EEEE") }
        /// «lunes 6».
        static func weekdayAndDay(of date: Foundation.Date) -> String { formatted(date, template: "EEEEd") }
        /// «1 de noviembre».
        static func dayAndMonth(of date: Foundation.Date) -> String { formatted(date, template: "dMMMM") }

        // MARK: - Lo que te falta pagar · Tus presupuestos (L11-5)

        static var toPayTitle: String { l11d("stats.l11d.toPay.title") }
        static func toPayTotal(_ amount: String) -> String { String(format: l11d("stats.l11d.toPay.total"), amount) }
        static var toPayPayments: String { l11d("stats.l11d.toPay.payments") }
        static var toPaySubscriptions: String { l11d("stats.l11d.toPay.subscriptions") }
        static func pendingCount(_ count: Int) -> String { String(format: l11d("stats.l11d.toPay.pendingCount"), count) }
        static var budgetsTitle: String { l11d("stats.l11d.budgets.title") }
        /// «S/ 780 de S/ 1,000 · 78 %».
        static func budgetUsage(spent: String, limit: String, percent: String) -> String {
            String(format: l11d("stats.l11d.budgets.usage"), spent, limit, percent)
        }
        /// «78 %» con el formato del idioma de la app (el espacio antes del signo, o no, lo decide el idioma).
        static func percent(_ value: Double) -> String {
            (value / 100).formatted(.percent.precision(.fractionLength(0)).locale(AppLocale.current))
        }

        // MARK: - Un nombre para el resumen con IA (L11-8)

        /// El sustantivo del período dentro de un título: «Este mes» metido en «Tu %@ en pocas palabras» daba
        /// «Tu Este mes en pocas palabras». Mes pasado sigue siendo «tu mes»: el título habla del mes que se ve.
        private static func periodNoun(_ period: DetailPeriod) -> String {
            switch period {
            case .thisWeek: return "week"
            case .last7Days: return "days7"
            case .last30Days: return "days30"
            case .thisMonth, .lastMonth: return "month"
            case .thisYear, .lastYear: return "year"
            case .allTime: return "all"
            case .custom: return "period"
            }
        }

        /// «Tu mes en pocas palabras» (Tendencias).
        static func inAFewWords(_ period: DetailPeriod) -> String {
            l11d("stats.l11d.title.inAFewWords.\(periodNoun(period))")
        }

        /// «Tu mes de un vistazo» (Distribución).
        static func atAGlance(_ period: DetailPeriod) -> String {
            l11d("stats.l11d.title.atAGlance.\(periodNoun(period))")
        }

        // MARK: - Tendencias: una tarjeta de saldo y «Entradas y salidas» (L11-10)

        static var inAndOut: String { l11d("stats.l11d.trends.inAndOut") }

        /// «Ver el mes anterior», «Ver la semana anterior»… o «Ver el año anterior» si se compara con el año anterior.
        static func showPrevious(period: DetailPeriod, mode: ComparisonMode) -> String {
            if mode == .year { return l11d("stats.l11d.trends.showPrevious.year") }
            let noun: String
            switch period {
            case .thisWeek: noun = "week"
            case .last7Days: noun = "days7"
            case .last30Days: noun = "days30"
            case .thisMonth, .lastMonth: noun = "month"
            case .thisYear, .lastYear, .allTime, .custom: noun = "period"
            }
            return l11d("stats.l11d.trends.showPrevious.\(noun)")
        }

        // MARK: - Distribución del gasto por necesidad (L11-6)

        static var needPurpose: String { l11d("stats.l11d.need.purpose") }

        // MARK: - Informe por notificación de un período cerrado (L11-12)

        /// El período ya cerrado del que habla el semanal del lunes o el mensual del día 1.
        enum ClosedPeriod: Equatable {
            /// La semana de lunes a domingo que acaba de terminar.
            case lastWeek
            /// Un mes cerrado, con su nombre («septiembre»).
            case month(String)
        }

        /// «Así cerró tu saldo en septiembre: S/ 1.200 💰», «La semana pasada gastaste S/ 350 📊».
        static func closedReport(_ dataType: ReportDataType, _ closed: ClosedPeriod, value: String) -> String {
            switch closed {
            case .lastWeek:
                return String(format: l11d("notifications.report.closed.week.\(dataType.rawValue)"), value)
            case .month(let month):
                return String(format: l11d("notifications.report.closed.month.\(dataType.rawValue)"), month, value)
            }
        }

        /// «En septiembre no registraste gastos ✨».
        static func closedReportNoExpenses(_ closed: ClosedPeriod) -> String {
            switch closed {
            case .lastWeek: return l11d("notifications.report.closed.week.noExpenses")
            case .month(let month): return String(format: l11d("notifications.report.closed.month.noExpenses"), month)
            }
        }

        // MARK: - Lo que llegará (L11-12)

        /// «El lunes a las 9:00, con lo que gastaste del lunes 6 al domingo 12» · «El 1 de noviembre a las 9:00, con lo
        /// que gastaste en octubre». El saldo no es de un tramo sino de un día: «con tu saldo al domingo 12».
        static func upcomingLine(
            type: NotificationType,
            dataType: ReportDataType,
            upcoming: ReportUpcomingLogic.Upcoming,
            time: String
        ) -> String {
            if type == .monthlyReport {
                let when = dayAndMonth(of: upcoming.sendDate)
                let month = monthName(of: upcoming.interval.start)
                return String(format: l11d("notifications.upcoming.month.\(dataType.rawValue)"), when, time, month)
            }
            let when = weekdayName(of: upcoming.sendDate)
            let first = weekdayAndDay(of: upcoming.interval.start)
            let last = weekdayAndDay(of: upcoming.interval.end)
            if dataType == .balance {
                return String(format: l11d("notifications.upcoming.week.balance"), when, time, last)
            }
            return String(format: l11d("notifications.upcoming.week.\(dataType.rawValue)"), when, time, first, last)
        }
    }
}
