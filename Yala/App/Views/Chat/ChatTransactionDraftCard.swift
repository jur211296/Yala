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

    @State private var activeField: ChatDraftField?
    @State private var showingDetails = false
    @State private var fullFormRequested = false

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
    //
    // Propuesta A (Jürgen, 2026-10-04): la card ES la fila que el registro tendrá en Registros —icono de categoría,
    // nota, subcategoría, importe— y debajo píldoras tocables para lo que más se corrige. Cada píldora abre el MISMO
    // selector que Nuevo registro (`ChatDraftFieldSheet`); «Detalles» abre la hoja con todo lo demás. Al guardar, la
    // fila se queda donde estaba con su ✓ (`compactRow`): pendiente y guardado son la misma pieza.

    private var editableCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            Button {
                showingDetails = true
            } label: {
                pendingRow
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .accessibilityIdentifier("chat_draft_row")
            chipsRow
            Divider()
            footer
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(.thCard)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .sheet(item: $activeField) { field in
            fieldSheet(field)
        }
        .sheet(isPresented: $showingDetails, onDismiss: openFullFormIfRequested) {
            ChatDraftDetailSheet(
                draft: draft, account: currentAccount, subcategory: currentSubcategory, tags: savedTagsResolved,
                canSave: canSave, editing: editing,
                onSave: { onSave(draft.id) },
                onDiscard: { onDiscard(draft.id) },
                onOpenFullForm: requestFullForm
            )
        }
    }

    private var pendingRow: some View {
        HStack(spacing: DS.ListRow.spacing) {
            ChatDraftCategoryIcon(subcategory: currentSubcategory)

            VStack(alignment: .leading, spacing: 3) {
                Text(pendingTitle)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(pendingSubtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(
                        currentSubcategory == nil
                            ? AnyShapeStyle(DS.Semantic.warningForeground) : AnyShapeStyle(.secondary)
                    )
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.sm)

            Text(draft.amount == nil ? L10n.Chat.Draft.missingAmount : savedFormattedAmount)
                .font(draft.amount == nil ? DS.Typography.caption : DS.Typography.headline)
                .foregroundStyle(
                    draft.amount == nil ? AnyShapeStyle(DS.Semantic.warningForeground) : AnyShapeStyle(savedAmountColor)
                )
                .monospacedDigit()
        }
        .padding(.top, DS.ListRow.paddingV)
        .padding(.bottom, DS.Spacing.sm)
        .padding(.horizontal, DS.ListRow.paddingH)
        .contentShape(Rectangle())
    }

    /// La nota es lo que el usuario dijo («Taxi al aeropuerto»); sin nota, la subcategoría hace de título.
    private var pendingTitle: String {
        if !draft.note.isEmpty { return draft.note }
        return currentSubcategoryShortName ?? L10n.Common.uncategorized
    }

    private var pendingSubtitle: String {
        guard let sub = currentSubcategory else { return L10n.Chat.Draft.missingSubcategory }
        return "\(sub.safeCategory.name) · \(sub.name)"
    }

    /// Lo que falta va primero y en ámbar; luego cuenta, fecha y etiquetas. La subcategoría ya elegida se cambia
    /// desde «Detalles» (ya se lee en la fila).
    private var chipsRow: some View {
        FlowLayout(spacing: DS.Spacing.sm) {
            if currentSubcategory == nil {
                chip(.subcategory, title: L10n.Chat.Draft.selectSubcategory, isMissing: true)
            }
            chip(
                .account,
                title: currentAccountShortName ?? L10n.Chat.Draft.selectAccount,
                isMissing: currentAccountShortName == nil
            )
            chip(.date, title: ChatDraftFormatting.dateLabel(draft.date), isMissing: false)
            chip(
                .tags,
                title: savedTagsResolved.isEmpty
                    ? "+ \(L10n.Chat.Draft.addTag)"
                    : savedTagsResolved.map(\.name).sorted().joined(separator: ", "),
                isMissing: false
            )
        }
        .padding(.leading, DS.ListRow.paddingH + DS.ListRow.iconSize + DS.ListRow.spacing)
        .padding(.trailing, DS.ListRow.paddingH)
        .padding(.bottom, DS.Spacing.md)
    }

    private func chip(_ field: ChatDraftField, title: String, isMissing: Bool) -> some View {
        Button {
            activeField = field
        } label: {
            Text(title)
                .font(DS.Typography.labelSmall)
                .lineLimit(1)
                .foregroundStyle(isMissing ? AnyShapeStyle(DS.Semantic.warningForeground) : AnyShapeStyle(.primary))
                .padding(.horizontal, DS.Chip.paddingH)
                .padding(.vertical, DS.Chip.paddingV)
                .background(
                    Capsule().fill(isMissing ? AnyShapeStyle(DS.Semantic.warningBackground) : AnyShapeStyle(.quaternary))
                )
                .overlay {
                    if isMissing {
                        Capsule().strokeBorder(DS.Semantic.warningForeground, lineWidth: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .accessibilityIdentifier("chat_draft_chip_\(field.rawValue)")
    }

    private var footer: some View {
        HStack(spacing: DS.Spacing.xs) {
            Button(L10n.Chat.Draft.discardButton) {
                    onDiscard(draft.id)
            }
            .font(DS.Typography.label)
            .foregroundStyle(.secondary)
            .frame(minHeight: 44)
            .padding(.horizontal, DS.Spacing.sm)
            .disabled(isSaving)

            Button(L10n.Chat.Draft.detailsButton) {
                    showingDetails = true
            }
            .font(DS.Typography.label)
            .foregroundStyle(theme.accent)
            .frame(minHeight: 44)
            .padding(.horizontal, DS.Spacing.sm)
            .disabled(isSaving)
            .accessibilityIdentifier("chat_draft_details")

            Spacer()

            Button {
                onSave(draft.id)
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    }
                    Text(L10n.Chat.Draft.saveButton)
                        .font(DS.Typography.label)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .frame(minHeight: 44)
                // Apagado se VE apagado: con fondo y texto explícitos, `.disabled` no atenúa nada y el botón
                // parecía activo sin hacer nada (medido el 2026-10-04 con la subcategoría sin elegir).
                .background(canSave ? theme.accent : DS.Semantic.disabledForeground.opacity(0.35))
                .foregroundStyle(canSave ? Color.contrastingText(for: theme.accent) : Color.secondary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isSaving)
            .accessibilityIdentifier("chat_draft_save")
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
    }

    private var isSaving: Bool { draft.status == .saving }

    private var canSave: Bool {
        draft.amount != nil && draft.accountID != nil && draft.subcategoryID != nil
    }

    private var editing: ChatDraftEditing {
        ChatDraftEditing(
            onAmountChange: onAmountChange,
            onAccountChange: onAccountChange,
            onSubcategoryChange: onSubcategoryChange,
            onDateChange: onDateChange,
            onTagsChange: onTagsChange,
            onNoteChange: onNoteChange
        )
    }

    private func fieldSheet(_ field: ChatDraftField) -> ChatDraftFieldSheet {
        ChatDraftFieldSheet(
            field: field, isExpense: draft.isExpense, account: currentAccount, subcategory: currentSubcategory,
            tags: savedTagsResolved, date: draft.date, editing: editing
        )
    }

    // «Abrir en el formulario completo» cierra el chat. Primero se cierra la hoja de detalles y SOLO en su
    // `onDismiss` se sigue: encadenar dos presentaciones a mano puede dejar una a medias
    // (`.claude/rules/swiftui-ds.md`, «Presentaciones»).
    private func requestFullForm() {
        fullFormRequested = true
        showingDetails = false
    }

    private func openFullFormIfRequested() {
        guard fullFormRequested else { return }
        fullFormRequested = false
        onEdit(draft.id)
        dismiss()  // Cierra ChatSheet (agnóstico al padre — funciona en los 3 puntos de entrada)
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
        // La divisa que se estampó de verdad: `saveDraft` la congela en el borrador al guardar.
        return appPreferences.currency(
            dbl, currencyCode: draft.currencyCode, forceFullPrecision: true)
    }

    /// Se colorea la excepción, no la norma: el gasto va en el color del texto y el ingreso en el tono oscurecido
    /// que sí se lee sobre la tarjeta (`.claude/rules/swiftui-ds.md`).
    private var savedAmountColor: Color {
        draft.isExpense ? Color.primary : Color.incomeAmount
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

    /// La cuenta del borrador para los selectores. Solo para PRESELECCIONAR: la divisa no se deduce de aquí (ver abajo).
    private var currentAccount: Account? {
        guard let id = draft.accountID else { return nil }
        return allAccounts.first(where: { $0.persistentModelID == id })
    }

    // Aquí NO va un helper que resuelva la cuenta para deducir la divisa. `draft.currencyCode` ya es
    // la divisa efectiva: el ViewModel la sincroniza al elegir cuenta y la congela al guardar.
    //
    // Se intentó al revés —derivarla aquí resolviendo `draft.accountID` contra `allAccounts`— y se
    // retiró el mismo día: este `@Query` filtra `!isArchived` y `saveDraft` resuelve con
    // `context.model(for:)`, que no filtra, así que con una cuenta archivada entre proponer y
    // guardar los dos lados discrepaban y volvía el bug que el cambio venía a cerrar. Dos criterios
    // para la misma pregunta son dos respuestas esperando a divergir; con un solo valor en el
    // borrador no hay nada que sincronizar.
}
