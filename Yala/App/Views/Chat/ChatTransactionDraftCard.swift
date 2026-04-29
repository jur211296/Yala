//
//  ChatTransactionDraftCard.swift
//  Yala
//
//  Card preview inline para registrar transacciones desde el chat. Vive dentro del
//  bubble del assistant. Estados: pending, saving, saved, failed.
//

import SwiftUI
import SwiftData

struct ChatTransactionDraftCard: View {

    let draft: ChatTransactionDraft
    let messageID: UUID

    var onSave: (UUID) -> Void
    var onEdit: (UUID) -> Void
    var onDiscard: (UUID) -> Void
    var onAmountChange: (Decimal?) -> Void
    var onAccountChange: (PersistentIdentifier?) -> Void
    var onSubcategoryChange: (PersistentIdentifier?) -> Void
    var onDateChange: (Date) -> Void
    var onTagsChange: ([PersistentIdentifier]) -> Void
    var onNoteChange: (String) -> Void
    var onTapSavedTransaction: ((PersistentIdentifier) -> Void)? = nil

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var allAccounts: [Account]
    @Query(filter: #Predicate<Subcategory> { $0.isVisible == true }) private var allSubcategories: [Subcategory]
    @Query private var allTags: [Tag]

    @FocusState private var amountFocused: Bool

    var body: some View {
        switch draft.status {
        case .saved:
            savedRow
        case .discarded:
            discardedRow
        case .failed:
            failedRow
        case .pending, .saving:
            editableCard
        }
    }

    // MARK: - Editable card (.pending / .saving)

    private var editableCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header
            Divider()
            menuRows
            footer
        }
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        // Tap en Save → cerrar teclado antes de guardar (UX más limpia).
        // El cierre vía swipe-down lo provee `.scrollDismissesKeyboard(.interactively)`
        // en el ScrollView de mensajes del ChatSheetView.
    }

    private var header: some View {
        HStack {
            Text(draft.isExpense ? L10n.Chat.Draft.chipExpense : L10n.Chat.Draft.chipIncome)
                .font(DS.Typography.labelSmall)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(draft.isExpense ? DS.Semantic.errorBackground : DS.Semantic.successBackground)
                .foregroundStyle(draft.isExpense ? DS.Semantic.errorForeground : DS.Semantic.successForeground)
                .clipShape(Capsule())

            Spacer()

            // SwiftUI sincroniza Binding<Decimal?> bidireccionalmente y rechaza
            // input no parseable. Resuelve el desync entre amountText y draft.amount,
            // y elimina la necesidad de `onAppear` con seed manual (que no se
            // re-disparaba si el draft cambiaba externamente).
            TextField(
                L10n.Chat.Draft.amountPlaceholder,
                value: Binding<Decimal?>(
                    get: { draft.amount },
                    set: { newValue in onAmountChange(newValue) }
                ),
                format: .number.precision(.fractionLength(0...2))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(DS.Typography.title)
            .frame(maxWidth: 140)
            .focused($amountFocused)
            .disabled(draft.status == .saving)

            Text(draft.currencyCode)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.thSecondaryText)
        }
    }

    private var menuRows: some View {
        VStack(spacing: DS.Spacing.sm) {
            accountRow
            subcategoryRow
            dateRow
            tagsRow
            noteRow
        }
    }

    private var tagsRow: some View {
        Menu {
            ForEach(sortedTags) { tag in
                Button {
                    var ids = draft.tagIDs
                    if let idx = ids.firstIndex(of: tag.persistentModelID) {
                        ids.remove(at: idx)
                    } else {
                        ids.append(tag.persistentModelID)
                    }
                    onTagsChange(ids)
                } label: {
                    HStack {
                        Text(tag.name)
                        if draft.tagIDs.contains(tag.persistentModelID) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            row(
                icon: "number",
                label: L10n.Chat.Draft.tagsLabel,
                value: currentTagsLabel,
                highlight: false
            )
        }
        .disabled(draft.status == .saving)
    }

    private var sortedTags: [Tag] {
        allTags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var currentTagsLabel: String {
        let selected = allTags.filter { draft.tagIDs.contains($0.persistentModelID) }
        if selected.isEmpty { return L10n.Chat.Draft.tagsNone }
        return selected.map { $0.name }.sorted().joined(separator: ", ")
    }

    @ViewBuilder
    private var accountRow: some View {
        let needsInput = draft.needsUserInput.contains("account")
        Menu {
            ForEach(allAccounts) { account in
                Button {
                    onAccountChange(account.persistentModelID)
                } label: {
                    Text("\(account.name) · \(account.currencyCode)")
                }
            }
        } label: {
            row(
                icon: "creditcard",
                label: L10n.Chat.Draft.accountLabel,
                value: currentAccountName ?? L10n.Chat.Draft.selectAccount,
                highlight: needsInput
            )
        }
        .disabled(draft.status == .saving)
    }

    @ViewBuilder
    private var subcategoryRow: some View {
        let needsInput = draft.needsUserInput.contains("subcategory")
        Menu {
            // Agrupado por categoría (A-Z) con subcategorías dentro (A-Z).
            ForEach(groupedSubcategories, id: \.categoryID) { group in
                Section(group.categoryName) {
                    ForEach(group.subcategories) { sub in
                        Button {
                            onSubcategoryChange(sub.persistentModelID)
                        } label: {
                            Text(sub.name)
                        }
                    }
                }
            }
        } label: {
            row(
                icon: "tag",
                label: L10n.Chat.Draft.subcategoryLabel,
                value: currentSubcategoryName ?? L10n.Chat.Draft.selectSubcategory,
                highlight: needsInput
            )
        }
        .disabled(draft.status == .saving)
    }

    private var dateRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "calendar")
                .foregroundStyle(AnyShapeStyle(.thSecondaryText))
                .frame(width: 20)
            Text(L10n.Chat.Draft.dateLabel)
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
            Spacer()
            DatePicker(
                "",
                selection: Binding(get: { draft.date }, set: onDateChange),
                displayedComponents: .date
            )
            .labelsHidden()
            .disabled(draft.status == .saving)
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.sm)
    }

    private var noteRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "text.alignleft")
                .foregroundStyle(AnyShapeStyle(.thSecondaryText))
                .frame(width: 20)
            Text(L10n.Chat.Draft.noteLabel)
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
            Spacer()
            TextField(
                L10n.Chat.Draft.noteLabel,
                text: Binding(
                    get: { draft.note },
                    set: { onNoteChange($0) }
                )
            )
            .font(DS.Typography.body)
            .foregroundStyle(.thPrimaryText)
            .multilineTextAlignment(.trailing)
            .submitLabel(.done)
            .disabled(draft.status == .saving)
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.sm)
    }

    private var footer: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(role: .destructive) {
                amountFocused = false
                onDiscard(draft.id)
            } label: {
                Text(L10n.Chat.Draft.discardButton)
                    .font(DS.Typography.labelSmall)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
            }
            .disabled(draft.status == .saving)

            Button {
                onEdit(draft.id)
                dismiss()  // Cierra ChatSheet (agnóstico al padre — funciona en los 3 puntos de entrada)
            } label: {
                Text(L10n.Chat.Draft.editButton)
                    .font(DS.Typography.labelSmall)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
            }
            .disabled(draft.status == .saving)

            Spacer()

            Button {
                amountFocused = false  // cierra teclado antes de iniciar save
                onSave(draft.id)
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    if draft.status == .saving {
                        ProgressView().controlSize(.small)
                    }
                    Text(L10n.Chat.Draft.saveButton)
                        .font(DS.Typography.labelSmall)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(theme.accent)
                .foregroundStyle(Color.contrastingText(for: theme.accent))
                .clipShape(Capsule())
            }
            .disabled(!canSave || draft.status == .saving)
        }
    }

    private var canSave: Bool {
        draft.amount != nil && draft.accountID != nil && draft.subcategoryID != nil
    }

    // MARK: - Helper rows

    @ViewBuilder
    private func row(icon: String, label: String, value: String, highlight: Bool) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(highlight ? AnyShapeStyle(DS.Semantic.warningForeground) : AnyShapeStyle(.thSecondaryText))
                .frame(width: 20)
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
            Spacer()
            Text(value)
                .font(DS.Typography.body)
                .foregroundStyle(.thPrimaryText)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.thSecondaryText)
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.sm)
        .background {
            if highlight {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(DS.Semantic.errorBorder, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(DS.Semantic.warningBackground.opacity(0.2))
                    )
            }
        }
    }

    // MARK: - Compact row (estilo RecordRowView, para estados terminales del draft)

    @ViewBuilder
    private var savedRow: some View {
        Button {
            if let txID = draft.savedTransactionID {
                onTapSavedTransaction?(txID)
            }
        } label: {
            compactRow(isDiscarded: false)
        }
        .buttonStyle(.plain)
        .disabled(onTapSavedTransaction == nil || draft.savedTransactionID == nil)
    }

    @ViewBuilder
    private var discardedRow: some View {
        compactRow(isDiscarded: true)
            .opacity(0.55)
            .accessibilityLabel(L10n.Chat.Draft.discardedBadge)
    }

    /// Layout compartido entre `.saved` y `.discarded`. La rama `.discarded` aplica
    /// strikethrough + dim externos y cambia el badge — el resto es idéntico para
    /// que el card transicione visualmente sin reflow inesperado.
    private func compactRow(isDiscarded: Bool) -> some View {
        HStack(spacing: DS.ListRow.spacing) {
            subcategoryIcon

            VStack(alignment: .leading, spacing: 3) {
                if !draft.note.isEmpty {
                    Text(draft.note)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                        .strikethrough(isDiscarded)
                        .lineLimit(1)
                    Text(savedSecondaryLine)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(currentSubcategoryShortName ?? L10n.Common.uncategorized)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                        .strikethrough(isDiscarded)
                        .lineLimit(1)
                    if let accountName = currentAccountShortName {
                        Text(accountName)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                if !savedTagsResolved.isEmpty {
                    savedTagsRow
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                Text(savedFormattedAmount)
                    .font(DS.Typography.headline)
                    .strikethrough(isDiscarded)
                    .foregroundStyle(isDiscarded ? AnyShapeStyle(.secondary) : AnyShapeStyle(savedAmountColor))

                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: isDiscarded ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(isDiscarded ? AnyShapeStyle(.secondary) : AnyShapeStyle(DS.Semantic.successForeground))
                    Text(isDiscarded ? L10n.Chat.Draft.discardedBadge : L10n.Chat.Draft.savedBadge)
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, DS.ListRow.paddingV)
        .padding(.horizontal, DS.ListRow.paddingH)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(.thCard)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(
            color: Color.black.opacity(isDiscarded ? 0 : theme.shadowOpacity),
            radius: 6, x: 0, y: 3
        )
    }

    private var subcategoryIcon: some View {
        let resolvedSub = currentSubcategory
        let colorHex = resolvedSub?.safeCategory.colorHex ?? AppConstants.defaultColorHex
        let iconName = resolvedSub?.iconName
            ?? resolvedSub?.safeCategory.iconName
            ?? "tag.fill"
        return ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
            Image(systemName: iconName)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
        }
    }

    private var savedTagsRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(savedTagsResolved.prefix(3)), id: \.persistentModelID) { tag in
                Text(tag.name)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(Color.contrastingText(for: Color(hex: tag.colorHex)))
                    .padding(.horizontal, DS.Chip.paddingV)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Capsule().fill(Color(hex: tag.colorHex)))
            }
            if savedTagsResolved.count > 3 {
                Text("+\(savedTagsResolved.count - 3)")
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var savedSecondaryLine: String {
        let parts = [currentSubcategoryShortName, currentAccountShortName].compactMap { $0 }
        return parts.joined(separator: " • ")
    }

    private var currentSubcategory: Subcategory? {
        guard let id = draft.subcategoryID else { return nil }
        return allSubcategories.first(where: { $0.persistentModelID == id })
    }

    private var currentSubcategoryShortName: String? {
        currentSubcategory?.name
    }

    private var currentAccountShortName: String? {
        guard let id = draft.accountID,
              let account = allAccounts.first(where: { $0.persistentModelID == id })
        else { return nil }
        return account.name
    }

    private var savedTagsResolved: [Tag] {
        allTags.filter { draft.tagIDs.contains($0.persistentModelID) }
    }

    private var savedFormattedAmount: String {
        guard let amount = draft.amount else { return "–" }
        let dbl = NSDecimalNumber(decimal: amount).doubleValue
        return appPreferences.currency(dbl, currencyCode: draft.currencyCode, forceFullPrecision: true)
    }

    private var savedAmountColor: Color {
        draft.isExpense ? Color.hotPink : Color.electricIndigo
    }

    // MARK: - Failed row

    private var failedRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DS.Semantic.errorForeground)
            Text(L10n.Chat.Draft.failedSavingLine)
                .font(DS.Typography.caption)
            Spacer()
            Button(L10n.Chat.Draft.retryButton) {
                onSave(draft.id)
            }
            .font(DS.Typography.labelSmall)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Semantic.errorBackgroundSubtle)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Lookups

    private var currentAccountName: String? {
        guard let id = draft.accountID,
              let account = allAccounts.first(where: { $0.persistentModelID == id })
        else { return nil }
        return "\(account.name) · \(account.currencyCode)"
    }

    private var currentSubcategoryName: String? {
        guard let id = draft.subcategoryID,
              let sub = allSubcategories.first(where: { $0.persistentModelID == id })
        else { return nil }
        return "\(sub.safeCategory.name) · \(sub.name)"
    }

    private var filteredSubcategories: [Subcategory] {
        allSubcategories.filter { $0.safeCategory.isIncome != draft.isExpense }
    }

    /// Subcategorías agrupadas por categoría. Categorías ordenadas A-Z, y dentro
    /// de cada categoría las subcategorías ordenadas A-Z.
    private struct SubcategoryGroup: Identifiable {
        let id: PersistentIdentifier
        var categoryID: PersistentIdentifier { id }
        let categoryName: String
        let subcategories: [Subcategory]
    }

    private var groupedSubcategories: [SubcategoryGroup] {
        let grouped = Dictionary(grouping: filteredSubcategories) { $0.safeCategory.persistentModelID }
        return grouped.map { (categoryID, subs) in
            let categoryName = subs.first?.safeCategory.name ?? ""
            let sorted = subs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return SubcategoryGroup(id: categoryID, categoryName: categoryName, subcategories: sorted)
        }
        .sorted { $0.categoryName.localizedCaseInsensitiveCompare($1.categoryName) == .orderedAscending }
    }
}
