import Foundation
import SwiftData
import SwiftUI

// MARK: - User Calendar Preferences

/// Returns a Calendar configured with the user's preferred first day of week
func userConfiguredCalendar() -> Calendar {
    var calendar = Calendar.current
    // 1 = Sunday, 2 = Monday (default to Monday if not set)
    let firstWeekday = UserDefaults.standard.integer(forKey: "firstWeekday")
    calendar.firstWeekday = firstWeekday > 0 ? firstWeekday : 2  // Default to Monday
    return calendar
}

/// Enum for first day of week selection
enum FirstWeekday: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sunday: return L10n.Settings.sunday
        case .monday: return L10n.Settings.monday
        }
    }
}

/// Naturaleza de subcategoría para FIN-45
enum SubcategoryNature: String, CaseIterable, Identifiable {
    case essential = "esencial"
    case priority = "prioritaria"
    case optional = "opcional"
    case unclassified = "sin_clasificacion"

    var id: String { rawValue }

    /// Nombre visible en la UI
    var displayName: String {
        switch self {
        case .essential: return L10n.Nature.essential
        case .priority: return L10n.Nature.priority
        case .optional: return L10n.Nature.optional
        case .unclassified: return L10n.Nature.unclassified
        }
    }

    /// Descripción corta para ayudar al usuario
    var description: String {
        switch self {
        case .essential: return L10n.Nature.essentialDesc
        case .priority: return L10n.Nature.priorityDesc
        case .optional: return L10n.Nature.optionalDesc
        case .unclassified: return L10n.Nature.unclassifiedDesc
        }
    }
}

/// Acceso cómodo a la naturaleza desde el modelo SwiftData
extension Subcategory {
    var nature: SubcategoryNature {
        get {
            SubcategoryNature(rawValue: natureRawValue ?? "") ?? .unclassified
        }
        set {
            natureRawValue = newValue.rawValue
        }
    }
}

enum TrendType: String, CaseIterable, Identifiable {
    case balance
    case income
    case expense

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .balance: return L10n.TrendType.balance
        case .income: return L10n.TrendType.income
        case .expense: return L10n.TrendType.expense
        }
    }

    var color: Color {
        switch self {
        case .balance: return .brandPrimary
        case .income: return .teal
        case .expense: return .hotPink
        }
    }

    var iconName: String {
        switch self {
        case .balance: return "arrow.left.arrow.right"
        case .income: return "arrow.up.right"
        case .expense: return "arrow.down.right"
        }
    }
}

/// Metric type for detailed trends view (includes Income)
enum TrendMetric: String, CaseIterable, Identifiable {
    case balance
    case income
    case expense

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .balance: return L10n.TrendType.balance
        case .income: return L10n.TrendType.income
        case .expense: return L10n.TrendType.expense
        }
    }

    /// Convert to TrendType for shared properties
    var toTrendType: TrendType {
        switch self {
        case .balance: return .balance
        case .income: return .income
        case .expense: return .expense
        }
    }

    /// Color - delegated to TrendType (single source of truth)
    var color: Color { toTrendType.color }

    /// Icon - delegated to TrendType (single source of truth)
    var iconName: String { toTrendType.iconName }
}

/// Period options for detail view (expanded from Panel's TrendPeriod)
enum DetailPeriod: String, CaseIterable, Identifiable {
    case thisWeek
    case last7Days
    case last30Days
    case thisMonth
    case lastMonth
    case thisYear
    case lastYear
    case allTime
    case custom

    var id: String { rawValue }

    // Use localized display name
    var displayName: String {
        switch self {
        case .thisWeek: return L10n.Period.thisWeek
        case .last7Days: return L10n.Period.last7Days
        case .last30Days: return L10n.Period.last30Days
        case .thisMonth: return L10n.Period.thisMonth
        case .lastMonth: return L10n.Period.lastMonth
        case .thisYear: return L10n.Period.thisYear
        case .lastYear: return L10n.Period.lastYear
        case .allTime: return L10n.Period.allTime
        case .custom: return L10n.Period.custom
        }
    }

    /// Display name for UI - redirect to displayName property which is now localized
    // var displayName: String { rawValue } // OLD

    /// Calendar icon for the selector
    var iconName: String { "calendar" }

    /// Get the date interval for this period
    /// - Parameter customRange: Optional custom date range for .custom period
    func dateInterval(customRange: DateInterval? = nil) -> DateInterval {
        let calendar = userConfiguredCalendar()
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        switch self {
        case .thisWeek:
            let startOfWeek = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return DateInterval(start: startOfWeek, end: now)

        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
            return DateInterval(start: start, end: now)

        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: startOfToday)!
            return DateInterval(start: start, end: now)

        case .thisMonth:
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now))!
            return DateInterval(start: startOfMonth, end: now)

        case .lastMonth:
            let startOfThisMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now))!
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth)!
            return DateInterval(start: startOfLastMonth, end: startOfThisMonth)

        case .thisYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return DateInterval(start: startOfYear, end: now)

        case .lastYear:
            let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear)!
            return DateInterval(start: startOfLastYear, end: startOfThisYear)

        case .allTime:
            // Return a very long interval (10 years back)
            let start = calendar.date(byAdding: .year, value: -10, to: now)!
            return DateInterval(start: start, end: now)

        case .custom:
            // Use provided custom range or fallback to this month
            if let customRange {
                return customRange
            } else {
                let startOfMonth = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: now))!
                return DateInterval(start: startOfMonth, end: now)
            }
        }
    }

    /// Grouping for chart display
    var chartGrouping: TrendGrouping {
        switch self {
        case .thisWeek, .last7Days:
            return .day
        case .last30Days, .thisMonth, .lastMonth:
            return .day
        case .thisYear, .lastYear, .allTime, .custom:
            return .day  // Use day for data, but smooth visually
        }
    }
}

/// Navigation tabs for detail views
enum DetailViewTab: String, CaseIterable, Identifiable {
    case trends = "Tendencias"
    case categories = "Categorías"
    case records = "Registros"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trends: return L10n.Statistics.trends
        case .categories: return L10n.Statistics.categories
        case .records: return L10n.Statistics.records
        }
    }

    var icon: String {
        switch self {
        case .trends: return "chart.line.uptrend.xyaxis"
        case .categories: return "chart.pie"
        case .records: return "list.bullet.rectangle"
        }
    }
}

enum TrendGrouping: String, CaseIterable, Identifiable {
    case day = "Día"
    case week = "Semana"
    case month = "Mes"

    var id: String { rawValue }

    /// Returns the calendar component for date stride operations
    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }

    /// Returns the start date of the bucket containing the given date
    func dateKey(for date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start
                ?? calendar.startOfDay(for: date)
        }
    }
}

struct ChartTransaction: Identifiable {
    let id: UUID
    let date: Date
    let income: Double
    let expense: Double
    let balance: Double
}

struct CategorySpendingSummary: Identifiable {
    let category: Category
    let amount: Double
    let percentage: Double
    var previousAmount: Double? = nil  // For period comparison

    var id: PersistentIdentifier { category.persistentModelID }

    /// Variation percentage vs previous period
    var variation: Double? {
        PreviousPeriodHelper.calculateVariation(currentAmount: amount, previousAmount: previousAmount ?? 0)
    }
}

struct TagSpendingSummary: Identifiable {
    let tag: Tag
    let amount: Double
    let percentage: Double
    var previousAmount: Double? = nil  // For period comparison

    var id: PersistentIdentifier { tag.persistentModelID }

    /// Variation percentage vs previous period
    var variation: Double? {
        PreviousPeriodHelper.calculateVariation(currentAmount: amount, previousAmount: previousAmount ?? 0)
    }
}

struct SubcategorySpendingSummary: Identifiable {
    let subcategoryName: String
    let colorHex: String?
    let amount: Double
    let percentageOfTotal: Double
    let percentageOfCategory: Double
    var previousAmount: Double? = nil  // For period comparison

    var id: String { subcategoryName }

    // Optional reference to actual model if it exists
    let subcategory: Subcategory?
    // Optional reference to parent category
    let category: Category?

    /// PersistentIdentifier for filtering (nil for "No Subcategory" case)
    var persistentID: PersistentIdentifier? {
        subcategory?.persistentModelID
    }

    /// Variation percentage vs previous period
    var variation: Double? {
        PreviousPeriodHelper.calculateVariation(currentAmount: amount, previousAmount: previousAmount ?? 0)
    }
}

struct NatureSpendingSummary: Identifiable {
    let nature: SubcategoryNature
    let amount: Double
    let percentage: Double

    var id: String { nature.rawValue }

    // Color helper - uses distinct nature colors (not brand colors)
    var color: Color {
        switch nature {
        case .essential: return .essentialNature    // Amber
        case .priority: return .priorityNatureNew   // Violet
        case .optional: return .optionalNature      // Rose
        case .unclassified: return .gray.opacity(0.5)
        }
    }
}

struct NatureTrendPoint: Identifiable {
    let id: UUID = UUID()
    let date: Date  // X axis
    // Amounts per nature
    let essential: Double
    let priority: Double
    let optional: Double
    let unclassified: Double

    var total: Double { essential + priority + optional + unclassified }
}

enum BalanceStatus {
    case normal
    case good
    case critical
    case unknown
}
