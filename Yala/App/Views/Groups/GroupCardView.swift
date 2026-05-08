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
    /// #26: drives chip pending/rejected en lugar de balance.
    let displayMode: GroupCardDisplayMode
    let action: () -> Void
    /// #26: callback cuando current user está rejected y tap card → padre
    /// muestra alert "¿Salir del grupo?".
    var onRejectedTap: (() -> Void)?

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    init(
        group: SplitGroup,
        memberCount: Int,
        pendingCount: Int,
        balance: MemberBalance?,
        displayMode: GroupCardDisplayMode = .active,
        action: @escaping () -> Void,
        onRejectedTap: (() -> Void)? = nil
    ) {
        self.group = group
        self.memberCount = memberCount
        self.pendingCount = pendingCount
        self.balance = balance
        self.displayMode = displayMode
        self.action = action
        self.onRejectedTap = onRejectedTap
    }

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                groupIcon

                // Name + member count
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(group.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.xs) {
                        Text(L10n.Groups.Member.activeCount(memberCount))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)

                        if pendingCount > 0 {
                            Text("·")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                            Text(L10n.Groups.Member.pendingCount(pendingCount))
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Semantic.warningForeground)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }

                Spacer()

                // #26: trailing area según displayMode.
                trailingArea
            }
            .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
            .dsSubtleShadow()
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(displayMode == .pendingApproval)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var trailingArea: some View {
        switch displayMode {
        case .pendingApproval:
            membershipChip(
                icon: "clock.arrow.circlepath",
                text: L10n.Groups.Card.pendingApprovalChip,
                fg: DS.Semantic.warningForeground,
                bg: DS.Semantic.warningBackground
            )
        case .rejected:
            membershipChip(
                icon: "xmark.circle.fill",
                text: L10n.Groups.Card.rejectedChip,
                fg: DS.Semantic.errorForeground,
                bg: DS.Semantic.errorBackground
            )
        case .active:
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
    }

    private func membershipChip(icon: String, text: String, fg: Color, bg: Color) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.Typography.captionSmall)
            Text(text)
                .font(DS.Typography.captionSmall)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(Capsule().fill(bg))
    }

    private func handleTap() {
        switch displayMode {
        case .pendingApproval:
            // No-op: card disabled via `.disabled(...)`. Defensa-en-profundidad.
            break
        case .rejected:
            onRejectedTap?()
        case .active:
            action()
        }
    }

    private var accessibilityText: String {
        var parts = [group.name, L10n.Groups.Member.activeCount(memberCount)]
        if pendingCount > 0 { parts.append(L10n.Groups.Member.pendingCount(pendingCount)) }
        switch displayMode {
        case .pendingApproval:
            parts.append(L10n.Groups.Card.pendingApprovalChip)
        case .rejected:
            parts.append(L10n.Groups.Card.rejectedChip)
        case .active:
            if let balance {
                let amount = appPreferences.currency(abs(balance.netBalance), currencyCode: balance.currencyCode)
                let label = balanceLabel(balance.netBalance)
                if !label.isEmpty { parts.append("\(amount) \(label)") }
            }
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
