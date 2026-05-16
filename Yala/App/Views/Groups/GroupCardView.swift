//
//  GroupCardView.swift
//  Yala
//
//  Card de un grupo en la lista principal — icono, nombre, miembros, deudas perspectiva.
//
//  M6 D3: trailing area muestra hasta 3 rows estilo Splitwise (deudas simplificadas que
//  involucran al current user). Si hay más de 3, chip "+N más" → CTA al GroupDetailView.
//

import SwiftUI

struct GroupCardView: View {

    let group: SplitGroup
    let memberCount: Int
    let pendingCount: Int
    /// M6 D3: deudas simplificadas perspectiva del current user (max display 3 + chip overflow).
    let debts: [GroupsViewModel.DebtRow]
    /// Drives chip pending/rejected en lugar del balance trailing.
    let displayMode: GroupCardDisplayMode
    let action: () -> Void
    /// Disparado cuando current user `.rejected` toca la card. El padre
    /// presenta el alert "¿Salir del grupo?" (un solo modal global).
    var onRejectedTap: (() -> Void)?

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    /// Max rows visibles en el trailing antes de truncate con "+N más".
    private static let maxVisibleDebts = 3

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

    /// M6 D3: layout estilo Splitwise — hasta 3 rows + chip "+N más" si overflow.
    @ViewBuilder
    private var debtsTrailing: some View {
        if debts.isEmpty {
            EmptyView()
        } else {
            let visibleDebts = Array(debts.prefix(Self.maxVisibleDebts))
            let extraCount = max(0, debts.count - Self.maxVisibleDebts)
            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                ForEach(visibleDebts) { row in
                    debtRowView(row)
                }
                if extraCount > 0 {
                    Text(L10n.Groups.Card.moreDebts(extraCount))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func debtRowView(_ row: GroupsViewModel.DebtRow) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(perspectiveCopy(for: row))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            AmountText(
                value: row.amount,
                currencyCode: row.currencyCode,
                size: .body,
                tint: .color(amountColor(for: row.perspective))
            )
        }
    }

    private func perspectiveCopy(for row: GroupsViewModel.DebtRow) -> String {
        switch row.perspective {
        case .iOwe:
            // "Le debes a {name}"
            return L10n.Groups.Balance.owes + " " + row.counterpartyName
        case .theyOweMe:
            // "{name} te debe"
            return row.counterpartyName + " " + L10n.Groups.Balance.isOwed
        }
    }

    private func amountColor(for perspective: GroupsViewModel.Perspective) -> Color {
        switch perspective {
        case .iOwe: return DS.Semantic.errorForeground
        case .theyOweMe: return DS.Semantic.successForeground
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
            for row in debts.prefix(Self.maxVisibleDebts) {
                let amount = appPreferences.currency(row.amount, currencyCode: row.currencyCode)
                parts.append("\(perspectiveCopy(for: row)) \(amount)")
            }
            let extra = max(0, debts.count - Self.maxVisibleDebts)
            if extra > 0 { parts.append(L10n.Groups.Card.moreDebts(extra)) }
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Components

    private var groupIcon: some View {
        GroupIconBadge(colorHex: group.colorHex, iconName: group.iconName)
    }
}
