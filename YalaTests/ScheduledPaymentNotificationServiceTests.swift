//
//  ScheduledPaymentNotificationServiceTests.swift
//  YalaTests
//
//  Cubre el fix del ticket pagos-planificados-notifs-incoherentes-y-dedup-sin-entrega:
//  (1) markNotified SOLO con entrega confirmada — el mutante que debe cazar es
//      re-incondicionalizar el marcado tras un send fallido;
//  (2) gate de quiescencia (bandeja y notifs se mueven juntas);
//  (3) dueToday re-sourceada desde drafts materializados (causa 4);
//  (4) flip one-shot del toggle maestro (decisión owner D2).
//
//  Usa los seams inyectables del service (sendOverride / isQuiescentOverride /
//  isAuthorizedOverride / tracker con UserDefaults aislado) — el singleton `.shared`
//  jamás se toca. ≥2 makeTestContext() ⇒ @Suite(.serialized).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct ScheduledPaymentNotificationServiceTests {

    // MARK: - Harness

    /// Service con seams: tracker aislado, autorizado, quiescente, item activo a las 00:00
    /// (ventana siempre abierta) salvo que el test lo cambie.
    private func makeService(
        context: ModelContext,
        sendResult: Bool = true,
        quiescent: Bool = true,
        seedActiveItem: Bool = true
    ) throws -> (service: ScheduledPaymentNotificationService, sentLog: SentLog) {
        let tracker = ScheduledPaymentNotificationTracker(defaults: makeIsolatedDefaults())
        let service = ScheduledPaymentNotificationService(tracker: tracker)
        service.setContext(context)
        service.isAuthorizedOverride = { true }
        service.isQuiescentOverride = { quiescent }
        let log = SentLog()
        service.sendOverride = { title, _, deepLink in
            log.record(title: title, deepLink: deepLink)
            return sendResult
        }
        if seedActiveItem {
            let item = NotificationItem(
                name: "Pagos", text: "", hour: 0, minute: 0, type: .scheduledPayments, isActive: true
            )
            context.insert(item)
            try context.save()
        }
        return (service, log)
    }

    @MainActor
    private final class SentLog {
        private(set) var entries: [(title: String, deepLink: String?)] = []
        func record(title: String, deepLink: String?) { entries.append((title, deepLink)) }
        var count: Int { entries.count }
    }

    /// Pago activo con vencimiento hoy + su draft pending materializado (como lo dejaría
    /// processDuePayments).
    @discardableResult
    private func seedDueTodayPaymentWithDraft(
        context: ModelContext,
        notifyOnDueDate: Bool = true
    ) throws -> ScheduledPayment {
        let payment = ScheduledPayment(
            name: "Netflix",
            amount: 15.0,
            currencyCode: "USD",
            nextDueDate: Calendar.current.startOfDay(for: .now),
            notifyOnDueDate: notifyOnDueDate,
            notifyDaysBefore: 0
        )
        context.insert(payment)

        let draft = InboxDraft(
            note: payment.name,
            amount: -15.0,
            date: Calendar.current.startOfDay(for: .now),
            sourceType: .scheduledPayment,
            status: .pending
        )
        draft.sourceScheduledPaymentID = payment.id.uuidString
        context.insert(draft)
        try context.save()
        return payment
    }

    // MARK: - (1) markNotified solo con entrega confirmada

    @Test func dueToday_sendFails_doesNotMarkDedup() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context, sendResult: false)
        let payment = try seedDueTodayPaymentWithDraft(context: context)

        await service.checkAllPaymentNotifications()

        #expect(log.count == 1, "el envío se intentó")
        #expect(!service.tracker.hasNotifiedForDate(paymentID: payment.id, date: .now, type: .dueDate),
                "un send fallido NO debe quemar el dedup del día")
        #expect(payment.lastNotifiedDate == nil)

        // Reintento en el mismo día con entrega OK → ahora sí marca.
        service.sendOverride = { _, _, _ in true }
        await service.checkAllPaymentNotifications()
        #expect(service.tracker.hasNotifiedForDate(paymentID: payment.id, date: .now, type: .dueDate))
        #expect(payment.lastNotifiedDate != nil)
    }

    @Test func dueToday_sendSucceeds_marksDedup_andSecondPassIsSilent() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context, sendResult: true)
        let payment = try seedDueTodayPaymentWithDraft(context: context)

        await service.checkAllPaymentNotifications()
        #expect(log.count == 1)
        #expect(service.tracker.hasNotifiedForDate(paymentID: payment.id, date: .now, type: .dueDate))

        await service.checkAllPaymentNotifications()
        #expect(log.count == 1, "el dedup del día suprime el segundo pass")
    }

    @Test func creditCard_sendFails_doesNotMarkDedup() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context, sendResult: false)
        let account = Account(name: "Visa", currencyCode: "USD", colorHex: "#4A90D9", iconName: "creditcard", type: AccountType.creditCard.rawValue)
        account.creditCardPaymentReminder = true
        account.creditCardPaymentDay = Calendar.current.component(.day, from: .now)
        context.insert(account)
        try context.save()

        await service.checkAndNotifyCreditCardPayments()
        #expect(log.count == 1)
        #expect(!service.tracker.hasNotifiedCreditCard(accountID: account.shortcutID, date: .now))

        service.sendOverride = { _, _, _ in true }
        await service.checkAndNotifyCreditCardPayments()
        #expect(service.tracker.hasNotifiedCreditCard(accountID: account.shortcutID, date: .now))
    }

    // MARK: - (2) Quiescencia: difiere sin marcar

    @Test func notQuiescent_defersWithoutSendingOrMarking() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context, quiescent: false)
        let payment = try seedDueTodayPaymentWithDraft(context: context)

        await service.checkAllPaymentNotifications()

        #expect(log.count == 0, "sin quiescencia no debe enviarse nada")
        #expect(!service.tracker.hasNotifiedForDate(paymentID: payment.id, date: .now, type: .dueDate))
    }

    // MARK: - (3) dueToday desde drafts materializados

    @Test func dueToday_withoutMaterializedDraft_doesNotNotify() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context)
        // Pago vence hoy pero SIN draft (bandeja aún no lo materializó): coherencia exige silencio.
        let payment = ScheduledPayment(
            name: "Spotify",
            amount: 6.0,
            currencyCode: "USD",
            nextDueDate: Calendar.current.startOfDay(for: .now),
            notifyDaysBefore: 0
        )
        context.insert(payment)
        try context.save()

        await service.checkAllPaymentNotifications()
        #expect(log.count == 0, "sin draft en bandeja no hay notificación dueToday")
    }

    @Test func dueToday_respectsPerPaymentOptOut() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context)
        try seedDueTodayPaymentWithDraft(context: context, notifyOnDueDate: false)

        await service.checkAllPaymentNotifications()
        #expect(log.count == 0, "notifyOnDueDate=false debe respetarse aunque exista draft")
    }

    // MARK: - Supresión contra el canal agendado (híbrido D1)

    @Test func summaryMarkedToday_suppressesOpportunisticDueToday() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context)
        try seedDueTodayPaymentWithDraft(context: context)

        service.tracker.markSummaryScheduled(
            dayKey: ScheduledPaymentSummaryPlanner.dayKey(from: .now)
        )

        await service.checkAllPaymentNotifications()
        #expect(log.count == 0, "con summary agendada hoy, la oportunista dueToday es redundante")
    }

    @Test func paymentCreatedAfterTodaysSummary_stillNotifies() async throws {
        // La supresión es POR PAGO, no día completo (review adversarial): un pago creado
        // DESPUÉS de agendarse la summary de hoy no estuvo en su conteo — debe avisar.
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context)

        // Summary de hoy agendada AYER; el pago (createdAt = ahora) nace después.
        service.tracker.markSummaryScheduled(
            dayKey: ScheduledPaymentSummaryPlanner.dayKey(from: .now),
            at: Date.now.addingTimeInterval(-86_400)
        )
        try seedDueTodayPaymentWithDraft(context: context)

        await service.checkAllPaymentNotifications()
        #expect(log.count == 1, "el pago nuevo no está cubierto por la summary vieja del día")
    }

    // MARK: - Gate honesto en el service

    @Test func masterToggleOff_silencesPaymentLoop_butNotCreditCard() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context, seedActiveItem: false)
        let item = NotificationItem(
            name: "Pagos", text: "", hour: 0, minute: 0, type: .scheduledPayments, isActive: false
        )
        context.insert(item)
        try seedDueTodayPaymentWithDraft(context: context)

        let account = Account(name: "Visa", currencyCode: "USD", colorHex: "#4A90D9", iconName: "creditcard", type: AccountType.creditCard.rawValue)
        account.creditCardPaymentReminder = true
        account.creditCardPaymentDay = Calendar.current.component(.day, from: .now)
        context.insert(account)
        try context.save()

        await service.checkAllPaymentNotifications()
        #expect(log.count == 0, "toggle maestro OFF = silencio de pagos")

        // La tarjeta tiene opt-in propio per-account: el toggle de pagos no la silencia.
        await service.checkAndNotifyCreditCardPayments()
        #expect(log.count == 1)
        #expect(log.entries.last?.deepLink == "accounts")
    }

    @Test func activeItemWithFutureHour_defersCreditCardToo() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context, seedActiveItem: false)
        // Hora 23:59 — salvo que el test corra exactamente a medianoche, la ventana está cerrada.
        let item = NotificationItem(
            name: "Pagos", text: "", hour: 23, minute: 59, type: .scheduledPayments, isActive: true
        )
        context.insert(item)

        let account = Account(name: "Visa", currencyCode: "USD", colorHex: "#4A90D9", iconName: "creditcard", type: AccountType.creditCard.rawValue)
        account.creditCardPaymentReminder = true
        account.creditCardPaymentDay = Calendar.current.component(.day, from: .now)
        context.insert(account)
        try context.save()

        // Guard de flakiness: si el reloj real ya pasó las 23:59, el caso no aplica.
        guard service.gateDecision(context: context) == .waitForHour else { return }

        await service.checkAndNotifyCreditCardPayments()
        #expect(log.count == 0, "con item activo, la tarjeta espera la ventana horaria")
    }

    // MARK: - (4) Flip one-shot del toggle maestro

    @Test func flip_inactiveItem_activatesAndMarksSentinel() throws {
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults()
        let item = NotificationItem(
            name: "Pagos", text: "", hour: 9, minute: 0, type: .scheduledPayments, isActive: false
        )
        context.insert(item)
        try context.save()

        ScheduledPaymentNotificationService.flipMasterToggleIfNeeded(
            context: context, defaults: defaults, ubiquitous: nil, isQuiescent: { true }
        )

        #expect(item.isActive, "el one-shot activa el item de usuarios existentes")
        #expect(defaults.bool(forKey: ScheduledPaymentNotificationService.masterToggleFlipKey))
    }

    @Test func flip_sentinelPresent_respectsDeliberateOff() throws {
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: ScheduledPaymentNotificationService.masterToggleFlipKey)
        let item = NotificationItem(
            name: "Pagos", text: "", hour: 9, minute: 0, type: .scheduledPayments, isActive: false
        )
        context.insert(item)
        try context.save()

        ScheduledPaymentNotificationService.flipMasterToggleIfNeeded(
            context: context, defaults: defaults, ubiquitous: nil, isQuiescent: { true }
        )

        #expect(!item.isActive, "un OFF posterior al flip es decisión del usuario — intocable")
    }

    @Test func flip_notQuiescent_defersWithoutMarkingSentinel() throws {
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults()
        let item = NotificationItem(
            name: "Pagos", text: "", hour: 9, minute: 0, type: .scheduledPayments, isActive: false
        )
        context.insert(item)
        try context.save()

        ScheduledPaymentNotificationService.flipMasterToggleIfNeeded(
            context: context, defaults: defaults, ubiquitous: nil, isQuiescent: { false }
        )

        #expect(!item.isActive)
        #expect(!defaults.bool(forKey: ScheduledPaymentNotificationService.masterToggleFlipKey),
                "diferir por quiescencia NO quema el sentinel — debe reintentar")
    }

    @Test func flip_absentItem_leavesOneShotOpen() throws {
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults()

        ScheduledPaymentNotificationService.flipMasterToggleIfNeeded(
            context: context, defaults: defaults, ubiquitous: nil, isQuiescent: { true }
        )

        #expect(!defaults.bool(forKey: ScheduledPaymentNotificationService.masterToggleFlipKey),
                "con CERO items el one-shot queda ABIERTO (pre-onboarding/pre-seed) — quemarlo aquí dejaba al usuario nuevo silenciado si el seed sembraba OFF")
    }

    // MARK: - Default del seed

    @Test func createDefaults_scheduledPayments_isActiveByDefault() {
        let defaults = NotificationItem.createDefaults()
        let item = defaults.first { $0.typeRaw == "scheduledPayments" }
        #expect(item?.isActive == true,
                "con el gate honesto, el default OFF dejaría a los usuarios nuevos sin recordatorios")
    }
}
