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

    // MARK: - UX 2.2 · L10-13: el aviso lleva el pago y el formato de la app

    @MainActor
    private final class SentBody {
        var body: String?
        var deepLink: String?
    }

    @Test func dueToday_carriesThePaymentID_andTheAppAmountFormat() async throws {
        let context = try makeTestContext()
        let (service, _) = try makeService(context: context)
        let sent = SentBody()
        service.sendOverride = { _, body, deepLink in
            sent.body = body
            sent.deepLink = deepLink
            return true
        }
        let payment = try seedDueTodayPaymentWithDraft(context: context)

        await service.checkAllPaymentNotifications()

        // Tocarlo abre el detalle de ESTE pago, no la lista.
        #expect(sent.deepLink == AlertDeepLink.scheduledPayment.deepLink(for: payment.id))
        // El monto con el formato de la app (con espacio y la preferencia de símbolo o código), no «$15».
        let formatted = YalaFormatterStatic.currency(value: 15, currencyCode: "USD")
        #expect(sent.body?.contains(formatted) == true, "cuerpo: \(sent.body ?? "nil") · esperado: \(formatted)")
    }

    // MARK: - Una pasada a la vez (ticket notices-come-out-one-after-another-by-priority)

    /// Dos pasadas solapadas —el arranque en frío y el primer `.active`— leían el tracker antes de que la otra marcara, y el
    /// mismo pago salía dos veces. El envío falso suspende, así que sin la guarda la segunda pasada entra mientras la
    /// primera espera su `send` y lo manda otra vez.
    @Test func twoOverlappingPasses_sendThePaymentOnce() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context)
        service.sendOverride = { title, _, deepLink in
            log.record(title: title, deepLink: deepLink)
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                print("Test: Error: \(error)")
            }
            return true
        }
        try seedDueTodayPaymentWithDraft(context: context)

        async let first: Void = service.checkAllPaymentNotifications()
        async let second: Void = service.checkAllPaymentNotifications()
        _ = await (first, second)

        #expect(log.count == 1, "dos pasadas solapadas mandaron \(log.count) avisos del mismo pago")

        // La guarda se suelta: un pago nuevo en una pasada posterior sale.
        try seedDueTodayPaymentWithDraft(context: context)
        await service.checkAllPaymentNotifications()
        #expect(log.count == 2, "tras la pasada solapada la guarda se quedó puesta")
    }

    /// Review adversarial: la pasada que llega durante otra no se tira, se repite al terminar. Un pago que aparece mientras
    /// la primera manda el suyo (la primera ya lo leyó) sale en la repetición; sin ella se quedaba para el siguiente
    /// primer plano (el borrado parcial de `DataWipeService` pide su pasada justo así).
    @Test func aPassRequestedDuringAnother_runsAfterIt() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context)
        var seededDuringTheFirstSend = false
        service.sendOverride = { title, _, deepLink in
            log.record(title: title, deepLink: deepLink)
            if !seededDuringTheFirstSend {
                seededDuringTheFirstSend = true
                do {
                    try self.seedDueTodayPaymentWithDraft(context: context)
                    try await Task.sleep(for: .milliseconds(50))
                } catch {
                    print("Test: Error: \(error)")
                }
            }
            return true
        }
        try seedDueTodayPaymentWithDraft(context: context)

        async let first: Void = service.checkAllPaymentNotifications()
        async let second: Void = service.checkAllPaymentNotifications()
        _ = await (first, second)

        #expect(log.count == 2, "el pago que apareció durante la primera pasada salió \(log.count - 1) veces")
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

    /// El aviso de la tarjeta ya no pasa por aquí (card nmtk, `CreditCardReminderSchedulerTests`): el toggle maestro
    /// sigue silenciando los pagos planificados.
    @Test func masterToggleOff_silencesPaymentLoop() async throws {
        let context = try makeTestContext()
        let (service, log) = try makeService(context: context, seedActiveItem: false)
        let item = NotificationItem(
            name: "Pagos", text: "", hour: 0, minute: 0, type: .scheduledPayments, isActive: false
        )
        context.insert(item)
        try seedDueTodayPaymentWithDraft(context: context)
        try context.save()

        await service.checkAllPaymentNotifications()
        #expect(log.count == 0, "toggle maestro OFF = silencio de pagos")
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
