//
//  InboxView.swift
//  Yala
//
//  Bandeja de entrada para borradores de transacciones.
//  Fase 8: Registro Inteligente
//

import SwiftData
import SwiftUI

// MARK: - InboxView

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(CurrencyConverter.self) private var currencyConverter
    @Environment(DraftService.self) private var draftService
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @AppStorage("defaultCurrencyCode") private var preferredCurrency: String = "PEN"

    /// Callback for navigating to Records tab (bulk approve success)
    var onNavigateToRecords: (() -> Void)?

    @State private var viewModel = InboxViewModel()
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

    // Archived account alert
    @State private var showArchivedAccountAlert = false

    private var filteredDrafts: [InboxDraft] {
        viewModel.filteredDrafts(for: selectedFilter)
    }

    private var groupedDrafts: [(date: Date, drafts: [InboxDraft])] {
        viewModel.groupedDrafts(for: selectedFilter)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: DS.Spacing.none) {
                    // Filter chips
                    filterChips
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.sm)
                        .padding(.bottom, DS.Spacing.md)

                    // Bulk action hint (shown when 2+ pending drafts and not in selection mode)
                    if !isSelectionMode && selectedFilter == .pending && filteredDrafts.count >= 2 {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "hand.tap")
                                .font(DS.Typography.captionSmall)
                            Text(L10n.Inbox.bulkHint)
                                .font(DS.Typography.caption)
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
                            dsWithAnimation(reduceMotion) {
                                exitSelectionMode()
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        let allSelected = selectedDraftIDs.count == filteredDrafts.count
                        Button(allSelected ? L10n.Export.deselectAll : L10n.Export.selectAll) {
                            dsWithAnimation(reduceMotion) {
                                if allSelected {
                                    selectedDraftIDs.removeAll()
                                } else {
                                    selectedDraftIDs = Set(filteredDrafts.map { $0.persistentModelID })
                                }
                            }
                        }
                    }
                } else {
                    // Normal mode: X left, selection icon right
                    ToolbarItem(placement: .topBarLeading) {
                        YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                            dismiss()
                        }
                    }
                    if !filteredDrafts.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            YalaToolbarButton(systemName: "checkmark.circle", label: L10n.Inbox.approveAll) {
                                dsWithAnimation(reduceMotion) {
                                    isSelectionMode = true
                                }
                            }
                        }
                    }
                }
            }
            .tint(.primary)
            .sheet(item: $selectedDraft, onDismiss: { viewModel.loadData() }) { draft in
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
                    if let nextDraft = viewModel.findPendingDraft(by: nextID) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedDraft = nextDraft
                        }
                    }
                }
            }
            .sheet(item: $selectedTransaction, onDismiss: { viewModel.loadData() }) { transaction in
                NewTransactionView(transactionToEdit: transaction)
            }
            .sheet(isPresented: $showBulkActions, onDismiss: { viewModel.loadData() }) {
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
                        hasNextDraft: viewModel.hasPendingDrafts,
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
                            if let next = viewModel.firstPendingDraft() {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    selectedDraft = next
                                }
                            }
                        }
                    )
                }
            }
            .alert(L10n.Inbox.cannotApprove, isPresented: $showArchivedAccountAlert) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(L10n.Inbox.errorArchivedAccount)
            }
            .safeAreaInset(edge: .bottom) {
                if isSelectionMode {
                    selectionBar
                }
            }
            .onAppear {
                viewModel.setContext(modelContext)
            }
            .onChange(of: sessionState.dataVersion) { _, _ in
                viewModel.loadData()
            }
        }
    }

    // MARK: - Selection Bar

    private var selectionBar: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Select all / Deselect all
            Button {
                dsWithAnimation(reduceMotion) {
                    if selectedDraftIDs.count == filteredDrafts.count {
                        selectedDraftIDs.removeAll()
                    } else {
                        selectedDraftIDs = Set(filteredDrafts.map { $0.persistentModelID })
                    }
                }
            } label: {
                Image(systemName: selectedDraftIDs.count == filteredDrafts.count ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title)
                    .foregroundStyle(theme.accent)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(selectedDraftIDs.count == filteredDrafts.count ? L10n.Filters.deselectAll : L10n.Filters.selectAll)

            // Count
            Text(L10n.Inbox.selectedCount(selectedDraftIDs.count))
                .font(DS.Typography.label)

            Spacer()

            // Actions button
            Button {
                showBulkActions = true
            } label: {
                Text(L10n.Action.edit)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .frame(minHeight: 44)
                    .background(
                        Capsule()
                            .fill(selectedDraftIDs.isEmpty ? DS.Semantic.disabledForeground : theme.accent)
                    )
            }
            .disabled(selectedDraftIDs.isEmpty)
            .accessibilityHint(selectedDraftIDs.isEmpty ? L10n.Accessibility.selectAtLeastOneDraft : "")
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
            dsWithAnimation(reduceMotion, .easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: filter.icon)
                    .font(DS.Typography.caption)
                Text(filter.displayName)
                    .font(DS.Typography.label)
                if count > 0 {
                    Text("\(count)")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, DS.Chip.paddingV)
                        .padding(.vertical, DS.Spacing.xxs)
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
                    .fill(isSelected ? theme.accent : Color.clear)
            )
            .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func countForFilter(_ filter: InboxFilter) -> Int {
        viewModel.countForFilter(filter)
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
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private static let sectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.sectionDateFormatter.string(from: date)
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
                    .tint(DS.Semantic.errorForeground)

                    Button {
                        rejectDraft(draft)
                    } label: {
                        Label(L10n.Inbox.reject, systemImage: "xmark.circle")
                    }
                    .tint(DS.Semantic.warningForeground)
                } else if draft.status == .rejected {
                    // Archived (rejected only): Delete
                    Button {
                        deleteDraftPermanently(draft)
                    } label: {
                        Label(L10n.Inbox.delete, systemImage: "trash")
                    }
                    .tint(DS.Semantic.errorForeground)
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

            }
        }
    }

    private func toggleSelection(_ draft: InboxDraft) {
        dsWithAnimation(reduceMotion) {
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

        dsWithAnimation(reduceMotion) {
            draftService.setContext(modelContext)
            do {
                try draftService.rejectDraft(draft)
            } catch {
                #if DEBUG
                print("InboxView: Error rejecting draft: \(error)")
                #endif
            }
        }
    }

    private func deleteDraftPermanently(_ draft: InboxDraft) {
        // Haptic feedback for destructive action
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        dsWithAnimation(reduceMotion) {
            draftService.setContext(modelContext)
            do {
                try draftService.deleteDraft(draft)
                viewModel.loadData()
            } catch {
                #if DEBUG
                print("InboxView: Error deleting draft: \(error)")
                #endif
            }
        }
    }

    private func approveDraft(_ draft: InboxDraft) {
        guard let account = draft.account,
              let amount = draft.amount,
              let subcategory = draft.subcategory else { return }

        // Block approval if account is archived
        if account.isArchived {
            showArchivedAccountAlert = true
            return
        }

        // Haptic feedback for positive action
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        dsWithAnimation(reduceMotion) {
            draftService.setContext(modelContext)
            do {
                let transaction = try draftService.approveDraft(
                    draft,
                    currencyConverter: currencyConverter
                )

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
                    categoryName: subcategory.safeCategory.name,
                    categoryColorHex: subcategory.safeCategory.colorHex,
                    isExpense: amount < 0
                )
                showSwipeSuccessView = true
            } catch {
                #if DEBUG
                print("InboxView: Error approving draft: \(error)")
                #endif
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
                draftService.setContext(modelContext)
                do {
                    try draftService.returnToPending(draft)
                } catch {
                    #if DEBUG
                    print("InboxView: Error returning draft to pending: \(error)")
                    #endif
                }
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
