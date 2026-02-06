//
//  BulkEditSheet.swift
//  Yala
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

    @State private var bulkEditViewModel = BulkEditViewModel()

    @Bindable var viewModel: RecordsViewModel
    let selectedCount: Int
    let onComplete: () -> Void

    // Sheet navigation state
    @State private var showAccountSelector = false
    @State private var showSubcategorySelector = false
    @State private var showTagEditor = false
    @State private var showNoteEditor = false
    @State private var showAmountEditor = false

    // Track applied changes
    @State private var appliedChanges: Set<BulkEditOption> = []

    // Selected values for editing
    @State private var selectedAccount: Account?
    @State private var selectedSubcategory: Subcategory?
    @State private var bulkNote: String = ""
    @State private var bulkAmount: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        // Header with count
                        Text(L10n.BulkEdit.editCount(selectedCount))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Options list
                        SectionBox(title: "") {
                            VStack(spacing: 0) {
                                ForEach(Array(BulkEditOption.allCases.enumerated()), id: \.element.id) { index, option in
                                    if index > 0 {
                                        SubsectionDivider()
                                    }

                                    BulkEditOptionRow(
                                        option: option,
                                        isApplied: appliedChanges.contains(option)
                                    ) {
                                        handleOptionTap(option)
                                    }
                                }
                            }
                        }

                        // Currency warning for account changes
                        if appliedChanges.contains(.account) || showAccountSelector {
                            currencyWarning
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
            .sheet(isPresented: $showTagEditor) {
                BulkTagEditorSheet(
                    viewModel: viewModel,
                    allTags: bulkEditViewModel.activeTags,
                    onApply: { tagsToAdd, tagsToRemove in
                        applyTagChanges(add: tagsToAdd, remove: tagsToRemove)
                    }
                )
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
        .onAppear {
            bulkEditViewModel.setContext(modelContext)
        }
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
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
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
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
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
            showTagEditor = true
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
        appliedChanges.insert(.account)
        onComplete()
    }

    private func applySubcategoryChange(_ subcategory: Subcategory) {
        viewModel.bulkUpdateSubcategory(subcategory, context: modelContext)
        appliedChanges.insert(.subcategory)
        onComplete()
    }

    private func applyTagChanges(add tagsToAdd: [Tag], remove tagsToRemove: [Tag]) {
        if !tagsToAdd.isEmpty {
            viewModel.bulkAddTags(tagsToAdd, context: modelContext)
        }
        if !tagsToRemove.isEmpty {
            viewModel.bulkRemoveTags(tagsToRemove, context: modelContext)
        }
        if !tagsToAdd.isEmpty || !tagsToRemove.isEmpty {
            appliedChanges.insert(.tag)
            onComplete()
        }
    }

    private func applyNoteChange(_ note: String) {
        viewModel.bulkUpdateNote(note, context: modelContext)
        appliedChanges.insert(.note)
        onComplete()
    }

    private func applyAmountChange(_ amount: Double) {
        viewModel.bulkUpdateAmount(amount, context: modelContext)
        appliedChanges.insert(.amount)
        onComplete()
    }

    private func finishEditing() {
        viewModel.exitSelectionMode()
        dismiss()
    }
}

// MARK: - Bulk Edit Option Row

private struct BulkEditOptionRow: View {
    let option: BulkEditOption
    let isApplied: Bool
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

                // Applied checkmark or chevron
                if isApplied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                } else {
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
    }
}

// MARK: - Bulk Tag Editor Sheet

struct BulkTagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: RecordsViewModel
    let allTags: [Tag]
    let onApply: ([Tag], [Tag]) -> Void

    @State private var tagsToAdd: Set<PersistentIdentifier> = []
    @State private var tagsToRemove: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        // Common tags section (tags that ALL selected transactions have)
                        if !commonTags.isEmpty {
                            SectionBox(title: L10n.BulkEdit.commonTags) {
                                VStack(spacing: 0) {
                                    ForEach(Array(commonTags.enumerated()), id: \.element.persistentModelID) { index, tag in
                                        if index > 0 {
                                            SubsectionDivider()
                                        }
                                        BulkTagRow(
                                            tag: tag,
                                            state: tagState(for: tag),
                                            onToggle: { toggleTag(tag) }
                                        )
                                    }
                                }
                            }
                        }

                        // Partial tags section (tags that SOME selected transactions have)
                        if !partialTags.isEmpty {
                            SectionBox(title: L10n.BulkEdit.partialTags) {
                                VStack(spacing: 0) {
                                    ForEach(Array(partialTags.enumerated()), id: \.element.persistentModelID) { index, tag in
                                        if index > 0 {
                                            SubsectionDivider()
                                        }
                                        BulkTagRow(
                                            tag: tag,
                                            state: tagState(for: tag),
                                            onToggle: { toggleTag(tag) }
                                        )
                                    }
                                }
                            }
                        }

                        // Available tags section (tags that NO selected transactions have)
                        if !availableTags.isEmpty {
                            SectionBox(title: L10n.BulkEdit.availableTags) {
                                VStack(spacing: 0) {
                                    ForEach(Array(availableTags.enumerated()), id: \.element.persistentModelID) { index, tag in
                                        if index > 0 {
                                            SubsectionDivider()
                                        }
                                        BulkTagRow(
                                            tag: tag,
                                            state: tagState(for: tag),
                                            onToggle: { toggleTag(tag) }
                                        )
                                    }
                                }
                            }
                        }

                        if allTags.isEmpty {
                            YalaEmptyState(
                                icon: "tag.slash",
                                title: L10n.Empty.noTags,
                                message: L10n.Empty.tagsDescription
                            )
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Settings.tags)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton {
                        let addTags = allTags.filter { tagsToAdd.contains($0.persistentModelID) }
                        let removeTags = allTags.filter { tagsToRemove.contains($0.persistentModelID) }
                        onApply(addTags, removeTags)
                        dismiss()
                    }
                    .disabled(tagsToAdd.isEmpty && tagsToRemove.isEmpty)
                }
            }
        }
        .tint(Color.electricIndigo)
    }

    // MARK: - Tag Analysis

    private var selectedTransactionTags: [[Tag]] {
        viewModel.getSelectedTransactionTags()
    }

    private var commonTags: [Tag] {
        guard !selectedTransactionTags.isEmpty else { return [] }
        let allTagSets = selectedTransactionTags.map { Set($0.map { $0.persistentModelID }) }
        guard let first = allTagSets.first else { return [] }
        let commonIDs = allTagSets.dropFirst().reduce(first) { $0.intersection($1) }
        return allTags.filter { commonIDs.contains($0.persistentModelID) }
    }

    private var partialTags: [Tag] {
        guard selectedTransactionTags.count > 1 else { return [] }
        let allTagSets = selectedTransactionTags.map { Set($0.map { $0.persistentModelID }) }
        let allUsedIDs = allTagSets.reduce(Set<PersistentIdentifier>()) { $0.union($1) }
        let commonIDs = Set(commonTags.map { $0.persistentModelID })
        let partialIDs = allUsedIDs.subtracting(commonIDs)
        return allTags.filter { partialIDs.contains($0.persistentModelID) }
    }

    private var availableTags: [Tag] {
        let usedIDs = Set(commonTags.map { $0.persistentModelID })
            .union(Set(partialTags.map { $0.persistentModelID }))
        return allTags.filter { !usedIDs.contains($0.persistentModelID) }
    }

    // MARK: - Tag State

    enum TagState {
        case toAdd      // Will be added
        case toRemove   // Will be removed
        case common     // All have it, no change
        case partial    // Some have it, no change
        case available  // None have it, no change
    }

    private func tagState(for tag: Tag) -> TagState {
        let id = tag.persistentModelID
        if tagsToAdd.contains(id) { return .toAdd }
        if tagsToRemove.contains(id) { return .toRemove }
        if commonTags.contains(where: { $0.persistentModelID == id }) { return .common }
        if partialTags.contains(where: { $0.persistentModelID == id }) { return .partial }
        return .available
    }

    private func toggleTag(_ tag: Tag) {
        let id = tag.persistentModelID
        let isCommon = commonTags.contains(where: { $0.persistentModelID == id })
        let isPartial = partialTags.contains(where: { $0.persistentModelID == id })

        if tagsToAdd.contains(id) {
            // Was marked to add → mark for removal (or back to original if common)
            tagsToAdd.remove(id)
            if isPartial {
                // Partial: add → remove cycle
                tagsToRemove.insert(id)
            }
            // If was common or available, just go back to original state
        } else if tagsToRemove.contains(id) {
            // Was marked to remove → back to original state
            tagsToRemove.remove(id)
        } else if isCommon {
            // Common tag (all have) → mark for removal
            tagsToRemove.insert(id)
        } else if isPartial {
            // Partial tag (some have) → mark for add to all
            tagsToAdd.insert(id)
        } else {
            // Available tag (none have) → mark for add
            tagsToAdd.insert(id)
        }
    }
}

// MARK: - Bulk Tag Row

private struct BulkTagRow: View {
    let tag: Tag
    let state: BulkTagEditorSheet.TagState
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DS.Spacing.md) {
                // Checkbox indicator (left side, clear selection state)
                checkboxIndicator

                // Color circle with icon
                Circle()
                    .fill(Color(hex: tag.colorHex))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: tag.iconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                // Tag name
                Text(tag.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var checkboxIndicator: some View {
        switch state {
        case .toAdd, .common:
            // Checked - tag will be present after save
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.electricIndigo)
        case .toRemove, .available:
            // Unchecked - tag will NOT be present after save
            Image(systemName: "square")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
        case .partial:
            // Mixed state - some have it, some don't
            Image(systemName: "minus.square.fill")
                .font(.system(size: 22))
                .foregroundStyle(.orange)
        }
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
                    YalaToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton {
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
                    YalaToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton {
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
