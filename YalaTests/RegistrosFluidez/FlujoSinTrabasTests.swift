//
//  FlujoSinTrabasTests.swift
//  YalaTests / RegistrosFluidez
//
//  Tres cuelgues de la build 2.3 (4) en el iPhone, 19-nov-2026 (YALA-IOS-12, -Q y -P). Sus pilas están en el Flujo de
//  caja, no en la lista de Registros: el motor del mes (`FlujoMotorMesEntrada.movimientos`) y el índice de las líneas
//  (`TransactionIndex`) recorrían toda la historia en el hilo principal, pedían al calendario el mes de cada movimiento,
//  armaban la clave «AAAA-MM» con `String(format:)` y el cálculo del plan leía la historia dos veces de SwiftData.
//
//  Lo que se fija: (1) el cálculo del plan ya no arma el índice leyendo los modelos (testigo
//  `TransactionIndex._testModelPasses`, que sin el arreglo sube a 1); (2) el mes de cada movimiento sale de una caché
//  (testigo `MonthBucketer._testCalendarLookups`, que sin ella crece con los movimientos); y (3) nada de eso cambia lo
//  que se ve: el índice desde el motor es el mismo que desde los modelos, también en los bordes del mes y con cambio de
//  hora, y la clave es la misma que daba `String(format:)`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Flujo de caja sin trabas (YALA-IOS-12, -Q, -P)", .serialized)
@MainActor
struct FlujoSinTrabasTests {

    // MARK: - Infra

    private struct Fixture {
        let context: ModelContext
        let transactions: [TransactionItem]
        let categories: [Yala.Category]
    }

    private static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier) ?? .current
        return calendar
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, _ s: Int = 0,
                             in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s)) ?? .distantPast
    }

    /// Un gasto, una devolución en la misma categoría, un ingreso, uno sin categoría, uno con subcategoría, un ajuste de
    /// saldo, y los bordes del mes: medianoche del día 1 y el último segundo del mes.
    private func makeFixture(calendar: Calendar, bulk: Int = 0) throws -> Fixture {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.personalSchema, configurations: [config])
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let comida = Yala.Category(name: "Comida", colorHex: "#000000", isIncome: false)
        let sueldo = Yala.Category(name: "Sueldo", colorHex: "#000000", isIncome: true)
        let transporte = Yala.Category(name: "Transporte", colorHex: "#000000", isIncome: false)
        for item in [comida, sueldo, transporte] { context.insert(item) }
        let taxi = Subcategory(name: "Taxi", category: transporte)
        context.insert(taxi)

        func tx(_ date: Date, _ amount: Double, _ category: Yala.Category?, _ sub: Subcategory? = nil) -> TransactionItem {
            let item = TransactionItem(date: date, amount: amount, currencyCode: "PEN", category: category,
                                       subcategory: sub, amountInPreferredCurrency: amount)
            context.insert(item)
            return item
        }
        _ = tx(Self.date(2026, 3, 1, 0, 0, 0, in: calendar), -120, comida)     // medianoche del día 1
        _ = tx(Self.date(2026, 2, 28, 23, 59, 59, in: calendar), -80, comida)  // último segundo de febrero
        _ = tx(Self.date(2026, 3, 10, in: calendar), 30, comida)               // devolución: resta del gasto
        _ = tx(Self.date(2026, 3, 15, in: calendar), 5000, sueldo)
        _ = tx(Self.date(2026, 3, 29, 2, 30, in: calendar), -15, transporte, taxi) // noche del cambio de hora en Madrid
        _ = tx(Self.date(2026, 4, 2, in: calendar), -40, nil)                  // sin categoría: fuera del índice
        let ajuste = tx(Self.date(2026, 4, 3, in: calendar), 999, comida)
        ajuste.balanceAdjustmentType = InitialBalanceService.typeAdjustment    // no es ingreso ni gasto
        for i in 0..<bulk {
            _ = tx(Self.date(2026, 4, 1, in: calendar).addingTimeInterval(-Double(i) * 86_400 / 2), -Double(i % 90 + 1),
                   i.isMultiple(of: 2) ? comida : transporte, i.isMultiple(of: 3) ? taxi : nil)
        }
        try context.save()

        let transactions = try context.fetch(
            FetchDescriptor<TransactionItem>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )
        return Fixture(context: context, transactions: transactions, categories: [comida, sueldo, transporte])
    }

    // MARK: - (1) El cálculo del plan no vuelve a leer la historia para el índice

    @Test func elPlanArmaElIndiceSinLeerLosModelos() throws {
        let calendar = Self.calendar("America/Lima")
        let fixture = try makeFixture(calendar: calendar, bulk: 200)
        let plan = CashFlowPlan(name: "", startingBalance: 0)
        let lines = fixture.categories.map {
            CashFlowLine(name: $0.name, isIncome: $0.isIncome, estimationMethod: .average3m, category: $0)
        }
        TransactionIndex._testModelPasses = 0
        _ = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: lines, transactions: fixture.transactions, allExpenseCategories: fixture.categories,
            scheduledPayments: [], monthsBack: 6, monthsAhead: 6, currencyCode: "PEN",
            converter: MockCurrencyConverter(), now: Self.date(2026, 4, 5, in: calendar), calendar: calendar
        )
        #expect(TransactionIndex._testModelPasses == 0,
                "el índice de las líneas sale de lo que el motor ya leyó, no de otra pasada por SwiftData")
    }

    @Test func elDetalleDeUnaLineaTampocoRelee() throws {
        let calendar = Self.calendar("America/Lima")
        let fixture = try makeFixture(calendar: calendar)
        TransactionIndex._testModelPasses = 0
        _ = FlujoDetalleLineaLogica.indiceDelLimite(
            lineas: [], historia: fixture.transactions, currencyCode: "PEN", adjustment: .none,
            converter: MockCurrencyConverter(), now: Self.date(2026, 4, 5, in: calendar), calendar: calendar
        )
        #expect(TransactionIndex._testModelPasses == 0)
    }

    // MARK: - (2) El mes de cada movimiento sale de la caché

    @Test func elMotorPreguntaAlCalendarioPorMesNoPorMovimiento() throws {
        let calendar = Self.calendar("America/Lima")
        let fixture = try makeFixture(calendar: calendar, bulk: 600)
        MonthBucketer._testCalendarLookups = 0
        let resultado = FlujoMotorMesEntrada.movimientos(
            fixture.transactions, currencyCode: "PEN", adjustment: .none, converter: MockCurrencyConverter(),
            startOfTomorrow: Self.date(2026, 4, 6, 0, in: calendar), calendar: calendar
        )
        let meses = Set(resultado.movimientos.map(\.mes)).count
        #expect(resultado.movimientos.count > 600)
        // Al menos una: el mes sale de la caché (con 0, el bucle volvió a preguntar al calendario por su cuenta).
        #expect((1...(meses + 2)).contains(MonthBucketer._testCalendarLookups),
                "ordenados por fecha, una pregunta por mes (\(MonthBucketer._testCalendarLookups) para \(meses) meses)")
    }

    // MARK: - (3) Nada cambia lo que se ve

    @Test(arguments: ["America/Lima", "Europe/Madrid", "America/Santiago"])
    func elMesDeLaCacheEsElDelCalendario(_ zona: String) {
        let calendar = Self.calendar(zona)
        var buckets = MonthBucketer(calendar: calendar)
        var fechas: [Date] = []
        for mes in 1...12 {
            let inicio = Self.date(2026, mes, 1, 0, 0, 0, in: calendar)
            fechas += [inicio, inicio.addingTimeInterval(-1), inicio.addingTimeInterval(1),
                       Self.date(2026, mes, 15, 3, in: calendar)]
        }
        // Desordenadas a propósito: la caché tiene que fallar bien, no solo acertar con la lista ordenada.
        for fecha in fechas.shuffled() + fechas.reversed() {
            #expect(buckets.monthStart(of: fecha) == calendar.dateInterval(of: .month, for: fecha)?.start)
            #expect(buckets.monthKey(of: fecha) == CashFlowProjectionCalculator.monthKey(for: fecha, calendar: calendar))
        }
    }

    @Test(arguments: ["America/Lima", "Europe/Madrid"])
    func elIndiceDesdeElMotorEsElMismo(_ zona: String) throws {
        let calendar = Self.calendar(zona)
        let fixture = try makeFixture(calendar: calendar, bulk: 120)
        let converter = MockCurrencyConverter()
        let desdeModelos = TransactionIndex(
            transactions: fixture.transactions.filter { $0.balanceAdjustmentType == nil },
            currencyCode: "PEN", adjustment: .none, converter: converter, calendar: calendar
        )
        let movimientos = FlujoMotorMesEntrada.movimientos(
            fixture.transactions, currencyCode: "PEN", adjustment: .none, converter: converter,
            startOfTomorrow: Self.date(2026, 4, 6, 0, in: calendar), calendar: calendar
        ).movimientos
        let desdeMotor = TransactionIndex(movimientos: movimientos, calendar: calendar)
        #expect(desdeMotor.byCategoryMonth == desdeModelos.byCategoryMonth)
        #expect(desdeMotor.bySubcategoryMonth == desdeModelos.bySubcategoryMonth)

        // Y los bordes caen en su mes: lo de medianoche del día 1 en marzo, el último segundo en febrero.
        let comida = fixture.categories[0].persistentModelID
        #expect(desdeMotor.total(for: comida, monthKey: "2026-02") == desdeModelos.total(for: comida, monthKey: "2026-02"))
        #expect(desdeMotor.monthKeys(for: comida)["2026-03"] != nil)
    }

    @Test func laClaveEsLaMismaQueConFormato() {
        for year in [0, 7, 99, 999, 1999, 2026, 9999] {
            for month in 1...12 {
                #expect(MonthKeyText.make(year: year, month: month) == String(format: "%04d-%02d", year, month))
            }
        }
        #expect(MonthKeyText.make(year: 12026, month: 3) == String(format: "%04d-%02d", 12026, 3))
        #expect(RecordsMonthSectionsLogic.monthKey(Self.date(2026, 10, 17, in: .current)) == "2026-10")
    }
}
