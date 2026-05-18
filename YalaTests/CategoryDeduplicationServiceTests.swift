//
//  CategoryDeduplicationServiceTests.swift
//  YalaTests
//
//  Tests for CategoryDeduplicationService.identityKey and grouping logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct CategoryDeduplicationServiceTests {

    // MARK: - Identity Key

    @MainActor @Test func identityKey_sameProperties_sameKey() {
        let cat1 = Category(name: "Food", colorHex: "#FF0000", isIncome: false)
        cat1.iconName = "fork.knife"
        let cat2 = Category(name: "Comida", colorHex: "#FF0000", isIncome: false)
        cat2.iconName = "fork.knife"

        let key1 = CategoryDeduplicationService.identityKey(for: cat1)
        let key2 = CategoryDeduplicationService.identityKey(for: cat2)
        #expect(key1 == key2)
    }

    @MainActor @Test func identityKey_differentIcon_differentKey() {
        let cat1 = Category(name: "Food", colorHex: "#FF0000", isIncome: false)
        cat1.iconName = "fork.knife"
        let cat2 = Category(name: "Food", colorHex: "#FF0000", isIncome: false)
        cat2.iconName = "cart"

        let key1 = CategoryDeduplicationService.identityKey(for: cat1)
        let key2 = CategoryDeduplicationService.identityKey(for: cat2)
        #expect(key1 != key2)
    }

    @MainActor @Test func identityKey_differentIsIncome_differentKey() {
        let cat1 = Category(name: "Salary", colorHex: "#FF0000", isIncome: false)
        cat1.iconName = "dollarsign"
        let cat2 = Category(name: "Salary", colorHex: "#FF0000", isIncome: true)
        cat2.iconName = "dollarsign"

        let key1 = CategoryDeduplicationService.identityKey(for: cat1)
        let key2 = CategoryDeduplicationService.identityKey(for: cat2)
        #expect(key1 != key2)
    }

    @MainActor @Test func identityKey_nilIconName_usesNilString() {
        let cat = Category(name: "Other", colorHex: "#00FF00", isIncome: false)
        // iconName is nil by default
        let key = CategoryDeduplicationService.identityKey(for: cat)
        #expect(key.contains("nil|"))
    }

    // MARK: - Grouping

    @MainActor @Test func grouping_duplicates_groupedTogether() {
        let cat1 = Category(name: "Food", colorHex: "#FF0000", isIncome: false)
        cat1.iconName = "fork.knife"
        let cat2 = Category(name: "Food Copy", colorHex: "#FF0000", isIncome: false)
        cat2.iconName = "fork.knife"
        let cat3 = Category(name: "Transport", colorHex: "#00FF00", isIncome: false)
        cat3.iconName = "car"

        let categories = [cat1, cat2, cat3]
        let grouped = Dictionary(grouping: categories) {
            CategoryDeduplicationService.identityKey(for: $0)
        }
        #expect(grouped.count == 2)
        let duplicateGroup = grouped.values.first { $0.count > 1 }
        #expect(duplicateGroup?.count == 2)
    }

    @MainActor @Test func grouping_noDuplicates_allSingleGroups() {
        let cat1 = Category(name: "Food", colorHex: "#FF0000", isIncome: false)
        cat1.iconName = "fork.knife"
        let cat2 = Category(name: "Transport", colorHex: "#00FF00", isIncome: false)
        cat2.iconName = "car"
        let cat3 = Category(name: "Salary", colorHex: "#0000FF", isIncome: true)
        cat3.iconName = "dollarsign"

        let categories = [cat1, cat2, cat3]
        let grouped = Dictionary(grouping: categories) {
            CategoryDeduplicationService.identityKey(for: $0)
        }
        #expect(grouped.count == 3)
        #expect(grouped.values.allSatisfy { $0.count == 1 })
    }

    // MARK: - Re-parenting Inverse Relationships
    //
    // El bug: cuando una subcategoría duplicada se borra durante dedup, deleteRule .nullify
    // vacía silenciosamente las relaciones inversas (Budget.subcategories, FavoritePayment.subcategory,
    // ScheduledPayment.subcategory, InboxDraft.subcategory, MerchantMemory.subcategory,
    // CashFlowLine.subcategory). Estos tests verifican que las refs se preservan en el keeper match.

    /// Setup: 2 Categories seed duplicadas (mismo identityKey), cada una con 1 sub seed
    /// con mismo iconName → matchean. Keeper tiene 1 transacción para forzar orden estable.
    @MainActor
    private func makeDedupSetup(_ context: ModelContext) throws -> DedupSetup {
        let keeperCat = Category(name: "Food", colorHex: "#FF0000", isIncome: false, isDefaultSeed: true, iconName: "fork.knife")
        let dupCat = Category(name: "Food", colorHex: "#FF0000", isIncome: false, isDefaultSeed: true, iconName: "fork.knife")
        context.insert(keeperCat)
        context.insert(dupCat)

        let keeperSub = Subcategory(name: "Restaurants", isDefaultSeed: true, iconName: "fork.knife", category: keeperCat)
        let dupSub = Subcategory(name: "Restaurants Dup", isDefaultSeed: true, iconName: "fork.knife", category: dupCat)
        context.insert(keeperSub)
        context.insert(dupSub)

        // Push keeper al tope del sort: añade 1 tx para que transactions.count > 0
        let account = makeTestAccount(context: context, name: "Test Acc")
        _ = makeTestTransaction(context: context, amount: 100, account: account, category: keeperCat, subcategory: keeperSub)

        try context.save()
        return DedupSetup(keeperCat: keeperCat, dupCat: dupCat, keeperSub: keeperSub, dupSub: dupSub, account: account)
    }

    @MainActor @Test func dedup_preservesBudgetSubcategoryRef_whenMatched() throws {
        let context = try makeTestContext()
        let setup = try makeDedupSetup(context)

        let budget = makeTestBudget(context: context, name: "Food Budget", subcategories: [setup.dupSub])
        try context.save()

        let removed = CategoryDeduplicationService.deduplicateSeedCategories(in: context)

        #expect(removed == 1)
        #expect(budget.subcategories?.count == 1)
        #expect(budget.subcategories?.first?.persistentModelID == setup.keeperSub.persistentModelID)
    }

    @MainActor @Test func dedup_preservesBudgetSubcategoryRef_idempotent() throws {
        let context = try makeTestContext()
        let setup = try makeDedupSetup(context)

        // Budget ya tiene AMBAS subs (keeper y dup). Tras dedup no debe duplicar match.
        let budget = makeTestBudget(context: context, name: "Food Budget", subcategories: [setup.keeperSub, setup.dupSub])
        try context.save()

        let removed = CategoryDeduplicationService.deduplicateSeedCategories(in: context)

        #expect(removed == 1)
        #expect(budget.subcategories?.count == 1)
        #expect(budget.subcategories?.first?.persistentModelID == setup.keeperSub.persistentModelID)
    }

    @MainActor @Test func dedup_preservesFavoritePaymentSubcategoryRef() throws {
        let context = try makeTestContext()
        let setup = try makeDedupSetup(context)

        let fav = FavoritePayment(name: "Lunch")
        fav.subcategory = setup.dupSub
        context.insert(fav)
        try context.save()

        _ = CategoryDeduplicationService.deduplicateSeedCategories(in: context)

        #expect(fav.subcategory?.persistentModelID == setup.keeperSub.persistentModelID)
    }

    @MainActor @Test func dedup_preservesScheduledPaymentSubcategoryRef() throws {
        let context = try makeTestContext()
        let setup = try makeDedupSetup(context)

        let sched = ScheduledPayment(name: "Monthly dining", amount: 50, currencyCode: "PEN", nextDueDate: Date())
        sched.subcategory = setup.dupSub
        context.insert(sched)
        try context.save()

        _ = CategoryDeduplicationService.deduplicateSeedCategories(in: context)

        #expect(sched.subcategory?.persistentModelID == setup.keeperSub.persistentModelID)
    }

    @MainActor @Test func dedup_preservesInboxDraftSubcategoryRef() throws {
        let context = try makeTestContext()
        let setup = try makeDedupSetup(context)

        let draft = makeTestInboxDraft(context: context)
        draft.subcategory = setup.dupSub
        try context.save()

        _ = CategoryDeduplicationService.deduplicateSeedCategories(in: context)

        #expect(draft.subcategory?.persistentModelID == setup.keeperSub.persistentModelID)
    }

    @MainActor @Test func dedup_preservesMerchantMemorySubcategoryRef() throws {
        let context = try makeTestContext()
        let setup = try makeDedupSetup(context)

        let memory = MerchantMemory(merchantCanonical: "burger_king", subcategory: setup.dupSub)
        context.insert(memory)
        try context.save()

        _ = CategoryDeduplicationService.deduplicateSeedCategories(in: context)

        #expect(memory.subcategory?.persistentModelID == setup.keeperSub.persistentModelID)
    }

    @MainActor @Test func dedup_preservesCashFlowLineSubcategoryRef() throws {
        let context = try makeTestContext()
        let setup = try makeDedupSetup(context)

        let line = CashFlowLine(name: "Dining", subcategory: setup.dupSub)
        context.insert(line)
        try context.save()

        _ = CategoryDeduplicationService.deduplicateSeedCategories(in: context)

        #expect(line.subcategory?.persistentModelID == setup.keeperSub.persistentModelID)
    }

    @MainActor @Test func dedup_preservesTransactionSubcategoryRef() throws {
        // Baseline: este caso ya funcionaba pre-fix. Lo mantenemos para detectar regresión.
        let context = try makeTestContext()
        let setup = try makeDedupSetup(context)

        let dupTx = makeTestTransaction(context: context, amount: 50, account: setup.account, category: setup.dupCat, subcategory: setup.dupSub)
        try context.save()

        _ = CategoryDeduplicationService.deduplicateSeedCategories(in: context)

        #expect(dupTx.subcategory?.persistentModelID == setup.keeperSub.persistentModelID)
    }

    @MainActor @Test func dedup_customSubcategory_neverMergedWithSeed() throws {
        // Sub custom con MISMO iconName que sub seed del keeper. No debe mergearse.
        // Su identidad (transacciones, budget refs) se preserva intacta.
        let context = try makeTestContext()
        let setup = try makeDedupSetup(context)

        let customSub = Subcategory(name: "MyCustom", isDefaultSeed: false, iconName: "fork.knife", category: setup.dupCat)
        context.insert(customSub)

        let budget = makeTestBudget(context: context, name: "Custom Budget", subcategories: [customSub])
        try context.save()

        let removed = CategoryDeduplicationService.deduplicateSeedCategories(in: context)

        #expect(removed == 1)
        // Custom sub sobrevive (no se borró)
        #expect(customSub.category?.persistentModelID == setup.keeperCat.persistentModelID)
        #expect(customSub.isDefaultSeed == false)
        // Budget mantiene su ref al custom sub original (no se sustituyó por keeper seed)
        #expect(budget.subcategories?.count == 1)
        #expect(budget.subcategories?.first?.persistentModelID == customSub.persistentModelID)
    }

    @MainActor @Test func dedup_customSubcategory_withoutMatchInKeeper_reparented() throws {
        // Sub custom sin match por iconName en keeper. Se re-parentea preservando identidad.
        let context = try makeTestContext()
        let setup = try makeDedupSetup(context)

        let customSub = Subcategory(name: "Niche", isDefaultSeed: false, iconName: "star.fill", category: setup.dupCat)
        context.insert(customSub)
        try context.save()

        _ = CategoryDeduplicationService.deduplicateSeedCategories(in: context)

        #expect(customSub.category?.persistentModelID == setup.keeperCat.persistentModelID)
    }
}

/// Container helper para los tests de re-parenting. Mantiene 1 lugar el setup duplicado.
@MainActor
private struct DedupSetup {
    let keeperCat: YalaCategory
    let dupCat: YalaCategory
    let keeperSub: Subcategory
    let dupSub: Subcategory
    let account: Account
}
