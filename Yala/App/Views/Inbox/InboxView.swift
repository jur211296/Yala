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

    /// Callback for navigating to Records tab (bulk approve success)
    var onNavigateToRecords: (() -> Void)?

    @State private var selectedFilter: InboxFilter = .pending
    @State private var selectedDraft: InboxDraft?
    @State private var selectedTransaction: TransactionItem?

    // Selection mode
    @State private var isSelectionMode = false
    @State private var selectedDraftIDs: Set<PersistentIdentifier> = []
    @State private var showBulkActions = false

    // Success view state (for swipe approve)
    @State private var showSwipeSuccessView = false
    @State private var swipeSuccessData: InboxApproveSuccessData?
    @State private var swipeApprovedTransaction: TransactionItem?

    // Pending next draft (for "Approve Next" flow)
    @State private var pendingNextDraftID: PersistentIdentifier?

    // Query all drafts
    @Query(sort: \InboxDraft.createdAt, order: .reverse)
    private var allDrafts: [InboxDraft]

    // Query for pending drafts (needed for "Approve Next")
    @Query(
        filter: #Predicate<InboxDraft> { $0.statusRaw == "pending" },
        sort: \InboxDraft.createdAt,
        order: .reverse
    ) private var pendingDrafts: [InboxDraft]


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

    /// Drafts grouped by transaction date (effectiveDate), sorted newest first
    private var groupedDrafts: [(date: Date, drafts: [InboxDraft])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredDrafts) { draft in
            calendar.startOfDay(for: draft.effectiveDate)
        }
        return grouped
            .map { (date: $0.key, drafts: $0.value.sorted { $0.effectiveDate > $1.effectiveDate }) }
            .sorted { $0.date > $1.date }
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

                    // Bulk action hint (shown when 2+ pending drafts and not in selection mode)
                    if !isSelectionMode && selectedFilter == .pending && filteredDrafts.count >= 2 {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "hand.tap")
                                .font(.caption2)
                            Text(L10n.Inbox.bulkHint)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.bottom, DS.Spacing.sm)
                    }

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
                if isSelectionMode {
                    // Selection mode: Cancel left, Select All right
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L10n.Action.cancel) {
                            withAnimation {
                                exitSelectionMode()
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.Export.selectAll) {
                            withAnimation {
                                selectedDraftIDs = Set(filteredDrafts.map { $0.persistentModelID })
                            }
                        }
                    }
                } else {
                    // Normal mode: X left, selection icon right
                    ToolbarItem(placement: .topBarLeading) {
                        YalaToolbarButton(systemName: "xmark") {
                            dismiss()
                        }
                    }
                    if !filteredDrafts.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            YalaToolbarButton(systemName: "checkmark.circle") {
                                withAnimation {
                                    isSelectionMode = true
                                }
                            }
                        }
                    }
                }
            }
            .tint(.primary)
            .sheet(item: $selectedDraft) { draft in
                InboxDraftEditSheet(
                    draft: draft,
                    onApproved: nil,
                    onApproveNext: { nextDraft in
                        // Store the ID and close sheet - onChange will open the next
                        pendingNextDraftID = nextDraft.persistentModelID
                    },
                    onEditTransaction: { transaction in
                        // Open transaction editor after sheet dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedTransaction = transaction
                        }
                    }
                )
            }
            .onChange(of: selectedDraft) { oldValue, newValue in
                // When sheet closes and we have a pending next draft, open it
                if oldValue != nil && newValue == nil, let nextID = pendingNextDraftID {
                    pendingNextDraftID = nil
                    // Find the draft by ID and open it
                    if let nextDraft = pendingDrafts.first(where: { $0.persistentModelID == nextID }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedDraft = nextDraft
                        }
                    }
                }
            }
            .sheet(item: $selectedTransaction) { transaction in
                NewTransactionView(transactionToEdit: transaction)
            }
            .sheet(isPresented: $showBulkActions) {
                InboxBulkActionsSheet(
                    selectedDrafts: selectedDrafts,
                    filter: selectedFilter,
                    onComplete: {
                        exitSelectionMode()
                    },
                    onNavigateToRecords: {
                        // Call parent's navigation callback and dismiss
                        onNavigateToRecords?()
                        dismiss()
                    }
                )
            }
            .sheet(isPresented: $showSwipeSuccessView) {
                if let data = swipeSuccessData {
                    InboxApproveSuccessView(
                        data: data,
                        hasNextDraft: !pendingDrafts.isEmpty,
                        onEdit: {
                            showSwipeSuccessView = false
                            if let transaction = swipeApprovedTransaction {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    selectedTransaction = transaction
                                }
                            }
                        },
                        onAccept: {
                            showSwipeSuccessView = false
                        },
                        onApproveNext: {
                            showSwipeSuccessView = false
                            if let next = pendingDrafts.first {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    selectedDraft = next
                                }
                            }
                        }
                    )
                }
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
                    .frame(minWidth: 44, minHeight: 44)
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
                    .frame(minHeight: 44)
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
            .frame(minHeight: 44)
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
            ForEach(groupedDrafts, id: \.date) { group in
                Section {
                    ForEach(group.drafts, id: \.persistentModelID) { draft in
                        draftRow(for: draft)
                    }
                } header: {
                    Text(formattedDate(group.date))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter.string(from: date)
    }

    private func draftRow(for draft: InboxDraft) -> some View {
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
        .swipeActions(edge: .trailing, allowsFullSwipe: !isSelectionMode && (selectedFilter == .pending || draft.status == .rejected)) {
            if !isSelectionMode {
                if selectedFilter == .pending {
                    // Pending: Delete + Reject
                    Button {
                        deleteDraftPermanently(draft)
                    } label: {
                        Label(L10n.Inbox.delete, systemImage: "trash")
                    }
                    .tint(.red)

                    Button {
                        rejectDraft(draft)
                    } label: {
                        Label(L10n.Inbox.reject, systemImage: "xmark.circle")
                    }
                    .tint(.orange)
                } else if draft.status == .rejected {
                    // Archived (rejected only): Delete
                    Button {
                        deleteDraftPermanently(draft)
                    } label: {
                        Label(L10n.Inbox.delete, systemImage: "trash")
                    }
                    .tint(.red)
                }
                // Approved drafts in archived: no swipe actions
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
            YalaEmptyState(
                icon: "tray",
                title: L10n.Inbox.noPending,
                message: L10n.Inbox.noPendingDescription
            )
        case .archived:
            YalaEmptyState(
                icon: "archivebox",
                title: L10n.Inbox.noArchived,
                message: L10n.Inbox.noArchivedDescription
            )
        }
    }

    // MARK: - Actions

    private func rejectDraft(_ draft: InboxDraft) {
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

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
                print("Error rejecting draft: \(error)")
            }
        }
    }

    private func deleteDraftPermanently(_ draft: InboxDraft) {
        // Haptic feedback for destructive action
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        withAnimation {
            modelContext.delete(draft)
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

        // Haptic feedback for positive action
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

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

                // Prepare and show success view
                swipeApprovedTransaction = transaction
                swipeSuccessData = InboxApproveSuccessData(
                    date: draft.effectiveDate,
                    accountName: account.name,
                    accountColorHex: account.colorHex,
                    note: draft.note,
                    amount: amount,
                    currencyCode: account.currencyCode,
                    subcategoryName: subcategory.name,
                    categoryName: subcategory.category.name,
                    categoryColorHex: subcategory.category.colorHex,
                    isExpense: amount < 0
                )
                showSwipeSuccessView = true
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
            // Open editor for rejected drafts (status stays .rejected until user takes action)
            selectedDraft = draft
        }
    }

}

// MARK: - Preview

#Preview {
    InboxView()
        .modelContainer(for: InboxDraft.self, inMemory: true)
}
