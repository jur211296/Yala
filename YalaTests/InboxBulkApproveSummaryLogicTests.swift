//
//  InboxBulkApproveSummaryLogicTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 4 · L4-13 (variante 2). Al aprobar varios borradores, bajo «N transacciones creadas» va
//  «S/ 60.50 en total · Cuenta Principal». Cada parte sale solo si es la misma para todos.
//

import Testing

@testable import Yala

struct InboxBulkApproveSummaryLogicTests {

    private typealias Item = InboxBulkApproveSummaryLogic.Item

    @Test func mismosGastosMismaCuenta_daTotalPositivoYCuenta() {
        let summary = InboxBulkApproveSummaryLogic.summary(of: [
            Item(amount: -42.50, currencyCode: "PEN", accountName: "Cuenta Principal"),
            Item(amount: -18.00, currencyCode: "PEN", accountName: "Cuenta Principal"),
        ])
        #expect(summary.total == 60.50)
        #expect(summary.currencyCode == "PEN")
        #expect(summary.accountName == "Cuenta Principal")
    }

    @Test func ingresos_tambienSumanEnPositivo() {
        let summary = InboxBulkApproveSummaryLogic.summary(of: [
            Item(amount: 100, currencyCode: "USD", accountName: "A"),
            Item(amount: 50, currencyCode: "USD", accountName: "A"),
        ])
        #expect(summary.total == 150)
        #expect(summary.currencyCode == "USD")
    }

    /// Una suma de soles y dólares no es ninguna cifra: se calla el total, la cuenta sigue.
    @Test func variasDivisas_sinTotal() {
        let summary = InboxBulkApproveSummaryLogic.summary(of: [
            Item(amount: -10, currencyCode: "PEN", accountName: "A"),
            Item(amount: -10, currencyCode: "USD", accountName: "A"),
        ])
        #expect(summary.total == nil)
        #expect(summary.currencyCode == nil)
        #expect(summary.accountName == "A")
    }

    /// Un gasto y un ingreso: ni la suma ni la resta dicen «cuánto se guardó».
    @Test func gastoEIngreso_sinTotal() {
        let summary = InboxBulkApproveSummaryLogic.summary(of: [
            Item(amount: -10, currencyCode: "PEN", accountName: "A"),
            Item(amount: 30, currencyCode: "PEN", accountName: "A"),
        ])
        #expect(summary.total == nil)
    }

    @Test func variasCuentas_sinCuenta() {
        let summary = InboxBulkApproveSummaryLogic.summary(of: [
            Item(amount: -10, currencyCode: "PEN", accountName: "A"),
            Item(amount: -5, currencyCode: "PEN", accountName: "B"),
        ])
        #expect(summary.total == 15)
        #expect(summary.accountName == nil)
    }

    @Test func sinNombreDeCuenta_sinCuenta() {
        let summary = InboxBulkApproveSummaryLogic.summary(of: [
            Item(amount: -10, currencyCode: "PEN", accountName: nil),
            Item(amount: -5, currencyCode: "PEN", accountName: nil),
        ])
        #expect(summary.accountName == nil)
        #expect(summary.total == 15)
    }

    @Test func vacio_noDiceNada() {
        #expect(InboxBulkApproveSummaryLogic.summary(of: []).isEmpty)
    }
}
