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
