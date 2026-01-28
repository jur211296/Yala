//
//  InboxBulkActionsSheet.swift
//  Neto
//
//  Sheet para acciones en lote sobre drafts seleccionados.
//  Fase 8: Registro Inteligente - Subfase 8.2
//

import SwiftData
import SwiftUI

// MARK: - Bulk Action Option

enum InboxBulkOption: String, Identifiable {
    case account
    case subcategory
    case approve
    case reject
    case delete
    case returnToPending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: return L10n.Settings.accounts
        case .subcategory: return L10n.Transaction.subcategory
        case .approve: return L10n.Inbox.approve
        case .reject: return L10n.Inbox.reject
        case .delete: return L10n.Inbox.delete
        case .returnToPending: return L10n.Inbox.returnToPending
        }
    }

    var icon: String {
        switch self {
        case .account: return "building.columns"
        case .subcategory: return "folder"
        case .approve: return "checkmark.circle"
        case .reject: return "xmark.circle"
        case .delete: return "trash"
        case .returnToPending: return "arrow.uturn.backward"
        }
    }

    var iconColor: Color {
        switch self {
        case .account: return .blue
        case .subcategory: return .purple
        case .approve: return .green
        case .reject: return .orange
        case .delete: return .red
        case .returnToPending: return .teal
        }
    }
}

// MARK: - Inbox Bulk Actions Sheet

struct InboxBulkActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.name) private var accounts: [Account]

    let selectedDrafts: [InboxDraft]
    let filter: InboxFilter
    let onComplete: () -> Void

    /// Callback for navigating to Records tab
    var onNavigateToRecords: (() -> Void)?

    private var availableOptions: [InboxBulkOption] {
        switch filter {
        case .pending:
            return [.account, .subcategory, .approve, .reject, .delete]
        case .archived:
            return [.returnToPending, .delete]
        }
    }

    // Sheet navigation state
    @State private var showAccountSelector = false
    @State private var showSubcategorySelector = false
    @State private var showDeleteConfirmation = false

    // Track applied changes
    @State private var appliedChanges: Set<InboxBulkOption> = []

    // Selected values
    @State private var selectedAccount: Account?
    @State private var selectedSubcategory: Subcategory?

    // Bulk approve success
    @State private var showBulkSuccessView = false
    @State private var bulkApprovedCount = 0

    private var approveableCount: Int {
        selectedDrafts.filter { $0.isReadyToApprove }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if showBulkSuccessView {
                    InboxBulkApproveSuccessView(
                        approvedCount: bulkApprovedCount,
                        onViewRecords: {
                            onNavigateToRecords?()
                            finishEditing()
                        },
                        onBackToInbox: {
                            finishEditing()
                        }
                    )
                } else {
                    ZStack {
                        PanelBackgroundView()

                        ScrollView {
                            VStack(spacing: DS.Spacing.xxl) {
                                // Header with count
                                Text(L10n.Inbox.selectedCount(selectedDrafts.count))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // Options list
                                SectionBox(title: "") {
                                    VStack(spacing: 0) {
                                        ForEach(Array(availableOptions.enumerated()), id: \.element.id) { index, option in
                                            if index > 0 {
                                                SubsectionDivider()
                                            }

                                            bulkOptionRow(option)
                                        }
                                    }
                                }

                                // Applied changes summary
                                if !appliedChanges.isEmpty {
                                    appliedChangesSummary
                                }
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.xxl)
                        }
                    }
                    .navigationTitle(L10n.Action.edit)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            YalaToolbarButton(systemName: "xmark") {
                                finishEditing()
                            }
                        }

                        if !appliedChanges.isEmpty {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(L10n.Action.done) {
                                    finishEditing()
                                }
                                .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showAccountSelector) {
                AccountSelectorSheet(selectedAccount: $selectedAccount)
                    .onDisappear {
                        if let account = selectedAccount {
                            applyAccountChange(account)
                        }
                    }
            }
            .sheet(isPresented: $showSubcategorySelector) {
                SubcategorySelectorSheet(
                    selectedSubcategory: $selectedSubcategory,
                    transactionType: .expense
                )
                .onDisappear {
                    if let subcategory = selectedSubcategory {
                        applySubcategoryChange(subcategory)
                    }
                }
            }
            .alert(L10n.Alert.confirmDelete, isPresented: $showDeleteConfirmation) {
                Button(L10n.Action.cancel, role: .cancel) {}
                Button(L10n.Action.delete, role: .destructive) {
                    deleteSelected()
                }
            } message: {
                Text(L10n.Inbox.deleteConfirmMessage(selectedDrafts.count))
            }
        }
        .tint(Color.electricIndigo)
    }

    // MARK: - Option Row

    private func bulkOptionRow(_ option: InboxBulkOption) -> some View {
        let isApplied = appliedChanges.contains(option)
        let isDisabled = option == .approve && approveableCount == 0

        return Button {
            handleOptionTap(option)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                Circle()
                    .fill(option.iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: option.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(option.iconColor)
                    )

                // Title with subtitle for approve
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.body)
                        .foregroundStyle(isDisabled ? .tertiary : .primary)

                    if option == .approve && approveableCount < selectedDrafts.count {
                        Text(L10n.Inbox.approveableCount(approveableCount, selectedDrafts.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Applied checkmark or chevron
                if isApplied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                } else if !isDisabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    // MARK: - Applied Changes Summary

    private var appliedChangesSummary: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(L10n.BulkEdit.successMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .cornerRadius(DS.Radius.md)
    }

    // MARK: - Actions

    private func handleOptionTap(_ option: InboxBulkOption) {
        switch option {
        case .account:
            selectedAccount = nil
            showAccountSelector = true
        case .subcategory:
            selectedSubcategory = nil
            showSubcategorySelector = true
        case .approve:
            approveSelected()
        case .reject:
            rejectSelected()
        case .delete:
            showDeleteConfirmation = true
        case .returnToPending:
            returnToPendingSelected()
        }
    }

    private func applyAccountChange(_ account: Account) {
        for draft in selectedDrafts {
            draft.account = account
            draft.updatedAt = Date()
            updateNeedsUserInput(draft)
        }
        saveChanges()
        appliedChanges.insert(.account)
    }

    private func applySubcategoryChange(_ subcategory: Subcategory) {
        for draft in selectedDrafts {
            draft.subcategory = subcategory
            draft.updatedAt = Date()
            updateNeedsUserInput(draft)
        }
        saveChanges()
        appliedChanges.insert(.subcategory)
    }

    private func approveSelected() {
        var approvedCount = 0

        let preferredCode = CurrencyDefaults.currentPreferred

        for draft in selectedDrafts where draft.isReadyToApprove {
            guard let account = draft.account,
                  let amount = draft.amount,
                  let subcategory = draft.subcategory else { continue }

            // Calculate amount in preferred currency for charts/statistics
            let amountInPreferred = CurrencyConverter.shared.convert(
                Decimal(amount),
                from: account.currencyCode,
                to: preferredCode,
                on: draft.effectiveDate,
                context: modelContext
            )
            let exchangeRate: Double
            if abs(amount) > 0.0001 {
                exchangeRate = (amountInPreferred as NSDecimalNumber).doubleValue / amount
            } else {
                exchangeRate = 1.0
            }

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
            transaction.exchangeRate = abs(exchangeRate)
            transaction.amountInPreferredCurrency = (amountInPreferred as NSDecimalNumber).doubleValue
            transaction.preferredCurrencyCode = preferredCode

            modelContext.insert(transaction)

            // Cache display values BEFORE changing status
            draft.cachedAccountName = account.name
            draft.cachedSubcategoryName = subcategory.name
            draft.cachedCategoryColorHex = subcategory.category.colorHex
            draft.cachedSubcategoryIcon = subcategory.iconName ?? subcategory.category.iconName
            draft.cachedCurrencyCode = account.currencyCode

            draft.status = .approved
            draft.approvedTransaction = transaction
            draft.updatedAt = Date()
            approvedCount += 1
        }

        saveChanges()
        appliedChanges.insert(.approve)

        // Show bulk success view
        if approvedCount > 0 {
            bulkApprovedCount = approvedCount
            withAnimation(.easeOut(duration: 0.3)) {
                showBulkSuccessView = true
            }
        }
    }

    private func rejectSelected() {
        for draft in selectedDrafts {
            // Cache values for display in archived list
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
        }
        saveChanges()
        appliedChanges.insert(.reject)
        finishEditing()
    }

    private func deleteSelected() {
        for draft in selectedDrafts {
            modelContext.delete(draft)
        }
        saveChanges()
        appliedChanges.insert(.delete)
        finishEditing()
    }

    private func returnToPendingSelected() {
        for draft in selectedDrafts {
            draft.status = .pending
            draft.updatedAt = Date()
            updateNeedsUserInput(draft)
        }
        saveChanges()
        appliedChanges.insert(.returnToPending)
        finishEditing()
    }

    private func updateNeedsUserInput(_ draft: InboxDraft) {
        var needs: [String] = []
        if draft.account == nil { needs.append("account") }
        if draft.subcategory == nil { needs.append("subcategory") }
        if draft.amount == nil { needs.append("amount") }
        draft.needsUserInput = needs
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving bulk changes: \(error)")
        }
    }

    private func finishEditing() {
        onComplete()
        dismiss()
    }
}

#Preview {
    InboxBulkActionsSheet(
        selectedDrafts: [],
        filter: .pending,
        onComplete: {}
    )
}
