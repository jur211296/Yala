//
//  CreditCardReminderSchedulerTests.swift
//  YalaTests
//
//  El aviso PROGRAMADO antes de pagar la tarjeta (card nmtk, D3-A). Sustituye a los casos del canal viejo «al abrir el
//  día de pago» de `ScheduledPaymentNotificationServiceTests`: el toggle de pagos no lo silencia, comparte su hora, un envío
//  que falla no marca, lo pagado no se avisa y el aviso abre la ficha. Seams del programador; el `.shared` no se toca.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct CreditCardReminderSchedulerTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima")!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @MainActor
    private final class Log {
        var replaced: [[NotificationService.CreditCardReminderRequest]] = []
        var sent: [(title: String, body: String, deepLink: String?)] = []
        /// Lo que el centro tendría pendiente: lo programado en la pasada anterior (nada dispara en el test).
        var pending: Set<String> = []
    }

    private func makeScheduler(context: ModelContext, sendResult: Bool = true, quiescent: Bool = true)
        -> (CreditCardReminderScheduler, Log) {
        let scheduler = CreditCardReminderScheduler(
            tracker: ScheduledPaymentNotificationTracker(defaults: UserDefaults(suiteName: "cc.\(UUID().uuidString)")!))
        scheduler.setContext(context)
        let log = Log()
        scheduler.isAuthorizedOverride = { true }
        scheduler.isQuiescentOverride = { quiescent }
        scheduler.replaceOverride = { requests in
            log.replaced.append(requests)
            let removed = log.pending
            log.pending = Set(requests.map(\.identifier))
            return NotificationService.CreditCardReplaceOutcome(scheduled: log.pending, removedPending: removed)
        }
        scheduler.sendOverride = { title, body, deepLink in
            log.sent.append((title, body, deepLink))
            return sendResult
        }
        return (scheduler, log)
    }

    /// Visa con corte el 15 y pago el 5: S/ 1,240 antes del corte de octubre y S/ 386.50 después.
    @discardableResult
    private func seedCard(_ context: ModelContext, lead: Int = 3, statementDay: Int? = 15,
                          payment: Double? = nil) throws -> Account {
        let card = Account(name: "Visa", currencyCode: "PEN", colorHex: "#3D36B3", iconName: "creditcard",
                           type: AccountType.creditCard.rawValue)
        card.creditCardPaymentReminder = true
        card.creditCardPaymentDay = 5
        card.creditCardStatementDay = statementDay
        card.creditCardReminderDaysBefore = lead
        context.insert(card)
        func tx(_ amount: Double, _ when: Date) {
            context.insert(TransactionItem(date: when, amount: amount, currencyCode: "PEN", note: nil,
                                           category: nil, subcategory: nil, account: card))
        }
        tx(-1_240, date(2026, 10, 10, 12))
        tx(-386.5, date(2026, 10, 20, 12))
        if let payment { tx(payment, date(2026, 10, 25, 12)) }
        try context.save()
        return card
    }

    private func seedSummaryItem(_ context: ModelContext, active: Bool, hour: Int, minute: Int = 0) throws {
        context.insert(NotificationItem(name: "Pagos", text: "", hour: hour, minute: minute,
                                        type: .scheduledPayments, isActive: active))
        try context.save()
    }

    @Test func programaElAvisoTresDiasAntes_conLoFacturado_yAbreLaFicha() async throws {
        let context = try makeTestContext()
        let card = try seedCard(context)
        try seedSummaryItem(context, active: true, hour: 8, minute: 30)
        let (scheduler, log) = makeScheduler(context: context)

        await scheduler.replan(now: { self.date(2026, 10, 27, 10) }, calendar: calendar)

        let requests = try #require(log.replaced.last)
        let first = try #require(requests.first)
        #expect(first.fireDate == calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 8, minute: 30)))
        #expect(first.title == "Visa")
        #expect(first.body.contains("1,240") || first.body.contains("1.240"), "sin importe: «\(first.body)»")
        #expect(first.deepLink == AlertDeepLink.account.deepLink(for: card.shortcutID))
        #expect(first.identifier.hasPrefix(CreditCardReminderScheduler.identifierPrefix))
        #expect(scheduler.tracker.hasNotifiedCreditCard(accountID: card.shortcutID, date: date(2026, 11, 2)))
        #expect(log.sent.isEmpty)
    }

    /// El toggle del resumen de pagos apagado no silencia la tarjeta (opt-in propio); solo deja la hora por defecto.
    @Test func elResumenApagado_noLaSilencia_yAvisaALasNueve() async throws {
        let context = try makeTestContext()
        try seedCard(context)
        try seedSummaryItem(context, active: false, hour: 20)
        let (scheduler, log) = makeScheduler(context: context)

        await scheduler.replan(now: { self.date(2026, 10, 27, 10) }, calendar: calendar)

        let first = try #require(log.replaced.last?.first)
        #expect(calendar.component(.hour, from: first.fireDate) == CreditCardStatementLogic.defaultReminderHour)
    }

    @Test func yaPagado_noSeAvisaDeEseCorte() async throws {
        let context = try makeTestContext()
        try seedCard(context, payment: 1_240)
        let (scheduler, log) = makeScheduler(context: context)

        await scheduler.replan(now: { self.date(2026, 10, 27, 10) }, calendar: calendar)

        let requests = try #require(log.replaced.last)
        #expect(!requests.contains { calendar.isDate($0.day, inSameDayAs: self.date(2026, 11, 2)) })
        // El del corte siguiente sigue, sin importe todavía.
        #expect(requests.contains { calendar.isDate($0.day, inSameDayAs: self.date(2026, 12, 2)) })
    }

    @Test func avisoApagado_retiraTodo() async throws {
        let context = try makeTestContext()
        let card = try seedCard(context)
        card.creditCardPaymentReminder = false
        try context.save()
        let (scheduler, log) = makeScheduler(context: context)

        await scheduler.replan(now: { self.date(2026, 10, 27, 10) }, calendar: calendar)

        #expect(log.replaced.last?.isEmpty == true, "el plan vacío limpia lo programado")
    }

    /// El aviso de HOY con la hora pasada y sin programar sale al momento, una vez; si el envío falla, no marca.
    @Test func elDeHoyConLaHoraPasada_saleAlMomento_yUnEnvioFallidoNoMarca() async throws {
        let context = try makeTestContext()
        let card = try seedCard(context)
        let (scheduler, log) = makeScheduler(context: context, sendResult: false)
        let now = date(2026, 11, 2, 15)

        await scheduler.replan(now: { now }, calendar: calendar)
        #expect(log.sent.count == 1)
        #expect(log.sent.first?.deepLink == AlertDeepLink.account.deepLink(for: card.shortcutID))
        #expect(!scheduler.tracker.hasNotifiedCreditCard(accountID: card.shortcutID, date: now))

        scheduler.sendOverride = { title, body, deepLink in
            log.sent.append((title, body, deepLink))
            return true
        }
        await scheduler.replan(now: { now }, calendar: calendar)
        #expect(log.sent.count == 2)
        #expect(scheduler.tracker.hasNotifiedCreditCard(accountID: card.shortcutID, date: now))

        await scheduler.replan(now: { now }, calendar: calendar)
        #expect(log.sent.count == 2, "ya salió: no se repite")
    }

    /// El aviso de hoy estaba programado (y marcado) a las 18:00; el usuario pasa la hora a las 8:00 a media mañana. El
    /// pendiente se retira sin disparar: su marca cae y el aviso sale al momento (lo cazó la review: se perdía).
    @Test func avisoDeHoyMovidoAUnaHoraPasada_saleAlMomento() async throws {
        let context = try makeTestContext()
        let card = try seedCard(context)
        try seedSummaryItem(context, active: true, hour: 18)
        let (scheduler, log) = makeScheduler(context: context)
        let now = date(2026, 11, 2, 10)

        await scheduler.replan(now: { now }, calendar: calendar)
        #expect(log.sent.isEmpty)
        #expect(scheduler.tracker.hasNotifiedCreditCard(accountID: card.shortcutID, date: now))

        let item = try #require(try context.fetch(FetchDescriptor<NotificationItem>()).first)
        item.hour = 8
        try context.save()
        await scheduler.replan(now: { now }, calendar: calendar)

        #expect(log.sent.count == 1, "el aviso de hoy, movido a una hora pasada, no salió")
        #expect(scheduler.tracker.hasNotifiedCreditCard(accountID: card.shortcutID, date: now))
    }

    @Test func identificadorDelAviso_vaYVuelve() throws {
        let id = UUID()
        let parsed = try #require(CreditCardReminderScheduler.parse(
            CreditCardReminderScheduler.identifierPrefix + id.uuidString + "_20261102", calendar: calendar))
        #expect(parsed.0 == id)
        #expect(parsed.1 == date(2026, 11, 2))
        #expect(CreditCardReminderScheduler.parse("spDailySummary_20261102", calendar: calendar) == nil)
    }

    @Test func sinDiaDeCorte_elMismoDiaYSinImporte() async throws {
        let context = try makeTestContext()
        try seedCard(context, lead: 3, statementDay: nil)
        let (scheduler, log) = makeScheduler(context: context)

        await scheduler.replan(now: { self.date(2026, 10, 27, 10) }, calendar: calendar)

        let first = try #require(log.replaced.last?.first)
        #expect(calendar.isDate(first.day, inSameDayAs: date(2026, 11, 5)))
        #expect(first.body == L10n.Account.CreditCard.paymentNotification("Visa"))
    }

    /// Una transferencia a la tarjeta es un PAGO: lleva `balanceAdjustmentType = "transfer"` y no puede leerse como ajuste
    /// (la review lo cazó: el aviso anunciaba lo facturado ya pagado).
    @Test func unaTransferenciaALaTarjeta_esUnPago() async throws {
        let context = try makeTestContext()
        let card = try seedCard(context)
        let payment = TransactionItem(date: date(2026, 10, 25, 12), amount: 1_240, currencyCode: "PEN", note: nil,
                                      category: nil, subcategory: nil, account: card)
        payment.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
        context.insert(payment)
        try context.save()
        #expect(!CreditCardReminderScheduler.isBalanceAdjustment(TransactionItem.adjustmentTypeTransfer))
        #expect(CreditCardReminderScheduler.isBalanceAdjustment(InitialBalanceService.typeAdjustment))
        #expect(CreditCardReminderScheduler.isBalanceAdjustment(InitialBalanceService.typeInitialBalance))
        let (scheduler, log) = makeScheduler(context: context)

        await scheduler.replan(now: { self.date(2026, 10, 27, 10) }, calendar: calendar)

        let requests = try #require(log.replaced.last)
        #expect(!requests.contains { calendar.isDate($0.day, inSameDayAs: self.date(2026, 11, 2)) },
                "pagado por transferencia: no se avisa")
    }

    /// Con el import de CloudKit a medias no se toca nada: el importe sería parcial.
    @Test func sinQuiescencia_noTocaNada() async throws {
        let context = try makeTestContext()
        try seedCard(context)
        let (scheduler, log) = makeScheduler(context: context, quiescent: false)

        await scheduler.replan(now: { self.date(2026, 10, 27, 10) }, calendar: calendar)

        #expect(log.replaced.isEmpty)
        #expect(log.sent.isEmpty)
    }

    /// Una tarjeta con una línea en dólares avisa una vez, con el importe de cada divisa.
    @Test func tarjetaConLinea_unAviso_conLasDosDivisas() async throws {
        let context = try makeTestContext()
        let card = try seedCard(context)
        let line = Account(name: "Visa · USD", currencyCode: "USD", colorHex: "#3D36B3", iconName: "creditcard",
                           type: AccountType.creditCard.rawValue)
        line.parentAccountID = card.shortcutID
        line.creditCardPaymentReminder = true
        context.insert(line)
        context.insert(TransactionItem(date: date(2026, 10, 12, 12), amount: -80, currencyCode: "USD", note: nil,
                                       category: nil, subcategory: nil, account: line))
        try context.save()
        let (scheduler, log) = makeScheduler(context: context)

        await scheduler.replan(now: { self.date(2026, 10, 27, 10) }, calendar: calendar)

        let requests = try #require(log.replaced.last)
        let closed = requests.filter { calendar.isDate($0.day, inSameDayAs: self.date(2026, 11, 2)) }
        #expect(closed.count == 1)
        let body = try #require(closed.first?.body)
        #expect(body.contains("80"), "falta la línea en dólares: «\(body)»")
        #expect(body.contains("1,240") || body.contains("1.240"))
    }
}
