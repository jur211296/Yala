//
//  SankeyColumnLayoutLogicTests.swift
//  YalaTests
//
//  G3 de la decisión 28 (revisión 2.3, Estadísticas con diez años): en el ancho de un iPhone el Sankey se ve entero en
//  tres columnas —ingresos, flujo y categorías— sin desplazar. Con cuatro columnas fijas de 220 pt hacían falta dos
//  deslizamientos para llegar a las categorías.
//

import CoreGraphics
import Testing
@testable import Yala

@Suite("Sankey · columnas por ancho (G3)")
struct SankeyColumnLayoutLogicTests {

    /// El ancho de la tarjeta en un iPhone 17 Pro (402 pt de pantalla menos márgenes) y en un SE.
    private static let iPhoneWidths: [CGFloat] = [370, 343, 311]

    @Test("En el ancho de un iPhone caben ingresos, flujo y categorías, sin desplazar", arguments: iPhoneWidths)
    func iPhoneWidth_showsThreeColumnsThatFit(width: CGFloat) {
        let columns = SankeyColumnLayoutLogic.columns(containerWidth: width, hasCategorySelection: false)
        #expect(columns.visible == [.income, .pool, .expenseCategory])
        #expect(!columns.shows(.expenseSubcategory))
        #expect(columns.totalWidth <= width + 0.5)
        // Las categorías, la columna de los nombres largos, llevan más sitio que las otras dos.
        let category = columns.width[.expenseCategory] ?? 0
        #expect(category > (columns.width[.income] ?? 0))
        #expect(columns.stacksLabels)
    }

    @Test("Con una categoría elegida vuelven sus subcategorías, a un deslizamiento")
    func iPhoneWidth_withACategoryChosen_addsSubcategories() {
        let columns = SankeyColumnLayoutLogic.columns(containerWidth: 370, hasCategorySelection: true)
        #expect(columns.visible == SankeyColumn.allCases)
        // Las tres primeras siguen cabiendo en la pantalla: el deslizamiento lleva solo a las subcategorías.
        let subcategoryStart = columns.originX[.expenseSubcategory] ?? 0
        #expect(subcategoryStart <= 370 + SankeyColumnLayoutLogic.columnGap)
        #expect(columns.totalWidth > 370)
    }

    @Test("En el ancho del iPad caben las cuatro, repartidas")
    func wideWidth_showsFourColumnsThatFit() {
        let columns = SankeyColumnLayoutLogic.columns(containerWidth: 700, hasCategorySelection: false)
        #expect(columns.visible == SankeyColumn.allCases)
        #expect(columns.totalWidth <= 700 + 0.5)
        #expect(!columns.stacksLabels)
        let widths = Set(columns.visible.compactMap { columns.width[$0] }.map { Int($0.rounded()) })
        #expect(widths.count == 1)
    }

    @Test("Sin medir todavía, las cuatro de siempre")
    func unmeasured_keepsTheFourFixedColumns() {
        let columns = SankeyColumnLayoutLogic.columns(containerWidth: 0, hasCategorySelection: false)
        #expect(columns.visible == SankeyColumn.allCases)
        #expect(columns.width[.income] == SankeyColumnLayoutLogic.scrollingColumnWidth)
    }

    @Test("Las columnas no se solapan y van en orden")
    func columnsAreOrderedWithoutOverlap() {
        for width in [311, 370, 520, 700, 1000] as [CGFloat] {
            for selected in [false, true] {
                let columns = SankeyColumnLayoutLogic.columns(containerWidth: width, hasCategorySelection: selected)
                var previousEnd: CGFloat = -SankeyColumnLayoutLogic.columnGap
                for column in columns.visible {
                    let start = columns.originX[column] ?? -1
                    #expect(start >= previousEnd + SankeyColumnLayoutLogic.columnGap - 0.01)
                    previousEnd = start + (columns.width[column] ?? 0)
                }
                #expect(abs(previousEnd - columns.totalWidth) < 0.01)
            }
        }
    }
}
