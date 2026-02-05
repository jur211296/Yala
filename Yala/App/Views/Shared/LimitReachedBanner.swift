//
//  LimitReachedBanner.swift
//  Yala
//
//  Banner shown when user has reached free tier limit for accounts/budgets.
//

import SwiftUI

struct LimitReachedBanner: View {

    // MARK: - Properties

    let feature: ProFeature
    let currentCount: Int
    let onUpgrade: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.FeatureGate.limitReachedTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.yalaPrimaryText)

                if let limit = feature.freeLimit {
                    Text(L10n.FeatureGate.limitInfo(currentCount, limit))
                        .font(.caption)
                        .foregroundStyle(Color.yalaSecondaryText)
                }
            }

            Spacer()

            Button {
                onUpgrade()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    YalaSpark(size: .small, animated: false)
                    Text(L10n.FeatureGate.upgrade)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(Color.brandPrimary)
                .clipShape(Capsule())
            }
        }
        .padding(DS.Spacing.md)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.xl) {
        LimitReachedBanner(
            feature: .accounts,
            currentCount: 2
        ) {
            print("Upgrade tapped")
        }

        LimitReachedBanner(
            feature: .budgets,
            currentCount: 3
        ) {
            print("Upgrade tapped")
        }
    }
    .padding()
}
