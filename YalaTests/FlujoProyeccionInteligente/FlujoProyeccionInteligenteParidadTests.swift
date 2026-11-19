//
//  FlujoProyeccionInteligenteParidadTests.swift
//  YalaTests
//
//  Proyección inteligente (19-nov-2026): con un sueldo fijo detectado y un iPhone aislado, «Al 30» del flujo de caja,
//  «Al 30» del Panel (`MonthEndBalanceLogic`), el último punto del mes del widget de Saldo y lo que Tendencias
//  («Ver proyectado», `ProjectedFlowBuilder.build`) suma en diciembre dan las mismas cifras que el flujo de caja: todos
//  salen del mismo motor del mes. Con plan sin líneas y sin plan.
//
//  El fixture trae lo que separa las reglas (`ingreso-gasto.md`): un movimiento sin categoría de cada signo y una
//  devolución en una categoría de gasto.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · proyección inteligente · paridad de consumidores", .serialized)
struct FlujoProyeccionInteligenteParidadTests {

    // `WidgetDataCache.buildProjectedFlow` usa `Calendar.current`: todo el caso va con él y un «hoy» fijo a mitad de mes.
    private static let calendar = Calendar.current

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private static var now: Date { date(2026, 11, 18) }

    private struct IdentityConverter: CurrencyConverting {
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
    }

    private struct Escenario {
        let context: ModelContext
        let bank: Account
        let transactions: [TransactionItem]
    }

    /// Mayo a octubre: sueldo de 3,000 el 28, comida 700 y 100 sin categoría; en julio una devolución de 50 en comida y
    /// 40 sin categoría que entran; en agosto un iPhone de 6,000. Noviembre (hoy, 18): 300 de comida y aún sin sueldo.
    ///
    /// Gastos de cada mes sin el iPhone: 800, 800, 750, 800, 800, 800 ⇒ 800. Con él, agosto 6,800 y la mediana igual 800
    /// (el iPhone solo se ve en la lista de aislados). Noviembre lleva 300 ⇒ faltan 500. El sueldo falta entero.
    private static func escenario() throws -> Escenario {
        let context = try makeTestContext()
        let bank = Account(name: "Banco", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(bank)
        let food = YalaCategory(name: "Comida", colorHex: "#000", isIncome: false)
        let salary = YalaCategory(name: "Sueldo", colorHex: "#000", isIncome: true)
        let tech = YalaCategory(name: "Tecnología", colorHex: "#000", isIncome: false)
        [food, salary, tech].forEach { context.insert($0) }
        var transactions: [TransactionItem] = []
        func tx(_ amount: Double, _ day: Date, _ category: YalaCategory? = nil, note: String? = nil) {
            let item = TransactionItem(date: day, amount: amount, currencyCode: "PEN", category: category)
            item.account = bank
            item.note = note
            context.insert(item)
            transactions.append(item)
        }
        tx(10_000, date(2026, 4, 30))              // sin categoría y positivo: ingreso de abril, fuera de la ventana
        for month in 5...10 {
            tx(3_000, date(2026, month, 28), salary)
            tx(-700, date(2026, month, 6), food)
            tx(-100, date(2026, month, 12))
        }
        tx(50, date(2026, 7, 9), food)             // devolución: resta de comida
        tx(40, date(2026, 7, 15))                  // sin categoría y positivo: ingreso
        tx(-6_000, date(2026, 8, 20), tech, note: "iPhone 17 Pro")
        tx(-300, date(2026, 11, 5), food)
        try context.save()
        return Escenario(context: context, bank: bank, transactions: transactions)
    }

    private static func panel(_ e: Escenario) throws -> MonthEndBalanceLogic.Result {
        try #require(MonthEndBalanceLogic.compute(
            accounts: [e.bank], transactions: e.transactions, scheduledPayments: [], currencyCode: "PEN",
            includeGroups: true, adjustment: .none, converter: IdentityConverter(), context: e.context,
            now: now, calendar: calendar
        ))
    }

    private static func widget(_ e: Escenario) throws -> Double {
        let flow = try #require(WidgetDataCache.buildProjectedFlow(
            allTransactions: e.transactions, eligibleTransactions: e.transactions, scheduledPayments: [],
            currencyCode: "PEN", adjustment: .none, converter: IdentityConverter(), context: e.context, now: now
        ))
        let anchor = (LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [e.bank], transactions: e.transactions, preferredCurrencyCode: "PEN", asOf: now,
            converter: IdentityConverter()
        ).convertedTotal as NSDecimalNumber).doubleValue
        let points = WidgetInsightsLogic.projectedCumulative(
            anchor: anchor,
            deltas: flow.days.map { (date: $0.date, value: $0.income - $0.expense) },
            asOf: now,
            end: date(2026, 11, 30, hour: 0),
            calendar: calendar
        )
        return try #require(points.last?.value)
    }

    /// «Ver proyectado» de Tendencias hasta fin de diciembre.
    private static func tendencias(_ e: Escenario) -> (flows: [Date: ProjectedFlowCalculator.DayFlow], days: [Date]) {
        let days = ProjectedFlowCalculator.futureDays(
            in: DateInterval(start: date(2026, 11, 1, hour: 0), end: date(2026, 12, 31, hour: 23)),
            today: now, calendar: calendar
        )
        let built = ProjectedFlowBuilder.build(
            ProjectedFlowBuilder.Inputs(
                today: now, calendar: calendar, overdueWindowStart: date(2026, 11, 1, hour: 0), days: days,
                allTransactions: e.transactions, countedTransactions: e.transactions, hasSessionFilters: false,
                scheduledPayments: [], paymentFilter: .none, currencyCode: "PEN", adjustment: .none,
                converter: IdentityConverter()
            ),
            context: e.context
        )
        return (built.flows, days)
    }

    private static func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    // MARK: - Sin plan

    @Test func sinPlan_panelWidgetYTendencias_proyectanElSueldoFijoYNoElIPhone() throws {
        let e = try Self.escenario()
        let panel = try Self.panel(e)
        #expect(Self.near(panel.incomeLeft, 3_000), "El sueldo fijo de noviembre aún no llegó: \(panel.incomeLeft)")
        #expect(Self.near(panel.expenseLeft, 500), "Lo que se gasta en un mes normal menos lo que ya va: \(panel.expenseLeft)")
        #expect(Self.near(try Self.widget(e), panel.closing), "El widget de Saldo acaba el mes en la cifra del Panel")

        let t = Self.tendencias(e)
        let diciembre = t.days.filter { $0 >= Self.date(2026, 12, 1, hour: 0) }
        #expect(Self.near(diciembre.reduce(0) { $0 + (t.flows[$1]?.income ?? 0) }, 3_000))
        #expect(Self.near(diciembre.reduce(0) { $0 + (t.flows[$1]?.expense ?? 0) }, 800), "Sin el iPhone")
        #expect(Self.near(t.flows[Self.calendar.startOfDay(for: Self.date(2026, 12, 28))]?.income ?? 0, 3_000),
                "El sueldo se dibuja en su día")
    }

    // MARK: - Con plan sin líneas

    @Test func conPlanSinLineas_flujoDeCajaPanelWidgetYTendencias_danLasMismasCifras() throws {
        let e = try Self.escenario()
        let plan = CashFlowPlan(name: "Plan")
        e.context.insert(plan)
        try e.context.save()

        let projection = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [], transactions: e.transactions, allExpenseCategories: [],
            scheduledPayments: [], monthsBack: 0, monthsAhead: 1, currencyCode: "PEN",
            adjustment: .none, converter: IdentityConverter(),
            balance: FlujoMotorMesEntrada.FuenteSaldo(
                accounts: [e.bank], transactions: e.transactions, currencyCode: "PEN", converter: IdentityConverter()
            ),
            historyTransactions: e.transactions, now: Self.now, calendar: Self.calendar
        )
        let nov = try #require(projection.months.first { $0.isCurrent })
        let dic = try #require(projection.months.last)

        // Flujo de caja: lo que explica la hoja «Otros».
        let otrosIngresos = try #require(dic.otherIncome)
        #expect(otrosIngresos.fixedItems.count == 1)
        #expect(otrosIngresos.fixedItems.first?.day == 28)
        #expect(Self.near(otrosIngresos.fixedItems.first?.monthlyAmount ?? 0, 3_000))
        let otrosGastos = try #require(dic.otherExpenses)
        #expect(otrosGastos.isolatedItems.count == 1)
        #expect(Self.near(otrosGastos.isolatedItems.first?.amount ?? 0, 6_000))
        #expect(Self.near(otrosGastos.variableEstimate, 800))
        // Con plan, diciembre proyecta fuera de las líneas solo lo fijo (19-nov-2026): la comida de 700 el día 6 y los
        // 100 sin categoría del 12 se repiten con monto y día; el iPhone, no. Nada de la mediana.
        #expect(otrosGastos.isFixedOnly)
        #expect(Self.near(otrosGastos.variableLeft, 0))
        #expect(Self.near(otrosGastos.items.reduce(0) { $0 + $1.total }, otrosGastos.plannedAmount))
        #expect(Self.near(dic.totalIncome, 3_000))
        #expect(Self.near(dic.totalExpense, 800))

        // Panel y widget: «Al 30» es el cierre del mes en curso del flujo de caja.
        let panel = try Self.panel(e)
        #expect(panel.source == .plan)
        #expect(Self.near(try #require(nov.accumulatedBalance), panel.closing), "«Al 30» del flujo de caja es el del Panel")
        #expect(Self.near(try Self.widget(e), panel.closing))

        // Tendencias: diciembre suma lo que el flujo de caja dice de diciembre.
        let t = Self.tendencias(e)
        let diciembre = t.days.filter { $0 >= Self.date(2026, 12, 1, hour: 0) }
        #expect(Self.near(diciembre.reduce(0) { $0 + (t.flows[$1]?.income ?? 0) }, dic.totalIncome))
        #expect(Self.near(diciembre.reduce(0) { $0 + (t.flows[$1]?.expense ?? 0) }, dic.totalExpense))
    }

    // MARK: - Con plan y una partida apagada a futuro

    /// «Considerar a futuro» apagado en la comida fija: diciembre deja de proyectarla en el flujo de caja, y Tendencias
    /// («Ver proyectado») suma lo mismo, porque las dos leen el mismo almacén por el mismo cálculo.
    @Test func conPlan_partidaApagada_flujoDeCajaYTendencias_danLoMismo() throws {
        let e = try Self.escenario()
        let plan = CashFlowPlan(name: "Plan")
        e.context.insert(plan)
        try e.context.save()
        let defaults = makeIsolatedDefaults()
        FlujoFijosAFuturo._testDefaults = defaults
        defer { FlujoFijosAFuturo._testDefaults = nil }

        func diciembre() throws -> CashFlowMonth {
            let projection = CashFlowProjectionCalculator.calculate(
                plan: plan, lines: [], transactions: e.transactions, allExpenseCategories: [],
                scheduledPayments: [], monthsBack: 0, monthsAhead: 1, currencyCode: "PEN",
                adjustment: .none, converter: IdentityConverter(), historyTransactions: e.transactions,
                now: Self.now, calendar: Self.calendar
            )
            return try #require(projection.months.last)
        }
        let antes = try diciembre()
        let comida = try #require(antes.otherExpenses?.items.first { $0.name == "Comida" }?.fixedItems.first)
        FlujoFijosAFuturo.considerar(comida.stableKey, false)

        let dic = try diciembre()
        #expect(Self.near(dic.totalExpense, antes.totalExpense - 700))
        let fila = try #require(dic.otherExpenses?.items.first { $0.name == "Comida" })
        #expect(fila.fixedItems.first?.isConsideredInFuture == false)
        #expect(Self.near(fila.total, 0))

        let t = Self.tendencias(e)
        let dias = t.days.filter { $0 >= Self.date(2026, 12, 1, hour: 0) }
        #expect(Self.near(dias.reduce(0) { $0 + (t.flows[$1]?.expense ?? 0) }, dic.totalExpense))
        #expect(Self.near(dias.reduce(0) { $0 + (t.flows[$1]?.income ?? 0) }, dic.totalIncome))
    }
}
