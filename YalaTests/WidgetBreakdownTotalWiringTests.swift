//
//  WidgetBreakdownTotalWiringTests.swift
//  YalaTests
//
//  Card znu5: con una devolución en el período, las tartas y los rankings de Categorías de la pantalla de inicio
//  enseñaban porcentajes de más del 100 % y un centro menor que la suma de sus filas. Desde el arreglo cada trozo es el
//  neto de su categoría (`WidgetInsightsLogic.netExpenseSlices`) y centro, «Otros» y porcentajes se miden contra la suma
//  de los trozos (`expenseBreakdownTotal`).
//
//  La lógica y la foto se prueban por comportamiento en `WidgetInsightsLogicTests` y `WidgetDataCacheTests`. La
//  extensión no se puede llamar desde aquí (`YalaTests` no compila `YalaWidgets`), así que su camino de emergencia y
//  las tartas se fijan por su código, sin comentarios: la regla de `testing.md` para cuando el source-scan es la única
//  red.
//

import Foundation
import Testing

@Suite("Widget · el desglose de categorías se mide contra la suma de sus trozos (znu5)")
struct WidgetBreakdownTotalWiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Código sin comentarios, una línea por sentencia y sin sangría: reindentar o documentar no lo rompe.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") && !$0.hasPrefix("///") }
            .joined(separator: "\n")
    }

    private static func scope(_ text: String, from start: String, to end: String) throws -> String {
        let lower = try #require(text.range(of: start), "No encuentro «\(start)»")
        let upper = try #require(text.range(of: end, range: lower.upperBound..<text.endIndex), "No encuentro «\(end)»")
        return String(text[lower.lowerBound..<upper.lowerBound])
    }

    @Test("El camino de emergencia de la extensión calcula el total del desglose y lo guarda en la foto")
    func extensionFallbackComputesTheBreakdownTotal() throws {
        let service = Self.codeOnly(try Self.source("YalaWidgets/Services/WidgetDataService.swift"))
        let summary = try Self.scope(
            service, from: "private static func buildPeriodSummary(", to: "static let uncategorizedKey"
        )
        for line in [
            "let categorySlices = categoryExpenseSlices(from: transactions)",
            "let expenseBreakdownTotal = WidgetInsightsLogic.breakdownTotal(categorySlices.map(\\.amount))",
            "let topCategories = Self.topCategories(from: categorySlices, breakdownTotal: expenseBreakdownTotal)",
            "let subcategoryBreakdown = subcategoryExpenseBreakdown(from: transactions)",
            "let topSubcategories = subcategoryBreakdown.rows",
            "expenseBreakdownTotal: expenseBreakdownTotal,",
            "expenseSubcategoryBreakdownTotal: subcategoryBreakdown.total",
        ] {
            #expect(summary.contains(line), "buildPeriodSummary de la extensión no lleva «\(line)»")
        }
        #expect(!summary.contains("totalExpense: expenseTotalMagnitude"), """
            Los porcentajes de las categorías no se miden contra la magnitud de los movimientos: con una devolución, los \
            trozos netos no suman eso.
            """)
    }

    @Test("Los trozos de la extensión son netos: la devolución resta de su categoría y de su subcategoría")
    func extensionSlicesAreNet() throws {
        let service = Self.codeOnly(try Self.source("YalaWidgets/Services/WidgetDataService.swift"))
        let builders = try Self.scope(
            service, from: "private static func categoryExpenseSlices(", to: "private static func buildCashFlowByDay("
        )
        #expect(builders.components(separatedBy: "contributions.append((key: key, expense: -tx.amountInPreferredCurrency))").count == 3,
                "Categorías y subcategorías apuntan cada movimiento con signo (dos veces)")
        #expect(builders.components(separatedBy: "WidgetInsightsLogic.netExpenseSlices(contributions)").count == 3,
                "Categorías y subcategorías agrupan con `netExpenseSlices` (dos veces)")
        #expect(builders.components(separatedBy: "WidgetInsightsLogic.breakdownPercentage(").count == 3,
                "Categorías y subcategorías miden el porcentaje con `breakdownPercentage` (dos veces)")
        #expect(builders.contains("key = \"\\u{1}rest_\\(categoryName)\""),
                "Lo que no tiene subcategoría entra en el total de subcategorías, por categoría")
        #expect(builders.contains("percentage: WidgetInsightsLogic.breakdownPercentage(entry.amount, of: total)"),
                "Las subcategorías se miden contra su propio total")
        #expect(!builders.contains("abs(tx.amountInPreferredCurrency)"), """
            Sumar la magnitud de cada movimiento es el bug: un gasto de 100 y su devolución de 30 daban un trozo de 130.
            """)
    }

    @Test("La foto de la extensión lee el total del desglose, y una foto vieja cae al gasto del período")
    func extensionSummaryReadsTheBreakdownTotal() throws {
        let service = Self.codeOnly(try Self.source("YalaWidgets/Services/WidgetDataService.swift"))
        #expect(service.contains("var expenseBreakdownTotal: Double? = nil"))
        #expect(service.contains("var breakdownTotal: Double { expenseBreakdownTotal ?? totalExpense }"))
        #expect(service.contains("var expenseSubcategoryBreakdownTotal: Double? = nil"))
        #expect(service.contains(
            "var subcategoryBreakdownTotal: Double { expenseSubcategoryBreakdownTotal ?? breakdownTotal }"
        ))
    }

    @Test("Las dos tartas ponen en el centro y miden «Otros» contra el total de su desglose")
    func piesUseTheBreakdownTotal() throws {
        let categories = Self.codeOnly(try Self.source("YalaWidgets/Widgets/CategoriesPieWidget.swift"))
        #expect(categories.contains("totalExpense: summary?.breakdownTotal ?? 0,"), "Categorías: el centro no es el total del desglose")
        #expect(categories.contains(
            "let othersPercentage = WidgetInsightsLogic.breakdownPercentage(othersAmount, of: summary?.breakdownTotal ?? 0)"
        ), "Categorías: «Otros» no se mide contra el total del desglose")
        #expect(!categories.contains("summary?.totalExpense"), "Categorías: lee el gasto con signo")

        let subcategories = Self.codeOnly(try Self.source("YalaWidgets/Widgets/SubcategoriesPieWidget.swift"))
        #expect(subcategories.contains("totalExpense: summary?.subcategoryBreakdownTotal ?? 0,"),
                "Subcategorías: el centro no es el total de su desglose")
        #expect(subcategories.contains("othersAmount, of: summary?.subcategoryBreakdownTotal ?? 0"),
                "Subcategorías: «Otros» no se mide contra el total de su desglose")
        #expect(!subcategories.contains("summary?.totalExpense"), "Subcategorías: lee el gasto con signo")
    }

    @Test("El resumen del mes mide «Otros» contra el total del desglose y su «Gastado» sigue siendo el gasto")
    func monthSummaryUsesTheBreakdownTotalForOthers() throws {
        let code = Self.codeOnly(try Self.source("YalaWidgets/Widgets/MonthSummaryWidget.swift"))
        #expect(code.contains(
            "categories: Self.groupCategories(summary?.topCategories ?? [], totalExpense: summary?.breakdownTotal ?? 0),"
        ))
        #expect(code.contains("let totalExpense = summary?.totalExpense ?? 0"))
    }
}
