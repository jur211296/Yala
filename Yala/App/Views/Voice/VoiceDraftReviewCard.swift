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
    let onOpenDetails: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var allAccounts: [Account]
    @Query(filter: #Predicate<Subcategory> { $0.isVisible == true }) private var allSubcategories: [Subcategory]
    @Query private var allTags: [Tag]

    @State private var activeField: ChatDraftField?

    private var isSaved: Bool { draft.status == .approved }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            // Guardada, la fila ya no abre nada; sin `.disabled`, que la atenuaría como si faltara algo.
            if isSaved {
                row
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("voice_draft_row")
            } else {
                Button(action: onOpenDetails) {
                    row
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("voice_draft_row")

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
        }
    }

    // MARK: - Fila

    private var row: some View {
        HStack(spacing: DS.ListRow.spacing) {
            ChatDraftCategoryIcon(subcategory: draft.subcategory)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(
                        draft.subcategory == nil
                            ? AnyShapeStyle(DS.Semantic.warningForeground) : AnyShapeStyle(.secondary)
                    )
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.sm)

            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
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
        .padding(.top, DS.ListRow.paddingV)
        .padding(.bottom, isSaved ? DS.ListRow.paddingV : DS.Spacing.sm)
        .padding(.horizontal, DS.ListRow.paddingH)
        .contentShape(Rectangle())
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

    private var chipsRow: some View {
        FlowLayout(spacing: DS.Spacing.sm) {
            if draft.subcategory == nil {
                chip(.subcategory, title: L10n.Chat.Draft.selectSubcategory, isMissing: true)
            }
            chip(
                .account,
                title: draft.account?.name ?? L10n.Chat.Draft.selectAccount,
                isMissing: draft.account == nil
            )
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
        .accessibilityIdentifier("voice_draft_chip_\(field.rawValue)")
    }

    // MARK: - Edición

    /// Los selectores devuelven IDs; aquí vuelven a ser modelos contra lo cargado (nunca `model(for:)`, que fabrica
    /// un objeto aunque ya no exista). Importe y nota se corrigen en el formulario completo.
    private var editing: ChatDraftEditing {
        ChatDraftEditing(
            onAmountChange: { _ in },
            onAccountChange: { id in
                draft.account = allAccounts.first { $0.persistentModelID == id }
                persistChange()
            },
            onSubcategoryChange: { id in
                draft.subcategory = allSubcategories.first { $0.persistentModelID == id }
                persistChange()
            },
            onDateChange: { date in
                draft.date = date
                persistChange()
            },
            onTagsChange: { ids in
                draft.setTags(from: allTags.filter { ids.contains($0.persistentModelID) })
                persistChange()
            },
            onNoteChange: { _ in }
        )
    }

    /// Lo que falta se recalcula con el mismo criterio que la Bandeja (`needsUserInput`), para que su fila diga lo
    /// mismo si el usuario cierra sin guardar.
    private func persistChange() {
        var needs: [String] = []
        if draft.account == nil { needs.append(DraftInputRequirement.account) }
        if draft.subcategory == nil { needs.append(DraftInputRequirement.subcategory) }
        if draft.amount == nil { needs.append(DraftInputRequirement.amount) }
        draft.needsUserInput = needs
        draft.updatedAt = Date.now
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("VoiceDraftReviewCard: Error saving draft change: \(error)")
            #endif
        }
    }

    // MARK: - Datos

    private var currentTags: [Tag] {
        guard let ids = draft.resolvedTagIDs() else { return [] }
        return allTags.filter { ids.contains($0.id) }
    }

    /// El borrador guarda el importe con signo: negativo es gasto.
    private var isExpense: Bool { (draft.amount ?? -1) < 0 }

    private var formattedAmount: String {
        guard let amount = draft.amount else { return "–" }
        let code = draft.account?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue
        return appPreferences.currency(abs(amount), currencyCode: code, forceFullPrecision: true)
    }

    /// Se colorea la excepción, no la norma: el gasto va en el color del texto y el ingreso en el tono oscurecido que
    /// sí se lee sobre la tarjeta (`.claude/rules/swiftui-ds.md`).
    private var amountColor: Color {
        isExpense ? Color.primary : Color.incomeAmount
    }
}
