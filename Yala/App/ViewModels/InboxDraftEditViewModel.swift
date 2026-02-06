//
//  InboxDraftEditViewModel.swift
//  Yala
//
//  ViewModel para InboxDraftEditSheet - maneja pending drafts para "Aprobar siguiente".
//  Refactor D.8: @Query → ViewModel
//

import Foundation
import SwiftData

@MainActor
@Observable
final class InboxDraftEditViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var pendingDrafts: [InboxDraft] = []

    // MARK: - Setup

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadPendingDrafts()
    }

    func loadPendingDrafts() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { $0.statusRaw == "pending" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            pendingDrafts = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("InboxDraftEditViewModel: Error loading pending drafts: \(error)")
            #endif
        }
    }

    // MARK: - Helpers

    /// Next pending draft excluding the given one
    func nextPendingDraft(excluding draft: InboxDraft) -> InboxDraft? {
        pendingDrafts.first { $0.persistentModelID != draft.persistentModelID }
    }

    /// Check if there are more pending drafts after the given one
    func hasNextPendingDraft(excluding draft: InboxDraft) -> Bool {
        nextPendingDraft(excluding: draft) != nil
    }
}
