//
//  FullModeActivationLogicTests.swift
//  YalaTests
//
//  Tests pure-logic para los helpers que usa `FullModeActivationView` al
//  reusar `OnboardingView` para activar Yala completo desde modo `.groupInvite`.
//  Sin SwiftData ni UI — verificación end-to-end del flow vía Device QA C2-01.
//

import Foundation
import Testing

@testable import Yala

struct FullModeActivationLogicTests {

    // MARK: - buildSummary

    @Test func buildSummary_withUserNameAndGroupCurrency_setsBothAndSkipsAccountSteps() {
        let summary = FullModeActivationLogic.buildSummary(
            userName: "Juan",
            groupCurrency: "PEN",
            defaultCurrency: "USD",
            userCategoriesCount: 11
        )

        // Skips name step (userName != nil) y currencyName step (currency != nil)
        #expect(summary.userName == "Juan")
        #expect(summary.primaryCurrencyCode == "PEN")  // groupCurrency wins over defaultCurrency

        // Skip categories si user ya sembró (count > 0)
        #expect(summary.categoriesCount == 11)

        // NO skip account steps — user pasa por purpose + accounts + accountType + balance
        #expect(summary.accountsCount == 0)
        #expect(summary.transactionsCount == 0)
        #expect(summary.budgetsCount == 0)
        #expect(summary.groupsCount == 0)
    }

    @Test func buildSummary_groupCurrencyTakesPrecedenceOverDefault() {
        let summary = FullModeActivationLogic.buildSummary(
            userName: "Juan",
            groupCurrency: "EUR",
            defaultCurrency: "USD",
            userCategoriesCount: 0
        )
        #expect(summary.primaryCurrencyCode == "EUR")
    }

    @Test func buildSummary_fallsBackToDefaultCurrencyWhenGroupNil() {
        let summary = FullModeActivationLogic.buildSummary(
            userName: "Juan",
            groupCurrency: nil,
            defaultCurrency: "USD",
            userCategoriesCount: 0
        )
        #expect(summary.primaryCurrencyCode == "USD")
    }

    @Test func buildSummary_nilCategoriesCount_meansShowCategoriesStep() {
        // Approach J no aplicado: user llega a FullMode sin haber sembrado.
        let summary = FullModeActivationLogic.buildSummary(
            userName: "Juan",
            groupCurrency: "PEN",
            defaultCurrency: nil,
            userCategoriesCount: 0
        )
        #expect(summary.categoriesCount == 0)
        // OnboardingView mostrará el step .categories al user.
    }

    @Test func buildSummary_userNameNil_meansShowNameStep() {
        // Edge case defensivo: si por alguna razón `userName` no fue persistido.
        let summary = FullModeActivationLogic.buildSummary(
            userName: nil,
            groupCurrency: "PEN",
            defaultCurrency: nil,
            userCategoriesCount: 0
        )
        #expect(summary.userName == nil)
        // OnboardingView mostrará el step .name (red de seguridad).
    }

    // MARK: - shouldDeleteResidualGeneralAccount

    @Test func shouldDeleteResidualGeneralAccount_generalNoSystemNoTx_returnsTrue() {
        let result = FullModeActivationLogic.shouldDeleteResidualGeneralAccount(
            type: AccountType.general.rawValue,
            isSystemAccount: false,
            hasTransactions: false
        )
        #expect(result == true)
    }

    @Test func shouldDeleteResidualGeneralAccount_withTransactions_returnsFalse() {
        let result = FullModeActivationLogic.shouldDeleteResidualGeneralAccount(
            type: AccountType.general.rawValue,
            isSystemAccount: false,
            hasTransactions: true  // protege datos reales del user
        )
        #expect(result == false)
    }

    @Test func shouldDeleteResidualGeneralAccount_systemAccount_returnsFalse() {
        let result = FullModeActivationLogic.shouldDeleteResidualGeneralAccount(
            type: AccountType.general.rawValue,
            isSystemAccount: true,  // cuenta sistema "Grupos [moneda]" — no tocar
            hasTransactions: false
        )
        #expect(result == false)
    }

    @Test func shouldDeleteResidualGeneralAccount_nonGeneralType_returnsFalse() {
        let result = FullModeActivationLogic.shouldDeleteResidualGeneralAccount(
            type: AccountType.checking.rawValue,
            isSystemAccount: false,
            hasTransactions: false
        )
        #expect(result == false)
    }
}
