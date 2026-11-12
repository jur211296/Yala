//
//  TransactionDetailConversionDisplayTests.swift
//  YalaTests
//
//  Card kab4 del tablero: la fila «Tipo de cambio» del detalle de un registro pintaba «≈ S/ 0,00»
//  cuando la conversión a la divisa principal no se escribió (`amountInPreferredCurrency == 0` con
//  nativo distinto de 0: la fila llegó incompleta por sync o se creó sin tasas). Ese cero parece un
//  importe real.
//
//  Ahora `TransactionDetailSheetLogic.conversionDisplay` reconvierte con la tasa del día del registro
//  —la misma regla que las estadísticas, `CashFlowCalculator.reconverted`— y, si esa tasa no es la
//  EXACTA del día, la fila pasa a texto («Sin tipo de cambio para ese día»).
//
//  Escena: gasto de 50 USD con principal PEN, 1 USD = 3,7 en el doble.
//  - Con el bug: `.amount(0, …)` en los casos con el convertido a 0.
//  - El control (convertido escrito) usa una tasa ABSURDA: si el converter se consultara, saldría otro
//    número.
//
//  Sin `ModelContext`: los `@Model` sueltos bastan, como `ResolvedAmountZeroConvertedTests`.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Detalle de registro · fila «Tipo de cambio» con el convertido sin escribir")
struct TransactionDetailConversionDisplayTests {

    private let fecha = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 12)) ?? Date()

    private func gasto(guardado: Double, nativo: Double = -50, tasaGuardada: Double = 1.0) -> TransactionItem {
        TransactionItem(
            date: fecha, amount: nativo, currencyCode: "USD", note: "Hotel",
            exchangeRate: tasaGuardada,
            amountInPreferredCurrency: guardado, preferredCurrencyCode: "PEN"
        )
    }

    private func conversor(_ tasa: Decimal, _ quality: RateQuality = .exact) -> MockCurrencyConverter {
        MockCurrencyConverter(fixedRate: tasa, quality: quality)
    }

    private func cerca(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.0001 }

    // MARK: - Con tasa del día

    @Test("Convertido a 0 y tasa exacta del día: se reconvierte, con signo y la tasa usada")
    func zeroConverted_exactRate_reconverts() {
        let display = TransactionDetailSheetLogic.conversionDisplay(for: gasto(guardado: 0), converter: conversor(3.7))
        guard case .amount(let value, let rate) = display else {
            Issue.record("esperaba un importe, salió \(display)")
            return
        }
        #expect(cerca(value, -185), "con el bug: 0 (\(value))")
        #expect(cerca(rate, 3.7), "la tasa que se enseña es la usada, no la guardada (\(rate))")
    }

    // MARK: - Sin tasa del día

    @Test(
        "Convertido a 0 sin la tasa exacta de ese día: texto, nunca un importe",
        arguments: [RateQuality.carriedForward(fromDateKey: "2026-04-09"), .staticFallback]
    )
    func zeroConverted_noExactRate_isMissing(quality: RateQuality) {
        let display = TransactionDetailSheetLogic.conversionDisplay(
            for: gasto(guardado: 0), converter: conversor(3.7, quality)
        )
        #expect(display == .missingRateForDay, "con el bug: .amount(0) — salió \(display)")
    }

    @Test("Convertido a 0 y una tasa «exacta» que da 0: tampoco se pinta 0")
    func zeroConverted_rateThatYieldsZero_isMissing() {
        let display = TransactionDetailSheetLogic.conversionDisplay(for: gasto(guardado: 0), converter: conversor(0))
        #expect(display == .missingRateForDay)
    }

    // MARK: - Controles

    @Test("Control: con el convertido escrito manda lo guardado, sin consultar la tasa")
    func writtenConversion_isReadAsStored() {
        let display = TransactionDetailSheetLogic.conversionDisplay(
            for: gasto(guardado: -185, tasaGuardada: 3.7), converter: conversor(1_000)
        )
        #expect(display == .amount(value: -185, rate: 3.7))
    }

    @Test("Control: un importe de 0 de verdad (nativo 0) sigue siendo 0")
    func trueZero_staysZero() {
        let display = TransactionDetailSheetLogic.conversionDisplay(
            for: gasto(guardado: 0, nativo: 0, tasaGuardada: 3.7), converter: conversor(1_000, .staticFallback)
        )
        #expect(display == .amount(value: 0, rate: 3.7))
    }
}
