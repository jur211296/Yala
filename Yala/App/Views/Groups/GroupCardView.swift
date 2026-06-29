//
//  GroupCardView.swift
//  Yala
//
//  Card de un grupo en la lista principal — icono, nombre, miembros, deudas perspectiva.
//
//  Trailing: deudas del current user agrupadas por sentido — "Te deben: S/47.50 + $5.30 +1 más"
//  (verde) y "Debes: S/1.00" (hot pink). Suma por moneda, hasta 2 monedas + overflow por sentido.
//

import SwiftUI

struct GroupCardView: View {

    let group: SplitGroup
    let memberCount: Int
    let pendingCount: Int
    /// Deudas simplificadas perspectiva del current user (se agrupan por sentido en el trailing).
    let debts: [GroupsViewModel.DebtRow]
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
        debts: [GroupsViewModel.DebtRow],
        displayMode: GroupCardDisplayMode = .active,
        action: @escaping () -> Void,
        onRejectedTap: (() -> Void)? = nil
    ) {
        self.group = group
        self.memberCount = memberCount
        self.pendingCount = pendingCount
        self.debts = debts
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
            debtsTrailing
        }
    }

    /// Deudas agrupadas por sentido (te deben / debes), montos sumados por moneda.
    @ViewBuilder
    private var debtsTrailing: some View {
        let grouped = GroupsViewModel.groupDebtsByDirection(debts)
        if grouped.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                if !grouped.owedToMe.isEmpty {
                    directionBlock(
                        label: L10n.Groups.Summary.owedToMe,
                        amounts: grouped.owedToMe,
                        overflow: grouped.owedToMeOverflow,
                        color: DS.Semantic.successForeground
                    )
                }
                if !grouped.iOwe.isEmpty {
                    directionBlock(
                        label: L10n.Groups.Summary.iOwe,
                        amounts: grouped.iOwe,
                        overflow: grouped.iOweOverflow,
                        color: Color.hotPink
                    )
                }
            }
        }
    }

    private func directionBlock(
        label: String,
        amounts: [GroupsViewModel.GroupedDebtAmount],
        overflow: Int,
        color: Color
    ) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(label):")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
            Text(attributedAmounts(amounts, overflow: overflow, color: color))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// Montos por moneda con jerarquía symbol/decimal (entero grande, símbolo y decimales
    /// pequeños y tenues) igual que la banda; unidos con " + " y "+N más" si hay overflow.
    private func attributedAmounts(
        _ amounts: [GroupsViewModel.GroupedDebtAmount],
        overflow: Int,
        color: Color
    ) -> AttributedString {
        let integerFont = Font.subheadline.weight(.semibold)
        let secondaryFont = Font.caption
        var result = AttributedString()
        for (index, item) in amounts.enumerated() {
            if index > 0 {
                var plus = AttributedString(" + ")
                plus.font = integerFont
                plus.foregroundColor = color
                result.append(plus)
            }
            result.append(AmountText.attributedAmount(
                value: item.amount,
                currencyCode: item.currencyCode,
                prefs: appPreferences,
                integerFont: integerFont,
                secondaryFont: secondaryFont,
                tintColor: color,
                forceFullPrecision: true
            ))
        }
        if overflow > 0 {
            var more = AttributedString(" \(L10n.Groups.Card.moreDebts(overflow))")
            more.font = secondaryFont
            more.foregroundColor = color.opacity(0.7)
            result.append(more)
        }
        return result
    }

    /// Texto plano de los montos para accesibilidad (VoiceOver lee el monto completo).
    private func amountsText(_ amounts: [GroupsViewModel.GroupedDebtAmount], overflow: Int) -> String {
        let joined = amounts
            .map { appPreferences.currency($0.amount, currencyCode: $0.currencyCode) }
            .joined(separator: " + ")
        guard overflow > 0 else { return joined }
        return "\(joined) \(L10n.Groups.Card.moreDebts(overflow))"
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
            let grouped = GroupsViewModel.groupDebtsByDirection(debts)
            if !grouped.owedToMe.isEmpty {
                parts.append("\(L10n.Groups.Summary.owedToMe): \(amountsText(grouped.owedToMe, overflow: grouped.owedToMeOverflow))")
            }
            if !grouped.iOwe.isEmpty {
                parts.append("\(L10n.Groups.Summary.iOwe): \(amountsText(grouped.iOwe, overflow: grouped.iOweOverflow))")
            }
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Components

    private var groupIcon: some View {
        GroupIconBadge(colorHex: group.colorHex, iconName: group.iconName)
    }
}
