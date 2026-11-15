//
//  StatisticsNecesariasLote07Tests.swift
//  YalaTests
//
//  Lote 07 de mejoras necesarias 2.3 (Estadísticas: textos que dicen lo que no es). Un bloque por punto:
//  (1) el nombre del período no entra en una frase («Probaste X este Este mes»);
//  (2) los vacíos no dicen «insights» y Distribución no dice «Aún no tienes categorías» cuando solo faltan movimientos;
//  (3) la guía de Tendencias no da por hecho que la gráfica es de gasto y la de Registros no dice «Todos tus gastos»;
//  (4) el botón de montos del Sankey pinta la divisa del Sankey y el Sankey funde el borde en vez de partir etiquetas;
//  (5) la cabecera de Distribución y la tarta cuentan lo mismo, y «N registros» lleva separador de miles.
//
//  Los textos se leen de los `Localizable.strings` FUENTE de los 16 idiomas (vía `#filePath`), como
//  `PrivacyCopyForbiddenPhrasesTests`: el idioma del simulador no decide qué se comprueba.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Fuente

private enum Lote07Source {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let locales = [
        "de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl", "pt", "pt-BR", "pt-PT",
        "zh-Hans",
    ]

    /// Las claves y valores de un `Localizable.strings` de la app.
    static func strings(_ locale: String) throws -> [String: String] {
        let url = repoRoot.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String], "\(locale): no se pudo leer el catálogo")
    }

    /// El código de un fichero sin las líneas de comentario.
    static func code(_ path: String) throws -> String {
        let source = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }
}

// MARK: - (1) El nombre del período no entra en una frase

@Suite("Lote 07 · (1) los hallazgos no meten el nombre del período en la frase")
struct PeriodNameStaysOutOfInsightSentencesTests {

    /// «Este mes», «Mes pasado», «Últimos 30 días» son rótulos: en «este %@» salía «este Este mes». Las tres frases que
    /// los metían ya no reciben el período, en ningún idioma.
    @Test(arguments: Lote07Source.locales)
    func lasFrasesNuevasNoLlevanPeriodo(locale: String) throws {
        let strings = try Lote07Source.strings(locale)
        let newCategory = try #require(strings["stats.distribution.insight.newCategoryInPeriod %@"], "\(locale)")
        #expect(newCategory.components(separatedBy: "%@").count == 2, "\(locale): un solo hueco, el de la categoría")
        #expect(String(format: newCategory, "Mascotas").contains("Mascotas"))
        for key in ["stats.distribution.insight.onsetNoMovements", "stats.trends.insight.onsetNoPrevious"] {
            let value = try #require(strings[key], "\(locale): falta \(key)")
            #expect(!value.contains("%"), "\(locale) \(key): no recibe nada")
        }
        for retired in [
            "stats.distribution.insight.newCategory %@ %@",
            "stats.distribution.insight.onset %@",
            "stats.trends.insight.onset %@",
        ] {
            #expect(strings[retired] == nil, "\(locale): \(retired) volvió")
        }
    }

    /// Las dos vistas ya no le pasan el nombre del período a esas frases.
    @Test func lasVistasNoPasanElPeriodo() throws {
        let categories = try Lote07Source.code("Yala/App/Views/Statistics/CategoriesTabView.swift")
        #expect(categories.contains("Insight.newCategoryInPeriod(name)"))
        #expect(categories.contains("Insight.onsetNoMovements"))
        let trends = try Lote07Source.code("Yala/App/Views/Statistics/TrendsTabView.swift")
        #expect(trends.contains("Insight.onsetNoPrevious"))
        #expect(!trends.contains("Insight.onset("))
    }
}

// MARK: - (2) Vacíos

@Suite("Lote 07 · (2) los vacíos dicen lo que falta y en el idioma de la persona")
struct StatisticsEmptyStatesTellTheTruthTests {

    /// Los idiomas que escribían «insights» en inglés (ja, nl, pl y zh ya usaban su palabra).
    static let localesThatSaidInsights = [
        "de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "pt", "pt-BR", "pt-PT",
    ]

    @Test(arguments: localesThatSaidInsights)
    func losVaciosNoDicenInsights(locale: String) throws {
        let strings = try Lote07Source.strings(locale)
        for key in ["insights.emptyBody", "insights.fewTransactions", "insights.offlineNoCache"] {
            let value = try #require(strings[key], "\(locale): falta \(key)")
            #expect(!value.lowercased().contains("insight"), "\(locale) \(key): «\(value)»")
        }
    }

    /// Las tildes ya llegaron a 2.3 con el lote de idiomas de 2.2: que no se pierdan.
    @Test(arguments: ["es", "es-419", "es-AR", "es-ES"])
    func sinConexionLlevaTildes(locale: String) throws {
        let strings = try Lote07Source.strings(locale)
        #expect(strings["insights.offlineCached"]?.contains("Sin conexión") == true)
        #expect(strings["insights.offlineNoCache"]?.contains("Sin conexión") == true)
    }

    /// Las tarjetas de Distribución no dicen «Aún no tienes categorías / subcategorías / etiquetas» cuando lo que falta
    /// son movimientos del período.
    @Test func distribucionNoNiegaQueHayCategorias() throws {
        let code = try Lote07Source.code("Yala/App/Views/Statistics/CategoriesTabView.swift")
        for retired in ["L10n.Empty.noCategories", "L10n.Empty.noSubcategories", "L10n.Empty.noTags"] {
            #expect(!code.contains(retired), "Distribución vuelve a usar \(retired)")
        }
        for accessor in ["emptyNoMovementsTitle", "emptyNoSubcategoryMovementsTitle", "emptyNoTagMovementsTitle"] {
            #expect(code.contains("L10n.Stats.Distribution.\(accessor)"))
        }
    }

    @Test(arguments: Lote07Source.locales)
    func losVaciosDeDistribucionExistenEnTodosLosIdiomas(locale: String) throws {
        let strings = try Lote07Source.strings(locale)
        for key in [
            "stats.distribution.empty.noMovementsTitle",
            "stats.distribution.empty.noSubcategoryMovementsTitle",
            "stats.distribution.empty.noTagMovementsTitle",
        ] {
            #expect(strings[key]?.isEmpty == false, "\(locale): falta \(key)")
        }
    }
}

// MARK: - (3) Guías

@Suite("Lote 07 · (3) las guías de Tendencias y Registros describen lo que se ve")
struct StatisticsGuidesMatchTheScreenTests {

    /// La métrica por defecto de Tendencias es el saldo, y la gráfica cambia a ingresos o gastos: la guía nombra las
    /// tres con el mismo nombre que el selector. Antes decía «si la línea sube, estás gastando más».
    @Test(arguments: Lote07Source.locales)
    func laGuiaDeTendenciasNombraLasTresMetricas(locale: String) throws {
        let strings = try Lote07Source.strings(locale)
        let message = try #require(strings["guide.trends.message"]).lowercased()
        for key in ["trendType.balance", "trendType.income", "trendType.expense"] {
            let metric = try #require(strings[key]).lowercased()
            #expect(message.contains(metric), "\(locale): la guía no nombra «\(metric)»")
        }
    }

    @Test func laMetricaPorDefectoEsElSaldo() throws {
        let code = try Lote07Source.code("Yala/App/Models/SessionState.swift")
        #expect(code.contains("var selectedTrendMetric: TrendMetric = .balance"))
    }

    /// La lista de Registros trae ingresos y gastos: la guía nombra los dos y su título no dice «gastos».
    @Test(arguments: Lote07Source.locales)
    func laGuiaDeRegistrosNombraIngresosYGastos(locale: String) throws {
        let strings = try Lote07Source.strings(locale)
        let message = try #require(strings["guide.records.message"]).lowercased()
        let title = try #require(strings["guide.records.title"]).lowercased()
        let income = try #require(strings["trendType.income"]).lowercased()
        let expense = try #require(strings["trendType.expense"]).lowercased()
        #expect(message.contains(income), "\(locale): la guía no nombra «\(income)»")
        #expect(message.contains(expense), "\(locale): la guía no nombra «\(expense)»")
        #expect(!title.contains(expense), "\(locale): el título sigue diciendo «\(expense)»")
    }
}

// MARK: - (4) Sankey

@Suite("Lote 07 · (4) el Sankey no pinta «$» con soles ni parte etiquetas en el borde")
struct SankeyCurrencyAndEdgeTests {

    @Test func elBotonDeMontosPintaLaDivisaDelSankey() {
        #expect(SankeyLabelModeToggle.amountSymbol(for: "PEN") == "S/")
        #expect(SankeyLabelModeToggle.amountSymbol(for: "EUR") == "€")
        #expect(SankeyLabelModeToggle.amountSymbol(for: "USD") == "$")
    }

    @Test func elBotonYaNoEsUnDolarFijo() throws {
        let toggle = try Lote07Source.code("Yala/App/Views/Statistics/Sankey/SankeyLabelModeToggle.swift")
        #expect(!toggle.contains("\"dollarsign\""))
        let categories = try Lote07Source.code("Yala/App/Views/Statistics/CategoriesTabView.swift")
        #expect(categories.contains("SankeyLabelModeToggle(mode: $prefs.sankeyLabelMode, currencyCode: defaultCurrencyCode)"))
    }

    @Test func alPrincipioSeFundeSoloElBordeDerecho() {
        let edges = SankeyEdgeFadeLogic.edges(offsetX: 0, contentWidth: 910, containerWidth: 338)
        #expect(edges == .init(leading: false, trailing: true))
    }

    @Test func aMitadSeFundenLosDos() {
        let edges = SankeyEdgeFadeLogic.edges(offsetX: 200, contentWidth: 910, containerWidth: 338)
        #expect(edges == .init(leading: true, trailing: true))
    }

    @Test func alFinalSeFundeSoloElIzquierdo() {
        let edges = SankeyEdgeFadeLogic.edges(offsetX: 572, contentWidth: 910, containerWidth: 338)
        #expect(edges == .init(leading: true, trailing: false))
    }

    @Test func siCabeEnteroNoSeFundeNada() {
        let edges = SankeyEdgeFadeLogic.edges(offsetX: 0, contentWidth: 910, containerWidth: 1000)
        #expect(edges == .none)
    }

    @Test func elSankeyAplicaElFundido() throws {
        let code = try Lote07Source.code("Yala/App/Views/Statistics/Sankey/SankeyChartView.swift")
        #expect(code.contains(".mask { edgeFadeMask }"))
        #expect(code.contains("SankeyEdgeFadeLogic.edges("))
    }
}

// MARK: - (5) Recuentos

@Suite("Lote 07 · (5) la cabecera y VoiceOver cuentan lo mismo, con separador de miles")
struct DistributionCountsAgreeTests {

    /// El caso que separaba las dos cuentas: una categoría de importe cero (la cabecera la contaba, la tarta no) y el
    /// trozo «Sin categoría» (la tarta lo contaba, la cabecera no).
    @Test func cuentaCategoriasRealesConImporte() {
        let items = [
            CategorySpendingSummary(category: Category(name: "Hogar", colorHex: "#888888", isIncome: false), amount: 2200, percentage: 50),
            CategorySpendingSummary(category: Category(name: "Comida", colorHex: "#888888", isIncome: false), amount: 900, percentage: 30),
            CategorySpendingSummary(category: Category(name: "Devuelta", colorHex: "#888888", isIncome: false), amount: 0, percentage: 0),
            CategorySpendingSummary(category: nil, amount: 300, percentage: 20),
        ]
        #expect(DistributionCountLogic.categoryCount(items) == 2)
    }

    @Test func cuentaSubcategoriasRealesConImporte() {
        let hogar = Category(name: "Hogar", colorHex: "#888888", isIncome: false)
        let alquiler = Subcategory(name: "Alquiler", category: hogar)
        let luz = Subcategory(name: "Luz", category: hogar)
        let items = [
            SubcategorySpendingSummary(subcategoryName: "Alquiler", colorHex: nil, amount: 1800, percentageOfTotal: 60,
                                       percentageOfCategory: 80, subcategory: alquiler, category: hogar),
            SubcategorySpendingSummary(subcategoryName: "Luz", colorHex: nil, amount: 0, percentageOfTotal: 0,
                                       percentageOfCategory: 0, subcategory: luz, category: hogar),
            // «Sin subcategoría» de Hogar: tiene categoría y no subcategoría.
            SubcategorySpendingSummary(subcategoryName: "Sin subcategoría", colorHex: nil, amount: 400,
                                       percentageOfTotal: 13, percentageOfCategory: 20, subcategory: nil,
                                       category: hogar),
            // «Sin categoría».
            SubcategorySpendingSummary(subcategoryName: "Sin categoría", colorHex: nil, amount: 300,
                                       percentageOfTotal: 10, percentageOfCategory: 100, subcategory: nil,
                                       category: nil),
        ]
        #expect(DistributionCountLogic.subcategoryCount(items) == 1)
    }

    /// La cabecera y las dos tartas leen el mismo recuento.
    @Test func cabeceraYTartasUsanElMismoRecuento() throws {
        let header = try Lote07Source.code("Yala/App/Views/Statistics/CategoriesTabView.swift")
        #expect(header.contains("DistributionCountLogic.categoryCount(categorySpending)"))
        #expect(header.contains("DistributionCountLogic.subcategoryCount(subcategorySpending)"))
        let pie = try Lote07Source.code("Yala/App/Views/Panel/CategoriesPieWidget.swift")
        #expect(pie.contains("categoriesCount(DistributionCountLogic.categoryCount(categories)"))
        let subPie = try Lote07Source.code("Yala/App/Views/Panel/SubcategoriesPieWidget.swift")
        #expect(subPie.contains("subcategoriesCount(DistributionCountLogic.subcategoryCount(subcategories)"))
    }

    /// «11696 registros» salía sin separador junto a importes que sí lo llevan. Ahora el número lleva el del formato
    /// de los importes (el locale del sistema).
    @Test func losRegistrosLlevanSeparadorDeMiles() throws {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let grouped = try #require(formatter.string(from: NSNumber(value: 11696)))
        #expect(grouped != "11696", "el locale del test no agrupa: el caso no discrimina")
        #expect(L10n.Stats.Insights.motivationalMany(11696).contains(grouped))
        #expect(L10n.Stats.Records.motivationalMany(11696).contains(grouped))
    }
}
