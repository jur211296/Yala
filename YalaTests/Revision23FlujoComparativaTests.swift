//
//  Revision23FlujoComparativaTests.swift
//  YalaTests
//
//  Revisión 2.3, Reportes y Flujo de caja (decisiones 32 y 33 del 9-nov):
//  - La Comparativa decía «Noviembre» comparando del 1 al 7. Ahora el período en curso se nombra por su tramo
//    («1–7 nov»), abre desglosada por categoría y ordena las filas por cambio en dinero.
//  - La primera semana, sin ingresos, el armado del plan decía «Te faltan al mes S/ 2,573». Ahora pregunta el ingreso, y
//    con «Aún no lo sé» no anuncia una falta.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Comparativa: el tramo exacto

@MainActor
struct ComparativaTramoExactoTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    private let locale = Locale(identifier: "es_PE")

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    @Test("«Este mes» el día 7 se nombra por el tramo que entra, no por el mes entero")
    func thisMonth_onTheSeventh_isNamedByItsDays() {
        let now = date(2026, 11, 7)
        let name = ComparativeLabelsLogic.currentName(
            period: .thisMonth, customRange: nil, mode: .month, dataEnd: now,
            now: now, calendar: calendar, locale: locale
        )
        #expect(name.isDayRange)
        #expect(name.column.contains("1"))
        #expect(name.column.contains("7"))
        #expect(!name.column.lowercased().hasPrefix("noviembre"), "Sigue diciendo el mes entero: \(name.column)")
    }

    @Test("El tramo acaba el último día con movimientos, como el anterior con el que se compara")
    func thisMonth_endsWithTheLastDayWithData() {
        let now = date(2026, 11, 7)
        let name = ComparativeLabelsLogic.currentName(
            period: .thisMonth, customRange: nil, mode: .month, dataEnd: date(2026, 11, 5),
            now: now, calendar: calendar, locale: locale
        )
        let compared = ComparativeLabelsLogic.comparedName(
            period: .thisMonth, mode: .month, customRange: nil, dataEnd: date(2026, 11, 5),
            now: now, calendar: calendar, locale: locale
        )
        #expect(name.column.contains("5"))
        #expect(!name.column.contains("7"))
        #expect(compared?.column.contains("5") == true, "El anterior no acaba el mismo día: \(compared?.column ?? "nil")")
    }

    @Test("Control: sin modo de comparación, y en «Mes pasado», el nombre de siempre")
    func withoutAlignment_keepsTheMonthName() {
        let now = date(2026, 11, 7)
        let plain = ComparativeLabelsLogic.currentName(
            period: .thisMonth, customRange: nil, now: now, calendar: calendar, locale: locale
        )
        #expect(!plain.isDayRange)
        let lastMonth = ComparativeLabelsLogic.currentName(
            period: .lastMonth, customRange: nil, mode: .month, dataEnd: now,
            now: now, calendar: calendar, locale: locale
        )
        #expect(!lastMonth.isDayRange)
        // Con el mismo mes del año pasado no hay recorte: el mes entero contra el mes entero.
        let yearMode = ComparativeLabelsLogic.currentName(
            period: .thisMonth, customRange: nil, mode: .year, dataEnd: now,
            now: now, calendar: calendar, locale: locale
        )
        #expect(!yearMode.isDayRange)
    }

    @Test("El último día del mes vuelve a ser el mes entero")
    func thisMonth_onTheLastDay_isTheWholeMonth() {
        let now = date(2026, 11, 30)
        let name = ComparativeLabelsLogic.currentName(
            period: .thisMonth, customRange: nil, mode: .month, dataEnd: now,
            now: now, calendar: calendar, locale: locale
        )
        #expect(!name.isDayRange)
    }

    @Test("La frase de arriba lleva el tramo a los dos lados")
    func heading_withTwoRanges_saysBothRanges() {
        let current = ComparativeLabelsLogic.Name(column: "1–7 nov", inSentence: "1–7 de noviembre", isDayRange: true)
        let compared = ComparativeLabelsLogic.Name(column: "1–7 oct", inSentence: "1–7 de octubre", isDayRange: true)
        let heading = ComparativeLabelsLogic.heading(current: current, compared: compared, locale: locale)
        #expect(heading == L10n.UXL18.headingRange("1–7 de noviembre", "1–7 de octubre"))
        // Con un mes entero, la frase de siempre.
        let month = ComparativeLabelsLogic.Name(column: "Octubre", inSentence: "octubre", isDayRange: false)
        let september = ComparativeLabelsLogic.Name(column: "Setiembre", inSentence: "setiembre", isDayRange: false)
        #expect(ComparativeLabelsLogic.heading(current: month, compared: september, locale: locale)
            == L10n.UXL18.heading("Octubre", "setiembre"))
    }

    @Test("«igual» y «nuevo» existen y no son las siglas de antes")
    func changeWords_areNotTheOldSymbols() {
        #expect(!L10n.UXL18.changeSame.isEmpty)
        #expect(L10n.UXL18.changeNew != "N/A")
        #expect(!L10n.UXL18.changeSame.contains("%"))
    }
}

// MARK: - Comparativa: abre por categoría, ordenada por cambio

@MainActor
struct ComparativaDesgloseYOrdenTests {

    private let day = Date(timeIntervalSince1970: 1_790_000_000)  // 2026-09-21

    private func tx(_ amount: Double, _ category: YalaCategory, daysAgo: Int = 0) -> TransactionItem {
        let item = TransactionItem(
            date: day.addingTimeInterval(TimeInterval(-daysAgo * 86_400)), amount: amount, currencyCode: "PEN",
            note: "", category: category, account: nil, amountInPreferredCurrency: amount)
        item.preferredCurrencyCode = "PEN"
        return item
    }

    @Test("Abre con «Ingresos y gastos» › Categoría")
    func defaultGrouping_isByCategory() {
        #expect(ReportGroupingState().activeDimensions == [.tipo, .categoria])
    }

    /// El caso de la maqueta: Entretenimiento +156, Hogar +143, Alimentación −98, Vehículo −189. Por monto saldría
    /// Hogar (2.343) primero; por porcentaje, Entretenimiento (+205 %) taparía a Hogar.
    @Test("Con comparación, las categorías van por cambio en soles, de más a menos")
    func withComparison_sortsByChangeInMoney() throws {
        let fun = YalaCategory(name: "Entretenimiento", colorHex: "#000000", isIncome: false)
        let home = YalaCategory(name: "Hogar", colorHex: "#000000", isIncome: false)
        let food = YalaCategory(name: "Alimentación", colorHex: "#000000", isIncome: false)
        let car = YalaCategory(name: "Vehículo", colorHex: "#000000", isIncome: false)
        let current = [tx(-232, fun), tx(-2_343, home), tx(-542, food), tx(-93, car)]
        let previous = [tx(-76, fun, daysAgo: 31), tx(-2_200, home, daysAgo: 31),
                        tx(-640, food, daysAgo: 31), tx(-282, car, daysAgo: 31)]

        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: current, previousTransactions: previous, hierarchy: [.tipo, .categoria],
            preferredCurrency: "PEN", allTags: [], sortsByChange: true)

        let expenses = try #require(nodes.first { !$0.isIncome })
        #expect(expenses.children.map(\.label) == ["Entretenimiento", "Hogar", "Alimentación", "Vehículo"])

        // Control: sin comparación, por monto como siempre.
        let byAmount = PivotTableCalculator.buildTree(
            currentTransactions: current, previousTransactions: previous, hierarchy: [.tipo, .categoria],
            preferredCurrency: "PEN", allTags: [])
        let expensesByAmount = try #require(byAmount.first { !$0.isIncome })
        #expect(expensesByAmount.children.first?.label == "Hogar")
    }

    @Test("Lo nuevo cuenta entero como cambio, e Ingresos sigue arriba")
    func newRows_countWhole_andIncomeStaysFirst() throws {
        let salary = YalaCategory(name: "Sueldo", colorHex: "#000000", isIncome: true)
        let pets = YalaCategory(name: "Mascotas", colorHex: "#000000", isIncome: false)
        let home = YalaCategory(name: "Hogar", colorHex: "#000000", isIncome: false)
        let current = [tx(8_500, salary), tx(-48, pets), tx(-2_220, home)]
        let previous = [tx(8_500, salary, daysAgo: 31), tx(-2_200, home, daysAgo: 31)]

        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: current, previousTransactions: previous, hierarchy: [.tipo, .categoria],
            preferredCurrency: "PEN", allTags: [], sortsByChange: true)

        #expect(nodes.first?.isIncome == true, "«Ingresos» dejó de ir arriba")
        let expenses = try #require(nodes.first { !$0.isIncome })
        #expect(expenses.children.map(\.label) == ["Mascotas", "Hogar"], "48 nuevos pesan más que 20 de cambio")
        let pet = try #require(expenses.children.first)
        #expect(pet.previousAmount == nil, "Mascotas debería ser nueva (sin nada antes)")
    }
}

// MARK: - Armado del plan sin ingresos

@Suite(.serialized)
@MainActor
struct CashFlowSetupIngresoQueFaltaTests {

    @Test("Pregunta el ingreso solo si hay algo que sugerir y ninguna línea de ingreso")
    func asksForIncome_onlyWithoutIncomeLines() {
        #expect(CashFlowSetupLogic.asksForIncome(suggestedIncomeLines: 0, suggestedLines: 3))
        #expect(!CashFlowSetupLogic.asksForIncome(suggestedIncomeLines: 1, suggestedLines: 3))
        #expect(!CashFlowSetupLogic.asksForIncome(suggestedIncomeLines: 0, suggestedLines: 0))
    }

    @Test("Sin ingreso y con «Aún no lo sé», el resumen no anuncia «Te faltan»")
    func unknownIncome_isNotAShortfall() {
        let outcome = CashFlowSetupLogic.summaryOutcome(
            suggestedIncome: 0, expense: 2_573, asksForIncome: true, typedIncome: nil)
        #expect(outcome == .incomeMissing)
        // Control: con ingresos sugeridos que no alcanzan, sí falta.
        #expect(CashFlowSetupLogic.summaryOutcome(
            suggestedIncome: 1_000, expense: 2_573, asksForIncome: false, typedIncome: nil) == .shortfall(1_573))
    }

    @Test("Con el ingreso escrito, el resumen cuadra")
    func typedIncome_completesTheSummary() {
        #expect(CashFlowSetupLogic.summaryOutcome(
            suggestedIncome: 0, expense: 2_573, asksForIncome: true, typedIncome: 3_000) == .surplus(427))
    }

    @Test("El ingreso escrito se ata a la primera categoría de ingreso que la persona ve, nunca a una de sistema")
    func typedIncomeCategory_skipsSystemAndHidden() {
        let groups = YalaCategory(name: "Cobros de grupos", colorHex: "#000000", isIncome: true, sortOrder: 0, isSystem: true)
        let hidden = YalaCategory(name: "Oculta", colorHex: "#000000", isIncome: true, isVisible: false, sortOrder: 1)
        let income = YalaCategory(name: "Ingresos", colorHex: "#000000", isIncome: true, sortOrder: 5)
        let other = YalaCategory(name: "Extra", colorHex: "#000000", isIncome: true, sortOrder: 9)
        let food = YalaCategory(name: "Comida", colorHex: "#000000", isIncome: false, sortOrder: 0)
        let picked = CashFlowSetupLogic.typedIncomeCategory(in: [food, other, groups, hidden, income])
        #expect(picked?.name == "Ingresos")
        #expect(CashFlowSetupLogic.typedIncomeCategory(in: [food, groups]) == nil)
    }

    @Test("Crear el plan con el ingreso escrito deja una línea de ingreso con ese monto, atada a su categoría")
    func createPlan_withTypedIncome_addsTheIncomeLine() throws {
        let context = try makeTestContext()
        let income = YalaCategory(name: "Ingresos", colorHex: "#000000", isIncome: true)
        context.insert(income)
        try context.save()
        let viewModel = CashFlowPlanViewModel()
        viewModel.setContext(context)
        viewModel.suggestedLines = [
            SuggestedLine(category: nil, subcategory: nil, scheduledPayment: nil, name: "Alquiler", isIncome: false,
                          suggestedAmount: 2_200, estimationMethod: .manual, monthsWithActivity: 1, isSelected: true)
        ]

        viewModel.createPlan(startingBalance: 16_472, typedIncome: 3_000, incomeCategory: income)

        let lines = try context.fetch(FetchDescriptor<CashFlowLine>())
        let incomeLine = try #require(lines.first { $0.isIncome })
        #expect(incomeLine.manualAmount == 3_000)
        #expect(incomeLine.method == .manual)
        #expect(incomeLine.category?.name == "Ingresos")
        #expect(lines.count == 2)

        // Control: sin ingreso escrito no se inventa ninguna línea de ingreso.
        let other = CashFlowPlanViewModel()
        other.setContext(context)
        other.suggestedLines = viewModel.suggestedLines
        let before = try context.fetchCount(FetchDescriptor<CashFlowLine>(predicate: #Predicate { $0.isIncome }))
        other.createPlan(startingBalance: 0)
        let after = try context.fetchCount(FetchDescriptor<CashFlowLine>(predicate: #Predicate { $0.isIncome }))
        #expect(after == before)
    }
}
