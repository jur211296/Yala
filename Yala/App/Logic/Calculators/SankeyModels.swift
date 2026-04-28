//
//  SankeyModels.swift
//  Yala
//
//  Domain models for the Sankey flow widget (Statistics → Distribution).
//

import Foundation
import SwiftData

// MARK: - Columns

enum SankeyColumn: Int, CaseIterable, Equatable, Hashable {
    case income = 0
    case pool = 1
    case expenseCategory = 2
    case expenseSubcategory = 3
}

// MARK: - Label mode

enum SankeyLabelMode: String, CaseIterable, Equatable, Hashable {
    case amount
    case percentage
}

// MARK: - Planned (scheduled payments branch)

/// Kind of planned (scheduled) payment for the Sankey "Planificados" branch.
/// Mirrors `ScheduledPayment.paymentCategory`.
enum PlannedKind: String, Equatable, Hashable {
    case recurring
    case subscription
}

/// Single occurrence of a pending scheduled payment within the Sankey period.
/// Amount is already converted to the user's preferred currency by the builder.
struct PlannedOccurrence: Equatable, Hashable {
    let amount: Double
    let kind: PlannedKind
    /// Parent category of the SP's subcategory. Nil if the SP has no subcategory.
    /// Used by Fase 3 (propagation to expense categories).
    let categoryID: PersistentIdentifier?
}

/// Whether to render Planificados as a single pool node or split by kind.
enum PlannedSplit: Equatable, Hashable {
    case unified
    case byKind
}

// MARK: - Node

struct SankeyNode: Identifiable, Equatable, Hashable {
    let id: String
    let column: SankeyColumn
    let name: String
    let amount: Double
    let colorHex: String
    /// Real category/subcategory identifier. Nil for virtual nodes ("Total", "Otros").
    let persistentID: PersistentIdentifier?
    /// For col 3 (subcategory) nodes, the parent expense category ID. Nil otherwise.
    /// Enables view-level filtering of col 3 when a cat is selected.
    let parentCategoryID: PersistentIdentifier?
    /// True when this node represents the aggregated remainder ("Otros").
    let isOtros: Bool
    /// True when the tap should toggle a filter in SessionState.
    /// False for income nodes, pool and "Otros" (ambiguous target).
    let isTappable: Bool
}

// MARK: - Link

struct SankeyLink: Identifiable, Equatable, Hashable {
    let id: String
    let sourceID: String
    let targetID: String
    let amount: Double
    let sourceColorHex: String
}

// MARK: - Data

struct SankeyData: Equatable {
    let nodes: [SankeyNode]
    let links: [SankeyLink]
    let totalIncome: Double
    let totalExpense: Double
    /// Pool size = min(totalIncome, totalExpense). Zero when either side is empty.
    let pool: Double

    var hasFlow: Bool { totalIncome > 0 || totalExpense > 0 }

    func nodes(in column: SankeyColumn) -> [SankeyNode] {
        nodes.filter { $0.column == column }
    }

    static let empty = SankeyData(
        nodes: [],
        links: [],
        totalIncome: 0,
        totalExpense: 0,
        pool: 0
    )
}
