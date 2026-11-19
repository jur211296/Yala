//
//  FlujoAisladosPromedioTests.swift
//  YalaTests
//
//  Decisiones de Jürgen del 19-nov-2026 (encargo `2026-11-19-flujo-aislados-promedio-y-detalle-mes`):
//  - las líneas por promedio, último mes o tendencia dejan fuera los meses aislados (el ejemplo de Fitness con agosto y
//    octubre muy por encima del resto);
//  - los límites se mueven solos cada mes y solo «Monto fijo» deja un número quieto (con la migración de las líneas que
//    el P4 sembró como monto fijo);
//  - con plan, en los meses que vienen «otros» proyecta solo lo fijo, cada partida se puede apagar a futuro, y el total
//    de la hoja de no considerados es la suma de su lista.
//  El «ahora» es fijo: el 18 de noviembre de 2026 en Lima.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · aislados en las líneas, límites móviles y solo fijos a futuro", .serialized)
struct FlujoAisladosPromedioTests {

    // MARK: - Fixture

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private static func mes(_ year: Int, _ month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    private static let now = date(2026, 11, 18)
    private static let noviembre = mes(2026, 11)

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
        let fitness: CashFlowLine
        let transactions: [TransactionItem]
    }

    /// Fitness: 150 cada mes de mayo a noviembre, y dos compras grandes: 1,450 en agosto y 1,280 en octubre (agosto 1,600 y
    /// octubre 1,430). Fuera del plan: alquiler de 1,000 el día 5 de cada mes (fijo), comida de 300 a 700 en días
    /// distintos (variable) y un ingreso de sueldo de 5,000 el día 1. La línea de Fitness va por promedio de 6 meses.
    private static func escenario(method: EstimationMethod = .average6m, manualAmount: Double? = nil) throws -> Escenario {
        let context = try makeTestContext()
        let bank = Account(name: "Banco", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(bank)
        func cat(_ name: String, income: Bool = false) -> YalaCategory {
            let category = YalaCategory(name: name, colorHex: "#000000", isIncome: income)
            context.insert(category)
            return category
        }
        let fitnessCat = cat("Fitness")
        let vivienda = cat("Vivienda")
        let comida = cat("Comida")
        let sueldo = cat("Sueldo", income: true)
        var transactions: [TransactionItem] = []
        func tx(_ amount: Double, _ day: Date, _ category: YalaCategory) {
            let item = TransactionItem(date: day, amount: amount, currencyCode: "PEN", category: category)
            item.account = bank
            context.insert(item)
            transactions.append(item)
        }
        let comidas: [Double] = [300, 700, 450, 520, 380, 610]
        for (i, month) in (5...10).enumerated() {
            tx(-150, date(2026, month, 3), fitnessCat)
            tx(-1_000, date(2026, month, 5), vivienda)
            tx(-comidas[i], date(2026, month, 8 + i * 3), comida)
            tx(5_000, date(2026, month, 1), sueldo)
        }
        tx(-1_450, date(2026, 8, 14), fitnessCat)
        tx(-1_280, date(2026, 10, 9), fitnessCat)
        tx(-150, date(2026, 11, 3), fitnessCat)
        tx(-1_000, date(2026, 11, 5), vivienda)
        tx(5_000, date(2026, 11, 1), sueldo)
        tx(-200, date(2026, 11, 10), comida)

        let plan = CashFlowPlan(name: "")
        context.insert(plan)
        let fitness = CashFlowLine(
            name: "Fitness", isIncome: false, sortOrder: 0, estimationMethod: method, manualAmount: manualAmount,
            category: fitnessCat
        )
        context.insert(fitness)
        fitness.plan = plan
        try context.save()
        return Escenario(context: context, plan: plan, fitness: fitness, transactions: transactions)
    }

    private static func projection(_ e: Escenario, excluded: Set<String> = []) -> CashFlowProjection {
        CashFlowProjectionCalculator.calculate(
            plan: e.plan, lines: [e.fitness], transactions: e.transactions, allExpenseCategories: [],
            scheduledPayments: [], monthsBack: 6, monthsAhead: 2, currencyCode: "PEN", converter: Conv(),
            excludedFutureFixed: excluded, now: now, calendar: calendar
        )
    }

    private static func index(_ e: Escenario, byLine: Bool) -> TransactionIndex {
        if byLine {
            return FlujoDetalleLineaLogica.indiceDelLimite(
                lineas: [FlujoMotorMesEntrada.linea(e.fitness)], historia: e.transactions, currencyCode: "PEN",
                adjustment: .none, converter: Conv(), now: now, calendar: calendar
            )
        }
        return TransactionIndex(transactions: e.transactions, currencyCode: "PEN", converter: Conv(), calendar: calendar)
    }

    private static func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

    // MARK: - Meses aislados

    @Test("Dos meses fuertes en una línea salen los dos: la mediana aguanta menos de la mitad de meses raros")
    func dosMesesFuertes_salenLosDos() {
        let meses = (5...10).map { Self.mes(2026, $0) }
        let totales = Dictionary(uniqueKeysWithValues: zip(meses, [150.0, 150, 150, 1_600, 150, 1_430]))
        #expect(FlujoProyeccionInteligente.mesesAislados(totales) == [Self.mes(2026, 8), Self.mes(2026, 10)])
    }

    @Test("La mitad de los meses altos no son aislados: es el nivel de la línea")
    func mitadAltos_noSonAislados() {
        let meses = (5...10).map { Self.mes(2026, $0) }
        let totales = Dictionary(uniqueKeysWithValues: zip(meses, [100.0, 100, 100, 1_500, 1_500, 1_500]))
        #expect(FlujoProyeccionInteligente.mesesAislados(totales).isEmpty)
    }

    @Test("Con menos de 3 meses con algo no se deja nada fuera (historia corta, conservador)")
    func historiaCorta_nadaFuera() {
        let totales = [Self.mes(2026, 9): 150.0, Self.mes(2026, 10): 1_500, Self.mes(2026, 8): 0]
        #expect(FlujoProyeccionInteligente.mesesAislados(totales).isEmpty)
    }

    // MARK: - El límite de la línea sin aislados

    @Test("Promedio 6 meses de Fitness: 150 sin agosto ni octubre (antes 605)")
    func promedio6_sinAislados() throws {
        let e = try Self.escenario()
        let idx = Self.index(e, byLine: true)
        let ahora = CashFlowProjectionCalculator.explainEstimate(
            method: .average6m, line: e.fitness, referenceDate: Self.noviembre, index: idx, calendar: Self.calendar
        )
        #expect(Self.near(ahora.amount, 150))
        #expect(ahora.isolatedMonths == [Self.mes(2026, 10), Self.mes(2026, 8)])
        #expect(ahora.usedMonths.count == 4)
        let antes = CashFlowProjectionCalculator.explainEstimate(
            method: .average6m, line: e.fitness, referenceDate: Self.noviembre, index: idx, calendar: Self.calendar,
            excludesIsolated: false
        )
        #expect(Self.near(antes.amount, (150.0 * 4 + 1_600 + 1_430) / 6))
    }

    @Test("Último mes: octubre fue aislado, así que usa septiembre")
    func ultimoMes_saltaElAislado() throws {
        let e = try Self.escenario(method: .lastMonth)
        let estimate = CashFlowProjectionCalculator.explainEstimate(
            method: .lastMonth, line: e.fitness, referenceDate: Self.noviembre, index: Self.index(e, byLine: true),
            calendar: Self.calendar
        )
        #expect(Self.near(estimate.amount, 150))
        #expect(estimate.usedMonths == [Self.mes(2026, 9)])
        #expect(estimate.isolatedMonths == [Self.mes(2026, 10)])
    }

    @Test("Tendencia: la regresión sin los meses aislados no sube por ellos")
    func tendencia_sinAislados() throws {
        let e = try Self.escenario(method: .trend)
        let estimate = CashFlowProjectionCalculator.explainEstimate(
            method: .trend, line: e.fitness, referenceDate: Self.noviembre, index: Self.index(e, byLine: true),
            calendar: Self.calendar
        )
        #expect(Self.near(estimate.amount, 150))
        #expect(Set(estimate.isolatedMonths) == [Self.mes(2026, 8), Self.mes(2026, 10)])
    }

    @Test("El límite del mes en curso del flujo de caja ya sale sin aislados, y el real del mes con aislado sigue contando")
    func proyeccion_limiteSinAislados_realIntacto() throws {
        let e = try Self.escenario()
        let months = Self.projection(e).months
        let nov = try #require(months.first { $0.isCurrent })
        let linea = try #require(nov.expenseLines.first { $0.lineID == e.fitness.id })
        #expect(Self.near(linea.plannedAmount, 150))
        let octubre = try #require(months.first { $0.monthKey == "2026-10" })
        let lineaOctubre = try #require(octubre.expenseLines.first { $0.lineID == e.fitness.id })
        #expect(Self.near(lineaOctubre.realAmount ?? 0, 1_430))
    }

    @Test("Límite móvil: cada mes pasado mira sus 6 meses anteriores; los que vienen, los del mes en curso")
    func limiteMovil_porMes() throws {
        let e = try Self.escenario()
        let months = Self.projection(e).months
        func limite(_ key: String) throws -> Double {
            let month = try #require(months.first { $0.monthKey == key })
            return try #require(month.expenseLines.first { $0.lineID == e.fitness.id }).plannedAmount
        }
        // Septiembre mira marzo-agosto: mayo, junio, julio y agosto con datos (4 meses, agosto aislado ⇒ 150).
        #expect(Self.near(try limite("2026-09"), 150))
        // Agosto mira febrero-julio: tres meses de 150.
        #expect(Self.near(try limite("2026-08"), 150))
        // Diciembre y enero usan la ventana del mes en curso (mayo-octubre, sin aislados).
        #expect(Self.near(try limite("2026-12"), 150))
        #expect(Self.near(try limite("2027-01"), 150))
    }

    // MARK: - «Cómo se calcula»

    @Test("«Cómo se calcula» nombra los meses que se dejaron fuera")
    func comoSeCalcula_nombraLosAislados() throws {
        let e = try Self.escenario()
        let historia = try #require(FlujoDetalleLineaLogica.historia(
            line: e.fitness, lineasPlan: [e.fitness], transactions: e.transactions, historia: e.transactions,
            hasta: Self.noviembre, currencyCode: "PEN", adjustment: .none, converter: Conv(), now: Self.now,
            calendar: Self.calendar
        ))
        let explicacion = try #require(historia.explicacion)
        #expect(explicacion.isolatedMonths.count == 2)
        let texto = try #require(FlujoDetalleLineaLogica.comoSeCalcula(
            line: e.fitness, explicacion: explicacion, cambioDesde: nil
        ))
        let lista = try #require(L10n.FlujoDetalleLinea.listaDeMeses(explicacion.isolatedMonths))
        #expect(texto.contains(lista))
        #expect(texto == L10n.FlujoDetalleLinea.comoPromedio(meses: 6, aislados: lista))
        // La gráfica marca agosto y octubre como aislados, y solo esos.
        #expect(historia.meses.filter(\.esAislado).map(\.monthKey) == ["2026-08", "2026-10"])
    }

    @Test("Monto fijo «desde» un mes se dice así, sin promedio")
    func comoSeCalcula_fijoDesde() throws {
        let e = try Self.escenario()
        let texto = FlujoDetalleLineaLogica.comoSeCalcula(
            line: e.fitness, explicacion: nil, cambioDesde: Self.noviembre
        )
        #expect(texto == L10n.FlujoDetalleLinea.comoFijoDesde(CashFlowMonthSummaryLogic.monthInSentence(Self.noviembre)))
    }

    // MARK: - Solo fijos en los meses que vienen

    @Test("Con plan, diciembre proyecta fuera de las líneas solo el alquiler fijo y el sueldo, nada de la mediana")
    func diciembre_soloFijos() throws {
        let e = try Self.escenario()
        let dic = try #require(Self.projection(e).months.first { $0.monthKey == "2026-12" })
        let gastos = try #require(dic.otherExpenses)
        #expect(gastos.isFixedOnly)
        #expect(Self.near(gastos.variableLeft, 0))
        #expect(Self.near(gastos.plannedAmount, 1_000))
        #expect(gastos.items.count == 1)
        #expect(gastos.items.first?.fixedItems.first.map { Self.near($0.monthlyAmount, 1_000) } == true)
        let ingresos = try #require(dic.otherIncome)
        #expect(Self.near(ingresos.plannedAmount, 5_000))
    }

    @Test("La comida, que cambia de monto y de día, no es fija y no se proyecta a futuro")
    func comidaVariable_noEsFija() throws {
        let e = try Self.escenario()
        let dic = try #require(Self.projection(e).months.first { $0.monthKey == "2026-12" })
        let nombres = dic.otherExpenses?.items.map(\.name) ?? []
        #expect(!nombres.contains("Comida"))
    }

    @Test("El mes en curso sigue como hoy: lo real y lo que falta de lo variable")
    func noviembre_comoHoy() throws {
        let e = try Self.escenario()
        let nov = try #require(Self.projection(e).months.first { $0.isCurrent })
        let gastos = try #require(nov.otherExpenses)
        #expect(!gastos.isFixedOnly)
        #expect(gastos.variableLeft > 0)
    }

    @Test("Apagar «Considerar a futuro» quita el alquiler de diciembre y enero, y la fila sigue en la hoja apagada")
    func considerarAFuturo_apagado() throws {
        let e = try Self.escenario()
        let base = try #require(Self.projection(e).months.first { $0.monthKey == "2026-12" }?.otherExpenses)
        let clave = try #require(base.items.first?.fixedItems.first?.stableKey)
        let months = Self.projection(e, excluded: [clave]).months
        for key in ["2026-12", "2027-01"] {
            let gastos = try #require(months.first { $0.monthKey == key }?.otherExpenses)
            #expect(Self.near(gastos.plannedAmount, 0))
            #expect(gastos.items.first?.fixedItems.first?.isConsideredInFuture == false)
        }
        // El mes en curso no cambia: la decisión es a futuro.
        let nov = try #require(months.first { $0.isCurrent }?.otherExpenses)
        let novBase = try #require(Self.projection(e).months.first { $0.isCurrent }?.otherExpenses)
        #expect(Self.near(nov.plannedAmount, novBase.plannedAmount))
    }

    @Test("La hoja de no considerados: en cada mes, la suma de su lista es su total (nunca vacía con total)")
    func totalYLista_mismaFuente() throws {
        let e = try Self.escenario()
        for month in Self.projection(e).months {
            for other in [month.otherExpenses, month.otherIncome].compactMap({ $0 }) {
                let suma = other.items.reduce(0) { $0 + $1.total } + other.variableLeft
                #expect(Self.near(suma, other.plannedAmount), "\(month.monthKey): \(suma) ≠ \(other.plannedAmount)")
                if abs(other.plannedAmount) > 0.005 {
                    #expect(!other.items.isEmpty || other.variableLeft > 0, "\(month.monthKey) con total y sin lista")
                }
            }
        }
    }

    // MARK: - Migración de las líneas sembradas por P4

    /// Un plan creado con una build de TestFlight que traía el P4 (en su ventana) y antes de este arranque.
    private static let creadoConP4 = date(2026, 11, 19, hour: 9)

    private static func migrar(_ e: Escenario, creado: Date? = nil) -> Int {
        e.plan.createdAt = creado ?? creadoConP4
        return FlujoLimitesMovilesMigracion.migrar(
            lines: [e.fitness], indice: index(e, byLine: false), mesEnCurso: noviembre, calendar: calendar,
            creadoAntesDe: date(2026, 11, 20)
        )
    }

    @Test("Una línea que el P4 sembró con su promedio vuelve a «Promedio 6 meses»")
    func migracion_sembradaVuelveAlPromedio() throws {
        let sembrado = (150.0 * 4 + 1_600 + 1_430) / 6
        let e = try Self.escenario(method: .manual, manualAmount: sembrado)
        let cambiadas = Self.migrar(e)
        #expect(cambiadas == 1)
        #expect(e.fitness.method == .average6m)
        #expect(e.fitness.manualAmount == nil)
    }

    @Test("Un monto fijo que escribió la persona se queda fijo")
    func migracion_fijoAPropositoSeQueda() throws {
        let e = try Self.escenario(method: .manual, manualAmount: 500)
        let cambiadas = Self.migrar(e)
        #expect(cambiadas == 0)
        #expect(e.fitness.method == .manual)
        #expect(e.fitness.manualAmount == 500)
    }

    @Test("Una línea sembrada con un cambio «desde» escrito encima no se toca")
    func migracion_conCambioDesde_seQueda() throws {
        let sembrado = (150.0 * 4 + 1_600 + 1_430) / 6
        let e = try Self.escenario(method: .manual, manualAmount: sembrado)
        e.fitness.amountChangesRaw = "2026-11=300"
        let cambiadas = Self.migrar(e)
        #expect(cambiadas == 0)
        #expect(e.fitness.method == .manual)
    }

    @Test("Un monto fijo de 2.2 igual a su promedio (plan de antes del P4) se queda fijo")
    func migracion_planDeAntesDelP4_seQueda() throws {
        let sembrado = (150.0 * 4 + 1_600 + 1_430) / 6
        let e = try Self.escenario(method: .manual, manualAmount: sembrado)
        #expect(Self.migrar(e, creado: Self.date(2026, 10, 2)) == 0)
        #expect(e.fitness.method == .manual)
    }

    @Test("Un plan creado en este arranque (Monto fijo relleno con el promedio) no se toca")
    func migracion_planDeEsteArranque_seQueda() throws {
        let sembrado = (150.0 * 4 + 1_600 + 1_430) / 6
        let e = try Self.escenario(method: .manual, manualAmount: sembrado)
        e.plan.createdAt = Self.date(2026, 11, 19, hour: 9)
        let cambiadas = FlujoLimitesMovilesMigracion.migrar(
            lines: [e.fitness], indice: Self.index(e, byLine: false), mesEnCurso: Self.noviembre,
            calendar: Self.calendar, creadoAntesDe: Self.date(2026, 11, 19, hour: 8)
        )
        #expect(cambiadas == 0)
    }

    @Test("La hora de arranque es la del proceso, anterior a ahora (no la de la primera consulta)")
    func arranque_esLaDelProceso() {
        let arranque = FlujoLimitesMovilesMigracion.arranque
        #expect(arranque < Date.now)
        #expect(arranque > Date.now.addingTimeInterval(-86_400))
        #expect(arranque != .distantPast)
    }

    // MARK: - Un pago de una línea no paga un gasto fijo de «otros»

    @Test("El seguro de 140 que se paga por su línea no descuenta del gasto fijo de 150 que vive en «otros»")
    func pagoDeLinea_noCubreUnFijoDeOtros() throws {
        let context = try makeTestContext()
        let seguros = YalaCategory(name: "Seguros", colorHex: "#000000", isIncome: false)
        context.insert(seguros)
        try context.save()
        let pago = UUID()
        let linea = FlujoMotorMes.Linea(
            id: UUID(), esIngreso: false, categoriaID: seguros.persistentModelID, subcategoriaID: nil, pagoID: pago
        )
        var movimientos: [FlujoMotorMes.Movimiento] = []
        for month in 5...11 {
            var gym = FlujoMotorMes.Movimiento(
                mes: Self.mes(2026, month), importe: 150, esIngreso: false, categoriaID: nil, subcategoriaID: nil,
                categoria: nil, pagoID: nil, esFechado: false
            )
            gym.dia = 12
            movimientos.append(gym)
        }
        let diciembre = Self.mes(2026, 12)
        var entrada = FlujoMotorMes.Entrada(
            meses: [Self.noviembre, diciembre], mesEnCurso: Self.noviembre, quedanDiasEnElMes: true, lineas: [linea],
            limite: { _, _ in 140 }, movimientos: movimientos,
            pendientes: [FlujoMotorMes.Pendiente(
                mes: diciembre, pagoID: pago, categoriaID: seguros.persistentModelID, subcategoriaID: nil,
                esIngreso: false, importe: 140
            )],
            calendar: Self.calendar
        )
        entrada.soloFijosEnMesesFuturos = true
        let dic = try #require(FlujoMotorMes.calcular(entrada).last)
        #expect(dic.gastos.otros.fijos.count == 1)
        #expect(Self.near(dic.gastos.otros.falta, 150))
        #expect(Self.near(dic.gastos.lineas[linea.id]?.pendiente ?? 0, 140))
    }

    // MARK: - Considerar a futuro (almacén)

    @Test("«Considerar a futuro» se guarda y se retira por clave")
    func almacen_consideraYRetira() {
        let defaults = makeIsolatedDefaults()
        #expect(FlujoFijosAFuturo.excluidos(defaults: defaults).isEmpty)
        FlujoFijosAFuturo.considerar("out|c:Vivienda", false, defaults: defaults)
        #expect(FlujoFijosAFuturo.excluidos(defaults: defaults) == ["out|c:Vivienda"])
        FlujoFijosAFuturo.considerar("out|c:Vivienda", true, defaults: defaults)
        #expect(FlujoFijosAFuturo.excluidos(defaults: defaults).isEmpty)
    }
}
