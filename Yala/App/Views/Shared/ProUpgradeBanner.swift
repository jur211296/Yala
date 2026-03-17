//
//  ProUpgradeBanner.swift
//  Yala
//
//  Periodic banner reminding Free users about Pro features.
//

import SwiftUI

struct ProUpgradeBanner: View {

    // MARK: - Environment

    @Environment(\.yalaTheme) private var theme

    // MARK: - Properties

    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                YalaSpark(size: .medium, animated: false)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.ProBanner.title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thPrimaryText)

                    Text(L10n.ProBanner.subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .padding(DS.Spacing.xs)
                }
                .accessibilityLabel(L10n.Action.close)
            }

            Button {
                onUpgrade()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    YalaSpark(size: .small, animated: false)
                    Text(L10n.FeatureGate.upgradeToPro)
                        .font(DS.Typography.labelSmall)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .background(theme.accent)
                .clipShape(Capsule())
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Semantic.infoBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

// MARK: - L10n Extension

extension L10n {
    enum ProBanner {
        static var title: String {
            NSLocalizedString("proBanner.title", comment: "Pro upgrade banner title")
        }
        static var subtitle: String {
            NSLocalizedString("proBanner.subtitle", comment: "Pro upgrade banner subtitle")
        }
    }
}

// MARK: - Preview

#Preview {
    ProUpgradeBanner(onUpgrade: {}, onDismiss: {})
        .padding()
}
