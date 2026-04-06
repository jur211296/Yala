//
//  GroupCardView.swift
//  Yala
//
//  Card de un grupo en la lista principal — icono, nombre, miembros, balance.
//

import SwiftUI

struct GroupCardView: View {

    let group: SplitGroup
    let memberCount: Int
    let balance: MemberBalance?
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                groupIcon

                // Name + member count
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(group.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(L10n.Groups.Member.people(memberCount))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Net balance
                if let balance {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        Text(YalaFormatter.currency(value: abs(balance.netBalance), currencyCode: balance.currencyCode))
                            .font(DS.Typography.headline)
                            .foregroundStyle(Color.groupBalance(balance.netBalance))

                        Text(balanceLabel(balance.netBalance))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(.thCardBorder, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(theme.shadowOpacity),
                radius: 6, x: 0, y: 3
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Components

    private var groupIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: group.colorHex))
                .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

            Image(systemName: group.iconName)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Helpers

    private func balanceLabel(_ net: Double) -> String {
        if net > 0.01 {
            return L10n.Groups.Balance.isOwed
        } else if net < -0.01 {
            return L10n.Groups.Balance.owes
        }
        return ""
    }
}
