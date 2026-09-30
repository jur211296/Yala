//
//  PairedColumnsLayout.swift
//  Yala
//
//  Rejillas en pares para una ventana ancha (ADR «Yala se adapta por espacio, no por dispositivo», 2026-09-27).
//  Dos contenedores, los dos `Layout`, para que la vista cambie de una columna a dos con `AnyLayout` sin cambiar de
//  hijos ni de identidad al redimensionar:
//
//  - `PairedColumnsLayout`: los hijos, en orden, de dos en dos; el que lleva `.spansAllColumns()` (una cabecera, un
//    selector) ocupa la fila entera; un impar se queda en la columna izquierda.
//  - `HeaderBandLayout`: la cabecera del Panel. Los hijos marcados `.headerBandColumn(.leading/.trailing)` forman una
//    banda de dos columnas; los demás van a todo lo ancho, arriba o debajo de la banda según su orden.
//
//  En compacta NO se usan: la vista monta el `VStackLayout` de siempre, con los mismos parámetros, así el iPhone queda
//  igual por construcción. Aquí solo se decide lo ancho, y también aquí se vuelve a una columna si no caben dos de
//  `minColumnWidth` (Yala IA abierto al lado, una ventana regular estrecha).
//
//  Pares, y no tres columnas, para que en el iPhone Duo a medio plegar el pliegue caiga entre dos
//  (HIG · Designing for iPhone Duo).
//

import SwiftUI

// MARK: - Marcas de los hijos

nonisolated private struct SpansAllColumnsKey: LayoutValueKey {
    static let defaultValue = false
}

/// En qué columna de la banda de cabecera va un hijo de `HeaderBandLayout`. Sin marca, a todo lo ancho.
nonisolated enum HeaderBandColumn {
    case leading
    case trailing
}

nonisolated private struct HeaderBandColumnKey: LayoutValueKey {
    static let defaultValue: HeaderBandColumn? = nil
}

extension View {
    /// En un `PairedColumnsLayout`, este hijo ocupa la fila entera (cabeceras, selectores). Fuera de él no hace nada.
    func spansAllColumns(_ spans: Bool = true) -> some View {
        layoutValue(key: SpansAllColumnsKey.self, value: spans)
    }

    /// En un `HeaderBandLayout`, la columna de la banda donde va este hijo. Fuera de él no hace nada.
    func headerBandColumn(_ column: HeaderBandColumn) -> some View {
        layoutValue(key: HeaderBandColumnKey.self, value: column)
    }
}

// MARK: - Lógica pura (con test)

/// El reparto de `PairedColumnsLayout` y `HeaderBandLayout`, separado de SwiftUI para poder probarlo: recibe cómo se
/// mide cada hijo a un ancho dado y devuelve dónde va.
nonisolated enum PairedColumnsLogic {

    /// Cuántas columnas caben: dos si caben dos de `minColumnWidth` con su separación, una si no.
    static func columnCount(width: CGFloat, minColumnWidth: CGFloat, columnSpacing: CGFloat) -> Int {
        width + 0.5 >= minColumnWidth * 2 + columnSpacing ? 2 : 1
    }

    /// Las filas: índices de los hijos en orden, de dos en dos; uno que ocupa todo va solo en su fila y cierra la
    /// anterior aunque esté a medias.
    static func rows(spans: [Bool], columns: Int) -> [[Int]] {
        var rows: [[Int]] = []
        var current: [Int] = []
        for (index, spansAll) in spans.enumerated() {
            if spansAll || columns <= 1 {
                if !current.isEmpty { rows.append(current); current = [] }
                rows.append([index])
            } else {
                current.append(index)
                if current.count == columns { rows.append(current); current = [] }
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    struct Placement: Equatable {
        /// Origen arriba-izquierda del hueco del hijo.
        var origin: CGPoint
        /// Ancho del hueco (la columna, o la fila entera).
        var slotWidth: CGFloat
        /// Alto del hueco (el de la fila).
        var slotHeight: CGFloat
    }

    /// Dónde va cada hijo de una rejilla en pares, y el alto total. `measure(i, ancho)` es el alto del hijo `i` a ese
    /// ancho.
    static func pairedPlacements(
        width: CGFloat,
        spans: [Bool],
        minColumnWidth: CGFloat,
        columnSpacing: CGFloat,
        rowSpacing: CGFloat,
        measure: (Int, CGFloat) -> CGFloat
    ) -> (placements: [Placement], height: CGFloat) {
        let columns = columnCount(width: width, minColumnWidth: minColumnWidth, columnSpacing: columnSpacing)
        let columnWidth = columns > 1 ? (width - columnSpacing * CGFloat(columns - 1)) / CGFloat(columns) : width
        var placements = Array(repeating: Placement(origin: .zero, slotWidth: 0, slotHeight: 0), count: spans.count)
        var y: CGFloat = 0
        let allRows = rows(spans: spans, columns: columns)
        for (rowIndex, row) in allRows.enumerated() {
            let fullRow = row.count == 1 && (spans[row[0]] || columns == 1)
            let slotWidth = fullRow ? width : columnWidth
            let rowHeight = row.map { measure($0, slotWidth) }.max() ?? 0
            for (column, index) in row.enumerated() {
                let x = fullRow ? 0 : CGFloat(column) * (columnWidth + columnSpacing)
                placements[index] = Placement(origin: CGPoint(x: x, y: y), slotWidth: slotWidth, slotHeight: rowHeight)
            }
            y += rowHeight
            if rowIndex < allRows.count - 1 { y += rowSpacing }
        }
        return (placements, y)
    }

    /// Dónde va cada hijo de la banda de cabecera, y el alto total. Con dos columnas y algún hijo en la derecha, los
    /// marcados forman la banda (cada columna apilada en su orden) en el sitio del primero; los demás, a todo lo ancho
    /// arriba si van antes y debajo si van después. Sin columna derecha o sin sitio, una pila en orden.
    static func bandPlacements(
        width: CGFloat,
        columns bandColumns: [HeaderBandColumn?],
        minColumnWidth: CGFloat,
        columnSpacing: CGFloat,
        spacing: CGFloat,
        measure: (Int, CGFloat) -> CGFloat
    ) -> (placements: [Placement], height: CGFloat) {
        var placements = Array(repeating: Placement(origin: .zero, slotWidth: 0, slotHeight: 0), count: bandColumns.count)
        let fits = columnCount(width: width, minColumnWidth: minColumnWidth, columnSpacing: columnSpacing) == 2
        let hasTrailing = bandColumns.contains { $0 == .trailing }
        let firstBand = bandColumns.firstIndex { $0 != nil }

        guard fits, hasTrailing, let firstBand else {
            var y: CGFloat = 0
            for index in bandColumns.indices {
                let h = measure(index, width)
                placements[index] = Placement(origin: CGPoint(x: 0, y: y), slotWidth: width, slotHeight: h)
                y += h + (index < bandColumns.count - 1 ? spacing : 0)
            }
            return (placements, y)
        }

        let columnWidth = (width - columnSpacing) / 2
        var y: CGFloat = 0
        var needsSpacing = false
        func stackFullWidth(_ index: Int) {
            if needsSpacing { y += spacing }
            let h = measure(index, width)
            placements[index] = Placement(origin: CGPoint(x: 0, y: y), slotWidth: width, slotHeight: h)
            y += h
            needsSpacing = true
        }

        for index in 0..<firstBand where bandColumns[index] == nil { stackFullWidth(index) }

        if needsSpacing { y += spacing }
        let bandTop = y
        var columnBottoms: [HeaderBandColumn: CGFloat] = [.leading: bandTop, .trailing: bandTop]
        var columnStarted: [HeaderBandColumn: Bool] = [.leading: false, .trailing: false]
        for index in bandColumns.indices {
            guard let column = bandColumns[index] else { continue }
            var top = columnBottoms[column] ?? bandTop
            if columnStarted[column] == true { top += spacing }
            let h = measure(index, columnWidth)
            let x = column == .leading ? 0 : columnWidth + columnSpacing
            placements[index] = Placement(origin: CGPoint(x: x, y: top), slotWidth: columnWidth, slotHeight: h)
            columnBottoms[column] = top + h
            columnStarted[column] = true
        }
        y = max(columnBottoms[.leading] ?? bandTop, columnBottoms[.trailing] ?? bandTop)
        needsSpacing = true

        for index in bandColumns.indices where index > firstBand && bandColumns[index] == nil { stackFullWidth(index) }
        return (placements, y)
    }
}

// MARK: - Rejilla en pares

/// Hijos de dos en dos en una ventana ancha. Ver la cabecera del fichero.
struct PairedColumnsLayout: Layout {
    var rowSpacing: CGFloat
    var columnSpacing: CGFloat = DS.Spacing.md
    var minColumnWidth: CGFloat = DS.Adaptive.pairedColumnMinWidth
    /// Cómo se alinea en su hueco un hijo más estrecho que él. `.center`, como el `VStack` por defecto.
    var alignment: HorizontalAlignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = resolvedWidth(proposal, subviews)
        return CGSize(width: width, height: layout(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let slot = result.placements[index]
            let size = subview.sizeThatFits(ProposedViewSize(width: slot.slotWidth, height: slot.slotHeight))
            let dx: CGFloat
            switch alignment {
            case .leading: dx = 0
            case .trailing: dx = max(0, slot.slotWidth - size.width)
            default: dx = max(0, (slot.slotWidth - size.width) / 2)
            }
            subview.place(
                at: CGPoint(x: bounds.minX + slot.origin.x + dx, y: bounds.minY + slot.origin.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: slot.slotWidth, height: slot.slotHeight))
        }
    }

    private func layout(width: CGFloat, subviews: Subviews) -> (placements: [PairedColumnsLogic.Placement], height: CGFloat) {
        PairedColumnsLogic.pairedPlacements(
            width: width,
            spans: subviews.map { $0[SpansAllColumnsKey.self] },
            minColumnWidth: minColumnWidth,
            columnSpacing: columnSpacing,
            rowSpacing: rowSpacing,
            measure: { index, slotWidth in
                subviews[index].sizeThatFits(ProposedViewSize(width: slotWidth, height: nil)).height
            })
    }
}

/// Una lista de tarjetas que en compacta es el `VStackLayout(spacing:)` de siempre (el iPhone no cambia) y en ancha
/// `PairedColumnsLayout`. Con `AnyLayout` los hijos no cambian de identidad al redimensionar. Los hijos marcados
/// `.spansAllColumns()` ocupan la fila entera.
struct PairedCardsStack<Content: View>: View {
    var rowSpacing: CGFloat
    var columnSpacing: CGFloat = DS.Spacing.lg
    @ViewBuilder var content: Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let layout = DS.Adaptive.isWideScreen(sizeClass)
            ? AnyLayout(PairedColumnsLayout(rowSpacing: rowSpacing, columnSpacing: columnSpacing))
            : AnyLayout(VStackLayout(spacing: rowSpacing))
        layout { content }
    }
}

// MARK: - Banda de cabecera

/// La cabecera del Panel en una ventana ancha: saldo y acciones a la izquierda, «Tus finanzas» a la derecha, el resto
/// a todo lo ancho. Alineado a la izquierda, como el `VStack(alignment: .leading)` al que sustituye.
struct HeaderBandLayout: Layout {
    var spacing: CGFloat
    var columnSpacing: CGFloat = DS.Spacing.lg
    var minColumnWidth: CGFloat = DS.Adaptive.pairedColumnMinWidth

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = resolvedWidth(proposal, subviews)
        return CGSize(width: width, height: layout(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let slot = result.placements[index]
            subview.place(
                at: CGPoint(x: bounds.minX + slot.origin.x, y: bounds.minY + slot.origin.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: slot.slotWidth, height: slot.slotHeight))
        }
    }

    private func layout(width: CGFloat, subviews: Subviews) -> (placements: [PairedColumnsLogic.Placement], height: CGFloat) {
        PairedColumnsLogic.bandPlacements(
            width: width,
            columns: subviews.map { $0[HeaderBandColumnKey.self] },
            minColumnWidth: minColumnWidth,
            columnSpacing: columnSpacing,
            spacing: spacing,
            measure: { index, slotWidth in
                subviews[index].sizeThatFits(ProposedViewSize(width: slotWidth, height: nil)).height
            })
    }
}

/// Sin ancho propuesto (medida ideal), el del hijo más ancho: es lo que haría un `VStack`.
private func resolvedWidth(_ proposal: ProposedViewSize, _ subviews: LayoutSubviews) -> CGFloat {
    if let width = proposal.width, width.isFinite { return width }
    return subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
}
