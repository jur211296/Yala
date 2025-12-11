import Foundation
import SwiftData

enum TrendType: String, CaseIterable, Identifiable {
    case balance = "Saldo"
    case expense = "Gasto"

    var id: String { rawValue }
}

enum TrendGrouping: String, CaseIterable, Identifiable {
    case day = "Día"
    case week = "Semana"
    case month = "Mes"

    var id: String { rawValue }
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

enum BalanceStatus {
    case normal
    case good
    case critical
    case unknown
}
