//
//  BudgetAlertService.swift
//  Yala
//
//  Service for checking budgets and sending alerts when thresholds are crossed.
//

import Foundation
import SwiftData

/// Service for checking budgets and sending alerts when thresholds are crossed
@MainActor
@Observable
final class BudgetAlertService {
    static let shared = BudgetAlertService()

    private var modelContext: ModelContext?
    private var isChecking = false
    private let tracker: BudgetAlertTracker

    /// Sustituye el envío real (`NotificationService.sendNotification`) en tests.
    /// Mismo contrato: `true` = iOS aceptó el request.
    var sendOverride: ((_ budgetName: String, _ threshold: Int, _ spent: Double, _ limit: Double, _ currencyCode: String) async -> Bool)?

    private init() {
        self.tracker = .shared
    }

    /// Init de test — tracker aislado (`BudgetAlertTracker(defaults:)`). No usar en producción.
    init(tracker: BudgetAlertTracker) {
        self.tracker = tracker
    }

    func setContext(_ context: ModelContext?) {
        self.modelContext = context
    }

    // MARK: - Main Check Method

    /// Check all budgets with alerts enabled and notify if thresholds crossed
    func checkBudgetsAndNotify() async {
        // Check global toggle first (default false, enabled via onboarding)
        let globalEnabled = UserDefaults.standard.bool(forKey: "budgetAlertsEnabled")
        guard globalEnabled else { return }

        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        guard let context = modelContext else { return }

        // 1. Fetch budgets with alerts enabled
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.isActive && $0.alertEnabled }
        )

        let budgets: [Budget]
        do {
            budgets = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("BudgetAlertService: Error fetching budgets: \(error)")
            #endif
            return
        }

        guard !budgets.isEmpty else { return }

        // 2. Fetch transactions within budget periods (not all history)
        let earliestDate = budgets.compactMap { budget -> Date? in
            if let start = budget.startDate { return start }
            return Calendar.current.date(byAdding: .year, value: -1, to: Date.now)
        }.min() ?? Calendar.current.date(byAdding: .year, value: -1, to: Date.now) ?? Date.now
        let capturedDate = earliestDate
        let txDescriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.date >= capturedDate }
        )
        let transactions: [TransactionItem]
        do {
            transactions = try context.fetch(txDescriptor)
        } catch {
            #if DEBUG
            print("BudgetAlertService: Error fetching transactions: \(error)")
            #endif
            return
        }

        // 3. Check each budget
        // Neteo del bridge de grupos construido UNA vez del set amplio recién fetcheado.
        let adjustment = GroupBridgeStatsAdjustment.build(from: transactions, context: context)
        for budget in budgets {
            await checkBudget(budget, transactions: transactions, adjustment: adjustment)
        }
    }

    // MARK: - Budget Check

    private func checkBudget(_ budget: Budget, transactions: [TransactionItem], adjustment: GroupBridgeStatsAdjustment = .none) async {
        // Parse configured thresholds
        guard let thresholdsString = budget.alertThresholds else { return }
        let configuredThresholds = Set(
            thresholdsString.split(separator: ",").compactMap { component -> Int? in
                let trimmed = component.trimmingCharacters(in: .whitespaces)
                guard let value = Int(trimmed) else {
                    #if DEBUG
                    print("BudgetAlertService: Warning — unparseable threshold component: '\(component)'")
                    #endif
                    return nil
                }
                return value
            }
        )
        guard !configuredThresholds.isEmpty else { return }

        // Calculate spending
        let interval = getCurrentPeriodInterval(for: budget)
        let spending = calculateSpending(budget: budget, transactions: transactions, interval: interval, adjustment: adjustment)

        guard budget.limitAmount > 0 else { return }
        let percentage = (spending / budget.limitAmount) * 100.0

        // Get period key and check for new thresholds
        let periodKey = tracker.periodKey(for: budget)
        let newThresholds = tracker.getNewThresholds(
            budgetID: budget.id,
            periodKey: periodKey,
            currentPercentage: percentage,
            configuredThresholds: configuredThresholds
        )

        // Get currency for notification
        let currencyCode = budget.currencyCode

        await notifyCrossedThresholds(
            budgetID: budget.id,
            budgetName: budget.name,
            periodKey: periodKey,
            newThresholds: newThresholds,
            spent: spending,
            limit: budget.limitAmount,
            currencyCode: currencyCode
        )
    }

    /// Marca los thresholds cruzados y envía UNA notificación (la del más alto cruzado).
    ///
    /// Asimetría DELIBERADA del marcado:
    /// - Los thresholds cruzados PERO NO enviados (todos menos el más alto) se marcan
    ///   INCONDICIONALMENTE: su supresión es la intención anti-spam — no queremos avisos
    ///   separados 50/75/90 del mismo período cuando un salto los cruzó todos de golpe.
    /// - El threshold efectivamente ENVIADO (el más alto) se marca SOLO con entrega confirmada
    ///   por iOS (`sendNotification -> Bool`, paridad con `ScheduledPaymentNotificationService`):
    ///   un fallo silencioso — permisos revocados, wipe personal armado, throttle de iOS — no
    ///   debe suprimir el alerta del período; el próximo check lo reintenta.
    ///
    /// Extraído de `checkBudget` como seam de test (el marcado del enviado queda gateado por
    /// la entrega, verificable sin `ModelContext` ni `Date.now`).
    func notifyCrossedThresholds(
        budgetID: UUID,
        budgetName: String,
        periodKey: String,
        newThresholds: [Int],
        spent: Double,
        limit: Double,
        currencyCode: String
    ) async {
        guard let maxThreshold = newThresholds.max() else { return }

        // Cruzados-pero-no-enviados: supresión intencional (solo se avisa del más alto).
        for threshold in newThresholds where threshold != maxThreshold {
            tracker.markNotified(budgetID: budgetID, periodKey: periodKey, threshold: threshold)
        }

        // El enviado (el más alto): marca solo tras entrega confirmada.
        let delivered = await sendNotification(
            budgetName: budgetName,
            threshold: maxThreshold,
            spent: spent,
            limit: limit,
            currencyCode: currencyCode
        )
        if delivered {
            tracker.markNotified(budgetID: budgetID, periodKey: periodKey, threshold: maxThreshold)
        }
    }

    // MARK: - Period Interval (uses current date, not ViewModel state)

    /// Calcula el intervalo del período actual. `now` se inyecta opcionalmente
    /// en tests para hacer el resultado determinístico (sin depender de `Date.now`).
    func getCurrentPeriodInterval(for budget: Budget, now: Date = .now) -> DateInterval {
        let calendar = userConfiguredCalendar()

        guard let periodType = BudgetPeriodType(rawValue: budget.periodType) else {
            let monthStart = calendar.startOfMonth(for: now)
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            return DateInterval(start: monthStart, end: monthEnd)
        }

        switch periodType {
        case .weekly:
            let weekStart = calendar.startOfWeek(for: now)
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            return DateInterval(start: weekStart, end: weekEnd)
        case .monthly:
            let monthStart = calendar.startOfMonth(for: now)
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            return DateInterval(start: monthStart, end: monthEnd)
        case .yearly:
            let year = calendar.component(.year, from: now)
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? yearStart
            return DateInterval(start: yearStart, end: yearEnd)
        case .unique:
            guard let start = budget.startDate, let end = budget.endDate else {
                let monthStart = calendar.startOfMonth(for: now)
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                return DateInterval(start: monthStart, end: monthEnd)
            }
            return DateInterval(start: start, end: end)
        }
    }

    // MARK: - Spending Calculation

    private func calculateSpending(
        budget: Budget,
        transactions: [TransactionItem],
        interval: DateInterval,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> Double {
        BudgetsViewModel.calculateSpending(budget: budget, transactions: transactions, interval: interval, adjustment: adjustment)
    }

    // MARK: - Notifications

    /// Envía la notificación del threshold. Retorna `true` si iOS aceptó el request
    /// (`NotificationService.sendNotification -> Bool`) — el llamador gatea el dedup con ese valor.
    private func sendNotification(
        budgetName: String,
        threshold: Int,
        spent: Double,
        limit: Double,
        currencyCode: String
    ) async -> Bool {
        if let override = sendOverride {
            return await override(budgetName, threshold, spent, limit, currencyCode)
        }

        let symbol = CurrencyUtils.symbol(for: currencyCode)
        let spentStr = "\(symbol)\(spent.formatted(.number.precision(.fractionLength(0...2))))"
        let limitStr = "\(symbol)\(limit.formatted(.number.precision(.fractionLength(0...2))))"

        let message: String
        switch threshold {
        case 50: message = L10n.Budgets.alertMessage50(budgetName, spentStr, limitStr)
        case 75: message = L10n.Budgets.alertMessage75(budgetName, spentStr, limitStr)
        case 90: message = L10n.Budgets.alertMessage90(budgetName, spentStr, limitStr)
        case 100: message = L10n.Budgets.alertMessage100(budgetName, spentStr, limitStr)
        default: message = "\(budgetName): \(threshold)%"
        }

        return await NotificationService.shared.sendNotification(
            title: budgetName,
            body: message,
            deepLink: "budgets"
        )
    }
}

// MARK: - Calendar Extensions

