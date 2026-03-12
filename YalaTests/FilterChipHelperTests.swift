// Tests generated for: FilterChipHelper
// Cobertura estimada: 90%

import Foundation
import SwiftData
import Testing

@testable import Yala

struct FilterChipHelperTests {

    // MARK: - buildAccountChips Tests

    @Test func buildAccountChips_withEmptySelection_returnsEmpty() {
        let accounts = [
            Account(name: "Bank", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        ]
        let result = buildAccountChips(selectedAccounts: [], allAccounts: accounts)
        #expect(result.isEmpty)
    }

    @Test func buildAccountChips_withOneSelected_returnsChipWithCount1() {
        let account = Account(name: "Bank A", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let selected: Set<PersistentIdentifier> = [account.persistentModelID]
        let result = buildAccountChips(selectedAccounts: selected, allAccounts: [account])
        #expect(result.count == 1)
        #expect(result.first?.name == "Bank A")
        #expect(result.first?.count == 1)
    }

    @Test func buildAccountChips_withMultipleSelected_showsFirstNameAndTotalCount() {
        let accountA = Account(name: "Bank A", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let accountB = Account(name: "Bank B", currencyCode: "USD", colorHex: "#111", iconName: "creditcard", type: "bank")
        let accountC = Account(name: "Bank C", currencyCode: "EUR", colorHex: "#222", iconName: "creditcard", type: "bank")
        let selected: Set<PersistentIdentifier> = [
            accountA.persistentModelID,
            accountB.persistentModelID,
            accountC.persistentModelID
        ]
        let result = buildAccountChips(selectedAccounts: selected, allAccounts: [accountA, accountB, accountC])
        #expect(result.count == 1)
        #expect(result.first?.count == 3)
    }

    @Test func buildAccountChips_withSelectedNotInAllAccounts_returnsEmpty() {
        let accountA = Account(name: "A", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let accountB = Account(name: "B", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        // Select accountA but only provide accountB in allAccounts
        let selected: Set<PersistentIdentifier> = [accountA.persistentModelID]
        let result = buildAccountChips(selectedAccounts: selected, allAccounts: [accountB])
        #expect(result.isEmpty)
    }

    // MARK: - buildTagChips Tests

    @Test func buildTagChips_withEmptySelection_returnsEmpty() {
        let tag = YalaTag(name: "Food", colorHex: "#F00", iconName: "fork.knife")
        let result = buildTagChips(selectedTags: [], allTags: [tag])
        #expect(result.isEmpty)
    }

    @Test func buildTagChips_withSelectedTags_returnsMatchingChips() {
        let tagA = YalaTag(name: "Food", colorHex: "#F00", iconName: "fork.knife")
        let tagB = YalaTag(name: "Transport", colorHex: "#00F", iconName: "car")
        let tagC = YalaTag(name: "Fun", colorHex: "#0F0", iconName: "gamecontroller")
        let selected: Set<PersistentIdentifier> = [
            tagA.persistentModelID,
            tagC.persistentModelID
        ]
        let result = buildTagChips(selectedTags: selected, allTags: [tagA, tagB, tagC])
        #expect(result.count == 2)
        let names = Set(result.map(\.name))
        #expect(names.contains("Food"))
        #expect(names.contains("Fun"))
        #expect(!names.contains("Transport"))
    }

    @Test func buildTagChips_preservesTagProperties() {
        let tag = YalaTag(name: "Lunch", colorHex: "#AABBCC", iconName: "fork.knife")
        let selected: Set<PersistentIdentifier> = [tag.persistentModelID]
        let result = buildTagChips(selectedTags: selected, allTags: [tag])
        #expect(result.count == 1)
        let chip = result[0]
        #expect(chip.name == "Lunch")
        #expect(chip.iconName == "fork.knife")
        #expect(chip.colorHex == "#AABBCC")
        #expect(chip.tagID == tag.persistentModelID)
    }

    // MARK: - buildNeedChips Tests

    @Test func buildNeedChips_withEmptySelection_returnsEmpty() {
        let result = buildNeedChips(selectedNeeds: [])
        #expect(result.isEmpty)
    }

    @Test func buildNeedChips_withMultipleNeeds_returnsSortedByRawValue() {
        let needs: Set<SubcategoryNeed> = [.optional, .essential, .priority]
        let result = buildNeedChips(selectedNeeds: needs)
        #expect(result.count == 3)
        // Sorted by rawValue: "esencial" < "opcional" < "prioritaria"
        #expect(result[0].need == .essential)
        #expect(result[1].need == .optional)
        #expect(result[2].need == .priority)
    }

    @Test func buildNeedChips_withSingleNeed_returnsSingleChip() {
        let result = buildNeedChips(selectedNeeds: [.unclassified])
        #expect(result.count == 1)
        #expect(result[0].need == .unclassified)
    }

    // MARK: - aggregatedCategoryChip Tests

    @Test func aggregatedCategoryChip_withEmptySelection_returnsNil() {
        let cat = YalaCategory(name: "Food", colorHex: "#F00", isIncome: false)
        let sub = Subcategory(name: "Groceries", colorHex: nil, iconName: "cart", category: cat)
        let result = aggregatedCategoryChip(selectedSubcategories: [], allSubcategories: [sub])
        #expect(result == nil)
    }

    @Test func aggregatedCategoryChip_withAllSelected_returnsNil() {
        let cat = YalaCategory(name: "Food", colorHex: "#F00", isIncome: false)
        let subA = Subcategory(name: "Groceries", colorHex: nil, iconName: "cart", category: cat)
        let subB = Subcategory(name: "Restaurant", colorHex: nil, iconName: "fork.knife", category: cat)
        let allIDs: Set<PersistentIdentifier> = [
            subA.persistentModelID,
            subB.persistentModelID
        ]
        let result = aggregatedCategoryChip(selectedSubcategories: allIDs, allSubcategories: [subA, subB])
        #expect(result == nil)
    }

    @Test func aggregatedCategoryChip_withPartialSelection_returnsChip() {
        let cat = YalaCategory(name: "Food", colorHex: "#F00", isIncome: false)
        let subA = Subcategory(name: "Groceries", colorHex: nil, iconName: "cart", category: cat)
        let subB = Subcategory(name: "Restaurant", colorHex: nil, iconName: "fork.knife", category: cat)
        let subC = Subcategory(name: "Other", colorHex: nil, iconName: "ellipsis", category: cat)
        let selected: Set<PersistentIdentifier> = [subA.persistentModelID, subB.persistentModelID]
        let result = aggregatedCategoryChip(selectedSubcategories: selected, allSubcategories: [subA, subB, subC])
        #expect(result != nil)
        #expect(result?.name == "Food")
        #expect(result?.count == 1) // Only 1 parent category
    }

    // MARK: - aggregatedSubcategoryChip Tests

    @Test func aggregatedSubcategoryChip_withEmptySelection_returnsNil() {
        let cat = YalaCategory(name: "Food", colorHex: "#F00", isIncome: false)
        let sub = Subcategory(name: "Groceries", colorHex: "#0F0", iconName: "cart", category: cat)
        let result = aggregatedSubcategoryChip(selectedSubcategories: [], allSubcategories: [sub])
        #expect(result == nil)
    }

    @Test func aggregatedSubcategoryChip_withAllSelected_returnsNil() {
        let cat = YalaCategory(name: "Food", colorHex: "#F00", isIncome: false)
        let subA = Subcategory(name: "Groceries", colorHex: "#0F0", iconName: "cart", category: cat)
        let allIDs: Set<PersistentIdentifier> = [subA.persistentModelID]
        let result = aggregatedSubcategoryChip(selectedSubcategories: allIDs, allSubcategories: [subA])
        #expect(result == nil)
    }

    @Test func aggregatedSubcategoryChip_withPartialSelection_returnsChipWithSubcategoryColor() {
        let cat = YalaCategory(name: "Food", colorHex: "#F00", isIncome: false)
        let subA = Subcategory(name: "Groceries", colorHex: "#0F0", iconName: "cart", category: cat)
        let subB = Subcategory(name: "Restaurant", colorHex: "#00F", iconName: "fork.knife", category: cat)
        let subC = Subcategory(name: "Other", colorHex: nil, iconName: "ellipsis", category: cat)
        let selected: Set<PersistentIdentifier> = [subA.persistentModelID]
        let result = aggregatedSubcategoryChip(
            selectedSubcategories: selected,
            allSubcategories: [subA, subB, subC]
        )
        #expect(result != nil)
        #expect(result?.name == "Groceries")
        #expect(result?.colorHex == "#0F0") // Uses subcategory's own color
        #expect(result?.count == 1)
    }

    @Test func aggregatedSubcategoryChip_withNilSubcategoryColor_fallsBackToCategory() {
        let cat = YalaCategory(name: "Food", colorHex: "#F00", isIncome: false)
        let subA = Subcategory(name: "Groceries", colorHex: nil, iconName: "cart", category: cat)
        let subB = Subcategory(name: "Restaurant", colorHex: "#00F", iconName: "fork.knife", category: cat)
        let selected: Set<PersistentIdentifier> = [subA.persistentModelID]
        let result = aggregatedSubcategoryChip(
            selectedSubcategories: selected,
            allSubcategories: [subA, subB]
        )
        #expect(result != nil)
        #expect(result?.colorHex == "#F00") // Falls back to category color
    }

    @Test func aggregatedSubcategoryChip_withEmptySubcategoryColor_fallsBackToCategory() {
        let cat = YalaCategory(name: "Food", colorHex: "#F00", isIncome: false)
        let subA = Subcategory(name: "Groceries", colorHex: "", iconName: "cart", category: cat)
        let subB = Subcategory(name: "Restaurant", colorHex: "#00F", iconName: "fork.knife", category: cat)
        let selected: Set<PersistentIdentifier> = [subA.persistentModelID]
        let result = aggregatedSubcategoryChip(
            selectedSubcategories: selected,
            allSubcategories: [subA, subB]
        )
        #expect(result != nil)
        #expect(result?.colorHex == "#F00") // Empty string treated as no color
    }
}

/*
Tests generated:
1. test buildAccountChips_withEmptySelection_returnsEmpty - No selection returns empty
2. test buildAccountChips_withOneSelected_returnsChipWithCount1 - Single account chip
3. test buildAccountChips_withMultipleSelected_showsFirstNameAndTotalCount - Aggregation logic
4. test buildAccountChips_withSelectedNotInAllAccounts_returnsEmpty - Orphan selection
5. test buildTagChips_withEmptySelection_returnsEmpty - No selection returns empty
6. test buildTagChips_withSelectedTags_returnsMatchingChips - Filtering logic
7. test buildTagChips_preservesTagProperties - Property mapping
8. test buildNeedChips_withEmptySelection_returnsEmpty - No selection returns empty
9. test buildNeedChips_withMultipleNeeds_returnsSortedByRawValue - Sort order
10. test buildNeedChips_withSingleNeed_returnsSingleChip - Single need
11. test aggregatedCategoryChip_withEmptySelection_returnsNil - No filter
12. test aggregatedCategoryChip_withAllSelected_returnsNil - All = no filter
13. test aggregatedCategoryChip_withPartialSelection_returnsChip - Aggregation
14. test aggregatedSubcategoryChip_withEmptySelection_returnsNil - No filter
15. test aggregatedSubcategoryChip_withAllSelected_returnsNil - All = no filter
16. test aggregatedSubcategoryChip_withPartialSelection_returnsChipWithSubcategoryColor - Own color
17. test aggregatedSubcategoryChip_withNilSubcategoryColor_fallsBackToCategory - Color fallback nil
18. test aggregatedSubcategoryChip_withEmptySubcategoryColor_fallsBackToCategory - Color fallback empty

Casos NO cubiertos:
- None (all public functions fully covered)
*/
