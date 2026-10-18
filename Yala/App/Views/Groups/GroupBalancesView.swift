//
//  GroupBalancesView.swift
//  Yala
//
//  Saldos de un grupo. Auditoría UX 2.2 (decisiones de Jürgen del 15-oct):
//  - L13-2 (variante 2): un pago que te toca confirmar sube a una tarjeta arriba de todo, «Ana dice que te pagó S/ 50 ·
//    ¿Lo recibiste?», con «Sí, lo recibí» y «No me llegó», que pregunta antes de quitarlo.
//  - L13-1 (variante 3 combinada): arriba lo tuyo (cuánto te deben o debes) y debajo «Para quedar a mano» con cada deuda
//    en una tarjeta con avatares; las tuyas, resaltadas y con «Saldar»; las de los demás, sin botón. Sin la lista de
//    saldo por miembro: el cuadro de arriba y las deudas ya dicen quién debe a quién con palabras, no solo con color.
//

import SwiftUI

struct GroupBalancesView: View {

    let balances: [MemberBalance]
    let debts: [Debt]
    let settlements: [SplitSettlement]
    let memberNameLookup: [String: String]
    /// Quién eres en este grupo. `nil` (sin resolver): no hay «lo tuyo» y ninguna deuda lleva botón.
    var currentUserMemberID: String?
    var groupColorHex: String = "#8B5CF6"

    /// True si los balances/debts vienen de consolidar multiples monedas a una sola.
    /// Drives `isEstimate` (prefijo "≈") cuando hubo conversión real.
    var balancesWereConverted: Bool = false
    var debtsWereConverted: Bool = false

    // Callbacks (optional for backwards compatibility)
    var onSettleDebt: ((Debt) -> Void)?
    var onConfirmSettlement: ((SplitSettlement) -> Void)?
    var onRejectSettlement: ((SplitSettlement) -> Void)?
    /// Eliminar una liquidación YA CONFIRMADA. Las pendientes se rechazan (`onRejectSettlement`),
    /// no se eliminan: son dos gestos distintos sobre estados distintos.
    var onDeleteSettlement: ((SplitSettlement) -> Void)?

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 32 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .body) private var largeAvatarSize: CGFloat = 40 // A11Y-DT: @ScaledMetric

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    /// Liquidación elegida en el menú de la fila, a la espera del diálogo de confirmación.
    @State private var settlementToDelete: SplitSettlement?
    @State private var showDeleteSettlementConfirm = false
    /// L13-2: «No me llegó» pregunta antes de quitar el pago (antes la ✗ lo borraba al primer toque).
    @State private var settlementToReject: SplitSettlement?
    @State private var showRejectConfirm = false

    private var pendingForMe: [SplitSettlement] {
        guard onConfirmSettlement != nil else { return [] }
        return settlements.filter {
            GroupBalancesPresentationLogic.needsMyConfirmation(
                isConfirmed: $0.isConfirmed, toMemberID: $0.toMemberID, currentUserMemberID: currentUserMemberID)
        }
    }

    private var listedSettlements: [SplitSettlement] {
        let shownAbove = Set(pendingForMe.map(\.id))
        return settlements.filter { !shownAbove.contains($0.id) }
    }

    var body: some View {
        let pending = pendingForMe
        if balances.isEmpty && debts.isEmpty && pending.isEmpty {
            YalaEmptyState(
                icon: "checkmark.circle",
                title: L10n.Groups.Balance.noDebts
            )
        } else {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    if !pending.isEmpty {
                        VStack(spacing: DS.Spacing.md) {
                            ForEach(pending, id: \.id) { pendingCard($0) }
                        }
                    }

                    if !balances.isEmpty || !debts.isEmpty,
                       let summary = GroupBalancesPresentationLogic.summary(
                        debts: debts, currentUserMemberID: currentUserMemberID) {
                        summaryCard(summary)
                    }

                    if !debts.isEmpty {
                        debtsSection
                    }

                    let listed = listedSettlements
                    if !listed.isEmpty {
                        settlementsSection(listed)
                    }
                }
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
            .scrollViewGlassEdges()
            .confirmationDialog(
                L10n.Groups.Settlement.deleteTitle,
                isPresented: $showDeleteSettlementConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Action.delete, role: .destructive) {
                    if let settlement = settlementToDelete {
                        onDeleteSettlement?(settlement)
                    }
                    settlementToDelete = nil
                }
                // Lote 13: con `role: .cancel` este diálogo (sale como popover) no pintaba la salida.
                Button(L10n.Common.cancel) { settlementToDelete = nil }
            } message: {
                Text(L10n.Groups.Settlement.deleteMessage)
            }
            // Una `.alert` y no un diálogo: pinta siempre las dos salidas (regla de `swiftui-ds.md`).
            // `presenting:` y no el `@State` leído dentro: el cierre se quedaría con el valor de antes (regla de
            // `swiftui-ds.md`, lote 8).
            .alert(L10n.Groups.Settlement.rejectQuestion, isPresented: $showRejectConfirm,
                   presenting: settlementToReject) { settlement in
                Button(L10n.UXL13.pendingRejectConfirm, role: .destructive) {
                    onRejectSettlement?(settlement)
                    settlementToReject = nil
                }
                .accessibilityIdentifier("group_pending_reject_confirm")
                Button(L10n.Common.cancel) { settlementToReject = nil }
                    .accessibilityIdentifier("group_pending_reject_cancel")
            } message: { settlement in
                Text(settlement.toMemberID == currentUserMemberID
                     ? L10n.UXL13.pendingRejectMessage(name(settlement.fromMemberID))
                     : L10n.UXL13.pendingRejectMessageOther)
            }
        }
    }

    // MARK: - L13-2 · Un pago que te toca confirmar

    private func pendingCard(_ settlement: SplitSettlement) -> some View {
        let fromName = name(settlement.fromMemberID)
        let amount = appPreferences.currency(settlement.amount, currencyCode: settlement.currencyCode)
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                avatar(fromName, size: largeAvatarSize)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.UXL13.pendingTitle(name: fromName, amount: amount))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.UXL13.pendingQuestion)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.sm) { pendingButtons(settlement) }
                VStack(spacing: DS.Spacing.sm) { pendingButtons(settlement) }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hotPink.opacity(0.16), in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
    }

    @ViewBuilder
    private func pendingButtons(_ settlement: SplitSettlement) -> some View {
        Button {
            DS.Haptic.success()
            onConfirmSettlement?(settlement)
        } label: {
            Text(L10n.UXL13.pendingYes)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.hotPink, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("group_pending_confirm_yes")

        Button {
            settlementToReject = settlement
            showRejectConfirm = true
        } label: {
            Text(L10n.UXL13.pendingNo)
                .font(DS.Typography.label)
                .foregroundStyle(.thAccent)
                .padding(.horizontal, DS.Spacing.lg)
                .frame(minHeight: 44)
                .background(Capsule().fill(.thAccent.opacity(0.14)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("group_pending_confirm_no")
    }

    // MARK: - L13-1 · Lo tuyo, arriba

    private func summaryCard(_ summary: GroupBalancesPresentationLogic.Summary) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(summaryCaption(summary.kind))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            switch summary.kind {
            case .owedToMe:
                amountsLine(summary.owedToMe, isEstimate: debtsWereConverted)
            case .iOwe:
                amountsLine(summary.iOwe, isEstimate: debtsWereConverted)
            case .settled:
                EmptyView()
            }

            Text(summaryDetail(summary))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.electricIndigo.opacity(0.22),
            in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
        )
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("group_balance_summary")
    }

    private func amountsLine(_ amounts: [GroupBalancesPresentationLogic.CurrencyAmount], isEstimate: Bool) -> some View {
        Text(joined(amounts, isEstimate: isEstimate))
            .font(DS.Typography.title2.weight(.bold))
            .foregroundStyle(.primary)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func summaryCaption(_ kind: GroupBalancesPresentationLogic.Summary.Kind) -> String {
        switch kind {
        case .owedToMe: L10n.UXL13.summaryOwedToMe
        case .iOwe: L10n.UXL13.summaryIOwe
        case .settled: L10n.UXL13.summarySettled
        }
    }

    private func summaryDetail(_ summary: GroupBalancesPresentationLogic.Summary) -> String {
        switch summary.kind {
        case .owedToMe:
            summary.iOwe.isEmpty
                ? L10n.UXL13.summaryOwedToMeDetail
                : L10n.UXL13.summaryAlsoOwe(joined(summary.iOwe, isEstimate: debtsWereConverted))
        case .iOwe: L10n.UXL13.summaryIOweDetail
        case .settled: L10n.UXL13.summarySettledDetail
        }
    }

    // MARK: - L13-1 · Para quedar a mano

    private var debtsSection: some View {
        let cards = GroupBalancesPresentationLogic.debtCards(debts: debts, currentUserMemberID: currentUserMemberID)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.UXL13.settleUpTitle)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: DS.Spacing.md) {
                ForEach(cards) { debtCard($0) }
            }
        }
    }

    private func debtCard(_ card: GroupBalancesPresentationLogic.DebtCard) -> some View {
        let fromName = name(card.fromMemberID)
        let toName = name(card.toMemberID)
        let amounts = card.debts.map { GroupBalancesPresentationLogic.CurrencyAmount(currencyCode: $0.currencyCode, amount: $0.amount) }
        let amountsText = joined(amounts, isEstimate: debtsWereConverted)
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.sm) { pairLabel(card, from: fromName, to: toName) }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) { pairLabel(card, from: fromName, to: toName) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(card.fromMemberID == currentUserMemberID
                ? L10n.UXL13.debtA11yMe(to: toName, amounts: amountsText)
                : L10n.UXL13.debtA11y(from: fromName, to: toName, amounts: amountsText))

            HStack(alignment: .firstTextBaseline) {
                Text(amountsText)
                    .font(DS.Typography.headline)
                    .foregroundStyle(amountColor(card))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
                Spacer(minLength: DS.Spacing.sm)
                if card.involvesMe, onSettleDebt != nil {
                    settleButton(card)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            card.involvesMe ? Color.electricIndigo.opacity(0.16) : Color.clear,
            in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
        )
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        // Sin identificador en la tarjeta: en un contenedor pisa el de su botón «Saldar» (regla de `testing.md`).
    }

    /// «Beto paga a Tú» / «Tú pagas a Ana»: cuando el que paga eres tú, la frase va en segunda persona (con «Tú» +
    /// «paga a» salía «Tú paga a Ana», «You pays to»).
    @ViewBuilder
    private func pairLabel(_ card: GroupBalancesPresentationLogic.DebtCard, from: String, to: String) -> some View {
        let iPay = card.fromMemberID == currentUserMemberID
        HStack(spacing: DS.Spacing.sm) {
            avatar(from, size: avatarSize)
            Text(iPay ? L10n.UXL13.youPayTo : from)
                .font(DS.Typography.subheadlineEmphasized)
                .lineLimit(1)
        }
        HStack(spacing: DS.Spacing.sm) {
            if !iPay {
                Text(L10n.Groups.Settlement.payTo)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            avatar(to, size: avatarSize)
            Text(to)
                .font(DS.Typography.subheadlineEmphasized)
                .lineLimit(1)
        }
    }

    /// Una moneda: un botón. Varias: un menú con un «Saldar» por moneda — cada pago se apunta en su moneda y nunca se
    /// mezclan.
    @ViewBuilder
    private func settleButton(_ card: GroupBalancesPresentationLogic.DebtCard) -> some View {
        if card.debts.count == 1, let debt = card.debts.first {
            Button { onSettleDebt?(debt) } label: { settleLabel }
                .buttonStyle(.plain)
                .accessibilityHint(L10n.Groups.Settlement.settleHint)
                .accessibilityIdentifier("group_debt_settle")
        } else {
            Menu {
                ForEach(card.debts) { debt in
                    Button(appPreferences.currency(debt.amount, currencyCode: debt.currencyCode,
                                                   isEstimate: debtsWereConverted)) {
                        onSettleDebt?(debt)
                    }
                }
            } label: { settleLabel }
                .buttonStyle(.plain)
                .accessibilityHint(L10n.Groups.Settlement.settleHint)
                .accessibilityIdentifier("group_debt_settle")
        }
    }

    private var settleLabel: some View {
        Text(L10n.UXL13.settle)
            .font(DS.Typography.subheadlineEmphasized)
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.lg)
            .frame(minHeight: 36)
            .background(Color.hotPink, in: Capsule())
            .contentShape(Capsule())
    }

    /// Solo se colorea la excepción, y en un tono que vale como texto (`amountTint`, decisión L4-14): lo que te deben, en
    /// el verde oscurecido; lo que debes, en el color del texto. El rosa y el verde de sistema no llegan al contraste.
    private func amountColor(_ card: GroupBalancesPresentationLogic.DebtCard) -> Color {
        guard card.involvesMe else { return .secondary }
        return Color.amountTint(isIncome: card.isOwedToMe)
    }

    // MARK: - Settlements Section

    private func settlementsSection(_ listed: [SplitSettlement]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Balance.settlements)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.none) {
                ForEach(listed, id: \.id) { settlement in
                    settlementRow(settlement)

                    if settlement.id != listed.last?.id {
                        Divider()
                            .padding(.leading, DS.FormRow.paddingH)
                    }
                }
            }
            .solidCard(radius: DS.Radius.xl)
        }
    }

    /// Press SIMPLE sobre una liquidación CONFIRMADA abre su menú de acciones (la sección no es una
    /// `List`, así que swipe-to-delete no existe aquí).
    @ViewBuilder
    private func settlementRow(_ settlement: SplitSettlement) -> some View {
        if !settlement.isConfirmed, onRejectSettlement != nil {
            // Un pendiente que no te toca confirmar a ti (lo apuntaste tú, o es entre otros): antes la ✓/✗ salía en todos;
            // quitarlo se conserva aquí, con la misma pregunta que «No me llegó».
            Menu {
                Button(role: .destructive) {
                    settlementToReject = settlement
                    showRejectConfirm = true
                } label: {
                    Label(L10n.UXL13.pendingRejectConfirm, systemImage: "xmark.circle")
                }
            } label: {
                settlementRowContent(settlement)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("group_settlement_pending_menu_\(settlement.id.uuidString)")
        } else if settlement.isConfirmed, onDeleteSettlement != nil {
            Menu {
                Button(role: .destructive) {
                    settlementToDelete = settlement
                    showDeleteSettlementConfirm = true
                } label: {
                    Label(L10n.Groups.Settlement.deleteAction, systemImage: "trash")
                }
            } label: {
                settlementRowContent(settlement)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("group_settlement_menu_\(settlement.id.uuidString)")
        } else {
            settlementRowContent(settlement)
        }
    }

    private func settlementRowContent(_ settlement: SplitSettlement) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(name(settlement.fromMemberID))
                        .font(DS.Typography.body)

                    Image(systemName: "arrow.right")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)

                    Text(name(settlement.toMemberID))
                        .font(DS.Typography.body)
                }

                HStack(spacing: DS.Spacing.xxs) {
                    Text(statusText(settlement))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(settlement.isConfirmed ? DS.Semantic.successForeground : .secondary)

                    Text("·")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)

                    Text(Self.dateFormatter.string(from: settlement.date))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            AmountText(
                value: settlement.amount,
                currencyCode: settlement.currencyCode,
                font: DS.Typography.headline
            )
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    /// L13-2: un pendiente que queda en la lista espera a otra persona, y lo dice: «Falta que Beto lo confirme».
    private func statusText(_ settlement: SplitSettlement) -> String {
        if settlement.isConfirmed { return L10n.Groups.Balance.confirmed }
        if settlement.toMemberID == currentUserMemberID { return L10n.Groups.Balance.pending }
        return L10n.UXL13.pendingWaitingFor(name(settlement.toMemberID))
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// «Tú» para ti; el nombre del miembro para los demás.
    private func name(_ memberID: String) -> String {
        if let me = currentUserMemberID, memberID == me { return L10n.UXL13.you }
        return memberNameLookup[memberID] ?? "?"
    }

    private func joined(_ amounts: [GroupBalancesPresentationLogic.CurrencyAmount], isEstimate: Bool) -> String {
        amounts
            .map { appPreferences.currency($0.amount, currencyCode: $0.currencyCode, isEstimate: isEstimate) }
            .joined(separator: " + ")
    }

    private func avatar(_ name: String, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: groupColorHex).opacity(0.22))
                .frame(width: size, height: size)
            Text(String(name.prefix(1)).uppercased())
                .font(DS.Typography.label)
                .foregroundStyle(Color(hex: groupColorHex))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Shared Balance Color

extension Color {
    /// Color for net balance: green (owed to), hotPink (owes), secondary (zero).
    static func groupBalance(_ net: Double) -> Color {
        if net > 0.01 { return DS.Semantic.successForeground }
        if net < -0.01 { return .hotPink }
        return .secondary
    }
}
