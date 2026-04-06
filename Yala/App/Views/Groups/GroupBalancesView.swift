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

    @Environment(\.yalaTheme) private var theme

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
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
        }
    }

    // MARK: - Balances Section

    private var balancesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Balance.title)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.none) {
                ForEach(balances.indices, id: \.self) { index in
                    balanceRow(balances[index])

                    if index < balances.count - 1 {
                        Divider()
                            .padding(.leading, DS.FormRow.paddingH)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(.thCardBorder, lineWidth: 1)
            )
        }
    }

    private func balanceRow(_ balance: MemberBalance) -> some View {
        HStack {
            Text(balance.displayName)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Spacer()

            Text(YalaFormatter.currency(value: abs(balance.netBalance), currencyCode: balance.currencyCode))
                .font(DS.Typography.headline)
                .foregroundStyle(balanceColor(balance.netBalance))
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Debts Section

    private var debtsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Balance.pendingDebts)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.none) {
                ForEach(debts.indices, id: \.self) { index in
                    debtRow(debts[index])

                    if index < debts.count - 1 {
                        Divider()
                            .padding(.leading, DS.FormRow.paddingH)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(.thCardBorder, lineWidth: 1)
            )
        }
    }

    private func debtRow(_ debt: Debt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(memberNameLookup[debt.fromMemberID] ?? debt.fromMemberID)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.right")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)

                    Text(memberNameLookup[debt.toMemberID] ?? debt.toMemberID)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(YalaFormatter.currency(value: debt.amount, currencyCode: debt.currencyCode))
                .font(DS.Typography.headline)
                .foregroundStyle(Color.hotPink)
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
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(.thCardBorder, lineWidth: 1)
            )
        }
    }

    private func settlementRow(_ settlement: SplitSettlement) -> some View {
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

                Text(settlement.isConfirmed ? L10n.Groups.Balance.confirmed : L10n.Groups.Balance.pending)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(settlement.isConfirmed ? DS.Semantic.successForeground : .secondary)
            }

            Spacer()

            Text(YalaFormatter.currency(value: settlement.amount, currencyCode: settlement.currencyCode))
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Helpers

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
