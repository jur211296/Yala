//
//  LimitReachedBanner.swift
//  Yala
//
//  Banner shown when user has reached free tier limit for accounts/budgets.
//

import SwiftUI

struct LimitReachedBanner: View {

    // MARK: - Environment

    @Environment(\.yalaTheme) private var theme

    // MARK: - Properties

    let feature: ProFeature
    let currentCount: Int
    let onUpgrade: () -> Void

    // MARK: - Body

    var body: some View {
        if feature == .budgets, let limit = feature.freeLimit {
            budgetsNeutralBanner(limit: limit)
        } else {
            alertBanner
        }
    }

    /// Presupuestos (UX 2.2 · L9-9): informa sin alarmar. Sin rojo ni estrella con brillo, y la cifra es el límite del
    /// plan, no «6 de 3».
    private func budgetsNeutralBanner(limit: Int) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "info.circle")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(L10n.UXL9.freePlanBanner(limit))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: DS.Spacing.sm)

            Button {
                onUpgrade()
            } label: {
                Text(L10n.UXL9.seePro)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.thAccent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("budgets_free_plan_see_pro")
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
        .accessibilityIdentifier("budgets_free_plan_banner")
    }

    private var alertBanner: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(DS.Typography.title)
                .foregroundStyle(DS.Semantic.warningForeground)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.FeatureGate.limitReachedTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)

                if let limit = feature.freeLimit {
                    Text(L10n.FeatureGate.limitInfo(currentCount, limit))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                }
            }

            Spacer()

            Button {
                onUpgrade()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    YalaSpark(size: .small, animated: false)
                    Text(L10n.FeatureGate.upgrade)
                        .font(DS.Typography.labelSmall)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(theme.accent)
                .clipShape(Capsule())
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Semantic.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.xl) {
        LimitReachedBanner(
            feature: .accounts,
            currentCount: 2
        ) {}

        LimitReachedBanner(
            feature: .budgets,
            currentCount: 3
        ) {}
    }
    .padding()
}
