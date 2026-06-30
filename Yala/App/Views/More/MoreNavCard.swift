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
    var badge: String? = nil
    var iconColor: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(alignment: .top) {
                    AccentIconBadge(systemName: icon, tint: iconColor)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.chevron)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(title)
                            .font(DS.Typography.subheadlineEmphasized)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if let badge {
                            Text(badge)
                                .font(DS.Typography.captionSmall)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.essentialNeed)
                                .padding(.horizontal, DS.Spacing.xs)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(Capsule().fill(Color.essentialNeed.opacity(0.15)))
                                .fixedSize()
                        }
                    }

                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // maxHeight: .infinity → todas las cards de una fila igualan la altura
            // de la más alta (enunciados de 1 vs 2 líneas). topLeading mantiene el
            // contenido arriba; el espacio extra queda abajo.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    var tint: Color? = nil

    var body: some View {
        let color = tint ?? theme.accent
        Image(systemName: systemName)
            .font(font)
            .foregroundStyle(color)
            .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(color.opacity(0.12))
            )
    }
}
