//
//  ViewModelFilterTests.swift
//  YalaTests
//
//  Tests for filter state logic in ScheduledPaymentsViewModel.
//  Pure Set mutation tests — models created without ModelContext to avoid CloudKit crashes.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct ViewModelFilterTests {

    // MARK: - ScheduledPaymentsViewModel: hasActiveFilters

    @MainActor @Test func scheduledPayments_hasActiveFilters_noFilters_false() {
        let vm = ScheduledPaymentsViewModel()
        #expect(vm.hasActiveFilters == false)
    }

    @MainActor @Test func scheduledPayments_hasActiveFilters_withAccount_true() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let vm = ScheduledPaymentsViewModel()
        vm.selectedAccounts.insert(account.persistentModelID)
        #expect(vm.hasActiveFilters == true)
    }

    // MARK: - ScheduledPaymentsViewModel: activeFilterCount

    @MainActor @Test func scheduledPayments_activeFilterCount_none() {
        let vm = ScheduledPaymentsViewModel()
        #expect(vm.activeFilterCount == 0)
    }

    @MainActor @Test func scheduledPayments_activeFilterCount_accountAndTag() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let tag = Tag(name: "Tag1", colorHex: "#000", iconName: "tag")
        let vm = ScheduledPaymentsViewModel()
        vm.selectedAccounts.insert(account.persistentModelID)
        vm.selectedTags.insert(tag.persistentModelID)
        #expect(vm.activeFilterCount == 2)
    }

    @MainActor @Test func scheduledPayments_activeFilterCount_categoryAndSubcategoryCountAsOne() {
        let category = YalaCategory(name: "Cat", colorHex: "#000", isIncome: false)
        let sub = Subcategory(name: "Sub", colorHex: nil, natureRawValue: "essential", iconName: "cart", category: category)
        let vm = ScheduledPaymentsViewModel()
        vm.selectedCategories.insert(category.persistentModelID)
        vm.selectedSubcategories.insert(sub.persistentModelID)
        // Categories + subcategories count as 1 filter group
        #expect(vm.activeFilterCount == 1)
    }

    // MARK: - ScheduledPaymentsViewModel: clearFilters

    @MainActor @Test func scheduledPayments_clearFilters_resetsAll() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let tag = Tag(name: "Tag1", colorHex: "#000", iconName: "tag")
        let vm = ScheduledPaymentsViewModel()
        vm.selectedAccounts.insert(account.persistentModelID)
        vm.selectedTags.insert(tag.persistentModelID)
        vm.clearFilters()
        #expect(vm.hasActiveFilters == false)
        #expect(vm.activeFilterCount == 0)
    }
}
