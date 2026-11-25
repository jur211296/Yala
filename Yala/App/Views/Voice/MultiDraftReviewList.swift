//
//  MultiDraftReviewList.swift
//  Yala
//
//  La hoja de varios registros de foto y voz, propuesta C de Jürgen (2026-11-03, card va62): arriba el total de lo
//  marcado, una barra fina por categoría con su leyenda y las fechas; debajo, un bloque por día con su subtotal y una
//  fila compacta por registro con su marca. Todo sale marcado; lo desmarcado sigue en la Bandeja al guardar. Lo que
//  decide está en `MultiDraftReviewLogic`; la fila corrige categoría y cuenta con los selectores de siempre.
//
//  Con la opción A de «Esto leí» (Jürgen, 2026-11-22) la fila ya no abre el formulario al tocarla: se despliega con lo
//  que falta, la fecha, la cuenta y «Ver todo», que abre el editor completo dentro de la misma hoja. La primera marcada a
//  la que le falta algo sale desplegada sola (`EstoLeiLogic`), y el recuento dice cuántas quedan por completar.
//

import SwiftData
import SwiftUI

struct MultiDraftReviewList: View {
    let drafts: [InboxDraft]
    @Binding var selection: MultiDraftReviewLogic.Selection<PersistentIdentifier>
    /// La hoja de foto deja corregir la descripción tocándola (encargo del 2026-11-17); la de voz no lo pide.
    var editsNoteInPlace = false
    /// «Ver todo» de una fila: el editor completo, dentro de la misma hoja.
    let onOpenDetails: (InboxDraft) -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// La fila desplegada (una a la vez).
    @State private var expandedID: PersistentIdentifier?

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
        .dsAnimation(DS.Animation.appear, value: expandedID, reduceMotion: reduceMotion)
        .onChange(of: expansionKey, initial: true) { _, _ in settleExpansion() }
    }

    /// Lo que puede cambiar qué fila va desplegada: los borradores, qué falta en cada uno y si siguen pendientes.
    private var expansionKey: [String] {
        items.map { "\($0.id.hashValue)|\($0.isComplete)|\($0.isSaved)" }
    }

    private func settleExpansion() {
        let items = items
        expandedID = EstoLeiLogic.expandedAfterChange(
            current: expandedID, items, selection, order: Logic.days(items).flatMap(\.ids))
    }

    private func toggleExpansion(_ id: PersistentIdentifier) {
        expandedID = expandedID == id ? nil : id
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
    private func summaryToggleAll(pending: [PersistentIdentifier], markable: [PersistentIdentifier], allMarked: Bool) -> some View {
        // Sin nada completo que marcar, «Marcar todos» no haría nada: no sale.
        if !markable.isEmpty {
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
        // «Quitar todos» mira solo lo que se puede marcar: un incompleto nunca sale marcado.
        let markable = items.filter { $0.isPending && Logic.isMarkable($0) }.map(\.id)
        let allMarked = !markable.isEmpty && markable.allSatisfy(selection.contains)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Con texto de accesibilidad, el total encima de «Quitar todos»: al lado, el total salía «S/2….71» (pase de
            // estrés 2.2, card 48ri). A tamaño normal, la fila de siempre.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    summaryTotal(items, code: code)
                    summaryToggleAll(pending: pending, markable: markable, allMarked: allMarked)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    summaryTotal(items, code: code)
                    Spacer(minLength: DS.Spacing.sm)
                    summaryToggleAll(pending: pending, markable: markable, allMarked: allMarked)
                }
            }
            countLine(items, marked: marked.count)
                .font(DS.Typography.subheadline)
                .accessibilityIdentifier("multi_review_count")
            if !slices.isEmpty {
                categoryBar(slices)
                legend(Logic.legend(slices))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("multi_review_summary")
    }

    /// «5 de 7 · 19 – 22 nov.» y, si a alguno le falta algo, «· 2 por completar» en ámbar: es lo que dice por qué esos no
    /// se pueden marcar.
    private func countLine(_ items: [Item], marked: Int) -> Text {
        let base = Text(countAndRange(items, marked: marked)).foregroundStyle(.secondary)
        let incomplete = Logic.incompletePending(items)
        guard incomplete > 0 else { return base }
        let separator = Text(verbatim: " · ").foregroundStyle(.secondary)
        let toComplete = Text(L10n.EstoLei.toComplete(incomplete)).foregroundStyle(DS.Semantic.warningForeground)
        return Text("\(base)\(separator)\(toComplete)")
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
                        let item = items.first { $0.id == id }
                        MultiDraftReviewRow(
                            draft: draft,
                            isMarked: selection.contains(id) && (item.map { Logic.isMarkable($0) } ?? true),
                            canBeMarked: item.map { Logic.isMarkable($0) } ?? true,
                            editsNoteInPlace: editsNoteInPlace,
                            isExpanded: expandedID == id,
                            onToggle: {
                                selection.toggle(id)
                                DS.Haptic.selection()
                            },
                            onToggleExpanded: { toggleExpansion(id) },
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

/// Una fila compacta: marca, icono de categoría, nota y lo que falta (en ámbar), importe. Tocar la fila la despliega
/// (opción A, 2026-11-22) y, desplegada, es la tarjeta de un registro pegada a la izquierda (`EstoLeiCardStyle.row`,
/// 25-nov-2026). Ya guardada, no se despliega y la marca pasa a «Registrado».
private struct MultiDraftReviewRow: View {
    let draft: InboxDraft
    let isMarked: Bool
    /// Incompleto: el check sale vacío y no se puede tocar hasta completarlo (Jürgen, 25-nov-2026).
    let canBeMarked: Bool
    let editsNoteInPlace: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onToggleExpanded: () -> Void
    let onOpenDetails: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    /// La cuenta elegida sola al leer la foto (`CuentaSolaAlLeer`), para el chip y el selector.
    @Environment(\.cuentaSolaAlLeerHoja) private var cuentaSolaHoja

    private var isSaved: Bool { draft.status == .approved }
    private var isShowingCard: Bool { isExpanded && !isSaved }

    var body: some View {
        // Una fila puede volver a pintarse con su borrador ya borrado (rechazado desde el formulario completo).
        if draft.isDeleted || draft.modelContext == nil {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // La marca va centrada en vertical en la fila, también desplegada, a la altura del chevron (Jürgen, 25-nov).
            HStack(spacing: DS.ListRow.spacing) {
                mark
                Group {
                    if isShowingCard {
                        // Desplegada, la fila es la tarjeta de un registro: descripción en dos líneas, «S/ ▾» y monto,
                        // categoría, Hoy · Cuenta · # y el chevron de «Ver todo» (Jürgen, 25-nov-2026: «como Nuevo
                        // registro, bien ordenada»). Crece desde la fila plegada, sin saltar.
                        VoiceDraftReviewCard(
                            draft: draft, editsNoteInPlace: editsNoteInPlace, style: .row, onOpenDetails: onOpenDetails)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                            // La fila sigue existiendo para VoiceOver (y para quien cuenta las filas): su botón de fondo
                            // la lee entera y la pliega. El dedo lo reciben las piezas de la tarjeta.
                            .background { rowButton }
                    } else if isSaved {
                        rowLabel
                    } else {
                        // Plegada, un toque en cualquier parte de la fila la despliega; la descripción se edita ya
                        // desplegada, en la tarjeta (Jürgen, 25-nov-2026).
                        Button(action: onToggleExpanded) { rowLabel }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("voice_draft_row")
                    }
                }
                // Se atenúa lo que la persona quitó, no lo incompleto: eso tiene que verse para completarlo.
                .opacity(isMarked || isSaved || !canBeMarked ? 1 : 0.45)
            }
        }
        .padding(.vertical, DS.ListRow.paddingV)
        .padding(.horizontal, DS.ListRow.paddingH)
        // La fila que se está editando, con el borde del acento (Jürgen, 25-nov-2026: índigo, no ámbar). Lo que falta
        // ya lo dicen en ámbar sus chips.
        .overlay {
            if isShowingCard {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(theme.accent, lineWidth: 1.5)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("multi_review_row")
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
                        .strokeBorder(
                            isMarked ? Color.clear : Color.secondary.opacity(canBeMarked ? 0.6 : 0.25), lineWidth: 1.5)
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
            // Incompleto no se marca: se completa primero (el chip ámbar dice qué falta).
            .disabled(!canBeMarked)
            .accessibilityLabel(L10n.Voice.reviewIncludeA11y(title))
            .accessibilityValue(canBeMarked ? "" : L10n.UXL2.missingChipValue)
            .accessibilityAddTraits(isMarked ? .isSelected : [])
            .accessibilityIdentifier("multi_review_check")
        }
    }

    /// Desplegada, la fila sigue existiendo para VoiceOver: lee la fila entera y la pliega. Solo para VoiceOver: el dedo
    /// lo reciben las piezas de la tarjeta, encima.
    private var rowButton: some View {
        Button(action: onToggleExpanded) {
            Color.clear
        }
        .buttonStyle(.plain)
        .allowsHitTesting(false)
        .accessibilityLabel([title, draft.subcategory?.name ?? L10n.Common.uncategorized,
                             draft.amount == nil ? L10n.Chat.Draft.missingAmount : formattedAmount].joined(separator: ", "))
        .accessibilityIdentifier("voice_draft_row")
    }

    private var accountPresentation: CuentaSolaAlLeerChipPresentacion {
        CuentaSolaAlLeerChipPresentacion.make(
            eleccion: cuentaSolaHoja.eleccion(for: draft), currentAccountID: draft.account?.shortcutID,
            accountName: draft.account?.name, muestraPorque: false, selectAccount: L10n.Chat.Draft.selectAccount)
    }

    private var rowLabel: some View {
        HStack(spacing: DS.ListRow.spacing) {
            ChatDraftCategoryIcon(subcategory: draft.subcategory)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
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

    /// Lo que falta, en ámbar y en texto («Falta la categoría»); los chips para completarlo van en lo desplegado. Si no
    /// falta nada, la subcategoría.
    @ViewBuilder
    private var detailLine: some View {
        if !isSaved, let missing = missingText {
            Text(missing)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Semantic.warningForeground)
                .lineLimit(1)
        } else {
            Text(draft.subcategory?.name ?? L10n.Common.uncategorized)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// Lo primero que falta, con las palabras de la tarjeta de un registro (`EstoLeiLogic.missing`).
    private var missingText: String? {
        let readiness = VoiceDraftReadiness(
            hasAmount: draft.amount != nil, hasAccount: draft.account != nil,
            accountIsArchived: draft.account?.isArchived ?? false, hasSubcategory: draft.subcategory != nil,
            isFutureDate: false)
        switch EstoLeiLogic.missing(readiness).first {
        case .amount: return L10n.Chat.Draft.missingAmount
        case .subcategory: return L10n.Chat.Draft.missingSubcategory
        case .account: return accountPresentation.titulo
        case nil: return nil
        }
    }

    private var title: String {
        if !draft.note.isEmpty { return draft.note }
        return draft.subcategory?.name ?? L10n.Common.uncategorized
    }

    private var formattedAmount: String {
        guard let amount = draft.amount else { return "–" }
        let code = draft.account?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue
        return appPreferences.currency(
            VoiceEntryFlowLogic.reviewDisplayedAmount(amount), currencyCode: code, forceFullPrecision: true)
    }
}
