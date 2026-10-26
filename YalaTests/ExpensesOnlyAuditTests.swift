//
//  ExpensesOnlyAuditTests.swift
//  YalaTests
//
//  Auditoría del modo «Solo gastos» (2026-10-26, card 1qfi, decisiones A de Jürgen): qué cifra rotula el hero de
//  Estadísticas, qué cuenta como filtro del usuario, cómo se llama la agrupación de la Comparativa, y el cableado de
//  las pantallas que lo pintan (source-scan: son vistas).
//

import Foundation
import Testing

@testable import Yala

@Suite("Solo gastos · lógica")
struct ExpensesOnlyAuditLogicTests {

    @Test("Resumen y Registros rotulan el gasto en «Solo gastos» y su neto de siempre fuera")
    func captionsFollowTheMode() {
        #expect(StatsHeroCaptionLogic.insights(expensesOnly: true) == .expensePeriod)
        #expect(StatsHeroCaptionLogic.insights(expensesOnly: false) == .netPeriod)
        #expect(StatsHeroCaptionLogic.records(natures: [.expense], expensesOnly: true) == .expensePeriod)
        // Fuera del modo manda el filtro de naturaleza, como antes.
        #expect(StatsHeroCaptionLogic.records(natures: [], expensesOnly: false) == .netPeriod)
        #expect(StatsHeroCaptionLogic.records(natures: [.income], expensesOnly: false) == .incomePeriod)
    }

    @Test("La naturaleza que fija «Solo gastos» no es un filtro del usuario")
    func forcedNatureIsNotAUserFilter() {
        // Solo la naturaleza forzada: cero filtros (antes, 1 → «Filtros aplicados» vacío y el punto encendido).
        #expect(FilterControlBarLogic.userFilterCount(
            activeFilterCount: 1, isExpensesOnlyMode: true, natures: [.expense]) == 0)
        // Con una cuenta además, queda esa.
        #expect(FilterControlBarLogic.userFilterCount(
            activeFilterCount: 2, isExpensesOnlyMode: true, natures: [.expense]) == 1)
        // Fuera del modo, el chip de gasto SÍ lo puso el usuario.
        #expect(FilterControlBarLogic.userFilterCount(
            activeFilterCount: 1, isExpensesOnlyMode: false, natures: [.expense]) == 1)
        // Nunca negativo.
        #expect(FilterControlBarLogic.userFilterCount(
            activeFilterCount: 0, isExpensesOnlyMode: true, natures: [.expense]) == 0)
    }

    @Test("El punto de filtros del Panel sigue la misma regla")
    func panelBadgeUsesTheSameRule() {
        #expect(!PanelSessionFilters.hasUserFilters(activeFilterCount: 1, isExpensesOnlyMode: true, natures: [.expense]))
        #expect(PanelSessionFilters.hasUserFilters(activeFilterCount: 1, isExpensesOnlyMode: false, natures: [.expense]))
    }

    @Test("La agrupación de tipo se llama «Gastos» en «Solo gastos»")
    func comparisonGroupingName() {
        #expect(ReportGroupingDimension.tipo.displayName(expensesOnly: true) == L10n.Report.expense)
        #expect(ReportGroupingDimension.tipo.displayName(expensesOnly: false) == L10n.Report.Grouping.type)
        // Las demás no cambian.
        #expect(ReportGroupingDimension.categoria.displayName(expensesOnly: true) == L10n.Report.Grouping.category)
    }
}

@Suite("Solo gastos · cableado (source-scan)")
struct ExpensesOnlyAuditWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("Resumen y Registros enseñan la cifra también en «Solo gastos», y es el gasto")
    func insightsAndRecordsShowTheSpentFigure() throws {
        let insights = try Self.source("Yala/App/Views/Statistics/InsightsTabView.swift")
        #expect(!insights.contains("!sessionState.isExpensesOnlyMode && hasRecords"),
                "Resumen vuelve a esconder la cifra en «Solo gastos».")
        #expect(insights.contains("value: expensesOnly ? summary.totalExpense : summary.netBalance"))
        #expect(insights.contains("ExpensesOnlyHeroVariation(variation: summary.expenseVariation)"))

        let records = try Self.source("Yala/App/Views/Statistics/RecordsTabView.swift")
        #expect(!records.contains("!sessionState.isExpensesOnlyMode && hasRecords"),
                "Registros vuelve a esconder la cifra en «Solo gastos».")
        #expect(records.contains("value: expensesOnly ? recordsSummary.expense : recordsSummary.balance"))
    }

    @Test("Tendencias no pinta la frase del balance en «Solo gastos» y lleva la variación del gasto")
    func trendsDropsTheBalanceLine() throws {
        let trends = try Self.source("Yala/App/Views/Statistics/TrendsTabView.swift")
        #expect(trends.contains("if !sessionState.isExpensesOnlyMode, let summary, let text = heroVariationSubtitle(for: summary)"),
                "La frase del balance volvió a «Solo gastos»: gastar más se lee «por debajo · Ánimo».")
        #expect(trends.contains("ExpensesOnlyHeroVariation(variation: summary.expenseVariation)"))
    }

    @Test("Distribución lleva la variación del gasto en «Solo gastos»")
    func distributionShowsTheVariation() throws {
        let src = try Self.source("Yala/App/Views/Statistics/CategoriesTabView.swift")
        #expect(src.contains("PreviousPeriodHelper.calculateVariation(currentAmount: totalAmount, previousAmount: $0)"))
    }

    /// `YalaWidgets` no lo compila esta suite: la única red es leer su fuente.
    @Test("El widget de flujo dice «Gastado» y enseña el gasto en positivo en «Solo gastos»")
    func cashFlowWidgetSaysSpent() throws {
        let src = try Self.source("YalaWidgets/Widgets/CashFlowWidget.swift")
        #expect(src.contains("netCashFlow: isExpensesOnly ? (summary?.totalExpense ?? 0) : (summary?.netCashFlow ?? 0)"),
                "El widget vuelve a enseñar el gasto en negativo como «flujo».")
        #expect(src.contains("isExpensesOnly: isExpensesOnly"), "El proveedor no le dice a la entrada el modo.")
        #expect(src.contains("? String(localized: \"widget.ui.spent\", bundle: .main)"))
        // Los tres tamaños pasan por el rótulo que sigue al modo.
        #expect(src.components(separatedBy: "entry.kpiTitle(fallbackKey:").count - 1 == 3)
    }

    @Test("Los cinco sitios que pintan filtros cuentan sin la naturaleza forzada")
    func filterSurfacesUseTheUserCount() throws {
        let paths = [
            "Yala/App/Views/Filters/FilterControlBar.swift",
            "Yala/App/Views/Statistics/DetailContainerView.swift",
            "Yala/App/Views/Records/Components/RecordsOverflowMenu.swift",
            "Yala/App/Views/Reports/FinancialReportView.swift",
        ]
        for path in paths {
            let src = try Self.source(path)
            #expect(src.contains("userFilterCount(isExpensesOnlyMode:"), "\(path) cuenta la naturaleza forzada como filtro.")
        }
        let panel = try Self.source("Yala/App/Views/Panel/Components/PanelFilterControlBar.swift")
        #expect(panel.contains("&& !sessionState.isExpensesOnlyMode"),
                "El Panel vuelve a enseñar la píldora «Gasto» en «Solo gastos».")
    }
}
