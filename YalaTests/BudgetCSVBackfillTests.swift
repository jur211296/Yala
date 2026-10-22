//
//  BudgetCSVBackfillTests.swift
//  YalaTests
//
//  Cubre `CategoryDeduplicationService.backfillBudgetCSVMirrorsFromM2M`: el pase
//  eager repetible que reconstruye el CSV mirror de un Budget cuya relación M2M ya
//  está hidratada pero cuyo espejo CSV quedó vacío/desincronizado (el filtro perdido
//  tras un restore lento de iCloud → el cálculo lo lee como "sin filtros" y cuenta todo).
//
//  El estado roto de producción se simula creando el Budget con M2M vacío (init
//  auto-deriva CSV nil) y asignando la relación M2M DESPUÉS, sin tocar el CSV —
//  replica "el nuke dejó el CSV vacío y la M2M se hidrató más tarde".
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Budget CSV mirror — eager backfill from hydrated M2M", .serialized)
struct BudgetCSVBackfillTests {

    /// El bug: M2M hidratada + CSV vacío → reconstruye el espejo y el filtro vuelve a aplicar.
    @Test func csvNil_m2mPopulated_rebuilds_andFiltersAgain() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Bank")
        let cat = makeTestCategory(context: context, name: "Food", isIncome: false)
        let subA = makeTestSubcategory(context: context, name: "Coffee", category: cat)
        let subB = makeTestSubcategory(context: context, name: "Lunch", category: cat)
        try context.save()

        // M2M vacío en el init (CSV auto-derivado = nil), luego hidratar la relación
        // sin tocar el CSV → estado "post-nuke + M2M hidratada tarde".
        let budget = makeTestBudget(context: context, name: "Coffee", limitAmount: 300, subcategories: [])
        budget.subcategories = [subA]
        try context.save()
        #expect(budget.subcategoryIDsSet == nil, "Precondición: CSV vacío con M2M poblada")

        let count = CategoryDeduplicationService.backfillBudgetCSVMirrorsFromM2M(in: context)

        #expect(count == 1)
        #expect(budget.subcategoryIDsSet == [subA.shortcutID], "CSV reconstruido desde la M2M")

        // End-to-end: el cálculo ya filtra por subcategoría (no cuenta todo).
        let now = Date()
        let txA = makeTestTransaction(context: context, amount: 50, date: now, account: account, category: cat, subcategory: subA)
        let txB = makeTestTransaction(context: context, amount: 100, date: now, account: account, category: cat, subcategory: subB)
        try context.save()
        let interval = DateInterval(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(3600))
        let result = BudgetsViewModel.filterTransactions([txA, txB], forBudget: budget, in: interval)

        #expect(result.count == 1, "Solo TX A (Coffee), ya no suma todo")
        #expect(result.first?.subcategory?.persistentModelID == subA.persistentModelID)
    }

    /// Clave: M2M vacío + CSV poblado → NUNCA nukear (lo contrario al nuke-on-nil del one-shot).
    @Test func csvPopulated_m2mEmpty_doesNotNuke() throws {
        let context = try makeTestContext()
        let cat = makeTestCategory(context: context, name: "Food", isIncome: false)
        let subA = makeTestSubcategory(context: context, name: "Coffee", category: cat)
        try context.save()

        // M2M vacío, CSV poblado explícitamente (un Budget cuyo record CSV llegó pero
        // la relación aún no se materializó). El pase NO debe borrar el CSV bueno.
        let budget = makeTestBudget(context: context, subcategories: [], subcategoryIDs: subA.shortcutID.uuidString)
        try context.save()
        #expect(budget.subcategoryIDsSet == [subA.shortcutID])

        let count = CategoryDeduplicationService.backfillBudgetCSVMirrorsFromM2M(in: context)

        #expect(count == 0)
        #expect(budget.subcategoryIDsSet == [subA.shortcutID], "CSV intacto — no se nukea")
    }

    /// Convergencia: una hidratación parcial dejó un CSV incompleto → se corrige a la M2M completa.
    @Test func csvIncomplete_m2mComplete_corrects() throws {
        let context = try makeTestContext()
        let cat = makeTestCategory(context: context, name: "Food", isIncome: false)
        let subA = makeTestSubcategory(context: context, name: "Coffee", category: cat)
        let subB = makeTestSubcategory(context: context, name: "Lunch", category: cat)
        try context.save()

        // CSV solo con subA (oleada previa parcial), M2M ya completa [subA, subB].
        let budget = makeTestBudget(context: context, subcategories: [], subcategoryIDs: subA.shortcutID.uuidString)
        budget.subcategories = [subA, subB]
        try context.save()

        let count = CategoryDeduplicationService.backfillBudgetCSVMirrorsFromM2M(in: context)

        #expect(count == 1)
        #expect(budget.subcategoryIDsSet == [subA.shortcutID, subB.shortcutID])
    }

    /// Idempotencia: CSV ya igual a la M2M → no-op (no marca dirty, retorna 0).
    @Test func csvEqualsM2M_noOp() throws {
        let context = try makeTestContext()
        let cat = makeTestCategory(context: context, name: "Food", isIncome: false)
        let subA = makeTestSubcategory(context: context, name: "Coffee", category: cat)
        try context.save()

        // init auto-deriva CSV desde la M2M → CSV == M2M.
        let budget = makeTestBudget(context: context, subcategories: [subA])
        try context.save()
        #expect(budget.subcategoryIDsSet == [subA.shortcutID])

        let count = CategoryDeduplicationService.backfillBudgetCSVMirrorsFromM2M(in: context)

        #expect(count == 0)
    }

    /// Cuentas y etiquetas se reconstruyen independientes y con el keypath correcto
    /// (Account/Subcategory → `shortcutID`, Tag → `id`).
    @Test func accountsAndTags_rebuildIndependently() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Bank")
        let tag = makeTestTag(context: context, name: "Trip")
        try context.save()

        let budget = makeTestBudget(context: context, accounts: [], tags: [])
        budget.accounts = [account]
        budget.tags = [tag]
        try context.save()
        #expect(budget.accountIDsSet == nil)
        #expect(budget.tagIDsSet == nil)

        let count = CategoryDeduplicationService.backfillBudgetCSVMirrorsFromM2M(in: context)

        #expect(count == 1)
        #expect(budget.accountIDsSet == [account.shortcutID], "Account usa shortcutID")
        #expect(budget.tagIDsSet == [tag.id], "Tag usa id")
    }

    /// CRÍTICO (path sin gate, ej. force-sync): un CSV completo + M2M PARCIAL (relación a
    /// medio materializar) NO debe degradarse. El pase nunca reconstruye desde un subconjunto.
    @Test func csvComplete_m2mPartial_doesNotDegrade() throws {
        let context = try makeTestContext()
        let cat = makeTestCategory(context: context, name: "Food", isIncome: false)
        let subA = makeTestSubcategory(context: context, name: "Coffee", category: cat)
        let subB = makeTestSubcategory(context: context, name: "Lunch", category: cat)
        try context.save()

        // CSV completo {A,B}; M2M solo {A} (simula la relación a medio hidratar en CloudKit).
        let budget = makeTestBudget(
            context: context,
            subcategories: [],
            subcategoryIDs: "\(subA.shortcutID.uuidString),\(subB.shortcutID.uuidString)"
        )
        budget.subcategories = [subA]
        try context.save()

        let count = CategoryDeduplicationService.backfillBudgetCSVMirrorsFromM2M(in: context)

        #expect(count == 0, "M2M parcial (subconjunto) NO debe sobrescribir el CSV completo")
        #expect(budget.subcategoryIDsSet == [subA.shortcutID, subB.shortcutID], "CSV completo intacto")
    }

    /// Un CSV huérfano (UUID que ya no resuelve) con M2M vacío se deja intacto:
    /// no hay fuente para reconstruir y nunca nukeamos (paridad con el comportamiento
    /// defensivo de `BudgetFilterRegressionTests` Caso 3).
    @Test func orphanCSV_m2mEmpty_leftIntact() throws {
        let context = try makeTestContext()
        let orphan = UUID()
        let budget = makeTestBudget(context: context, subcategories: [], subcategoryIDs: orphan.uuidString)
        try context.save()

        let count = CategoryDeduplicationService.backfillBudgetCSVMirrorsFromM2M(in: context)

        #expect(count == 0)
        #expect(budget.subcategoryIDsSet == [orphan], "CSV huérfano intacto")
    }
}
