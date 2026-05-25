//
//  PivotTableCalculator.swift
//  Yala
//
//  Recursive grouping calculator for the financial report pivot table.
//

import Foundation
import SwiftData

struct PivotTableCalculator {

    // MARK: - Public API

    /// Build the pivot tree from transactions and a grouping hierarchy
    /// - Parameters:
    ///   - currentTransactions: Transactions in the current period
    ///   - previousTransactions: Transactions in the previous period (for comparison)
    ///   - hierarchy: Ordered grouping dimensions
    ///   - preferredCurrency: User's preferred currency code
    /// - Returns: Root-level pivot nodes
    static func buildTree(
        currentTransactions: [TransactionItem],
        previousTransactions: [TransactionItem],
        hierarchy: [ReportGroupingDimension],
        preferredCurrency: String,
        allTags: [Tag] = []
    ) -> [PivotNode] {
        guard !hierarchy.isEmpty else { return [] }

        let dimension = hierarchy[0]
        let remaining = Array(hierarchy.dropFirst())

        let currentGroups = group(transactions: currentTransactions, by: dimension, allTags: allTags)
        let previousGroups = group(transactions: previousTransactions, by: dimension, allTags: allTags)

        // Collect all keys from both periods
        let allKeys = Set(currentGroups.keys).union(previousGroups.keys)

        var nodes: [PivotNode] = allKeys.map { key in
            let currentTxns = currentGroups[key] ?? []
            let previousTxns = previousGroups[key] ?? []

            // When grouped by currency or account, sum in original currency; otherwise preferred
            let useOriginalAmount = (dimension == .divisa || dimension == .cuenta)
            let amountKeyPath: KeyPath<TransactionItem, Double> = useOriginalAmount ? \.amount : \.amountInPreferredCurrency

            let currentAmount = currentTxns.reduce(0) { $0 + $1[keyPath: amountKeyPath] }
            let previousAmountValue = previousTxns.reduce(0) { $0 + $1[keyPath: amountKeyPath] }

            let previousAmount: Double? = previousTxns.isEmpty ? nil : previousAmountValue
            let variation = PreviousPeriodHelper.calculateVariation(
                currentAmount: abs(currentAmount),
                previousAmount: abs(previousAmount ?? 0)
            )

            // Currency code for the node
            let nodeCurrency: String?
            if dimension == .divisa {
                nodeCurrency = key.label  // The currency code IS the group label
            } else if dimension == .cuenta {
                nodeCurrency = currentTxns.first?.currencyCode ?? previousTxns.first?.currencyCode
            } else {
                nodeCurrency = nil
            }

            // Recurse for children
            let children: [PivotNode]
            if remaining.isEmpty {
                children = []
            } else {
                children = buildTree(
                    currentTransactions: currentTxns,
                    previousTransactions: previousTxns,
                    hierarchy: remaining,
                    preferredCurrency: preferredCurrency,
                    allTags: allTags
                )
            }

            return PivotNode(
                label: key.label,
                iconName: key.iconName,
                colorHex: key.colorHex,
                amount: currentAmount,
                previousAmount: previousAmount,
                variation: variation,
                currencyCode: nodeCurrency,
                children: children,
                isIncome: key.isIncome,
                dimension: dimension
            )
        }

        // Sort: income first, then expense; within each, by absolute amount descending
        nodes.sort { a, b in
            if a.isIncome != b.isIncome { return a.isIncome }
            return abs(a.amount) > abs(b.amount)
        }

        return nodes
    }

    /// Calculate net flow from root nodes
    static func calculateNetFlow(
        currentNodes: [PivotNode],
        previousNodes: [PivotNode]? = nil
    ) -> (current: Double, previous: Double?, variation: Double?) {
        let currentNet = currentNodes.reduce(0) { $0 + $1.amount }
        let previousNet = previousNodes?.reduce(0) { $0 + ($1.amount) }
        let variation: Double?
        if let prev = previousNet {
            variation = PreviousPeriodHelper.calculateVariation(
                currentAmount: currentNet,
                previousAmount: prev
            )
        } else {
            variation = nil
        }
        return (currentNet, previousNet, variation)
    }

    /// Flatten a tree of pivot nodes into rows with indentation levels
    static func flatten(nodes: [PivotNode], level: Int = 0) -> [PivotFlatRow] {
        var rows: [PivotFlatRow] = []
        for node in nodes {
            rows.append(PivotFlatRow(id: node.id, node: node, level: level))
            if !node.children.isEmpty {
                rows.append(contentsOf: flatten(nodes: node.children, level: level + 1))
            }
        }
        return rows
    }

    // MARK: - Grouping Logic

    /// Key for grouping transactions
    struct GroupKey: Hashable {
        let label: String
        let iconName: String?
        let colorHex: String?
        let isIncome: Bool
    }

    /// Group transactions by a given dimension.
    /// `allTags`: caller-provided Tag catalog for CSV mirror resolution (case `.etiqueta`).
    /// When empty, falls back to M2M-direct (legacy/preview path).
    static func group(
        transactions: [TransactionItem],
        by dimension: ReportGroupingDimension,
        allTags: [Tag] = []
    ) -> [GroupKey: [TransactionItem]] {
        var groups: [GroupKey: [TransactionItem]] = [:]
        let tagsByID = Tag.byIDLookup(allTags)

        for tx in transactions {
            let keys = groupKeys(for: tx, dimension: dimension, tagsByID: tagsByID)
            for key in keys {
                groups[key, default: []].append(tx)
            }
        }

        return groups
    }

    /// Get group key(s) for a transaction. Tags return multiple keys (fan-out).
    private static func groupKeys(
        for tx: TransactionItem,
        dimension: ReportGroupingDimension,
        tagsByID: [UUID: Tag] = [:]
    ) -> [GroupKey] {
        switch dimension {
        case .tipo:
            let isIncome = tx.category?.isIncome ?? (tx.amount > 0)
            let label = isIncome ? L10n.Report.income : L10n.Report.expense
            let icon = isIncome ? TrendType.income.iconName : TrendType.expense.iconName
            let color: String? = nil  // View layer decides color based on isIncome
            return [GroupKey(label: label, iconName: icon, colorHex: color, isIncome: isIncome)]

        case .categoria:
            let label = tx.category?.name ?? L10n.Report.uncategorized
            let icon = tx.category?.iconName
            let color = tx.category?.colorHex
            let isIncome = tx.category?.isIncome ?? false
            return [GroupKey(label: label, iconName: icon, colorHex: color, isIncome: isIncome)]

        case .subcategoria:
            let label = tx.subcategory?.name ?? L10n.Report.noSubcategory
            let icon = tx.subcategory?.iconName
            let color = tx.subcategory?.colorHex ?? tx.category?.colorHex
            let isIncome = tx.category?.isIncome ?? false
            return [GroupKey(label: label, iconName: icon, colorHex: color, isIncome: isIncome)]

        case .etiqueta:
            // CSV-first read: resuelve UUIDs via `tagsByID` (catalog del caller).
            // Si tagsByID está vacío (callers legacy sin migrar), fallback a M2M directo.
            let txTagUUIDs = tx.resolvedTagIDs(scheduleBackfill: true) ?? []
            if !tagsByID.isEmpty {
                let resolvedTags = txTagUUIDs.compactMap { tagsByID[$0] }
                if resolvedTags.isEmpty {
                    return [GroupKey(label: L10n.Report.noTag, iconName: "tag.slash", colorHex: nil, isIncome: false)]
                }
                return resolvedTags.map { tag in
                    GroupKey(
                        label: tag.name,
                        iconName: tag.iconName,
                        colorHex: tag.colorHex,
                        isIncome: false
                    )
                }
            }
            // Fallback legacy (M2M direct) — usado por callers sin allTags.
            let tags = tx.tags ?? []
            if tags.isEmpty {
                return [GroupKey(label: L10n.Report.noTag, iconName: "tag.slash", colorHex: nil, isIncome: false)]
            }
            return tags.map { tag in
                GroupKey(
                    label: tag.name,
                    iconName: tag.iconName,
                    colorHex: tag.colorHex,
                    isIncome: false
                )
            }

        case .cuenta:
            let label = tx.account?.name ?? L10n.Report.noAccount
            let icon = tx.account?.iconName
            let color = tx.account?.colorHex
            let isIncome = tx.category?.isIncome ?? false
            return [GroupKey(label: label, iconName: icon, colorHex: color, isIncome: isIncome)]

        case .divisa:
            let currency = tx.currencyCode
            return [GroupKey(label: currency, iconName: "coloncurrencysign.circle", colorHex: nil, isIncome: false)]

        case .naturaleza:
            let need = tx.effectiveNeed
            return [GroupKey(label: need.displayName, iconName: "leaf", colorHex: nil, isIncome: false)]
        }
    }
}
