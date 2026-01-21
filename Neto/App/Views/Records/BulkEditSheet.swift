//
//  BulkEditSheet.swift
//  Neto
//
//  Sheet for bulk editing multiple transactions.
//

import SwiftData
import SwiftUI

// MARK: - Bulk Edit Option

enum BulkEditOption: String, CaseIterable, Identifiable {
    case account
    case subcategory
    case tag
    case note
    case amount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: return L10n.Settings.accounts
        case .subcategory: return L10n.Transaction.subcategory
        case .tag: return L10n.Settings.tags
        case .note: return L10n.Transaction.note
        case .amount: return L10n.Transaction.amount
        }
    }

    var icon: String {
        switch self {
        case .account: return "building.columns"
        case .subcategory: return "folder"
        case .tag: return "tag"
        case .note: return "note.text"
        case .amount: return "dollarsign.circle"
        }
    }

    var iconColor: Color {
        switch self {
        case .account: return .blue
        case .subcategory: return .purple
        case .tag: return .orange
        case .note: return .green
        case .amount: return .pink
        }
    }
}

// MARK: - Bulk Edit Sheet

struct BulkEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Tag.name) private var tags: [Tag]

    @Bindable var viewModel: RecordsViewModel
    let selectedCount: Int
    let onComplete: () -> Void

    // Sheet navigation state
    @State private var showAccountSelector = false
    @State private var showSubcategorySelector = false
    @State private var showTagSelector = false
    @State private var showNoteEditor = false
    @State private var showAmountEditor = false

    // Selected values for editing
    @State private var selectedAccount: Account?
    @State private var selectedSubcategory: Subcategory?
    @State private var selectedTags: [Tag] = []
    @State private var bulkNote: String = ""
    @State private var bulkAmount: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        // Options list
                        SectionBox(title: "") {
                            VStack(spacing: 0) {
                                ForEach(Array(BulkEditOption.allCases.enumerated()), id: \.element.id) { index, option in
                                    if index > 0 {
                                        SubsectionDivider()
                                    }

                                    BulkEditOptionRow(option: option) {
                                        handleOptionTap(option)
                                    }
                                }
                            }
                        }

                        // Currency warning for account changes
                        if showAccountSelector || selectedAccount != nil {
                            currencyWarning
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
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
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
            .sheet(isPresented: $showTagSelector) {
                TagSelectorSheet(selectedTags: $selectedTags)
                    .onDisappear {
                        if !selectedTags.isEmpty {
                            applyTagChange(selectedTags)
                        }
                    }
            }
            .sheet(isPresented: $showNoteEditor) {
                BulkNoteEditorSheet(note: $bulkNote) {
                    applyNoteChange(bulkNote)
                }
            }
            .sheet(isPresented: $showAmountEditor) {
                BulkAmountEditorSheet(amount: $bulkAmount) {
                    applyAmountChange(bulkAmount)
                }
            }
        }
        .tint(Color.electricIndigo)
    }

    // MARK: - Currency Warning

    private var currencyWarning: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(L10n.BulkEdit.currencyWarning)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(DS.Radius.md)
    }

    // MARK: - Actions

    private func handleOptionTap(_ option: BulkEditOption) {
        switch option {
        case .account:
            selectedAccount = nil
            showAccountSelector = true
        case .subcategory:
            selectedSubcategory = nil
            showSubcategorySelector = true
        case .tag:
            selectedTags = []
            showTagSelector = true
        case .note:
            bulkNote = ""
            showNoteEditor = true
        case .amount:
            bulkAmount = 0
            showAmountEditor = true
        }
    }

    private func applyAccountChange(_ account: Account) {
        viewModel.bulkUpdateAccount(account, context: modelContext)
        onComplete()
        dismiss()
    }

    private func applySubcategoryChange(_ subcategory: Subcategory) {
        viewModel.bulkUpdateSubcategory(subcategory, context: modelContext)
        onComplete()
        dismiss()
    }

    private func applyTagChange(_ tags: [Tag]) {
        viewModel.bulkAddTags(tags, context: modelContext)
        onComplete()
        dismiss()
    }

    private func applyNoteChange(_ note: String) {
        viewModel.bulkUpdateNote(note, context: modelContext)
        onComplete()
        dismiss()
    }

    private func applyAmountChange(_ amount: Double) {
        viewModel.bulkUpdateAmount(amount, context: modelContext)
        onComplete()
        dismiss()
    }
}

// MARK: - Bulk Edit Option Row

private struct BulkEditOptionRow: View {
    let option: BulkEditOption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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

                // Title
                Text(option.title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bulk Note Editor Sheet

struct BulkNoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var note: String
    let onSave: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                    .dismissKeyboardOnTap()

                VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: "") {
                        TextField(L10n.Transaction.notePlaceholder, text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.FormRow.paddingV)
                            .focused($isFocused)
                    }

                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .navigationTitle(L10n.Transaction.note)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NetoSaveButton {
                        onSave()
                        dismiss()
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
        .tint(Color.electricIndigo)
    }
}

// MARK: - Bulk Amount Editor Sheet

struct BulkAmountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var amount: Double
    let onSave: () -> Void

    @State private var amountText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                    .dismissKeyboardOnTap()

                VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: "") {
                        HStack {
                            TextField("0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(.title2.weight(.semibold))
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .focused($isFocused)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .navigationTitle(L10n.Transaction.amount)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NetoSaveButton {
                        if let value = Double(amountText.replacingOccurrences(of: ",", with: ".")) {
                            amount = value
                            onSave()
                        }
                        dismiss()
                    }
                    .disabled(amountText.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
        .tint(Color.electricIndigo)
    }
}

#Preview {
    BulkEditSheet(
        viewModel: RecordsViewModel(context: .empty),
        selectedCount: 3,
        onComplete: {}
    )
}
