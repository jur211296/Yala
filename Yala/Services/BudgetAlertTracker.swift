//
//  BudgetAlertTracker.swift
//  Yala
//
//  Tracks which budget alert thresholds have been notified per period.
//  Uses UserDefaults for persistence.
//

import Foundation

/// Tracks which budget alert thresholds have been notified per period
@MainActor
final class BudgetAlertTracker {
    static let shared = BudgetAlertTracker()

    private let defaults = UserDefaults.standard
    private let keyPrefix = "budgetAlert_"

    private static let periodDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    private static let monthlyDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

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
            return Self.monthlyDateFormatter.string(from: now)
        case .yearly:
            return "\(calendar.component(.year, from: now))"
        case .unique:
            let start = budget.startDate.map { Self.periodDateFormatter.string(from: $0) } ?? "none"
            let end = budget.endDate.map { Self.periodDateFormatter.string(from: $0) } ?? "none"
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
        let cutoffWeek = calendar.component(.weekOfYear, from: threeMonthsAgo)
        let cutoffYearForWeek = calendar.component(.yearForWeekOfYear, from: threeMonthsAgo)

        for key in budgetKeys {
            // Extract period from key (last component after last _)
            let components = key.split(separator: "_")
            guard components.count >= 3 else { continue }

            let period = String(components.last ?? "")

            // Monthly: "2026-01"
            if period.count == 7, period.contains("-"), !period.contains("W") {
                let parts = period.split(separator: "-")
                if parts.count == 2,
                   let year = Int(parts[0]),
                   let month = Int(parts[1]) {
                    if year < cutoffYear || (year == cutoffYear && month < cutoffMonth) {
                        defaults.removeObject(forKey: key)
                    }
                }
            }
            // Weekly: "2026-W05"
            else if period.contains("-W") {
                let parts = period.split(separator: "-W")
                if parts.count == 2,
                   let year = Int(parts[0]),
                   let week = Int(parts[1]) {
                    if year < cutoffYearForWeek || (year == cutoffYearForWeek && week < cutoffWeek) {
                        defaults.removeObject(forKey: key)
                    }
                }
            }
            // Yearly: "2026" (4-digit number, no separators)
            else if period.count == 4, let year = Int(period) {
                if year < cutoffYear {
                    defaults.removeObject(forKey: key)
                }
            }
            // Unique: period key is "unique_YYYYMMDD_YYYYMMDD"
            // Extract full period by dropping prefix + UUID (36 chars) + "_"
            else {
                let afterPrefix = String(key.dropFirst(keyPrefix.count))
                // UUID is always 36 chars (8-4-4-4-12), followed by "_periodKey"
                if afterPrefix.count > 37 {
                    let periodPart = String(afterPrefix.dropFirst(37))
                    if periodPart.hasPrefix("unique_") {
                        let uniqueParts = periodPart.split(separator: "_")
                        // Format: unique_YYYYMMDD_YYYYMMDD
                        if uniqueParts.count == 3,
                           let endStr = uniqueParts.last,
                           let endDate = Self.periodDateFormatter.date(from: String(endStr)) {
                            if endDate < threeMonthsAgo {
                                defaults.removeObject(forKey: key)
                            }
                        }
                    }
                }
            }
        }
    }
}
