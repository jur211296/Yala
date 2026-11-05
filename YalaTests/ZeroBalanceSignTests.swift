//
//  ZeroBalanceSignTests.swift
//  YalaTests
//
//  Card «Una cuenta cuyo saldo suma cero sale como «€ -0.00» en Cuentas». La suma en coma flotante de movimientos que
//  dan cero deja un residuo (`-1e-9`) y el formateador lo pintaba «-0.00» conservando el signo. Medido en el barrido
//  QA 2.2 del 2026-10-30: la cuenta «Euros» del Excel real de Jürgen (73 movimientos que suman cero).
//
//  Cada caso lleva su control: un importe que SÍ se pinta distinto de cero conserva su signo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Un saldo que se pinta como cero no lleva signo", .serialized)
struct ZeroBalanceSignTests {

    /// Lo que deja una suma de `Double` que debería dar cero.
    private let floatResidue = -1e-9

    // MARK: - Formateador central (AmountText, saldos, widgets por su foto)

    @Test func currency_negativeResidue_isPaintedAsZero() {
        let shown = CurrencyFormattingHelper.currency(
            floatResidue, decimals: 2, identifier: "€", forceSign: false, isEstimate: false)
        let zero = CurrencyFormattingHelper.currency(0, decimals: 2, identifier: "€", forceSign: false, isEstimate: false)
        #expect(shown == zero)
        #expect(!shown.contains("-"))
    }

    @Test func currency_positiveResidueWithForcedSign_hasNoPlus() {
        let shown = CurrencyFormattingHelper.currency(
            -floatResidue, decimals: 2, identifier: "€", forceSign: true, isEstimate: false)
        #expect(!shown.contains("+"))
        #expect(!shown.contains("-"))
        let control = CurrencyFormattingHelper.currency(5, decimals: 2, identifier: "€", forceSign: true, isEstimate: false)
        #expect(control.contains("+"))
    }

    @Test func currency_belowHalfACent_isZero_aboveKeepsItsSign() {
        let below = CurrencyFormattingHelper.currency(-0.004, decimals: 2, identifier: "€", forceSign: false, isEstimate: false)
        let above = CurrencyFormattingHelper.currency(-0.006, decimals: 2, identifier: "€", forceSign: false, isEstimate: false)
        #expect(!below.contains("-"))
        #expect(above.contains("-"))
    }

    @Test func currency_withoutDecimals_halfAUnitIsTheEdge() {
        let below = CurrencyFormattingHelper.currency(-0.4, decimals: 0, identifier: "€", forceSign: false, isEstimate: false)
        let above = CurrencyFormattingHelper.currency(-0.6, decimals: 0, identifier: "€", forceSign: false, isEstimate: false)
        #expect(!below.contains("-"))
        #expect(above.contains("-"))
    }

    @Test func number_negativeResidue_isZero() {
        #expect(CurrencyFormattingHelper.number(floatResidue, decimals: 2) == CurrencyFormattingHelper.number(0, decimals: 2))
        // Control sin depender del glifo del menos del idioma del simulador.
        #expect(CurrencyFormattingHelper.number(-5, decimals: 2) != CurrencyFormattingHelper.number(5, decimals: 2))
    }

    // MARK: - Ajustes › Cuentas (el sitio medido)

    private func balanceShown(amount: Double) throws -> String {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Euros", currencyCode: "EUR")
        let item = TransactionItem(
            date: aMomentAgoToday(), amount: amount, currencyCode: "EUR", note: "",
            category: nil, subcategory: nil, account: account, tags: [], amountInPreferredCurrency: amount,
            preferredCurrencyCode: "EUR", tagIDs: nil
        )
        context.insert(item)
        try context.save()

        let vm = AccountsSettingsListViewModel()
        vm.setContext(context)
        return vm.formattedBalance(for: account)
    }

    @Test func accountsList_balanceThatSumsToZero_hasNoSign() throws {
        let shown = try balanceShown(amount: floatResidue)
        #expect(!shown.contains("-"), "Salía «\(shown)».")
        #expect(shown.hasSuffix("0.00") || shown.hasSuffix("0,00"))
    }

    @Test func accountsList_negativeBalance_keepsItsSign() throws {
        // Contra el positivo, no contra «-»: algunos idiomas escriben el menos con otro glifo.
        let negative = try balanceShown(amount: -5)
        let positive = try balanceShown(amount: 5)
        #expect(negative != positive)
    }

    // MARK: - Lo que decide por el signo

    @Test func creditCard_residueIsNotDebt() {
        #expect(PanelAccountCardLogic.amountKind(isExpensesOnlyMode: false, isCreditCard: true, value: floatResidue) == .balance)
        #expect(PanelAccountCardLogic.amountKind(isExpensesOnlyMode: false, isCreditCard: true, value: -5) == .toPay)
        #expect(PanelAccountCardLogic.lineKind(isExpensesOnlyMode: false, isCreditCard: true, value: floatResidue) == nil)
        #expect(PanelAccountCardLogic.lineKind(isExpensesOnlyMode: false, isCreditCard: true, value: -5) == .toPay)
    }

    @Test func editBalance_residueStartsPositive() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Euros", currencyCode: "EUR")
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        // Con su saldo inicial: sin él, el formulario abre en «Cambiar saldo inicial» y no lee el signo del saldo de hoy.
        let opening = makeTestTransaction(
            context: context, amount: floatResidue, date: aMomentAgoToday(),
            account: account, category: category, subcategory: sub)
        opening.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        try context.save()

        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.setContext(context)
        #expect(vm.selectedAdjustmentMode == .byEntry)
        #expect(vm.currentBalance < 0, "Control del escenario: el residuo llega negativo.")
        #expect(vm.isPositive)
    }

    // MARK: - Widgets de inicio y cifras compactas

    @Test func widgetSplitter_negativeResidue_hasNoSign() {
        #expect(WidgetAmountSplitter.split(value: floatResidue, symbol: "€", fractionDigits: 0).sign == "")
        #expect(WidgetAmountSplitter.split(value: -0.6, symbol: "€", fractionDigits: 0).sign == "-")
        #expect(WidgetAmountSplitter.split(value: -floatResidue, symbol: "€", fractionDigits: 0, forceSign: true).sign == "")
        #expect(WidgetAmountSplitter.split(value: 5, symbol: "€", fractionDigits: 0, forceSign: true).sign == "+")
    }

    @Test func lockScreenCompactAmount_negativeResidue_hasNoSign() {
        let locale = Locale(identifier: "es_PE")
        #expect(WidgetInsightsLogic.compactAmount(-0.4, locale: locale) == "0")
        #expect(WidgetInsightsLogic.compactAmount(-0.6, locale: locale) == "-1")
    }

    @Test func compactTableCells_negativeResidue_haveNoSign() {
        #expect(YalaFormatter.amountCompactTable(value: -0.4) == YalaFormatter.amountCompactTable(value: 0))
        #expect(YalaFormatter.amountCompactTable(value: -2).hasPrefix("-"))
        #expect(!YalaFormatterStatic.amountCashFlowCell(value: -0.4, currencyCode: "EUR").contains("-"))
        #expect(YalaFormatterStatic.amountCashFlowCell(value: -2, currencyCode: "EUR").hasPrefix("-"))
    }

    @Test func cashFlowStartingBalanceField_negativeResidue_isZero() {
        let locale = Locale(identifier: "en_US")
        #expect(CashFlowStartingBalanceSheet.editableText(floatResidue, locale: locale) == "0")
        #expect(CashFlowStartingBalanceSheet.editableText(-5, locale: locale) == "-5")
    }
}
