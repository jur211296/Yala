//
//  GraficasEstadisticasLote125Tests.swift
//  YalaTests
//
//  Cola 2.2 · lote 12.5 (gráficas, estadísticas y flujo de caja). Lógica pura y cableado; lo que necesita contexto de
//  SwiftData vive en su propio fichero (`.serialized` no ordena entre suites hermanas, `testing.md`).
//

import Foundation
import Testing
@testable import Yala

// MARK: - Distribución arranca en Detalle

@Suite("Distribución: Detalle primero")
struct DistributionContentModeOrderTests {

    /// El selector pinta los `case` en orden: Detalle a la izquierda, Gráficas a la derecha.
    @Test func detailIsTheFirstSegment() {
        #expect(DistributionContentMode.allCases == [.details, .charts])
    }

    /// El modo es `@State` sin persistir: cada visita arranca en su valor inicial, que es Detalle. Y el enlace de los widgets
    /// de subcategorías (que promete la gráfica) pasa a Gráficas antes de mover el carrusel.
    @Test func arrivesInDetail_andTheSubcategoriesLinkSwitchesToCharts() throws {
        let code = codeOnly(try source("Yala/App/Views/Statistics/CategoriesTabView.swift"))
        #expect(code.contains("@State private var contentMode: DistributionContentMode = .details"))
        let link = try #require(code.range(of: "private func showSubcategoriesFromLink() {"))
        let body = code[link.upperBound...].prefix(200)
        #expect(body.contains("contentMode = .charts"))
    }
}

// MARK: - Monto en «Ocultar»

@Suite("Filtro de monto: la moneda que queda a la vista")
struct RecordsAmountFilterCurrencyLogicTests {

    private let available: [CurrencyCode] = [.pen, .usd]

    /// El bug: en «Ocultar», con USD marcado, el monto filtraba en USD, la moneda que se oculta.
    @Test func exclude_withOneHidden_usesTheOtherOne() {
        #expect(RecordsAmountFilterCurrencyLogic.currency(selected: [.usd], available: available, isExcludeMode: true) == .pen)
        #expect(RecordsAmountFilterCurrencyLogic.currency(selected: [.pen], available: available, isExcludeMode: true) == .usd)
    }

    /// Con tres monedas y una oculta quedan dos a la vista: no hay una sola en la que comparar.
    @Test func exclude_leavingSeveral_orNone_hasNoAmountCurrency() {
        let three: [CurrencyCode] = [.pen, .usd, .eur]
        #expect(RecordsAmountFilterCurrencyLogic.currency(selected: [.usd], available: three, isExcludeMode: true) == nil)
        #expect(RecordsAmountFilterCurrencyLogic.currency(selected: [.pen, .usd], available: available, isExcludeMode: true) == nil)
        #expect(RecordsAmountFilterCurrencyLogic.currency(selected: [], available: available, isExcludeMode: true) == nil)
    }

    /// Sin nada oculto y una sola moneda en los registros, esa.
    @Test func exclude_nothingHidden_singleCurrency() {
        #expect(RecordsAmountFilterCurrencyLogic.currency(selected: [], available: [.pen], isExcludeMode: true) == .pen)
    }

    /// «Mostrar solo» sigue como estaba: la marcada, o la única que tienen los registros.
    @Test func include_keepsItsRule() {
        #expect(RecordsAmountFilterCurrencyLogic.currency(selected: [.usd], available: available, isExcludeMode: false) == .usd)
        #expect(RecordsAmountFilterCurrencyLogic.currency(selected: [], available: [.pen], isExcludeMode: false) == .pen)
        #expect(RecordsAmountFilterCurrencyLogic.currency(selected: [], available: available, isExcludeMode: false) == nil)
        #expect(RecordsAmountFilterCurrencyLogic.currency(selected: [.pen, .usd], available: available, isExcludeMode: false) == nil)
    }

    /// La hoja de filtros decide con esta regla y le pasa el modo; y en «Ocultar» la línea de ayuda es la suya.
    @Test func filtersSheet_usesTheRuleWithTheMode() throws {
        let code = codeOnly(try source("Yala/App/Views/Records/RecordsFiltersView.swift"))
        #expect(code.contains("RecordsAmountFilterCurrencyLogic.currency("))
        #expect(code.contains("isExcludeMode: localIsExcludeMode"))
        #expect(code.contains("? L10n.UXL8C.Filters.amountNeedsOneVisibleCurrency"))
        #expect(!code.contains("if localSelectedCurrencies.count == 1 { return localSelectedCurrencies.first }"))
    }
}

// MARK: - Frase de IA del flujo de caja

@Suite("Flujo de caja: la frase de IA exige Pro")
struct CashFlowAICommentGateTests {

    @Test func needsTheThreeConditions() {
        #expect(CashFlowAICommentGate.isEnabled(toggleOn: true, consentAccepted: true, isPro: true))
        // Encendida siendo Pro, y la suscripción terminó: ya no se pide.
        #expect(!CashFlowAICommentGate.isEnabled(toggleOn: true, consentAccepted: true, isPro: false))
        #expect(!CashFlowAICommentGate.isEnabled(toggleOn: true, consentAccepted: false, isPro: true))
        #expect(!CashFlowAICommentGate.isEnabled(toggleOn: false, consentAccepted: true, isPro: true))
    }

    /// La hoja de gráficas pide las frases con esa condición (la `.task(id:)` y las tarjetas leen `isAIEnabled`).
    @Test func chartsSheet_passesThePlan() throws {
        let code = codeOnly(try source("Yala/App/Views/Reports/CashFlow/CashFlowChartsSheet.swift"))
        let gate = try #require(code.range(of: "private var isAIEnabled: Bool {"))
        let body = code[gate.upperBound...].prefix(260)
        #expect(body.contains("CashFlowAICommentGate.isEnabled("))
        #expect(body.contains("isPro: isPro"))
        #expect(code.contains(".task(id: isAIEnabled) {"))
    }
}

// MARK: - Tendencias se entera de una edición en sitio

@Suite("Tendencias cuelga de la generación de datos del contenedor")
struct TrendsDataGenerationWiringTests {

    /// `.count` no ve una edición del importe (mismas filas); `dataGeneration` sí
    /// (`DetailContainerDataGenerationTests.amountEdit_advancesGeneration_withTheSameRows`).
    @Test func trends_observesDataGeneration_notTheCount() throws {
        let code = codeOnly(try source("Yala/App/Views/Statistics/TrendsTabView.swift"))
        #expect(code.contains("let dataGeneration: Int"))
        #expect(code.contains(".onChange(of: dataGeneration)"))
        #expect(!code.contains(".onChange(of: allTransactions.count)"))
        let observer = try #require(code.range(of: ".onChange(of: dataGeneration)"))
        #expect(code[observer.upperBound...].prefix(120).contains("scheduleTrendsRecalc("))
    }

    @Test func container_passesTheGenerationToTrends() throws {
        let code = codeOnly(try source("Yala/App/Views/Statistics/DetailContainerView.swift"))
        let trends = try #require(code.range(of: "TrendsTabView("))
        #expect(code[trends.upperBound...].prefix(400).contains("dataGeneration: dataViewModel.dataGeneration"))
    }
}

// MARK: - Modo duplicados sin «Fecha»

@Suite("Modo duplicados: la fecha de cada fila")
struct DuplicatesRowDateCaptionTests {

    private let criteriaWithoutDate = RecordsDuplicateLogic.Criteria(amount: true, note: false, subcategory: true, date: false)
    private let criteriaWithDate = RecordsDuplicateLogic.Criteria(amount: true, note: true, subcategory: true, date: true)
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ d: Int, hour: Int = 0) throws -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = d; c.hour = hour
        return try #require(calendar.date(from: c))
    }

    /// Sin «Fecha» y con el grupo en días distintos, cada fila dice el suyo, con año.
    @Test func withoutDate_groupAcrossDays_eachRowSaysItsDay() throws {
        let es = Locale(identifier: "es_PE")
        let dates = [try day(14), try day(20)]
        let caption = RecordsDuplicateLogic.rowDateCaption(
            for: dates[0], groupDates: dates, criteria: criteriaWithoutDate, calendar: calendar, locale: es)
        #expect(caption == ScheduledPaymentDateText.medium(dates[0], locale: es))
        #expect(caption?.contains("2026") == true)
        #expect(caption?.contains("14") == true)
    }

    /// Todo el grupo del mismo día: la cabecera ya lo dice y la fila no lo repite.
    @Test func withoutDate_groupOnTheSameDay_noCaption() throws {
        let dates = [try day(14, hour: 9), try day(14, hour: 20)]
        #expect(RecordsDuplicateLogic.rowDateCaption(
            for: dates[0], groupDates: dates, criteria: criteriaWithoutDate, calendar: calendar) == nil)
    }

    /// Con «Fecha» todos los del grupo son del mismo día: la fila no la repite.
    @Test func withDate_noCaption() throws {
        let dates = [try day(14), try day(20)]
        #expect(RecordsDuplicateLogic.rowDateCaption(
            for: dates[0], groupDates: dates, criteria: criteriaWithDate, calendar: calendar) == nil)
    }

    /// Las filas del modo la reciben con las fechas de su grupo; las de la lista normal no (su fecha va en la cabecera del
    /// día).
    @Test func duplicatesList_passesIt() throws {
        let code = codeOnly(try source("Yala/App/Views/Statistics/RecordsTabView.swift"))
        #expect(code.components(separatedBy: "RecordsDuplicateLogic.rowDateCaption(").count == 2)
        let duplicates = try #require(code.range(of: "private var duplicateGroupsContent: some View {"))
        let call = try #require(code.range(of: "RecordsDuplicateLogic.rowDateCaption(", range: duplicates.upperBound..<code.endIndex))
        #expect(code[call.upperBound...].prefix(160).contains("groupDates: group.map(\\.date)"))
    }
}

// MARK: - La semilla avisa al conversor de las tasas que escribe

@Suite("La semilla avisa al conversor de las tasas que escribe")
struct DevSeedNotifiesExchangeRatesTests {

    /// Sin el aviso, el saldo de hoy se convertía con la tabla estática que el conversor resolvió antes de sembrar
    /// (ficha `ficha-mx-vida`: 17,2 en vez de 18,30), y la curva caía el último día.
    @Test func seedPostsTheRatesNotification_beforeRefreshingTheScreens() throws {
        let raw = try source("Yala/Seed/DevSeedService.swift")
        let code = codeOnly(raw)
        let marked = try #require(raw.range(of: "// Mark as executed"))
        let tail = raw[marked.lowerBound...]
        let post = try #require(tail.range(of: "NotificationCenter.default.post(name: .yalaExchangeRatesUpdated, object: nil)"))
        let refresh = try #require(tail.range(of: "SessionState.shared.incrementDataVersion()"))
        #expect(post.lowerBound < refresh.lowerBound)
        // Y el camino corto que también escribe tasas (cuenta con movimientos, tarjeta con dos líneas…).
        #expect(code.components(separatedBy: "NotificationCenter.default.post(name: .yalaExchangeRatesUpdated, object: nil)").count == 3)
    }
}

// MARK: - Helpers

private func source(_ relative: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
}

private func codeOnly(_ code: String) -> String {
    code.split(separator: "\n").map { line -> Substring in
        if let range = line.range(of: "//") { return line[..<range.lowerBound] }
        return line
    }.joined(separator: "\n")
}
