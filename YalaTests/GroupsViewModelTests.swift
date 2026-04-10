//
//  GroupsViewModelTests.swift
//  YalaTests
//
//  Tests for GroupsViewModel — initial state, UI navigation, computed properties.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct GroupsViewModelTests {

    // MARK: - Initial State

    @Test func initialState_allEmpty() {
        let vm = GroupsViewModel()

        #expect(vm.groups.isEmpty)
        #expect(vm.membersByGroup.isEmpty)
        #expect(vm.balancesByGroup.isEmpty)
        #expect(vm.globalSummary == nil)
        #expect(vm.showCreateGroup == false)
        #expect(vm.selectedGroup == nil)
        #expect(vm.showGroupDetail == false)
        #expect(vm.searchText.isEmpty)
        #expect(vm.showArchived == false)
    }

    @Test func computedGroups_emptyWhenNoData() {
        let vm = GroupsViewModel()
        #expect(vm.activeGroups.isEmpty)
        #expect(vm.archivedGroups.isEmpty)
        #expect(vm.filteredGroups.isEmpty)
    }

    // MARK: - Navigation State

    @Test func openDetail_setsState() {
        let vm = GroupsViewModel()
        let group = SplitGroup(name: "Test Group")

        vm.openDetail(for: group)

        #expect(vm.selectedGroup != nil)
        #expect(vm.selectedGroup?.name == "Test Group")
        #expect(vm.showGroupDetail == true)
    }

    @Test func openDetail_replacesExisting() {
        let vm = GroupsViewModel()
        let group1 = SplitGroup(name: "Group 1")
        let group2 = SplitGroup(name: "Group 2")

        vm.openDetail(for: group1)
        vm.openDetail(for: group2)

        #expect(vm.selectedGroup?.name == "Group 2")
    }

    // MARK: - Member Count & Balance Helpers

    @Test func memberCount_noData_returnsZero() {
        let vm = GroupsViewModel()
        let group = SplitGroup(name: "Empty")

        #expect(vm.memberCount(for: group) == 0)
    }

    @Test func currentUserBalance_noData_returnsNil() {
        let vm = GroupsViewModel()
        let group = SplitGroup(name: "Empty")

        #expect(vm.currentUserBalance(for: group) == nil)
    }

    // MARK: - loadData without context

    @Test func loadData_withoutContext_doesNotCrash() {
        let vm = GroupsViewModel()
        vm.loadData()

        #expect(vm.groups.isEmpty)
    }
}
