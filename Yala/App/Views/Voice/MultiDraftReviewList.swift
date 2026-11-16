//
//  MultiDraftReviewList.swift
//  Yala
//
//  La hoja de varios registros de foto y voz, propuesta C de Jürgen (2026-11-03, card va62): arriba el total de lo
//  marcado, una barra fina por categoría con su leyenda y las fechas; debajo, un bloque por día con su subtotal y una
//  fila compacta por registro con su marca. Todo sale marcado; lo desmarcado sigue en la Bandeja al guardar. Lo que
//  decide está en `MultiDraftReviewLogic`; la fila corrige categoría y cuenta con los selectores de siempre.
//

import SwiftData
import SwiftUI

struct MultiDraftReviewList: View {
    let drafts: [InboxDraft]
    @Binding var selection: MultiDraftReviewLogic.Selection<PersistentIdentifier>
    let onOpenDetails: (InboxDraft) -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    typealias Logic = MultiDraftReviewLogic
    typealias Item = MultiDraftReviewLogic.Item<PersistentIdentifier>

    private var items: [Item] {
        Logic.items(for: drafts, defaultCurrency: appPreferences.defaultCurrencyCode.rawValue)
    }

    var body: some View {
        let items = items
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            summary(items)
            ForEach(Logic.days(items), id: \.day) { day in
                daySection(day, items: items)
            }
        }
        .dsAnimation(DS.Animation.selection, value: selection, reduceMotion: reduceMotion)
    }

    // MARK: - Resumen

    @ViewBuilder
    private func summaryTotal(_ items: [Item], code: String?) -> some View {
        if let code {
            AmountText(
                value: Logic.total(items, selection),
                currencyCode: code,
                font: DS.Typography.amountLarge,
                secondaryFont: DS.Typography.subheadline,
                forceFullPrecision: true,
                animatesValue: true
            )
            .accessibilityIdentifier("multi_review_total")
        }
    }

    @ViewBuilder
    private func summaryToggleAll(pending: [PersistentIdentifier], allMarked: Bool) -> some View {
        if !pending.isEmpty {
            Button(allMarked ? L10n.Voice.reviewDeselectAll : L10n.Voice.reviewSelectAll) {
                selection.setAll(!allMarked, pending: pending)
                DS.Haptic.selection()
            }
            .font(DS.Typography.label)
            .foregroundStyle(.thAccentText)
            .frame(minHeight: 44)
            .accessibilityIdentifier("multi_review_toggle_all")
        }
    }

    private func summary(_ items: [Item]) -> some View {
        let marked = Logic.marked(items, selection)
        let code = Logic.sharedCurrency(marked.isEmpty ? items : marked)
        let slices = code == nil ? [] : Logic.slices(items, selection)
        let pending = items.filter(\.isPending).map(\.id)
        let allMarked = pending.allSatisfy(selection.contains)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Con texto de accesibilidad, el total encima de «Quitar todos»: al lado, el total salía «S/2….71» (pase de
            // estrés 2.2, card 48ri). A tamaño normal, la fila de siempre.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    summaryTotal(items, code: code)
                    summaryToggleAll(pending: pending, allMarked: allMarked)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    summaryTotal(items, code: code)
                    Spacer(minLength: DS.Spacing.sm)
                    summaryToggleAll(pending: pending, allMarked: allMarked)
                }
            }
            Text(countAndRange(items, marked: marked.count))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("multi_review_count")
            if !slices.isEmpty {
                categoryBar(slices)
                legend(Logic.legend(slices))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("multi_review_summary")
    }

    private func countAndRange(_ items: [Item], marked: Int) -> String {
        let count = L10n.Voice.reviewSelectedOf(marked, items.count)
        guard let range = Logic.dateRange(items) else { return count }
        let style = Date.FormatStyle.dateTime.day().month(.abbreviated)
        let dates = Calendar.current.isDate(range.lowerBound, inSameDayAs: range.upperBound)
            ? range.lowerBound.formatted(style)
            : "\(range.lowerBound.formatted(style)) – \(range.upperBound.formatted(style))"
        return "\(count) · \(dates)"
    }

    /// Tramos sólidos separados por un hueco, sin degradados. El ancho se mide en el carril (regla del iPhone Duo: un
    /// relleno medido no fija el ancho de un hermano dentro de lo que se mide).
    private func categoryBar(_ slices: [Logic.Slice]) -> some View {
        let total = slices.reduce(0) { $0 + $1.value }
        let gap: CGFloat = 3
        return Color.clear
            .frame(height: 6) // A11Y-DT: barra decorativa
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    let usable = max(0, proxy.size.width - gap * CGFloat(max(slices.count - 1, 0)))
                    HStack(spacing: gap) {
                        ForEach(slices, id: \.key) { slice in
                            Capsule()
                                .fill(color(slice))
                                .frame(width: total > 0 ? usable * slice.value / total : 0)
                        }
                    }
                }
            }
            .accessibilityHidden(true)
    }

    private func legend(_ slices: [Logic.Slice]) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(slices, id: \.key) { slice in
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(color(slice))
                        .frame(width: 8, height: 8) // A11Y-DT: punto de la leyenda
                        .accessibilityHidden(true)
                    Text(slice.name)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func color(_ slice: Logic.Slice) -> Color {
        slice.colorHex.map { Color(hex: $0) } ?? Color.secondary.opacity(0.35)
    }

    // MARK: - Días

    private func daySection(_ day: Logic.Day<PersistentIdentifier>, items: [Item]) -> some View {
        let dayItems = items.filter { day.ids.contains($0.id) }
        let markedInDay = Logic.marked(dayItems, selection)
        let code = Logic.sharedCurrency(markedInDay.isEmpty ? dayItems : markedInDay)
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(ChatDraftFormatting.dateLabel(day.day))
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: DS.Spacing.sm)
                if let code {
                    Text(appPreferences.currency(
                        Logic.subtotal(day.ids, items: items, selection), currencyCode: code, forceFullPrecision: true))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(day.ids.enumerated()), id: \.element) { index, id in
                    if let draft = drafts.first(where: { $0.persistentModelID == id }) {
                        if index > 0 {
                            Divider().padding(.leading, DS.ListRow.paddingH + 28 + DS.ListRow.spacing)
                        }
                        MultiDraftReviewRow(
                            draft: draft,
                            isMarked: selection.contains(id),
                            onToggle: {
                                selection.toggle(id)
                                DS.Haptic.selection()
                            },
                            onOpenDetails: { onOpenDetails(draft) }
                        )
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(.thCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("multi_review_day")
    }
}

extension MultiDraftReviewLogic {
    /// Los borradores de la hoja como los lee la lógica. La divisa de cada uno es la de su cuenta, o la principal: la
    /// misma con la que se pinta su importe.
    @MainActor
    static func items(for drafts: [InboxDraft], defaultCurrency: String) -> [Item<PersistentIdentifier>] {
        drafts.filter { !$0.isDeleted && $0.modelContext != nil }.map { draft in
            let readiness = VoiceDraftReadiness(
                hasAmount: draft.amount != nil,
                hasAccount: draft.account != nil,
                accountIsArchived: draft.account?.isArchived ?? false,
                hasSubcategory: draft.subcategory != nil,
                isFutureDate: DraftFutureDateLogic.isFuture(draft.effectiveDate)
            )
            let category = draft.subcategory?.safeCategory
            return Item(
                id: draft.persistentModelID,
                amount: draft.amount,
                currencyCode: draft.account?.currencyCode ?? defaultCurrency,
                date: draft.effectiveDate,
                categoryKey: category.map { String(describing: $0.persistentModelID) },
                categoryName: category?.name ?? L10n.Common.uncategorized,
                colorHex: category?.colorHex,
                isPending: draft.status == .pending,
                isSaved: draft.status == .approved,
                isComplete: readiness.isComplete
            )
        }
    }
}

// MARK: - Fila

/// Una fila compacta: marca, icono de categoría, nota y lo que falta (en ámbar, abre su selector), importe. Tocar la
/// fila abre el formulario completo; ya guardada, no abre nada y la marca pasa a «Registrado».
private struct MultiDraftReviewRow: View {
    let draft: InboxDraft
    let isMarked: Bool
    let onToggle: () -> Void
    let onOpenDetails: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var allAccounts: [Account]
    @Query(filter: #Predicate<Subcategory> { $0.isVisible == true }) private var allSubcategories: [Subcategory]
    @Query private var allTags: [Tag]

    @State private var activeField: ChatDraftField?

    private var isSaved: Bool { draft.status == .approved }

    var body: some View {
        // Una fila puede volver a pintarse con su borrador ya borrado (rechazado desde el formulario completo).
        if draft.isDeleted || draft.modelContext == nil {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: DS.ListRow.spacing) {
            mark
            Group {
                if isSaved {
                    rowLabel
                } else {
                    Button(action: onOpenDetails) { rowLabel }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("voice_draft_row")
                }
            }
            .opacity(isMarked || isSaved ? 1 : 0.45)
        }
        .padding(.vertical, DS.ListRow.paddingV)
        .padding(.horizontal, DS.ListRow.paddingH)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("multi_review_row")
        .sheet(item: $activeField) { field in
            ChatDraftFieldSheet(
                field: field,
                isExpense: (draft.amount ?? -1) < 0,
                account: draft.account,
                subcategory: draft.subcategory,
                tags: currentTags,
                date: draft.effectiveDate,
                editing: VoiceDraftFieldEditing.editing(
                    draft: draft, accounts: allAccounts, subcategories: allSubcategories, tags: allTags,
                    context: modelContext
                )
            )
        }
    }

    @ViewBuilder
    private var mark: some View {
        if isSaved {
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.title3)
                .foregroundStyle(DS.Semantic.successForeground)
                .frame(width: 28, height: 28) // A11Y-DT: misma caja que la marca
                .accessibilityLabel(L10n.Chat.Draft.savedBadge)
                .accessibilityIdentifier("voice_draft_saved")
        } else {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isMarked ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color.clear))
                    Circle()
                        .strokeBorder(isMarked ? Color.clear : Color.secondary.opacity(0.6), lineWidth: 1.5)
                    if isMarked {
                        Image(systemName: "checkmark")
                            .font(DS.Typography.labelSmall.weight(.bold))
                            .foregroundStyle(theme.onAccent)
                    }
                }
                .frame(width: 28, height: 28) // A11Y-DT: marca de selección; el toque es de 44
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .accessibilityLabel(L10n.Voice.reviewIncludeA11y(title))
            .accessibilityAddTraits(isMarked ? .isSelected : [])
            .accessibilityIdentifier("multi_review_check")
        }
    }

    private var rowLabel: some View {
        HStack(spacing: DS.ListRow.spacing) {
            ChatDraftCategoryIcon(subcategory: draft.subcategory)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                detailLine
            }
            Spacer(minLength: DS.Spacing.sm)
            Text(draft.amount == nil ? L10n.Chat.Draft.missingAmount : formattedAmount)
                .font(draft.amount == nil ? DS.Typography.caption : DS.Typography.headline)
                .foregroundStyle(
                    draft.amount == nil
                        ? AnyShapeStyle(DS.Semantic.warningForeground)
                        : AnyShapeStyle(Color.amountTint(isIncome: (draft.amount ?? -1) >= 0))
                )
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }

    /// Lo que falta va primero y en ámbar, como en la tarjeta de un registro; si no falta nada, la subcategoría.
    @ViewBuilder
    private var detailLine: some View {
        if !isSaved, draft.subcategory == nil || draft.account == nil {
            HStack(spacing: DS.Spacing.xs) {
                if draft.subcategory == nil {
                    missingChip(.subcategory, title: L10n.Chat.Draft.selectSubcategory)
                }
                if draft.account == nil {
                    missingChip(.account, title: L10n.Chat.Draft.selectAccount)
                }
            }
        } else {
            Text(draft.subcategory?.name ?? L10n.Common.uncategorized)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func missingChip(_ field: ChatDraftField, title: String) -> some View {
        Button {
            activeField = field
        } label: {
            Text(title)
                .font(DS.Typography.labelSmall)
                .lineLimit(1)
                .foregroundStyle(DS.Semantic.warningForeground)
                .padding(.horizontal, DS.Chip.paddingH)
                .padding(.vertical, DS.Spacing.xxs)
                .background(Capsule().fill(DS.Semantic.warningBackground))
                .overlay(Capsule().strokeBorder(DS.Semantic.warningForeground, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("voice_draft_chip_\(field.rawValue)")
    }

    private var title: String {
        if !draft.note.isEmpty { return draft.note }
        return draft.subcategory?.name ?? L10n.Common.uncategorized
    }

    private var currentTags: [Tag] {
        guard let ids = draft.resolvedTagIDs() else { return [] }
        return allTags.filter { ids.contains($0.id) }
    }

    private var formattedAmount: String {
        guard let amount = draft.amount else { return "–" }
        let code = draft.account?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue
        return appPreferences.currency(
            VoiceEntryFlowLogic.reviewDisplayedAmount(amount), currencyCode: code, forceFullPrecision: true)
    }
}
