//
//  UpdateAvailableBanner.swift
//  Yala
//
//  Banner que informa al usuario cuando hay una versión nueva en el App Store.
//

import SwiftUI

struct UpdateAvailableBanner: View {

    // MARK: - Environment

    @Environment(\.yalaTheme) private var theme

    // MARK: - Properties

    let version: String
    let appStoreURL: URL?
    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "arrow.up.circle.fill")
                .font(DS.Typography.title)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.AppUpdate.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)

                Text(L10n.AppUpdate.message(version))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
            }

            Spacer()

            Button {
                if let url = appStoreURL {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(L10n.AppUpdate.updateButton)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(theme.accent)
                    .clipShape(Capsule())
            }

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
        .padding(DS.Spacing.md)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

// MARK: - Preview

#Preview {
    UpdateAvailableBanner(
        version: "1.3.0",
        appStoreURL: URL(string: "https://apps.apple.com/app/id123"),
        onDismiss: {}
    )
    .padding()
}
