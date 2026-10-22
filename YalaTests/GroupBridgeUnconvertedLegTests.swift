//
//  GroupBridgeUnconvertedLegTests.swift
//  YalaTests
//
//  Un gasto de grupo con una pata SIN CONVERTIR. Ticket `bridge-synthesis-trusts-a-zero-converted-amount`.
//
//  `GroupBridgeStatsAdjustment.build` sintetiza «mi parte» sumando el `amountInPreferredCurrency` de
//  la pata real y de las de préstamo. Si la de préstamo llegó al store con ese importe a 0 —la fila
//  existe, la conversión no se escribió—, la suma daba el importe del grupo ENTERO, y sin «≈»: la pata
//  aportaba 0 al importe y 0 a la duda. Mismo efecto si se guardó con OTRA divisa preferida.
//
//  El escenario base: gasto de 100 USD, divisa preferida PEN, tasa 4 (sin decimales a propósito, para
//  que las igualdades sean exactas). Pata real −100 USD = −400 PEN guardados; pata de préstamo +90 USD.
//  Mi parte son 10 USD = **−40 PEN**. Con el bug: −400.
//
//  Archivo propio: `makeTestContext()` reusa el store por `#fileID` (ver `testing.md`).
//
//  MUTANTE VERIFICADO (2026-10-11): con `storedPreferred(_:isUsableIn:)` devolviendo siempre `true`
//  —la suma vieja— caen los seis casos de «pata que no se puede creer» (Estadísticas incluido) y los
//  dos controles siguen verdes.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Gasto de grupo con una pata sin convertir", .serialized)
struct GroupBridgeUnconvertedLegTests {

    private let fecha = Date(timeIntervalSince1970: 1_775_000_000)

    private struct Escenario {
        let real: TransactionItem
        let prestamo: TransactionItem
        var transacciones: [TransactionItem] { [real, prestamo] }
    }

    /// - Parameters:
    ///   - realGuardado: `amountInPreferredCurrency` de la pata real (−400 si se convirtió).
    ///   - prestamoGuardado: el de la pata de préstamo (+360 si se convirtió; 0 = sin convertir).
    ///   - prestamoGuardadoEn: divisa preferida con la que se guardó la pata de préstamo.
    private func escenario(
        _ context: ModelContext,
        divisa: String = "USD",
        total: Double = 100,
        prestado: Double = 90,
        realGuardado: Double = -400,
        prestamoGuardado: Double,
        prestamoGuardadoEn: String = "PEN"
    ) throws -> Escenario {
        let cuentaReal = makeTestAccount(context: context, name: "Diaria", currencyCode: divisa)
        let cuentaGrupos = makeTestAccount(context: context, name: "Grupos", currencyCode: divisa)
        cuentaGrupos.isSystemAccount = true
        let gasto = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let prestamoCat = makeTestCategory(context: context, name: "Préstamo a grupos", isIncome: true)
        let eid = UUID().uuidString

        let real = TransactionItem(
            date: fecha, amount: -total, currencyCode: divisa, note: "",
            category: gasto, account: cuentaReal, tags: [],
            amountInPreferredCurrency: realGuardado, preferredCurrencyCode: "PEN"
        )
        real.splitExpenseID = eid
        context.insert(real)

        let prestamo = TransactionItem(
            date: fecha, amount: prestado, currencyCode: divisa, note: "",
            category: prestamoCat, account: cuentaGrupos, tags: [],
            amountInPreferredCurrency: prestamoGuardado, preferredCurrencyCode: prestamoGuardadoEn
        )
        prestamo.splitExpenseID = eid
        context.insert(prestamo)
        try context.save()
        return Escenario(real: real, prestamo: prestamo)
    }

    private func conversor(_ calidad: RateQuality = .exact) -> MockCurrencyConverter {
        MockCurrencyConverter(fixedRate: 4, quality: calidad)
    }

    // MARK: - La síntesis

    @Test("Pata de préstamo sin convertir: cuenta mi parte, no el grupo entero")
    func prestamoSinConvertir_cuentaMiParte() throws {
        let context = try makeTestContext()
        let e = try escenario(context, prestamoGuardado: 0)

        let ajuste = GroupBridgeStatsAdjustment.build(from: e.transacciones, converter: conversor())

        #expect(ajuste.isSuppressed(e.prestamo), "premisa: el bridge neteó la pareja")
        #expect(ajuste.amount(e.real) == -10, "el nativo nunca dependió de la conversión")
        #expect(ajuste.amountInPreferredCurrency(e.real) == -40, """
            Mi parte son 10 USD = 40 PEN. Sumando el 0 guardado salían −400: el gasto entero.
            """)
        #expect(ajuste.approximateMagnitude(e.real, magnitude: 40) == 0, """
            Con la tasa exacta el número reconvertido es correcto: no hay nada que marcar.
            """)
    }

    @Test("Pata de préstamo sin convertir y tasa aproximada: mi parte, con «≈»")
    func prestamoSinConvertir_tasaAproximada_marca() throws {
        let context = try makeTestContext()
        let e = try escenario(context, prestamoGuardado: 0)

        let ajuste = GroupBridgeStatsAdjustment.build(
            from: e.transacciones, converter: conversor(.carriedForward(fromDateKey: "2026-03-31"))
        )

        #expect(ajuste.amountInPreferredCurrency(e.real) == -40)
        #expect(ajuste.approximateMagnitude(e.real, magnitude: 40) == 360, """
            La pata reconvertida (90 USD = 360 PEN) salió de una tasa arrastrada: su magnitud entera
            es duda. Con el bug aportaba 0 a la duda y el número salía limpio.
            """)
    }

    @Test("Mismo gasto en la divisa preferida: el 0 guardado tampoco cuenta como importe")
    func prestamoSinConvertir_mismaDivisa() throws {
        let context = try makeTestContext()
        // El caso del ticket: gasto de 1.000 PEN, me tocan 100.
        let e = try escenario(
            context, divisa: "PEN", total: 1_000, prestado: 900,
            realGuardado: -1_000, prestamoGuardado: 0
        )

        let ajuste = GroupBridgeStatsAdjustment.build(from: e.transacciones, converter: conversor())

        #expect(ajuste.amountInPreferredCurrency(e.real) == -100, "con el bug: −1.000")
        #expect(ajuste.approximateMagnitude(e.real, magnitude: 100) == 0, "PEN → PEN es exacta")
    }

    @Test("Pata REAL sin convertir: también se reconvierte")
    func realSinConvertir_cuentaMiParte() throws {
        let context = try makeTestContext()
        let e = try escenario(context, realGuardado: 0, prestamoGuardado: 360)

        let ajuste = GroupBridgeStatsAdjustment.build(from: e.transacciones, converter: conversor())

        #expect(ajuste.amountInPreferredCurrency(e.real) == -40, """
            Con el bug salía +360: el gasto de grupo se pintaba como un INGRESO.
            """)
    }

    @Test("Pata de préstamo guardada con otra divisa preferida: se reconvierte, no se mezcla")
    func prestamoEnOtraDivisaPreferida_seReconvierte() throws {
        let context = try makeTestContext()
        // Guardada cuando la preferida era USD: 90 «USD» que no son PEN.
        let e = try escenario(context, prestamoGuardado: 90, prestamoGuardadoEn: "USD")

        let ajuste = GroupBridgeStatsAdjustment.build(from: e.transacciones, converter: conversor())

        #expect(ajuste.amountInPreferredCurrency(e.real) == -40, "con el bug: −400 + 90 = −310")
    }

    // MARK: - Controles: lo que se puede creer no se toca

    @Test("Patas bien convertidas: manda lo guardado y el conversor no se consulta")
    func patasConvertidas_mandaLoGuardado() throws {
        let context = try makeTestContext()
        let e = try escenario(context, prestamoGuardado: 360)
        // Un conversor con una tasa absurda: si lo consultara, el importe dejaría de ser −40.
        let absurdo = MockCurrencyConverter(fixedRate: 999, quality: .staticFallback)

        let ajuste = GroupBridgeStatsAdjustment.build(from: e.transacciones, converter: absurdo)

        #expect(ajuste.amountInPreferredCurrency(e.real) == -40)
        #expect(ajuste.approximateMagnitude(e.real, magnitude: 40) == 0)
    }

    @Test("Pata guardada provisional: conserva su propia duda, no la del conversor")
    func pataProvisional_conservaSuDuda() throws {
        let context = try makeTestContext()
        let e = try escenario(context, prestamoGuardado: 360)
        e.prestamo.isExchangeRateProvisional = true

        let ajuste = GroupBridgeStatsAdjustment.build(from: e.transacciones, converter: conversor())

        #expect(ajuste.amountInPreferredCurrency(e.real) == -40)
        #expect(ajuste.approximateMagnitude(e.real, magnitude: 40) == 360)
    }

    // MARK: - Lo que ve el usuario: el flujo de caja de Estadísticas

    @Test("Estadísticas: el gasto del período es mi parte, con «≈» si la tasa es aproximada")
    func flujoDeCaja_cuentaMiParte_yMarca() throws {
        let context = try makeTestContext()
        let e = try escenario(context, prestamoGuardado: 0)
        let inicio = Calendar.current.startOfDay(for: fecha)
        let intervalo = DateInterval(start: inicio, duration: 86_399)

        for (calidad, marca) in [(RateQuality.exact, false), (.carriedForward(fromDateKey: "2026-03-31"), true)] {
            let ajuste = GroupBridgeStatsAdjustment.build(
                from: e.transacciones, converter: conversor(calidad)
            )
            let resumen = CashFlowCalculator.calculateCashFlow(
                transactions: e.transacciones, interval: intervalo, grouping: .day,
                currencyCode: "PEN", adjustment: ajuste, converter: conversor(calidad)
            )
            #expect(resumen.totalExpense == 40, "con el bug: 400")
            #expect(resumen.totalIncome == 0, "premisa: la pata de préstamo está suprimida")
            #expect(resumen.expenseAmountsAreApproximate == marca)
        }
    }
}
