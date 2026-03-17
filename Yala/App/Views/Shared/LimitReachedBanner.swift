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
        .onAppear {
            TelemetryService.trackOnce(.proUpsellShown, key: "limitBanner_\(feature.rawValue)", parameters: TelemetryService.upsellParameters(source: "limitBanner"))
        }
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
