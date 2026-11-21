//
//  VoiceDraftReviewCard.swift
//  Yala
//
//  Un borrador del registro por voz tal como se verá en Registros (propuesta C, 2026-10-04): icono de categoría, nota,
//  subcategoría e importe, y debajo las píldoras de la card de Yala IA (#348) para corregir lo que más se corrige.
//  Cada píldora abre el MISMO selector que Nuevo registro (`ChatDraftFieldSheet`); lo que falta va primero y en
//  ámbar. Tocar la fila abre el formulario completo del borrador (lo decide quien la monta).
//
//  Cada cambio se escribe en el `InboxDraft` y se guarda al momento: si el usuario cierra la hoja sin guardar, el
//  borrador se queda en la Bandeja con lo que corrigió.
//

import SwiftData
import SwiftUI

struct VoiceDraftReviewCard: View {
    let draft: InboxDraft
    /// La hoja de foto deja corregir la descripción tocándola (encargo del 2026-11-17); la de voz no lo pide.
    var editsNoteInPlace = false
    let onOpenDetails: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var allAccounts: [Account]
    @Query(filter: #Predicate<Subcategory> { $0.isVisible == true }) private var allSubcategories: [Subcategory]
    @Query private var allTags: [Tag]

    @State private var activeField: ChatDraftField?
    @State private var isEditingNote = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// La cuenta elegida sola al leer la foto (`CuentaSolaAlLeer`): sin ella, el chip de siempre.
    @Environment(\.cuentaSolaAlLeerHoja) private var cuentaSolaHoja

    private var isSaved: Bool { draft.status == .approved }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            // Guardada, la fila ya no abre nada; sin `.disabled`, que la atenuaría como si faltara algo.
            if isSaved {
                row
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("voice_draft_row")
            } else {
                if editsNoteInPlace {
                    // La descripción es un botón propio: dentro de la etiqueta de la fila se fundiría con ella. El resto de
                    // la fila abre el formulario con un toque (el botón de la descripción, como hijo, gana el suyo), y el
                    // botón de fondo solo existe para VoiceOver, que lee la fila entera ahí.
                    row
                        .onTapGesture(perform: openDetailsOrConfirmNote)
                        .background { openDetailsButton }
                } else {
                    Button(action: onOpenDetails) {
                        row
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("voice_draft_row")
                }

                chipsRow
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(.thCard)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .sheet(item: $activeField) { field in
            ChatDraftFieldSheet(
                field: field,
                isExpense: isExpense,
                account: draft.account,
                subcategory: draft.subcategory,
                tags: currentTags,
                date: draft.effectiveDate,
                editing: editing
            )
            .environment(\.cuentaSolaAlLeerSelector, CuentaSolaAlLeerSelectorPista.pista(for: cuentaSolaEleccion))
        }
    }

    // MARK: - Fila

    private var row: some View {
        rowContent
            .padding(.top, DS.ListRow.paddingV)
            .padding(.bottom, isSaved ? DS.ListRow.paddingV : DS.Spacing.sm)
            .padding(.horizontal, DS.ListRow.paddingH)
            .contentShape(Rectangle())
    }

    /// Con la descripción editable en línea, el resto de la fila abre el formulario (y, con la descripción abierta, la
    /// confirma). VoiceOver lee la fila entera en este botón.
    private var openDetailsButton: some View {
        Button(action: openDetailsOrConfirmNote) {
            Color.clear
        }
        .buttonStyle(.plain)
        // Solo para VoiceOver: el dedo lo recibe el gesto de la fila, encima.
        .allowsHitTesting(false)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityIdentifier("voice_draft_row")
    }

    /// Con la descripción abierta, tocar el resto de la fila la confirma; si no, abre el formulario completo.
    private func openDetailsOrConfirmNote() {
        if isEditingNote {
            isEditingNote = false
        } else {
            onOpenDetails()
        }
    }

    private var rowAccessibilityLabel: String {
        let amount = draft.amount == nil ? L10n.Chat.Draft.missingAmount : formattedAmount
        return [title, subtitle, amount].joined(separator: ", ")
    }

    /// Las piezas que no se tocan dejan el toque al gesto de la fila cuando la descripción va en línea.
    private var passesTouches: Bool { editsNoteInPlace && !isSaved }

    /// Con el texto al máximo el importe baja a su propia línea, entero: a su lado se partía en «S/ / 25.0 / 0»
    /// (barrido final 2.2). A tamaño normal, la fila de siempre, con los mismos hijos en el mismo `HStack`.
    @ViewBuilder
    private var rowContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.ListRow.spacing) {
                    ChatDraftCategoryIcon(subcategory: draft.subcategory)
                        .rowPassesTouches(passesTouches)
                    rowTexts
                }
                amountColumn(alignment: .leading)
                    .rowPassesTouches(passesTouches)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: DS.ListRow.spacing) {
                ChatDraftCategoryIcon(subcategory: draft.subcategory)
                    .rowPassesTouches(passesTouches)

                rowTexts

                Spacer(minLength: DS.Spacing.sm)

                amountColumn(alignment: .trailing)
                    .rowPassesTouches(passesTouches)
            }
        }
    }

    private var rowTexts: some View {
        VStack(alignment: .leading, spacing: 3) {
            if editsNoteInPlace, !isSaved {
                DraftNoteInlineEditor(draft: draft, title: title, isEditing: $isEditingNote)
            } else {
                Text(title)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Text(subtitle)
                .font(DS.Typography.caption)
                .foregroundStyle(
                    draft.subcategory == nil
                        ? AnyShapeStyle(DS.Semantic.warningForeground) : AnyShapeStyle(.secondary)
                )
                .lineLimit(1)
                .rowPassesTouches(passesTouches)
        }
    }

    private func amountColumn(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: DS.Spacing.xs) {
            Text(draft.amount == nil ? L10n.Chat.Draft.missingAmount : formattedAmount)
                .font(draft.amount == nil ? DS.Typography.caption : DS.Typography.headline)
                .foregroundStyle(
                    draft.amount == nil ? AnyShapeStyle(DS.Semantic.warningForeground) : AnyShapeStyle(amountColor)
                )
                .monospacedDigit()

            if isSaved {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(DS.Semantic.successForeground)
                    Text(L10n.Chat.Draft.savedBadge)
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("voice_draft_saved")
            }
        }
    }

    /// La nota es lo que el usuario dijo («Almuerzo»); sin nota, la subcategoría hace de título.
    private var title: String {
        if !draft.note.isEmpty { return draft.note }
        return draft.subcategory?.name ?? L10n.Common.uncategorized
    }

    private var subtitle: String {
        guard let sub = draft.subcategory else { return L10n.Chat.Draft.missingSubcategory }
        return "\(sub.safeCategory.name) · \(sub.name)"
    }

    // MARK: - Píldoras

    @ViewBuilder
    private var chipsRow: some View {
        FlowLayout(spacing: DS.Spacing.sm) {
            if draft.subcategory == nil {
                chip(.subcategory, title: L10n.Chat.Draft.selectSubcategory, isMissing: true)
            }
            accountChip
            chip(.date, title: ChatDraftFormatting.dateLabel(draft.effectiveDate), isMissing: false)
            chip(
                .tags,
                title: currentTags.isEmpty
                    ? "+ \(L10n.Chat.Draft.addTag)"
                    : currentTags.map(\.name).sorted().joined(separator: ", "),
                isMissing: false
            )
        }
        .padding(.leading, DS.ListRow.paddingH + DS.ListRow.iconSize + DS.ListRow.spacing)
        .padding(.trailing, DS.ListRow.paddingH)
        .padding(.bottom, accountChipPresentation.porque == nil ? DS.Spacing.md : DS.Spacing.sm)

        if let porque = accountChipPresentation.porque {
            CuentaSolaAlLeerPorqueLine(text: porque)
                .padding(.leading, DS.ListRow.paddingH + DS.ListRow.iconSize + DS.ListRow.spacing)
                .padding(.trailing, DS.ListRow.paddingH)
                .padding(.bottom, DS.Spacing.md)
        }
    }

    // MARK: - Cuenta sola al leer

    private var cuentaSolaEleccion: CuentaSolaAlLeer.Eleccion? { cuentaSolaHoja.eleccion(for: draft) }

    private var accountChipPresentation: CuentaSolaAlLeerChipPresentacion {
        CuentaSolaAlLeerChipPresentacion.make(
            eleccion: cuentaSolaEleccion,
            currentAccountID: draft.account?.shortcutID,
            accountName: draft.account?.name,
            muestraPorque: cuentaSolaHoja.muestraPorque(draft),
            selectAccount: L10n.Chat.Draft.selectAccount)
    }

    /// El chip de cuenta: el de siempre, «✦ Cuenta» si se eligió sola, «Cuenta · sugerida» si la propone Yala IA o
    /// «Elige cuenta · 2 coinciden».
    private var accountChip: some View {
        let presentation = accountChipPresentation
        return chip(
            .account, title: presentation.titulo, isMissing: presentation.estilo == .falta,
            isSuggested: presentation.estilo == .sugerida
        )
        .accessibilityLabel(presentation.accessibilityLabel.map { Text($0) } ?? Text(presentation.titulo))
    }

    private func chip(_ field: ChatDraftField, title: String, isMissing: Bool, isSuggested: Bool = false) -> some View {
        Button {
            activeField = field
        } label: {
            Text(title)
                .font(DS.Typography.labelSmall)
                .lineLimit(1)
                .foregroundStyle(isMissing ? AnyShapeStyle(DS.Semantic.warningForeground) : AnyShapeStyle(.primary))
                .padding(.horizontal, DS.Chip.paddingH)
                .padding(.vertical, DS.Chip.paddingV)
                .background {
                    if isSuggested {
                        CuentaSolaAlLeerSugeridaFondo()
                    } else {
                        Capsule().fill(isMissing ? AnyShapeStyle(DS.Semantic.warningBackground) : AnyShapeStyle(.quaternary))
                    }
                }
                .overlay {
                    if isMissing {
                        Capsule().strokeBorder(DS.Semantic.warningForeground, lineWidth: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("voice_draft_chip_\(field.rawValue)")
    }

    // MARK: - Edición

    private var editing: ChatDraftEditing {
        VoiceDraftFieldEditing.editing(
            draft: draft, accounts: allAccounts, subcategories: allSubcategories, tags: allTags, context: modelContext
        )
    }

    // MARK: - Datos

    private var currentTags: [Tag] {
        guard let ids = draft.resolvedTagIDs() else { return [] }
        return allTags.filter { ids.contains($0.id) }
    }

    /// El borrador guarda el importe con signo: negativo es gasto.
    private var isExpense: Bool { (draft.amount ?? -1) < 0 }

    /// Sin signo, como en 2.1: «S/ -251.81» en «Esto leí» parecía un error de lectura (card ex73, 2026-10-25). Lo que
    /// dice si es gasto o ingreso es el color: el ingreso va teñido y el gasto en el color del texto. La Bandeja conserva
    /// el signo (UX 2.2 · L4-14).
    private var formattedAmount: String {
        guard let amount = draft.amount else { return "–" }
        let code = draft.account?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue
        return appPreferences.currency(
            VoiceEntryFlowLogic.reviewDisplayedAmount(amount), currencyCode: code, forceFullPrecision: true)
    }

    /// Se colorea la excepción, no la norma: el gasto va en el color del texto y el ingreso en el tono oscurecido que
    /// sí se lee sobre la tarjeta (`.claude/rules/swiftui-ds.md`).
    private var amountColor: Color {
        Color.amountTint(isIncome: !isExpense)
    }
}

/// Lo que escriben los selectores de una fila de «Esto leí» en su borrador. Lo comparten la tarjeta de un registro y la
/// fila de la hoja de varios (`MultiDraftReviewList`).
enum VoiceDraftFieldEditing {
    /// Los selectores devuelven IDs; aquí vuelven a ser modelos contra lo cargado (nunca `model(for:)`, que fabrica
    /// un objeto aunque ya no exista). Importe y nota se corrigen en el formulario completo.
    @MainActor
    static func editing(
        draft: InboxDraft,
        accounts: [Account],
        subcategories: [Subcategory],
        tags: [Tag],
        context: ModelContext
    ) -> ChatDraftEditing {
        ChatDraftEditing(
            onAmountChange: { _ in },
            onAccountChange: { id in
                draft.account = accounts.first { $0.persistentModelID == id }
                persist(draft, context: context)
            },
            onSubcategoryChange: { id in
                draft.subcategory = subcategories.first { $0.persistentModelID == id }
                persist(draft, context: context)
            },
            onDateChange: { date in
                draft.date = date
                persist(draft, context: context)
            },
            onTagsChange: { ids in
                draft.setTags(from: tags.filter { ids.contains($0.persistentModelID) })
                persist(draft, context: context)
            },
            onNoteChange: { _ in }
        )
    }

    /// Lo que falta se recalcula con el mismo criterio que la Bandeja (`needsUserInput`), para que su fila diga lo
    /// mismo si el usuario cierra sin guardar.
    @MainActor
    static func persist(_ draft: InboxDraft, context: ModelContext) {
        var needs: [String] = []
        if draft.account == nil { needs.append(DraftInputRequirement.account) }
        if draft.subcategory == nil { needs.append(DraftInputRequirement.subcategory) }
        if draft.amount == nil { needs.append(DraftInputRequirement.amount) }
        draft.needsUserInput = needs
        draft.updatedAt = Date.now
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("VoiceDraftReviewCard: Error saving draft change: \(error)")
            #endif
        }
    }
}

extension View {
    /// Una pieza de una fila de «Esto leí» que no se toca: con la descripción en línea deja el toque al gesto de la fila,
    /// y VoiceOver la oye en el botón de fondo de la fila, no suelta.
    func rowPassesTouches(_ passes: Bool) -> some View {
        allowsHitTesting(!passes)
            .accessibilityHidden(passes)
    }
}
