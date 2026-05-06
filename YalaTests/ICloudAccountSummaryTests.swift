//
//  ICloudAccountSummaryTests.swift
//  YalaTests
//
//  A4 Welcome Restore — verifies the summary excludes A0-Bridge infrastructure
//  (system accounts, bridged TX, system subcategories) so the user sees REAL data
//  counts when restoring from iCloud.
//
//  ⚠️ Flake R8 conocido (CLAUDE.md): tests con `makeTestContext()` pasan
//  individualmente con `-only-testing:` pero pueden crashear en `test-without-building`
//  full-suite por race con metadata SwiftData entre clones del simulador. Validación
//  end-to-end via integration tests F7 + Device QA A4-03..A4-05 (cuenta iCloud poblada
//  vs vacía vs parcial).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized) @MainActor
struct ICloudAccountSummaryTests {

    // MARK: - Helpers

    private func makePreferences() -> AppPreferences {
        AppPreferences(defaults: makeIsolatedDefaults(prefix: "summary"))
    }

    private func makeUserCategoryAndSubcat(in context: ModelContext) -> (YalaCategory, Subcategory) {
        let cat = makeTestCategory(context: context, name: "Comida")
        let sub = makeTestSubcategory(context: context, name: "Almuerzo", category: cat)
        return (cat, sub)
    }

    // MARK: - Empty context

    @Test func iCloudAccountSummary_emptyContext_returnsZeros() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.accountsCount == 0)
        #expect(summary.transactionsCount == 0)
        #expect(summary.budgetsCount == 0)
        #expect(summary.groupsCount == 0)
        #expect(summary.categoriesCount == 0)
        #expect(summary.hasAnyData == false)
    }

    // MARK: - Excludes system accounts

    @Test func iCloudAccountSummary_excludesSystemAccounts() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()

        // 1 user account + 1 system account (A0-Bridge virtual "Grupos PEN")
        _ = makeTestAccount(context: context, name: "Mi cuenta")
        let systemAccount = makeTestAccount(context: context, name: "Grupos PEN")
        systemAccount.isSystemAccount = true

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.accountsCount == 1)
    }

    @Test func iCloudAccountSummary_excludesArchivedAccounts() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()

        let active = makeTestAccount(context: context, name: "Activa")
        let archived = makeTestAccount(context: context, name: "Archivada")
        archived.isArchived = true
        _ = active

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.accountsCount == 1)
    }

    // MARK: - Excludes bridged transactions

    @Test func iCloudAccountSummary_excludesBridgedTransactions() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()

        let account = makeTestAccount(context: context)
        let (cat, sub) = makeUserCategoryAndSubcat(in: context)

        // 1 normal TX + 1 bridged (splitExpenseID set)
        _ = makeTestTransaction(context: context, amount: 50, account: account, category: cat, subcategory: sub)
        let bridged = makeTestTransaction(context: context, amount: 30, account: account, category: cat, subcategory: sub)
        bridged.splitExpenseID = "split-uuid-abc"

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.transactionsCount == 1)
    }

    @Test func iCloudAccountSummary_excludesSettlementBridgedTransactions() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()

        let account = makeTestAccount(context: context)
        let (cat, sub) = makeUserCategoryAndSubcat(in: context)

        let normal = makeTestTransaction(context: context, amount: 50, account: account, category: cat, subcategory: sub)
        let bridged = makeTestTransaction(context: context, amount: 100, account: account, category: cat, subcategory: sub)
        bridged.splitSettlementID = "settle-uuid-xyz"
        _ = normal

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.transactionsCount == 1)
    }

    // MARK: - Excludes system subcategories

    @Test func iCloudAccountSummary_excludesSystemSubcategories() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()

        let cat = makeTestCategory(context: context)
        _ = makeTestSubcategory(context: context, name: "User sub", category: cat)
        let systemSub = makeTestSubcategory(context: context, name: "Préstamo a grupos", category: cat)
        systemSub.isSystem = true

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.categoriesCount == 1)
    }

    // MARK: - User name fallback

    @Test func iCloudAccountSummary_userNameDefaultUsuario_returnsNil() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()
        prefs.userName = "Usuario"  // default placeholder

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.userName == nil)
    }

    @Test func iCloudAccountSummary_userNameRealValue_returnsTrimmed() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()
        prefs.userName = "  Jur  "

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.userName == "Jur")
    }

    @Test func iCloudAccountSummary_userNameEmpty_returnsNil() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()
        prefs.userName = "   "  // whitespace only

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.userName == nil)
    }

    // MARK: - hasAnyData semantics

    @Test func iCloudAccountSummary_hasAnyData_trueWithAccountOnly() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()
        _ = makeTestAccount(context: context)

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.hasAnyData == true)
    }

    @Test func iCloudAccountSummary_hasAnyData_trueWithCategoryOnly() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()
        let cat = makeTestCategory(context: context)
        _ = makeTestSubcategory(context: context, category: cat)

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.hasAnyData == true)
    }

    // MARK: - Pure-logic tests (sin makeTestContext) — A4 v3.1 SSOT extension

    /// `isFullyPrefilled` lo consume `WelcomeRestoreView.isAllPrefilled` y el
    /// `WelcomeFlowModifier.consumeDetectedSummary` (alert post-Hero). Tests
    /// pure-logic — no requieren ModelContext.

    @Test func isFullyPrefilled_trueWhenAllSet_pureLogic() {
        let summary = ICloudAccountSummary(
            userName: "Juan",
            accountsCount: 3,
            transactionsCount: 50,
            budgetsCount: 2,
            groupsCount: 1,
            primaryCurrencyCode: "PEN",
            categoriesCount: 12
        )
        #expect(summary.isFullyPrefilled == true)
    }

    @Test func isFullyPrefilled_falseWhenUserNameNil() {
        let summary = ICloudAccountSummary(
            userName: nil,
            accountsCount: 3,
            transactionsCount: 50,
            budgetsCount: 0,
            groupsCount: 0,
            primaryCurrencyCode: "PEN",
            categoriesCount: 12
        )
        #expect(summary.isFullyPrefilled == false)
    }

    @Test func isFullyPrefilled_falseWhenZeroAccounts() {
        let summary = ICloudAccountSummary(
            userName: "Juan",
            accountsCount: 0,
            transactionsCount: 0,
            budgetsCount: 0,
            groupsCount: 0,
            primaryCurrencyCode: "PEN",
            categoriesCount: 12
        )
        #expect(summary.isFullyPrefilled == false)
    }

    @Test func isFullyPrefilled_falseWhenZeroCategories() {
        // Caso edge: cuentas + nombre pero sin categorías (mid-restore o delete manual).
        // Onboarding sigue siendo necesario para seedearlas.
        let summary = ICloudAccountSummary(
            userName: "Juan",
            accountsCount: 2,
            transactionsCount: 0,
            budgetsCount: 0,
            groupsCount: 0,
            primaryCurrencyCode: "PEN",
            categoriesCount: 0
        )
        #expect(summary.isFullyPrefilled == false)
    }

    @Test func isFullyPrefilled_doesNotRequirePrimaryCurrencyCode() {
        // El currencyCode siempre está populated (default desde appPreferences),
        // así que NO se chequea para isFullyPrefilled.
        let summary = ICloudAccountSummary(
            userName: "Juan",
            accountsCount: 3,
            transactionsCount: 50,
            budgetsCount: 0,
            groupsCount: 0,
            primaryCurrencyCode: nil,
            categoriesCount: 12
        )
        #expect(summary.isFullyPrefilled == true)
    }

    /// `hasAnyData` decide si el alert "Detectamos tu cuenta" se muestra (post-Hero).
    /// Pure-logic complement a los tests integration de arriba.

    @Test func hasAnyData_returnsFalse_whenAllZero_pureLogic() {
        let summary = ICloudAccountSummary(
            userName: nil,
            accountsCount: 0,
            transactionsCount: 0,
            budgetsCount: 0,
            groupsCount: 0,
            primaryCurrencyCode: "PEN",
            categoriesCount: 0
        )
        #expect(summary.hasAnyData == false)
    }

    @Test func hasAnyData_ignoresBudgetsAndGroups() {
        // Budgets y groups por sí solos NO triggerean el alert: el user puede tener
        // budgets sin haber registrado nada. La intención del flag es "hay data REAL"
        // (cuentas/registros/categorías), no "hay artefactos secundarios".
        let summary = ICloudAccountSummary(
            userName: "Juan",
            accountsCount: 0,
            transactionsCount: 0,
            budgetsCount: 5,
            groupsCount: 3,
            primaryCurrencyCode: "PEN",
            categoriesCount: 0
        )
        #expect(summary.hasAnyData == false)
    }
}
