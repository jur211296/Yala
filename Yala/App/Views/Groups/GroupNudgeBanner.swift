//
//  GroupNudgeBanner.swift
//  Yala
//
//  Contextual nudge banner for converting invited/dormant/sporadic users.
//  Follows ContextualGuideBanner pattern: .yalaCard, DS tokens, transitions.
//

import SwiftUI

struct GroupNudgeBanner: View {

    // MARK: - Properties

    let nudge: NudgeType
    let message: String
    let onAction: () -> Void
    let onDismiss: () -> Void
    var onAutoDismiss: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: nudge.icon)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Semantic.infoForeground)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(nudge.title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thPrimaryText)

                    Text(message)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thSecondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Action.close)
            }

            if nudge.actionType != .dismiss {
                HStack {
                    Spacer()
                    Button {
                        onAction()
                    } label: {
                        Text(nudge.ctaLabel)
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(.white)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(Capsule().fill(.thAccent))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .yalaCard(padding: DS.Spacing.md, radius: DS.Radius.md, shadow: false)
        .transition(reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity.combined(with: .scale(scale: 0.95))
            )
        )
        .task {
            do {
                try await Task.sleep(for: .seconds(10))
                (onAutoDismiss ?? onDismiss)()
            } catch {
                // Task cancelled — view disappeared, noop
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.md) {
        GroupNudgeBanner(
            nudge: .invitedSpendingInsight,
            message: "Llevas 850 en gastos compartidos. ¿Quieres ver en qué más gastas?",
            onAction: {},
            onDismiss: {}
        )
        GroupNudgeBanner(
            nudge: .dormantGroupsAsMain,
            message: "Tienes gastos compartidos pendientes. Revisa cómo van.",
            onAction: {},
            onDismiss: {}
        )
        GroupNudgeBanner(
            nudge: .sporadicImbalance,
            message: "Registraste 5 gastos compartidos pero solo 1 personal esta semana.",
            onAction: {},
            onDismiss: {}
        )
    }
    .padding()
}
