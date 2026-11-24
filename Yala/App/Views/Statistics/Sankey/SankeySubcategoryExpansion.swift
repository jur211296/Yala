//
//  SankeySubcategoryExpansion.swift
//  Yala
//
//  «Ver subcategorías» del Sankey de Distribución (pedido de Jürgen del 23-nov-2026, pruebas de 2.3 en el iPhone).
//
//  Donde no caben las cuatro columnas (el iPhone), el Sankey arranca hasta las categorías, como hasta ahora. Un botón
//  bajo la gráfica despliega la columna de subcategorías de TODAS las categorías, y su estado inverso, «Ver menos», la
//  repliega. Desplegada, la columna se ordena por categoría madre (en el orden de la columna de categorías, cada grupo
//  por importe), para que los flujos no se crucen, y si hay más de `maxRows` subcategorías la cola va a un «Otros»
//  con un enlace desde cada categoría que aporta a él. Así ninguna etiqueta queda por debajo del alto legible.
//
//  Lógica pura: la vista decide CUÁNDO enseñar el botón y la aplica sobre los datos que ya filtró por flujo.
//

import Foundation

enum SankeySubcategoryExpansion {

    /// Como mucho tantas filas en la columna desplegada, «Otros» incluido. Con ocho nodos y la etiqueta en dos líneas,
    /// la columna cabe en el alto del Sankey del iPhone sin bajar del suelo legible (`minLabelHeight`).
    static let maxRows = 8

    /// El id del nodo «Otros» de subcategorías: el mismo que emite `SankeyFlowCalculator`, para que la vista lo
    /// trate igual (no se toca, no se filtra por categoría).
    static let othersNodeID = "sub_otros"

    /// El gris de «Otros», el mismo de `SankeyFlowCalculator.otherColor`.
    static let othersColorHex = "#8E8E93"

    /// ¿Se enseña el botón? Solo donde no caben las cuatro columnas, con algo que desplegar y sin una categoría o
    /// subcategoría elegida (lo elegido ya despliega sus subcategorías, como antes).
    static func showsToggle(
        fitsAllColumns: Bool,
        hasCategorySelection: Bool,
        hasSubcategories: Bool
    ) -> Bool {
        !fitsAllColumns && !hasCategorySelection && hasSubcategories
    }

    /// ¿Hay alguna subcategoría con importe que desplegar?
    static func hasSubcategories(_ data: SankeyData) -> Bool {
        data.nodes(in: .expenseSubcategory).contains { $0.amount > 0 }
    }

    /// Los datos con la columna de subcategorías lista para desplegarse: ordenada por categoría madre y con la cola
    /// en «Otros». El resto de columnas y enlaces no cambia.
    static func expanded(_ data: SankeyData, maxRows: Int = maxRows) -> SankeyData {
        let categories = data.nodes(in: .expenseCategory)
        let subcategories = data.nodes(in: .expenseSubcategory)
        guard !subcategories.isEmpty else { return data }

        let subcategoryIDs = Set(subcategories.map(\.id))
        // El enlace que llega a cada subcategoría (una sola madre por subcategoría).
        var incoming: [String: SankeyLink] = [:]
        for link in data.links where subcategoryIDs.contains(link.targetID) {
            incoming[link.targetID] = link
        }
        var categoryOrder: [String: Int] = [:]
        for (index, category) in categories.enumerated() where categoryOrder[category.id] == nil {
            categoryOrder[category.id] = index
        }

        // Reales: con categoría madre en la columna. Lo demás (el «Otros» del calculador, una huérfana) va a «Otros».
        let real = subcategories.filter { sub in
            guard !sub.isOtros, sub.amount > 0, let link = incoming[sub.id] else { return false }
            return categoryOrder[link.sourceID] != nil
        }
        let realIDs = Set(real.map(\.id))
        let unattributed = subcategories.filter { !realIDs.contains($0.id) && $0.amount > 0 }

        let keepsAll = real.count <= maxRows && unattributed.isEmpty
        let keptCount = keepsAll ? real.count : max(maxRows - 1, 0)
        let byAmount = real.sorted { lhs, rhs in
            lhs.amount != rhs.amount ? lhs.amount > rhs.amount : lhs.id < rhs.id
        }
        let kept = Array(byAmount.prefix(keptCount))
        let grouped = Array(byAmount.dropFirst(keptCount))

        // Orden de la columna: por la posición de su madre y, dentro, por importe.
        func parentIndex(_ sub: SankeyNode) -> Int {
            guard let link = incoming[sub.id] else { return Int.max }
            return categoryOrder[link.sourceID] ?? Int.max
        }
        let ordered = kept.sorted { lhs, rhs in
            let leftIndex = parentIndex(lhs)
            let rightIndex = parentIndex(rhs)
            if leftIndex != rightIndex { return leftIndex < rightIndex }
            if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
            return lhs.id < rhs.id
        }

        var subNodes = ordered
        var subLinks: [SankeyLink] = ordered.compactMap { incoming[$0.id] }

        let othersAmount = (grouped + unattributed).reduce(0.0) { $0 + $1.amount }
        if othersAmount > 0 {
            subNodes.append(SankeyNode(
                id: othersNodeID,
                column: .expenseSubcategory,
                name: L10n.Statistics.Sankey.others,
                amount: othersAmount,
                colorHex: othersColorHex,
                persistentID: nil,
                parentCategoryID: nil,
                isOtros: true,
                isTappable: false
            ))
            // Un enlace a «Otros» por categoría que aporta, en el orden de la columna de categorías.
            var perParent: [String: Double] = [:]
            for sub in grouped + unattributed {
                guard let link = incoming[sub.id], categoryOrder[link.sourceID] != nil else { continue }
                perParent[link.sourceID, default: 0] += link.amount
            }
            for category in categories {
                guard let amount = perParent[category.id], amount > 0 else { continue }
                subLinks.append(SankeyLink(
                    id: "\(category.id)__\(othersNodeID)",
                    sourceID: category.id,
                    targetID: othersNodeID,
                    amount: amount,
                    sourceColorHex: category.colorHex
                ))
            }
        }

        let otherNodes = data.nodes.filter { $0.column != .expenseSubcategory }
        let otherLinks = data.links.filter { !subcategoryIDs.contains($0.targetID) }
        return SankeyData(
            nodes: otherNodes + subNodes,
            links: otherLinks + subLinks,
            totalIncome: data.totalIncome,
            totalExpense: data.totalExpense,
            pool: data.pool
        )
    }
}
