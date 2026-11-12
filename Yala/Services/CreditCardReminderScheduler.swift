//
//  CreditCardReminderScheduler.swift
//  Yala
//
//  El aviso antes de pagar la tarjeta, PROGRAMADO (card nmtk, D3-A de Jürgen). Hasta 2.2 el aviso salía solo si se abría
//  la app el mismo día de pago, y sin importe. Ahora se deja en el centro de notificaciones de iOS para el día que eligió
//  el usuario (el mismo día, 1, 3 o 5 días antes), a la hora del resumen de pagos planificados si lo tiene puesto (las 9:00
//  si no), con lo facturado del último corte: «Paga S/ 1,240.00 antes del jueves 5.». Tocarlo abre la ficha de la tarjeta.
//
//  Cómo converge: `replan()` retira TODO lo programado con su prefijo y vuelve a programar desde el estado actual. Corre en
//  cada arranque y vuelta a primer plano (`AppBootstrapper.ensureNotificationsScheduled`) y tras cada cambio de datos
//  (`SessionState.incrementDataVersion`: editar la tarjeta, registrarle un pago). Un pago que deja lo facturado en 0 retira
//  el aviso: «si ya está pagado, no se manda». Un cambio que llega por sync se recoge en el siguiente primer plano.
//  Single-flight con re-corrida, como `replanSummaries`: dos replans intercalados en los `await` del centro dejaban ganar
//  al que terminaba último, no al más nuevo.
//
//  El hueco de hoy: si el aviso de HOY ya debía haber salido y nunca se programó (la tarjeta se configuró después de esa
//  hora), sale al momento, una vez. La marca del día (`ScheduledPaymentNotificationTracker`, `creditCardNotif_<id>_<día>`)
//  se pone al programarlo o al mandarlo, así que un aviso que ya salió no se repite; y se RETIRA si el pendiente se quita
//  sin haber disparado (cambió la hora o la antelación), o el aviso de hoy movido a una hora pasada se perdía.
//  `rescheduleAllNotifications` (Ajustes › Notificaciones) no toca estos pendientes: no los vuelve a programar.
//
//  Lo que respeta: la quiescencia del import de CloudKit (con el import a medias el importe sería parcial: no se toca nada
//  y se reintenta en el siguiente pase) y el fallo de lectura del ajuste de pagos (estado desconocido: tampoco se toca). El
//  toggle del resumen de pagos NO lo silencia: el aviso de la tarjeta es un opt-in propio, en su formulario (la asimetría
//  de siempre). Solo comparte su hora.
//

import Foundation
import SwiftData

@MainActor
final class CreditCardReminderScheduler {
    static let shared = CreditCardReminderScheduler()

    static let identifierPrefix = "creditCardReminder_"

    private var modelContext: ModelContext?
    let tracker: ScheduledPaymentNotificationTracker

    // MARK: - Seams de test (nil en producción)

    /// Sustituye a `NotificationService.replaceCreditCardReminders`. Devuelve los identificadores que quedaron programados.
    var replaceOverride: ((_ requests: [NotificationService.CreditCardReminderRequest]) async
        -> NotificationService.CreditCardReplaceOutcome)?
    /// Sustituye el envío inmediato del aviso de hoy. `true` = iOS lo aceptó.
    var sendOverride: ((_ title: String, _ body: String, _ deepLink: String?) async -> Bool)?
    var isQuiescentOverride: (() -> Bool)?
    var isAuthorizedOverride: (() async -> Bool)?

    private init() { tracker = .shared }

    /// Init de test: tracker aislado. No usar en producción.
    init(tracker: ScheduledPaymentNotificationTracker) { self.tracker = tracker }

    func setContext(_ context: ModelContext?) { modelContext = context }

    // MARK: - Replan

    private var inFlight = false
    private var queuedRerun = false

    /// Hook de una línea para quien cambia datos: replan en segundo plano, idempotente. Sin contexto (antes del arranque o
    /// en tests que no lo fijan) no hace nada.
    func requestReplan() {
        guard modelContext != nil else { return }
        Task { await replan() }
    }

    func replan(now: () -> Date = { .now }, calendar: Calendar = .current) async {
        if inFlight {
            queuedRerun = true
            return
        }
        inFlight = true
        defer { inFlight = false }
        repeat {
            queuedRerun = false
            await performReplan(now: now(), calendar: calendar)
        } while queuedRerun
    }

    private func performReplan(now: Date, calendar: Calendar) async {
        guard let context = modelContext else { return }
        guard isImportQuiescent() else {
            SaveBreadcrumb.deferred("CreditCardReminderScheduler.replan", "import not quiescent")
            return
        }
        guard await isAuthorized() else { return }

        let hour: Int
        let minute: Int
        switch ScheduledPaymentNotificationService.fetchSummaryItemState(context: context) {
        case .fetchError:
            return
        case .active(let h, let m):
            hour = h
            minute = m
        case .inactive, .absent:
            hour = CreditCardStatementLogic.defaultReminderHour
            minute = CreditCardStatementLogic.defaultReminderMinute
        }

        let accounts: [Account]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>())
        } catch {
            #if DEBUG
            print("CreditCardReminderScheduler: Error fetching accounts: \(error)")
            #endif
            return
        }

        var requests: [NotificationService.CreditCardReminderRequest] = []
        var dueToday: [(card: Account, reminder: CreditCardStatementLogic.Reminder)] = []
        // Card p0iu: con «Solo grupos» elegido, los avisos personales esperan. Plan vacío: retira lo programado (y sus
        // marcas, abajo) y no manda nada; volver a Yala completo replanifica (`UsageModeService`).
        for card in PersonalRemindersPause.isPaused() ? [] : Self.remindableCards(accounts) {
            let members = card.members
            let head = card.head
            let reminders = CreditCardStatementLogic.reminders(
                statementDay: head.creditCardStatementDay,
                paymentDay: head.creditCardPaymentDay,
                leadDays: head.creditCardReminderDaysBefore,
                hour: hour, minute: minute, now: now, calendar: calendar
            ) { cycle in
                members.map { member in
                    let statement = CreditCardStatementLogic.statement(
                        entries: Self.entries(of: member), cycle: cycle, now: now, calendar: calendar)
                    return CreditCardStatementLogic.LineAmount(
                        amount: statement.billed, currencyCode: normalizeCurrencyCode(member.currencyCode))
                }
            }
            for reminder in reminders {
                if reminder.fireDate > now {
                    requests.append(request(for: head, reminder: reminder, calendar: calendar))
                } else if calendar.isDate(reminder.day, inSameDayAs: now) {
                    dueToday.append((head, reminder))
                }
            }
        }

        let outcome = await replace(requests)
        // Lo que estaba pendiente y se retiró sin volver a programarse no disparó: su marca se retira, o el aviso de hoy
        // movido a una hora ya pasada no saldría nunca. Lo que se vuelve a programar conserva (o recibe) la suya.
        for identifier in outcome.removedPending.subtracting(outcome.scheduled) {
            guard let (accountID, day) = Self.parse(identifier, calendar: calendar) else { continue }
            tracker.clearNotifiedCreditCard(accountID: accountID, date: day)
        }
        for request in requests where outcome.scheduled.contains(request.identifier) {
            tracker.markNotifiedCreditCard(accountID: request.accountID, date: request.day)
        }

        // El aviso de hoy ya pasado que no salió (no estaba marcado: ni disparó ni se programó) sale ahora, una vez.
        let dueNow = dueToday.filter { !tracker.hasNotifiedCreditCard(accountID: $0.card.shortcutID, date: $0.reminder.day) }
        for item in dueNow {
            let content = Self.content(for: item.card, reminder: item.reminder, calendar: calendar)
            guard await send(title: content.title, body: content.body,
                             deepLink: AlertDeepLink.account.deepLink(for: item.card.shortcutID)) else { continue }
            tracker.markNotifiedCreditCard(accountID: item.card.shortcutID, date: item.reminder.day)
        }
    }

    // MARK: - Qué tarjetas avisan

    /// Las tarjetas de crédito con el aviso puesto, con sus líneas. Los ajustes son de la principal
    /// (`AccountCardLogic.ownsCardSettings`): una línea no avisa por su cuenta, avisa su tarjeta con el importe de cada
    /// divisa. Las archivadas no avisan.
    static func remindableCards(_ accounts: [Account]) -> [AccountCard<Account>] {
        let roles = accounts.lineRoles
        let live = accounts.filter { !$0.isArchived }
        return live.accountCards(roles: roles).filter { card in
            AccountType(rawValue: card.head.type) == .creditCard
                && card.head.creditCardPaymentReminder
                && AccountCardLogic.ownsCardSettings(roles[card.head.shortcutID])
        }
    }

    /// Los movimientos de una línea para el estado de cuenta. Lo que espera su borrado con «Deshacer» no cuenta, como en
    /// la ficha.
    static func entries(of account: Account) -> [CreditCardStatementLogic.Entry] {
        RecordPendingDeletion.shared.visible(account.transactions ?? []).map {
            CreditCardStatementLogic.Entry(date: $0.date, amount: $0.amount,
                                           isBalanceAdjustment: isBalanceAdjustment($0.balanceAdjustmentType))
        }
    }

    /// Solo el saldo inicial y el ajuste de saldo. NO `balanceAdjustmentType != nil`: las dos patas de una transferencia
    /// llevan `"transfer"` en ese campo, y una transferencia a la tarjeta es justo cómo se paga (lo cazó la review).
    static func isBalanceAdjustment(_ type: String?) -> Bool {
        type == InitialBalanceService.typeInitialBalance || type == InitialBalanceService.typeAdjustment
    }

    // MARK: - El texto

    static func content(for card: Account, reminder: CreditCardStatementLogic.Reminder,
                        calendar: Calendar) -> (title: String, body: String) {
        let payment = reminderDateFormatter(calendar: calendar).string(from: reminder.paymentDate)
        guard let amounts = reminder.amounts, !amounts.isEmpty else {
            let body = reminder.leadDays == 0
                ? L10n.Account.CreditCard.paymentNotification(card.name)
                : L10n.CreditCardStatement.reminderPayByNoAmount(payment)
            return (card.name, body)
        }
        let formatted = amounts
            .map { YalaFormatterStatic.currency(value: $0.amount, currencyCode: $0.currencyCode) }
            .joined(separator: " · ")
        let body = reminder.leadDays == 0
            ? L10n.CreditCardStatement.reminderDueToday(formatted)
            : L10n.CreditCardStatement.reminderPayBy(formatted, payment)
        return (card.name, body)
    }

    /// «jueves 5»: el día de la semana y el número, en el idioma de la app.
    static func reminderDateFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = AppLocale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEEd")
        return formatter
    }

    private func request(for card: Account, reminder: CreditCardStatementLogic.Reminder,
                         calendar: Calendar) -> NotificationService.CreditCardReminderRequest {
        let content = Self.content(for: card, reminder: reminder, calendar: calendar)
        return NotificationService.CreditCardReminderRequest(
            identifier: Self.identifierPrefix + card.shortcutID.uuidString + "_"
                + CreditCardStatementLogic.dayKey(reminder.day, calendar: calendar),
            accountID: card.shortcutID,
            day: reminder.day,
            title: content.title,
            body: content.body,
            deepLink: AlertDeepLink.account.deepLink(for: card.shortcutID),
            fireDate: reminder.fireDate,
            calendar: calendar
        )
    }

    /// `creditCardReminder_<UUID>_<yyyyMMdd>` → la tarjeta y el día.
    static func parse(_ identifier: String, calendar: Calendar) -> (UUID, Date)? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        let rest = identifier.dropFirst(identifierPrefix.count)
        guard let separator = rest.lastIndex(of: "_"),
              let accountID = UUID(uuidString: String(rest[..<separator]))
        else { return nil }
        let key = rest[rest.index(after: separator)...]
        guard key.count == 8, let year = Int(key.prefix(4)), let month = Int(key.dropFirst(4).prefix(2)),
              let day = Int(key.suffix(2)),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return nil }
        return (accountID, date)
    }

    // MARK: - Efectos

    private func isImportQuiescent() -> Bool {
        isQuiescentOverride?() ?? iCloudSyncService.shared.isImportQuiescent
    }

    private func isAuthorized() async -> Bool {
        if let override = isAuthorizedOverride { return await override() }
        return await NotificationService.shared.isAuthorized()
    }

    private func replace(_ requests: [NotificationService.CreditCardReminderRequest]) async
        -> NotificationService.CreditCardReplaceOutcome {
        if let override = replaceOverride { return await override(requests) }
        return await NotificationService.shared.replaceCreditCardReminders(requests)
    }

    private func send(title: String, body: String, deepLink: String?) async -> Bool {
        if let override = sendOverride { return await override(title, body, deepLink) }
        return await NotificationService.shared.sendNotification(title: title, body: body, deepLink: deepLink)
    }
}
