//
//  ScheduledPaymentNotificationService.swift
//  Yala
//
//  Service for sending personalized notifications for scheduled payments.
//  Handles: due today, upcoming (X days before), and overdue payments.
//
//  Modelo (ticket pagos-planificados-notifs-incoherentes-y-dedup-sin-entrega, 2026-07-22):
//  las notificaciones oportunistas de este service corren al abrir la app (boot/foreground vía
//  `AppBootstrapper.ensureNotificationsScheduled`), gateadas por la ventana horaria del item
//  `scheduledPayments` (`ScheduledPaymentNotificationGateLogic` — toggle honesto, fail-closed)
//  y por la QUIESCENCIA del import de CloudKit (misma compuerta que
//  `ScheduledPaymentDraftService.processDuePayments`, para que bandeja y notificaciones se
//  muevan juntas). El dedup del tracker se marca SOLO con entrega confirmada por iOS
//  (`sendNotification -> Bool`) — marcar sin entrega quema la supresión del día sin banner.
//

import Foundation
import SwiftData

/// Service for checking scheduled payments and sending personalized notifications
@MainActor
final class ScheduledPaymentNotificationService {
    static let shared = ScheduledPaymentNotificationService()

    private var modelContext: ModelContext?

    /// Tracker de dedup. Inyectable como seam de test (default: singleton compartido).
    let tracker: ScheduledPaymentNotificationTracker

    // MARK: - Test seams (nil/default en producción; patrón de closures inyectables del repo)

    /// Sustituye el envío real (`NotificationService.sendNotification`) en tests.
    /// Retorna el mismo contrato: `true` = iOS aceptó el request.
    var sendOverride: ((_ title: String, _ body: String, _ deepLink: String?) async -> Bool)?
    /// Sustituye la lectura de quiescencia del import en tests.
    var isQuiescentOverride: (() -> Bool)?
    /// Sustituye el check de permisos del sistema en tests.
    var isAuthorizedOverride: (() async -> Bool)?
    /// Sustituye el efecto de agendado de summaries (`NotificationService`) en tests.
    /// Mismo contrato que `replaceScheduledPaymentSummaries(_:todayKey:todayAlreadyMarked:)`.
    var replaceSummariesOverride: ((
        _ plans: [ScheduledPaymentSummaryPlanner.DayPlan],
        _ todayKey: String,
        _ todayAlreadyMarked: Bool
    ) async -> NotificationService.SummaryReplaceOutcome)?

    /// Maximum overdue notifications per session to avoid spam
    private let maxOverdueNotifications = 5

    private init() {
        self.tracker = .shared
    }

    /// Init de test — permite un tracker aislado (UserDefaults propio). No usar en producción.
    init(tracker: ScheduledPaymentNotificationTracker) {
        self.tracker = tracker
    }

    func setContext(_ context: ModelContext?) {
        self.modelContext = context
    }

    private func isImportQuiescent() -> Bool {
        isQuiescentOverride?() ?? iCloudSyncService.shared.isImportQuiescent
    }

    private func isAuthorized() async -> Bool {
        if let override = isAuthorizedOverride { return await override() }
        return await NotificationService.shared.isAuthorized()
    }

    private func send(title: String, body: String, deepLink: String?) async -> Bool {
        if let override = sendOverride { return await override(title, body, deepLink) }
        return await NotificationService.shared.sendNotification(title: title, body: body, deepLink: deepLink)
    }

    // MARK: - Public Methods

    /// Single entry point: checks all scheduled payment notifications (overdue, due today, upcoming).
    /// Fetches payments, paid status, and notification config once to avoid redundant queries.
    func checkAllPaymentNotifications() async {
        guard let context = modelContext else { return }
        guard await isAuthorized() else { return }

        // Gate de quiescencia: comparte compuerta con processDuePayments (que materializa los
        // drafts) — sin esto se notificaban pagos que aún no estaban en la bandeja durante el
        // import de un cold launch. No marca nada: reintenta en el próximo pass.
        guard isImportQuiescent() else {
            SaveBreadcrumb.deferred("ScheduledPaymentNotificationService.checkAll", "import not quiescent")
            return
        }

        // Gate horario honesto y fail-closed. Solo `.send` deja correr el loop; ninguna otra
        // rama marca dedup (silenced = toggle OFF; waitForHour = aún no es la hora;
        // deferFetchError = estado desconocido, reintenta el próximo pass).
        guard gateDecision(context: context) == .send else { return }

        let payments = fetchActivePayments(context: context)
        guard !payments.isEmpty else { return }

        let today = Date.now
        // Una sola query: counts mensuales (overdue/upcoming, semántica histórica) + días
        // pagados exactos (dueToday por-ocurrencia: un weekly con la 1ª ocurrencia del mes
        // pagada NO debe silenciar la 2ª que ya está pending en la bandeja).
        let paidAmounts = ScheduledPaymentPaidStatusHelper.loadPaidAmounts(for: payments, month: today, context: context)
        let paidStatus = paidAmounts.mapValues(\.count)
        let paidDayKeys = paidAmounts.mapValues { infos in
            Set(infos.map { ScheduledPaymentNotificationTracker.dateKeyString(from: $0.date) })
        }

        await notifyOverduePayments(payments: payments, paidStatus: paidStatus, today: today)
        await notifyDuePayments(context: context, paidDayKeys: paidDayKeys, today: today)
        await notifyUpcomingPayments(payments: payments, paidStatus: paidStatus, today: today)

        // Re-verificación ADYACENTE al save (patrón gate-junto-al-save del repo): entre el
        // gate de entrada y aquí hubo N awaits al notification center — un import de CloudKit
        // pudo arrancar en esa ventana. Diferir es seguro: las marcas del tracker (UserDefaults)
        // ya están commiteadas, solo se pospone `lastNotifiedDate` (write-only).
        guard isImportQuiescent() else {
            SaveBreadcrumb.deferred("ScheduledPaymentNotificationService.checkAll.save", "import started mid-window")
            return
        }
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("ScheduledPaymentNotificationService: Error saving context: \(error)")
            #endif
        }
    }

    // MARK: - Notification Checks

    /// Notify payments that are due TODAY.
    ///
    /// Fuente: los `InboxDraft` pending MATERIALIZADOS por `ScheduledPaymentDraftService`
    /// (no el calculador de ocurrencias) — se notifica EXACTAMENTE lo que está en la bandeja,
    /// cerrando la divergencia de fuentes de fecha del ticket ("notificado sin draft").
    /// El filtro de fecha va EN MEMORIA: `draft.date` es opcional y coalescarlo en un
    /// `#Predicate` genera TERNARY que el SQL de SwiftData no implementa (regla del repo).
    private func notifyDuePayments(context: ModelContext, paidDayKeys: [String: Set<String>], today: Date) async {
        let pendingStatus = "pending"
        let descriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> {
                $0.statusRaw == pendingStatus && $0.sourceScheduledPaymentID != nil
            }
        )

        let drafts: [InboxDraft]
        do {
            drafts = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentNotificationService: Error fetching pending drafts: \(error)")
            #endif
            return
        }

        // Supresión contra el canal AGENDADO, por PAGO (no día completo): la summary del día
        // solo cubre los pagos que existían cuando se agendó — uno creado DESPUÉS no estuvo
        // en su conteo y sí debe avisar. Vencidos/próximos no se suprimen (el summary solo
        // habla de hoy).
        let todayKey = ScheduledPaymentSummaryPlanner.dayKey(from: today)
        let summaryMarkDate = tracker.summaryScheduledDate(dayKey: todayKey)

        let calendar = Calendar.current
        for draft in drafts {
            guard let draftDate = draft.date, calendar.isDate(draftDate, inSameDayAs: today) else { continue }
            guard let idString = draft.sourceScheduledPaymentID,
                  let paymentUUID = UUID(uuidString: idString) else { continue }

            var paymentDescriptor = FetchDescriptor<ScheduledPayment>(
                predicate: #Predicate { $0.id == paymentUUID }
            )
            paymentDescriptor.fetchLimit = 1

            let payment: ScheduledPayment
            do {
                guard let found = try context.fetch(paymentDescriptor).first else { continue }
                payment = found
            } catch {
                #if DEBUG
                print("ScheduledPaymentNotificationService: Error resolving payment for draft: \(error)")
                #endif
                continue
            }

            // Los drafts se materializan sin mirar notifyOnDueDate — el opt-in per-pago se
            // aplica aquí. isActive como cinturón (draft pending huérfano de un pago pausado).
            guard payment.isActive, payment.notifyOnDueDate else { continue }
            // Cubierto por la summary del día (existía al agendarla) → la oportunista calla.
            if let markDate = summaryMarkDate, payment.createdAt <= markDate { continue }
            // Pagado HOY (por-ocurrencia, no por-mes): no re-avisar lo ya cubierto.
            if paidDayKeys[payment.id.uuidString]?.contains(todayKey) == true { continue }

            guard !tracker.hasNotifiedForDate(
                paymentID: payment.id,
                date: today,
                type: .dueDate
            ) else { continue }

            guard await sendPaymentNotification(payment: payment, type: .dueToday) else { continue }
            tracker.markNotified(paymentID: payment.id, date: today, type: .dueDate)
            payment.lastNotifiedDate = today
        }
    }

    /// Notify payments that are due in X days (based on notifyDaysBefore)
    private func notifyUpcomingPayments(payments: [ScheduledPayment], paidStatus: [String: Int], today: Date) async {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: today) ?? today

        for payment in payments {
            guard payment.notifyDaysBefore > 0 else { continue }

            let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams, month: today
            )

            for date in dates where date <= sevenDaysFromNow {
                let startOfDueDate = calendar.startOfDay(for: date)
                let daysUntilDue = calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate).day ?? 0
                guard daysUntilDue == payment.notifyDaysBefore else { continue }
                guard !payment.isDateSkipped(date) else { continue }
                guard !isPaid(payment, paidStatus: paidStatus) else { continue }

                guard !tracker.hasNotifiedForDate(
                    paymentID: payment.id,
                    date: today,
                    type: .daysBefore
                ) else { continue }

                guard await sendPaymentNotification(payment: payment, type: .dueSoon(days: daysUntilDue)) else { continue }
                tracker.markNotified(paymentID: payment.id, date: today, type: .daysBefore)
            }
        }
    }

    /// Notify OVERDUE payments (user didn't open app for days)
    private func notifyOverduePayments(payments: [ScheduledPayment], paidStatus: [String: Int], today: Date) async {
        let calendar = Calendar.current
        var notificationCount = 0

        for payment in payments {
            guard notificationCount < maxOverdueNotifications else { break }
            guard payment.notifyOnDueDate else { continue }

            guard calendar.compare(payment.nextDueDate, to: today, toGranularity: .day) == .orderedAscending else {
                continue
            }

            guard !payment.isDateSkipped(payment.nextDueDate) else { continue }
            guard !isPaid(payment, paidStatus: paidStatus) else { continue }

            guard !tracker.hasNotifiedForDate(
                paymentID: payment.id,
                date: payment.nextDueDate,
                type: .overdue
            ) else { continue }

            guard await sendPaymentNotification(payment: payment, type: .overdue) else { continue }
            tracker.markNotified(paymentID: payment.id, date: payment.nextDueDate, type: .overdue)
            notificationCount += 1
        }
    }

    private func isPaid(_ payment: ScheduledPayment, paidStatus: [String: Int]) -> Bool {
        (paidStatus[payment.id.uuidString] ?? 0) > 0
    }

    // MARK: - Notification Window (gate honesto)

    func gateDecision(context: ModelContext, now: Date = .now) -> ScheduledPaymentNotificationGateLogic.Decision {
        ScheduledPaymentNotificationGateLogic.decide(itemState: fetchItemState(context: context), now: now)
    }

    private func fetchItemState(context: ModelContext) -> ScheduledPaymentNotificationGateLogic.ItemState {
        let typeRaw = "scheduledPayments"
        let descriptor = FetchDescriptor<NotificationItem>(
            predicate: #Predicate { $0.typeRaw == typeRaw }
        )

        do {
            let items = try context.fetch(descriptor)
            // Con duplicados (race R9 pre-dedupe) manda el activo, como en deduplicateNotifications.
            guard let item = items.first(where: { $0.isActive }) ?? items.first else { return .absent }
            return item.isActive ? .active(hour: item.hour, minute: item.minute) : .inactive
        } catch {
            #if DEBUG
            print("ScheduledPaymentNotificationService: Error fetching notification config: \(error)")
            #endif
            return .fetchError
        }
    }

    // MARK: - Daily Summary Replan (canal AGENDADO del modelo híbrido, decisión owner D1)

    /// Hook de 1 línea para mutaciones de pagos (crear/editar/borrar/skip/aprobación) y
    /// para el toggle/hora del item: re-plan fire-and-forget, idempotente.
    func requestSummaryReplan() {
        Task { await replanSummaries() }
    }

    private var replanInFlight = false
    private var replanQueuedRerun = false

    /// Recalcula y reemplaza las summaries diarias agendadas ("Tienes N pagos planificados
    /// para hoy") según el estado actual de pagos + item. Convergencia idempotente: corre en
    /// cada boot/foreground (`ensureNotificationsScheduled`) y tras cada mutación local.
    /// Cambios REMOTOS (CloudSync) convergen en el próximo foreground — residual documentado.
    ///
    /// SINGLE-FLIGHT + re-corrida: dos replans intercalados en los awaits del notification
    /// center dejaban ganar al que COMPLETABA último, no al más nuevo (los adds stale de un
    /// replan viejo re-agendaban la summary de un pago recién borrado — hallazgo del review
    /// adversarial). Uno solo en vuelo; el que llega tarde encola una re-corrida que parte
    /// del estado FRESCO del modelo.
    func replanSummaries() async {
        if replanInFlight {
            replanQueuedRerun = true
            return
        }
        replanInFlight = true
        defer { replanInFlight = false }
        repeat {
            replanQueuedRerun = false
            await performSummaryReplan()
        } while replanQueuedRerun
    }

    private func performSummaryReplan() async {
        guard let context = modelContext else { return }

        let now = Date.now
        let todayKey = ScheduledPaymentSummaryPlanner.dayKey(from: now)
        let todayMarked = tracker.hasSummaryScheduled(dayKey: todayKey)

        let plans: [ScheduledPaymentSummaryPlanner.DayPlan]
        switch fetchItemState(context: context) {
        case .fetchError:
            // Estado desconocido: no tocar nada (ni pendientes ni marcas). Próximo pass.
            return

        case .inactive, .absent:
            // Toggle honesto: OFF = plan vacío ⇒ el replace limpia lo agendado. El reconcile
            // decide sobre la marca de hoy: si el pending de hoy se retiró SIN disparar, la
            // marca cae (el fallback oportunista vuelve a ser elegible si el toggle regresa
            // a ON cruzando la hora); si hoy ya había disparado, se conserva (anti doble-banner).
            plans = []

        case .active(let hour, let minute):
            let payments = fetchActivePayments(context: context)
            let inputs = payments.map { payment in
                ScheduledPaymentSummaryPlanner.PaymentInput(
                    params: payment.dateCalculatorParams,
                    notifyOnDueDate: payment.notifyOnDueDate,
                    skippedDateKeys: payment.skippedDates
                )
            }
            plans = ScheduledPaymentSummaryPlanner.plan(
                payments: inputs, hour: hour, minute: minute, now: now
            )
        }

        let outcome = await replaceSummaries(plans, todayKey: todayKey, todayAlreadyMarked: todayMarked)
        tracker.reconcileSummaryMarks(
            scheduledDayKeys: outcome.scheduledDayKeys,
            attemptedDayKeys: outcome.attemptedDayKeys,
            removedPendingDayKeys: outcome.removedPendingDayKeys,
            todayKey: todayKey,
            now: now
        )
    }

    private func replaceSummaries(
        _ plans: [ScheduledPaymentSummaryPlanner.DayPlan],
        todayKey: String,
        todayAlreadyMarked: Bool
    ) async -> NotificationService.SummaryReplaceOutcome {
        if let override = replaceSummariesOverride {
            return await override(plans, todayKey, todayAlreadyMarked)
        }
        return await NotificationService.shared.replaceScheduledPaymentSummaries(
            plans, todayKey: todayKey, todayAlreadyMarked: todayAlreadyMarked
        )
    }

    // MARK: - One-shot: toggle maestro honesto (decisión owner D2, 2026-07-22)

    /// Key del sentinel del flip. NO añadir a `DataWipeService.removeUserPreferenceKeys`:
    /// debe sobrevivir los wipes (tras un wipe el item se re-seedea ya activo y el flip es
    /// no-op; si la key muriera con el store VIVO, re-flipearía un OFF deliberado del usuario).
    static let masterToggleFlipKey = "scheduledPaymentsMasterToggleFlipped"

    /// El gate horario pasó de falla-abierto a honesto: item inactivo = silencio. Como el
    /// default de fábrica era `isActive: false` y aun así los usuarios recibían notifs, este
    /// one-shot activa el item existente para no cortarles los recordatorios. El seed nuevo
    /// (`NotificationItem.createDefaults` + onboarding) ya nace activo.
    ///
    /// Endurecimientos del review adversarial (2026-07-22):
    /// - El sentinel se ESPEJA en `NSUbiquitousKeyValueStore`: el `NotificationItem` viaja
    ///   por CloudKit pero `UserDefaults` muere con la desinstalación — sin el espejo, una
    ///   reinstalación (o un device nuevo) re-flipearía un OFF DELIBERADO del usuario.
    /// - Con CERO items NO se quema el sentinel: en el primer launch pre-onboarding el item
    ///   aún no existe; quemarlo ahí dejaba el one-shot cerrado antes de tener nada que
    ///   evaluar (y si el seed sembrara OFF, al usuario nuevo en silencio permanente).
    static func flipMasterToggleIfNeeded(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        // La PUERTA y no el store crudo (frontera M1, 2026-08-12): en sesión secundaria este espejo
        // cae en el iCloud del DUEÑO y le quema el one-shot del interruptor maestro con la decisión
        // de otra persona. Era la OCTAVA vía y no estaba en ningún inventario.
        ubiquitous: OwnerKeyValueWriting? = OwnerKeyValueStore.shared,
        isQuiescent: (() -> Bool)? = nil
    ) {
        if defaults.bool(forKey: masterToggleFlipKey) { return }
        if ubiquitous?.bool(forKey: masterToggleFlipKey) == true {
            // Reinstalación/device nuevo con flip ya hecho en la cuenta: sanar el espejo
            // local y respetar el estado sincronizado del item (incl. un OFF deliberado).
            defaults.set(true, forKey: masterToggleFlipKey)
            return
        }

        // Gate de quiescencia: save del store personal — diferir durante el import del restore
        // SIN marcar el sentinel (idempotente: reintenta en el próximo boot/foreground).
        guard isQuiescent?() ?? iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("ScheduledPaymentNotificationService.flipMasterToggle", "import not quiescent")
            return
        }

        let typeRaw = "scheduledPayments"
        let descriptor = FetchDescriptor<NotificationItem>(
            predicate: #Predicate { $0.typeRaw == typeRaw }
        )

        do {
            let items = try context.fetch(descriptor)
            guard let item = items.first else { return }
            if items.allSatisfy({ !$0.isActive }) {
                item.isActive = true
                SaveBreadcrumb.willSave("ScheduledPaymentNotificationService.flipMasterToggle")
                try context.save()
                SaveBreadcrumb.didSave("ScheduledPaymentNotificationService.flipMasterToggle")
            }
            // A partir de aquí, OFF = decisión del usuario (local + espejo de cuenta).
            defaults.set(true, forKey: masterToggleFlipKey)
            ubiquitous?.setBool(true, forKey: masterToggleFlipKey)
        } catch {
            // Fetch/save fallido → NO marcar; reintenta en el próximo pass.
            #if DEBUG
            print("ScheduledPaymentNotificationService: Error in master toggle flip: \(error)")
            #endif
        }
    }

    // MARK: - Private

    private enum PaymentNotificationType {
        case dueToday
        case dueSoon(days: Int)
        case overdue
    }

    private func sendPaymentNotification(payment: ScheduledPayment, type: PaymentNotificationType) async -> Bool {
        let currencySymbol = CurrencyUtils.symbol(for: payment.currencyCode)
        let estimatePrefix = payment.isVariableAmount ? "≈ " : ""
        let formattedAmount = "\(estimatePrefix)\(currencySymbol)\(payment.amount.formatted(.number.precision(.fractionLength(0...2))))"
        let isIncome = payment.transactionType == "income"

        let message: String
        switch type {
        case .dueToday:
            message = isIncome
                ? L10n.Notifications.ScheduledPayment.dueTodayIncome(formattedAmount, payment.name)
                : L10n.Notifications.ScheduledPayment.dueToday(payment.name, formattedAmount)
        case .dueSoon(let days):
            message = isIncome
                ? L10n.Notifications.ScheduledPayment.dueSoonIncome(days, formattedAmount, payment.name)
                : L10n.Notifications.ScheduledPayment.dueSoon(days, payment.name, formattedAmount)
        case .overdue:
            message = isIncome
                ? L10n.Notifications.ScheduledPayment.overdueIncome(formattedAmount, payment.name)
                : L10n.Notifications.ScheduledPayment.overdue(payment.name, formattedAmount)
        }

        return await send(title: payment.name, body: message, deepLink: "scheduledPayments")
    }

    // MARK: - Credit Card Payment Notifications

    /// Check accounts with credit card payment reminders and notify if today is payment day.
    ///
    /// Asimetría DELIBERADA con el toggle maestro: el opt-in de la tarjeta es per-account
    /// (editor de cuentas), independiente del item `scheduledPayments` — con el item
    /// `inactive`/`absent` la tarjeta SIGUE notificando (silenciarla rompería un opt-in que
    /// el usuario configuró en otra superficie). Lo que SÍ comparte es la VENTANA HORARIA
    /// cuando el item está activo (era la notif "de las 8am" del ticket) y el fail-closed
    /// ante fetch-error.
    func checkAndNotifyCreditCardPayments() async {
        guard let context = modelContext else { return }
        guard await isAuthorized() else { return }

        switch gateDecision(context: context) {
        case .waitForHour, .deferFetchError:
            return
        case .send, .silenced:
            break
        }

        let accounts = fetchCreditCardAccounts(context: context)
        let today = Date.now
        let dayOfMonth = Calendar.current.component(.day, from: today)

        for account in accounts {
            guard account.creditCardPaymentDay == dayOfMonth else { continue }

            guard !tracker.hasNotifiedCreditCard(accountID: account.shortcutID, date: today) else { continue }

            let message = L10n.Account.CreditCard.paymentNotification(account.name)
            guard await send(title: account.name, body: message, deepLink: "accounts") else { continue }

            tracker.markNotifiedCreditCard(accountID: account.shortcutID, date: today)
        }
    }

    private func fetchCreditCardAccounts(context: ModelContext) -> [Account] {
        let creditCardType = AccountType.creditCard.rawValue
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate {
                $0.type == creditCardType && $0.creditCardPaymentReminder == true
            }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentNotificationService: Error fetching credit card accounts: \(error)")
            #endif
            return []
        }
    }

    private func fetchActivePayments(context: ModelContext) -> [ScheduledPayment] {
        let descriptor = FetchDescriptor<ScheduledPayment>(
            predicate: #Predicate { $0.isActive }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentNotificationService: Error fetching payments: \(error)")
            #endif
            return []
        }
    }
}
