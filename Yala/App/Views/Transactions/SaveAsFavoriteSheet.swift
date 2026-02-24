//
//  SaveAsFavoriteSheet.swift
//  Yala
//
//  Sheet for saving current transaction as a favorite template.
//

import SwiftData
import SwiftUI

struct SaveAsFavoriteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    @State private var viewModel = SaveAsFavoriteViewModel()

    // Initial values from transaction
    let transactionType: TransactionType
    let initialAmount: Double
    let initialNote: String
    let initialAccount: Account?
    let initialSubcategory: Subcategory?
    let initialTags: [Tag]
    let natureOverride: SubcategoryNature?
    let currencyCode: String

    // Callback for success
    let onSaved: (String) -> Void

    // Editable state
    @State private var name: String = ""
    @State private var selectedAccount: Account?
    @State private var selectedSubcategory: Subcategory?
    @State private var selectedTags: Set<PersistentIdentifier> = []
    @State private var amount: Double = 0
    @State private var note: String = ""
    @State private var includeAmount: Bool = true
    @State private var includeNote: Bool = true

    // Sheet states
    @State private var showAccountSelector = false
    @State private var showSubcategorySelector = false
    @State private var showTagSelector = false

    @FocusState private var isNameFocused: Bool

    init(
        transactionType: TransactionType,
        amount: Double,
        note: String,
        account: Account?,
        subcategory: Subcategory?,
        tags: [Tag],
        natureOverride: SubcategoryNature?,
        currencyCode: String,
        onSaved: @escaping (String) -> Void
    ) {
        self.transactionType = transactionType
        self.initialAmount = amount
        self.initialNote = note
        self.initialAccount = account
        self.initialSubcategory = subcategory
        self.initialTags = tags
        self.natureOverride = natureOverride
        self.currencyCode = currencyCode
        self.onSaved = onSaved

        self._name = State(initialValue: note)
        self._selectedAccount = State(initialValue: account)
        self._selectedSubcategory = State(initialValue: subcategory)
        self._selectedTags = State(initialValue: Set(tags.map { $0.persistentModelID }))
        self._amount = State(initialValue: amount)
        self._note = State(initialValue: note)
        self._includeAmount = State(initialValue: amount > 0)
        self._includeNote = State(initialValue: !note.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Name Section
                    nameSection

                    // Fields Section
                    fieldsSection

                    // Info text
                    Text(L10n.Favorites.saveDescription)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Save button
                    YalaPrimaryButton(
                        L10n.Action.save,
                        isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty
                    ) {
                        saveFavorite()
                    }
                    .padding(.top, DS.Spacing.md)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                PanelBackgroundView()
                    .dismissKeyboardOnTap()
            )
            .navigationTitle(L10n.Action.saveAsFavorite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAccountSelector) {
                AccountSelectorSheet(selectedAccount: $selectedAccount)
            }
            .sheet(isPresented: $showSubcategorySelector) {
                SubcategorySelectorSheet(
                    selectedSubcategory: $selectedSubcategory,
                    transactionType: transactionType
                )
            }
            .sheet(isPresented: $showTagSelector) {
                tagSelectorSheet
            }
        }
        .onAppear {
            viewModel.setContext(modelContext)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFocused = true
            }
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        SectionBox(title: "") {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "star")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                TextField(L10n.Favorites.namePlaceholder, text: $name)
                    .focused($isNameFocused)
            }
            .padding()
        }
    }

    // MARK: - Fields Section

    private var fieldsSection: some View {
        SectionBox(title: L10n.Common.details) {
            VStack(spacing: DS.Spacing.none) {
                // Account
                fieldRow(
                    icon: "creditcard",
                    label: L10n.Transaction.account,
                    value: selectedAccount?.name,
                    color: selectedAccount.map { Color(hex: $0.colorHex) },
                    onTap: { showAccountSelector = true },
                    onClear: { selectedAccount = nil }
                )

                SubsectionDivider()

                // Subcategory
                fieldRow(
                    icon: "tag",
                    label: L10n.Transaction.subcategory,
                    value: selectedSubcategory?.name,
                    color: selectedSubcategory.map { Color(hex: $0.colorHex ?? $0.safeCategory.colorHex) },
                    onTap: { showSubcategorySelector = true },
                    onClear: { selectedSubcategory = nil }
                )

                SubsectionDivider()

                // Tags
                tagsRow

                SubsectionDivider()

                // Amount toggle
                amountRow

                if includeNote || !note.isEmpty {
                    SubsectionDivider()
                    noteRow
                }
            }
        }
    }

    private func fieldRow(
        icon: String,
        label: String,
        value: String?,
        color: Color? = nil,
        onTap: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .foregroundStyle(.primary)

            Spacer()

            if let value = value {
                Button(action: onTap) {
                    HStack(spacing: DS.Spacing.xs) {
                        if let color = color {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                        }
                        Text(value)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onTap) {
                    Text(L10n.Common.select)
                        .foregroundStyle(.thAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .contentShape(Rectangle())
    }

    private var tagsRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "number")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(L10n.Settings.tags)
                .foregroundStyle(.primary)

            Spacer()

            if selectedTags.isEmpty {
                Button { showTagSelector = true } label: {
                    Text(L10n.Common.select)
                        .foregroundStyle(.thAccent)
                }
                .buttonStyle(.plain)
            } else {
                Button { showTagSelector = true } label: {
                    Text("\(selectedTags.count)")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button { selectedTags.removeAll() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .contentShape(Rectangle())
    }

    private var amountRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "dollarsign.circle")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(L10n.Transaction.amount)
                .foregroundStyle(.primary)

            Spacer()

            if includeAmount && amount > 0 {
                Text(YalaFormatter.currency(value: amount, currencyCode: currencyCode, forceFullPrecision: true))
                    .foregroundStyle(.secondary)

                Button { includeAmount = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Toggle(L10n.Transaction.amount, isOn: $includeAmount)
                    .labelsHidden()

            }
        }
        .padding()
    }

    private var noteRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "note.text")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(L10n.Transaction.note)
                .foregroundStyle(.primary)

            Spacer()

            if !note.isEmpty {
                Text(note)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button { note = ""; includeNote = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    // MARK: - Tag Selector Sheet

    private var tagSelectorSheet: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        if viewModel.activeTags.isEmpty {
                            YalaEmptyState(
                                icon: "tag.slash",
                                title: L10n.Empty.noTags,
                                message: L10n.Empty.tagsDescription
                            )
                        } else {
                            SectionBox(title: "") {
                                VStack(spacing: DS.Spacing.none) {
                                    ForEach(Array(viewModel.activeTags.enumerated()), id: \.element.persistentModelID) { index, tag in
                                        if index > 0 {
                                            SubsectionDivider()
                                        }
                                        Button {
                                            if selectedTags.contains(tag.persistentModelID) {
                                                selectedTags.remove(tag.persistentModelID)
                                            } else {
                                                selectedTags.insert(tag.persistentModelID)
                                            }
                                        } label: {
                                            HStack(spacing: DS.Spacing.md) {
                                                Circle()
                                                    .fill(Color(hex: tag.colorHex))
                                                    .frame(width: 28, height: 28)
                                                    .overlay(
                                                        Image(systemName: tag.iconName)
                                                            .font(DS.Typography.labelSmall)
                                                            .foregroundStyle(.white)
                                                    )

                                                Text(tag.name)
                                                    .font(DS.Typography.body)
                                                    .foregroundStyle(.primary)

                                                Spacer()

                                                if selectedTags.contains(tag.persistentModelID) {
                                                    Image(systemName: "checkmark")
                                                        .font(DS.Typography.headline)
                                                        .foregroundStyle(.thAccent)
                                                }
                                            }
                                            .padding(.horizontal, DS.Spacing.lg)
                                            .padding(.vertical, DS.FormRow.paddingV)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
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
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        showTagSelector = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { showTagSelector = false })
                }
            }
        }

        .presentationDetents([.medium, .large])
    }

    // MARK: - Save

    private func saveFavorite() {
        let finalName = name.trimmingCharacters(in: .whitespaces)
        guard !finalName.isEmpty else { return }

        do {
            try viewModel.saveFavorite(
                name: finalName,
                transactionType: transactionType,
                amount: includeAmount && amount > 0 ? amount : nil,
                note: includeNote && !note.isEmpty ? note : nil,
                account: selectedAccount,
                subcategory: selectedSubcategory,
                selectedTagIDs: selectedTags,
                natureOverride: natureOverride,
                currencyCode: currencyCode
            )
            onSaved(L10n.Action.savedAsFavorite)
            dismiss()
        } catch {
            #if DEBUG
            print("Error saving favorite: \(error)")
            #endif
        }
    }
}
