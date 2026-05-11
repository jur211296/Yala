//
//  ProfileSectionPreviewCard.swift
//  Yala
//
//  Componente sintético para el carrusel del Step 1 (`exploreSettings`).
//  NO es una extracción literal de ProfileView — es una representación visual
//  (icon + título + caption) de las 5 secciones principales de Ajustes,
//  pensada para verse rápido en un carrusel auto-rotando.
//

import SwiftUI

struct ProfileSectionPreviewCard: View {
    let iconName: String
    let title: String
    let caption: String

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 32, weight: .medium)) // A11Y-DT: icon size estable
                .foregroundStyle(theme.accent)
                .frame(width: 64, height: 64)
                .background(
                    Circle().fill(theme.accent.opacity(0.15))
                )

            VStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(caption)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.md)
        }
        .padding(.vertical, DS.Spacing.xxl)
        .padding(.horizontal, DS.Spacing.xl)
        .frame(maxWidth: 320)
        .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
    }
}
