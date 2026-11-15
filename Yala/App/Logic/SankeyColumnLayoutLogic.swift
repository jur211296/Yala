//
//  SankeyColumnLayoutLogic.swift
//  Yala
//
//  Qué columnas pinta el Sankey y con qué ancho. Con columnas fijas de 220 pt, en el iPhone se veían «Salario → Gastos»
//  y hacían falta dos deslizamientos laterales para llegar a las categorías (revisión 2.3, problema 7; decisión 28 de
//  Jürgen, opción G3: «el Sankey del iPhone empieza en las categorías»).
//
//  Tres casos, por el ancho que hay y no por el aparato:
//  - Caben las cuatro columnas a un ancho legible: las cuatro, repartidas en el ancho (el iPad, «donde ya cabe entero»).
//  - No caben y no hay ninguna categoría elegida: tres columnas que caben (ingresos, flujo y categorías), sin
//    desplazar. Las subcategorías se dejan para el toque en una categoría.
//  - No caben y hay una categoría o subcategoría elegida: las cuatro, con las subcategorías de lo elegido, y se
//    desplaza a lo ancho como antes.
//

import CoreGraphics

enum SankeyColumnLayoutLogic {

    /// El ancho de columna de siempre, para cuando aún no se ha medido el ancho.
    static let scrollingColumnWidth: CGFloat = 220
    /// Por debajo de este ancho la etiqueta de una columna ya no se lee en una línea («Alimentación» y su importe).
    static let minimumFittedColumnWidth: CGFloat = 150
    /// Hueco entre columnas.
    static let columnGap: CGFloat = 10
    /// En tres columnas, la de categorías lleva más sitio: sus nombres son los largos.
    private static let compactWeights: [SankeyColumn: CGFloat] = [.income: 1, .pool: 1, .expenseCategory: 1.4]

    struct Columns: Equatable {
        /// Las columnas que se pintan, en orden.
        let visible: [SankeyColumn]
        let originX: [SankeyColumn: CGFloat]
        let width: [SankeyColumn: CGFloat]
        let totalWidth: CGFloat
        /// La etiqueta va en dos líneas (nombre arriba, cifra abajo): en tres columnas no cabe en una.
        let stacksLabels: Bool

        func shows(_ column: SankeyColumn) -> Bool { originX[column] != nil }
    }

    /// - Parameters:
    ///   - containerWidth: el ancho que ocupa la gráfica; `0` mientras no se ha medido.
    ///   - hasCategorySelection: hay una categoría o subcategoría elegida (sus subcategorías ya dicen algo).
    static func columns(containerWidth: CGFloat, hasCategorySelection: Bool) -> Columns {
        let all = SankeyColumn.allCases
        guard containerWidth > 0 else {
            return uniform(all, width: scrollingColumnWidth, stacksLabels: false)
        }

        let fittedFour = fittedWidth(count: all.count, in: containerWidth)
        if fittedFour >= minimumFittedColumnWidth {
            return uniform(all, width: fittedFour, stacksLabels: false)
        }

        let three: [SankeyColumn] = [.income, .pool, .expenseCategory]
        let compact = proportionalWidths(three, in: containerWidth)
        if hasCategorySelection {
            // Las cuatro, con los anchos de las tres que caben: las subcategorías de lo elegido, a un deslizamiento.
            var widths = compact
            widths[.expenseSubcategory] = compact[.expenseCategory] ?? scrollingColumnWidth
            return place(all, widths: widths, stacksLabels: true)
        }
        return place(three, widths: compact, stacksLabels: true)
    }

    // MARK: - Helpers

    private static func fittedWidth(count: Int, in containerWidth: CGFloat) -> CGFloat {
        let gaps = CGFloat(max(count - 1, 0)) * columnGap
        return max((containerWidth - gaps) / CGFloat(count), 0)
    }

    private static func proportionalWidths(_ columns: [SankeyColumn], in containerWidth: CGFloat) -> [SankeyColumn: CGFloat] {
        let gaps = CGFloat(max(columns.count - 1, 0)) * columnGap
        let available = max(containerWidth - gaps, 0)
        let totalWeight = columns.reduce(0) { $0 + (compactWeights[$1] ?? 1) }
        var widths: [SankeyColumn: CGFloat] = [:]
        for column in columns {
            widths[column] = available * (compactWeights[column] ?? 1) / totalWeight
        }
        return widths
    }

    private static func uniform(_ columns: [SankeyColumn], width: CGFloat, stacksLabels: Bool) -> Columns {
        var widths: [SankeyColumn: CGFloat] = [:]
        for column in columns { widths[column] = width }
        return place(columns, widths: widths, stacksLabels: stacksLabels)
    }

    private static func place(_ columns: [SankeyColumn], widths: [SankeyColumn: CGFloat], stacksLabels: Bool) -> Columns {
        var origins: [SankeyColumn: CGFloat] = [:]
        var x: CGFloat = 0
        for (index, column) in columns.enumerated() {
            if index > 0 { x += columnGap }
            origins[column] = x
            x += widths[column] ?? 0
        }
        return Columns(visible: columns, originX: origins, width: widths, totalWidth: x, stacksLabels: stacksLabels)
    }
}
