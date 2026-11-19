//
//  FlujoMotorMesTests.swift
//  YalaTests
//
//  S1 del replanteo del flujo de caja (decisiones de Jürgen del 18-nov-2026, ticket
//  `2026-11-17-flujo-de-caja-replanteo`): un solo motor del mes, real con signo más lo que falta. Un caso por hallazgo
//  de motor (1 a 11) sobre el escenario de la sonda del análisis (`docs/analisis/2026-11-17-flujo-de-caja-replanteo/
//  sonda/`), con el «ahora» fijo el 18 de noviembre en Lima. Las cifras de antes salen de `salida-2026-11-18.txt`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · motor del mes (S1 del replanteo)", .serialized)
struct FlujoMotorMesTests {

    // MARK: - Fixture

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    /// El 18 de noviembre de 2026 a las 10:00 en Lima, como la sonda.
    private static let now = date(2026, 11, 18)

    private struct Conv: CurrencyConverting {
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { rate(from, to) * amount }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { rate(from, to) * amount }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (rate(from, to) * amount, .exact) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (rate(from, to) * amount, .exact) }
        private func rate(_ from: String, _ to: String) -> Decimal {
            if from == to { return 1 }
            if from == "USD" && to == "PEN" { return 3.75 }
            if from == "PEN" && to == "USD" { return 1 / 3.75 }
            return 1
        }
    }

    private struct Escenario {
        let context: ModelContext
        let plan: CashFlowPlan
        let accounts: [Account]
        let transactions: [TransactionItem]
        let lines: [String: CashFlowLine]
        let categories: [String: YalaCategory]
    }

    private static func cuenta(_ context: ModelContext, _ name: String, _ currency: String) -> Account {
        let account = Account(name: name, currencyCode: currency, colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(account)
        return account
    }

    private static func categoria(_ context: ModelContext, _ name: String, income: Bool = false) -> YalaCategory {
        let category = YalaCategory(name: name, colorHex: "#000000", isIncome: income)
        context.insert(category)
        return category
    }

    /// El escenario A de la sonda: seis meses iguales (sueldo 4,000; vivienda 1,500; comida 3 × 300; transporte 200;
    /// ocio 300; 100 sin categoría) y noviembre a medias con una devolución, lo sin categoría de los dos signos, un
    /// ingreso sin línea, un gasto en dólares, un gasto fechado el 28 y otro en diciembre.
    private static func escenarioA(startingBalance: Double = 0) throws -> Escenario {
        let context = try makeTestContext()
        let bank = cuenta(context, "Banco", "PEN")
        let usd = cuenta(context, "Dolares", "USD")
        let sueldo = categoria(context, "Sueldo", income: true)
        let freelance = categoria(context, "Freelance", income: true)
        let vivienda = categoria(context, "Vivienda")
        let comida = categoria(context, "Comida")
        let transporte = categoria(context, "Transporte")
        let ocio = categoria(context, "Ocio")
        var all: [TransactionItem] = []
        func tx(_ amount: Double, _ date: Date, _ category: YalaCategory?, account: Account? = nil,
                currency: String = "PEN", adjustment: String? = nil) {
            let converted = currency == "USD" ? amount * 3.75 : amount
            let item = TransactionItem(date: date, amount: amount, currencyCode: currency, category: category,
                                       account: account ?? bank, amountInPreferredCurrency: converted,
                                       preferredCurrencyCode: "PEN")
            item.balanceAdjustmentType = adjustment
            context.insert(item)
            all.append(item)
        }
        tx(5_000, date(2026, 4, 1), nil, adjustment: InitialBalanceService.typeInitialBalance)
        tx(100, date(2026, 4, 1), nil, account: usd, currency: "USD", adjustment: InitialBalanceService.typeInitialBalance)
        for month in 5...10 {
            tx(4_000, date(2026, month, 1), sueldo)
            tx(-1_500, date(2026, month, 3), vivienda)
            tx(-300, date(2026, month, 5), comida)
            tx(-300, date(2026, month, 15), comida)
            tx(-300, date(2026, month, 25), comida)
            tx(-200, date(2026, month, 10), transporte)
            tx(-300, date(2026, month, 20), ocio)
            tx(-100, date(2026, month, 12), nil)
        }
        tx(4_000, date(2026, 11, 1), sueldo)
        tx(-1_500, date(2026, 11, 3), vivienda)
        tx(-400, date(2026, 11, 2), comida)
        tx(-400, date(2026, 11, 6), comida)
        tx(-300, date(2026, 11, 9), comida)
        tx(80, date(2026, 11, 11), comida)                       // devolución
        tx(-50, date(2026, 11, 4), transporte)
        tx(-10, date(2026, 11, 7), transporte, account: usd, currency: "USD")
        tx(-100, date(2026, 11, 8), nil)
        tx(250, date(2026, 11, 8), nil)
        tx(600, date(2026, 11, 8), freelance)                  // ingreso sin línea
        tx(-200, date(2026, 11, 28), comida)                   // fechado
        tx(-150, date(2026, 12, 10), ocio)                     // fechado en diciembre

        let plan = CashFlowPlan(name: "", startingBalance: startingBalance)
        context.insert(plan)
        var lines: [String: CashFlowLine] = [:]
        for (index, (name, category)) in [
            ("Sueldo", sueldo), ("Vivienda", vivienda), ("Comida", comida), ("Ocio", ocio), ("Transporte", transporte),
        ].enumerated() {
            let line = CashFlowLine(name: name, isIncome: category.isIncome, sortOrder: index,
                                    estimationMethod: .average6m, category: category)
            context.insert(line)
            line.plan = plan
            lines[name] = line
        }
        try context.save()
        return Escenario(
            context: context, plan: plan, accounts: [bank, usd], transactions: all, lines: lines,
            categories: ["Comida": comida, "Ocio": ocio, "Sueldo": sueldo]
        )
    }

    private static func proyeccion(_ e: Escenario, monthsBack: Int = 3, monthsAhead: Int = 6) -> CashFlowProjection {
        CashFlowProjectionCalculator.calculate(
            plan: e.plan, lines: e.plan.lines ?? [], transactions: e.transactions, allExpenseCategories: [],
            scheduledPayments: [], monthsBack: monthsBack, monthsAhead: monthsAhead, currencyCode: "PEN",
            converter: Conv(),
            balance: FlujoMotorMesEntrada.FuenteSaldo(
                accounts: e.accounts, transactions: e.transactions, currencyCode: "PEN", converter: Conv()
            ),
            occurrences: [], now: now, calendar: calendar
        )
    }

    private static func mes(_ p: CashFlowProjection, _ key: String) throws -> CashFlowMonth {
        try #require(p.months.first { $0.monthKey == key })
    }

    private static func linea(_ m: CashFlowMonth, _ name: String) throws -> CashFlowLineResult {
        try #require((m.incomeLines + m.expenseLines).first { $0.name == name })
    }

    private static func near(_ a: Double?, _ b: Double) -> Bool {
        guard let a else { return false }
        return abs(a - b) < 0.005
    }

    private static func monthEnd(_ e: Escenario) throws -> MonthEndBalanceLogic.Result {
        try #require(MonthEndBalanceLogic.compute(
            accounts: e.accounts, transactions: e.transactions, scheduledPayments: [], currencyCode: "PEN",
            includeGroups: true, adjustment: .none, converter: Conv(), context: e.context, now: now,
            calendar: calendar
        ))
    }

    // MARK: - 1. Una sola historia del mes

    /// Antes: «Al 30» 12,905, «Este mes te quedaría» 1,700 y el acumulado 15,217.50 en la misma pantalla. Ahora el mes
    /// empieza con el saldo real del 1, suma su neto y termina en la cifra de «Al 30».
    @Test func hallazgo1_elMesEnCursoCuentaUnaSolaHistoria() throws {
        let e = try Self.escenarioA()
        let nov = try Self.mes(Self.proyeccion(e), "2026-11")
        #expect(Self.near(nov.openingBalance, 11_375))
        #expect(Self.near(nov.accumulatedBalance, 12_905))
        #expect(Self.near(nov.netFlow, 1_530))
        #expect(Self.near((nov.openingBalance ?? 0) + nov.netFlow, nov.accumulatedBalance ?? -1))
    }

    // MARK: - 2. El saldo inicial manual ya no manda

    @Test func hallazgo2_elSaldoInicialDelPlanNoSeDeslizaAlMesEnCurso() throws {
        let e = try Self.escenarioA(startingBalance: 99_999)
        let p = Self.proyeccion(e)
        let nov = try Self.mes(p, "2026-11")
        #expect(Self.near(p.startingBalance, 11_375))
        #expect(Self.near(nov.accumulatedBalance, 12_905))
        #expect(Self.near(try Self.mes(p, "2026-09").accumulatedBalance, 10_375))
    }

    // MARK: - 3. Sin doble conteo en el mes de inicio

    @Test func hallazgo3_elCierreDelMesEnCursoEsElSaldoDeHoyMasLoQueFalta() throws {
        let e = try Self.escenarioA()
        let nov = try Self.mes(Self.proyeccion(e), "2026-11")
        #expect(Self.near(nov.realIncome, 4_850))
        #expect(Self.near(nov.realExpense, 2_707.5))
        #expect(Self.near(nov.incomeLeft, 0))
        #expect(Self.near(nov.expenseLeft, 612.5))
        // 13,517.50 de hoy − 612.50 que falta; antes 15,217.50 (13,517.50 + el neto planeado del mes entero).
        #expect(Self.near(nov.accumulatedBalance, 13_517.5 - 612.5))
    }

    // MARK: - 4. Los totales son lo real, también excedido y cerrado

    @Test func hallazgo4_losTotalesSonLoRealEnMesesCerradosYLineasExcedidas() throws {
        let e = try Self.escenarioA()
        let p = Self.proyeccion(e)
        let oct = try Self.mes(p, "2026-10")
        #expect(Self.near(oct.totalExpense, 3_000))      // 2,900 de líneas + 100 sin categoría; antes, 2,900 planeado
        #expect(Self.near(oct.totalIncome, 4_000))
        let nov = try Self.mes(p, "2026-11")
        let comida = try Self.linea(nov, "Comida")
        #expect(comida.isExceeded)
        #expect(Self.near(comida.leftAmount, 0))
        #expect(Self.near(comida.expectedAmount, 1_220))  // lo real y lo fechado, no los 900 planeados
        #expect(Self.near(nov.totalExpense, 3_320))       // antes, 2,900
    }

    // MARK: - 5. Sin categoría existe

    @Test func hallazgo5_loSinCategoriaEntraEnLosTotalesYEnOtros() throws {
        let e = try Self.escenarioA()
        let nov = try Self.mes(Self.proyeccion(e), "2026-11")
        let otrosGasto = try #require(nov.otherExpenses)
        let otrosIngreso = try #require(nov.otherIncome)
        #expect(Self.near(otrosGasto.realAmount, 100))
        #expect(otrosGasto.categoryBreakdown.contains { $0.categoryName == L10n.Report.uncategorized && Self.near($0.amount, 100) })
        #expect(Self.near(otrosIngreso.realAmount, 850))  // 600 freelance + 250 sin categoría
        #expect(otrosIngreso.categoryBreakdown.contains { $0.categoryName == L10n.Report.uncategorized && Self.near($0.amount, 250) })
        #expect(Self.near(nov.totalIncome, 4_850))
    }

    // MARK: - 6. Con signo

    @Test func hallazgo6_unaDevolucionRestaDeSuLinea() throws {
        let e = try Self.escenarioA()
        let comida = try Self.linea(try Self.mes(Self.proyeccion(e), "2026-11"), "Comida")
        #expect(Self.near(comida.realAmount, 1_020))      // 400 + 400 + 300 − 80; antes 1,380
    }

    // MARK: - 7. Lo fechado no es real todavía

    @Test func hallazgo7_loFechadoDespuesDeHoyNoEsReal() throws {
        let e = try Self.escenarioA()
        let comida = try Self.linea(try Self.mes(Self.proyeccion(e), "2026-11"), "Comida")
        #expect(Self.near(comida.datedAmount, 200))
        #expect(!Self.near(comida.realAmount, 1_220))
    }

    // MARK: - 8. El promedio no mira el mes a medias

    @Test func hallazgo8_elPromedioDeLosMesesQueVienenNoMiraElMesAMedias() throws {
        let e = try Self.escenarioA()
        let dic = try Self.mes(Self.proyeccion(e), "2026-12")
        #expect(Self.near(try Self.linea(dic, "Comida").plannedAmount, 900))       // antes 980
        #expect(Self.near(try Self.linea(dic, "Transporte").plannedAmount, 200))   // antes 181.25
    }

    // MARK: - 9. El límite no se mueve solo

    @Test func hallazgo9_elLimiteEsElMismoEnElMesEnCursoYEnLosQueVienen() throws {
        let e = try Self.escenarioA()
        let p = Self.proyeccion(e)
        for name in ["Comida", "Transporte", "Ocio", "Vivienda"] {
            let planned = try p.months.filter { !$0.isPast }.map { try Self.linea($0, name).plannedAmount }
            #expect(Set(planned.map { ($0 * 100).rounded() }).count == 1, "\(name): \(planned)")
        }
    }

    // MARK: - 10. «Falta salir» no castiga de más

    /// El escenario 2 de la sonda: línea por subcategoría (Supermercado, 600) con 500 anotados en la categoría madre,
    /// y un gasto puntual de 2,400 sin línea hace 45 días. Antes faltaba salir 1,066.67; lo real son 100.
    @Test func hallazgo10_loDeLaCategoriaMadreYElGastoPuntualNoSeCuentanDosVeces() throws {
        let context = try makeTestContext()
        let bank = Self.cuenta(context, "Banco", "PEN")
        let sueldo = Self.categoria(context, "Sueldo", income: true)
        let comida = Self.categoria(context, "Comida")
        let hogar = Self.categoria(context, "Hogar")
        let supermercado = Subcategory(name: "Supermercado", category: comida)
        context.insert(supermercado)
        var all: [TransactionItem] = []
        func tx(_ amount: Double, _ date: Date, _ category: YalaCategory?, sub: Subcategory? = nil, adj: String? = nil) {
            let item = TransactionItem(date: date, amount: amount, currencyCode: "PEN", category: category,
                                       subcategory: sub, account: bank, amountInPreferredCurrency: amount,
                                       preferredCurrencyCode: "PEN")
            item.balanceAdjustmentType = adj
            context.insert(item)
            all.append(item)
        }
        tx(3_000, Self.date(2026, 4, 1), nil, adj: InitialBalanceService.typeInitialBalance)
        for month in 5...10 {
            tx(4_000, Self.date(2026, month, 1), sueldo)
            tx(-600, Self.date(2026, month, 5), comida, sub: supermercado)
        }
        tx(-2_400, Self.calendar.date(byAdding: .day, value: -45, to: Self.now) ?? Self.now, hogar)
        tx(4_000, Self.date(2026, 11, 1), sueldo)
        tx(-500, Self.date(2026, 11, 4), comida)            // súper anotado sin subcategoría
        let plan = CashFlowPlan(name: "", startingBalance: 0)
        context.insert(plan)
        let l1 = CashFlowLine(name: "Sueldo", isIncome: true, estimationMethod: .manual, manualAmount: 4_000,
                              category: sueldo)
        let l2 = CashFlowLine(name: "Supermercado", isIncome: false, sortOrder: 1, estimationMethod: .manual,
                              manualAmount: 600, category: comida, subcategory: supermercado)
        for line in [l1, l2] { context.insert(line); line.plan = plan }
        try context.save()

        let projection = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [l1, l2], transactions: all, allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 1, currencyCode: "PEN", converter: Conv(),
            balance: FlujoMotorMesEntrada.FuenteSaldo(accounts: [bank], transactions: all, currencyCode: "PEN",
                                                      converter: Conv()),
            occurrences: [], now: Self.now, calendar: Self.calendar
        )
        let nov = try Self.mes(projection, "2026-11")
        #expect(Self.near(nov.expenseLeft, 100))
        #expect(Self.near(try Self.linea(nov, "Supermercado").leftAmount, 100))
        let grupo = try #require(nov.expenseGroups.first { $0.categoryID == comida.persistentModelID })
        #expect(Self.near(grupo.unassignedAmount, 500))
        #expect(Self.near(grupo.expectedAmount, 600))
        #expect(Self.near(nov.otherExpenses?.leftAmount, 0))   // la mediana no ve el gasto puntual

        // Y es la cifra de «Al 30» del Panel.
        let end = try #require(MonthEndBalanceLogic.compute(
            accounts: [bank], transactions: all, scheduledPayments: [], currencyCode: "PEN", includeGroups: true,
            adjustment: .none, converter: Conv(), context: context, now: Self.now, calendar: Self.calendar
        ))
        #expect(Self.near(end.expenseLeft, 100))               // antes 1,066.67
        #expect(Self.near(end.closing, nov.accumulatedBalance ?? -1))
    }

    // MARK: - 11. Los meses que vienen proyectan «otros»

    @Test func hallazgo11_losMesesQueVienenProyectanOtrosPorLaMediana() throws {
        let e = try Self.escenarioA()
        let p = Self.proyeccion(e)
        let dic = try Self.mes(p, "2026-12")
        let otros = try #require(dic.otherExpenses)
        #expect(Self.near(otros.plannedAmount, 100))
        #expect(otros.realAmount == nil)
        #expect(dic.otherIncome.map { Self.near($0.plannedAmount, 0) } ?? true)   // los ingresos sin línea no se proyectan
        // Diciembre: 1,500 + 900 + 200 + 300 (150 ya fechados) + 100 de otros; ingresos, el sueldo.
        #expect(Self.near(dic.totalExpense, 3_000))
        #expect(Self.near(dic.totalIncome, 4_000))
        #expect(Self.near(dic.accumulatedBalance, 12_905 + 1_000))
    }

    /// El ticket `projected-flow-with-plan-counts-a-future-dated-row-twice-in-a-future-month`: el ocio fechado en
    /// diciembre (150) entra una vez, dentro de su límite de 300.
    @Test func loFechadoEnUnMesQueVieneEntraUnaVezDentroDeSuLinea() throws {
        let e = try Self.escenarioA()
        let ocio = try Self.linea(try Self.mes(Self.proyeccion(e), "2026-12"), "Ocio")
        #expect(Self.near(ocio.datedAmount, 150))
        #expect(Self.near(ocio.leftAmount, 150))
        #expect(Self.near(ocio.expectedAmount, 300))
    }

    // MARK: - Paridad con «Al 30» del Panel

    @Test func elCierreDelMesEnCursoEsLaCifraDeAl30DelPanel() throws {
        let e = try Self.escenarioA()
        let nov = try Self.mes(Self.proyeccion(e), "2026-11")
        let end = try Self.monthEnd(e)
        #expect(Self.near(end.today, 13_517.5))
        #expect(Self.near(end.incomeLeft, nov.incomeLeft))
        #expect(Self.near(end.expenseLeft, nov.expenseLeft))
        #expect(Self.near(end.closing, nov.accumulatedBalance ?? -1))
        #expect(end.source == .plan)
    }

    // MARK: - Subcategoría como id base

    /// Una línea por categoría trae siempre lo real de cada subcategoría y de lo anotado sin subcategoría.
    @Test func unaLineaPorCategoriaTraeSuDesglosePorSubcategoria() throws {
        let e = try Self.escenarioA()
        let comida = try #require(e.categories["Comida"])
        let rapida = Subcategory(name: "Rápida", category: comida)
        e.context.insert(rapida)
        let item = TransactionItem(date: Self.date(2026, 11, 12), amount: -45, currencyCode: "PEN", category: comida,
                                   subcategory: rapida, account: e.accounts[0], amountInPreferredCurrency: -45,
                                   preferredCurrencyCode: "PEN")
        e.context.insert(item)
        try e.context.save()
        let escenario = Escenario(context: e.context, plan: e.plan, accounts: e.accounts,
                                  transactions: e.transactions + [item], lines: e.lines, categories: e.categories)
        let linea = try Self.linea(try Self.mes(Self.proyeccion(escenario), "2026-11"), "Comida")
        let breakdown = try #require(linea.subcategoryBreakdown)
        #expect(breakdown.contains { $0.subcategoryName == "Rápida" && Self.near($0.realAmount, 45) })
        #expect(breakdown.contains { $0.subcategoryName == L10n.Report.noSubcategory && Self.near($0.realAmount, 1_020) })
        #expect(Self.near(linea.realAmount, 1_065))
    }

    // MARK: - La mediana

    @Test func laMedianaDeOtrosEmpiezaEnElPrimerMesConMovimientos() {
        let calendar = Self.calendar
        let current = Self.date(2026, 11, 1, hour: 0)
        let movimientos = [9, 10].map { month in
            FlujoMotorMes.Movimiento(
                mes: Self.date(2026, month, 1, hour: 0), importe: 300, esIngreso: false, categoriaID: nil,
                subcategoriaID: nil, categoria: nil, pagoID: nil, esFechado: false
            )
        }
        let entrada = FlujoMotorMes.Entrada(
            meses: [current], mesEnCurso: current, quedanDiasEnElMes: true, lineas: [], limite: { _, _ in 0 },
            movimientos: movimientos, pendientes: [], calendar: calendar
        )
        // Dos meses de historia con 300: la mediana es 300, no la de seis meses con cuatro ceros.
        #expect(FlujoMotorMes.medianaDeOtros(entrada) == 300)
        #expect(FlujoMotorMes.mediana([0, 0, 0, 0, 0, 2_400]) == 0)
        #expect(FlujoMotorMes.mediana([100, 300]) == 200)
    }

    // MARK: - Review adversarial (18-nov): lo que encontró y quedó fijado

    private static func mov(
        _ importe: Double, mes: Date, ingreso: Bool = false, cat: PersistentIdentifier? = nil,
        sub: PersistentIdentifier? = nil, pago: UUID? = nil, fechado: Bool = false
    ) -> FlujoMotorMes.Movimiento {
        FlujoMotorMes.Movimiento(mes: mes, importe: importe, esIngreso: ingreso, categoriaID: cat, subcategoriaID: sub,
                                 categoria: nil, pagoID: pago, esFechado: fechado)
    }

    private static func motor(
        lineas: [FlujoMotorMes.Linea], limites: [UUID: Double], movimientos: [FlujoMotorMes.Movimiento] = [],
        pendientes: [FlujoMotorMes.Pendiente] = []
    ) -> FlujoMotorMes.Mes? {
        let nov = date(2026, 11, 1, hour: 0)
        return FlujoMotorMes.calcular(FlujoMotorMes.Entrada(
            meses: [nov], mesEnCurso: nov, quedanDiasEnElMes: true, lineas: lineas,
            limite: { id, _ in limites[id] ?? 0 }, movimientos: movimientos, pendientes: pendientes,
            calendar: calendar
        )).first
    }

    /// Alta de dos lentes: una línea por categoría sumaba en su promedio lo de su subcategoría con línea propia, y el
    /// mes proyectaba ese gasto dos veces.
    @Test func review_elLimiteDeUnaLineaPorCategoriaNoCuentaLoDeSusSubcategoriasConLinea() throws {
        let context = try makeTestContext()
        let bank = Self.cuenta(context, "Banco", "PEN")
        let comida = Self.categoria(context, "Comida")
        let restaurantes = Subcategory(name: "Restaurantes", category: comida)
        context.insert(restaurantes)
        var all: [TransactionItem] = []
        func tx(_ amount: Double, _ date: Date, sub: Subcategory? = nil) {
            let item = TransactionItem(date: date, amount: amount, currencyCode: "PEN", category: comida,
                                       subcategory: sub, account: bank, amountInPreferredCurrency: amount,
                                       preferredCurrencyCode: "PEN")
            context.insert(item)
            all.append(item)
        }
        for month in 5...10 {
            tx(-600, Self.date(2026, month, 5))
            tx(-400, Self.date(2026, month, 9), sub: restaurantes)
        }
        tx(-360, Self.date(2026, 11, 5))
        tx(-240, Self.date(2026, 11, 9), sub: restaurantes)
        let plan = CashFlowPlan(name: "", startingBalance: 0)
        context.insert(plan)
        let porCategoria = CashFlowLine(name: "Comida", sortOrder: 0, estimationMethod: .average6m, category: comida)
        let porSub = CashFlowLine(name: "Restaurantes", sortOrder: 1, estimationMethod: .average6m, category: comida,
                                  subcategory: restaurantes)
        for line in [porCategoria, porSub] { context.insert(line); line.plan = plan }
        try context.save()
        let p = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [porCategoria, porSub], transactions: all, allExpenseCategories: [],
            scheduledPayments: [], monthsBack: 0, monthsAhead: 0, currencyCode: "PEN", converter: Conv(),
            occurrences: [], now: Self.now, calendar: Self.calendar
        )
        let nov = try Self.mes(p, "2026-11")
        #expect(Self.near(try Self.linea(nov, "Comida").plannedAmount, 600))       // antes 1,000
        #expect(Self.near(try Self.linea(nov, "Restaurantes").plannedAmount, 400))
        #expect(Self.near(nov.totalExpense, 1_000))                               // antes 1,400
        let breakdown = try #require(try Self.linea(nov, "Comida").subcategoryBreakdown)
        #expect(!breakdown.contains { $0.subcategoryName == "Restaurantes" })    // es de su línea
    }

    /// Una línea de pago programado sigue su límite (con su ajuste): lo pendiente cuenta y lo que falta es lo de más.
    /// Sin pendientes (pago de grupo, pausado, sin cuenta) proyecta su límite, no cero.
    @Test func review_unaLineaDePagoProgramadoRespetaSuLimiteYSuAjuste() {
        let pago = UUID()
        let linea = FlujoMotorMes.Linea(id: UUID(), esIngreso: false, categoriaID: nil, subcategoriaID: nil, pagoID: pago)
        let nov = Self.date(2026, 11, 1, hour: 0)
        let pendiente = FlujoMotorMes.Pendiente(mes: nov, pagoID: pago, categoriaID: nil, subcategoriaID: nil,
                                                esIngreso: false, importe: 300)
        let conAjuste = Self.motor(lineas: [linea], limites: [linea.id: 500], pendientes: [pendiente])
        #expect(conAjuste?.gastos.lineas[linea.id]?.falta == 200)
        #expect(conAjuste?.gastos.total == 500)
        let sinPendiente = Self.motor(lineas: [linea], limites: [linea.id: 300])
        #expect(sinPendiente?.gastos.total == 300)
    }

    /// Dos líneas para lo mismo: la segunda no proyecta otra vez el mismo gasto.
    @Test func review_unaLineaRepetidaNoProyectaDosVeces() throws {
        let context = try makeTestContext()
        let cat = Self.categoria(context, "Restaurantes")
        try context.save()
        let a = FlujoMotorMes.Linea(id: UUID(), esIngreso: false, categoriaID: cat.persistentModelID,
                                    subcategoriaID: nil, pagoID: nil)
        let b = FlujoMotorMes.Linea(id: UUID(), esIngreso: false, categoriaID: cat.persistentModelID,
                                    subcategoriaID: nil, pagoID: nil)
        let nov = Self.date(2026, 11, 1, hour: 0)
        let mes = Self.motor(lineas: [a, b], limites: [a.id: 300, b.id: 300],
                             movimientos: [Self.mov(250, mes: nov, cat: cat.persistentModelID)])
        #expect(mes?.gastos.total == 300)     // antes 600
        #expect(mes?.gastos.lineas[b.id]?.falta == 0)
    }

    /// Una línea libre (sin categoría) y «otros» por la mediana son el mismo gasto: cuenta el mayor.
    @Test func review_unaLineaLibreYOtrosNoSeSuman() {
        let libre = FlujoMotorMes.Linea(id: UUID(), esIngreso: false, categoriaID: nil, subcategoriaID: nil, pagoID: nil)
        let nov = Self.date(2026, 11, 1, hour: 0)
        let historia = (5...10).map { Self.mov(100, mes: Self.date(2026, $0, 1, hour: 0)) }
        let mes = FlujoMotorMes.calcular(FlujoMotorMes.Entrada(
            meses: [nov], mesEnCurso: nov, quedanDiasEnElMes: true, lineas: [libre],
            limite: { _, _ in 300 }, movimientos: historia, pendientes: [], calendar: Self.calendar
        )).first
        #expect(mes?.gastos.total == 300)     // antes 300 + 100
    }

    /// Un movimiento enlazado a un pago de gasto que llega como ingreso (un reembolso) no se pierde: va a su lado.
    @Test func review_unMovimientoDeOtroLadoQueSuPagoNoSePierde() {
        let pago = UUID()
        let linea = FlujoMotorMes.Linea(id: UUID(), esIngreso: false, categoriaID: nil, subcategoriaID: nil, pagoID: pago)
        let nov = Self.date(2026, 11, 1, hour: 0)
        let mes = Self.motor(lineas: [linea], limites: [linea.id: 0],
                             movimientos: [Self.mov(40, mes: nov, ingreso: true, pago: pago)])
        #expect(mes?.ingresos.real == 40)
    }

    /// Lo pendiente en la categoría madre no descuenta de las líneas por subcategoría: solo lo anotado.
    @Test func review_unPagoPendienteEnLaCategoriaMadreNoAbsorbe() throws {
        let context = try makeTestContext()
        let comida = Self.categoria(context, "Comida")
        let super_ = Subcategory(name: "Súper", category: comida)
        context.insert(super_)
        try context.save()
        let linea = FlujoMotorMes.Linea(id: UUID(), esIngreso: false, categoriaID: comida.persistentModelID,
                                        subcategoriaID: super_.persistentModelID, pagoID: nil)
        let nov = Self.date(2026, 11, 1, hour: 0)
        let pendiente = FlujoMotorMes.Pendiente(mes: nov, pagoID: UUID(), categoriaID: comida.persistentModelID,
                                                subcategoriaID: nil, esIngreso: false, importe: 200)
        let mes = Self.motor(lineas: [linea], limites: [linea.id: 600], pendientes: [pendiente])
        #expect(mes?.gastos.lineas[linea.id]?.falta == 600)
        #expect(mes?.gastos.total == 800)
    }

    /// Llevar justo el límite ya es excedida (P2: real + fechado ≥ límite); un límite 0 con gasto, también.
    @Test func review_excedidaEsLlegarAlLimite() throws {
        let context = try makeTestContext()
        let cat = Self.categoria(context, "Ocio")
        try context.save()
        let linea = FlujoMotorMes.Linea(id: UUID(), esIngreso: false, categoriaID: cat.persistentModelID,
                                        subcategoriaID: nil, pagoID: nil)
        let nov = Self.date(2026, 11, 1, hour: 0)
        let justo = Self.motor(lineas: [linea], limites: [linea.id: 300],
                               movimientos: [Self.mov(300, mes: nov, cat: cat.persistentModelID)])
        #expect(justo?.gastos.lineas[linea.id]?.excedida == true)
        let sinLimite = Self.motor(lineas: [linea], limites: [linea.id: 0],
                                   movimientos: [Self.mov(50, mes: nov, cat: cat.persistentModelID)])
        #expect(sinLimite?.gastos.lineas[linea.id]?.excedida == true)
        let nada = Self.motor(lineas: [linea], limites: [linea.id: 0])
        #expect(nada?.gastos.lineas[linea.id]?.excedida == false)
    }

    /// Alta de la lente de paridad: con un plan sin líneas, el Panel iba al ritmo y el flujo de caja a la mediana.
    @Test func review_unPlanSinLineasDaLaMismaCifraDeAl30() throws {
        let e = try Self.escenarioA()
        for line in e.plan.lines ?? [] { e.context.delete(line) }
        try e.context.save()
        let nov = try Self.mes(Self.proyeccion(e), "2026-11")
        let end = try Self.monthEnd(e)
        #expect(Self.near(end.closing, nov.accumulatedBalance ?? -1))
        #expect(end.source == .plan)
    }
}
