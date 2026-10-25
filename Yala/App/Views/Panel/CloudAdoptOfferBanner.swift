//
//  CloudAdoptOfferBanner.swift
//  Yala
//
//  Card vbf9: el aviso del Panel que propone activar la nube en este dispositivo cuando otro del mismo iCloud ya lo hizo.
//  El molde es `UpdateAvailableBanner` (icono, título y línea, botón en cápsula y cerrar): un aviso más de la cola, sin
//  diseño nuevo. Quién decide si sale, en `CloudAdoptOfferLogic`.
//

import SwiftUI

struct CloudAdoptOfferBanner: View {

    @Environment(\.yalaTheme) private var theme

    let onActivate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "icloud.and.arrow.up.fill")
                .font(DS.Typography.title)
                .foregroundStyle(theme.accentText)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.CloudAdoptOffer.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.CloudAdoptOffer.body)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                onActivate()
            } label: {
                Text(L10n.CloudAdoptOffer.button)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.thOnAccent)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(theme.accent)
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("cloud_adopt_offer_action")

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                    .padding(DS.Spacing.xs)
            }
            .accessibilityLabel(L10n.Action.close)
            .accessibilityIdentifier("cloud_adopt_offer_dismiss")
        }
        .padding(DS.Spacing.md)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

#Preview {
    CloudAdoptOfferBanner(onActivate: {}, onDismiss: {})
        .padding()
}
