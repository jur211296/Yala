//
//  ScheduledPaymentDetailLogicTests.swift
//  YalaTests
//
//  Bugs de Pagos planificados medidos en el simulador (auditoría UX 2.2, lote 10): el historial con fechas que aún no
//  llegaron como «Vencido», el gasto vinculado que el detalle no veía, «Próxima fecha» tras saltar, la frecuencia que
//  decía «Mensual» a todo, la lista de «Vincular gasto» al revés y con transferencias, la fecha larga sin «de», el
//  primer vencimiento en la fecha de inicio y el pago pausado que descuadraba Pagado + Pendiente con el total.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct ScheduledPaymentDetailLogicTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour)) ?? .distantPast
    }

    /// Un pago mensual el día `day`: la fecha de cada mes.
    private func monthly(day: Int) -> (Date) -> [Date] {
        { month in
            let c = calendar.dateComponents([.year, .month], from: month)
            guard let d = calendar.date(from: DateComponents(year: c.year, month: c.month, day: day)) else { return [] }
            return [d]
        }
    }

    // MARK: - Historial y próximas

    @Test("Con el mes que viene elegido, la fecha de mañana no sale en el historial")
    func pastNeverIncludesFutureDates() {
        let today = date(2026, 10, 14, hour: 21)
        let past = ScheduledPaymentDetailLogic.pastOccurrences(
            selectedMonth: date(2026, 11, 1), today: today, calendar: calendar, datesInMonth: monthly(day: 15)
        )
        #expect(!past.contains(date(2026, 10, 15)))
        #expect(past.allSatisfy { $0 <= today })
        #expect(past.first == date(2026, 9, 15))
    }

    @Test("Las próximas empiezan mañana, mire el mes que mire la lista")
    func upcomingStartsAfterToday() {
        let today = date(2026, 10, 14, hour: 21)
        let upcoming = ScheduledPaymentDetailLogic.upcomingOccurrences(
            today: today, calendar: calendar, datesInMonth: monthly(day: 15)
        )
        #expect(upcoming == [date(2026, 10, 15), date(2026, 11, 15), date(2026, 12, 15)])
    }

    @Test("La fecha de hoy es historial, no próxima")
    func todayIsPast() {
        let today = date(2026, 10, 15, hour: 9)
        let past = ScheduledPaymentDetailLogic.pastOccurrences(
            selectedMonth: today, today: today, calendar: calendar, datesInMonth: monthly(day: 15)
        )
        let upcoming = ScheduledPaymentDetailLogic.upcomingOccurrences(
            today: today, calendar: calendar, datesInMonth: monthly(day: 15)
        )
        #expect(past.first == date(2026, 10, 15))
        #expect(upcoming.first == date(2026, 11, 15))
    }

    // MARK: - Gastos vinculados

    @Test("Un gasto del 4 vinculado al pago del 15 lo cubre, como en la lista (mismo mes)")
    func linkedSameMonth() {
        let occurrences = [date(2026, 10, 15), date(2026, 11, 15)]
        let matches = ScheduledPaymentDetailLogic.linkedOccurrences(
            occurrences: occurrences, linkedDates: [date(2026, 10, 4, hour: 12)], calendar: calendar
        )
        #expect(matches == [0: 0])
    }

    @Test("Un gasto de otro mes no cubre la fecha (la lista lo cuenta en su mes)")
    func linkedOtherMonth() {
        let matches = ScheduledPaymentDetailLogic.linkedOccurrences(
            occurrences: [date(2026, 10, 1)], linkedDates: [date(2026, 9, 17)], calendar: calendar
        )
        #expect(matches.isEmpty)
    }

    @Test("Semanal: el pago adelantado el miércoles cubre el lunes siguiente, no se pierde")
    func linkedWeeklyInOrder() {
        // Lunes 5 y 12 de octubre; gastos el 5 (el suyo) y el 7 (adelantado para el 12).
        let occurrences = [date(2026, 10, 12), date(2026, 10, 5)]
        let matches = ScheduledPaymentDetailLogic.linkedOccurrences(
            occurrences: occurrences, linkedDates: [date(2026, 10, 7), date(2026, 10, 5)], calendar: calendar
        )
        #expect(matches == [1: 1, 0: 0])
    }

    @Test("Una fecha saltada no consume un gasto")
    func linkedSkipsSkipped() {
        let occurrences = [date(2026, 10, 5), date(2026, 10, 12)]
        let matches = ScheduledPaymentDetailLogic.linkedOccurrences(
            occurrences: occurrences, linkedDates: [date(2026, 10, 13)],
            isSkipped: { $0 == date(2026, 10, 5) }, calendar: calendar
        )
        #expect(matches == [1: 0])
    }

    // MARK: - Próxima fecha

    @Test("Tras saltar la próxima, «Próxima fecha» pasa a la siguiente")
    func nextDateSkipsSkippedAndPaid() {
        let upcoming = [date(2026, 10, 22), date(2026, 11, 22), date(2026, 12, 22)]
        let skipped = ScheduledPaymentDetailLogic.nextDate(
            upcoming: upcoming, isSkipped: { $0 == date(2026, 10, 22) }, isPaid: { _ in false }, fallback: upcoming[0]
        )
        #expect(skipped == date(2026, 11, 22))
        let none = ScheduledPaymentDetailLogic.nextDate(
            upcoming: [], isSkipped: { _ in false }, isPaid: { _ in false }, fallback: upcoming[2]
        )
        #expect(none == upcoming[2])
    }

    @Test("«Próxima fecha» sale de nextDueDate: un pago vencido y sin pagar la mantiene")
    func nextDateFromDueDate() {
        let next = ScheduledPaymentDetailLogic.nextDate(
            nextDueDate: date(2026, 10, 1), linkedDates: [], isSkipped: { _ in false }, calendar: calendar,
            datesInMonth: monthly(day: 1)
        )
        #expect(next == date(2026, 10, 1))
    }

    @Test("«Próxima fecha» salta la fecha saltada y la pagada")
    func nextDateSkipsSkippedAndLinked() {
        let skipped = ScheduledPaymentDetailLogic.nextDate(
            nextDueDate: date(2026, 10, 22), linkedDates: [], isSkipped: { $0 == date(2026, 10, 22) }, calendar: calendar,
            datesInMonth: monthly(day: 22)
        )
        #expect(skipped == date(2026, 11, 22))
        let paid = ScheduledPaymentDetailLogic.nextDate(
            nextDueDate: date(2026, 10, 5), linkedDates: [date(2026, 10, 5, hour: 10)], isSkipped: { _ in false },
            calendar: calendar, datesInMonth: monthly(day: 5)
        )
        #expect(paid == date(2026, 11, 5))
    }

    // MARK: - Frecuencia

    @Test("«Una sola vez» no se rotula «Mensual», y cada 2 meses tampoco")
    func frequencyText() {
        let once = ScheduledPaymentDetailLogic.frequencyText(isRecurring: false, recurrenceType: "monthly", interval: 1)
        #expect(once == L10n.Scheduled.Editor.onetime)
        let monthly = ScheduledPaymentDetailLogic.frequencyText(isRecurring: true, recurrenceType: "monthly", interval: 1)
        #expect(monthly == RecurrenceType.monthly.localizedName)
        let everyTwo = ScheduledPaymentDetailLogic.frequencyText(isRecurring: true, recurrenceType: "monthly", interval: 2)
        #expect(everyTwo == L10n.Scheduled.Frequency.every(2, .monthly))
        #expect(everyTwo != monthly)
        #expect(everyTwo.contains("2"))
        for type in RecurrenceType.allCases {
            let text = L10n.Scheduled.Frequency.every(3, type)
            #expect(!text.hasPrefix("scheduled."), "Clave sin traducir: \(text)")
        }
    }

    // MARK: - Candidatos de «Vincular gasto»

    @Test("Ni transferencias ni ajustes de saldo; gasto con gasto e ingreso con ingreso")
    func linkCandidates() {
        #expect(ScheduledPaymentDetailLogic.isLinkCandidate(adjustmentType: nil, categoryIsIncome: false, paymentIsIncome: false))
        #expect(!ScheduledPaymentDetailLogic.isLinkCandidate(
            adjustmentType: TransactionItem.adjustmentTypeTransfer, categoryIsIncome: nil, paymentIsIncome: false
        ))
        #expect(!ScheduledPaymentDetailLogic.isLinkCandidate(adjustmentType: "initial_balance", categoryIsIncome: nil, paymentIsIncome: false))
        #expect(!ScheduledPaymentDetailLogic.isLinkCandidate(adjustmentType: nil, categoryIsIncome: true, paymentIsIncome: false))
        #expect(ScheduledPaymentDetailLogic.isLinkCandidate(adjustmentType: nil, categoryIsIncome: true, paymentIsIncome: true))
    }

    @Test("El gasto de S/ 60 queda más cerca de un pago de S/ 60 que uno de S/ 9")
    func amountDistanceComparesMagnitudes() {
        let exact = ScheduledPaymentDetailLogic.amountDistance(transactionAmount: -60, paymentAmount: 60)
        let small = ScheduledPaymentDetailLogic.amountDistance(transactionAmount: -9, paymentAmount: 60)
        #expect(exact == 0)
        #expect(exact < small)
    }

    // MARK: - Fechas en el idioma de la app

    @Test("La fecha larga en español lleva «de» y el mes con año solo la primera mayúscula")
    func spanishDates() {
        let es = Locale(identifier: "es_PE")
        let d = date(2026, 10, 14, hour: 12)
        let full = ScheduledPaymentDateText.full(d, locale: es)
        #expect(full.contains("14 de octubre de 2026"), "\(full)")
        #expect(ScheduledPaymentDateText.monthYear(d, locale: es) == "Octubre de 2026")
    }

    @Test("Con la app en inglés las fechas salen en inglés, aunque el sistema esté en español")
    func englishDates() {
        let en = Locale(identifier: "en_US")
        let d = date(2026, 10, 14, hour: 12)
        #expect(ScheduledPaymentDateText.full(d, locale: en).contains("October"))
        #expect(ScheduledPaymentDateText.monthAbbreviation(d, locale: en) == "OCT")
    }

    @Test("El día va sin «日» en japonés y chino (cabe en su columna)")
    func dayWithoutSuffix() {
        let d = date(2026, 10, 14, hour: 12)
        #expect(ScheduledPaymentDateText.day(d, locale: Locale(identifier: "ja_JP")) == "14")
        #expect(ScheduledPaymentDateText.day(d, locale: Locale(identifier: "zh_Hans_CN")) == "14")
    }

    // MARK: - Primer vencimiento

    @Test("Un pago «cada mes, día 1» creado el 14 vence el 1 del mes que viene, no el 14")
    func firstDueDateMonthly() {
        let due = ScheduledPaymentEditorViewModel.firstDueDate(
            start: date(2026, 10, 14), recurrenceType: .monthly, recurrenceInterval: 1, dayOfMonth: 1,
            weekdays: "", yearlyMonth: nil, yearlyDay: nil, endDate: nil, calendar: calendar
        )
        #expect(due == date(2026, 11, 1))
    }

    @Test("Si la fecha de inicio ya es una fecha del pago, se queda")
    func firstDueDateOnStart() {
        let due = ScheduledPaymentEditorViewModel.firstDueDate(
            start: date(2026, 10, 14), recurrenceType: .monthly, recurrenceInterval: 1, dayOfMonth: 14,
            weekdays: "", yearlyMonth: nil, yearlyDay: nil, endDate: nil, calendar: calendar
        )
        #expect(due == date(2026, 10, 14))
    }

    @Test("Semanal los lunes desde un miércoles: el lunes siguiente")
    func firstDueDateWeekly() {
        // 14-oct-2026 es miércoles; lunes = 2.
        let due = ScheduledPaymentEditorViewModel.firstDueDate(
            start: date(2026, 10, 14), recurrenceType: .weekly, recurrenceInterval: 1, dayOfMonth: nil,
            weekdays: "2", yearlyMonth: nil, yearlyDay: nil, endDate: nil, calendar: calendar
        )
        #expect(due == date(2026, 10, 19))
    }

    @Test("Anual el 3 de marzo desde octubre: el 3 de marzo del año que viene")
    func firstDueDateYearly() {
        let due = ScheduledPaymentEditorViewModel.firstDueDate(
            start: date(2026, 10, 14), recurrenceType: .yearly, recurrenceInterval: 1, dayOfMonth: nil,
            weekdays: "", yearlyMonth: 3, yearlyDay: 3, endDate: nil, calendar: calendar
        )
        #expect(due == date(2027, 3, 3))
    }

    @Test("firstOccurrence usa la fecha de inicio como límite aunque el pago se creara antes")
    func firstOccurrenceBoundsByStart() {
        // Pago mensual del día 1, creado en septiembre; se edita con inicio el 14 de octubre: el 1 de octubre ya no vale.
        let params = ScheduledPaymentDateCalculator.PaymentParams(
            isRecurring: true, recurrenceType: "monthly", recurrenceInterval: 1, nextDueDate: date(2026, 10, 14),
            createdAt: date(2026, 9, 1), endDate: nil, dayOfMonth: 1, selectedWeekdays: nil, yearlyMonth: nil, yearlyDay: nil
        )
        let first = ScheduledPaymentDateCalculator.firstOccurrence(onOrAfter: date(2026, 10, 14), params: params, calendar: calendar)
        #expect(first == date(2026, 11, 1))
    }

    @Test("Con una fecha de fin anterior a cualquier fecha del pago, se queda la de inicio")
    func firstDueDateEndBeforeAny() {
        let due = ScheduledPaymentEditorViewModel.firstDueDate(
            start: date(2026, 10, 14), recurrenceType: .monthly, recurrenceInterval: 1, dayOfMonth: 1,
            weekdays: "", yearlyMonth: nil, yearlyDay: nil, endDate: date(2026, 10, 20), calendar: calendar
        )
        #expect(due == date(2026, 10, 14))
    }

    // MARK: - Totales del mes

    @Test("Un pago de una sola vez ya pagado (inactivo) sigue en Pagado y en el total")
    func completedOneOffStaysPaid() {
        let vm = ScheduledPaymentsViewModel()
        let now = Date()
        let done = ScheduledPayment(name: "Matrícula", amount: 350, currencyCode: "PEN", transactionType: "expense",
                                    isRecurring: false, nextDueDate: now, isActive: false)
        var paidSummary = ScheduledPaymentSummary(payment: done, dueDate: now, dueStatus: .past, daysUntilDue: 0,
                                                  icon: "creditcard", color: "#000000")
        paidSummary.isPaidForMonth = true
        vm.selectedMonth = now
        vm.groupedPayments = [(status: .past, payments: [paidSummary])]
        #expect(vm.monthlyTotalPaid(preferredCurrencyCode: "PEN") == 350)
        #expect(vm.monthlyTotalPending(preferredCurrencyCode: "PEN") == 0)
    }

    @Test("Un pago pausado no cuenta en Pendiente, igual que en el total del mes")
    func pausedPaymentIsNotPending() {
        let vm = ScheduledPaymentsViewModel()
        let now = Date()
        let active = ScheduledPayment(name: "Activo", amount: 100, currencyCode: "PEN", transactionType: "expense",
                                      isRecurring: false, nextDueDate: now)
        let paused = ScheduledPayment(name: "Pausado", amount: 45, currencyCode: "PEN", transactionType: "expense",
                                      isRecurring: false, nextDueDate: now, isActive: false)
        func summary(_ p: ScheduledPayment) -> ScheduledPaymentSummary {
            ScheduledPaymentSummary(payment: p, dueDate: now, dueStatus: .upcoming, daysUntilDue: 0,
                                    icon: "creditcard", color: "#000000")
        }
        vm.selectedMonth = now
        vm.groupedPayments = [(status: .upcoming, payments: [summary(active), summary(paused)])]
        let total = vm.calculateMonthlyTotal(subscriptions: [active, paused], for: now, preferredCurrencyCode: "PEN")
        let paid = vm.monthlyTotalPaid(preferredCurrencyCode: "PEN")
        let pending = vm.monthlyTotalPending(preferredCurrencyCode: "PEN")
        #expect(pending == 100)
        #expect(paid + pending == total)
    }
}

/// Cableado de los arreglos en las vistas (source-scan): lo que no se puede llamar desde un test.
struct ScheduledPaymentWiringTests {

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Sin líneas de comentario: documentar lo que el test prohíbe no puede ponerlo en rojo.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("La fila, el detalle, Ajustes y el flujo de caja nombran la frecuencia con la misma regla")
    func frequencyIsShared() throws {
        for path in ["Yala/App/Views/Planning/ScheduledPaymentRowView.swift",
                     "Yala/App/Views/Planning/ScheduledPaymentDetailView.swift",
                     "Yala/App/Views/Settings/ScheduledPaymentsSettingsView.swift",
                     "Yala/App/Views/Reports/CashFlow/CashFlowAddLineSheet.swift"] {
            let code = Self.codeOnly(try Self.source(path))
            #expect(code.contains("ScheduledPaymentDetailLogic.frequencyText("), "\(path)")
            #expect(!code.contains("localizedNamePlural"), "\(path)")
        }
    }

    @Test("El detalle no formatea fechas con el idioma del sistema ni busca el gasto a ±7 días")
    func detailUsesSharedDatesAndWindow() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Planning/ScheduledPaymentDetailView.swift"))
        #expect(!code.contains("DateFormatter()"))
        #expect(!code.contains("EEEE, d MMMM yyyy"))
        #expect(code.contains("ScheduledPaymentDetailLogic.linkedOccurrences("))
        #expect(code.contains("ScheduledPaymentDetailLogic.nextDate("))
        #expect(code.contains("value: formatDate(nextDate)"))
    }

    @Test("El interruptor del editor dice «Activo» y el ✓ apagado dice lo que falta")
    func editorCopy() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Planning/ScheduledPaymentEditorView.swift"))
        #expect(!code.contains("\"common.active\""))
        #expect(code.contains("Text(L10n.Scheduled.Editor.active)"))
        #expect(!code.contains(".accessibilityHint(!canSave ? L10n.Accessibility.createAccountFirst"))
        #expect(code.contains("disabledHint: saveMissingHint"))
    }

    @Test("El aviso con un día de antelación dice «Mañana»")
    func tomorrowNotification() throws {
        let code = Self.codeOnly(try Self.source("Yala/Services/ScheduledPaymentNotificationService.swift"))
        #expect(code.contains("case .dueSoon(let days) where days == 1:"))
        #expect(code.contains("L10n.Notifications.ScheduledPayment.dueTomorrow(payment.name, formattedAmount)"))
        #expect(code.contains("L10n.Notifications.ScheduledPayment.dueTomorrowIncome(formattedAmount, payment.name)"))
    }

    @Test("El editor guarda como primer vencimiento la primera fecha del pago, no la de inicio")
    func editorSavesFirstOccurrence() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/ViewModels/ScheduledPaymentEditorViewModel.swift"))
        #expect(code.contains("existingPayment.nextDueDate = dueDate"))
        #expect(code.contains("nextDueDate: dueDate,"))
        #expect(!code.contains("nextDueDate = paymentDate"))
    }

    @Test("Con pagos en otros meses, el mes vacío dice «Sin pagos este mes»")
    func monthEmptyState() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Planning/ScheduledPaymentsListView.swift"))
        #expect(code.contains("if payments.isEmpty {"))
        #expect(code.contains("} else if !viewModel.groupedPayments.isEmpty {"))
        #expect(code.contains("\"scheduled.filter.empty\""))
        #expect(code.contains("\"scheduled.calendar.month.empty\""))
        #expect(code.contains("subscriptions: payments,"))
    }

    @Test("«Vincular gasto» excluye transferencias y ordena por magnitud del importe")
    func associationCandidates() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/ViewModels/ScheduledPaymentsViewModel.swift"))
        #expect(code.contains("ScheduledPaymentDetailLogic.isLinkCandidate("))
        #expect(code.contains("ScheduledPaymentDetailLogic.amountDistance(transactionAmount: tx1.amount"))
        #expect(code.contains("summary.isPaidForMonth || summary.payment.isActive,"))
        #expect(code.contains("} else if !isSkipped && payment.isActive {"))
    }
}
