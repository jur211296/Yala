//
//  FlujoConsumidoresParidadTests.swift
//  YalaTests
//
//  S6 del replanteo del flujo de caja (ticket `2026-11-17-flujo-de-caja-replanteo`, decisiones de Jürgen del
//  18-nov-2026): «Ver proyectado» del Panel, Tendencias y el widget de Saldo usan la misma pieza del motor del mes
//  (`FlujoMotorMes`). Con plan, lo que les falta a las líneas; sin plan o con filtros, «otros» por la mediana de 6 meses
//  sin líneas. Desde el 19-nov-2026 los ingresos sin línea se proyectan solo si son fijos detectados
//  (`FlujoProyeccionInteligente`), y nada se cuenta dos veces.
//
//  Paridad: «Al 30» del flujo de caja (el cierre del mes en curso), «Al 30» del Panel (`MonthEndBalanceLogic`) y el
//  último punto del mes del widget de Saldo (`WidgetDataCache.buildProjectedFlow` acumulado como lo acumula el widget)
//  dan la misma cifra, con plan y sin plan.
//
//  El fixture trae lo que separa las reglas (`ingreso-gasto.md`): un movimiento sin categoría de cada signo, una
//  devolución en una categoría de gasto, un gasto ya fechado por delante y gastos enlazados a un pago planificado.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja S6: Panel, Tendencias y widget con el mismo motor", .serialized)
struct FlujoConsumidoresParidadTests {

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
        let rent: ScheduledPayment
    }

    /// Agosto a octubre: comida 300, 90 sin categoría y el alquiler de 800 enlazado a su pago; en octubre, una
    /// devolución de 60 en comida. Noviembre (hoy, 18): el sueldo, 200 de comida, 250 sin categoría que entran y 150 de
    /// comida ya fechados para el 25; el alquiler del 25 aún no se pagó.
    ///
    /// «Otros» de cada mes (sin pagos): agosto 390, septiembre 390, octubre 330 ⇒ mediana 390. Noviembre ya lleva
    /// 200 + 150 fechado = 350, así que le faltan 40.
    private static func escenario() throws -> Escenario {
        let context = try makeTestContext()
        let bank = Account(name: "Banco", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(bank)
        let food = YalaCategory(name: "Comida", colorHex: "#000", isIncome: false)
        let salary = YalaCategory(name: "Sueldo", colorHex: "#000", isIncome: true)
        let housing = YalaCategory(name: "Vivienda", colorHex: "#000", isIncome: false)
        [food, salary, housing].forEach { context.insert($0) }

        let rent = ScheduledPayment(
            name: "Alquiler", amount: 800, currencyCode: "PEN", transactionType: "expense",
            isRecurring: true, recurrenceType: "monthly", recurrenceInterval: 1,
            nextDueDate: date(2026, 11, 25, hour: 0), paymentCategory: "recurring", isActive: true
        )
        rent.account = bank
        rent.createdAt = date(2026, 1, 1)
        context.insert(rent)

        var transactions: [TransactionItem] = []
        func tx(_ amount: Double, _ day: Date, _ category: YalaCategory? = nil, payment: ScheduledPayment? = nil) {
            let item = TransactionItem(date: day, amount: amount, currencyCode: "PEN", category: category)
            item.account = bank
            item.scheduledPaymentID = payment?.id.uuidString
            context.insert(item)
            transactions.append(item)
        }
        for month in 8...10 {
            tx(3_000, date(2026, month, 1), salary)
            tx(-300, date(2026, month, 5), food)
            tx(-90, date(2026, month, 12))
            tx(-800, date(2026, month, 25), housing, payment: rent)
        }
        tx(60, date(2026, 10, 8), food)            // devolución: resta de comida
        tx(3_000, date(2026, 11, 1), salary)
        tx(-200, date(2026, 11, 5), food)
        tx(250, date(2026, 11, 6))                 // sin categoría y positivo: ingreso
        tx(-150, date(2026, 11, 25), food)         // ya fechado por delante
        try context.save()
        return Escenario(context: context, bank: bank, transactions: transactions, rent: rent)
    }

    // MARK: - Las tres cifras

    /// «Al 30» del Panel: saldo de hoy + lo que falta.
    private static func panel(_ e: Escenario) throws -> MonthEndBalanceLogic.Result {
        try #require(MonthEndBalanceLogic.compute(
            accounts: [e.bank], transactions: e.transactions, scheduledPayments: [e.rent], currencyCode: "PEN",
            includeGroups: true, adjustment: .none, converter: IdentityConverter(), context: e.context,
            now: now, calendar: calendar
        ))
    }

    /// El último punto del mes del widget de Saldo: su saldo con lo esperado de cada día acumulado encima, como
    /// `BalanceWidgetProvider.createEntry`.
    private static func widget(_ e: Escenario) throws -> Double {
        let flow = try #require(WidgetDataCache.buildProjectedFlow(
            allTransactions: e.transactions, eligibleTransactions: e.transactions, scheduledPayments: [e.rent],
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

    /// El cierre del mes en curso del flujo de caja, armado como `CashFlowPlanViewModel.loadProjection`.
    private static func flujoDeCaja(_ e: Escenario, plan: CashFlowPlan, lines: [CashFlowLine]) throws -> Double {
        let balance = FlujoMotorMesEntrada.FuenteSaldo(
            accounts: [e.bank], transactions: e.transactions, currencyCode: "PEN", converter: IdentityConverter()
        )
        let occurrences = FlujoMotorMesEntrada.ocurrencias(
            allTransactions: e.transactions, scheduledPayments: [e.rent],
            paymentFilter: ProjectedFlowBuilder.PaymentFilter(
                accounts: EntityFilter(included: [e.bank.persistentModelID])
            ),
            currencyCode: "PEN", adjustment: .none, converter: IdentityConverter(),
            lastMonth: date(2026, 12, 1), now: now, calendar: calendar
        )
        let projection = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: lines, transactions: e.transactions, allExpenseCategories: [],
            scheduledPayments: [e.rent], monthsBack: 0, monthsAhead: 1, currencyCode: "PEN",
            adjustment: .none, converter: IdentityConverter(), balance: balance, occurrences: occurrences,
            historyTransactions: e.transactions, now: now, calendar: calendar
        )
        let enCurso = projection.months.first { $0.isCurrent }
        let current = try #require(enCurso)
        return try #require(current.accumulatedBalance)
    }

    // MARK: - Sin plan

    @Test func sinPlan_panelYWidget_danLaMismaCifra_conOtrosPorLaMediana() throws {
        let e = try Self.escenario()
        let panel = try Self.panel(e)

        // Hoy: 4 × 3.000 − 3 × (300 + 90 + 800) + 60 − 200 + 250 = 8.540 (lo fechado del 25 aún no está).
        #expect(abs(panel.today - 8_540) < 0.001)
        #expect(abs(panel.incomeLeft) < 0.001, "Sin plan, los ingresos sin línea no se proyectan (P6)")
        // Falta salir: 40 de «otros» (mediana 390 − 350 que ya lleva el mes), el alquiler del 25 y lo fechado.
        #expect(abs(panel.expenseLeft - (40 + 800 + 150)) < 0.001, "Falta salir: \(panel.expenseLeft)")
        #expect(panel.source == .rhythm, "El gasto estimado sigue nombrándose «tu ritmo de gasto»")

        let widget = try Self.widget(e)
        #expect(abs(widget - panel.closing) < 0.001, "El widget de Saldo acaba el mes en la cifra del Panel")
    }

    /// Lo ya fechado para el 25 se pinta en su día y descuenta de lo que le falta a «otros»: no entra dos veces (el ticket
    /// `projected-flow-with-plan-counts-a-future-dated-row-twice-in-a-future-month`, también sin plan).
    @Test func sinPlan_loFechadoEntraUnaVez() throws {
        let e = try Self.escenario()
        let days = ProjectedFlowCalculator.futureDays(
            in: DateInterval(start: Self.date(2026, 11, 1, hour: 0), end: Self.date(2026, 12, 31, hour: 23)),
            today: Self.now, calendar: Self.calendar
        )
        let built = ProjectedFlowBuilder.build(
            ProjectedFlowBuilder.Inputs(
                today: Self.now, calendar: Self.calendar,
                overdueWindowStart: Self.date(2026, 11, 1, hour: 0), days: days,
                allTransactions: e.transactions, countedTransactions: e.transactions, hasSessionFilters: false,
                scheduledPayments: [e.rent], paymentFilter: .none, currencyCode: "PEN", adjustment: .none,
                converter: IdentityConverter()
            ),
            context: e.context
        )
        let december = days.filter { $0 >= Self.date(2026, 12, 1, hour: 0) }
        let decemberExpense = december.reduce(0.0) { $0 + (built.flows[$1]?.expense ?? 0) }
        #expect(abs(decemberExpense - (390 + 800)) < 0.001,
                "Diciembre: la mediana entera y el alquiler, sin el gasto puntual de noviembre: \(decemberExpense)")
        let novemberExpense = days.filter { $0 < Self.date(2026, 12, 1, hour: 0) }
            .reduce(0.0) { $0 + (built.flows[$1]?.expense ?? 0) }
        #expect(abs(novemberExpense - (40 + 800 + 150)) < 0.001)
        // Desde el 19-nov-2026 (proyección inteligente) el sueldo de agosto a octubre es un ingreso fijo detectado: en
        // noviembre ya llegó y no se proyecta otra vez; en diciembre entra entero el día 1, su día típico.
        #expect(days.filter { $0 < Self.date(2026, 12, 1, hour: 0) }.allSatisfy { (built.flows[$0]?.income ?? 0) == 0 },
                "Noviembre ya cobró su sueldo")
        #expect(abs((built.flows[Self.calendar.startOfDay(for: Self.date(2026, 12, 1))]?.income ?? 0) - 3_000) < 0.001,
                "Diciembre: el sueldo fijo en su día")
        #expect(abs(december.reduce(0.0) { $0 + (built.flows[$1]?.income ?? 0) } - 3_000) < 0.001)
        #expect(built.incomeSource == .scheduledOnly)
    }

    // MARK: - Con plan

    /// Con plan: una línea de comida de 500. Comida lleva 200 + 150 fechado, le faltan 150; «otros» sin comida: agosto
    /// y septiembre 90, octubre 90 ⇒ mediana 90, y noviembre aún no tiene nada suyo.
    @Test func conPlan_flujoDeCajaPanelYWidget_danLaMismaCifra() throws {
        let e = try Self.escenario()
        let food = try #require(e.transactions.first { $0.category?.name == "Comida" }?.category)
        let plan = CashFlowPlan(name: "Plan")
        e.context.insert(plan)
        let line = CashFlowLine(name: "Comida", isIncome: false, estimationMethod: .manual, manualAmount: 500,
                                category: food)
        line.plan = plan
        e.context.insert(line)
        try e.context.save()

        let panel = try Self.panel(e)
        #expect(panel.source == .plan)
        #expect(abs(panel.expenseLeft - (150 + 90 + 800 + 150)) < 0.001, "Falta salir: \(panel.expenseLeft)")

        let flujo = try Self.flujoDeCaja(e, plan: plan, lines: [line])
        #expect(abs(flujo - panel.closing) < 0.001, "«Al 30» del flujo de caja es el del Panel")
        let widget = try Self.widget(e)
        #expect(abs(widget - panel.closing) < 0.001, "El widget de Saldo acaba el mes en la cifra del Panel")
    }

    // MARK: - Con filtros

    /// Con filtros de sesión el plan no se sabe repartir: manda el motor sin líneas sobre lo filtrado, y la mediana es
    /// la de lo filtrado. «Solo Comida»: agosto y septiembre 300, octubre 240 ⇒ 300; noviembre lleva 350 ⇒ nada más.
    @Test func conFiltros_laMedianaEsLaDeLoFiltrado() throws {
        let e = try Self.escenario()
        let soloComida = e.transactions.filter { $0.category?.name == "Comida" }
        let days = ProjectedFlowCalculator.futureDays(
            in: DateInterval(start: Self.date(2026, 11, 1, hour: 0), end: Self.date(2026, 12, 31, hour: 23)),
            today: Self.now, calendar: Self.calendar
        )
        let built = ProjectedFlowBuilder.build(
            ProjectedFlowBuilder.Inputs(
                today: Self.now, calendar: Self.calendar,
                overdueWindowStart: Self.date(2026, 11, 1, hour: 0), days: days,
                allTransactions: e.transactions, countedTransactions: soloComida, hasSessionFilters: true,
                scheduledPayments: [], paymentFilter: .none, currencyCode: "PEN", adjustment: .none,
                converter: IdentityConverter()
            ),
            context: e.context
        )
        let november = days.filter { $0 < Self.date(2026, 12, 1, hour: 0) }
        let december = days.filter { $0 >= Self.date(2026, 12, 1, hour: 0) }
        let novemberExpense = november.reduce(0.0) { $0 + (built.flows[$1]?.expense ?? 0) }
        let decemberExpense = december.reduce(0.0) { $0 + (built.flows[$1]?.expense ?? 0) }
        #expect(abs(novemberExpense - 150) < 0.001, "Noviembre ya pasó de la mediana: solo lo fechado: \(novemberExpense)")
        #expect(abs(decemberExpense - 300) < 0.001, "La mediana de comida, no la de todo: \(decemberExpense)")
        #expect(built.expenseSource == .rhythm)
    }
}
