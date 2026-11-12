//
//  ScheduledPaymentWidgetPayTests.swift
//  YalaTests
//
//  «Ya lo pagué» en el widget de Pagos planificados (decisión B de Jürgen, 2026-11-03): qué pago lleva el botón, la cola
//  del App Group y el registro que la app crea con la lógica de «Apuntarlo ahora» (`ScheduledPaymentPayNow`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Widget de Pagos · qué pago se marca en un toque")
struct ScheduledPaymentWidgetPayLogicTests {

    private typealias Logic = ScheduledPaymentWidgetPayLogic
    private let calendar = Calendar.current

    @Test func onlyAPersonalPaymentWithAccountSubcategoryAndFixedAmount_canBeMarked() {
        #expect(Logic.canMarkPaid(isGroupPayment: false, hasAccount: true, hasSubcategory: true, isVariableAmount: false))
        #expect(!Logic.canMarkPaid(isGroupPayment: true, hasAccount: true, hasSubcategory: true, isVariableAmount: false))
        #expect(!Logic.canMarkPaid(isGroupPayment: false, hasAccount: false, hasSubcategory: true, isVariableAmount: false))
        #expect(!Logic.canMarkPaid(isGroupPayment: false, hasAccount: true, hasSubcategory: false, isVariableAmount: false))
        #expect(!Logic.canMarkPaid(isGroupPayment: false, hasAccount: true, hasSubcategory: true, isVariableAmount: true))
    }

    /// El botón es del pago de HOY: ni el vencido ni el de mañana.
    @Test func theButton_isOnlyForTodaysPayment() {
        let now = Date.now
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        #expect(Logic.showsButton(canMarkPaid: true, nextDueDate: today, now: now, calendar: calendar))
        #expect(!Logic.showsButton(canMarkPaid: true, nextDueDate: yesterday, now: now, calendar: calendar))
        #expect(!Logic.showsButton(canMarkPaid: true, nextDueDate: tomorrow, now: now, calendar: calendar))
        #expect(!Logic.showsButton(canMarkPaid: false, nextDueDate: today, now: now, calendar: calendar))
    }

    @Test func aRequest_marksOnlyThatDateOfThatPayment() {
        let today = calendar.startOfDay(for: .now)
        let next = calendar.date(byAdding: .month, value: 1, to: today)!
        let request = ScheduledPaymentWidgetPaidRequest(paymentID: "p", occurrence: today, requestedAt: .now)
        #expect(Logic.isRequested(paymentID: "p", nextDueDate: today, requests: [request], calendar: calendar))
        #expect(!Logic.isRequested(paymentID: "q", nextDueDate: today, requests: [request], calendar: calendar))
        #expect(!Logic.isRequested(paymentID: "p", nextDueDate: next, requests: [request], calendar: calendar))
    }

    /// Si el pago ya avanzó de esa fecha (se apuntó o se saltó desde la app), apuntarla otra vez duplicaría el registro.
    @Test func aRequestWhosePaymentMovedOn_isDiscarded() {
        let today = calendar.startOfDay(for: .now)
        let next = calendar.date(byAdding: .month, value: 1, to: today)!
        let request = ScheduledPaymentWidgetPaidRequest(paymentID: "p", occurrence: today, requestedAt: .now)
        #expect(Logic.resolve(request: request, paymentExists: true, canMarkPaid: true, nextDueDate: today,
                              calendar: calendar) == .record)
        #expect(Logic.resolve(request: request, paymentExists: true, canMarkPaid: true, nextDueDate: next,
                              calendar: calendar) == .discard)
        #expect(Logic.resolve(request: request, paymentExists: false, canMarkPaid: true, nextDueDate: nil,
                              calendar: calendar) == .discard)
        #expect(Logic.resolve(request: request, paymentExists: true, canMarkPaid: false, nextDueDate: today,
                              calendar: calendar) == .discard)
    }

    @Test func theQueue_roundTripsAndRemovesByKey() throws {
        let defaults = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        let first = ScheduledPaymentWidgetPaidRequest(paymentID: "a", occurrence: .now, requestedAt: Date(timeIntervalSince1970: 10))
        let second = ScheduledPaymentWidgetPaidRequest(paymentID: "b", occurrence: .now, requestedAt: Date(timeIntervalSince1970: 20))
        ScheduledPaymentWidgetPaidStore.append(second, defaults: defaults)
        ScheduledPaymentWidgetPaidStore.append(first, defaults: defaults)
        defaults.set(Data("no es json".utf8), forKey: ScheduledPaymentWidgetPaidStore.keyPrefix + "roto")
        let all = ScheduledPaymentWidgetPaidStore.peekAll(defaults: defaults)
        #expect(all.map(\.request) == [first, second], "Por orden de toque, y lo corrupto fuera.")
        ScheduledPaymentWidgetPaidStore.remove(keys: [all[0].key], defaults: defaults)
        #expect(ScheduledPaymentWidgetPaidStore.peekAll(defaults: defaults).map(\.request) == [second])
    }
}

@Suite("Widget de Pagos · el «Ya lo pagué» se apunta como en la app", .serialized)
@MainActor
struct ScheduledPaymentWidgetPayRecordTests {

    private struct Fixture {
        let context: ModelContext
        let payment: ScheduledPayment
        let defaults: UserDefaults
    }

    private func makeFixture() throws -> Fixture {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "BCP", currencyCode: "PEN")
        let category = makeTestCategory(context: context, name: "Salud")
        let subcategory = makeTestSubcategory(context: context, name: "Gimnasio", category: category)
        let today = Calendar.current.startOfDay(for: .now)
        let payment = ScheduledPayment(
            name: "Gimnasio", amount: 150, currencyCode: "PEN", transactionType: "expense", isRecurring: true,
            recurrenceType: RecurrenceType.monthly.rawValue, recurrenceInterval: 1, nextDueDate: today,
            dayOfMonth: Calendar.current.component(.day, from: today))
        payment.account = account
        payment.subcategory = subcategory
        context.insert(payment)
        try context.save()
        let defaults = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        return Fixture(context: context, payment: payment, defaults: defaults)
    }

    private func records(_ context: ModelContext) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>())
    }

    /// El caso del encargo: el botón del pago de hoy deja la petición y la app la apunta como «Apuntarlo ahora»: un
    /// registro con el monto del pago, en su cuenta, y el pago pasa a su próxima fecha. Una segunda pasada no duplica.
    @Test func theWidgetRequest_becomesTheRecord_andThePaymentMovesOn() throws {
        let f = try makeFixture()
        defer { DraftService.shared.setContext(nil) }
        let today = f.payment.nextDueDate
        ScheduledPaymentWidgetPaidStore.append(
            ScheduledPaymentWidgetPaidRequest(paymentID: f.payment.id.uuidString, occurrence: today, requestedAt: .now),
            defaults: f.defaults)

        let created = ScheduledPaymentPayNow.processWidgetPaidRequests(
            context: f.context, defaults: f.defaults, currencyConverter: CurrencyConverter())

        #expect(created == 1)
        let record = try #require(try records(f.context).first)
        #expect(try records(f.context).count == 1)
        #expect(record.amount == -150)
        #expect(record.account?.name == "BCP")
        #expect(record.subcategory?.name == "Gimnasio")
        #expect(Calendar.current.isDate(record.date, inSameDayAs: today))
        #expect(f.payment.nextDueDate > today, "Como «Ya lo pagué»: el pago pasa a su próxima fecha.")
        #expect(ScheduledPaymentWidgetPaidStore.peekAll(defaults: f.defaults).isEmpty)

        #expect(ScheduledPaymentPayNow.processWidgetPaidRequests(
            context: f.context, defaults: f.defaults, currencyConverter: CurrencyConverter()) == 0)
        #expect(try records(f.context).count == 1)
    }

    /// Lo apuntaste desde la app antes de que corriera el drenaje: la petición del widget se retira sin otro registro.
    @Test func aRequestForADateAlreadyPaidInTheApp_doesNotRecordTwice() throws {
        let f = try makeFixture()
        defer { DraftService.shared.setContext(nil) }
        let today = f.payment.nextDueDate
        ScheduledPaymentWidgetPaidStore.append(
            ScheduledPaymentWidgetPaidRequest(paymentID: f.payment.id.uuidString, occurrence: today, requestedAt: .now),
            defaults: f.defaults)
        DraftService.shared.setContext(f.context)
        _ = try ScheduledPaymentPayNow.recordPaymentNow(
            f.payment, occurrence: today, amount: 150, draftService: .shared, currencyConverter: CurrencyConverter(),
            context: f.context)
        #expect(try records(f.context).count == 1)

        #expect(ScheduledPaymentPayNow.processWidgetPaidRequests(
            context: f.context, defaults: f.defaults, currencyConverter: CurrencyConverter()) == 0)
        #expect(try records(f.context).count == 1)
        #expect(ScheduledPaymentWidgetPaidStore.peekAll(defaults: f.defaults).isEmpty)
    }

    /// Un pago compartido no se apunta desde el widget: se retira sin registro (lo aprueba el formulario de grupo).
    @Test func aGroupPaymentRequest_isDiscarded() throws {
        let f = try makeFixture()
        defer { DraftService.shared.setContext(nil) }
        f.payment.groupZoneID = "zona"
        try f.context.save()
        ScheduledPaymentWidgetPaidStore.append(
            ScheduledPaymentWidgetPaidRequest(
                paymentID: f.payment.id.uuidString, occurrence: f.payment.nextDueDate, requestedAt: .now),
            defaults: f.defaults)
        #expect(ScheduledPaymentPayNow.processWidgetPaidRequests(
            context: f.context, defaults: f.defaults, currencyConverter: CurrencyConverter()) == 0)
        #expect(try records(f.context).isEmpty)
        #expect(ScheduledPaymentWidgetPaidStore.peekAll(defaults: f.defaults).isEmpty)
    }

    /// La foto del widget lleva si el pago se puede marcar, y la extensión lo lee opcional (fotos viejas: no).
    @Test func theSnapshotDTO_carriesCanMarkPaid_andOldSnapshotsReadFalse() throws {
        let payment = WidgetScheduledPayment(
            id: "p", name: "P", amount: 1, currencyCode: "PEN", nextDueDate: .now, isOverdue: false,
            paymentCategory: "recurring", isIncome: false, iconName: "i", colorHex: "#000000", canMarkPaid: true)
        let data = try JSONEncoder().encode(payment)
        #expect(try JSONDecoder().decode(WidgetScheduledPayment.self, from: data).canMarkPaid)
        var legacy = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "canMarkPaid")
        let old = try JSONSerialization.data(withJSONObject: legacy)
        #expect(try !JSONDecoder().decode(WidgetScheduledPayment.self, from: old).canMarkPaid)
    }
}
