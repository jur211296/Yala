//
//  UXAudit22Lote10ScheduledTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 10 (pagos planificados): secciones y estado de cada fecha (L10-1, L10-3, L10-8), qué es un
//  pago pausado y cómo se reanuda (L10-7), las cifras de la cabecera (L10-2), los enlaces de los avisos (L10-13,
//  L10-14) y el borrado con «Deshacer» (L10-15).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Lógica pura

struct ScheduledPaymentListLogicTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: Pausado o terminado (L10-7)

    @Test func activePayment_isNeitherPausedNorFinished() {
        #expect(!ScheduledPaymentListLogic.isFinished(isActive: true, isRecurring: true, lastPaidDate: nil, nextDueDate: .now, endDate: nil))
        #expect(!ScheduledPaymentListLogic.isPaused(isActive: true, isRecurring: true, lastPaidDate: nil, nextDueDate: .now, endDate: nil))
    }

    @Test func inactiveOneTimeThatWasPaid_isFinished_notPaused() {
        let paid = date(2026, 10, 1)
        #expect(ScheduledPaymentListLogic.isFinished(isActive: false, isRecurring: false, lastPaidDate: paid, nextDueDate: paid, endDate: nil))
        #expect(!ScheduledPaymentListLogic.isPaused(isActive: false, isRecurring: false, lastPaidDate: paid, nextDueDate: paid, endDate: nil))
    }

    @Test func inactiveOneTimeNeverPaid_isPaused() {
        #expect(ScheduledPaymentListLogic.isPaused(isActive: false, isRecurring: false, lastPaidDate: nil, nextDueDate: .now, endDate: nil))
    }

    @Test func inactiveRecurringPastItsEnd_isFinished() {
        let end = date(2026, 6, 30)
        #expect(ScheduledPaymentListLogic.isFinished(isActive: false, isRecurring: true, lastPaidDate: nil, nextDueDate: date(2026, 7, 1), endDate: end))
        // Antes de su fin, inactivo es pausado.
        #expect(ScheduledPaymentListLogic.isPaused(isActive: false, isRecurring: true, lastPaidDate: nil, nextDueDate: date(2026, 6, 1), endDate: end))
    }

    @Test func inactiveRecurringWithoutEnd_isPaused() {
        #expect(ScheduledPaymentListLogic.isPaused(isActive: false, isRecurring: true, lastPaidDate: date(2026, 9, 1), nextDueDate: .now, endDate: nil))
    }

    // MARK: Estado de una fecha

    @Test func paidWinsOverSkippedPausedAndOverdue() {
        #expect(ScheduledPaymentListLogic.rowState(isPaid: true, isSkipped: true, isPaused: true, daysUntilDue: -3) == .paid)
    }

    @Test func skippedWinsOverPaused() {
        #expect(ScheduledPaymentListLogic.rowState(isPaid: false, isSkipped: true, isPaused: true, daysUntilDue: 2) == .skipped)
    }

    @Test func pausedWinsOverTheDate() {
        #expect(ScheduledPaymentListLogic.rowState(isPaid: false, isSkipped: false, isPaused: true, daysUntilDue: -3) == .paused)
    }

    @Test func dateStates_withTheirNeighbours() {
        let state = { (days: Int) in ScheduledPaymentListLogic.rowState(isPaid: false, isSkipped: false, isPaused: false, daysUntilDue: days) }
        #expect(state(-1) == .overdue)
        #expect(state(0) == .dueToday)
        #expect(state(1) == .dueTomorrow)
        #expect(state(2) == .dueInDays(2))
    }

    /// L10-1: lo ya pagado ya no va bajo «Vencidos»: va a «Pagados», aunque su fecha haya pasado.
    @Test func sections_separatePaidFromPending_notByDate() {
        struct Row { let name: String; let date: Date; let state: ScheduledPaymentRowState }
        let rows = [
            Row(name: "Alquiler", date: date(2026, 10, 5), state: .paid),
            Row(name: "Netflix", date: date(2026, 10, 20), state: .dueInDays(3)),
            Row(name: "Teléfono", date: date(2026, 10, 15), state: .overdue),
            Row(name: "Gym", date: date(2026, 10, 3), state: .paused),
            Row(name: "iCloud", date: date(2026, 10, 22), state: .skipped),
            Row(name: "Gimnasio", date: date(2026, 10, 3), state: .paid),
        ]
        let sections = ScheduledPaymentListLogic.sections(rows, date: \.date, state: \.state)
        #expect(sections.map(\.section) == [.toPay, .paid, .skipped, .paused])
        #expect(sections[0].items.map(\.name) == ["Teléfono", "Netflix"], "por fecha dentro de la sección")
        #expect(sections[1].items.map(\.name) == ["Gimnasio", "Alquiler"])
    }

    @Test func sections_dropEmptySections() {
        let sections = ScheduledPaymentListLogic.sections([date(2026, 10, 1)], date: { $0 }, state: { _ in .paid })
        #expect(sections.map(\.section) == [.paid])
    }

    /// L10-1: rosa solo lo vencido.
    @Test func onlyOverdueIsAnAlert() {
        let all: [ScheduledPaymentRowState] = [.overdue, .dueToday, .dueTomorrow, .dueInDays(4), .paid, .skipped, .paused]
        #expect(all.filter(ScheduledPaymentListLogic.isAlert) == [.overdue])
    }

    /// L10-3: un color, un significado. Un pago pendiente nunca sale con el color de su categoría.
    @Test func calendarDots_byStateOnly() {
        #expect(ScheduledPaymentListLogic.dotStatus(for: .paid) == .paid)
        #expect(ScheduledPaymentListLogic.dotStatus(for: .overdue) == .overdue)
        for state: ScheduledPaymentRowState in [.dueToday, .dueTomorrow, .dueInDays(9), .skipped, .paused] {
            #expect(ScheduledPaymentListLogic.dotStatus(for: state) == .pending)
        }
    }

    @Test func dayAmount_sumsOneCurrency_andHidesMixed() {
        let one = ScheduledPaymentListLogic.dayAmount([(amount: 45, currencyCode: "PEN"), (amount: -18, currencyCode: "PEN")])
        #expect(one?.value == 63)
        #expect(one?.currencyCode == "PEN")
        #expect(ScheduledPaymentListLogic.dayAmount([(amount: 45, currencyCode: "PEN"), (amount: 10, currencyCode: "USD")]) == nil)
        #expect(ScheduledPaymentListLogic.dayAmount([]) == nil)
    }

    // MARK: Cabecera (L10-2)

    @Test func hero_totalIsPaidPlusPending_soTheFiguresAlwaysAddUp() {
        let hero = ScheduledPaymentListLogic.Hero(pending: 403, paid: 2350)
        #expect(hero.total == 2753)
        #expect(abs(hero.paidFraction - 2350.0 / 2753.0) < 0.0001)
        #expect(!hero.isEmpty)
    }

    @Test func hero_emptyMonth_hasNoBar() {
        let hero = ScheduledPaymentListLogic.Hero(pending: 0, paid: 0)
        #expect(hero.isEmpty)
        #expect(hero.paidFraction == 0)
    }

    // MARK: Reanudar (L10-7)

    /// Pausado en julio y reanudado el 17 de octubre: la próxima fecha es el 20 de octubre, no el 20 de julio (que
    /// dejaría un borrador en la Bandeja por un pago que no se hizo).
    @Test func resume_movesAStaleDueDateToTheFirstFromToday() {
        let datesInMonth: (Date) -> [Date] = { month in
            let c = calendar.dateComponents([.year, .month], from: month)
            return [calendar.date(from: DateComponents(year: c.year, month: c.month, day: 20))!]
        }
        let next = ScheduledPaymentListLogic.resumedNextDueDate(
            current: date(2026, 7, 20), today: date(2026, 10, 17), calendar: calendar, datesInMonth: datesInMonth
        )
        #expect(next == date(2026, 10, 20))
        // El mismo día cuenta: si toca hoy, toca hoy.
        let today = ScheduledPaymentListLogic.resumedNextDueDate(
            current: date(2026, 7, 20), today: date(2026, 10, 20), calendar: calendar, datesInMonth: datesInMonth
        )
        #expect(today == date(2026, 10, 20))
        // Pasado el 20, el del mes que viene.
        let later = ScheduledPaymentListLogic.resumedNextDueDate(
            current: date(2026, 7, 20), today: date(2026, 10, 21), calendar: calendar, datesInMonth: datesInMonth
        )
        #expect(later == date(2026, 11, 20))
    }

    @Test func resume_keepsAFutureDueDate() {
        let next = ScheduledPaymentListLogic.resumedNextDueDate(
            current: date(2026, 11, 20), today: date(2026, 10, 17), calendar: calendar
        ) { _ in [] }
        #expect(next == date(2026, 11, 20))
    }
}

// MARK: - Enlaces de los avisos (L10-13, L10-14)

@Suite(.serialized)
@MainActor
struct UXAudit22Lote10AlertRoutingTests {

    @Test func deepLinks_roundTrip_andDoNotCross() {
        let id = UUID()
        let payment = AlertDeepLink.scheduledPayment.deepLink(for: id)
        let account = AlertDeepLink.account.deepLink(for: id)
        #expect(AlertDeepLink.scheduledPayment.id(fromDeepLink: payment) == id)
        #expect(AlertDeepLink.account.id(fromDeepLink: account) == id)
        #expect(AlertDeepLink.account.id(fromDeepLink: payment) == nil)
        #expect(AlertDeepLink.scheduledPayment.id(fromDeepLink: "scheduledPayments") == nil)
    }

    /// El aviso de la tarjeta («accounts») no abría nada: `parseDestination` no lo conocía.
    @Test func parseDestination_knowsBothNewLinks_andTheOldAccountsOne() {
        let id = UUID()
        #expect(NotificationService.parseDestination(AlertDeepLink.scheduledPayment.deepLink(for: id)) == .scheduledPayments)
        #expect(NotificationService.parseDestination(AlertDeepLink.account.deepLink(for: id)) == .panel)
        #expect(NotificationService.parseDestination("accounts") == .panel)
        #expect(NotificationService.parseDestination("scheduledPayments") == .scheduledPayments)
    }

    @Test func target_isConsumedOnce_andExpires() {
        let target = AlertDeepLinkTarget()
        let id = UUID()
        let now = Date.now
        target.request(id, now: now)
        #expect(target.consume(now: now.addingTimeInterval(60)) == id)
        #expect(target.consume(now: now.addingTimeInterval(61)) == nil, "una sola vez")

        target.request(id, now: now)
        #expect(target.consume(now: now.addingTimeInterval(AlertDeepLinkTarget.maxAge + 1)) == nil, "caduca")
    }

    @Test func routeTap_leavesTheIDForTheWindow() {
        let id = UUID()
        _ = AlertDeepLinkTarget.scheduledPayment.consume()
        NotificationService.routeTap(deepLink: AlertDeepLink.scheduledPayment.deepLink(for: id), targetSessionID: nil)
        #expect(AlertDeepLinkTarget.scheduledPayment.consume() == id)
    }
}

// MARK: - Pausar, apuntar y borrar con «Deshacer»

@Suite(.serialized)
@MainActor
struct UXAudit22Lote10ScheduledViewModelTests {

    private func makePayment(in context: ModelContext, nextDueDate: Date) -> ScheduledPayment {
        let day = Calendar.current.component(.day, from: nextDueDate)
        let payment = ScheduledPayment(
            name: "Gimnasio",
            amount: 150,
            currencyCode: "PEN",
            transactionType: "expense",
            isRecurring: true,
            recurrenceType: RecurrenceType.monthly.rawValue,
            recurrenceInterval: 1,
            nextDueDate: nextDueDate,
            dayOfMonth: day
        )
        context.insert(payment)
        return payment
    }

    @Test func pauseAndResume_fromTheDetail() throws {
        let context = try makeTestContext()
        let calendar = Calendar.current
        let stale = calendar.date(byAdding: .month, value: -3, to: calendar.startOfDay(for: .now))!
        let payment = makePayment(in: context, nextDueDate: stale)
        try context.save()
        let vm = ScheduledPaymentsViewModel()
        vm.setContext(context)

        vm.setPaused(payment, paused: true)
        #expect(!payment.isActive)
        #expect(payment.isPausedByUser)

        vm.setPaused(payment, paused: false)
        #expect(payment.isActive)
        #expect(calendar.startOfDay(for: payment.nextDueDate) >= calendar.startOfDay(for: .now),
                "reanudar no cobra lo que cayó en pausa")
    }

    /// «Reanudar» no reactiva un pago de una sola vez ya pagado: está terminado, no pausado.
    @Test func resume_doesNotReviveAFinishedOneTimePayment() throws {
        let context = try makeTestContext()
        let payment = ScheduledPayment(
            name: "Matrícula", amount: 300, currencyCode: "PEN", transactionType: "expense",
            isRecurring: false, nextDueDate: .now
        )
        payment.isActive = false
        payment.lastPaidDate = .now
        context.insert(payment)
        try context.save()
        let vm = ScheduledPaymentsViewModel()
        vm.setContext(context)

        vm.setPaused(payment, paused: false)
        #expect(!payment.isActive)
    }

    @Test func draftForPaying_reusesThePendingDraftOfThatMonth_andCreatesOtherwise() throws {
        let context = try makeTestContext()
        let today = Calendar.current.startOfDay(for: .now)
        let payment = makePayment(in: context, nextDueDate: today)
        let pending = InboxDraft(note: payment.name, amount: -150, date: today, sourceType: .scheduledPayment, status: .pending)
        pending.sourceScheduledPaymentID = payment.id.uuidString
        context.insert(pending)
        try context.save()
        let vm = ScheduledPaymentsViewModel()
        vm.setContext(context)

        let same = try #require(vm.draftForPaying(payment, occurrence: today))
        #expect(same.draft.persistentModelID == pending.persistentModelID)
        #expect(!same.isNew)

        // Una fecha futura: borrador nuevo, con fecha de HOY (la Bandeja no guarda fechas futuras).
        let future = Calendar.current.date(byAdding: .month, value: 1, to: today)!
        let created = try #require(vm.draftForPaying(payment, occurrence: future))
        #expect(created.isNew)
        #expect(Calendar.current.isDate(try #require(created.draft.date), inSameDayAs: today))

        // Cerrar sin guardar descarta el creado, nunca el que ya esperaba.
        vm.discardUnusedPayNowDraft(created.draft)
        vm.discardUnusedPayNowDraft(same.draft) // no es nuevo: el llamador solo lo pide con isNew, pero aquí se mide que tampoco rompe nada
        let remaining = try context.fetch(FetchDescriptor<InboxDraft>())
        #expect(!remaining.contains { $0.persistentModelID == created.draft.persistentModelID })
    }

    /// Un pago compartido no se apunta por aquí: lo aprueba el formulario de grupo.
    @Test func draftForPaying_skipsGroupPayments() throws {
        let context = try makeTestContext()
        let payment = makePayment(in: context, nextDueDate: .now)
        payment.groupZoneID = "zona"
        try context.save()
        let vm = ScheduledPaymentsViewModel()
        vm.setContext(context)
        #expect(payment.isGroupPayment)
        #expect(vm.draftForPaying(payment, occurrence: .now) == nil)
    }

    /// L10-15: mientras espera su borrado, el pago no sale; «Deshacer» lo devuelve y no se borra.
    @Test func pendingDeletion_hidesTheRow_andUndoBringsItBack() throws {
        let context = try makeTestContext()
        let payment = makePayment(in: context, nextDueDate: .now)
        try context.save()
        let vm = ScheduledPaymentsViewModel()
        vm.setContext(context)
        vm.loadPayments()
        #expect(vm.allPayments.contains { $0.id == payment.id })

        var committed = false
        ScheduledPaymentPendingDeletion.shared.request(paymentID: payment.id, name: payment.name) { committed = true }
        defer { ScheduledPaymentPendingDeletion.shared.undo(payment.id) }
        vm.loadPayments()
        #expect(!vm.allPayments.contains { $0.id == payment.id })

        ScheduledPaymentPendingDeletion.shared.undo(payment.id)
        vm.loadPayments()
        #expect(vm.allPayments.contains { $0.id == payment.id })
        #expect(!committed)
    }
}
