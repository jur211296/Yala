//
//  SubcategoryDedupLogicTests.swift
//  YalaTests
//
//  Pure-logic tests for SubcategoryDedupLogic. Avoids `makeTestContext()` per R8
//  (CloudKit container race crashes the runner) — builds @Model with `init`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
struct SubcategoryDedupLogicTests {

    // Stable, orderable shortcutIDs for deterministic keeper assertions.
    private func uuid(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    @MainActor
    private func makeCategory(
        name: String = "Hogar",
        icon: String = "house.fill",
        color: String = "#475569",
        isIncome: Bool = false
    ) -> YalaCategory {
        Category(name: name, colorHex: color, isIncome: isIncome, isDefaultSeed: true, iconName: icon)
    }

    @MainActor
    private func makeSub(
        name: String,
        sortOrder: Int = 4,
        icon: String? = "house.and.flag.fill",
        isDefaultSeed: Bool = true,
        isSystem: Bool = false,
        shortcutID: UUID,
        category: YalaCategory?
    ) -> Subcategory {
        let s = Subcategory(
            name: name,
            isDefaultSeed: isDefaultSeed,
            sortOrder: sortOrder,
            iconName: icon,
            isSystem: isSystem,
            category: category
        )
        s.shortcutID = shortcutID
        return s
    }

    @MainActor @Test func emptyArray_returnsNoGroups() {
        #expect(SubcategoryDedupLogic.duplicateGroups(in: []).isEmpty)
    }

    @MainActor @Test func noDuplicates_returnsNoGroups() {
        let cat = makeCategory()
        let a = makeSub(name: "Seguro del hogar", sortOrder: 4, shortcutID: uuid(1), category: cat)
        let b = makeSub(name: "Servicios del hogar", sortOrder: 5, icon: "bolt.fill", shortcutID: uuid(2), category: cat)
        #expect(SubcategoryDedupLogic.duplicateGroups(in: [a, b]).isEmpty)
    }

    @MainActor @Test func threeIdenticalCopies_keepsDeterministicKeeper_marksTwo() {
        let cat = makeCategory()
        // Same name/sortOrder/icon/category → same identity. Distinct shortcutIDs.
        let c2 = makeSub(name: "Seguro del hogar", shortcutID: uuid(2), category: cat)
        let c1 = makeSub(name: "Seguro del hogar", shortcutID: uuid(1), category: cat)
        let c3 = makeSub(name: "Seguro del hogar", shortcutID: uuid(3), category: cat)

        let groups = SubcategoryDedupLogic.duplicateGroups(in: [c2, c1, c3])

        #expect(groups.count == 1)
        // Keeper = lowest shortcutID.uuidString (sortOrder + name tie).
        #expect(groups.first?.keeper.shortcutID == uuid(1))
        #expect(Set(groups.first?.duplicates.map(\.shortcutID) ?? []) == Set([uuid(2), uuid(3)]))
    }

    @MainActor @Test func customSubcategory_excluded() {
        let cat = makeCategory()
        let seed = makeSub(name: "Seguro del hogar", shortcutID: uuid(1), category: cat)
        let custom = makeSub(name: "Seguro del hogar", isDefaultSeed: false, shortcutID: uuid(2), category: cat)
        // Custom no es elegible → no forma grupo con la seed.
        #expect(SubcategoryDedupLogic.duplicateGroups(in: [seed, custom]).isEmpty)
    }

    @MainActor @Test func systemSubcategory_excluded() {
        let cat = makeCategory()
        let a = makeSub(name: "Préstamo a grupos", isSystem: true, shortcutID: uuid(1), category: cat)
        let b = makeSub(name: "Préstamo a grupos", isSystem: true, shortcutID: uuid(2), category: cat)
        #expect(SubcategoryDedupLogic.duplicateGroups(in: [a, b]).isEmpty)
    }

    @MainActor @Test func orphanSubcategory_excluded() {
        let a = makeSub(name: "Seguro del hogar", shortcutID: uuid(1), category: nil)
        let b = makeSub(name: "Seguro del hogar", shortcutID: uuid(2), category: nil)
        #expect(SubcategoryDedupLogic.duplicateGroups(in: [a, b]).isEmpty)
    }

    @MainActor @Test func sameIconDifferentName_notMerged() {
        let cat = makeCategory()
        // Mismo sortOrder + icon pero distinto name → identidades distintas (filtro de seguridad).
        let a = makeSub(name: "Seguro del hogar", sortOrder: 4, shortcutID: uuid(1), category: cat)
        let b = makeSub(name: "Otra cosa", sortOrder: 4, shortcutID: uuid(2), category: cat)
        #expect(SubcategoryDedupLogic.duplicateGroups(in: [a, b]).isEmpty)
    }

    @MainActor @Test func crossCategory_notMerged() {
        let hogar = makeCategory(name: "Hogar", icon: "house.fill", color: "#475569")
        let compras = makeCategory(name: "Compras", icon: "bag.fill", color: "#F59E0B")
        // Mismo name/sortOrder/icon pero categorías distintas → grupos separados.
        let a = makeSub(name: "Otros", sortOrder: 2, icon: "ellipsis.circle.fill", shortcutID: uuid(1), category: hogar)
        let b = makeSub(name: "Otros", sortOrder: 2, icon: "ellipsis.circle.fill", shortcutID: uuid(2), category: compras)
        #expect(SubcategoryDedupLogic.duplicateGroups(in: [a, b]).isEmpty)
    }
}
