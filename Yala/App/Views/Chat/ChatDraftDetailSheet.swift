//
//  ChatDraftDetailSheet.swift
//  Yala
//
//  «Detalles» de un registro propuesto por Yala IA: hoja a media altura sobre el chat (propuesta A, elegida por
//  Jürgen el 2026-10-04). Todos los datos del borrador a la vista, y cada uno abre el MISMO selector que Nuevo
//  registro (`ChatDraftFieldSheet`). Los cambios se aplican al borrador al momento: «Listo» solo cierra,
//  «Guardar» registra. El formulario completo sigue a un toque, pero ya no es lo que pasa por defecto.
//

import SwiftUI
import SwiftData

struct ChatDraftDetailSheet: View {
    let draft: ChatTransactionDraft
    let account: Account?
    let subcategory: Subcategory?
    let tags: [Tag]
    let canSave: Bool
    let editing: ChatDraftEditing
    var onSave: () -> Void
    var onDiscard: () -> Void
    var onOpenFullForm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    @State private var activeField: ChatDraftField?
    @State private var selectedDetent: PresentationDetent = .medium
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField { case amount, note }

    private var isLargeDetent: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    amountHeader
                    fieldsCard
                    YalaPrimaryButton(L10n.Chat.Draft.saveButton, isDisabled: !canSave) {
                        focusedField = nil
                        onSave()
                        dismiss()
                    }
                    .accessibilityIdentifier("chat_draft_detail_save")
                    Button(L10n.Chat.Draft.openFullForm) {
                        focusedField = nil
                        onOpenFullForm()
                    }
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(theme.accent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("chat_draft_open_full_form")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
            .navigationTitle(L10n.Chat.Draft.detailsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .yalaSheetDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .sheet(item: $activeField) { field in
            ChatDraftFieldSheet(
                field: field, isExpense: draft.isExpense, account: account, subcategory: subcategory,
                tags: tags, date: draft.date, editing: editing
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(L10n.Chat.Draft.discardButton) {
                focusedField = nil
                onDiscard()
                dismiss()
            }
            .accessibilityIdentifier("chat_draft_detail_discard")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(L10n.Action.done) {
                focusedField = nil
                dismiss()
            }
            .fontWeight(.semibold)
            .accessibilityIdentifier("chat_draft_detail_done")
        }
    }

    // MARK: - Importe

    private var amountHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            ChatDraftCategoryIcon(subcategory: subcategory)
            Text(draft.isExpense ? L10n.Chat.Draft.chipExpense : L10n.Chat.Draft.chipIncome)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: DS.Spacing.sm)
            TextField(
                L10n.Chat.Draft.amountPlaceholder,
                value: Binding<Decimal?>(get: { draft.amount }, set: { editing.onAmountChange($0) }),
                format: .number.precision(.fractionLength(2))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(DS.Typography.title)
            .focused($focusedField, equals: .amount)
            .accessibilityIdentifier("chat_draft_detail_amount")
            Text(draft.currencyCode)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Datos

    private var fieldsCard: some View {
        VStack(spacing: DS.Spacing.none) {
            noteRow
            Divider()
            fieldRow(
                .subcategory, label: L10n.Chat.Draft.subcategoryLabel,
                value: subcategory.map { "\($0.safeCategory.name) · \($0.name)" },
                placeholder: L10n.Chat.Draft.selectSubcategory
            )
            Divider()
            fieldRow(
                .account, label: L10n.Chat.Draft.accountLabel,
                value: account?.name, placeholder: L10n.Chat.Draft.selectAccount
            )
            Divider()
            fieldRow(.date, label: L10n.Chat.Draft.dateLabel, value: ChatDraftFormatting.dateLabel(draft.date), placeholder: "")
            Divider()
            fieldRow(
                .tags, label: L10n.Chat.Draft.tagsLabel,
                value: tags.isEmpty ? nil : tags.map(\.name).sorted().joined(separator: ", "),
                placeholder: L10n.Chat.Draft.tagsNone, missingIsWarning: false
            )
        }
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(.thCard))
    }

    private var noteRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(L10n.Chat.Draft.noteLabel)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
            TextField(
                L10n.Chat.Draft.noteLabel,
                text: Binding(get: { draft.note }, set: { editing.onNoteChange($0) })
            )
            .font(DS.Typography.body)
            .multilineTextAlignment(.trailing)
            .submitLabel(.done)
            .focused($focusedField, equals: .note)
            .accessibilityIdentifier("chat_draft_detail_note")
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(minHeight: 48)
    }

    private func fieldRow(
        _ field: ChatDraftField,
        label: String,
        value: String?,
        placeholder: String,
        missingIsWarning: Bool = true
    ) -> some View {
        let isMissing = value == nil && missingIsWarning
        return Button {
            focusedField = nil
            activeField = field
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text(label)
                    .font(DS.Typography.body)
                    .foregroundStyle(isMissing ? AnyShapeStyle(DS.Semantic.warningForeground) : AnyShapeStyle(.secondary))
                Spacer(minLength: DS.Spacing.sm)
                Text(value ?? placeholder)
                    .font(DS.Typography.body)
                    .foregroundStyle(isMissing ? AnyShapeStyle(DS.Semantic.warningForeground) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.md)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat_draft_detail_\(field.rawValue)")
    }
}

// MARK: - Piezas compartidas con la card

/// El círculo con el icono y el color de la categoría, como en Registros. Sin subcategoría, un círculo vacío en
/// ámbar con «?»: es lo que falta.
struct ChatDraftCategoryIcon: View {
    let subcategory: Subcategory?

    var body: some View {
        if let subcategory {
            ZStack {
                Circle()
                    .fill(Color(hex: subcategory.safeCategory.colorHex))
                Image(systemName: subcategory.iconName ?? subcategory.safeCategory.iconName ?? "tag.fill")
                    .font(DS.Typography.label)
                    .foregroundStyle(.white)
            }
            .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
            .accessibilityHidden(true)
        } else {
            ZStack {
                Circle()
                    .strokeBorder(DS.Semantic.warningForeground, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Text(verbatim: "?")
                    .font(DS.Typography.label)
                    .foregroundStyle(DS.Semantic.warningForeground)
            }
            .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
            .accessibilityHidden(true)
        }
    }
}

enum ChatDraftFormatting {
    /// «Hoy», «Ayer» o la fecha corta: lo que el usuario dijo, no una fecha completa.
    static func dateLabel(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return L10n.Date.today }
        if calendar.isDateInYesterday(date) { return L10n.Date.yesterday }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}
