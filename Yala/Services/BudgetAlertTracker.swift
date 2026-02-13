//
//  BudgetAlertTracker.swift
//  Yala
//
//  Tracks which budget alert thresholds have been notified per period.
//  Uses UserDefaults for persistence.
//

import Foundation

/// Tracks which budget alert thresholds have been notified per period
final class BudgetAlertTracker {
    static let shared = BudgetAlertTracker()

    private let defaults = UserDefaults.standard
    private let keyPrefix = "budgetAlert_"

    private init() {}

    // MARK: - Period Key Generation

    /// Generate period key based on budget type and current date
    func periodKey(for budget: Budget) -> String {
        let calendar = Calendar.current
        let now = Date()

        guard let periodType = BudgetPeriodType(rawValue: budget.periodType) else {
            return "unknown"
        }

        switch periodType {
        case .weekly:
            let weekOfYear = calendar.component(.weekOfYear, from: now)
            let year = calendar.component(.yearForWeekOfYear, from: now)
            return "\(year)-W\(String(format: "%02d", weekOfYear))"
        case .monthly:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: now)
        case .yearly:
            return "\(calendar.component(.year, from: now))"
        case .unique:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let start = budget.startDate.map { formatter.string(from: $0) } ?? "none"
            let end = budget.endDate.map { formatter.string(from: $0) } ?? "none"
            return "unique_\(start)_\(end)"
        }
    }

    // MARK: - Threshold Tracking

    /// Get already-notified thresholds for a budget/period
    func notifiedThresholds(budgetID: UUID, periodKey: String) -> Set<Int> {
        let key = "\(keyPrefix)\(budgetID.uuidString)_\(periodKey)"
        let array = defaults.array(forKey: key) as? [Int] ?? []
        return Set(array)
    }

    /// Mark a threshold as notified
    func markNotified(budgetID: UUID, periodKey: String, threshold: Int) {
        let key = "\(keyPrefix)\(budgetID.uuidString)_\(periodKey)"
        var current = defaults.array(forKey: key) as? [Int] ?? []
        if !current.contains(threshold) {
            current.append(threshold)
            defaults.set(current, forKey: key)
        }
    }

    /// Get thresholds that should be notified (crossed but not yet notified)
    func getNewThresholds(
        budgetID: UUID,
        periodKey: String,
        currentPercentage: Double,
        configuredThresholds: Set<Int>
    ) -> [Int] {
        let alreadyNotified = notifiedThresholds(budgetID: budgetID, periodKey: periodKey)

        return configuredThresholds
            .filter { threshold in
                currentPercentage >= Double(threshold) && !alreadyNotified.contains(threshold)
            }
            .sorted()
    }

    // MARK: - Cleanup

    /// Clean up old entries (> 3 months)
    func cleanupOldEntries() {
        let allKeys = defaults.dictionaryRepresentation().keys
        let budgetKeys = allKeys.filter { $0.hasPrefix(keyPrefix) }

        let calendar = Calendar.current
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        let cutoffYear = calendar.component(.year, from: threeMonthsAgo)
        let cutoffMonth = calendar.component(.month, from: threeMonthsAgo)

        for key in budgetKeys {
            // Extract period from key (last component after last _)
            let components = key.split(separator: "_")
            guard components.count >= 3 else { continue }

            let period = String(components.last ?? "")

            // Check if it's a year-month pattern (2026-01)
            if period.count == 7, period.contains("-") {
                let parts = period.split(separator: "-")
                if parts.count == 2,
                   let year = Int(parts[0]),
                   let month = Int(parts[1]) {
                    if year < cutoffYear || (year == cutoffYear && month < cutoffMonth) {
                        defaults.removeObject(forKey: key)
                    }
                }
            }
        }
    }
}
