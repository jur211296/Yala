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
    /// Caso "todos cero" ya cubierto por `iCloudAccountSummary_emptyContext_returnsZeros`
    /// arriba (integration). Aquí los casos no obvios: presupuestos y grupos, CADA UNO SOLO.

    /// **Los presupuestos CUENTAN; los grupos NO, y las dos mitades están medidas** (2026-09-21,
    /// `restore-treats-budgets-and-groups-as-no-data`).
    ///
    /// Este test decía que ninguno de los dos contaba, con el argumento de que eran «artefactos
    /// secundarios». Lo que se midió al cerrar el ticket:
    ///
    ///  · **Presupuestos: sí.** Viven en `personalSchema`, así que el espejo los baja, y
    ///    `RestoreProgressView.liveCounts` los pinta subiendo mientras la pantalla siguiente negaba
    ///    que existieran. CloudKit entrega por lotes y sin orden garantizado.
    ///  · **Grupos: no.** `SplitGroup` vive en un store `cloudKitDatabase: .none` y llega por el
    ///    backend de Yala, así que este predicado —que contesta «¿trajo algo el espejo?»— no puede
    ///    moverse con ellos sin mentir. Y contarlos tapaba cuatro estados: ver
    ///    `hasAnyData_ignoresGroups_becauseTheyDoNotComeFromICloud` abajo.
    @Test("los presupuestos encienden el predicado por sí solos")
    func hasAnyData_countsBudgets() {
        let summary = ICloudAccountSummary(
            userName: "Juan",
            accountsCount: 0,
            transactionsCount: 0,
            budgetsCount: 5,
            groupsCount: 0,
            primaryCurrencyCode: "PEN",
            categoriesCount: 0
        )
        #expect(summary.hasAnyData == true, """
            con presupuestos bajados y nada más, esta persona SÍ tiene datos en iCloud: negarlo la
            manda a `.notFound` con «Empezar desde cero» de botón primario.
            """)
    }

    /// **Y los grupos NO lo encienden, que es la otra mitad de la decisión.**
    ///
    /// La razón no es que no sean datos —lo son, y `checkHasExistingData()` sí los cuenta para avisar
    /// antes de borrar—, sino que **no vienen de iCloud**. `WelcomeRestoreView` decide con un
    /// `if hasAnyData` que cortocircuita antes de leer el veredicto del import, así que con un solo
    /// grupo local se volverían inalcanzables `.importIncomplete`, `.cloudPaused`, `.cloudUnverified`
    /// y `.notFound`. En `FullModeActivationView`, que monta esa pantalla y a la que **solo se llega
    /// desde una sesión solo-grupos**, lo serían POR CONSTRUCCIÓN.
    ///
    /// Este caso existe para que nadie «alinee» el predicado con `visibleCountItems` —que sí pinta los
    /// grupos— sin leer antes esto.
    @Test("los grupos NO encienden el predicado: no vienen de iCloud")
    func hasAnyData_ignoresGroups_becauseTheyDoNotComeFromICloud() {
        let summary = ICloudAccountSummary(
            userName: "Juan",
            accountsCount: 0,
            transactionsCount: 0,
            budgetsCount: 0,
            groupsCount: 3,
            primaryCurrencyCode: "PEN",
            categoriesCount: 0
        )
        #expect(summary.hasAnyData == false, """
            contar los grupos aquí tapa cuatro estados de `WelcomeRestoreView` y deja `.notFound`
            inalcanzable en la activación de Yala completo, donde siempre hay grupos.
            """)
    }

    /// Y el conteo de VERDAD, contra un store: el predicado puede estar perfecto mientras el
    /// constructor deja la cifra en cero — el struct de arriba se lo inventa.
    @Test func iCloudAccountSummary_budgetOnly_hasAnyData() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()
        _ = makeTestBudget(context: context, name: "Comida")

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.budgetsCount == 1)
        #expect(summary.accountsCount == 0)
        #expect(summary.transactionsCount == 0)
        #expect(summary.categoriesCount == 0)
        #expect(summary.hasAnyData == true)
    }

    /// El grupo se CUENTA —la cifra viaja y la pantalla del hallazgo la pinta— pero **no enciende el
    /// predicado**. Las dos mitades en el mismo caso, porque separarlas deja pasar el mutante que
    /// confunde «no se transporta» con «no decide».
    @Test func iCloudAccountSummary_groupOnly_countsButDoesNotFlagData() throws {
        let context = try makeTestContext()
        let prefs = makePreferences()
        context.insert(SplitGroup(name: "Viaje"))

        let summary = try context.iCloudAccountSummary(appPreferences: prefs)

        #expect(summary.groupsCount == 1, "la cifra viaja: `visibleCountItems` la pinta")
        #expect(summary.accountsCount == 0)
        #expect(summary.hasAnyData == false, """
            pero no decide: los grupos no vienen de iCloud. A quien solo tiene grupos se le avisa antes
            de borrar en la PUERTA, cuyo `deviceHasData` sale de `checkHasExistingData()`.
            """)
    }
}
