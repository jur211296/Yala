//
//  InboxViewModel.swift
//  Neto
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
            print("InboxViewModel: Error loading all drafts: \(error)")
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
            print("InboxViewModel: Error loading pending drafts: \(error)")
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
            .map { (date: $0.key, drafts: $0.value.sorted { $0.effectiveDate > $1.effectiveDate }) }
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
}
