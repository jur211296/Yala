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
    private static let expensePoolColor = "#FF0080"     // hotPink
    private static let availableColor = "#6366F1"       // electricIndigo
    private static let plannedColor = "#A78BFA"         // violet (between hotPink and indigo)
    private static let plannedRecurringColor = "#A78BFA"
    private static let plannedSubscriptionColor = "#C084FC"  // lighter purple
    private static let deficitColor = "#9CA3AF"         // neutral gray for "Otros fondos"

    private static var expensesLabel: String { L10n.Statistics.Sankey.expenses }
    private static var availableLabel: String { L10n.Statistics.Sankey.available }
    private static var otrosLabel: String { L10n.Statistics.Sankey.others }
    private static var plannedLabel: String { L10n.Statistics.Sankey.planned }
    private static var plannedRecurringLabel: String { L10n.Statistics.Sankey.plannedRecurring }
    private static var plannedSubscriptionLabel: String { L10n.Statistics.Sankey.plannedSubscription }
    private static var otherFundsLabel: String { L10n.Statistics.Sankey.otherFunds }

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
        maxPerColumn: Int = 12,
        plannedPending: [PlannedOccurrence] = [],
        plannedSplit: PlannedSplit = .unified,
        propagatePlannedToCategories: Bool = false
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

        guard totalIncome > 0 || totalExpense > 0 else { return .empty }

        var plannedTotal = 0.0
        var recurringSum = 0.0
        for occ in plannedPending {
            plannedTotal += occ.amount
            if occ.kind == .recurring { recurringSum += occ.amount }
        }

        // No cap: pool reflects real expense, planned reflects real planned.
        // When outflow exceeds income, a virtual "Otros fondos" node in col .income
        // covers the deficit so the Sankey balance stays honest.
        let pool = totalExpense
        let plannedShown = plannedTotal
        let recurringShown = recurringSum
        let subscriptionShown = plannedTotal - recurringSum
        let totalOutflow = totalExpense + plannedTotal
        let surplus = max(0, totalIncome - totalOutflow)
        let deficit = max(0, totalOutflow - totalIncome)

        // Build columns.
        let incomeNodes = buildIncomeColumn(
            subcatTotals: incomeBySubcat,
            subcatMap: incomeSubcatMap,
            orphanTotals: incomeOrphanByCat,
            catMap: incomeCatMap,
            maxPerColumn: maxPerColumn
        )

        // Append a virtual "Otros fondos" income-column node when outflow exceeds
        // income — represents savings, prior balance or new debt covering the gap.
        var allIncomeNodes = incomeNodes
        if deficit > 0 {
            allIncomeNodes.append(SankeyNode(
                id: SankeyNodeID.incomeDeficit,
                column: .income,
                name: otherFundsLabel,
                amount: deficit,
                colorHex: deficitColor,
                persistentID: nil,
                parentCategoryID: nil,
                isOtros: false,
                isTappable: false
            ))
        }

        var poolNodes: [SankeyNode] = []
        if pool > 0 {
            poolNodes.append(SankeyNode(
                id: SankeyNodeID.poolExpenses,
                column: .pool,
                name: expensesLabel,
                amount: pool,
                colorHex: expensePoolColor,
                persistentID: nil,
                parentCategoryID: nil,
                isOtros: false,
                isTappable: true
            ))
        }
        switch plannedSplit {
        case .unified:
            appendPlannedNode(&poolNodes, id: SankeyNodeID.poolPlanned, name: plannedLabel, amount: plannedShown, colorHex: plannedColor)
        case .byKind:
            appendPlannedNode(&poolNodes, id: SankeyNodeID.poolPlannedRecurring, name: plannedRecurringLabel, amount: recurringShown, colorHex: plannedRecurringColor)
            appendPlannedNode(&poolNodes, id: SankeyNodeID.poolPlannedSubscription, name: plannedSubscriptionLabel, amount: subscriptionShown, colorHex: plannedSubscriptionColor)
        }
        if surplus > 0 {
            poolNodes.append(SankeyNode(
                id: SankeyNodeID.poolAvailable,
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

        // col 0 → col 1: waterfall fill instead of a proportional split. Income
        // sources (already sorted by amount desc, with the virtual deficit node
        // appended last) fill pool destinations top-to-bottom — "Gastos", then
        // "Planificados", then "Disponible" — via a two-pointer sweep. Each source
        // feeds as few destinations as possible, so the diagram shows a few thick
        // bands filling from the top down rather than every source fanning a thin
        // sliver into every destination.
        //
        // Balance holds exactly: Σ sources (totalIncome + deficit) == Σ destinations
        // (pool + plannedShown + surplus), so the sweep consumes every node fully.
        appendWaterfallLinks(&links, sources: allIncomeNodes, targets: poolNodes)

        // Categories without expense in the period are NOT promoted from the planned branch:
        // an SP pointing to such a category sees its rama terminate at column 1 (no ghost cat nodes).
        if propagatePlannedToCategories, plannedTotal > 0 {
            var perCatRecurring: [PersistentIdentifier: Double] = [:]
            var perCatSubscription: [PersistentIdentifier: Double] = [:]
            for occ in plannedPending {
                guard let catID = occ.categoryID else { continue }
                if occ.kind == .recurring {
                    perCatRecurring[catID, default: 0] += occ.amount
                } else {
                    perCatSubscription[catID, default: 0] += occ.amount
                }
            }
            let unifiedNode = poolNodes.first { $0.id == SankeyNodeID.poolPlanned }
            let recurringNode = poolNodes.first { $0.id == SankeyNodeID.poolPlannedRecurring }
            let subscriptionNode = poolNodes.first { $0.id == SankeyNodeID.poolPlannedSubscription }

            for cat in expenseCategoryNodes where !cat.isOtros {
                guard let catID = cat.persistentID else { continue }
                let recurringWeight = perCatRecurring[catID] ?? 0
                let subscriptionWeight = perCatSubscription[catID] ?? 0
                switch plannedSplit {
                case .unified:
                    appendPlannedCatLink(&links, from: unifiedNode, to: cat, amount: recurringWeight + subscriptionWeight)
                case .byKind:
                    appendPlannedCatLink(&links, from: recurringNode, to: cat, amount: recurringWeight)
                    appendPlannedCatLink(&links, from: subscriptionNode, to: cat, amount: subscriptionWeight)
                }
            }
        }

        // col 1 → col 2: "Gastos" distributes to expense categories at real amounts.
        // No scaling needed: pool == totalExpense always.
        if let expensesNode = poolNodes.first(where: { $0.id == SankeyNodeID.poolExpenses }) {
            for exp in expenseCategoryNodes {
                guard exp.amount > 0 else { continue }
                links.append(SankeyLink(
                    id: "\(expensesNode.id)__\(exp.id)",
                    sourceID: expensesNode.id,
                    targetID: exp.id,
                    amount: exp.amount,
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

        let allNodes = allIncomeNodes + poolNodes + expenseCategoryNodes + expenseSubcategoryNodes

        return SankeyData(
            nodes: allNodes,
            links: links,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            pool: pool
        )
    }

    // MARK: - Planned helpers

    /// Append a Planificados pool node only when its amount is positive.
    private static func appendPlannedNode(
        _ nodes: inout [SankeyNode],
        id: String,
        name: String,
        amount: Double,
        colorHex: String
    ) {
        guard amount > 0 else { return }
        nodes.append(SankeyNode(
            id: id,
            column: .pool,
            name: name,
            amount: amount,
            colorHex: colorHex,
            persistentID: nil,
            parentCategoryID: nil,
            isOtros: false,
            isTappable: true
        ))
    }

    // MARK: - Link helpers

    /// Distributes flow from `sources` into `targets` with a top-to-bottom
    /// waterfall sweep: both columns are consumed in their given vertical order
    /// (largest first), each source filling the current target until one of them
    /// is exhausted. Emits at most `sources.count + targets.count - 1` links — far
    /// fewer than a proportional split's cartesian product — and yields a planar,
    /// crossing-free diagram that fills from the top down.
    ///
    /// The virtual deficit source and the "Disponible" target are mutually
    /// exclusive (deficit > 0 ⟹ surplus == 0 ⟹ no Disponible node, and vice
    /// versa), so the legacy "deficit never feeds Disponible" rule holds
    /// structurally without an explicit guard here.
    private static func appendWaterfallLinks(
        _ links: inout [SankeyLink],
        sources: [SankeyNode],
        targets: [SankeyNode]
    ) {
        guard !sources.isEmpty, !targets.isEmpty else { return }
        let epsilon = 0.005
        var sourceIndex = 0
        var targetIndex = 0
        var sourceRemaining = sources[sourceIndex].amount
        var targetRemaining = targets[targetIndex].amount

        while sourceIndex < sources.count, targetIndex < targets.count {
            let flow = min(sourceRemaining, targetRemaining)
            if flow > epsilon {
                let source = sources[sourceIndex]
                let target = targets[targetIndex]
                links.append(SankeyLink(
                    id: "\(source.id)__\(target.id)",
                    sourceID: source.id,
                    targetID: target.id,
                    amount: flow,
                    sourceColorHex: source.colorHex
                ))
            }
            sourceRemaining -= flow
            targetRemaining -= flow
            if sourceRemaining <= epsilon {
                sourceIndex += 1
                if sourceIndex < sources.count { sourceRemaining = sources[sourceIndex].amount }
            }
            if targetRemaining <= epsilon {
                targetIndex += 1
                if targetIndex < targets.count { targetRemaining = targets[targetIndex].amount }
            }
        }
    }

    /// Append a Planificados → expense-category link only if both source/target exist and weight is positive.
    private static func appendPlannedCatLink(
        _ links: inout [SankeyLink],
        from source: SankeyNode?,
        to cat: SankeyNode,
        amount: Double
    ) {
        guard let source, amount > 0 else { return }
        links.append(SankeyLink(
            id: "\(source.id)__\(cat.id)",
            sourceID: source.id,
            targetID: cat.id,
            amount: amount,
            sourceColorHex: source.colorHex
        ))
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
