//
//  ProfileCardView.swift
//  Yala
//
//  La tarjeta de perfil de «Detalles personales» (2026-11-18): el fondo de las tarjetas de cuentas (degradado, patrón y
//  brillo de `CardBackgroundView`), el avatar grande y el nombre. Es la vista previa en vivo de la personalización: cada
//  toque de abajo se ve aquí. El texto se lee siempre: el contraste lo garantiza `CardLookLogic`.
//

import SwiftUI

struct ProfileCardView<AvatarLabel: View>: View {
    let look: CardLook
    let name: String
    let showsPro: Bool
    /// Cada pantalla le da el suyo: con el mismo, un XCUITest daría por abierta la hoja viendo la cabecera de debajo.
    let identifier: String
    /// El avatar, que en la hoja es además el botón de la foto.
    @ViewBuilder let avatar: () -> AvatarLabel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var foreground: Color { Color(card: look.foreground) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .top) {
                avatar()
                Spacer(minLength: DS.Spacing.md)
                YalaSparkShape()
                    .fill(foreground.opacity(0.55))
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(name)
                    .font(DS.Typography.title2.weight(.bold))
                    .foregroundStyle(foreground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("profile_card_name")
                if showsPro {
                    proBadge
                }
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(CardBackgroundView(look: look, cornerRadius: DS.Radius.xl))
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        .dsAnimation(DS.Animation.selection, value: look, reduceMotion: reduceMotion)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.PerfilPersonalizacion.cardLabel)
        .accessibilityIdentifier(identifier)
    }

    private var proBadge: some View {
        HStack(spacing: DS.Spacing.xs) {
            YalaSparkShape()
                .fill(Color.proGoldInk)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(verbatim: "Yala Pro")
                .font(DS.Typography.labelSmall.weight(.bold))
                .foregroundStyle(Color.proGoldInk)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(Capsule().fill(Color.proGold))
    }
}
