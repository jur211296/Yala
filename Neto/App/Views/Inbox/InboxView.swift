//
//  InboxView.swift
//  Neto
//
//  Bandeja de entrada para borradores de transacciones.
//  Fase 8: Registro Inteligente
//

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

// MARK: - InboxView

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("preferredCurrency") private var preferredCurrency: String = "PEN"

    @State private var selectedFilter: InboxFilter = .pending
    @State private var selectedDraft: InboxDraft?
    @State private var selectedTransaction: TransactionItem?

    // Selection mode
    @State private var isSelectionMode = false
    @State private var selectedDraftIDs: Set<PersistentIdentifier> = []
    @State private var showBulkActions = false

    // Query all drafts
    @Query(sort: \InboxDraft.createdAt, order: .reverse)
    private var allDrafts: [InboxDraft]


    private var filteredDrafts: [InboxDraft] {
        switch selectedFilter {
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

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: 0) {
                    // Filter chips
                    filterChips
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.sm)
                        .padding(.bottom, DS.Spacing.md)

                    // Content
                    if filteredDrafts.isEmpty {
                        Spacer()
                        emptyState
                        Spacer()
                    } else {
                        draftsList
                    }
                }
            }
            .navigationTitle(L10n.Inbox.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !filteredDrafts.isEmpty && selectedFilter == .pending {
                        Button {
                            withAnimation {
                                if isSelectionMode {
                                    exitSelectionMode()
                                } else {
                                    isSelectionMode = true
                                }
                            }
                        } label: {
                            Text(isSelectionMode ? L10n.Action.cancel : L10n.Action.multipleEdit)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.done) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedDraft) { draft in
                InboxDraftEditSheet(draft: draft)
            }
            .sheet(item: $selectedTransaction) { transaction in
                NewTransactionView(transactionToEdit: transaction)
            }
            .sheet(isPresented: $showBulkActions) {
                InboxBulkActionsSheet(
                    selectedDrafts: selectedDrafts,
                    onComplete: {
                        exitSelectionMode()
                    }
                )
            }
            .safeAreaInset(edge: .bottom) {
                if isSelectionMode {
                    selectionBar
                }
            }
        }
    }

    // MARK: - Selection Bar

    private var selectionBar: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Select all / Deselect all
            Button {
                withAnimation {
                    if selectedDraftIDs.count == filteredDrafts.count {
                        selectedDraftIDs.removeAll()
                    } else {
                        selectedDraftIDs = Set(filteredDrafts.map { $0.persistentModelID })
                    }
                }
            } label: {
                Image(systemName: selectedDraftIDs.count == filteredDrafts.count ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(Color.electricIndigo)
            }

            // Count
            Text(L10n.Inbox.selectedCount(selectedDraftIDs.count))
                .font(.subheadline.weight(.medium))

            Spacer()

            // Actions button
            Button {
                showBulkActions = true
            } label: {
                Text(L10n.Action.edit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(selectedDraftIDs.isEmpty ? Color.gray : Color.electricIndigo)
                    )
            }
            .disabled(selectedDraftIDs.isEmpty)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }

    private var selectedDrafts: [InboxDraft] {
        filteredDrafts.filter { selectedDraftIDs.contains($0.persistentModelID) }
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedDraftIDs.removeAll()
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(InboxFilter.allCases, id: \.self) { filter in
                filterChip(for: filter)
            }
            Spacer()
        }
    }

    private func filterChip(for filter: InboxFilter) -> some View {
        let isSelected = selectedFilter == filter
        let count = countForFilter(filter)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.displayName)
                    .font(.subheadline.weight(.medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Color.electricIndigo : Color.clear)
            )
            .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func countForFilter(_ filter: InboxFilter) -> Int {
        switch filter {
        case .pending:
            return allDrafts.filter { $0.status == .pending }.count
        case .archived:
            return allDrafts.filter { $0.status == .approved || $0.status == .rejected }.count
        }
    }

    // MARK: - Drafts List

    private var draftsList: some View {
        List {
            ForEach(filteredDrafts, id: \.persistentModelID) { draft in
                InboxDraftRowView(
                    draft: draft,
                    currencyCode: draft.displayCurrencyCode ?? preferredCurrency,
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedDraftIDs.contains(draft.persistentModelID),
                    onTap: {
                        if isSelectionMode {
                            toggleSelection(draft)
                        } else {
                            handleDraftTap(draft)
                        }
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: DS.Spacing.xs, leading: DS.Spacing.lg, bottom: DS.Spacing.xs, trailing: DS.Spacing.lg))
                .swipeActions(edge: .trailing, allowsFullSwipe: !isSelectionMode && selectedFilter == .pending) {
                    if !isSelectionMode && selectedFilter == .pending {
                        Button(role: .destructive) {
                            deleteDraft(draft)
                        } label: {
                            Label(L10n.Inbox.delete, systemImage: "trash")
                        }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: !isSelectionMode && draft.isReadyToApprove && selectedFilter == .pending) {
                    if !isSelectionMode && draft.isReadyToApprove && selectedFilter == .pending {
                        Button {
                            approveDraft(draft)
                        } label: {
                            Label(L10n.Inbox.approve, systemImage: "checkmark.circle")
                        }
                        .tint(Color.electricIndigo)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(nil, value: filteredDrafts.count)
    }

    private func toggleSelection(_ draft: InboxDraft) {
        withAnimation {
            if selectedDraftIDs.contains(draft.persistentModelID) {
                selectedDraftIDs.remove(draft.persistentModelID)
            } else {
                selectedDraftIDs.insert(draft.persistentModelID)
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        switch selectedFilter {
        case .pending:
            NetoEmptyState(
                icon: "tray",
                title: L10n.Inbox.noPending,
                message: L10n.Inbox.noPendingDescription
            )
        case .archived:
            NetoEmptyState(
                icon: "archivebox",
                title: L10n.Inbox.noArchived,
                message: L10n.Inbox.noArchivedDescription
            )
        }
    }

    // MARK: - Actions

    private func deleteDraft(_ draft: InboxDraft) {
        withAnimation {
            // Cache display values BEFORE changing status (if available)
            // (archived drafts use ONLY cached values to avoid accessing deleted relationships)
            if let account = draft.account {
                draft.cachedAccountName = account.name
                draft.cachedCurrencyCode = account.currencyCode
            }
            if let subcategory = draft.subcategory {
                draft.cachedSubcategoryName = subcategory.name
                draft.cachedCategoryColorHex = subcategory.category.colorHex
                draft.cachedSubcategoryIcon = subcategory.iconName ?? subcategory.category.iconName
            }

            draft.status = .rejected
            draft.updatedAt = Date()
            do {
                try modelContext.save()
            } catch {
                print("Error deleting draft: \(error)")
            }
        }
    }

    private func approveDraft(_ draft: InboxDraft) {
        guard let account = draft.account,
              let amount = draft.amount,
              let subcategory = draft.subcategory else { return }

        withAnimation {
            // Create TransactionItem
            let transaction = TransactionItem(
                date: draft.effectiveDate,
                amount: amount,
                currencyCode: account.currencyCode
            )
            transaction.note = draft.note.isEmpty ? nil : draft.note
            transaction.account = account
            transaction.subcategory = subcategory
            transaction.category = subcategory.category
            transaction.tags = draft.tags

            modelContext.insert(transaction)

            // Cache display values BEFORE changing status
            // (archived drafts use ONLY cached values to avoid accessing deleted relationships)
            draft.cachedAccountName = account.name
            draft.cachedSubcategoryName = subcategory.name
            draft.cachedCategoryColorHex = subcategory.category.colorHex
            draft.cachedSubcategoryIcon = subcategory.iconName ?? subcategory.category.iconName
            draft.cachedCurrencyCode = account.currencyCode

            // Update draft status and link to transaction
            draft.status = .approved
            draft.approvedTransaction = transaction
            draft.updatedAt = Date()

            do {
                try modelContext.save()
            } catch {
                print("Error approving draft: \(error)")
            }
        }
    }

    private func handleDraftTap(_ draft: InboxDraft) {
        switch draft.status {
        case .pending:
            // Show edit sheet for pending drafts
            selectedDraft = draft

        case .approved:
            // Check if we have a linked transaction
            if let transaction = draft.approvedTransaction {
                // Show the linked transaction
                selectedTransaction = transaction
            } else {
                // No linked transaction (old draft or transaction was deleted)
                // Allow re-approval by changing status to pending
                draft.status = .pending
                draft.updatedAt = Date()
                try? modelContext.save()
                selectedDraft = draft
            }

        case .rejected:
            // Allow re-attempting rejected drafts - change status back to pending and open editor
            draft.status = .pending
            draft.updatedAt = Date()
            try? modelContext.save()
            selectedDraft = draft
        }
    }

}

// MARK: - Preview

#Preview {
    InboxView()
        .modelContainer(for: InboxDraft.self, inMemory: true)
}
