//
//  BulkEditSheet.swift
//  Yala
//
//  Sheet for bulk editing multiple transactions.
//
//  Auditoría UX 2.2 · L8-13 (decisión de Jürgen, 2026-10-15): se elige primero y se aplica después. Cada opción deja
//  su cambio PENDIENTE; el resumen dice qué va a cambiar («Cuenta → Ahorros») y «Aplicar a N registros» lo aplica
//  todo de una vez, o nada si algo está bloqueado (`RecordsViewModel.applyBulkEdit`). Antes cada opción se aplicaba
//  al elegirla, sin resumen ni vuelta atrás.
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

    /// En singular: se elige UNA cuenta para todos (antes decía «Cuentas»).
    var title: String {
        switch self {
        case .account: return L10n.Transaction.account
        case .subcategory: return L10n.Transaction.subcategory
        case .tag: return L10n.Transaction.tags
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

    // A11Y-DM: paleta decorativa por tipo de campo (colores de sistema, adaptan a Dark Mode)
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
    @Environment(AppPreferences.self) private var appPreferences

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

    // Detected transaction type for subcategory filtering
    private var detectedTransactionType: TransactionType? {
        viewModel.getSelectedTransactionType()
    }

    // Lo que se está escribiendo en las hojas de nota y monto (pasa a `changes` al guardar).
    @State private var bulkNote: String = ""
    @State private var bulkAmount: Double = 0

    private var changes: BulkEditChanges { bulkEditViewModel.changes }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header with count
                    Text(L10n.UXL8B.BulkEdit.title(selectedCount))
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("bulk_edit_title")

                        // Options list
                        SectionBox(title: "") {
                            VStack(spacing: DS.Spacing.none) {
                                ForEach(Array(BulkEditOption.allCases.enumerated()), id: \.element.id) { index, option in
                                    if index > 0 {
                                        SubsectionDivider()
                                    }

                                    let isDisabled = isOptionDisabled(option)
                                    BulkEditOptionRow(
                                        option: option,
                                        subtitle: subtitle(for: option),
                                        isPending: changes.changedOptions.contains(option)
                                    ) {
                                        handleOptionTap(option)
                                    }
                                    .opacity(isDisabled ? 0.4 : 1.0)
                                    .allowsHitTesting(!isDisabled)
                                    .accessibilityIdentifier("bulk_edit_option_\(option.id)")
                                }
                            }
                        }

                        // Lo que va a cambiar, antes de aplicarlo (con el aviso de moneda y lo bloqueado).
                        if !changes.isEmpty {
                            pendingSummary
                        }

                        YalaPrimaryButton(
                            L10n.UXL8B.BulkEdit.apply(selectedCount),
                            isDisabled: changes.isEmpty || bulkEditViewModel.blocker != nil,
                            disabledHint: changes.isEmpty
                                ? L10n.UXL8B.BulkEdit.nothingPendingHint : bulkEditViewModel.blocker
                        ) {
                            applyChanges()
                        }
                        .accessibilityIdentifier("bulk_edit_apply")
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Action.edit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        finishEditing()
                    }
                }
            }
            .sheet(isPresented: $showAccountSelector) {
                AccountSelectorSheet(selectedAccount: $bulkEditViewModel.changes.account)
            }
            .sheet(isPresented: $showSubcategorySelector) {
                SubcategorySelectorSheet(
                    selectedSubcategory: $bulkEditViewModel.changes.subcategory,
                    transactionType: detectedTransactionType ?? .expense
                )
            }
            .sheet(isPresented: $showTagEditor) {
                BulkTagEditorSheet(
                    viewModel: viewModel,
                    allTags: bulkEditViewModel.activeTags,
                    onApply: { tagsToAdd, tagsToRemove in
                        bulkEditViewModel.changes.tagsToAdd = tagsToAdd
                        bulkEditViewModel.changes.tagsToRemove = tagsToRemove
                    }
                )
            }
            .sheet(isPresented: $showNoteEditor) {
                BulkNoteEditorSheet(note: $bulkNote) {
                    bulkEditViewModel.changes.note = bulkNote
                }
            }
            .sheet(isPresented: $showAmountEditor) {
                if let currencyCode = bulkEditViewModel.amountCurrency {
                    BulkAmountEditorSheet(
                        amount: $bulkAmount,
                        currencyCode: currencyCode,
                        recordCount: selectedCount
                    ) {
                        bulkEditViewModel.changes.amount = bulkAmount
                    }
                }
            }
        }

        .onAppear {
            bulkEditViewModel.setContext(modelContext)
            bulkEditViewModel.loadSelection(viewModel.selectedTransactions(context: modelContext))
        }
        .onChange(of: changes.signature) {
            bulkEditViewModel.dropAmountIfCurrencyIsUnclear()
            bulkEditViewModel.blocker = viewModel.bulkEditBlocker(bulkEditViewModel.changes, context: modelContext)
        }
        // Lo que rechaza «Aplicar» (la comprobación de antes cubre casi todo; esto es la red). No se titula «Error»:
        // dice qué pasa.
        .alert(
            L10n.UXL8B.BulkEdit.blockedTitle,
            isPresented: Binding(
                get: { viewModel.bulkUpdateError != nil },
                set: { if !$0 { viewModel.bulkUpdateError = nil } }
            ),
            presenting: viewModel.bulkUpdateError
        ) { _ in
            Button(L10n.Common.ok, role: .cancel) {
                viewModel.bulkUpdateError = nil
            }
        } message: { errorMessage in
            Text(errorMessage)
        }
    }

    // MARK: - Hoy / pendiente por opción

    private func isOptionDisabled(_ option: BulkEditOption) -> Bool {
        switch option {
        case .subcategory: return detectedTransactionType == nil
        // Con monedas distintas el mismo número no significa lo mismo en cada registro: no se ofrece (L8-13).
        case .amount: return bulkEditViewModel.amountCurrency == nil
        case .account, .tag, .note: return false
        }
    }

    /// Lo que enseña la fila: el valor nuevo si hay un cambio pendiente; si no, qué tienen hoy los elegidos.
    private func subtitle(for option: BulkEditOption) -> String? {
        if let pending = pendingValue(for: option) { return "→ \(pending)" }
        switch option {
        case .account:
            return todayText(
                bulkEditViewModel.currentAccount, distinct: { L10n.UXL8B.BulkEdit.distinctAccounts($0) })
        case .subcategory:
            guard detectedTransactionType != nil else { return nil }
            return todayText(
                bulkEditViewModel.currentSubcategory, distinct: { L10n.UXL8B.BulkEdit.distinctSubcategories($0) })
        case .tag:
            return nil
        case .note:
            switch bulkEditViewModel.currentNote {
            case .same(let note): return L10n.UXL8B.BulkEdit.today(note ?? L10n.UXL8B.BulkEdit.noNote)
            case .distinct: return L10n.UXL8B.BulkEdit.today(L10n.UXL8B.BulkEdit.distinctNotes)
            }
        case .amount:
            guard bulkEditViewModel.amountCurrency != nil else {
                return L10n.UXL8B.BulkEdit.mixedCurrencies
            }
            // `sharedAmount` solo existe si todos comparten moneda: se enseña en la de hoy.
            if let shared = bulkEditViewModel.sharedAmount, let currencyCode = bulkEditViewModel.selectedCurrencies.first {
                return L10n.UXL8B.BulkEdit.today(appPreferences.currency(shared, currencyCode: currencyCode))
            }
            return L10n.UXL8B.BulkEdit.today(L10n.UXL8B.BulkEdit.distinctAmounts)
        }
    }

    private func todayText(_ current: BulkEditLogic.Current, distinct: (Int) -> String) -> String? {
        switch current {
        case .same(let value):
            guard let value else { return nil }
            return L10n.UXL8B.BulkEdit.today(value)
        case .distinct(let count):
            return count > 1 ? L10n.UXL8B.BulkEdit.today(distinct(count)) : nil
        }
    }

    private func pendingValue(for option: BulkEditOption) -> String? {
        summaryLines.first { $0.option == option }?.value
    }

    private var summaryLines: [BulkEditLogic.SummaryLine] {
        BulkEditLogic.summaryLines(
            account: changes.account?.name,
            subcategory: changes.subcategory?.name,
            tagsAdded: changes.tagsToAdd.map(\.name),
            tagsRemoved: changes.tagsToRemove.map(\.name),
            note: changes.note,
            amount: pendingAmountText,
            noNote: L10n.UXL8B.BulkEdit.noNote
        )
    }

    private var pendingAmountText: String? {
        guard let amount = changes.amount, let currencyCode = bulkEditViewModel.amountCurrency else { return nil }
        return appPreferences.currency(amount, currencyCode: currencyCode)
    }

    // MARK: - Resumen de lo pendiente

    private var pendingSummary: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.UXL8B.BulkEdit.summaryTitle(selectedCount))
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.thPrimaryText)

            ForEach(summaryLines, id: \.option) { line in
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Text(verbatim: "\(line.option.title) → \(line.value)")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bulk_edit_summary_\(line.option.id)")
                    Spacer(minLength: DS.Spacing.sm)
                    Button {
                        discard(line.option)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: DS.Button.actionSize, minHeight: DS.Button.actionSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.UXL8B.BulkEdit.discardChange)
                    .accessibilityIdentifier("bulk_edit_discard_\(line.option.id)")
                }
            }

            if let pendingAmountText {
                Text(L10n.UXL8B.BulkEdit.amountResult(count: selectedCount, amount: pendingAmountText))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            if bulkEditViewModel.pendingAccountChangesCurrency {
                notice(icon: "exclamationmark.triangle.fill", text: L10n.BulkEdit.currencyWarning)
            }

            if let blocker = bulkEditViewModel.blocker {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.UXL8B.BulkEdit.blockedTitle)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.thPrimaryText)
                    notice(icon: "hand.raised.fill", text: blocker)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("bulk_edit_blocked")
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(radius: DS.Radius.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bulk_edit_summary")
    }

    private func notice(icon: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(DS.Semantic.warningForeground)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Semantic.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Actions

    private func handleOptionTap(_ option: BulkEditOption) {
        switch option {
        case .account:
            showAccountSelector = true
        case .subcategory:
            guard detectedTransactionType != nil else { return }
            showSubcategorySelector = true
        case .tag:
            showTagEditor = true
        case .note:
            bulkNote = changes.note ?? ""
            showNoteEditor = true
        case .amount:
            guard bulkEditViewModel.amountCurrency != nil else { return }
            bulkAmount = changes.amount ?? 0
            showAmountEditor = true
        }
    }

    private func discard(_ option: BulkEditOption) {
        switch option {
        case .account: bulkEditViewModel.changes.account = nil
        case .subcategory: bulkEditViewModel.changes.subcategory = nil
        case .tag:
            bulkEditViewModel.changes.tagsToAdd = []
            bulkEditViewModel.changes.tagsToRemove = []
        case .note: bulkEditViewModel.changes.note = nil
        case .amount: bulkEditViewModel.changes.amount = nil
        }
    }

    /// Todo o nada: si algo está bloqueado no se aplica ninguna parte y el aviso dice por qué.
    private func applyChanges() {
        guard viewModel.applyBulkEdit(bulkEditViewModel.changes, context: modelContext) else { return }
        onComplete()
        finishEditing()
    }

    private func finishEditing() {
        viewModel.exitSelectionMode()
        dismiss()
    }
}

// MARK: - Bulk Edit Option Row

private struct BulkEditOptionRow: View {
    let option: BulkEditOption
    /// «Hoy: Ahorros» o, con un cambio pendiente, «→ Restaurantes».
    let subtitle: String?
    let isPending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                // Icon: relleno de color cuando la opción tiene un cambio pendiente (lo elegido va relleno).
                Circle()
                    .fill(isPending ? option.iconColor : option.iconColor.opacity(0.15))
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                    .overlay(
                        Image(systemName: option.icon)
                            .font(DS.Typography.body).fontWeight(.medium)
                            .foregroundStyle(isPending ? Color.white : option.iconColor)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(option.title)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(isPending ? DS.Typography.subheadlineEmphasized : DS.Typography.caption)
                            .foregroundStyle(isPending ? Color.primary : Color.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPending ? .isSelected : [])
    }
}

// MARK: - Bulk Tag Editor Sheet

struct BulkTagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let viewModel: RecordsViewModel
    let allTags: [Tag]
    let onApply: ([Tag], [Tag]) -> Void

    @State private var tagsToAdd: Set<PersistentIdentifier> = []
    @State private var tagsToRemove: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Common tags section (tags that ALL selected transactions have)
                    if !commonTags.isEmpty {
                            SectionBox(title: L10n.BulkEdit.commonTags) {
                                LazyVStack(spacing: DS.Spacing.none) {
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
                                LazyVStack(spacing: DS.Spacing.none) {
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
                                LazyVStack(spacing: DS.Spacing.none) {
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
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Settings.tags)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
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
                    .accessibilityHint(tagsToAdd.isEmpty && tagsToRemove.isEmpty ? L10n.Accessibility.completeSelectionHint : "")
                }
            }
        }

    }

    // MARK: - Tag Analysis

    private var selectedTransactionTags: [[Tag]] {
        viewModel.getSelectedTransactionTags(context: modelContext)
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
    @Environment(\.yalaTheme) private var theme
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
                    .frame(width: DS.FormRow.iconWidth, height: DS.FormRow.iconWidth)
                    .overlay(
                        Image(systemName: tag.iconName)
                            .font(DS.Typography.labelSmall.weight(.semibold))
                            .foregroundStyle(.white)
                    )

                // Tag name
                Text(tag.name)
                    .font(DS.Typography.body)
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
                .font(DS.Typography.title)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
        case .toRemove, .available:
            // Unchecked - tag will NOT be present after save
            Image(systemName: "square")
                .font(DS.Typography.title)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        case .partial:
            // Mixed state - some have it, some don't
            Image(systemName: "minus.square.fill")
                .font(DS.Typography.title)
                .foregroundStyle(DS.Semantic.warningForeground)
                .accessibilityHidden(true)
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
            VStack(spacing: DS.Spacing.xxl) {
                SectionBox(title: "") {
                    TextField(L10n.Transaction.notePlaceholder, text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.FormRow.paddingV)
                        .focused($isFocused)
                        .accessibilityIdentifier("bulk_note_field")
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xxl)
            .dismissKeyboardOnTap()
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Transaction.note)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton {
                        onSave()
                        dismiss()
                    }
                    .accessibilityHint(L10n.Action.save)
                }
            }
            .onAppear {
                Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    isFocused = true
                }
            }
        }

    }
}

// MARK: - Bulk Amount Editor Sheet

/// L8-13: el campo lleva la moneda de los elegidos y avisa de que todos quedan con ese importe («Los 3 quedarán en
/// S/ 20»). Antes era un «0.00» sin moneda ni aviso.
struct BulkAmountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @Binding var amount: Double
    /// La moneda en que quedarán todos (la de la cuenta nueva si se cambia, o la que comparten).
    let currencyCode: String
    let recordCount: Int
    let onSave: () -> Void

    @State private var amountText: String = ""
    @FocusState private var isFocused: Bool

    private var typedAmount: Double { AmountInputHelper.parseDecimal(amountText) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                SectionBox(title: "") {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(appPreferences.currencyIdentifier(for: currencyCode))
                            .font(DS.Typography.title)
                            .foregroundStyle(.secondary)
                            .padding(.leading, DS.Spacing.lg)
                            .accessibilityHidden(true)
                        TextField(appPreferences.number(0), text: $amountText)
                            .accessibilityLabel(L10n.Transaction.amount)
                            .accessibilityIdentifier("bulk_amount_field")
                            .keyboardType(.decimalPad)
                            .font(DS.Typography.title)
                            .padding(.trailing, DS.Spacing.lg)
                            .padding(.vertical, DS.FormRow.paddingV)
                            .focused($isFocused)
                            .onChange(of: isFocused) { _, focused in
                                if !focused && !amountText.isEmpty {
                                    let value = AmountInputHelper.parseDecimal(amountText)
                                    amountText = AmountInputHelper.formatWithGrouping(value)
                                }
                            }
                            .onChange(of: amountText) { _, newValue in
                                let filtered = AmountInputHelper.filterAmountInput(newValue)
                                if filtered != newValue {
                                    amountText = filtered
                                }
                            }
                    }
                }

                // Lo que va a pasar, antes de guardar: todos quedan con el mismo importe (cada uno con su signo).
                Text(L10n.UXL8B.BulkEdit.amountResult(
                    count: recordCount,
                    amount: appPreferences.currency(typedAmount, currencyCode: currencyCode)
                ))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DS.Spacing.sm)
                .accessibilityIdentifier("bulk_amount_result")

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xxl)
            .dismissKeyboardOnTap()
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Transaction.amount)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton {
                        let value = typedAmount
                        if value > 0 {
                            amount = value
                            onSave()
                        }
                        dismiss()
                    }
                    .disabled(amountText.isEmpty)
                    .accessibilityHint(amountText.isEmpty ? L10n.Accessibility.completeSelectionHint : "")
                }
            }
            .onAppear {
                // Al volver a abrirlo, el monto que ya quedó pendiente.
                if amount > 0 && amountText.isEmpty {
                    amountText = AmountInputHelper.formatWithGrouping(amount)
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    isFocused = true
                }
            }
        }

    }
}

#Preview {
    BulkEditSheet(
        viewModel: RecordsViewModel(context: .empty),
        selectedCount: 3,
        onComplete: {}
    )
}
