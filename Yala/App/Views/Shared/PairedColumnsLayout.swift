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
//  (HIG · Designing for iPhone Duo). Y caer entre dos no es automático: el pliegue está en el centro de la PANTALLA y el
//  hueco entre columnas en el centro del CONTENIDO, que la barra vertical desplaza (medido el 2026-10-24 en el Duo
//  abierto en horizontal: pliegue de 455 a 495 pt, hueco en ~433; la columna derecha empezaba encima del pliegue). Con
//  `.readsVerticalFold(_:)` el contenedor mide el pliegue y los dos `Layout` ponen una columna a cada lado.
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

    /// Dónde van las dos columnas, en el espacio del contenedor.
    struct Columns: Equatable {
        var leadingWidth: CGFloat
        var trailingX: CGFloat
        var trailingWidth: CGFloat
    }

    /// Mitades con `columnSpacing` en medio; o, si un pliegue vertical cruza el contenedor (`fold`, en su espacio), una
    /// columna a cada lado de él, con el pliegue y sus márgenes de hueco. Solo si las dos siguen midiendo
    /// `minColumnWidth`: si no, mitades, como sin pliegue.
    static func columns(
        width: CGFloat,
        columnSpacing: CGFloat,
        minColumnWidth: CGFloat,
        fold: ClosedRange<CGFloat>?
    ) -> Columns {
        let half = (width - columnSpacing) / 2
        let even = Columns(leadingWidth: half, trailingX: half + columnSpacing, trailingWidth: half)
        guard let fold, fold.lowerBound > 0, fold.upperBound < width else { return even }
        let leading = fold.lowerBound
        let trailing = width - fold.upperBound
        guard leading + 0.5 >= minColumnWidth, trailing + 0.5 >= minColumnWidth else { return even }
        return Columns(leadingWidth: leading, trailingX: fold.upperBound, trailingWidth: trailing)
    }

    /// El pliegue que separa izquierda y derecha, de las regiones `division` activas que reporta el sistema (sus marcos,
    /// en el espacio de la vista): la primera más alta que ancha. Un pliegue horizontal (el Duo abierto en vertical) no
    /// separa columnas: lo cruza el scroll, y eso se permite (HIG).
    static func verticalFold(in divisions: [CGRect]) -> ClosedRange<CGFloat>? {
        guard let region = divisions.first(where: { $0.height > $0.width && $0.width > 0 }) else { return nil }
        return region.minX...region.maxX
    }

    /// El pliegue en el espacio de una vista que empieza en `originX` de la ventana. Sin medir la vista, nada.
    static func localFold(_ windowFold: ClosedRange<CGFloat>?, originX: CGFloat?) -> ClosedRange<CGFloat>? {
        guard let windowFold, let originX else { return nil }
        return (windowFold.lowerBound - originX)...(windowFold.upperBound - originX)
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
        fold: ClosedRange<CGFloat>? = nil,
        measure: (Int, CGFloat) -> CGFloat
    ) -> (placements: [Placement], height: CGFloat) {
        let columns = columnCount(width: width, minColumnWidth: minColumnWidth, columnSpacing: columnSpacing)
        let split = Self.columns(width: width, columnSpacing: columnSpacing, minColumnWidth: minColumnWidth, fold: fold)
        var placements = Array(repeating: Placement(origin: .zero, slotWidth: 0, slotHeight: 0), count: spans.count)
        var y: CGFloat = 0
        let allRows = rows(spans: spans, columns: columns)
        for (rowIndex, row) in allRows.enumerated() {
            let fullRow = row.count == 1 && (spans[row[0]] || columns == 1)
            func slot(_ column: Int) -> (x: CGFloat, width: CGFloat) {
                if fullRow { return (0, width) }
                return column == 0 ? (0, split.leadingWidth) : (split.trailingX, split.trailingWidth)
            }
            let rowHeight = row.enumerated().map { measure($0.element, slot($0.offset).width) }.max() ?? 0
            for (column, index) in row.enumerated() {
                let (x, slotWidth) = slot(column)
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
        fold: ClosedRange<CGFloat>? = nil,
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

        let split = columns(width: width, columnSpacing: columnSpacing, minColumnWidth: minColumnWidth, fold: fold)
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
            let slotWidth = column == .leading ? split.leadingWidth : split.trailingWidth
            let h = measure(index, slotWidth)
            let x = column == .leading ? 0 : split.trailingX
            placements[index] = Placement(origin: CGPoint(x: x, y: top), slotWidth: slotWidth, slotHeight: h)
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
    /// El pliegue que cruza la rejilla (iPhone Duo abierto en horizontal), en su espacio: ver `readsVerticalFold(_:)`.
    var fold: ClosedRange<CGFloat>?

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
            fold: fold,
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
    @State private var fold: ClosedRange<CGFloat>?

    var body: some View {
        let layout = DS.Adaptive.isWideScreen(sizeClass)
            ? AnyLayout(PairedColumnsLayout(rowSpacing: rowSpacing, columnSpacing: columnSpacing, fold: fold))
            : AnyLayout(VStackLayout(spacing: rowSpacing))
        layout { content }
            .readsVerticalFold($fold)
    }
}

// MARK: - Banda de cabecera

/// La cabecera del Panel en una ventana ancha: saldo y acciones a la izquierda, «Tus finanzas» a la derecha, el resto
/// a todo lo ancho. Alineado a la izquierda, como el `VStack(alignment: .leading)` al que sustituye.
struct HeaderBandLayout: Layout {
    var spacing: CGFloat
    var columnSpacing: CGFloat = DS.Spacing.lg
    var minColumnWidth: CGFloat = DS.Adaptive.pairedColumnMinWidth
    /// El pliegue que cruza la banda (iPhone Duo abierto en horizontal), en su espacio: ver `readsVerticalFold(_:)`.
    var fold: ClosedRange<CGFloat>?

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
            fold: fold,
            measure: { index, slotWidth in
                subviews[index].sizeThatFits(ProposedViewSize(width: slotWidth, height: nil)).height
            })
    }
}

// MARK: - Par de tarjetas a la misma altura (pares del Panel)

/// Dos hijos lado a lado, arriba alineados, cada uno en su columna: la izquierda y la derecha del pliegue. Solo se usa
/// cuando hay pliegue (`FoldAwarePair`); sin él, el `HStackLayout` de siempre.
struct FoldSplitPairLayout: Layout {
    var columnSpacing: CGFloat
    var minColumnWidth: CGFloat
    var fold: ClosedRange<CGFloat>

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = resolvedWidth(proposal, subviews)
        let split = columns(width: width)
        let heights = subviews.prefix(2).enumerated().map { offset, subview in
            subview.sizeThatFits(ProposedViewSize(width: offset == 0 ? split.leadingWidth : split.trailingWidth,
                                                  height: proposal.height)).height
        }
        return CGSize(width: width, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let split = columns(width: bounds.width)
        for (offset, subview) in subviews.enumerated() {
            let leading = offset == 0
            subview.place(
                at: CGPoint(x: bounds.minX + (leading ? 0 : split.trailingX), y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: leading ? split.leadingWidth : split.trailingWidth, height: bounds.height))
        }
    }

    private func columns(width: CGFloat) -> PairedColumnsLogic.Columns {
        PairedColumnsLogic.columns(width: width, columnSpacing: columnSpacing, minColumnWidth: minColumnWidth, fold: fold)
    }
}

/// Una fila de dos widgets del Panel: el `HStackLayout(alignment: .top, spacing:)` de siempre, o, con un pliegue que la
/// cruce (iPhone Duo abierto en horizontal), una a cada lado de él. `AnyLayout`: plegar o abrir no cambia la identidad de
/// los widgets. El contenedor mide el pliegue con `readsVerticalFold(_:)` y lo pasa.
func foldAwarePairLayout(spacing: CGFloat, fold: ClosedRange<CGFloat>?) -> AnyLayout {
    guard let fold else { return AnyLayout(HStackLayout(alignment: .top, spacing: spacing)) }
    return AnyLayout(FoldSplitPairLayout(columnSpacing: spacing, minColumnWidth: DS.Adaptive.pairedColumnMinWidth, fold: fold))
}

// MARK: - El pliegue

extension EnvironmentValues {
    /// El pliegue vertical activo del iPhone Duo, en coordenadas de la ventana (`.global`). Lo publica la raíz de la
    /// escena (`publishesVerticalFold()`); `nil` en cualquier otro aparato o postura.
    @Entry var verticalFoldInWindow: ClosedRange<CGFloat>? = nil
}

extension View {
    /// Solo en la raíz de la escena: mide el pliegue del iPhone Duo (región reservada `division` activa, iOS 27.1) sobre
    /// una vista que ocupa la ventana entera y lo publica en el entorno. Se mide aquí y no en cada contenedor porque el
    /// sistema da la región por INACTIVA en una vista que no la cruza de arriba abajo, y el contenido de un scroll casi
    /// nunca la cruza (medido el 2026-10-24: las rejillas del Panel la recibían inactiva).
    func publishesVerticalFold() -> some View {
        modifier(VerticalFoldPublisher())
    }

    /// El pliegue del iPhone Duo que cruza esta vista, en su propio espacio, en `fold`; `nil` si no hay. Para un
    /// contenedor en columnas que deba poner una a cada lado. Necesita `publishesVerticalFold()` en la raíz.
    func readsVerticalFold(_ fold: Binding<ClosedRange<CGFloat>?>) -> some View {
        modifier(VerticalFoldReader(fold: fold))
    }
}

private struct VerticalFoldPublisher: ViewModifier {
    @State private var fold: ClosedRange<CGFloat>?

    func body(content: Content) -> some View {
        content
            .background {
                if #available(iOS 27.1, *) {
                    Color.clear
                        .ignoresSafeArea()
                        .onGeometryChange(for: ClosedRange<CGFloat>?.self) { proxy in
                            guard let local = PairedColumnsLogic.verticalFold(
                                in: proxy.reservedRegions(kind: .division).filter(\.isActive).map(\.frame))
                            else { return nil }
                            let originX = proxy.frame(in: .global).minX
                            return (local.lowerBound + originX)...(local.upperBound + originX)
                        } action: { fold = $0 }
                }
            }
            .environment(\.verticalFoldInWindow, fold)
    }
}

private struct VerticalFoldReader: ViewModifier {
    @Binding var fold: ClosedRange<CGFloat>?
    @Environment(\.verticalFoldInWindow) private var windowFold
    /// Dónde empieza esta vista en la ventana. Solo cambia en horizontal: el scroll vertical no lo mueve.
    @State private var originX: CGFloat?

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minX } action: { originX = $0 }
            .onChange(of: PairedColumnsLogic.localFold(windowFold, originX: originX), initial: true) { _, local in
                fold = local
            }
    }
}

/// Sin ancho propuesto (medida ideal), el del hijo más ancho: es lo que haría un `VStack`.
private func resolvedWidth(_ proposal: ProposedViewSize, _ subviews: LayoutSubviews) -> CGFloat {
    if let width = proposal.width, width.isFinite { return width }
    return subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
}
