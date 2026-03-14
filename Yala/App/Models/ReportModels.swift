//
//  ReportModels.swift
//  Yala
//
//  Models for the Financial Report pivot table view.
//

import Foundation
import SwiftUI

// MARK: - Report Tab

/// Tabs available in the Financial Report screen
enum ReportTab: String, CaseIterable, Identifiable {
    case comparativa
    case flujoDeCaja

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comparativa: return L10n.Report.Tab.comparative
        case .flujoDeCaja: return L10n.Report.Tab.cashFlow
        }
    }

    var icon: String {
        switch self {
        case .comparativa: return "tablecells"
        case .flujoDeCaja: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Grouping Dimension

/// Dimensions available for grouping transactions in the financial report
enum ReportGroupingDimension: String, CaseIterable, Identifiable {
    case tipo          // Income vs Expense (mandatory)
    case categoria     // Category
    case subcategoria  // Subcategory
    case etiqueta      // Tag
    case cuenta        // Account
    case divisa        // Currency
    case naturaleza    // Need (essential/priority/optional)

    var id: String { rawValue }

    /// Whether this dimension can be deselected
    var isMandatory: Bool { self == .tipo }

    /// Whether this dimension represents an entity with icon + color (vs. a plain concept)
    var isEntityDimension: Bool {
        switch self {
        case .categoria, .subcategoria, .etiqueta, .cuenta: return true
        case .tipo, .divisa, .naturaleza: return false
        }
    }

    var displayName: String {
        switch self {
        case .tipo: return L10n.Report.Grouping.type
        case .categoria: return L10n.Report.Grouping.category
        case .subcategoria: return L10n.Report.Grouping.subcategory
        case .etiqueta: return L10n.Report.Grouping.tag
        case .cuenta: return L10n.Report.Grouping.account
        case .divisa: return L10n.Report.Grouping.currency
        case .naturaleza: return L10n.Report.Grouping.nature
        }
    }

    var iconName: String {
        switch self {
        case .tipo: return "arrow.up.arrow.down"
        case .categoria: return "square.grid.2x2"
        case .subcategoria: return "list.bullet.indent"
        case .etiqueta: return "tag"
        case .cuenta: return "creditcard"
        case .divisa: return "coloncurrencysign.circle"
        case .naturaleza: return "leaf"
        }
    }
}

// MARK: - Grouping State

/// Manages the active grouping dimensions and their order
struct ReportGroupingState {
    /// Active dimensions in hierarchy order
    var activeDimensions: [ReportGroupingDimension] = [.tipo]

    /// Toggle a dimension on/off (tipo cannot be deselected)
    mutating func toggle(_ dimension: ReportGroupingDimension) {
        if let index = activeDimensions.firstIndex(of: dimension) {
            guard !dimension.isMandatory else { return }
            activeDimensions.remove(at: index)
        } else {
            activeDimensions.append(dimension)
        }
    }

    /// Move a dimension within the active list
    mutating func move(from source: IndexSet, to destination: Int) {
        activeDimensions.move(fromOffsets: source, toOffset: destination)
    }

    /// Whether a dimension is currently active
    func isActive(_ dimension: ReportGroupingDimension) -> Bool {
        activeDimensions.contains(dimension)
    }

    /// Inactive dimensions (available for activation)
    var inactiveDimensions: [ReportGroupingDimension] {
        ReportGroupingDimension.allCases.filter { !activeDimensions.contains($0) }
    }
}

// MARK: - Pivot Node

/// A node in the pivot table tree hierarchy
struct PivotNode: Identifiable {
    let id = UUID()
    let label: String
    let iconName: String?
    let colorHex: String?

    /// Current period amount
    let amount: Double

    /// Previous period amount (for comparison)
    let previousAmount: Double?

    /// Percentage variation between periods
    let variation: Double?

    /// Currency code for this node (used when grouping by currency or account)
    let currencyCode: String?

    /// Child nodes (next grouping level)
    let children: [PivotNode]

    /// Whether this is an income node (for color coding)
    let isIncome: Bool

    /// The grouping dimension that produced this node
    let dimension: ReportGroupingDimension

    /// Whether this node represents a leaf (no children)
    var isLeaf: Bool { children.isEmpty }
}

// MARK: - Flattened Row

/// A flattened pivot node with its nesting level for rendering
struct PivotFlatRow: Identifiable {
    let id: UUID
    let node: PivotNode
    let level: Int
}
