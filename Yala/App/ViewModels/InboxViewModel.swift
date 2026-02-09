//
//  InboxViewModel.swift
//  Yala
//
//  ViewModel para InboxView - maneja drafts de transacciones.
//  Refactor D.8: @Query → ViewModel
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Filter Type

enum InboxFilter: String, CaseIterable {
    case pending
    case archived

    var displayName: String {
        switch self {
        case .pending:
            return L10n.Inbox.pending
        case .archived:
            return L10n.Inbox.archived
        }
    }

    var icon: String {
        switch self {
        case .pending:
            return "tray.full"
        case .archived:
            return "archivebox"
        }
    }
}

@MainActor
@Observable
final class InboxViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allDrafts: [InboxDraft] = []
    private(set) var pendingDrafts: [InboxDraft] = []

    // MARK: - Setup

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    func loadData() {
        loadAllDrafts()
        loadPendingDrafts()
    }

    private func loadAllDrafts() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<InboxDraft>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            allDrafts = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("InboxViewModel: Error loading all drafts: \(error)")
            #endif
        }
    }

    private func loadPendingDrafts() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { $0.statusRaw == "pending" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            pendingDrafts = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("InboxViewModel: Error loading pending drafts: \(error)")
            #endif
        }
    }

    // MARK: - Computed Properties

    func filteredDrafts(for filter: InboxFilter) -> [InboxDraft] {
        switch filter {
        case .pending:
            return allDrafts.filter { $0.status == .pending }
        case .archived:
            // Only show archived drafts that have cached values (to avoid crashes from invalid relationships)
            return allDrafts.filter {
                ($0.status == .approved || $0.status == .rejected) &&
                $0.cachedAccountName != nil
            }
        }
    }

    /// Drafts grouped by transaction date (effectiveDate), sorted newest first
    func groupedDrafts(for filter: InboxFilter) -> [(date: Date, drafts: [InboxDraft])] {
        let filtered = filteredDrafts(for: filter)
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { draft in
            calendar.startOfDay(for: draft.effectiveDate)
        }
        return grouped
            .map { (date: $0.key, drafts: $0.value.sorted {
                if $0.effectiveDate == $1.effectiveDate { return $0.createdAt > $1.createdAt }
                return $0.effectiveDate > $1.effectiveDate
            }) }
            .sorted { $0.date > $1.date }
    }

    func countForFilter(_ filter: InboxFilter) -> Int {
        switch filter {
        case .pending:
            return allDrafts.filter { $0.status == .pending }.count
        case .archived:
            return allDrafts.filter { $0.status == .approved || $0.status == .rejected }.count
        }
    }

    // MARK: - Draft Lookup

    func findPendingDraft(by id: PersistentIdentifier) -> InboxDraft? {
        pendingDrafts.first { $0.persistentModelID == id }
    }

    func firstPendingDraft() -> InboxDraft? {
        pendingDrafts.first
    }

    var hasPendingDrafts: Bool {
        !pendingDrafts.isEmpty
    }

    // MARK: - Pure Logic Functions (for testing)

    /// Filter drafts by status (testable without SwiftData)
    func filterDrafts(
        statuses: [DraftStatus],
        cachedAccountNames: [String?],
        for filter: InboxFilter
    ) -> [Int] {
        var result: [Int] = []
        for i in 0..<statuses.count {
            let status = statuses[i]
            let cachedName = cachedAccountNames[i]

            switch filter {
            case .pending:
                if status == .pending {
                    result.append(i)
                }
            case .archived:
                if (status == .approved || status == .rejected) && cachedName != nil {
                    result.append(i)
                }
            }
        }
        return result
    }

    /// Count drafts by filter (testable without SwiftData)
    func countDrafts(statuses: [DraftStatus], for filter: InboxFilter) -> Int {
        switch filter {
        case .pending:
            return statuses.filter { $0 == .pending }.count
        case .archived:
            return statuses.filter { $0 == .approved || $0 == .rejected }.count
        }
    }

    /// Group drafts by date (testable without SwiftData)
    func groupDraftsByDate(dates: [Date], indices: [Int]) -> [(date: Date, indices: [Int])] {
        guard !dates.isEmpty else { return [] }

        let calendar = Calendar.current
        var grouped: [Date: [Int]] = [:]

        for i in 0..<dates.count {
            let dayStart = calendar.startOfDay(for: dates[i])
            grouped[dayStart, default: []].append(indices[i])
        }

        return grouped
            .map { (date: $0.key, indices: $0.value) }
            .sorted { $0.date > $1.date }
    }
}
