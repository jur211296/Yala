//
//  FlujoDetalleLineaLogicaTests.swift
//  YalaTests
//
//  S3 del replanteo del flujo de caja (18-nov-2026): el detalle de una línea cuenta lo mismo que su cifra. Los registros
//  salen del reparto del motor (un solo dueño por movimiento) y suman lo real de la línea; los seis meses dan lo mismo
//  que la proyección en los meses que ésta tiene; el ritmo, el aviso de la categoría madre y el período de «Ver en
//  Registros». El «ahora» es fijo, el 18 de noviembre de 2026 en Lima.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · detalle de línea (S3 del replanteo)", .serialized)
struct FlujoDetalleLineaLogicaTests {

    // MARK: - Fixture

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private static let now = date(2026, 11, 18)

    private struct Conv: CurrencyConverting {
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
    }

    private struct Escenario {
        let context: ModelContext
        let plan: CashFlowPlan
        let bank: Account
        let transactions: [TransactionItem]
        let supermercado: CashFlowLine
        let comida: CashFlowLine
        let comidaCategoria: YalaCategory
    }

    /// Comida con dos subcategorías: «Supermercado» tiene línea propia y la categoría también («Comida»). Seis meses de
    /// historia y noviembre a medias: una devolución en el súper, lo anotado en la categoría y en «Restaurantes» (sin
    /// línea: es de «Comida»), un fechado el 28, un ajuste de saldo en el súper (fuera) y algo de otra categoría.
    private static func escenario() throws -> Escenario {
        let context = try makeTestContext()
        let bank = Account(name: "Banco", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(bank)
        let comida = YalaCategory(name: "Comida", colorHex: "#000000", isIncome: false)
        let ocio = YalaCategory(name: "Ocio", colorHex: "#000000", isIncome: false)
        context.insert(comida)
        context.insert(ocio)
        let supermercado = Subcategory(name: "Supermercado", category: comida)
        let restaurantes = Subcategory(name: "Restaurantes", category: comida)
        context.insert(supermercado)
        context.insert(restaurantes)
        var all: [TransactionItem] = []
        func tx(_ amount: Double, _ date: Date, _ category: YalaCategory?, sub: Subcategory? = nil, adj: String? = nil) {
            let item = TransactionItem(date: date, amount: amount, currencyCode: "PEN", category: category,
                                       subcategory: sub, account: bank, amountInPreferredCurrency: amount,
                                       preferredCurrencyCode: "PEN")
            item.balanceAdjustmentType = adj
            context.insert(item)
            all.append(item)
        }
        tx(10_000, date(2026, 4, 1), nil, adj: InitialBalanceService.typeInitialBalance)
        for month in 5...10 {
            tx(-400 - Double(month) * 10, date(2026, month, 5), comida, sub: supermercado)
            tx(-100, date(2026, month, 12), comida)
        }
        tx(-300, date(2026, 11, 2), comida, sub: supermercado)
        tx(-200, date(2026, 11, 6), comida, sub: supermercado)
        tx(50, date(2026, 11, 9), comida, sub: supermercado)          // devolución
        tx(-100, date(2026, 11, 4), comida)                           // en la categoría
        tx(-80, date(2026, 11, 5), comida, sub: restaurantes)          // subcategoría sin línea
        tx(-40, date(2026, 11, 28), comida, sub: supermercado)        // fechado
        tx(-999, date(2026, 11, 3), comida, sub: supermercado, adj: InitialBalanceService.typeAdjustment)
        tx(-70, date(2026, 11, 7), ocio)

        let plan = CashFlowPlan(name: "", startingBalance: 0)
        context.insert(plan)
        let lineaSuper = CashFlowLine(name: "Supermercado", isIncome: false, sortOrder: 0, estimationMethod: .average6m,
                                      category: comida, subcategory: supermercado)
        let lineaComida = CashFlowLine(name: "Comida", isIncome: false, sortOrder: 1, estimationMethod: .manual,
                                       manualAmount: 150, category: comida)
        for line in [lineaSuper, lineaComida] { context.insert(line); line.plan = plan }
        try context.save()
        return Escenario(context: context, plan: plan, bank: bank, transactions: all, supermercado: lineaSuper,
                         comida: lineaComida, comidaCategoria: comida)
    }

    private static func proyeccion(_ e: Escenario) -> CashFlowProjection {
        CashFlowProjectionCalculator.calculate(
            plan: e.plan, lines: e.plan.lines ?? [], transactions: e.transactions, allExpenseCategories: [],
            scheduledPayments: [], monthsBack: 3, monthsAhead: 2, currencyCode: "PEN", converter: Conv(),
            balance: FlujoMotorMesEntrada.FuenteSaldo(accounts: [e.bank], transactions: e.transactions,
                                                      currencyCode: "PEN", converter: Conv()),
            occurrences: [], now: now, calendar: calendar
        )
    }

    private static func registros(_ e: Escenario, _ line: CashFlowLine, mes: Date? = nil)
        -> [FlujoDetalleLineaLogica.Registro] {
        FlujoDetalleLineaLogica.registros(
            de: line.id, mes: mes ?? date(2026, 11, 1),
            lineas: FlujoDetalleLineaLogica.ordenDelPlan(e.plan.lines ?? []).map { FlujoMotorMesEntrada.linea($0) },
            transactions: e.transactions, currencyCode: "PEN", adjustment: .none, converter: Conv(), now: now,
            calendar: calendar
        )
    }

    private static func resultado(_ p: CashFlowProjection, _ key: String, _ name: String) throws -> CashFlowLineResult {
        let month = try #require(p.months.first { $0.monthKey == key })
        return try #require((month.incomeLines + month.expenseLines).first { $0.name == name })
    }

    private static func near(_ a: Double?, _ b: Double) -> Bool {
        guard let a else { return false }
        return abs(a - b) < 0.005
    }

    // MARK: - Registros

    /// Todos los del mes (antes salían 5), con la devolución restando, el fechado aparte y sin el ajuste de saldo: lo
    /// real que suman es lo real de la línea en la proyección.
    @Test func losRegistrosDeLaLineaSumanSuCifra() throws {
        let e = try Self.escenario()
        let lista = Self.registros(e, e.supermercado)
        #expect(lista.count == 4)
        let real = lista.filter { !$0.esFechado }.reduce(0) { $0 + $1.importe }
        let fechado = lista.filter(\.esFechado).reduce(0) { $0 + $1.importe }
        #expect(Self.near(real, 450))                       // 300 + 200 − 50
        #expect(Self.near(fechado, 40))
        let lr = try Self.resultado(Self.proyeccion(e), "2026-11", "Supermercado")
        #expect(Self.near(lr.realAmount, real))
        #expect(Self.near(lr.datedAmount, fechado))
    }

    /// La línea por categoría se queda lo anotado en la categoría y en la subcategoría sin línea, nunca lo del súper,
    /// que tiene dueño propio. Filtrar por categoría a mano (lo de antes) contaba también lo del súper.
    @Test func laLineaPorCategoriaNoCuentaLoDeUnaSubcategoriaConLineaPropia() throws {
        let e = try Self.escenario()
        let lista = Self.registros(e, e.comida)
        #expect(lista.count == 2)
        #expect(Self.near(lista.reduce(0) { $0 + $1.importe }, 180))
        let lr = try Self.resultado(Self.proyeccion(e), "2026-11", "Comida")
        #expect(Self.near(lr.realAmount, 180))
    }

    @Test func losDiasVanDelMasRecienteAlMasAntiguo_yElFechadoSaleProgramado() throws {
        let e = try Self.escenario()
        let dias = FlujoDetalleLineaLogica.dias(Self.registros(e, e.supermercado), calendar: Self.calendar)
        #expect(dias.map { Self.calendar.component(.day, from: $0.fecha) } == [28, 9, 6, 2])
        #expect(dias.first?.esProgramado == true)
        #expect(dias.dropFirst().allSatisfy { !$0.esProgramado })
        #expect(Self.near(dias[1].total, -50))
    }

    @Test func unMesSinRegistrosDaUnaListaVacia() throws {
        let e = try Self.escenario()
        #expect(Self.registros(e, e.supermercado, mes: Self.date(2026, 12, 1)).isEmpty)
    }

    // MARK: - Seis meses

    /// Seis meses aunque el plan guarde tres atrás, y en los que la proyección tiene, la misma cifra y el mismo límite.
    @Test func seisMeses_cuadranConLaProyeccion() throws {
        let e = try Self.escenario()
        let meses = FlujoDetalleLineaLogica.seisMeses(
            line: e.supermercado, lineasPlan: e.plan.lines ?? [], transactions: e.transactions,
            historia: e.transactions, hasta: Self.now, currencyCode: "PEN", adjustment: .none, converter: Conv(),
            now: Self.now, calendar: Self.calendar
        )
        #expect(meses.map(\.monthKey) == ["2026-06", "2026-07", "2026-08", "2026-09", "2026-10", "2026-11"])
        #expect(meses.last?.esActual == true)
        #expect(Self.near(meses.first?.real, 460))
        let p = Self.proyeccion(e)
        for key in ["2026-08", "2026-09", "2026-10", "2026-11"] {
            let mes = try #require(meses.first { $0.monthKey == key })
            let lr = try Self.resultado(p, key, "Supermercado")
            #expect(Self.near(lr.realAmount, mes.real), "real de \(key)")
            #expect(Self.near(lr.plannedAmount, mes.limite), "límite de \(key)")
        }
    }

    /// Un mes que viene no pinta meses sin datos: los seis acaban en el mes en curso.
    @Test func seisMeses_deUnMesQueVieneAcabanEnElActual() throws {
        let e = try Self.escenario()
        let meses = FlujoDetalleLineaLogica.seisMeses(
            line: e.comida, lineasPlan: e.plan.lines ?? [], transactions: e.transactions, historia: e.transactions,
            hasta: Self.date(2027, 1, 1), currencyCode: "PEN", adjustment: .none, converter: Conv(), now: Self.now,
            calendar: Self.calendar
        )
        #expect(meses.last?.monthKey == "2026-11")
        #expect(meses.allSatisfy { Self.near($0.limite, 150) })
    }

    // MARK: - Ritmo

    @Test func ritmo_soloEnGastosDelMesEnCurso() {
        let base = (real: 300.0, limite: 900.0)
        #expect(FlujoDetalleLineaLogica.ritmo(
            real: base.real, limite: base.limite, isExceeded: false, esIngreso: true, esMesActual: true,
            realMasFechado: base.real, now: Self.now, calendar: Self.calendar) == .ninguno)
        #expect(FlujoDetalleLineaLogica.ritmo(
            real: base.real, limite: base.limite, isExceeded: false, esIngreso: false, esMesActual: false,
            realMasFechado: base.real, now: Self.now, calendar: Self.calendar) == .ninguno)
        #expect(FlujoDetalleLineaLogica.ritmo(
            real: 0, limite: base.limite, isExceeded: false, esIngreso: false, esMesActual: true,
            realMasFechado: 0, now: Self.now, calendar: Self.calendar) == .ninguno)
    }

    /// 18 de noviembre: 600 en 18 días son 1,000 a fin de mes (30 días), más que 900.
    @Test func ritmo_alRitmoDelMes() throws {
        func alRitmo(_ real: Double) throws -> (Double, Bool) {
            let ritmo = FlujoDetalleLineaLogica.ritmo(
                real: real, limite: 900, isExceeded: false, esIngreso: false, esMesActual: true,
                realMasFechado: real, now: Self.now, calendar: Self.calendar)
            guard case .alRitmo(let llegarias, let sePasa) = ritmo else {
                Issue.record("Sin ritmo con \(real)")
                return (0, false)
            }
            return (llegarias, sePasa)
        }
        let pasa = try alRitmo(600)
        #expect(Self.near(pasa.0, 1_000) && pasa.1)
        // Llegar justo al límite no es pasarse.
        let justo = try alRitmo(540)
        #expect(Self.near(justo.0, 900) && !justo.1)
    }

    /// Excedida (P2): cuenta lo real y lo fechado, y no proyecta más.
    @Test func ritmo_excedidaNoProyecta() {
        #expect(FlujoDetalleLineaLogica.ritmo(
            real: 950, limite: 900, isExceeded: true, esIngreso: false, esMesActual: true,
            realMasFechado: 1_020, now: Self.now, calendar: Self.calendar) == .excedida(porCuanto: 120))
    }

    // MARK: - Categoría madre

    /// Con la línea por categoría, lo anotado en la madre es de esa línea: no hay aviso. Sin ella, el grupo lo deja
    /// «sin subcategoría» y la línea del súper avisa.
    @Test func elAvisoDeLaMadreSaleSoloSiLoAnotadoNoTieneLinea() throws {
        let e = try Self.escenario()
        let p = Self.proyeccion(e)
        let nov = try #require(p.months.first { $0.monthKey == "2026-11" })
        #expect(FlujoDetalleLineaLogica.anotadoEnLaMadre(
            lineID: e.supermercado.id, esPorSubcategoria: true, grupos: nov.expenseGroups) == nil)

        e.comida.isEnabled = false
        try e.context.save()
        let sinCategoria = Self.proyeccion(e)
        let nov2 = try #require(sinCategoria.months.first { $0.monthKey == "2026-11" })
        let aviso = FlujoDetalleLineaLogica.anotadoEnLaMadre(
            lineID: e.supermercado.id, esPorSubcategoria: true, grupos: nov2.expenseGroups)
        #expect(Self.near(aviso, 100))
        #expect(FlujoDetalleLineaLogica.anotadoEnLaMadre(
            lineID: e.supermercado.id, esPorSubcategoria: false, grupos: nov2.expenseGroups) == nil)
    }

    // MARK: - Ver en Registros

    @Test func verEnRegistros_abreElPeriodoDelMes() throws {
        let actual = FlujoDetalleLineaLogica.periodoDeRegistros(mes: Self.date(2026, 11, 1), now: Self.now, calendar: Self.calendar)
        #expect(actual.period == .thisMonth && actual.range == nil)
        let pasado = FlujoDetalleLineaLogica.periodoDeRegistros(mes: Self.date(2026, 10, 1), now: Self.now, calendar: Self.calendar)
        #expect(pasado.period == .lastMonth && pasado.range == nil)
        let viejo = FlujoDetalleLineaLogica.periodoDeRegistros(mes: Self.date(2026, 6, 15), now: Self.now, calendar: Self.calendar)
        #expect(viejo.period == .custom)
        let range = try #require(viejo.range)
        #expect(range.start == Self.calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        // Cierra a las 23:59:59 del 30 de junio: el 1 de julio a medianoche no entra (`CLAUDE.md`, «Cálculos con fechas»).
        let julio = try #require(Self.calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))
        #expect(range.end == julio.addingTimeInterval(-1))
    }
}
