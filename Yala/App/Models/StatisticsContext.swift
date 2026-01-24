//
//  StatisticsContext.swift
//  Yala
//
//  Context for passing filter state from Panel to Trends Detail View.
//

import Foundation
import SwiftData

/// Context passed from Panel to Trends Detail View with initial filter state
struct StatisticsContext {
    /// Initial metric to display (Saldo, Ingreso, Gasto)
    var initialMetric: TrendMetric

    /// Selected period from Panel
    var period: DetailPeriod

    /// Selected account filter (nil = all accounts)
    var accountID: PersistentIdentifier?

    /// Selected category filter
    var categoryID: PersistentIdentifier?

    /// Selected subcategory filter
    var subcategoryName: String?

    /// Selected nature filter
    var nature: SubcategoryNature?

    /// The date interval for the selected period
    var dateInterval: DateInterval?

    /// Create an empty context with defaults
    static func empty(metric: TrendMetric = .balance) -> StatisticsContext {
        StatisticsContext(
            initialMetric: metric,
            period: .thisYear,
            accountID: nil,
            categoryID: nil,
            subcategoryName: nil,
            nature: nil,
            dateInterval: nil
        )
    }
}
