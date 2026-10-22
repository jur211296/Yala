//
//  GroupBalancesView.swift
//  Yala
//
//  Balances por miembro, deudas pendientes y liquidaciones de un grupo.
//

import SwiftUI

struct GroupBalancesView: View {

    let balances: [MemberBalance]
    let debts: [Debt]
    let settlements: [SplitSettlement]
    let memberNameLookup: [String: String]

    /// True si los balances/debts vienen de consolidar multiples monedas a una sola.
    /// Drives `isEstimate` del AmountText (prefix "≈") cuando hubo conversión real.
    var balancesWereConverted: Bool = false
    var debtsWereConverted: Bool = false

    // Callbacks (optional for backwards compatibility)
    var onSettleDebt: ((Debt) -> Void)?
    var onConfirmSettlement: ((SplitSettlement) -> Void)?
    var onRejectSettlement: ((SplitSettlement) -> Void)?
    /// Eliminar una liquidación YA CONFIRMADA. Las pendientes se rechazan (`onRejectSettlement`),
    /// no se eliminan: son dos gestos distintos sobre estados distintos.
    var onDeleteSettlement: ((SplitSettlement) -> Void)?

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    /// Liquidación elegida en el menú de la fila, a la espera del diálogo de confirmación.
    @State private var settlementToDelete: SplitSettlement?
    @State private var showDeleteSettlementConfirm = false

    var body: some View {
        if balances.isEmpty && debts.isEmpty {
            YalaEmptyState(
                icon: "checkmark.circle",
                title: L10n.Groups.Balance.noDebts
            )
        } else {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Member balances
                    if !balances.isEmpty {
                        balancesSection
                    }

                    // Pending debts
                    if !debts.isEmpty {
                        debtsSection
                    }

                    // Settlements
                    if !settlements.isEmpty {
                        settlementsSection
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
                Button(L10n.Common.cancel, role: .cancel) { settlementToDelete = nil }
            } message: {
                Text(L10n.Groups.Settlement.deleteMessage)
            }
        }
    }

    // MARK: - Balances Section

    private var balancesSection: some View {
        let groups = GroupBalanceRowGrouping.groupByMember(balances)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Balance.title)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.none) {
                ForEach(groups) { group in
                    balanceRow(group)

                    if group.id != groups.last?.id {
                        Divider()
                            .padding(.leading, DS.FormRow.paddingH)
                    }
                }
            }
            .solidCard(radius: DS.Radius.xl)
        }
    }

    /// Una fila por miembro; si tiene saldo en varias monedas, los montos van apilados
    /// a la derecha (uno por moneda) en vez de repetir el nombre.
    private func balanceRow(_ group: GroupBalanceRowGrouping.MemberBalanceGroup) -> some View {
        HStack(alignment: .top) {
            Text(group.displayName)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                ForEach(group.amounts, id: \.currencyCode) { entry in
                    AmountText(
                        value: abs(entry.net),
                        currencyCode: entry.currencyCode,
                        font: DS.Typography.headline,
                        tint: .color(balanceColor(entry.net)),
                        isEstimate: balancesWereConverted
                    )
                }
            }
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Debts Section

    private var debtsSection: some View {
        let groups = GroupBalanceRowGrouping.groupByPair(debts)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Balance.pendingDebts)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.none) {
                ForEach(groups) { group in
                    debtRow(group)

                    if group.id != groups.last?.id {
                        Divider()
                            .padding(.leading, DS.FormRow.paddingH)
                    }
                }
            }
            .solidCard(radius: DS.Radius.xl)
        }
    }

    /// Una fila por par `from→to` (encabezado una sola vez); si deben en varias monedas,
    /// cada moneda es una sub-fila con su monto y su propio botón Saldar — la liquidación
    /// sigue siendo independiente por moneda (nunca se mezclan).
    private func debtRow(_ group: GroupBalanceRowGrouping.DebtPairGroup) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Text(memberNameLookup[group.fromMemberID] ?? group.fromMemberID)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Image(systemName: "arrow.right")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)

                Text(memberNameLookup[group.toMemberID] ?? group.toMemberID)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }

            ForEach(group.debts) { debt in
                HStack {
                    AmountText(
                        value: debt.amount,
                        currencyCode: debt.currencyCode,
                        font: DS.Typography.headline,
                        tint: .color(Color.hotPink),
                        isEstimate: debtsWereConverted
                    )

                    Spacer()

                    if onSettleDebt != nil {
                        Button {
                            onSettleDebt?(debt)
                        } label: {
                            Text(L10n.Groups.Settlement.settle)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.thAccent)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(Capsule().fill(.thAccent.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(L10n.Groups.Settlement.settleHint)
                    }
                }
            }
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Settlements Section

    private var settlementsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Balance.settlements)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.none) {
                ForEach(settlements, id: \.id) { settlement in
                    settlementRow(settlement)

                    if settlement.id != settlements.last?.id {
                        Divider()
                            .padding(.leading, DS.FormRow.paddingH)
                    }
                }
            }
            .solidCard(radius: DS.Radius.xl)
        }
    }

    /// Press SIMPLE sobre una liquidación CONFIRMADA abre su menú de acciones (la sección no es una
    /// `List`, así que swipe-to-delete no existe aquí). Las pendientes NO se envuelven: el `Menu` se
    /// tragaría los taps de sus botones de confirmar/rechazar.
    @ViewBuilder
    private func settlementRow(_ settlement: SplitSettlement) -> some View {
        if settlement.isConfirmed, onDeleteSettlement != nil {
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
                    Text(memberNameLookup[settlement.fromMemberID] ?? "?")
                        .font(DS.Typography.body)

                    Image(systemName: "arrow.right")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)

                    Text(memberNameLookup[settlement.toMemberID] ?? "?")
                        .font(DS.Typography.body)
                }

                HStack(spacing: DS.Spacing.xxs) {
                    Text(settlement.isConfirmed ? L10n.Groups.Balance.confirmed : L10n.Groups.Balance.pending)
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

            // Confirm/Reject buttons for pending settlements
            if !settlement.isConfirmed && onConfirmSettlement != nil {
                HStack(spacing: DS.Spacing.xs) {
                    Button {
                        onConfirmSettlement?(settlement)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(DS.Typography.headline)
                            .foregroundStyle(DS.Semantic.successForeground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Groups.Settlement.confirm)

                    Button {
                        onRejectSettlement?(settlement)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(DS.Typography.headline)
                            .foregroundStyle(DS.Semantic.errorForeground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Groups.Settlement.reject)
                }
            }
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private func balanceColor(_ net: Double) -> Color {
        Color.groupBalance(net)
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
