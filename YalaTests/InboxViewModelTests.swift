//
//  InboxViewModelTests.swift
//  YalaTests
//
//  Unit tests for InboxViewModel - Pure logic tests (no SwiftData context)
//

import Foundation
import Testing

@testable import Yala

struct InboxViewModelTests {

    // MARK: - Filter Logic Tests

    @MainActor
    @Test("Filter pending returns only pending drafts")
    func filterPendingReturnsOnlyPending() async {
        let vm = InboxViewModel()

        // Simulate draft statuses
        let result = vm.filterDrafts(
            statuses: [.pending, .approved, .pending, .rejected],
            cachedAccountNames: [nil, "Account", nil, "Account"],
            for: .pending
        )

        #expect(result == [0, 2]) // Indices of pending drafts
    }

    @MainActor
    @Test("Filter archived returns approved and rejected with cached names")
    func filterArchivedReturnsApprovedAndRejected() async {
        let vm = InboxViewModel()

        // Only drafts with cachedAccountName are included in archived
        let result = vm.filterDrafts(
            statuses: [.pending, .approved, .rejected, .approved],
            cachedAccountNames: [nil, "Account1", "Account2", nil],
            for: .archived
        )

        #expect(result == [1, 2]) // Indices of archived drafts with cached names
    }

    @MainActor
    @Test("Filter archived excludes drafts without cached account name")
    func filterArchivedExcludesMissingCachedName() async {
        let vm = InboxViewModel()

        // Approved draft without cachedAccountName is excluded
        let result = vm.filterDrafts(
            statuses: [.approved, .approved],
            cachedAccountNames: [nil, "Account"],
            for: .archived
        )

        #expect(result == [1]) // Only the one with cached name
    }

    @MainActor
    @Test("Filter pending returns empty when no pending")
    func filterPendingEmptyWhenNoPending() async {
        let vm = InboxViewModel()

        let result = vm.filterDrafts(
            statuses: [.approved, .rejected],
            cachedAccountNames: ["A", "B"],
            for: .pending
        )

        #expect(result.isEmpty)
    }

    // MARK: - Count Logic Tests

    @MainActor
    @Test("Count pending returns correct number")
    func countPendingReturnsCorrect() async {
        let vm = InboxViewModel()

        let count = vm.countDrafts(
            statuses: [.pending, .approved, .pending, .rejected, .pending],
            for: .pending
        )

        #expect(count == 3)
    }

    @MainActor
    @Test("Count archived returns approved and rejected count")
    func countArchivedReturnsCorrect() async {
        let vm = InboxViewModel()

        let count = vm.countDrafts(
            statuses: [.pending, .approved, .rejected, .approved],
            for: .archived
        )

        #expect(count == 3) // 2 approved + 1 rejected
    }

    @MainActor
    @Test("Count returns zero when empty")
    func countReturnsZeroWhenEmpty() async {
        let vm = InboxViewModel()

        let pendingCount = vm.countDrafts(statuses: [], for: .pending)
        let archivedCount = vm.countDrafts(statuses: [], for: .archived)

        #expect(pendingCount == 0)
        #expect(archivedCount == 0)
    }

    // MARK: - Grouping Logic Tests

    @MainActor
    @Test("Group by date creates correct groups")
    func groupByDateCreatesCorrectGroups() async {
        let vm = InboxViewModel()
        let calendar = Calendar.current

        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let groups = vm.groupDraftsByDate(
            dates: [today, yesterday, today, yesterday],
            indices: [0, 1, 2, 3]
        )

        #expect(groups.count == 2)
        // Most recent first
        #expect(groups[0].indices.count == 2) // Today's drafts
        #expect(groups[1].indices.count == 2) // Yesterday's drafts
    }

    @MainActor
    @Test("Group by date sorts newest first")
    func groupByDateSortsNewestFirst() async {
        let vm = InboxViewModel()
        let calendar = Calendar.current

        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let groups = vm.groupDraftsByDate(
            dates: [twoDaysAgo, today, yesterday],
            indices: [0, 1, 2]
        )

        #expect(groups.count == 3)
        #expect(groups[0].date == calendar.startOfDay(for: today))
        #expect(groups[1].date == calendar.startOfDay(for: yesterday))
        #expect(groups[2].date == calendar.startOfDay(for: twoDaysAgo))
    }

    @MainActor
    @Test("Group empty returns empty")
    func groupEmptyReturnsEmpty() async {
        let vm = InboxViewModel()

        let groups = vm.groupDraftsByDate(dates: [], indices: [])

        #expect(groups.isEmpty)
    }
}
