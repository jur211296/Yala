//
//  CategoryDeduplicationServiceTests.swift
//  YalaTests
//
//  Tests for CategoryDeduplicationService.identityKey and grouping logic.
//

import Foundation
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
}
