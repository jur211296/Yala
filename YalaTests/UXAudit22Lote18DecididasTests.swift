//
//  UXAudit22Lote18DecididasTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 18 decidido (Reportes): la lógica pura detrás de las pantallas.
//  - L18-3: los nombres de los períodos de la tabla de la Comparativa (mes entero por su nombre, tramo de días por sus
//    días, el tramo que de verdad entra).
//  - L18-4: el desglose sin el nivel fijo a la vista, y VoiceOver sin «Aumento» cuando no cambia.
//  - L18-5: qué gasto «se repite» y va a la vista al crear el plan.
//  - L18-11: las frases del resumen del mes.
//

import Foundation
import Testing

@testable import Yala

struct UXAudit22Lote18DecididasTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h)) ?? .now
    }

    private let es = Locale(identifier: "es_PE")

    // MARK: - L18-3 · nombres de los períodos

    @Test func currentName_ofThisMonth_isTheMonthCapitalized() {
        let name = ComparativeLabelsLogic.currentName(
            period: .thisMonth, customRange: nil, now: date(2026, 10, 21), calendar: calendar, locale: es
        )
        #expect(name.column == "Octubre")
        #expect(name.inSentence == "octubre")
        #expect(!name.isDayRange)
    }

    @Test func comparedName_withLastMonthWhole_isTheMonth() {
        // «Mes pasado» compara con el mes anterior entero: setiembre.
        let name = ComparativeLabelsLogic.comparedName(
            period: .lastMonth, mode: .month, customRange: nil, dataEnd: nil,
            now: date(2026, 10, 21), calendar: calendar, locale: es
        )
        #expect(name?.column == "Agosto")
        #expect(name?.isDayRange == false)
    }

    @Test func comparedName_ofThisMonthHalfway_isTheDaysThatReallyCount() throws {
        // «Este mes» a día 21 se compara con el 1–21 del mes anterior: la cabecera no puede decir «septiembre» entero.
        let name = try #require(ComparativeLabelsLogic.comparedName(
            period: .thisMonth, mode: .month, customRange: nil, dataEnd: date(2026, 10, 21),
            now: date(2026, 10, 21), calendar: calendar, locale: es
        ))
        #expect(name.isDayRange)
        #expect(name.column.contains("21"))
        let heading = ComparativeLabelsLogic.heading(
            current: ComparativeLabelsLogic.currentName(period: .thisMonth, customRange: nil,
                                                        now: date(2026, 10, 21), calendar: calendar, locale: es),
            compared: name
        )
        #expect(heading.hasPrefix("Octubre"))
    }

    @Test func comparedName_ofAllTime_isNil() {
        #expect(ComparativeLabelsLogic.comparedName(
            period: .allTime, mode: .month, customRange: nil, dataEnd: nil,
            now: date(2026, 10, 21), calendar: calendar, locale: es
        ) == nil)
    }

    @Test func yearAgoChip_namesTheMonthWithItsYear() {
        let text = ComparativeLabelsLogic.yearAgoChipName(
            period: .thisMonth, customRange: nil, now: date(2026, 10, 21), calendar: calendar, locale: es
        )
        #expect(text.contains("2025"))
        #expect(text.lowercased().contains("octubre"))
    }

    @Test func previousChipTitle_dependsOnThePeriod() {
        #expect(ComparativeLabelsLogic.previousChipTitle(for: .thisMonth) == L10n.UXL18.chipPreviousMonth)
        #expect(ComparativeLabelsLogic.previousChipTitle(for: .thisWeek) == L10n.UXL18.chipPreviousWeek)
        #expect(ComparativeLabelsLogic.previousChipTitle(for: .last30Days) == L10n.UXL18.chipPrevious30Days)
    }

    // MARK: - L18-4 · desglose

    @Test func grouping_optionalDimensions_hideTheMandatoryOne_andReorderKeepsItFirst() {
        var state = ReportGroupingState()
        state.toggle(.categoria)
        state.toggle(.subcategoria)
        #expect(state.optionalDimensions == [.categoria, .subcategoria])

        state.moveOptional(from: IndexSet(integer: 1), to: 0)

        #expect(state.activeDimensions == [.tipo, .subcategoria, .categoria], "«Ingresos y gastos» sigue delante")
    }

    @Test func grouping_example_followsTheChosenOrder() {
        var state = ReportGroupingState()
        state.toggle(.categoria)
        state.toggle(.subcategoria)
        let example = state.activeDimensions.map(\.exampleValue).joined(separator: " › ")
        #expect(example == [L10n.UXL18.exampleIncomeAndExpenses, L10n.UXL18.exampleCategory,
                            L10n.UXL18.exampleSubcategory].joined(separator: " › "))
    }

    @Test func variationAccessibility_saysNoChange_whenItRoundsToZero() {
        #expect(VariationChip.accessibilityText(for: 0) == L10n.Accessibility.variationNoChange)
        #expect(VariationChip.accessibilityText(for: 0.04) == L10n.Accessibility.variationNoChange)
        #expect(VariationChip.accessibilityText(for: -0.04) == L10n.Accessibility.variationNoChange)
        #expect(VariationChip.accessibilityText(for: 12) != L10n.Accessibility.variationNoChange, "control")
    }

    // MARK: - L18-5 · lo que se repite

    @Test func recurring_needsFiveActiveMonthsWithSimilarAmounts() {
        #expect(CashFlowSetupLogic.isRecurring(monthlyTotals: [2200, 2200, 2200, 2200, 2200, 2200]))
        #expect(CashFlowSetupLogic.isRecurring(monthlyTotals: [0, 150, 160, 140, 150, 155]), "5 de 6 bastan")
        #expect(!CashFlowSetupLogic.isRecurring(monthlyTotals: [0, 0, 150, 160, 140, 150]), "4 meses no")
        #expect(!CashFlowSetupLogic.isRecurring(monthlyTotals: [100, 400, 50, 300, 90, 600]), "montos que cambian")
        #expect(!CashFlowSetupLogic.isRecurring(monthlyTotals: []))
    }

    @Test func variableExamples_takeTheFirstThreeNames() {
        #expect(CashFlowSetupLogic.variableExamples(["Restaurantes", "Taxis", "Compras", "Cine"]) == "Restaurantes, Taxis, Compras")
    }

    // MARK: - L18-11 · el resumen del mes

    private func month(net: Double, isPast: Bool = false, isCurrent: Bool = false, expenses: [CashFlowLineResult] = []) -> CashFlowMonth {
        CashFlowMonth(
            monthKey: "2026-11", date: date(2026, 11, 1), isPast: isPast, isCurrent: isCurrent,
            incomeLines: [], expenseLines: expenses, otherExpenses: nil, otherIncome: nil,
            totalIncome: max(net, 0), totalExpense: max(-net, 0), netFlow: net, accumulatedBalance: nil
        )
    }

    private func expense(planned: Double, real: Double?) -> CashFlowLineResult {
        CashFlowLineResult(
            lineID: UUID(), name: "x", isIncome: false, plannedAmount: planned, realAmount: real,
            difference: nil, differencePercent: nil, progress: nil, isOverride: false,
            estimationMethod: .average6m, subcategoryBreakdown: nil
        )
    }

    @Test func heroLabel_saysSurplusOrShortfall_inTheRightTense() {
        #expect(CashFlowMonthSummaryLogic.heroLabel(for: month(net: 10, isCurrent: true)) == L10n.UXL18.surplusThisMonth)
        #expect(CashFlowMonthSummaryLogic.heroLabel(for: month(net: -10, isCurrent: true)) == L10n.UXL18.shortfallThisMonth)
        let name = CashFlowMonthSummaryLogic.monthInSentence(date(2026, 11, 1))
        #expect(CashFlowMonthSummaryLogic.heroLabel(for: month(net: 10)) == L10n.UXL18.surplusFuture(name))
        #expect(CashFlowMonthSummaryLogic.heroLabel(for: month(net: -10, isPast: true)) == L10n.UXL18.shortfallPast(name))
    }

    @Test func monthInSentence_isLowercaseInSpanish() {
        // `.month(.wide)` a secas daba «Noviembre» a media frase («Monto para Noviembre»).
        let text = CashFlowMonthSummaryLogic.monthInSentence(date(2026, 11, 1), calendar: calendar, locale: es)
        #expect(text == "noviembre")
        #expect(CashFlowMonthSummaryLogic.monthInSentence(date(2026, 11, 1), calendar: calendar,
                                                          locale: Locale(identifier: "en_US")) == "November")
    }

    @Test func spentShare_onlyInTheCurrentMonth() {
        let lines = [expense(planned: 100, real: 50), expense(planned: 100, real: 86)]
        #expect(CashFlowMonthSummaryLogic.spentShare(of: month(net: 0, isCurrent: true, expenses: lines)) == 68)
        #expect(CashFlowMonthSummaryLogic.spentShare(of: month(net: 0, expenses: lines)) == nil)
        #expect(CashFlowMonthSummaryLogic.spentShare(of: month(net: 0, isCurrent: true)) == nil, "sin plan de gasto")
    }

    @Test func projectedEnd_isTheLastMonthWithABalance() {
        let withBalance = CashFlowMonth(
            monthKey: "2026-12", date: date(2026, 12, 1), isPast: false, isCurrent: false,
            incomeLines: [], expenseLines: [], otherExpenses: nil, otherIncome: nil,
            totalIncome: 0, totalExpense: 0, netFlow: 0, accumulatedBalance: 12_028
        )
        let end = CashFlowMonthSummaryLogic.projectedEnd(of: [month(net: 1), withBalance, month(net: 2)])
        #expect(end?.monthKey == "2026-12")
    }

    @Test func startingBalanceText_keepsTwoDecimals_andNoGrouping() {
        let text = CashFlowStartingBalanceSheet.editableText(83_666.25, locale: Locale(identifier: "es_PE"))
        #expect(text == "83666.25")
        #expect(CashFlowStartingBalanceSheet.editableText(1200, locale: Locale(identifier: "es_PE")) == "1200")
        #expect(CashFlowStartingBalanceSheet.editableText(10.5, locale: Locale(identifier: "de_DE")) == "10,5")
    }
}
