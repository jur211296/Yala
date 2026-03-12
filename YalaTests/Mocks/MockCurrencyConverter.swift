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

    func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal {
        if from == to { return amount }
        return amount * fixedRate
    }

    func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal {
        if from == to { return amount }
        return amount * fixedRate
    }
}
