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
    ///   - accountGrouping: con `.byCard`, la dimensión de cuenta junta cada tarjeta con varias divisas en una fila,
    ///     convertida a `preferredCurrency` (entrega 4). Con `.byLine`, cada línea sale como su cuenta, como antes.
    ///   - cards: a qué tarjeta pertenece cada cuenta (`AccountCardIndex`). Vacío = ninguna cuenta tiene líneas.
    /// - Returns: Root-level pivot nodes
    static func buildTree(
        currentTransactions: [TransactionItem],
        previousTransactions: [TransactionItem],
        hierarchy: [ReportGroupingDimension],
        preferredCurrency: String,
        allTags: [Tag],
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared,
        accountGrouping: AccountCardGrouping = .byLine,
        cards: AccountCardIndex = .empty
    ) -> [PivotNode] {
        guard !hierarchy.isEmpty else { return [] }

        let dimension = hierarchy[0]
        let remaining = Array(hierarchy.dropFirst())

        // Income-aware: suprime las patas de préstamo derivadas del bridge (ingreso fantasma)
        // antes de agrupar — evita nodos vacíos; la pata real se netea a `-myShare` en la
        // acumulación vía los accessors del adjustment.
        let currentInput = currentTransactions.filter { !adjustment.isSuppressed($0) }
        let previousInput = previousTransactions.filter { !adjustment.isSuppressed($0) }

        let cardsForGrouping = accountGrouping == .byCard ? cards : .empty
        let currentGroups = group(transactions: currentInput, by: dimension, allTags: allTags, cards: cardsForGrouping)
        let previousGroups = group(transactions: previousInput, by: dimension, allTags: allTags, cards: cardsForGrouping)

        // Collect all keys from both periods
        let allKeys = Set(currentGroups.keys).union(previousGroups.keys)

        var nodes: [PivotNode] = allKeys.map { key in
            let currentTxns = currentGroups[key] ?? []
            let previousTxns = previousGroups[key] ?? []

            // When grouped by currency or account, sum in original currency; otherwise preferred.
            // Los montos pasan por el adjustment (pata real Caso A neteada a `-myShare`). El
            // preferido se resuelve con `CashFlowCalculator.resolvedAmount`: una fila guardada en
            // otra divisa principal se reconvierte en vez de sumarse en su escala.
            //
            // Una tarjeta con varias divisas («Por tarjeta», entrega 4) es la excepción de la cuenta: sus líneas están en
            // divisas distintas y sumarlas en nativo mezclaría soles con dólares, así que se resuelve en la preferida y
            // la fila lleva «≈» si algún movimiento se convirtió.
            // Solo si de verdad mezcla divisas: bajo un nodo de divisa (Divisa › Cuenta), o con todos sus movimientos en una,
            // la tarjeta suma en esa divisa como cualquier cuenta, sin «≈» (review del 2026-10-18).
            let rowCurrencies = Set((currentTxns + previousTxns).map { normalizeCurrencyCode($0.currencyCode) })
            let convertsCard = key.isAccountCard && rowCurrencies.count > 1
            let useOriginalAmount = dimension == .divisa || (dimension == .cuenta && !convertsCard)
            let amountOf: (TransactionItem) -> Double = { tx in
                useOriginalAmount
                    ? adjustment.amount(tx)
                    : CashFlowCalculator.resolvedAmount(
                        tx, currencyCode: preferredCurrency, adjustment: adjustment, converter: converter
                    ).value
            }

            let currentAmount = currentTxns.reduce(0.0) { $0 + amountOf($1) }
            let previousAmountValue = previousTxns.reduce(0.0) { $0 + amountOf($1) }

            let previousAmount: Double? = previousTxns.isEmpty ? nil : previousAmountValue
            let variation = PreviousPeriodHelper.calculateVariation(
                currentAmount: abs(currentAmount),
                previousAmount: abs(previousAmount ?? 0)
            )

            // Currency code for the node
            let nodeCurrency: String?
            if dimension == .divisa {
                nodeCurrency = key.label  // The currency code IS the group label
            } else if dimension == .cuenta && convertsCard {
                nodeCurrency = preferredCurrency
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
                    allTags: allTags,
                    adjustment: adjustment,
                    converter: converter,
                    accountGrouping: accountGrouping,
                    cards: cards
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
                dimension: dimension,
                isApproximate: convertsCard
                    && AccountCardReportLogic.convertsAny(currentTxns.map(\.currencyCode), to: preferredCurrency),
                previousIsApproximate: convertsCard
                    && AccountCardReportLogic.convertsAny(previousTxns.map(\.currencyCode), to: preferredCurrency)
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
        /// La fila es una tarjeta con varias divisas entera («Por tarjeta»): se suma en la divisa preferida.
        var isAccountCard: Bool = false
    }

    /// Group transactions by a given dimension.
    /// `allTags`: required Tag catalog for CSV mirror resolution (case `.etiqueta`).
    /// `cards`: con alguna tarjeta, la cuenta de cada movimiento se cambia por su tarjeta (case `.cuenta`).
    static func group(
        transactions: [TransactionItem],
        by dimension: ReportGroupingDimension,
        allTags: [Tag],
        cards: AccountCardIndex = .empty
    ) -> [GroupKey: [TransactionItem]] {
        var groups: [GroupKey: [TransactionItem]] = [:]
        let tagsByID = Tag.byIDLookup(allTags)

        for tx in transactions {
            let keys = groupKeys(for: tx, dimension: dimension, tagsByID: tagsByID, cards: cards)
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
        tagsByID: [UUID: Tag],
        cards: AccountCardIndex
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
            // CSV-mirror SSOT: resuelve UUIDs via `tagsByID` (catalog del caller).
            let txTagUUIDs = tx.resolvedTagIDs(scheduleBackfill: true) ?? []
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

        case .cuenta:
            if let card = cards.card(of: tx.account) {
                return [GroupKey(
                    label: card.name, iconName: card.iconName, colorHex: card.colorHex,
                    isIncome: tx.category?.isIncome ?? false, isAccountCard: true)]
            }
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
