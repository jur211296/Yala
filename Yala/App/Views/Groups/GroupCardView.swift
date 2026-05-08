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
    let pendingCount: Int
    let balance: MemberBalance?
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

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

                    Text(L10n.Groups.Member.activeCount(memberCount))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)

                    if pendingCount > 0 {
                        Text(L10n.Groups.Member.pendingCount(pendingCount))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(DS.Semantic.warningForeground)
                    }
                }

                Spacer()

                // Net balance
                if let balance {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        Text(appPreferences.currency(abs(balance.netBalance), currencyCode: balance.currencyCode))
                            .font(DS.Typography.headline)
                            .foregroundStyle(Color.groupBalance(balance.netBalance))

                        Text(balanceLabel(balance.netBalance))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
            .dsSubtleShadow()
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [group.name, L10n.Groups.Member.activeCount(memberCount)]
        if pendingCount > 0 { parts.append(L10n.Groups.Member.pendingCount(pendingCount)) }
        if let balance {
            let amount = appPreferences.currency(abs(balance.netBalance), currencyCode: balance.currencyCode)
            let label = balanceLabel(balance.netBalance)
            if !label.isEmpty { parts.append("\(amount) \(label)") }
        }
        return parts.joined(separator: ", ")
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
