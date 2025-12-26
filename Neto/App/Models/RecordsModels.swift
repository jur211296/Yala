//
//  RecordsModels.swift
//  Neto
//
//  Created by Neto - Records Feature.
//

import Foundation
import SwiftData

// MARK: - Period Options for Records Filter

/// Period options for the Records list filter
enum RecordsPeriod: String, CaseIterable, Identifiable {
    // Periodo actual (Current Period)
    case today
    case thisWeek
    case thisMonth
    case thisYear

    // Periodo móvil (Rolling Period)
    case last7Days
    case last30Days
    case last90Days
    case last180Days

    // Rango personalizado
    case custom

    var id: String { rawValue }

    /// Category this period belongs to
    var category: PeriodCategory {
        switch self {
        case .today, .thisWeek, .thisMonth, .thisYear:
            return .current
        case .last7Days, .last30Days, .last90Days, .last180Days:
            return .rolling
        case .custom:
            return .custom
        }
    }

    /// Short display name for segmented control
    var displayName: String {
        switch self {
        case .today: return "Hoy"
        case .thisWeek: return "Esta semana"
        case .thisMonth: return "Este mes"
        case .thisYear: return "Este año"
        case .last7Days: return "7 días"
        case .last30Days: return "30 días"
        case .last90Days: return "90 días"
        case .last180Days: return "180 días"
        case .custom: return "Personalizado"
        }
    }

    /// Returns the DateInterval for non-custom periods
    /// - Parameters:
    ///   - today: Reference date (defaults to now)
    ///   - calendar: Calendar to use (defaults to current)
    /// - Returns: DateInterval or nil for custom
    func dateInterval(
        relativeTo today: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval? {
        switch self {
        case .today:
            return calendar.dateInterval(of: .day, for: today)

        case .thisWeek:
            // Week starting on Monday
            var mondayCalendar = calendar
            mondayCalendar.firstWeekday = 2
            return mondayCalendar.dateInterval(of: .weekOfYear, for: today)

        case .thisMonth:
            return calendar.dateInterval(of: .month, for: today)

        case .thisYear:
            return calendar.dateInterval(of: .year, for: today)

        case .last7Days:
            let start = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -6, to: today)!)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
            return DateInterval(start: start, end: end)

        case .last30Days:
            let start = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -29, to: today)!)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
            return DateInterval(start: start, end: end)

        case .last90Days:
            let start = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -89, to: today)!)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
            return DateInterval(start: start, end: end)

        case .last180Days:
            let start = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -179, to: today)!)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
            return DateInterval(start: start, end: end)

        case .custom:
            // Custom requires explicit dates
            return nil
        }
    }

    /// All periods in the current category
    static var currentPeriods: [RecordsPeriod] {
        [.today, .thisWeek, .thisMonth, .thisYear]
    }

    static var rollingPeriods: [RecordsPeriod] {
        [.last7Days, .last30Days, .last90Days, .last180Days]
    }
}

/// Category for period options
enum PeriodCategory: String, CaseIterable, Identifiable {
    case current
    case rolling
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .current: return "Periodo actual"
        case .rolling: return "Periodo móvil"
        case .custom: return "Rango personalizado"
        }
    }
}

// MARK: - Transaction Type Filter

/// Filter options for transaction type
enum TransactionTypeFilter: String, CaseIterable, Identifiable {
    case all
    case income
    case expense
    case transfer

    var id: String { rawValue }

    /// Display name in Spanish
    var displayName: String {
        switch self {
        case .all: return "Todos"
        case .income: return "Ingresos"
        case .expense: return "Gastos"
        case .transfer: return "Transferencias"
        }
    }

    /// Icon for the filter option
    var iconName: String {
        switch self {
        case .all: return "arrow.left.arrow.right"
        case .income: return "arrow.down.circle"
        case .expense: return "arrow.up.circle"
        case .transfer: return "arrow.left.arrow.right.circle"
        }
    }
}

// MARK: - Records Context

/// Context passed from Panel to pre-fill filters
struct RecordsFilterContext {
    var accountID: PersistentIdentifier?
    var categoryID: PersistentIdentifier?
    var subcategoryName: String?
    var nature: SubcategoryNature?
    var period: RecordsPeriod?

    static let empty = RecordsFilterContext()
}
