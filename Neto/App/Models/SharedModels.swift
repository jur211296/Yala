import Foundation
import SwiftData
import SwiftUI

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
        case .essential: return "Esencial"
        case .priority: return "Prioritaria"
        case .optional: return "Opcional"
        case .unclassified: return "Sin clasificación"
        }
    }

    /// Descripción corta para ayudar al usuario
    var description: String {
        switch self {
        case .essential:
            return "Gastos imprescindibles, difíciles de recortar."
        case .priority:
            return "Importantes pero con algo de flexibilidad."
        case .optional:
            return "Gastos discrecionales o de ocio."
        case .unclassified:
            return "Sin etiqueta de naturaleza específica."
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
    case balance = "Saldo"
    case income = "Ingreso"
    case expense = "Gasto"

    var id: String { rawValue }

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
    case balance = "Saldo"
    case income = "Ingreso"
    case expense = "Gasto"

    var id: String { rawValue }

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
    case thisWeek = "Esta semana"
    case last7Days = "Últimos 7 días"
    case last30Days = "Últimos 30 días"
    case thisMonth = "Este mes"
    case lastMonth = "Mes pasado"
    case thisYear = "Este año"
    case lastYear = "Año pasado"
    case allTime = "Todo el tiempo"

    var id: String { rawValue }

    /// Display name for UI (same as rawValue)
    var displayName: String { rawValue }

    /// Calendar icon for the selector
    var iconName: String { "calendar" }

    /// Get the date interval for this period
    var dateInterval: DateInterval {
        let calendar = Calendar.current
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
        }
    }

    /// Grouping for chart display
    var chartGrouping: TrendGrouping {
        switch self {
        case .thisWeek, .last7Days:
            return .day
        case .last30Days, .thisMonth, .lastMonth:
            return .day
        case .thisYear, .lastYear, .allTime:
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

    var id: PersistentIdentifier { category.persistentModelID }
}

struct SubcategorySpendingSummary: Identifiable {
    let subcategoryName: String
    let colorHex: String?
    let amount: Double
    let percentageOfTotal: Double
    let percentageOfCategory: Double

    var id: String { subcategoryName }

    // Optional reference to actual model if it exists
    let subcategory: Subcategory?
    // Optional reference to parent category
    let category: Category?
}

struct NatureSpendingSummary: Identifiable {
    let nature: SubcategoryNature
    let amount: Double
    let percentage: Double

    var id: String { nature.rawValue }

    // Color helper
    var color: Color {
        switch nature {
        case .essential: return .electricIndigo
        case .priority: return .priorityNature
        case .optional: return .hotPink
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
