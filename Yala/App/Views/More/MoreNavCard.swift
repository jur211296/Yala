//
//  MoreNavCard.swift
//  Yala
//
//  Mini-card de navegación del dashboard "Más" (lenguaje visual tipo Oura):
//  icono con glow + título + enunciado corto. Reusa `.panelCard(small:)`.
//

import SwiftUI

struct MoreNavCard: View {
    @Environment(\.yalaTheme) private var theme

    let icon: String
    let title: String
    let subtitle: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(alignment: .top) {
                    AccentIconBadge(systemName: icon)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.chevron)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelCard(small: true)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier(identifier)
        .accessibilityElement(children: .combine)
    }
}

/// Icono con glow sutil sobre fondo accent — badge compartido por las cards del
/// dashboard "Más" (card vertical y card hero de Panel).
struct AccentIconBadge: View {
    @Environment(\.yalaTheme) private var theme
    let systemName: String
    var font: Font = DS.Typography.subheadline

    var body: some View {
        Image(systemName: systemName)
            .font(font)
            .foregroundStyle(theme.accent)
            .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(theme.accent.opacity(0.12))
            )
    }
}
