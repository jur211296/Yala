//
//  ReportNotificationService.swift
//  Yala
//
//  Service for sending report notifications with real calculated data.
//  Uses existing calculators: BalanceHelper, TopSpendingCategoriesCalculator.
//

import Foundation
import SwiftData

/// Data calculated for a report notification
struct ReportData {
    let balance: Double
    let totalExpense: Double
    let totalIncome: Double
    let topCategory: String?
    /// `true` si hubo ≥1 TX clasificada de ese tipo en el período. Distingue
    /// "no hubo actividad del tipo" de "el neto quedó en 0" (p.ej. gasto −100 +
    /// reembolso +100) → el empty-check del copy se basa en actividad, no en neto.
    let hasExpenseActivity: Bool
    let hasIncomeActivity: Bool
}

/// Totales income/expense de un reporte + señal de actividad por tipo,
/// producidos por `ReportNotificationService.accumulateReportTotals`.
struct ReportTotals {
    let totalIncome: Decimal
    let totalExpense: Decimal
    let hasIncomeActivity: Bool
    let hasExpenseActivity: Bool
}

/// Service for sending report notifications with real financial data
@MainActor
final class ReportNotificationService {
    static let shared = ReportNotificationService()

    private init() {}

    /// Guard flag to prevent concurrent sendDueReports calls (race between bootstrap and becameActive)
    private var isSendingReports = false

    // MARK: - Test seams (nil/default en producción; patrón de closures inyectables del repo,
    // espejo de `ScheduledPaymentNotificationService`). El singleton `.shared` no se toca en tests.

    /// Sustituye el envío real (`NotificationService.sendNotification`) en tests.
    /// Mismo contrato: `true` = iOS aceptó el request.
    var sendOverride: ((_ title: String, _ body: String, _ deepLink: String?) async -> Bool)?
    /// Sustituye el check de permisos del sistema en tests.
    var isAuthorizedOverride: (() async -> Bool)?
    /// Sustituye la lectura de quiescencia del import en tests.
    var isQuiescentOverride: (() -> Bool)?
    /// Sustituye la lectura del modo Solo Gastos en tests.
    var expensesOnlyOverride: (() -> Bool)?

    #if DEBUG
    /// Instancia aislada para tests (evita contaminar el singleton `.shared`). Jamás en producción.
    static func makeForTesting() -> ReportNotificationService { ReportNotificationService() }
    #endif

    private func send(title: String, body: String, deepLink: String?) async -> Bool {
        if let override = sendOverride { return await override(title, body, deepLink) }
        return await NotificationService.shared.sendNotification(title: title, body: body, deepLink: deepLink)
    }

    private func isAuthorized() async -> Bool {
        if let override = isAuthorizedOverride { return await override() }
        return await NotificationService.shared.isAuthorized()
    }

    private func isImportQuiescent() -> Bool {
        isQuiescentOverride?() ?? iCloudSyncService.shared.isImportQuiescent
    }

    /// Modo Solo Gastos. Lee `UserDefaults` directo (no `SessionState.shared`): el valor
    /// está respaldado 1:1 por esa key (`SessionState`/`AppPreferences`) y así la capa
    /// Service no depende del singleton de UI ni de su inicialización.
    private func isExpensesOnly() -> Bool {
        expensesOnlyOverride?() ?? UserDefaults.standard.bool(forKey: AppPreferences.Keys.expensesOnlyMode)
    }

    /// En Solo Gastos, los tipos de dato income/balance quedan huérfanos de config
    /// (el editor los oculta/coacciona, pero un `NotificationItem` guardado antes de
    /// activar el modo conserva su `dataType`). Coacciona income/balance → expenses en
    /// el send path (paridad con `NotificationEditorSheet.availableDataTypes`). Solo lógica.
    static func effectiveDataType(_ dataType: ReportDataType, expensesOnly: Bool) -> ReportDataType {
        guard expensesOnly else { return dataType }
        switch dataType {
        case .income, .balance: return .expenses
        case .expenses, .topCategory: return dataType
        }
    }

    // MARK: - Public Methods

    /// Sends report notifications that are due based on their configuration
    func sendDueReports(context: ModelContext) async {
        guard !isSendingReports else { return }
        isSendingReports = true
        defer { isSendingReports = false }
        guard await isAuthorized() else { return }

        // Gate de quiescencia: persiste `NotificationItem.lastNotifiedDate` (store personal); diferir
        // durante el import del restore (idempotente: se reevalúa al asentar / próximo arranque).
        guard isImportQuiescent() else {
            SaveBreadcrumb.deferred("ReportNotificationService.sendDueReports", "import not quiescent")
            return
        }

        let reports = fetchActiveReportNotifications(context: context)
        var sentCount = 0

        let expensesOnly = isExpensesOnly()

        for report in reports {
            guard Self.shouldSendNow(report) else { continue }

            // Coacción de solo-display en runtime (Solo Gastos): income/balance → expenses.
            // No muta el config persistido → sin `save()` extra ni riesgo de quiescencia.
            var effectiveConfig = report.reportConfig
            effectiveConfig.dataType = Self.effectiveDataType(report.reportConfig.dataType, expensesOnly: expensesOnly)

            let data = calculateReportData(config: effectiveConfig, type: report.notificationType, context: context)

            let delivered = await send(
                title: report.localizedName,
                body: Self.formatReportBody(effectiveConfig, reportType: report.notificationType, data: data),
                deepLink: "statistics"
            )

            // Marca de dedup SOLO con entrega confirmada por iOS (paridad con
            // `ScheduledPaymentNotificationService`): un fallo silencioso — permisos revocados,
            // wipe personal armado, throttle de iOS — no debe suprimir el reporte hasta el próximo
            // período. Si no se entregó, el próximo pass lo reintenta.
            guard delivered else { continue }
            report.lastNotifiedDate = Date.now
            sentCount += 1
        }

        // Save changes if any notifications were sent
        if sentCount > 0 {
            do {
                SaveBreadcrumb.willSave("ReportNotificationService.sendDueReports")
                try context.save()
                SaveBreadcrumb.didSave("ReportNotificationService.sendDueReports")
                #if DEBUG
                print("ReportNotificationService: Sent \(sentCount) report notifications")
                #endif
            } catch {
                #if DEBUG
                print("ReportNotificationService: Error saving lastNotifiedDate: \(error)")
                #endif
            }
        }
    }

    // MARK: - Timing Check

    /// Determines if the report should be sent now based on configuration
    /// Checks: 1) Not already notified today, 2) Within 30min window of scheduled time, 3) Correct day/weekday
    static func shouldSendNow(_ report: NotificationItem) -> Bool {
        let calendar = Calendar.current
        let now = Date.now
        let config = report.reportConfig

        // 1. Already notified today? Skip to avoid spam
        if let lastNotified = report.lastNotifiedDate,
           calendar.isDateInToday(lastNotified) {
            return false
        }

        // 2. Has the scheduled time passed today?
        // We accept any time after the scheduled time on the same day
        // (lastNotifiedDate check above prevents duplicates)
        guard let scheduledToday = calendar.date(
            bySettingHour: report.hour,
            minute: report.minute,
            second: 0,
            of: now
        ) else { return false }

        // Only send if we're past the scheduled time (same day)
        guard now >= scheduledToday else { return false }

        // 3. Check day/weekday based on notification type
        switch report.notificationType {
        case .dailyReport:
            // Daily: check selected weekdays
            let weekday = calendar.component(.weekday, from: now)
            let selectedWeekdays = report.selectedWeekdays
            return selectedWeekdays.isEmpty || selectedWeekdays.contains(weekday)

        case .weeklyReport:
            // Weekly: check if it's the configured day (sunday=1 or monday=2)
            let weekday = calendar.component(.weekday, from: now)
            let targetWeekday = config.dayPreference == .sunday ? 1 : 2
            return weekday == targetWeekday

        case .monthlyReport:
            // Monthly: check if it's first or last day of month
            let day = calendar.component(.day, from: now)
            if config.dayPreference == .firstDay {
                return day == 1
            } else {
                // Last day of month
                let range = calendar.range(of: .day, in: .month, for: now)
                return day == range?.count
            }

        default:
            return false
        }
    }

    // MARK: - Data Calculation

    private func calculateReportData(config: ReportConfig, type: NotificationType, context: ModelContext) -> ReportData {
        let interval = Self.getIntervalForReportType(config, type: type)
        let transactions = fetchTransactions(in: interval, context: context)
        let accounts = fetchAccounts(context: context)
        let currencyCode = CurrencyDefaults.currentPreferred

        // Balance del reporte: TC actual sobre saldo nativo (LiveBalanceCalculator)
        // en vez de suma de snapshots históricos.
        let balance = LiveBalanceCalculator.liveBalance(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: currencyCode
        )

        // Netea los gastos de grupo bridgeados a "mi parte". El fetch por rango
        // (`transactions`) trae AMBAS hermanas del bridge (comparten fecha).
        let adjustment = GroupBridgeStatsAdjustment.build(from: transactions, context: context)

        // Income/expense: clasificación por categoría + acumulación signed vía
        // helper puro (testeable sin ModelContext). Excluye balance adjustments y
        // cuentas no elegibles dentro del helper.
        let eligibleAccountIDs = Set(accounts.map { $0.persistentModelID })
        let totals = Self.accumulateReportTotals(
            transactions: transactions,
            eligibleAccountIDs: eligibleAccountIDs,
            currencyCode: currencyCode,
            adjustment: adjustment
        )

        // Get top category using TopSpendingCategoriesCalculator
        let topCategories = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: transactions,
            interval: interval,
            currencyCode: currencyCode,
            adjustment: adjustment
        )

        return ReportData(
            balance: balance,
            totalExpense: NSDecimalNumber(decimal: totals.totalExpense).doubleValue,
            totalIncome: NSDecimalNumber(decimal: totals.totalIncome).doubleValue,
            topCategory: topCategories.first?.category.name,
            hasExpenseActivity: totals.hasExpenseActivity,
            hasIncomeActivity: totals.hasIncomeActivity
        )
    }

    /// Acumula income/expense de las transacciones de un reporte. Clasifica por
    /// categoría (regla canónica `TransactionClassificationLogic`) y acumula
    /// *signed* (paridad con `CashFlowCalculator`): un monto de signo contrario a
    /// su categoría (reembolso) REDUCE el bucket. Excluye balance adjustments y
    /// cuentas no elegibles. Clasifica y acumula sobre el MISMO valor con signo.
    /// Pure-logic (sin `ModelContext`) para tests; el converter es inyectable.
    static func accumulateReportTotals(
        transactions: [TransactionItem],
        eligibleAccountIDs: Set<PersistentIdentifier>,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> ReportTotals {
        var totalIncome: Decimal = 0
        var totalExpense: Decimal = 0
        var hasIncomeActivity = false
        var hasExpenseActivity = false

        for tx in transactions {
            // Exclude balance adjustments (same as TrendDataProcessor)
            guard tx.balanceAdjustmentType == nil else { continue }
            // Filter by eligible accounts (consistent with BalanceHelper)
            guard let account = tx.account,
                  eligibleAccountIDs.contains(account.persistentModelID) else { continue }
            // Suprime la pata de préstamo derivada (bridge): mata el ingreso fantasma +lent.
            guard !adjustment.isSuppressed(tx) else { continue }

            let amount: Decimal
            // Check currency and convert if needed (BalanceHelper pattern); el signo
            // se preserva desde el monto ajustado (Caso A ⇒ `-myShare`).
            if tx.preferredCurrencyCode == currencyCode {
                amount = Decimal(adjustment.amountInPreferredCurrency(tx))
            } else {
                let sourceCurrency = CurrencyCode(rawValue: normalizeCurrencyCode(tx.currencyCode))
                    ?? (CurrencyCode(rawValue: currencyCode) ?? .usd)
                amount = converter.convert(
                    Decimal(adjustment.amount(tx)),
                    from: sourceCurrency.rawValue,
                    to: currencyCode,
                    on: tx.date
                )
            }

            // La categoría decide el bucket; acumulación signed sobre el mismo
            // `amount` (reembolso reduce). La actividad marca "hubo TX del tipo".
            if TransactionClassificationLogic.isIncome(tx) {
                totalIncome += amount
                hasIncomeActivity = true
            } else {
                totalExpense -= amount
                hasExpenseActivity = true
            }
        }

        return ReportTotals(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            hasIncomeActivity: hasIncomeActivity,
            hasExpenseActivity: hasExpenseActivity
        )
    }

    static func getIntervalForReportType(_ config: ReportConfig, type: NotificationType) -> DateInterval {
        let calendar = Calendar.current
        let now = Date.now

        // Daily: today only
        if type == .dailyReport {
            let todayStart = calendar.startOfDay(for: now)
            // R1: If now == startOfDay (exact midnight), use previous full day
            if now <= todayStart {
                let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
                return DateInterval(start: yesterdayStart, end: todayStart)
            }
            return DateInterval(start: todayStart, end: now)
        }

        // Weekly/Monthly: use config.dayPreference
        switch config.dayPreference {
        case .sunday, .monday:
            // Weekly: last 7 days
            let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return DateInterval(start: weekStart, end: now)
        case .firstDay:
            // First day of month: report previous month
            let currentMonthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            ) ?? now
            let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
            let previousMonthEnd = calendar.date(byAdding: .second, value: -1, to: currentMonthStart) ?? currentMonthStart
            return DateInterval(start: previousMonthStart, end: previousMonthEnd)
        case .lastDay:
            // Last day of month: report current month up to now
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            ) ?? now
            return DateInterval(start: monthStart, end: now)
        }
    }

    static func formatReportBody(_ config: ReportConfig, reportType: NotificationType, data: ReportData) -> String {
        let currencyCode = CurrencyDefaults.currentPreferred

        let period = reportType.periodKeySuffix

        // Snapshot al programar la notificación: el body se queda fijo en `UNNotificationContent`
        // — no es UI viva, no necesita reactividad.
        switch config.dataType {
        case .balance:
            let formatted = YalaFormatterStatic.currency(value: data.balance, currencyCode: currencyCode, forceFullPrecision: true)
            return L10n.Notifications.reportData(.balance, period: period, value: formatted)
        case .expenses:
            // "Vacío" = no hubo gastos del período, NO "el neto quedó en 0"
            // (un reembolso que cancela el gasto no debe disparar el copy vacío).
            if !data.hasExpenseActivity {
                switch reportType {
                case .dailyReport: return L10n.Notifications.emptyExpensesDaily
                case .weeklyReport: return L10n.Notifications.emptyExpensesWeekly
                case .monthlyReport: return L10n.Notifications.emptyExpensesMonthly
                default: return L10n.Notifications.emptyExpensesDaily
                }
            }
            let formatted = YalaFormatterStatic.currency(value: data.totalExpense, currencyCode: currencyCode, forceFullPrecision: true)
            return L10n.Notifications.reportData(.expenses, period: period, value: formatted)
        case .income:
            if !data.hasIncomeActivity {
                return L10n.Notifications.emptyIncome
            }
            let formatted = YalaFormatterStatic.currency(value: data.totalIncome, currencyCode: currencyCode, forceFullPrecision: true)
            return L10n.Notifications.reportData(.income, period: period, value: formatted)
        case .topCategory:
            guard let topCategory = data.topCategory else {
                return L10n.Notifications.emptyTopCategory
            }
            return L10n.Notifications.reportData(.topCategory, period: period, value: topCategory)
        }
    }

    // MARK: - Fetching

    private func fetchActiveReportNotifications(context: ModelContext) -> [NotificationItem] {
        let descriptor = FetchDescriptor<NotificationItem>(
            predicate: #Predicate {
                $0.isActive && (
                    $0.typeRaw == "dailyReport" ||
                    $0.typeRaw == "weeklyReport" ||
                    $0.typeRaw == "monthlyReport"
                )
            }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ReportNotificationService: Error fetching reports: \(error)")
            #endif
            return []
        }
    }

    private func fetchTransactions(in interval: DateInterval, context: ModelContext) -> [TransactionItem] {
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.date >= start && $0.date <= end }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ReportNotificationService: Error fetching transactions: \(error)")
            #endif
            return []
        }
    }

    private func fetchAccounts(context: ModelContext) -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { !$0.excludeFromStatistics }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ReportNotificationService: Error fetching accounts: \(error)")
            #endif
            return []
        }
    }
}
