//
//  FotoWidgetsFilasParidadTests.swift
//  YalaTests / EficienciaFotoWidgetsArranque
//
//  Lote 7 de eficiencia (27-nov-2026). La foto de los widgets lee cada movimiento UNA vez (`FilaFotoWidget`) y parte sus
//  etapas largas en tramos con reloj (`RecorridoConReloj`). Sentry YALA-IOS-16 y el informe del iPhone 14
//  (`docs/qa/rendimiento-iphone14-2026-11-26/`): con 16.004 movimientos la foto ocupaba 5,7 s de hilo principal en el
//  arranque, en bloques de hasta 1,3 s.
//
//  Se fija: (1) los ocho resúmenes de período y la curva de saldo salen idénticos al código previo
//  (`ReferenciaFotoPreLote7`, copia congelada de `a5e93673f`) sobre un almacén con todo lo que cambia una cifra: dos
//  divisas, conversión guardada y sin guardar, devoluciones, sin categoría, subcategorías, ajustes de saldo, cuenta
//  excluida, cuenta archivada, movimientos sin cuenta y con fecha futura; (2) la foto por etapas sale igual que la de una
//  vez y se hace en más tramos que etapas; (3) la proyección por trozos da lo mismo que la de una vez.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
enum FotoFilasFixture {

    /// El «ahora» de las pruebas: una fecha fija (regla de `testing.md`), un martes a media mañana de junio de 2026.
    static let ahora = Date(timeIntervalSince1970: 1_781_000_000)

    static func seed(_ context: ModelContext, count: Int, now: Date) throws {
        let pen = Account(name: "Soles", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        let usd = Account(name: "Dólares", currencyCode: "USD", colorHex: "#111111", iconName: "x", type: "bank")
        let excluida = Account(name: "Excluida", currencyCode: "PEN", colorHex: "#222222", iconName: "x", type: "cash",
                               excludeFromStatistics: true)
        let archivada = Account(name: "Archivada", currencyCode: "PEN", colorHex: "#333333", iconName: "x", type: "cash",
                                isArchived: true)
        for cuenta in [pen, usd, excluida, archivada] { context.insert(cuenta) }
        let comida = Category(name: "Comida", colorHex: "#FF0000", isIncome: false)
        let casa = Category(name: "Casa", colorHex: "#0000FF", isIncome: false)
        let sueldo = Category(name: "Sueldo", colorHex: "#00FF00", isIncome: true)
        for categoria in [comida, casa, sueldo] { context.insert(categoria) }
        let restaurante = Subcategory(name: "Restaurante", category: comida)
        let mercado = Subcategory(name: "Mercado", category: comida)
        let luz = Subcategory(name: "Luz", category: casa)
        for subcategoria in [restaurante, mercado, luz] { context.insert(subcategoria) }

        for i in 0..<count {
            // De 9 días en el futuro hacia atrás, cada ~7 h: cubre los ocho períodos, el año pasado y la curva entera.
            let date = now.addingTimeInterval(9 * 86_400 - Double(i) * 25_000)
            let cuenta: Account?
            switch i % 23 {
            case 0: cuenta = excluida
            case 1: cuenta = archivada
            case 2: cuenta = nil
            case 3, 4, 5, 6: cuenta = usd
            default: cuenta = pen
            }
            let category: Yala.Category?
            let subcategory: Subcategory?
            let value: Double
            switch i % 9 {
            case 0: category = sueldo; subcategory = nil; value = 2_500 + Double(i % 13) * 0.37
            case 1: category = comida; subcategory = restaurante; value = 30.1 + Double(i % 11)  // devolución
            case 2: category = nil; subcategory = nil; value = 40.25 + Double(i % 5)            // sin categoría, +
            case 3: category = nil; subcategory = nil; value = -(15.5 + Double(i % 9))          // sin categoría, −
            case 4: category = casa; subcategory = luz; value = -(80.33 + Double(i % 17))
            case 5: category = comida; subcategory = nil; value = -(12.4 + Double(i % 7))       // categoría sin sub
            default: category = comida; subcategory = mercado; value = -(10.01 + Double(i % 90))
            }
            let currency = cuenta?.currencyCode ?? "PEN"
            // En dólares: unas con el convertido guardado y otras sin él, para que la foto reconvierta.
            let guardado = currency == "USD" ? (i % 2 == 0 ? value * 3.7 : 0) : value
            let tx = TransactionItem(date: date, amount: value, currencyCode: currency, note: "n\(i % 31)",
                                     category: category, subcategory: subcategory, account: cuenta,
                                     amountInPreferredCurrency: guardado,
                                     preferredCurrencyCode: currency == "USD" && i % 2 == 1 ? "USD" : "PEN")
            tx.createdAt = date
            if i % 97 == 0 { tx.balanceAdjustmentType = InitialBalanceService.typeAdjustment }
            context.insert(tx)
        }
        context.insert(Budget(currencyCode: "PEN", limitAmount: 900, category: comida, name: "Comida mes"))
        context.insert(Budget(currencyCode: "PEN", limitAmount: 9_000, category: casa, name: "Casa año",
                              periodType: "yearly"))
        try context.save()
    }

    static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(value)
    }

    /// Los movimientos elegibles como los armaba la foto antes del lote 7.
    static func elegiblesComoAntes(_ context: ModelContext) throws -> [TransactionItem] {
        let todos = try context.fetch(FetchDescriptor<TransactionItem>(sortBy: [
            SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)
        ]))
        let cuentas = try context.fetch(FetchDescriptor<Account>())
        let excluidas = Set(cuentas.filter { !$0.keepsHistory }.map(\.persistentModelID))
        return todos.filter { WidgetDataCache.countsForWidgets($0, excludedAccountIDs: excluidas) }
    }
}

@Suite("Eficiencia 7 · la foto de los widgets sobre filas leídas una vez", .serialized)
@MainActor
struct FotoWidgetsFilasParidadTests {

    @Test("Los ocho resúmenes de período y la curva salen idénticos al código previo")
    func resumenesYCurva_identicosAlCodigoPrevio() throws {
        let context = try makeTestContext()
        let now = FotoFilasFixture.ahora
        try FotoFilasFixture.seed(context, count: 2_400, now: now)

        let foto = WidgetDataCache.buildSnapshot(context: context, now: now).widget
        let elegibles = try FotoFilasFixture.elegiblesComoAntes(context)
        let adjustment = GroupBridgeStatsAdjustment.build(
            from: try context.fetch(FetchDescriptor<TransactionItem>()), context: context)
        let moneda = WidgetDataCache.preferredCurrencyCode()

        let periodos: [DetailPeriod] = [.thisWeek, .last7Days, .last30Days, .thisMonth, .lastMonth, .thisYear, .lastYear,
                                        .allTime]
        #expect(foto.periodSummaries.count == 8)
        for periodo in periodos {
            let intervalo = periodo.dateInterval(now: now)
            let referencia = ReferenciaFotoPreLote7.buildPeriodSummary(
                transactions: elegibles, periodStart: intervalo.start, periodEnd: intervalo.end, currencyCode: moneda,
                allTransactionsForBalance: elegibles, adjustment: adjustment, converter: CurrencyConverter.shared
            )
            let hoy = try #require(foto.periodSummaries[periodo.rawValue])
            #expect(try FotoFilasFixture.encoded(hoy) == FotoFilasFixture.encoded(referencia),
                    "el resumen de \(periodo.rawValue) cambió")
        }
        // El fixture no es trivial: hay gasto, ingreso, categorías, subcategorías y reparto por cuenta en el año.
        let anio = try #require(foto.periodSummaries[DetailPeriod.thisYear.rawValue])
        #expect(anio.totalExpense != 0 && anio.totalIncome != 0)
        #expect(anio.topCategories.count >= 3 && !anio.topSubcategories.isEmpty && (anio.accountFlows?.count ?? 0) >= 2)

        let curva = ReferenciaFotoPreLote7.buildTrendData(
            transactions: elegibles, totalBalance: foto.totalBalance, currencyCode: moneda,
            converter: CurrencyConverter.shared)
        #expect(try FotoFilasFixture.encoded(foto.trendData) == FotoFilasFixture.encoded(curva), "la curva cambió")
        #expect(foto.trendData.monthlyPoints.count > 12)
    }

    @Test("Las funciones de siempre (sobre movimientos) dan lo mismo que la referencia")
    func funcionesSobreMovimientos_igualQueLaReferencia() throws {
        let context = try makeTestContext()
        let now = FotoFilasFixture.ahora
        try FotoFilasFixture.seed(context, count: 900, now: now)
        let elegibles = try FotoFilasFixture.elegiblesComoAntes(context)
        let intervalo = DetailPeriod.thisYear.dateInterval(now: now)

        let hoy = WidgetDataCache.buildPeriodSummary(
            transactions: elegibles, periodStart: intervalo.start, periodEnd: intervalo.end, currencyCode: "PEN",
            allTransactionsForBalance: elegibles)
        let antes = ReferenciaFotoPreLote7.buildPeriodSummary(
            transactions: elegibles, periodStart: intervalo.start, periodEnd: intervalo.end, currencyCode: "PEN",
            allTransactionsForBalance: elegibles)
        #expect(try FotoFilasFixture.encoded(hoy) == FotoFilasFixture.encoded(antes))

        let cashHoy = WidgetDataCache.buildCashFlowByDay(
            transactions: elegibles, periodStart: intervalo.start, periodEnd: intervalo.end, currencyCode: "PEN")
        let cashAntes = ReferenciaFotoPreLote7.buildCashFlowByDay(
            transactions: elegibles, periodStart: intervalo.start, periodEnd: intervalo.end, currencyCode: "PEN")
        #expect(try FotoFilasFixture.encoded(cashHoy) == FotoFilasFixture.encoded(cashAntes))

        let subHoy = WidgetDataCache.subcategoryExpenseBreakdown(transactions: elegibles, limit: 20, currencyCode: "PEN")
        let subAntes = ReferenciaFotoPreLote7.subcategoryExpenseBreakdown(transactions: elegibles, limit: 20,
                                                                          currencyCode: "PEN")
        #expect(try FotoFilasFixture.encoded(subHoy.rows) == FotoFilasFixture.encoded(subAntes.rows))
        #expect(subHoy.total == subAntes.total)

        let catHoy = WidgetDataCache.categoryExpenseSlices(transactions: elegibles, currencyCode: "PEN")
        let catAntes = ReferenciaFotoPreLote7.categoryExpenseSlices(transactions: elegibles, currencyCode: "PEN")
        #expect(catHoy.map(\.amount) == catAntes.map(\.amount))
        #expect(catHoy.map { $0.category?.name } == catAntes.map { $0.category?.name })
    }

    @Test("Por etapas sale la misma foto que de una vez, y en más tramos que etapas")
    func porEtapas_mismaFoto_yMasTramosQueEtapas() throws {
        let context = try makeTestContext()
        let now = FotoFilasFixture.ahora
        try FotoFilasFixture.seed(context, count: 1_500, now: now)

        let whole = WidgetDataCache.buildSnapshot(context: context, now: now)
        let (etapas, terminar) = WidgetDataCache.buildSnapshot(etapasDe: context, now: now)
        var tramos = 0
        for etapa in etapas {
            // Cada llamada es un tramo; entre una y otra, la foto por etapas cede el hilo principal.
            while true {
                tramos += 1
                if etapa() { break }
            }
        }
        let staged = terminar()
        #expect(try FotoFilasFixture.encoded(staged.widget) == FotoFilasFixture.encoded(whole.widget))
        #expect(staged.siri == whole.siri)
        #expect(etapas.count >= 10)
        #expect(tramos >= etapas.count)
    }

    @Test("La proyección del saldo por trozos da lo mismo que de una vez, sin plan y con filtros")
    func proyeccionPorTrozos_igualQueDeUnaVez() throws {
        let context = try makeTestContext()
        let now = FotoFilasFixture.ahora
        try FotoFilasFixture.seed(context, count: 2_000, now: now)
        let todos = try context.fetch(FetchDescriptor<TransactionItem>(sortBy: [
            SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)
        ]))
        let calendar = Calendar.current
        let month = try #require(calendar.dateInterval(of: .month, for: now))
        let horizon = DateInterval(start: month.start, end: month.end.addingTimeInterval(86_400 * 40))
        let days = ProjectedFlowCalculator.futureDays(in: horizon, today: now, calendar: calendar)
        try #require(!days.isEmpty)

        for conFiltros in [false, true] {
            let contados = conFiltros ? todos.filter { $0.account?.currencyCode == "PEN" } : todos
            let inputs = ProjectedFlowBuilder.Inputs(
                today: now, calendar: calendar, overdueWindowStart: month.start, days: days,
                allTransactions: todos, countedTransactions: contados, hasSessionFilters: conFiltros,
                scheduledPayments: [], paymentFilter: .none, currencyCode: "PEN", adjustment: .none,
                converter: CurrencyConverter.shared)
            let deUnaVez = ProjectedFlowBuilder.build(inputs, context: context)

            let precalculo = ProjectedFlowBuilder.PrecalculoMotor(inputs, context: context)
            while !precalculo.avanzar() {}
            let motor = try #require(precalculo.resultado, "sin plan, el motor tiene que precalcularse")
            // Más de un trozo: la unión de trozos es lo que se prueba.
            #expect(motor.contados.movimientos.count > ProjectedFlowBuilder.PrecalculoMotor.tamanoTrozo)
            let porTrozos = ProjectedFlowBuilder.build(inputs, context: context, motor: motor)
            #expect(porTrozos == deUnaVez, conFiltros ? "con filtros" : "sin filtros")
        }
    }

    @Test("Con plan de flujo de caja no se convierte nada por adelantado: manda el plan")
    func conPlan_noSePrecalcula() throws {
        let context = try makeTestContext()
        let now = FotoFilasFixture.ahora
        try FotoFilasFixture.seed(context, count: 300, now: now)
        context.insert(CashFlowPlan(name: "Plan"))
        try context.save()
        let calendar = Calendar.current
        let month = try #require(calendar.dateInterval(of: .month, for: now))
        let days = ProjectedFlowCalculator.futureDays(
            in: DateInterval(start: month.start, end: month.end), today: now, calendar: calendar)
        let inputs = ProjectedFlowBuilder.Inputs(
            today: now, calendar: calendar, overdueWindowStart: month.start, days: days,
            allTransactions: [], countedTransactions: [], hasSessionFilters: false, scheduledPayments: [],
            paymentFilter: .none, currencyCode: "PEN", adjustment: .none, converter: CurrencyConverter.shared)
        let precalculo = ProjectedFlowBuilder.PrecalculoMotor(inputs, context: context)
        #expect(precalculo.avanzar())
        #expect(precalculo.resultado == nil)
    }
}
