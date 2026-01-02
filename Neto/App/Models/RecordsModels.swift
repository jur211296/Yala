//
//  RecordsModels.swift
//  Neto
//
//  Created by Neto - Records Feature.
//

import Foundation
import SwiftData

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
    var transactionType: TransactionTypeFilter?
    var period: DetailPeriod?  // Unified period type

    static let empty = RecordsFilterContext()
}
