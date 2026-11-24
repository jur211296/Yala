//
//  SankeySubcategoriasTests.swift
//  YalaTests
//
//  «Ver subcategorías» del Sankey de Distribución (pedido de Jürgen del 23-nov-2026). Fija:
//  - plegado (iPhone): el Sankey llega hasta las categorías y la columna de subcategorías no se coloca;
//  - desplegado: la columna se ordena por categoría madre, la cola va a «Otros» con un enlace por categoría y los
//    importes no se pierden;
//  - cuándo sale el botón, y que su texto existe en los 16 idiomas.
//

import CoreGraphics
import Foundation
import Testing
@testable import Yala

// MARK: - Fixture

private enum SankeyFixture {

    static func node(_ id: String, _ column: SankeyColumn, _ amount: Double, isOtros: Bool = false) -> SankeyNode {
        SankeyNode(
            id: id, column: column, name: id, amount: amount, colorHex: "#123456",
            persistentID: nil, parentCategoryID: nil, isOtros: isOtros, isTappable: false
        )
    }

    static func link(_ source: String, _ target: String, _ amount: Double) -> SankeyLink {
        SankeyLink(id: "\(source)__\(target)", sourceID: source, targetID: target, amount: amount, sourceColorHex: "#123456")
    }

    /// Salario → Gastos → {Comida 100, Casa 60} → subcategorías. El calculador las emite por importe, mezclando madres.
    /// `subcats`: (id, madre, importe).
    static func data(subcats: [(String, String, Double)], extraOtros: Double = 0) -> SankeyData {
        var nodes = [
            node("inc", .income, 160),
            node("pool", .pool, 160),
            node("cat_comida", .expenseCategory, 100),
            node("cat_casa", .expenseCategory, 60)
        ]
        var links = [
            link("inc", "pool", 160),
            link("pool", "cat_comida", 100),
            link("pool", "cat_casa", 60)
        ]
        for (id, parent, amount) in subcats.sorted(by: { $0.2 > $1.2 }) {
            nodes.append(node(id, .expenseSubcategory, amount))
            links.append(link(parent, id, amount))
        }
        if extraOtros > 0 {
            nodes.append(node("sub_otros", .expenseSubcategory, extraOtros, isOtros: true))
        }
        return SankeyData(nodes: nodes, links: links, totalIncome: 160, totalExpense: 160, pool: 160)
    }

    static func subcategoryTotal(_ data: SankeyData) -> Double {
        data.nodes(in: .expenseSubcategory).reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Cálculo de nodos y enlaces

@Suite("Sankey · subcategorías: nodos y enlaces")
struct SankeySubcategoriasExpansionTests {

    @Test("Plegado en el iPhone: hasta las categorías, sin columna de subcategorías")
    func collapsed_reachesCategoriesOnly() {
        let columns = SankeyColumnLayoutLogic.columns(containerWidth: 370, hasCategorySelection: false)
        #expect(columns.visible == [.income, .pool, .expenseCategory])
        #expect(!columns.shows(.expenseSubcategory))
    }

    @Test("Desplegado en el iPhone: las cuatro columnas, con las subcategorías a un deslizamiento")
    func expanded_addsTheSubcategoryColumn() {
        // La vista pide las cuatro pasando «desplegado» como selección.
        let columns = SankeyColumnLayoutLogic.columns(containerWidth: 370, hasCategorySelection: true)
        #expect(columns.visible == SankeyColumn.allCases)
        #expect(columns.totalWidth > 370)
    }

    @Test("Desplegado: la columna va por categoría madre y, dentro, por importe")
    func expanded_ordersByParentThenAmount() {
        let data = SankeyFixture.data(subcats: [
            ("s_super", "cat_comida", 50), ("s_luz", "cat_casa", 45),
            ("s_resto", "cat_comida", 30), ("s_agua", "cat_casa", 15), ("s_cafe", "cat_comida", 20)
        ])
        let result = SankeySubcategoryExpansion.expanded(data)
        let ids = result.nodes(in: .expenseSubcategory).map(\.id)
        #expect(ids == ["s_super", "s_resto", "s_cafe", "s_luz", "s_agua"])
        // Los enlaces madre → subcategoría siguen el mismo orden (las bandas no se cruzan dentro de una categoría).
        let subLinkTargets = result.links.filter { ids.contains($0.targetID) }.map(\.targetID)
        #expect(subLinkTargets == ids)
        #expect(!ids.contains(SankeySubcategoryExpansion.othersNodeID))
    }

    @Test("Desplegado: el resto de columnas y enlaces no cambia")
    func expanded_keepsOtherColumns() {
        let data = SankeyFixture.data(subcats: [("s_super", "cat_comida", 50), ("s_luz", "cat_casa", 45)])
        let result = SankeySubcategoryExpansion.expanded(data)
        #expect(result.nodes.filter { $0.column != .expenseSubcategory } == data.nodes.filter { $0.column != .expenseSubcategory })
        #expect(result.links.filter { !$0.targetID.hasPrefix("s_") } == data.links.filter { !$0.targetID.hasPrefix("s_") })
        #expect(result.totalExpense == data.totalExpense)
    }

    @Test("Con más de ocho subcategorías: las siete mayores y «Otros», con un enlace por categoría que aporta")
    func expanded_groupsTheLongTailInOthers() {
        var subcats: [(String, String, Double)] = []
        for index in 0..<6 { subcats.append(("s_comida\(index)", "cat_comida", Double(20 - index))) }
        for index in 0..<6 { subcats.append(("s_casa\(index)", "cat_casa", Double(10 - index))) }
        let data = SankeyFixture.data(subcats: subcats)
        let result = SankeySubcategoryExpansion.expanded(data)
        let subNodes = result.nodes(in: .expenseSubcategory)

        #expect(subNodes.count == SankeySubcategoryExpansion.maxRows)
        let others = subNodes.last
        #expect(others?.id == SankeySubcategoryExpansion.othersNodeID)
        #expect(others?.isOtros == true)
        #expect(others?.isTappable == false)
        // Ningún importe se pierde al agrupar.
        #expect(abs(SankeyFixture.subcategoryTotal(result) - SankeyFixture.subcategoryTotal(data)) < 0.001)

        // Las seis de Comida (20…15) y la mayor de Casa (10) se quedan; las otras cinco de Casa van a «Otros».
        let kept = subNodes.dropLast().map(\.id)
        #expect(kept == ["s_comida0", "s_comida1", "s_comida2", "s_comida3", "s_comida4", "s_comida5", "s_casa0"])
        let othersLinks = result.links.filter { $0.targetID == SankeySubcategoryExpansion.othersNodeID }
        #expect(othersLinks.map(\.sourceID) == ["cat_casa"])
        let othersFromCasa: Double = 9 + 8 + 7 + 6 + 5
        #expect(othersLinks.first?.amount == othersFromCasa)
        // Cada nodo de subcategoría recibe exactamente lo que vale.
        for sub in subNodes {
            let incoming = result.links.filter { $0.targetID == sub.id }.reduce(0) { $0 + $1.amount }
            #expect(abs(incoming - sub.amount) < 0.001)
        }
    }

    @Test("Con dos categorías en la cola, «Otros» recibe un enlace de cada una, en el orden de las categorías")
    func expanded_othersGetsOneLinkPerParent() {
        var subcats: [(String, String, Double)] = []
        for index in 0..<5 { subcats.append(("s_comida\(index)", "cat_comida", Double(30 - index))) }
        for index in 0..<5 { subcats.append(("s_casa\(index)", "cat_casa", Double(29 - index) - 0.5)) }
        let result = SankeySubcategoryExpansion.expanded(SankeyFixture.data(subcats: subcats))
        let othersLinks = result.links.filter { $0.targetID == SankeySubcategoryExpansion.othersNodeID }
        #expect(othersLinks.map(\.sourceID) == ["cat_comida", "cat_casa"])
    }

    @Test("El «Otros» sin enlace del calculador se suma al «Otros» desplegado, sin duplicarlo")
    func expanded_absorbsTheCalculatorOthers() {
        let data = SankeyFixture.data(subcats: [("s_super", "cat_comida", 50), ("s_luz", "cat_casa", 45)], extraOtros: 12)
        let result = SankeySubcategoryExpansion.expanded(data)
        let others = result.nodes(in: .expenseSubcategory).filter(\.isOtros)
        #expect(others.count == 1)
        #expect(others.first?.amount == 12)
        #expect(abs(SankeyFixture.subcategoryTotal(result) - SankeyFixture.subcategoryTotal(data)) < 0.001)
    }

    @Test("Ocho subcategorías justas caben sin «Otros»")
    func expanded_exactlyMaxRows_hasNoOthers() {
        let subcats = (0..<8).map { ("s\($0)", $0 < 4 ? "cat_comida" : "cat_casa", Double(10 + $0)) }
        let result = SankeySubcategoryExpansion.expanded(SankeyFixture.data(subcats: subcats))
        #expect(result.nodes(in: .expenseSubcategory).count == 8)
        let hasOthers = result.nodes(in: .expenseSubcategory).contains { $0.isOtros }
        #expect(!hasOthers)
    }

    @Test("Sin subcategorías no hay nada que desplegar")
    func noSubcategories_isUnchanged() {
        let data = SankeyFixture.data(subcats: [])
        #expect(!SankeySubcategoryExpansion.hasSubcategories(data))
        #expect(SankeySubcategoryExpansion.expanded(data) == data)
    }
}

// MARK: - Cuándo sale el botón

@Suite("Sankey · subcategorías: el botón")
struct SankeySubcategoriasToggleTests {

    @Test("Sale en el iPhone con subcategorías y nada elegido")
    func showsOnPhone() {
        #expect(SankeySubcategoryExpansion.showsToggle(fitsAllColumns: false, hasCategorySelection: false, hasSubcategories: true))
    }

    @Test("No sale donde ya caben las cuatro columnas (iPad)")
    func hiddenWhereAllColumnsFit() {
        let fits = SankeyColumnLayoutLogic.columns(containerWidth: 700, hasCategorySelection: false)
            .visible.count == SankeyColumn.allCases.count
        #expect(fits)
        #expect(!SankeySubcategoryExpansion.showsToggle(fitsAllColumns: fits, hasCategorySelection: false, hasSubcategories: true))
    }

    @Test("No sale con una categoría elegida (ya despliega sus subcategorías) ni sin subcategorías")
    func hiddenWithSelectionOrNothingToShow() {
        #expect(!SankeySubcategoryExpansion.showsToggle(fitsAllColumns: false, hasCategorySelection: true, hasSubcategories: true))
        #expect(!SankeySubcategoryExpansion.showsToggle(fitsAllColumns: false, hasCategorySelection: false, hasSubcategories: false))
    }
}

// MARK: - Textos y cableado

@Suite("Sankey · subcategorías: textos y cableado")
struct SankeySubcategoriasWiringTests {

    private static let locales = [
        "es-419", "es", "es-AR", "es-ES", "en", "en-GB", "pt-BR", "pt-PT", "pt",
        "fr", "de", "it", "ja", "nl", "pl", "zh-Hans"
    ]
    private static let keys = ["show", "hide", "showHint", "hideHint"].map { "sankeySubcategorias.\($0)" }

    private static var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    @Test("La tabla SankeySubcategorias trae las cuatro claves en los 16 idiomas", arguments: locales)
    func everyLocaleHasTheKeys(locale: String) throws {
        let url = Self.root.appendingPathComponent("Yala/Resources/\(locale).lproj/SankeySubcategorias.strings")
        let table = try #require(NSDictionary(contentsOf: url) as? [String: String])
        for key in Self.keys {
            let value = try #require(table[key], "\(locale) sin \(key)")
            #expect(!value.isEmpty)
        }
    }

    @Test("Los textos se resuelven en el bundle de la app")
    func textsResolve() {
        #expect(!SankeySubcategoriasText.show.hasPrefix("sankeySubcategorias."))
        #expect(!SankeySubcategoriasText.hide.hasPrefix("sankeySubcategorias."))
        #expect(SankeySubcategoriasText.show != SankeySubcategoriasText.hide)
    }

    @Test("El Sankey aplica el despliegue y pide las cuatro columnas al desplegar")
    func chartIsWired() throws {
        let url = Self.root.appendingPathComponent("Yala/App/Views/Statistics/Sankey/SankeyChartView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("SankeySubcategoryExpansion.expanded("))
        #expect(source.contains("hasCategorySelection: hasCategorySelection || showsExpandedSubcategories"))
        #expect(source.contains("\"sankey_subcategories_toggle\""))
        // Arranca plegado: el inicio es hasta las categorías.
        #expect(source.contains("@State private var subcategoriesExpanded = false"))
    }
}
