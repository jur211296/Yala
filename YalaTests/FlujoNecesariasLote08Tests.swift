//
//  FlujoNecesariasLote08Tests.swift
//  YalaTests
//
//  Lote 08 de mejoras necesarias 2.3 (Flujo de caja). Un bloque por punto:
//  (1) «Gastos no considerados» lee el mes elegido en la tira, no siempre el mes en curso;
//  (2) el detalle de una línea no pega «vs» a mano: dice una frase traducida en los 16 idiomas;
//  (3) el vacío de Flujo de caja no habla de un período (el flujo de caja no tiene);
//  (4) «Te quedó» / «Te faltó» y su variación pintan el importe con tokens de texto que pasan AA, no índigo ni rosa.
//
//  Los textos se leen de los `Localizable.strings` FUENTE de los 16 idiomas (vía `#filePath`), como
//  `StatisticsNecesariasLote07Tests`: el idioma del simulador no decide qué se comprueba.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Fuente

private enum Lote08Source {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let locales = [
        "de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl", "pt", "pt-BR", "pt-PT",
        "zh-Hans",
    ]

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

    /// El tramo de `code` que va de `start` hasta el siguiente `end` (excluido).
    static func slice(_ code: String, from start: String, to end: String) throws -> String {
        let lower = try #require(code.range(of: start), "No está «\(start)»")
        let rest = code[lower.upperBound...]
        let upper = rest.range(of: end)?.lowerBound ?? rest.endIndex
        return String(rest[..<upper])
    }
}

// MARK: - (1) La hoja lee el mes elegido

@Suite("Lote 08 · (1) «Gastos no considerados» enseña el mes desde el que se abre")
@MainActor
struct CashFlowOthersSheetMonthTests {

    private func other(_ amount: Double, _ name: String) -> CashFlowOtherResult {
        CashFlowOtherResult(
            plannedAmount: amount, realAmount: amount,
            categoryBreakdown: [OtherCategoryItem(categoryName: name, iconName: "folder", colorHex: "#000000", amount: amount)]
        )
    }

    private func month(_ key: String, isPast: Bool, isCurrent: Bool, expenses: CashFlowOtherResult?,
                       income: CashFlowOtherResult?) -> CashFlowMonth {
        CashFlowMonth(
            monthKey: key, date: Date(timeIntervalSince1970: 0), isPast: isPast, isCurrent: isCurrent,
            incomeLines: [], expenseLines: [], otherExpenses: expenses, otherIncome: income,
            totalIncome: 0, totalExpense: 0, netFlow: 0, accumulatedBalance: nil
        )
    }

    private var months: [CashFlowMonth] {
        [
            month("2026-09", isPast: true, isCurrent: false, expenses: other(300, "Viajes"), income: other(50, "Regalos")),
            month("2026-10", isPast: true, isCurrent: false, expenses: nil, income: nil),
            month("2026-11", isPast: false, isCurrent: true, expenses: other(120, "Cafés"), income: other(10, "Ventas")),
        ]
    }

    @Test func abiertaDesdeUnMesPasado_enseñaEseMes() {
        let expenses = CashFlowOthersSheet.otherResult(in: months, selectedMonthKey: "2026-09", isIncome: false)
        #expect(expenses?.categoryBreakdown.first?.categoryName == "Viajes")
        let income = CashFlowOthersSheet.otherResult(in: months, selectedMonthKey: "2026-09", isIncome: true)
        #expect(income?.categoryBreakdown.first?.categoryName == "Regalos")
    }

    /// Un mes elegido sin «no considerados» no cae al mes en curso: esa era la forma del bug.
    @Test func unMesElegidoSinNoConsiderados_noEnseñaElMesEnCurso() {
        #expect(CashFlowOthersSheet.otherResult(in: months, selectedMonthKey: "2026-10", isIncome: false) == nil)
        #expect(CashFlowOthersSheet.otherResult(in: months, selectedMonthKey: "2026-10", isIncome: true) == nil)
    }

    @Test func conElMesEnCurso_enseñaElMesEnCurso() {
        let expenses = CashFlowOthersSheet.otherResult(in: months, selectedMonthKey: "2026-11", isIncome: false)
        #expect(expenses?.categoryBreakdown.first?.categoryName == "Cafés")
    }

    /// Si la clave elegida ya no está en la proyección (cambió el horizonte), la hoja enseña el mes en curso.
    @Test func conUnaClaveQueNoEstá_caeAlMesEnCurso() {
        let expenses = CashFlowOthersSheet.otherResult(in: months, selectedMonthKey: "2025-01", isIncome: false)
        #expect(expenses?.categoryBreakdown.first?.categoryName == "Cafés")
    }

    /// La hoja lee la clave de la tira (`selectedMonthKey`), no busca `isCurrent` por su cuenta.
    @Test func laHojaLeeLaClaveDeLaTira() throws {
        let code = try Lote08Source.code("Yala/App/Views/Reports/CashFlow/CashFlowOthersSheet.swift")
        let accessor = try Lote08Source.slice(code, from: "private var otherResult", to: "static func otherResult")
        #expect(accessor.contains("viewModel.selectedMonthKey"))
        #expect(!accessor.contains("isCurrent"))
    }
}

// MARK: - (2) El detalle de una línea no dice «vs»

@Suite("Lote 08 · (2) el detalle de una línea dice una frase traducida, sin «vs»")
struct CashFlowCellDetailVsTests {

    static let keys = ["cashFlowPlan.cellDetailSpentVsPlan", "cashFlowPlan.cellDetailEarnedVsPlan"]

    @Test(arguments: Lote08Source.locales)
    func laFraseEstáEnCadaIdioma_conSusDosCifras_ySinVs(locale: String) throws {
        let strings = try Lote08Source.strings(locale)
        for key in Self.keys {
            let value = try #require(strings[key], "\(locale): falta \(key)")
            #expect(value.contains("%1$@") && value.contains("%2$@"), "\(locale) · \(key): «\(value)»")
            #expect(!value.lowercased().contains(" vs"), "\(locale) · \(key): «\(value)»")
        }
    }

    @Test func elDetalleNoPegaVsAMano() throws {
        let code = try Lote08Source.code("Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift")
        #expect(!code.contains(") vs \\("), "El detalle sigue pegando «vs» entre dos cifras.")
        #expect(code.contains("cellDetailSpentVsPlan"))
        #expect(code.contains("cellDetailEarnedVsPlan"))
    }
}

// MARK: - (3) El vacío de Flujo de caja no habla de un período

@Suite("Lote 08 · (3) el vacío de Flujo de caja no habla de un período")
struct CashFlowEmptyStateCopyTests {

    /// La palabra «período» en cada idioma, tal como la usa hoy `report.noDataDescription`.
    static let periodWords = [
        "período", "periodo", "period", "zeitraum", "période", "periode", "okres", "期間", "时间段",
    ]

    @Test(arguments: Lote08Source.locales)
    func elVacíoDeFlujoDeCaja_noDicePeríodo(locale: String) throws {
        let strings = try Lote08Source.strings(locale)
        let value = try #require(strings["report.cashFlowNoDataDescription"], "\(locale): falta el vacío de Flujo de caja")
        let lower = value.lowercased()
        for word in Self.periodWords {
            #expect(!lower.contains(word), "\(locale): «\(value)» habla de un período")
        }
    }

    @Test func flujoDeCajaUsaSuVacío_yLaComparativaElDeSiempre() throws {
        let code = try Lote08Source.code("Yala/App/Views/Reports/FinancialReportView.swift")
        let cashFlow = try Lote08Source.slice(code, from: "private var cashFlowContent", to: "} else if")
        #expect(cashFlow.contains("cashFlowNoDataDescription"))
        let comparativa = try Lote08Source.slice(code, from: "private var comparativaContent", to: ".yalaSafeBottomPadding()")
        #expect(!comparativa.contains("cashFlowNoDataDescription"))
    }
}

// MARK: - (4) «Te quedó» con tokens de texto AA

@Suite("Lote 08 · (4) «Te quedó» y su variación pintan con tokens de texto AA")
struct NetFlowSummaryContrastTests {

    @Test func elResumenNoPintaTextoEnÍndigoNiRosa() throws {
        let code = try Lote08Source.code("Yala/App/Views/Reports/NetFlowSummaryView.swift")
        #expect(!code.contains("electricIndigo"))
        #expect(!code.contains("hotPink"))
        #expect(code.contains("Color.incomeAmount"))
        #expect(code.contains("Color.groupOweAmount"))
        #expect(code.contains("usesAccessibleTextTone: true"), "La variación del resumen no pide el tono de texto AA.")
    }

    /// El modo AA del chip usa los mismos dos tokens, y el resto de la app sigue con la paleta (no se pidió cambiarlo).
    @Test func elChipEnModoAA_usaLosTokensDeTexto() throws {
        let code = try Lote08Source.code("Yala/App/Views/Shared/VariationChip.swift")
        let accessible = try Lote08Source.slice(code, from: "if usesAccessibleTextTone", to: "if isExpenseContext")
        #expect(accessible.contains(".incomeAmount"))
        #expect(accessible.contains(".groupOweAmount"))
        #expect(code.contains("var usesAccessibleTextTone: Bool = false"))
    }
}

// MARK: - Decisión 2 (9-nov): el flujo de caja avanzado es gratis a propósito

@Suite("Lote 08 · decisión 2: el flujo de caja avanzado no tiene candado Pro")
struct CashFlowAdvancedIsFreeTests {

    static let removedKeys = [
        "featureGate.cashFlowAdvanced", "uxpro.gate.title.cashFlow", "uxpro.gate.body.cashFlowStays",
        "uxpro.welcome.cashFlow",
    ]

    /// El bloqueo no actuaba (`isProOnly` nunca lo incluyó): se retira entero, no se deja como opción de Pro.
    @Test func noHayFunciónProDeFlujoDeCaja() {
        #expect(!ProFeature.allCases.map(\.rawValue).contains("cashFlowAdvanced"))
    }

    /// «El flujo de caja avanzado es de Yala Pro» y «Ya puedes usar el flujo de caja avanzado.» ya no existen.
    @Test(arguments: Lote08Source.locales)
    func susTextosDeProSeFueron(locale: String) throws {
        let strings = try Lote08Source.strings(locale)
        for key in Self.removedKeys {
            #expect(strings[key] == nil, "\(locale): sigue \(key)")
        }
    }

    /// El horizonte (meses atrás y adelante) sale del plan, sin pasar por el servicio de Pro.
    @Test func elHorizonteNoPreguntaPorPro() throws {
        let code = try Lote08Source.code("Yala/App/ViewModels/CashFlowPlanViewModel.swift")
        let recalc = try Lote08Source.slice(code, from: "func recalculate(", to: "func updateHorizon(")
        #expect(recalc.contains("let monthsAhead = plan.defaultMonthsAhead"))
        #expect(recalc.contains("let monthsBack = plan.defaultMonthsBack"))
        #expect(!recalc.contains("FeatureGateService"))
    }
}

// MARK: - Decisión 35 (9-nov): la frase de Gráficas dice que es un promedio y de cuántos meses

@Suite("Lote 08 · decisión 35: «Gastos por revisar» dice el período del promedio")
@MainActor
struct CashFlowDeviationCommentPeriodTests {

    static let averageKeys = ["cashFlowPlan.deviationAverageSingle", "cashFlowPlan.deviationAverageMultiple"]

    @Test func conVariosMeses_laFraseDiceCuántos() {
        let amount = YalaFormatterStatic.currency(value: 25, currencyCode: "PEN")
        let single = CashFlowPlanViewModel.generateDeviationRuleComment(
            [(name: "Bares", amount: 25)], monthCount: 4, currencyCode: "PEN")
        #expect(single == L10n.CashFlowPlan.deviationAverageSingle(4, "Bares", amount))
        #expect(single.contains("4"), "La frase no dice de cuántos meses es el promedio: «\(single)»")

        let total = YalaFormatterStatic.currency(value: 35, currencyCode: "PEN")
        let ten = YalaFormatterStatic.currency(value: 10, currencyCode: "PEN")
        let multiple = CashFlowPlanViewModel.generateDeviationRuleComment(
            [(name: "Bares", amount: 25), (name: "Taxis", amount: 10)], monthCount: 3, currencyCode: "PEN")
        #expect(multiple == L10n.CashFlowPlan.deviationAverageMultiple(3, "Bares", amount, total))
        #expect(!multiple.contains(ten), "La frase de varias líneas da el total, no la segunda línea.")
    }

    /// Con un solo mes (el actual) no hay promedio: la frase dice «Este mes».
    @Test func conUnSoloMes_noHablaDePromedio() {
        let amount = YalaFormatterStatic.currency(value: 25, currencyCode: "PEN")
        let single = CashFlowPlanViewModel.generateDeviationRuleComment(
            [(name: "Bares", amount: 25)], monthCount: 1, currencyCode: "PEN")
        #expect(single == L10n.CashFlowPlan.deviationThisMonthSingle("Bares", amount))
    }

    @Test(arguments: Lote08Source.locales)
    func laFraseDelPromedioLlevaElNúmeroDeMeses(locale: String) throws {
        let strings = try Lote08Source.strings(locale)
        for key in Self.averageKeys {
            let value = try #require(strings[key], "\(locale): falta \(key)")
            #expect(value.contains("%1$d"), "\(locale) · \(key): «\(value)»")
        }
        #expect(strings["cashFlowPlan.deviationCommentSingle"] == nil, "\(locale): sigue la frase sin período")
        #expect(strings["cashFlowPlan.deviationCommentMultiple"] == nil, "\(locale): sigue la frase sin período")
    }

    @Test func gráficasPasaLosMesesDeLaGráfica() throws {
        let code = try Lote08Source.code("Yala/App/Views/Reports/CashFlow/CashFlowChartsSheet.swift")
        #expect(code.contains("monthCount: cachedPastMonths.count"))
    }
}
