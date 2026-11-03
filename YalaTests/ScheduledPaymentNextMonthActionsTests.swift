//
//  ScheduledPaymentNextMonthActionsTests.swift
//  YalaTests
//
//  Card 3zva (Jürgen, 2026-11-01): en el detalle de un pago con el mes en curso ya pagado, «Ya lo pagué» y «Saltar este
//  mes» no decían que eran de la próxima fecha. Ahora un encabezado «Próximo: diciembre de 2026» va encima y los botones
//  nombran el mes («Ya pagué diciembre») o, si ese mes tiene varias fechas, la fecha. Con el mes en curso sin pagar, todo
//  sigue igual. Aquí: la regla de cuándo y cómo se nombra, los textos del mes en cada idioma y que la fecha a la que
//  apuntan las acciones es la misma que leen la Bandeja y el widget de pagos (`nextDueDate`).
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct ScheduledPaymentNextMonthActionsTests {

    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    /// «Google Workspace Yala»: 17,99 al mes, el día 1 (el caso de la captura de Jürgen).
    private func monthlyOnTheFirst(nextDueDate: Date) -> ScheduledPayment {
        let payment = ScheduledPayment(
            name: "Google Workspace Yala", amount: 17.99, currencyCode: "USD", isRecurring: true,
            recurrenceType: "monthly", nextDueDate: nextDueDate, dayOfMonth: 1, paymentCategory: "subscription"
        )
        payment.createdAt = date(2026, 1, 1)
        return payment
    }

    private func datesInMonth(_ payment: ScheduledPayment) -> (Date) -> [Date] {
        { month in ScheduledPaymentDateCalculator.paymentDatesInMonth(params: payment.dateCalculatorParams, month: month) }
    }

    // MARK: - Cuándo se nombra

    @Test("Con noviembre pagado, las acciones son de diciembre y se nombra el mes")
    func settledMonth_targetsTheNextMonth() {
        let target = ScheduledPaymentDetailLogic.actionTarget(
            currentMonthSettled: true, nextDate: date(2026, 12, 1), datesInNextDateMonth: 1
        )
        #expect(target == .nextMonth(date(2026, 12, 1)))
    }

    @Test("Con el mes en curso sin pagar, todo sigue como antes")
    func unsettledMonth_keepsTheUsualTexts() {
        let target = ScheduledPaymentDetailLogic.actionTarget(
            currentMonthSettled: false, nextDate: date(2026, 11, 1), datesInNextDateMonth: 1
        )
        #expect(target == .current)
    }

    @Test("Si el mes de la próxima fecha tiene varias (semanal), se nombra la fecha: saltar quita una sola")
    func severalDatesInThatMonth_namesTheDate() {
        let target = ScheduledPaymentDetailLogic.actionTarget(
            currentMonthSettled: true, nextDate: date(2026, 12, 7), datesInNextDateMonth: 5
        )
        #expect(target == .nextDate(date(2026, 12, 7)))
    }

    @Test("El mes en curso está hecho solo si todas sus fechas se pagaron o saltaron y la próxima es de otro mes")
    func currentMonthSettled_rule() {
        let now = date(2026, 11, 3, hour: 9)
        let november = [date(2026, 11, 1)]
        let december = date(2026, 12, 1)
        func settled(dates: [Date]? = nil, next: Date? = nil, recurring: Bool = true,
                     active: Bool = true, covered: Bool = true) -> Bool {
            ScheduledPaymentDetailLogic.currentMonthSettled(
                isRecurring: recurring, isActive: active, datesThisMonth: dates ?? november, nextDate: next ?? december,
                now: now,
                calendar: calendar, isCovered: { _ in covered }
            )
        }
        #expect(settled())
        #expect(!settled(covered: false), "Noviembre sin pagar: no está hecho")
        #expect(!settled(next: date(2026, 11, 15)), "La próxima es de este mes: las acciones son de noviembre")
        #expect(!settled(dates: []), "Sin fechas este mes no hay nada hecho")
        #expect(!settled(recurring: false), "Un pago de una sola vez no tiene «mes en curso»")
        #expect(!settled(active: false), "Pausado o terminado, tampoco")
    }

    // MARK: - El mes, dentro de una frase

    @Test("El mes va en minúscula en español, con su año en el encabezado, y en mayúscula en inglés")
    func monthNames() {
        let december = date(2026, 12, 1, hour: 12)
        #expect(ScheduledPaymentDateText.monthName(december, locale: Locale(identifier: "es_PE")) == "diciembre")
        #expect(ScheduledPaymentDateText.monthYearInline(december, locale: Locale(identifier: "es_PE")) == "diciembre de 2026")
        #expect(ScheduledPaymentDateText.monthName(december, locale: Locale(identifier: "en_US")) == "December")
        #expect(ScheduledPaymentDateText.monthName(december, locale: Locale(identifier: "de_DE")) == "Dezember")
        // `es_PE` da el mes autónomo en mayúscula aunque se pida en mitad de frase: aquí se baja.
        for id in ["es_ES", "es_AR", "es_419", "pt_BR", "pt_PT", "fr_FR", "it_IT", "nl_NL"] {
            let name = ScheduledPaymentDateText.monthName(december, locale: Locale(identifier: id))
            #expect(name.first?.isLowercase == true, "\(id): \(name)")
        }
    }

    @Test("En polaco el mes sale en nominativo («grudzień»), que es la forma que piden «Pomiń» y «za»")
    func polishMonthIsNominative() {
        let december = date(2026, 12, 1, hour: 12)
        #expect(ScheduledPaymentDateText.monthName(december, locale: Locale(identifier: "pl_PL")) == "grudzień")
    }

    // MARK: - La Bandeja y el widget dicen el mismo mes

    /// Pagar noviembre («Ya lo apunté», «Apuntarlo ahora» o aprobar el borrador) avanza `nextDueDate`, que es lo que leen
    /// la Bandeja (crea el borrador cuando `nextDueDate <= hoy`) y el widget de pagos. El detalle calcula su «próxima» con
    /// los gastos vinculados. Las dos tienen que dar diciembre, o el detalle y la Bandeja hablarían de meses distintos.
    @Test("Tras pagar noviembre, el detalle, la Bandeja y el widget apuntan al 1 de diciembre")
    func afterPayingNovember_detailInboxAndWidgetAgree() {
        let payment = monthlyOnTheFirst(nextDueDate: date(2026, 11, 1))
        let paidNovember = [date(2026, 11, 1, hour: 10)]

        // Lo que pinta el detalle, antes y después de que el puntero avance.
        let detailBefore = ScheduledPaymentDetailLogic.nextDate(
            nextDueDate: payment.nextDueDate, linkedDates: paidNovember, isSkipped: { _ in false },
            datesInMonth: datesInMonth(payment)
        )
        payment.lastPaidDate = paidNovember[0]
        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)
        let detailAfter = ScheduledPaymentDetailLogic.nextDate(
            nextDueDate: payment.nextDueDate, linkedDates: paidNovember, isSkipped: { _ in false },
            datesInMonth: datesInMonth(payment)
        )

        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: date(2026, 12, 1)), "Bandeja y widget leen este puntero")
        #expect(calendar.isDate(detailBefore, inSameDayAs: payment.nextDueDate))
        #expect(calendar.isDate(detailAfter, inSameDayAs: payment.nextDueDate))

        // Y el detalle lo nombra: «Ya pagué diciembre».
        let now = date(2026, 11, 3, hour: 9)
        let settled = ScheduledPaymentDetailLogic.currentMonthSettled(
            isRecurring: true, isActive: payment.isActive, datesThisMonth: datesInMonth(payment)(now),
            nextDate: detailAfter, now: now, isCovered: { _ in true }
        )
        let target = ScheduledPaymentDetailLogic.actionTarget(
            currentMonthSettled: settled, nextDate: detailAfter,
            datesInNextDateMonth: datesInMonth(payment)(detailAfter).count
        )
        #expect(target == .nextMonth(detailAfter))
    }
}

/// Cableado del detalle (source-scan): la vista no se puede llamar desde un test.
struct ScheduledPaymentNextMonthActionsWiringTests {

    private static func codeOnly(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("Los botones, la ayuda y el encabezado salen de la regla, no de los textos fijos")
    func detailUsesTheTarget() throws {
        let view = try Self.codeOnly("Yala/App/Views/Planning/ScheduledPaymentDetailView.swift")
        #expect(view.contains("let target = actionTarget(for: date)"))
        #expect(view.contains("filledButton(paidTitle(target), identifier: \"scheduled_detail_paid_button\")"))
        #expect(view.contains("glassButton(skipTitle(target), identifier: \"scheduled_detail_skip_button\")"))
        #expect(view.contains("Text(skipHelp(target))"))
        #expect(view.contains("if target != .current {\n                    nextTargetHeader(target)"))
        #expect(view.contains(".accessibilityIdentifier(\"scheduled_detail_next_target\")"))
        // El mes en curso, con su regla pura y no a mano en la vista.
        #expect(view.contains("ScheduledPaymentDetailLogic.currentMonthSettled("))
    }
}
