//
//  SankeyFlowCalculator.swift
//  Yala
//
//  Builds a 4-column Sankey flow from a pre-filtered set of transactions:
//    col 0 (income subcategories) → col 1 (Gastos + optional Disponible)
//                                 → col 2 (expense categories)
//                                 → col 3 (expense subcategories)
//  Pure function, no side effects.
//

import Foundation
import SwiftData

struct SankeyFlowCalculator {

    private static let otherColor = "#8E8E93"
    private static let expensePoolColor = "#FF0080"   // hotPink
    private static let availableColor = "#6366F1"     // electricIndigo

    private static var expensesLabel: String { L10n.Statistics.Sankey.expenses }
    private static var availableLabel: String { L10n.Statistics.Sankey.available }
    private static var otrosLabel: String { L10n.Statistics.Sankey.others }

    // MARK: - Public API

    /// Builds the Sankey data structure for a given interval.
    ///
    /// Guards (independent of caller-side filtering):
    /// - `tx.balanceAdjustmentType == nil`
    /// - `tx.category != nil`
    /// - `interval.contains(tx.date)` — protects metrics that bypass the period filter (e.g. `.balance`).
    ///
    /// One O(N) pass over `transactions`. Uses `tx.amountInPreferredCurrency` snapshot.
    static func compute(
        transactions: [TransactionItem],
        interval: DateInterval,
        maxPerColumn: Int = 12
    ) -> SankeyData {

        // Income aggregations — by subcategory, plus orphan-per-parent-category for tx without subcat.
        var incomeBySubcat: [PersistentIdentifier: Double] = [:]
        var incomeOrphanByCat: [PersistentIdentifier: Double] = [:]
        var incomeSubcatMap: [PersistentIdentifier: Subcategory] = [:]
        var incomeCatMap: [PersistentIdentifier: Category] = [:]

        // Expense aggregations — by category and by subcategory.
        var expenseByCat: [PersistentIdentifier: Double] = [:]
        var expenseBySubcat: [PersistentIdentifier: Double] = [:]
        var expenseCatMap: [PersistentIdentifier: Category] = [:]
        var expenseSubcatMap: [PersistentIdentifier: Subcategory] = [:]
        var expenseSubcatToCat: [PersistentIdentifier: PersistentIdentifier] = [:]

        for tx in transactions {
            guard tx.balanceAdjustmentType == nil else { continue }
            guard let category = tx.category else { continue }
            guard interval.contains(tx.date) else { continue }

            let amount = abs(tx.amountInPreferredCurrency)
            guard amount > 0 else { continue }

            let catID = category.persistentModelID

            if category.isIncome {
                incomeCatMap[catID] = category
                if let subcategory = tx.subcategory {
                    let subID = subcategory.persistentModelID
                    incomeBySubcat[subID, default: 0] += amount
                    incomeSubcatMap[subID] = subcategory
                } else {
                    incomeOrphanByCat[catID, default: 0] += amount
                }
            } else {
                expenseCatMap[catID] = category
                expenseByCat[catID, default: 0] += amount
                if let subcategory = tx.subcategory {
                    let subID = subcategory.persistentModelID
                    expenseBySubcat[subID, default: 0] += amount
                    expenseSubcatMap[subID] = subcategory
                    expenseSubcatToCat[subID] = catID
                }
            }
        }

        let totalIncome = incomeBySubcat.values.reduce(0, +)
            + incomeOrphanByCat.values.reduce(0, +)
        let totalExpense = expenseByCat.values.reduce(0, +)
        let pool = min(totalIncome, totalExpense)
        let surplus = max(0, totalIncome - totalExpense)

        guard totalIncome > 0 || totalExpense > 0 else { return .empty }

        // Build columns.
        let incomeNodes = buildIncomeColumn(
            subcatTotals: incomeBySubcat,
            subcatMap: incomeSubcatMap,
            orphanTotals: incomeOrphanByCat,
            catMap: incomeCatMap,
            maxPerColumn: maxPerColumn
        )

        var poolNodes: [SankeyNode] = []
        if pool > 0 {
            poolNodes.append(SankeyNode(
                id: "pool_expenses",
                column: .pool,
                name: expensesLabel,
                amount: pool,
                colorHex: expensePoolColor,
                persistentID: nil,
                parentCategoryID: nil,
                isOtros: false,
                isTappable: false
            ))
        }
        if surplus > 0 {
            poolNodes.append(SankeyNode(
                id: "pool_available",
                column: .pool,
                name: availableLabel,
                amount: surplus,
                colorHex: availableColor,
                persistentID: nil,
                parentCategoryID: nil,
                isOtros: false,
                isTappable: false
            ))
        }

        let expenseCategoryNodes = buildCategoryNodes(
            from: expenseByCat,
            categoryMap: expenseCatMap,
            column: .expenseCategory,
            maxPerColumn: maxPerColumn,
            otrosID: "exp_otros",
            isTappable: true
        )

        let expenseSubcategoryNodes = buildSubcategoryNodes(
            from: expenseBySubcat,
            subcategoryMap: expenseSubcatMap,
            subcatToCat: expenseSubcatToCat,
            maxPerColumn: maxPerColumn
        )

        // Build links.
        var links: [SankeyLink] = []

        // col 0 → col 1: each income node splits between "Gastos" and "Disponible" proportionally.
        if totalIncome > 0 {
            let toExpensesRatio = totalIncome > 0 ? (pool / totalIncome) : 0
            let toAvailableRatio = totalIncome > 0 ? (surplus / totalIncome) : 0

            let expensesNode = poolNodes.first { $0.id == "pool_expenses" }
            let availableNode = poolNodes.first { $0.id == "pool_available" }

            for inc in incomeNodes {
                if let expensesNode, toExpensesRatio > 0 {
                    let weight = inc.amount * toExpensesRatio
                    if weight > 0 {
                        links.append(SankeyLink(
                            id: "\(inc.id)__\(expensesNode.id)",
                            sourceID: inc.id,
                            targetID: expensesNode.id,
                            amount: weight,
                            sourceColorHex: inc.colorHex
                        ))
                    }
                }
                if let availableNode, toAvailableRatio > 0 {
                    let weight = inc.amount * toAvailableRatio
                    if weight > 0 {
                        links.append(SankeyLink(
                            id: "\(inc.id)__\(availableNode.id)",
                            sourceID: inc.id,
                            targetID: availableNode.id,
                            amount: weight,
                            sourceColorHex: inc.colorHex
                        ))
                    }
                }
            }
        }

        // col 1 → col 2: "Gastos" distributes proportionally to expense categories.
        if let expensesNode = poolNodes.first(where: { $0.id == "pool_expenses" }),
           totalExpense > 0 {
            let scale = pool / totalExpense
            for exp in expenseCategoryNodes {
                let weight = exp.amount * scale
                guard weight > 0 else { continue }
                links.append(SankeyLink(
                    id: "\(expensesNode.id)__\(exp.id)",
                    sourceID: expensesNode.id,
                    targetID: exp.id,
                    amount: weight,
                    sourceColorHex: expensesNode.colorHex
                ))
            }
        }

        // col 2 → col 3: expense cat → its subcats (direct amount).
        for sub in expenseSubcategoryNodes {
            guard let subID = sub.persistentID,
                  let parentCatID = expenseSubcatToCat[subID] else { continue }
            let parent = expenseCategoryNodes.first { $0.persistentID == parentCatID }
                ?? expenseCategoryNodes.first(where: { $0.isOtros })
            guard let parentNode = parent else { continue }
            links.append(SankeyLink(
                id: "\(parentNode.id)__\(sub.id)",
                sourceID: parentNode.id,
                targetID: sub.id,
                amount: sub.amount,
                sourceColorHex: parentNode.colorHex
            ))
        }

        let allNodes = incomeNodes + poolNodes + expenseCategoryNodes + expenseSubcategoryNodes

        return SankeyData(
            nodes: allNodes,
            links: links,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            pool: pool
        )
    }

    // MARK: - Column builders

    private static func buildIncomeColumn(
        subcatTotals: [PersistentIdentifier: Double],
        subcatMap: [PersistentIdentifier: Subcategory],
        orphanTotals: [PersistentIdentifier: Double],
        catMap: [PersistentIdentifier: Category],
        maxPerColumn: Int
    ) -> [SankeyNode] {

        struct Entry {
            let id: String
            let name: String
            let amount: Double
            let colorHex: String
            let persistentID: PersistentIdentifier?
        }

        var entries: [Entry] = []

        for (subID, amount) in subcatTotals {
            guard let sub = subcatMap[subID], amount > 0 else { continue }
            let parentHex = sub.category?.colorHex ?? otherColor
            let hex = sub.colorHex ?? parentHex
            entries.append(Entry(
                id: nodeID(column: .income, persistentID: subID),
                name: sub.name,
                amount: amount,
                colorHex: hex,
                persistentID: subID
            ))
        }

        for (catID, amount) in orphanTotals {
            guard let cat = catMap[catID], amount > 0 else { continue }
            entries.append(Entry(
                id: "inc_orphan_\(catID.hashValue)",
                name: cat.name,
                amount: amount,
                colorHex: cat.colorHex,
                persistentID: nil
            ))
        }

        let sorted = entries.sorted { $0.amount > $1.amount }
        let top = sorted.prefix(maxPerColumn)
        let remainder = sorted.dropFirst(maxPerColumn)

        var nodes: [SankeyNode] = top.map { e in
            SankeyNode(
                id: e.id,
                column: .income,
                name: e.name,
                amount: e.amount,
                colorHex: e.colorHex,
                persistentID: e.persistentID,
                parentCategoryID: nil,
                isOtros: false,
                isTappable: false
            )
        }
        let remainderSum = remainder.reduce(0.0) { $0 + $1.amount }
        if remainderSum > 0 {
            nodes.append(SankeyNode(
                id: "inc_otros",
                column: .income,
                name: otrosLabel,
                amount: remainderSum,
                colorHex: otherColor,
                persistentID: nil,
                parentCategoryID: nil,
                isOtros: true,
                isTappable: false
            ))
        }
        return nodes
    }

    private static func buildCategoryNodes(
        from totals: [PersistentIdentifier: Double],
        categoryMap: [PersistentIdentifier: Category],
        column: SankeyColumn,
        maxPerColumn: Int,
        otrosID: String,
        isTappable: Bool
    ) -> [SankeyNode] {
        let sorted = totals.sorted { $0.value > $1.value }
        let top = sorted.prefix(maxPerColumn)
        let remainder = sorted.dropFirst(maxPerColumn)

        var nodes: [SankeyNode] = top.compactMap { (catID, amount) in
            guard let cat = categoryMap[catID], amount > 0 else { return nil }
            return SankeyNode(
                id: nodeID(column: column, persistentID: catID),
                column: column,
                name: cat.name,
                amount: amount,
                colorHex: cat.colorHex,
                persistentID: catID,
                parentCategoryID: nil,
                isOtros: false,
                isTappable: isTappable
            )
        }
        let remainderSum = remainder.reduce(0.0) { $0 + $1.value }
        if remainderSum > 0 {
            nodes.append(SankeyNode(
                id: otrosID,
                column: column,
                name: otrosLabel,
                amount: remainderSum,
                colorHex: otherColor,
                persistentID: nil,
                parentCategoryID: nil,
                isOtros: true,
                isTappable: false
            ))
        }
        return nodes
    }

    private static func buildSubcategoryNodes(
        from totals: [PersistentIdentifier: Double],
        subcategoryMap: [PersistentIdentifier: Subcategory],
        subcatToCat: [PersistentIdentifier: PersistentIdentifier],
        maxPerColumn: Int
    ) -> [SankeyNode] {
        let sorted = totals.sorted { $0.value > $1.value }
        let top = sorted.prefix(maxPerColumn)
        let remainder = sorted.dropFirst(maxPerColumn)

        var nodes: [SankeyNode] = top.compactMap { (subID, amount) in
            guard let sub = subcategoryMap[subID], amount > 0 else { return nil }
            let parentHex = sub.category?.colorHex ?? otherColor
            let colorHex = sub.colorHex ?? parentHex
            return SankeyNode(
                id: nodeID(column: .expenseSubcategory, persistentID: subID),
                column: .expenseSubcategory,
                name: sub.name,
                amount: amount,
                colorHex: colorHex,
                persistentID: subID,
                parentCategoryID: subcatToCat[subID],
                isOtros: false,
                isTappable: true
            )
        }
        let remainderSum = remainder.reduce(0.0) { $0 + $1.value }
        if remainderSum > 0 {
            nodes.append(SankeyNode(
                id: "sub_otros",
                column: .expenseSubcategory,
                name: otrosLabel,
                amount: remainderSum,
                colorHex: otherColor,
                persistentID: nil,
                parentCategoryID: nil,
                isOtros: true,
                isTappable: false
            ))
        }
        return nodes
    }

    private static func nodeID(column: SankeyColumn, persistentID: PersistentIdentifier) -> String {
        "c\(column.rawValue)_\(persistentID.hashValue)"
    }
}
