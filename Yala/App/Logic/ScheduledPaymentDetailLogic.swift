//
//  ScheduledPaymentDetailLogic.swift
//  Yala
//
//  Reglas puras del detalle de un pago planificado y de su lista (auditoría UX 2.2, lote 10), separadas de la vista
//  para poder probarlas:
//
//  - **Qué fechas son historial y cuáles próximas.** El historial son las fechas que ya llegaron; las próximas, las
//    que no. Antes las dos se anclaban en el mes elegido en la lista: con «Próximo mes» elegido, el pago de mañana
//    salía en el historial como «Vencido» y faltaba en «Próximos».
//  - **Qué fecha cubre cada gasto vinculado.** La misma regla que la lista: dentro de cada mes, por orden. El detalle
//    buscaba a ±7 días y un gasto vinculado a 11 no salía nunca como pagado, mientras la lista sí lo contaba.
//  - **La próxima fecha** es la primera que no se saltó ni se pagó. Tras «Saltar», «Próxima fecha» seguía diciendo la
//    fecha saltada.
//  - **Cómo se nombra la frecuencia.** «Una sola vez», «Mensual» o «Cada 2 meses». La fila decía «Mensual» a un pago
//    de una sola vez y a uno de cada dos meses, y Ajustes decía «2 Meses».
//

import Foundation

enum ScheduledPaymentDetailLogic {

    /// Ventana, en días a cada lado de una fecha, en la que «Vincular gasto» ofrece registros
    /// (`fetchCandidateTransactions`).
    static let linkWindowDays = 15

    // MARK: - Historial y próximas

    /// Fechas que ya llegaron, de la más reciente a la más vieja: las del mes elegido (o del mes en curso, si el elegido
    /// es futuro) y las de los tres meses anteriores, hasta `limit`.
    static func pastOccurrences(
        selectedMonth: Date,
        today: Date,
        limit: Int = 10,
        calendar: Calendar = .current,
        datesInMonth: (Date) -> [Date]
    ) -> [Date] {
        let todayStart = calendar.startOfDay(for: today)
        let anchor = min(calendar.startOfMonth(for: selectedMonth), calendar.startOfMonth(for: todayStart))
        var dates: [Date] = []
        for offset in 0...3 {
            guard let month = calendar.date(byAdding: .month, value: -offset, to: anchor) else { continue }
            dates.append(contentsOf: datesInMonth(month))
        }
        let past = Set(dates.filter { calendar.startOfDay(for: $0) <= todayStart })
        return Array(past.sorted(by: >).prefix(limit))
    }

    /// Las próximas `count` fechas a partir de mañana, mirando hasta `monthsAhead` meses desde el mes en curso.
    static func upcomingOccurrences(
        today: Date,
        count: Int = 3,
        monthsAhead: Int = 12,
        calendar: Calendar = .current,
        datesInMonth: (Date) -> [Date]
    ) -> [Date] {
        let todayStart = calendar.startOfDay(for: today)
        let currentMonth = calendar.startOfMonth(for: todayStart)
        var dates: [Date] = []
        for offset in 0...monthsAhead {
            guard let month = calendar.date(byAdding: .month, value: offset, to: currentMonth) else { continue }
            dates.append(contentsOf: datesInMonth(month).filter { calendar.startOfDay(for: $0) > todayStart })
            if dates.count >= count { break }
        }
        return Array(Set(dates).sorted().prefix(count))
    }

    // MARK: - Gastos vinculados

    /// Qué gasto cubre cada fecha: `[índice de la fecha en occurrences: índice del gasto en linkedDates]`. La regla de la
    /// lista (`calculatePaymentData` + `ScheduledPaymentPaidStatusHelper`): dentro de cada mes, los gastos del mes cubren
    /// las fechas del mes por orden, saltándose las fechas saltadas. Así el detalle y la lista dicen lo mismo; con la
    /// regla de cercanía a ±7 días, un gasto del día 4 vinculado al 15 contaba en la lista y no en el detalle.
    static func linkedOccurrences(
        occurrences: [Date],
        linkedDates: [Date],
        isSkipped: (Date) -> Bool = { _ in false },
        calendar: Calendar = .current
    ) -> [Int: Int] {
        func monthKey(_ date: Date) -> Int {
            let c = calendar.dateComponents([.year, .month], from: date)
            return (c.year ?? 0) * 100 + (c.month ?? 0)
        }
        let occurrencesByMonth = Dictionary(grouping: occurrences.indices) { monthKey(occurrences[$0]) }
        let linkedByMonth = Dictionary(grouping: linkedDates.indices) { monthKey(linkedDates[$0]) }
        var result: [Int: Int] = [:]
        for (month, occIndices) in occurrencesByMonth {
            var queue = (linkedByMonth[month] ?? []).sorted { linkedDates[$0] < linkedDates[$1] }
            for occIndex in occIndices.sorted(by: { occurrences[$0] < occurrences[$1] }) {
                guard !queue.isEmpty, !isSkipped(occurrences[occIndex]) else { continue }
                result[occIndex] = queue.removeFirst()
            }
        }
        return result
    }

    // MARK: - Próxima fecha

    /// La primera de `upcoming` que no está saltada ni pagada; si todas lo están (o no hay), `fallback`.
    static func nextDate(
        upcoming: [Date],
        isSkipped: (Date) -> Bool,
        isPaid: (Date) -> Bool,
        fallback: Date
    ) -> Date {
        upcoming.first { !isSkipped($0) && !isPaid($0) } ?? fallback
    }

    /// La próxima fecha que toca de verdad, desde `nextDueDate` (que puede estar vencida y sin pagar): la primera del
    /// calendario del pago que no se saltó ni se pagó. No depende del mes elegido en la lista.
    static func nextDate(
        nextDueDate: Date,
        linkedDates: [Date],
        isSkipped: (Date) -> Bool,
        monthsAhead: Int = 13,
        calendar: Calendar = .current,
        datesInMonth: (Date) -> [Date]
    ) -> Date {
        let from = calendar.startOfDay(for: nextDueDate)
        let firstMonth = calendar.startOfMonth(for: from)
        var all: [Date] = []
        for offset in 0...monthsAhead {
            guard let month = calendar.date(byAdding: .month, value: offset, to: firstMonth) else { continue }
            all.append(contentsOf: datesInMonth(month))
        }
        all = Array(Set(all)).sorted()
        let paid = Set(linkedOccurrences(occurrences: all, linkedDates: linkedDates, isSkipped: isSkipped, calendar: calendar).keys)
        let candidates = all.indices.filter { all[$0] >= from }
        guard let next = candidates.first(where: { !isSkipped(all[$0]) && !paid.contains($0) }) else { return nextDueDate }
        return all[next]
    }

    // MARK: - Frecuencia

    /// «Una sola vez», el nombre del tipo («Mensual») o «Cada 2 meses».
    static func frequencyText(isRecurring: Bool, recurrenceType: String, interval: Int) -> String {
        guard isRecurring else { return L10n.Scheduled.Editor.onetime }
        let type = RecurrenceType(rawValue: recurrenceType) ?? .monthly
        guard interval > 1 else { return type.localizedName }
        return L10n.Scheduled.Frequency.every(interval, type)
    }

    // MARK: - Candidatos de «Vincular gasto»

    /// `true` si un registro puede cubrir el pago: ni transferencia ni ajuste de saldo, y del mismo tipo (gasto con gasto,
    /// ingreso con ingreso).
    static func isLinkCandidate(adjustmentType: String?, categoryIsIncome: Bool?, paymentIsIncome: Bool) -> Bool {
        adjustmentType == nil && (categoryIsIncome ?? false) == paymentIsIncome
    }

    /// Diferencia de importe para ordenar candidatos: compara magnitudes, porque el gasto se guarda en negativo y el
    /// pago en positivo. Comparando con signo, el gasto de S/ 60 quedaba detrás de todos los pequeños.
    static func amountDistance(transactionAmount: Double, paymentAmount: Double) -> Double {
        abs(abs(transactionAmount) - abs(paymentAmount))
    }
}

// MARK: - Fechas en el idioma de la app

/// Fechas de Pagos planificados en el idioma de la app (`AppLocale`), no en el del sistema. Por llamada y no
/// `static let`: el idioma se cambia en caliente dentro de la app y un formatter guardado se quedaba con el anterior.
enum ScheduledPaymentDateText {

    /// «miércoles, 14 de octubre de 2026». El formato fijo `EEEE, d MMMM yyyy` daba «14 octubre 2026», sin «de».
    static func full(_ date: Date, locale: Locale = AppLocale.current) -> String {
        formatter(template: "EEEEdMMMMyyyy", locale: locale).string(from: date)
    }

    /// «14 oct 2026».
    static func medium(_ date: Date, locale: Locale = AppLocale.current) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    /// «14». Formato fijo y no plantilla: en japonés y chino la plantilla da «14日», que no cabe en la columna del día y
    /// repite el «月» del mes de debajo.
    static func day(_ date: Date, locale: Locale = AppLocale.current) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "d"
        return f.string(from: date)
    }

    /// «OCT».
    static func monthAbbreviation(_ date: Date, locale: Locale = AppLocale.current) -> String {
        formatter(template: "MMM", locale: locale).string(from: date).uppercased(with: locale)
    }

    /// «Octubre de 2026»: mayúscula solo en la primera letra (`capitalized` la ponía en cada palabra).
    static func monthYear(_ date: Date, locale: Locale = AppLocale.current) -> String {
        formatter(template: "MMMMyyyy", locale: locale).string(from: date).capitalizingFirstLetter(locale: locale)
    }

    private static func formatter(template: String, locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }
}
