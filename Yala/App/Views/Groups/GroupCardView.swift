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
    /// Drives chip pending/rejected en lugar del balance trailing.
    let displayMode: GroupCardDisplayMode
    let action: () -> Void
    /// Disparado cuando current user `.rejected` toca la card. El padre
    /// presenta el alert "¿Salir del grupo?" (un solo modal global).
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
            StatusChip(
                icon: "clock.arrow.circlepath",
                text: L10n.Groups.Card.pendingApprovalChip,
                foregroundColor: DS.Semantic.warningForeground,
                backgroundColor: DS.Semantic.warningBackground
            )
        case .rejected:
            StatusChip(
                icon: "xmark.circle.fill",
                text: L10n.Groups.Card.rejectedChip,
                foregroundColor: DS.Semantic.errorForeground,
                backgroundColor: DS.Semantic.errorBackground
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

    private func handleTap() {
        switch displayMode {
        case .pendingApproval:
            // Defensa-en-profundidad: la card está `.disabled` para pending,
            // pero si el modifier no aplica (ej. fallback de a11y), no abrir detail.
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
        GroupIconBadge(colorHex: group.colorHex, iconName: group.iconName)
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
