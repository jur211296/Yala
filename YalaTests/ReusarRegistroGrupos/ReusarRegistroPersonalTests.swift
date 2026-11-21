//
//  ReusarRegistroPersonalTests.swift
//  YalaTests
//
//  «Reusar» con registros propios (encargo del 21-nov, punto 3): cuenta archivada, otra moneda e ingresos. En su
//  propio fichero: `makeTestContext()` comparte el almacén por fichero y vacía el de la otra suite (`testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Lo personal que el encargo pidió probar

@Suite("Reusar personal · cuenta archivada, otra moneda e ingresos", .serialized)
@MainActor
struct ReusarRegistroPersonalTests {

    @Test("un registro en una cuenta archivada no la pasa al formulario: hay que elegir otra")
    func cuentaArchivada() throws {
        let context = try makeTestContext()
        let archivada = makeTestAccount(context: context, name: "Vieja", currencyCode: "PEN")
        archivada.isArchived = true
        let tx = TransactionItem(date: .now, amount: -50, currencyCode: "PEN", note: "Gym", account: archivada)
        context.insert(tx)
        try context.save()
        #expect(RecurringFromRecordService.offersMakeRecurring(tx))
        #expect(RecurringFromRecordService.prefill(from: tx).account == nil)
    }

    @Test("otra moneda: la del registro, con su cuenta")
    func otraMoneda() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "Visa", currencyCode: "PEN")
        let tx = TransactionItem(date: .now, amount: -20, currencyCode: "USD", note: "Cloudflare", account: visa)
        context.insert(tx)
        try context.save()
        let prefill = RecurringFromRecordService.prefill(from: tx)
        #expect(prefill.currencyCode == "USD")
        #expect(prefill.account?.name == "Visa")
    }

    @Test("un ingreso se repite como cobro, con su monto en positivo")
    func ingreso() throws {
        let context = try makeTestContext()
        let cuenta = makeTestAccount(context: context, name: "BCP", currencyCode: "PEN")
        let salario = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        let tx = TransactionItem(date: .now, amount: 3_000, currencyCode: "PEN", note: "Sueldo", category: salario,
                                 account: cuenta)
        context.insert(tx)
        try context.save()
        let prefill = RecurringFromRecordService.prefill(from: tx)
        #expect(prefill.transactionType == TransactionType.income.rawValue)
        #expect(prefill.amount == AmountInputHelper.formatWithGrouping(3_000))
        #expect(prefill.group == nil)
    }
}
