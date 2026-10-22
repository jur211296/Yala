//
//  MockCurrencyConverter.swift
//  YalaTests
//
//  Mock currency converter for testing calculators without ModelContext.
//

import Foundation
@testable import Yala

struct MockCurrencyConverter: CurrencyConverting {
    var fixedRate: Decimal = 1.0

    /// Calidad que declara este doble para toda conversión entre divisas distintas. Por defecto
    /// `.exact` —el doble representa un entorno con tasas completas, que es lo que asumen los tests
    /// que ya existían— y se sube a otro escalón para probar el camino de la marca de aproximado.
    var quality: RateQuality = .exact

    func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal {
        convertChecked(amount, from: from, to: to, on: date).amount
    }

    func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal {
        convertCheckedWithLatestRate(amount, from: from, to: to).amount
    }

    func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
        -> (amount: Decimal, quality: RateQuality)
    {
        if from == to { return (amount, .exact) }
        return (amount * fixedRate, quality)
    }

    func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
        -> (amount: Decimal, quality: RateQuality)
    {
        if from == to { return (amount, .exact) }
        return (amount * fixedRate, quality)
    }
}
