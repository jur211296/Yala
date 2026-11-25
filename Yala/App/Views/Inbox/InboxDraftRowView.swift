//
//  InboxDraftRowView.swift
//  Yala
//
//  Fila individual para drafts en la bandeja de entrada.
//  Fase 8: Registro Inteligente
//

import SwiftData
import SwiftUI

struct InboxDraftRowView: View {
    let draft: InboxDraft
    let currencyCode: String
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    /// «Ya registrado el 15 oct · Descartar / Guardar igual» (Bandeja sin duplicados, lote 3): solo en la lista de
    /// pendientes y fuera del modo selección. Sin él, la fila de siempre.
    var alreadyRecorded: InboxAlreadyRecorded?
    var onDiscard: () -> Void = {}
    var onSaveAnyway: () -> Void = {}
    let onTap: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.tagCatalog) private var tagCatalog
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    /// UX 2.2 · L13-12: el borrador de un pago de grupo sin descripción se nombra («Pago a Ana · Viaje a Cusco»).
    @State private var settlementName: String?

    var body: some View {
        // La fila observa su `InboxDraft` y puede volver a pintarse con él ya borrado (bajo una hoja, en la animación de
        // salida, o borrado por otro camino): entonces no se lee nada de él, ni la etiqueta ni el identificador. Leerlo
        // aborta la app (crash de TestFlight 2.2 (2), card f8rj).
        if draft.isReadableInInbox {
            if let alreadyRecorded {
                recordedRow(alreadyRecorded)
            } else {
                row
            }
        }
    }

    private var row: some View {
        Button(action: onTap) {
            rowContent
                .padding(.vertical, DS.ListRow.paddingV)
                .padding(.horizontal, DS.ListRow.paddingH)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .shadow(
                    color: Color.black.opacity(theme.shadowOpacity),
                    radius: 6,
                    x: 0,
                    y: 3
                )
        }
        .buttonStyle(.plain)
        .modifier(rowIdentity)
    }

    /// La fila con «Ya registrado» debajo, en la misma tarjeta. Los dos botones van fuera del botón de la fila: dentro de
    /// su etiqueta no existirían para VoiceOver ni para XCUITest. Cada uno con su estilo, o la fila entera tocaría.
    private func recordedRow(_ recorded: InboxAlreadyRecorded) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                rowContent
                    .padding(.top, DS.ListRow.paddingV)
                    .padding(.bottom, DS.Spacing.sm)
                    .padding(.horizontal, DS.ListRow.paddingH)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .modifier(rowIdentity)

            InboxAlreadyRecordedFooter(recorded: recorded, onDiscard: onDiscard, onSaveAnyway: onSaveAnyway)
                .padding(.horizontal, DS.ListRow.paddingH)
                .padding(.bottom, DS.ListRow.paddingV)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(theme.shadowOpacity), radius: 6, x: 0, y: 3)
    }

    private var rowIdentity: InboxDraftRowIdentity {
        InboxDraftRowIdentity(label: accessibilityText, identifier: "inbox_draft_row_\(draft.note)",
                              draft: draft, settlementName: $settlementName, modelContext: modelContext)
    }

    private var rowContent: some View {
            // A tamaños de accesibilidad el importe baja bajo el concepto (`AdaptiveRowStack`), como en
            // `RecordRowView`: en fila se cortaba («S/-…50»). Apilada, icono y texto quedan juntos en su propia fila.
            AdaptiveRowStack(spacing: DS.ListRow.spacing, stackedSpacing: DS.Spacing.sm) {
                // Selection circle (only in selection mode)
                if isSelectionMode {
                    selectionCircle
                }

                // Icon: status-based for archived, subcategory-based for complete pending, source for incomplete
                leadingIcon

                // Text content - different layout based on completeness
                VStack(alignment: .leading, spacing: 3) { // DS: intentional non-token value
                    if draft.hasAllRequiredFields {
                        // Complete draft: show like RecordRowView
                        completeContentView
                    } else {
                        // Incomplete draft: show missing fields
                        incompleteContentView
                    }
                }
            } trailing: {
                // Amount column
                amountColumn
            }
    }

    /// La descripción que se enseña: la del borrador, el nombre del pago de grupo (L13-12) o «Sin descripción».
    private var shownNote: String {
        if !draft.note.isEmpty { return draft.note }
        return settlementName ?? L10n.Inbox.noDescription
    }

    /// La etiqueta de siempre y, en el aviso de importe cambiado, su segunda línea: sin ella VoiceOver no dice qué cambió.
    private var accessibilityText: String {
        let origin = draft.joinedSources.map { L10n.BandejaUnir.llegoPor(fuentes: $0.map(\.name).joined(separator: ", ")) }
            ?? draft.sourceDisplayName
        let base = L10n.Accessibility.draftRow(shownNote, draft.amount.map { appPreferences.currency($0, currencyCode: currencyCode) } ?? L10n.Inbox.noAmount, L10n.Inbox.status(draft.status)) + ", " + origin
        guard let detail = settlementAmountChangeDetail(accountName: draft.displayAccountName ?? "") else { return base }
        return "\(base), \(detail)"
    }

    // MARK: - Complete Content View (like RecordRowView)

    @ViewBuilder
    private var completeContentView: some View {
        // Use display properties that fall back to cached values
        let subcategoryName = draft.displaySubcategoryName ?? L10n.Common.uncategorized
        let accountName = draft.displayAccountName ?? ""

        // Line 1: Note (primary text) OR Subcategory (if no note)
        if !draft.note.isEmpty {
            Text(draft.note)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(conceptLineLimit)

            // Line 2: Subcategory • Account (el aviso de importe cambiado: la cuenta y lo que tiene ahora)
            Text(settlementAmountChangeDetail(accountName: accountName) ?? "\(subcategoryName) • \(accountName)")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            // Fallback: Line 1 = Subcategory
            Text(subcategoryName)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Line 2: Account name
            if !accountName.isEmpty {
                Text(settlementAmountChangeDetail(accountName: accountName) ?? accountName)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }

        // Line 3: Tags (if any) - only for pending drafts (archived may have invalid tag references)
        if draft.status == .pending {
            let resolvedTags = TagDisplayResolver.tags(for: draft, catalog: tagCatalog, order: appPreferences.tagsSortOrderNames)
            if !resolvedTags.isEmpty {
                tagsRow(resolvedTags)
            }
        }

        originLabel
    }

    /// De dónde llegó el borrador (UX 2.2 · L4-8): «¿de dónde salió esto?» es lo primero que se pregunta ante un gasto
    /// que no se apuntó a mano. Antes solo la fila incompleta enseñaba su origen, y solo con un icono.
    ///
    /// Un pendiente que la Bandeja unió (lote 3 de la Bandeja sin duplicados) enseña una cápsula por fuente, en el orden
    /// en que llegaron: «Apple Pay · Aviso de BCP · Correo». Si no caben en una línea, una debajo de otra.
    @ViewBuilder
    private var originLabel: some View {
        if let sources = draft.joinedSources {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                        originCapsule(name: source.name, icon: source.icon)
                    }
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                        originCapsule(name: source.name, icon: source.icon)
                    }
                }
            }
            .accessibilityIdentifier("inbox_draft_sources")
        } else {
            originCapsule(name: draft.sourceDisplayName, icon: draft.sourceIcon)
        }
    }

    private func originCapsule(name: String, icon: String) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(DS.Typography.captionSmall)
                .accessibilityHidden(true)
            Text(name)
                .font(DS.Typography.captionSmall)
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
        .accessibilityIdentifier("inbox_draft_origin")
    }

    /// Segunda línea del aviso de importe cambiado pendiente: la cuenta de la transacción y lo que tiene ahora, leídos por
    /// la marca (`GroupTransactionBridge.amountChangeTarget`), no por el aviso. Solo pendiente: un archivado no lee
    /// relaciones (pueden estar invalidadas) y cae a la línea de siempre.
    private func settlementAmountChangeDetail(accountName: String) -> String? {
        guard draft.isSettlementAmountChangeNotice, draft.status == .pending else { return nil }
        let resolved: (mark: InboxDraft, transaction: TransactionItem)?
        do {
            resolved = try GroupTransactionBridge.amountChangeTarget(
                settlementID: draft.splitSettlementID, in: modelContext)
        } catch {
            #if DEBUG
            print("InboxDraftRowView: amountChangeTarget: Error: \(error)")
            #endif
            return nil
        }
        guard let transaction = resolved?.transaction else { return nil }
        let inAccount = appPreferences.currency(
            abs(transaction.amount), currencyCode: transaction.currencyCode, forceFullPrecision: true)
        return L10n.Inbox.GroupSettlementAmountChange.rowDetail(transaction.account?.name ?? accountName, inAccount)
    }

    /// Una línea a los tamaños normales; dos a los de accesibilidad, donde el concepto ya tiene la fila entera.
    private var conceptLineLimit: Int { dynamicTypeSize.isAccessibilitySize ? 2 : 1 }

    // MARK: - Incomplete Content View

    @ViewBuilder
    private var incompleteContentView: some View {
        // Line 1: Note or placeholder
        Text(shownNote)
            .font(DS.Typography.label)
            .foregroundStyle(draft.note.isEmpty && settlementName == nil ? .secondary : .primary)
            .lineLimit(conceptLineLimit)

        // Line 2: Missing fields indicators
        if !draft.needsUserInput.isEmpty {
            missingFieldsRow
        }

        originLabel

        // Line 3: Date
        Text(formattedDate)
            .font(DS.Typography.caption)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Amount Column

    private var amountColumn: some View {
        VStack(alignment: .trailingUnlessStacked(dynamicTypeSize), spacing: DS.Spacing.xs) {
            if let amount = draft.amount {
                AmountText(
                    value: amount,
                    currencyCode: currencyCode,
                    font: DS.Typography.headline, secondaryFont: DS.Typography.caption,
                    tint: .color(Color.amountTint(isIncome: amount >= 0)),
                    forceFullPrecision: true
                )
            } else {
                Text(L10n.Inbox.noAmount)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
            }

            // Date for complete drafts, confidence for incomplete
            if draft.hasAllRequiredFields {
                Text(formattedDate)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            } else if let confidence = draft.confidenceAmount, confidence < 0.7 {
                // Confidence indicator for incomplete drafts with low confidence
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DS.Typography.captionSmall)
                    Text("\(Int(confidence * 100))%")
                        .font(DS.Typography.captionSmall)
                }
                .foregroundStyle(DS.Semantic.warningForeground)
            }
        }
    }

    // MARK: - Tags Row

    private func tagsRow(_ tags: [Tag]) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(tags.prefix(3)), id: \.persistentModelID) { tag in
                Text(tag.name)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(Color.contrastingText(for: Color(hex: tag.colorHex)))
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(Color(hex: tag.colorHex))
                    )
            }

            if tags.count > 3 {
                Text("+\(tags.count - 3)")
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
        }
    }


    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .fill(.thCard)
    }

    // MARK: - Selection Circle

    private var selectionCircle: some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected ? theme.accent : Color.secondary.opacity(0.3),
                    lineWidth: 2
                )
                .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)

            if isSelected {
                Circle()
                    .fill(theme.accent)
                    .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)

                Image(systemName: "checkmark")
                    .font(DS.Typography.badgeLabel)
                    .foregroundStyle(.thOnAccent)
            }
        }
    }

    // MARK: - Leading Icon

    @ViewBuilder
    private var leadingIcon: some View {
        switch draft.status {
        case .approved:
            // Show green check or warning if transaction was deleted
            if draft.wasTransactionDeleted {
                // Transaction was deleted - show warning icon
                ZStack {
                    Circle()
                        .fill(DS.Semantic.warningBackground)
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Semantic.warningForeground)
                }
            } else {
                // Normal approved - show green check
                ZStack {
                    Circle()
                        .fill(DS.Semantic.successBackground)
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Semantic.successForeground)
                }
            }

        case .rejected:
            // Show red X
            ZStack {
                Circle()
                    .fill(DS.Semantic.errorBackground)
                    .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                Image(systemName: "xmark.circle.fill")
                    .font(DS.Typography.label)
                    .foregroundStyle(DS.Semantic.errorForeground)
            }

        case .pending:
            // For pending: show subcategory icon if complete, source icon if incomplete
            if draft.hasAllRequiredFields {
                // Complete: show subcategory icon with category color (like RecordRowView)
                // Use display properties that fall back to cached values
                let colorHex = draft.displayCategoryColorHex
                let iconName = draft.displaySubcategoryIcon

                ZStack {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                    Image(systemName: iconName)
                        .font(DS.Typography.label)
                        .foregroundStyle(.white)
                }
            } else {
                // Incomplete: show source type icon
                ZStack {
                    Circle()
                        .fill(sourceColor.opacity(0.15))
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                    Image(systemName: draft.sourceIcon)
                        .font(DS.Typography.label)
                        .foregroundStyle(sourceColor)
                }
            }
        }
    }

    private var sourceColor: Color {
        switch draft.sourceType {
        case .voice:
            return Color.essentialNeed       // amber #F59E0B — input rápido
        case .receiptPhoto, .screenshotList, .screenshotSingle:
            return Color.priorityNeedNew     // purple #8B5CF6 — análisis OCR/foto
        case .emailAlert:
            return theme.accent              // tema — datos externos parseados
        case .scheduledPayment, .subscription:
            return Color.electricIndigo      // indigo brand — recurring
        case .applePay:
            return theme.priorityNeed        // tema — Apple Pay
        case .automation:
            return theme.secondaryText       // neutro
        case .siri:
            return theme.accent              // tema — Siri AI parsed
        case .groupExpense, .groupSettlement:
            return Color.hotPink             // brand pink — grupos
        case .manual:
            return theme.secondaryText       // neutro — draft convertido (FU-02 cleanup)
        case .groupScheduledExpense:
            return Color.hotPink             // brand pink — gasto de grupo recurrente
        case .aiConnector:
            return theme.accent              // tema — lo apuntó la IA de la persona
        }
    }

    // MARK: - Missing Fields Row

    private var missingFieldsRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(L10n.Inbox.missingLabel)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)

            ForEach(draft.needsUserInput.prefix(2), id: \.self) { field in
                Text(localizedFieldName(field))
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.thPrimaryText)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(Color.essentialNeed.opacity(0.25))
                    )
            }

            if draft.needsUserInput.count > 2 {
                Text("+\(draft.needsUserInput.count - 2)")
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func localizedFieldName(_ field: String) -> String {
        InboxDraft.localizedMissingField(field)
    }

    // MARK: - Helpers

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = AppLocale.current
        return f
    }()

    private var formattedDate: String {
        let date = draft.effectiveDate
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return L10n.Date.today
        } else if calendar.isDateInYesterday(date) {
            return L10n.Date.yesterday
        } else {
            return Self.mediumDateFormatter.string(from: date)
        }
    }
}

// MARK: - La identidad de la fila

/// Lo que la fila de siempre llevaba colgado de su botón: un elemento de accesibilidad con su etiqueta e identificador, y
/// el nombre del pago de grupo sin descripción (L13-12). Igual en la fila sola y en la que lleva «Ya registrado».
private struct InboxDraftRowIdentity: ViewModifier {
    let label: String
    let identifier: String
    let draft: InboxDraft
    @Binding var settlementName: String?
    let modelContext: ModelContext

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
            .task(id: draft.persistentModelID) {
                guard draft.isReadableInInbox, draft.sourceType == .groupSettlement, draft.note.isEmpty,
                      !draft.isSettlementAmountChangeNotice else { return }
                settlementName = GroupSettlementDraftNameResolver.name(for: draft, context: modelContext)
            }
    }
}

// MARK: - «Ya registrado» (Bandeja sin duplicados, lote 3)

/// «Ya registrado el 15 oct · Descartar / Guardar igual», bajo la fila de un pendiente que se parece a un registro ya
/// guardado. Es lo mismo que frenaría «Guardar los listos», dicho antes de intentarlo.
struct InboxAlreadyRecordedFooter: View {
    let recorded: InboxAlreadyRecorded
    let onDiscard: () -> Void
    let onSaveAnyway: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            // En una fila solo si el aviso cabe entero en una línea; si no, el aviso arriba y los botones debajo.
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                notice(singleLine: true)
                Spacer(minLength: 0)
                buttons
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                notice(singleLine: false)
                buttons
            }
        }
    }

    private func notice(singleLine: Bool) -> some View {
        Label {
            Text(L10n.BandejaUnir.yaRegistrado(fecha: recorded.dateText))
                .fixedSize(horizontal: singleLine, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DS.Semantic.warningForeground)
        }
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.BandejaUnir.yaRegistradoDetalle(recorded.summary))
        .accessibilityIdentifier("inbox_already_recorded")
    }

    private var buttons: some View {
        HStack(spacing: DS.Spacing.md) {
            Button(L10n.BandejaUnir.descartar, action: onDiscard)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("inbox_already_recorded_discard")
            Button(L10n.BandejaUnir.guardarIgual, action: onSaveAnyway)
                .buttonStyle(.borderless)
                .accessibilityHint(L10n.BandejaUnir.guardarIgualPista)
                .accessibilityIdentifier("inbox_already_recorded_save_anyway")
        }
        .font(DS.Typography.subheadlineEmphasized)
        .foregroundStyle(theme.accentText)
    }
}

// MARK: - «¿Es el mismo gasto?» (Bandeja sin duplicados, lote 3)

/// Dos pendientes que pueden ser el mismo consumo, juntos en una tarjeta: «¿Es el mismo gasto?» con «Es el mismo» y «Son
/// distintos». Cada fila sigue abriendo su borrador.
struct InboxSameExpensePairCard: View {
    let pair: InboxSameExpensePair
    let currencyCode: (InboxDraft) -> String
    let onOpen: (InboxDraft) -> Void
    let onSame: () -> Void
    let onDistinct: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        if pair.holder.isReadableInInbox && pair.arriving.isReadableInInbox {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label(L10n.BandejaUnir.preguntaTitulo, systemImage: "square.on.square")
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("inbox_same_expense_title")

                ForEach(pair.chronological, id: \.persistentModelID) { draft in
                    InboxDraftRowView(draft: draft, currencyCode: currencyCode(draft)) { onOpen(draft) }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DS.Spacing.sm) { sameButton; distinctButton }
                    VStack(spacing: DS.Spacing.sm) { sameButton; distinctButton }
                }
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(theme.accent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("inbox_same_expense_pair")
        }
    }

    private var sameButton: some View {
        Button(action: onSame) {
            Text(L10n.BandejaUnir.esElMismo)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(theme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(Capsule().fill(theme.accent))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.BandejaUnir.esElMismoPista)
        .accessibilityIdentifier("inbox_same_expense_same")
    }

    private var distinctButton: some View {
        Button(action: onDistinct) {
            Text(L10n.BandejaUnir.sonDistintos)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(theme.accentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(Capsule().fill(theme.accent.opacity(0.12)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.BandejaUnir.sonDistintosPista)
        .accessibilityIdentifier("inbox_same_expense_distinct")
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()

        VStack(spacing: DS.Spacing.md) {
            Text("InboxDraftRowView Preview")
                .font(DS.Typography.headline)
        }
        .padding()
    }
}
