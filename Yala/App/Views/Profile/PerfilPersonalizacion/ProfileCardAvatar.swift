//
//  ProfileCardAvatar.swift
//  Yala
//
//  Las piezas que comparten las dos tarjetas de perfil (la cabecera de Ajustes y la de «Detalles personales», decisión
//  de Jürgen del 18-nov: «el perfil se muestra como tarjeta»): el avatar sobre la tarjeta y el color de acento del tema
//  en «#RRGGBB», con el que se tiñe «Tu color».
//

import SwiftUI
import UIKit

/// El avatar encima de la tarjeta: sin color elegido, un círculo translúcido en el color del texto de la tarjeta (el
/// relleno del tema se perdería sobre el degradado), con un aro del mismo color.
struct ProfileCardAvatar: View {
    let appearance: ProfileAvatarAppearance
    let look: CardLook
    var size: CGFloat = 76
    /// En «Detalles personales» el avatar es el botón de la foto y lo dice con una cámara.
    var showsCameraBadge = false

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        let foreground = Color(card: look.foreground)
        ProfileAvatarView(
            appearance: appearance,
            size: size,
            defaultFill: foreground.opacity(0.18),
            defaultForeground: foreground
        )
        .overlay(Circle().strokeBorder(foreground.opacity(0.85), lineWidth: 3))
        .overlay(alignment: .bottomTrailing) {
            if showsCameraBadge {
                Image(systemName: "camera.fill")
                    .font(DS.Typography.captionSmall.weight(.bold))
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    .foregroundStyle(theme.onAccent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(theme.accent))
                    .overlay(Circle().strokeBorder(foreground.opacity(0.85), lineWidth: 2))
                    .offset(x: 2, y: 2)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Circle())
    }
}

enum ProfileCardThemeColor {
    /// El color de acento del tema en «#RRGGBB», resuelto en el modo (claro u oscuro) que se ve.
    static func accentHex(_ accent: Color, colorScheme: ColorScheme) -> String {
        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let color = UIColor(accent).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return ProfileStyleLogic.fallbackAccentHex
        }
        return CardRGB(red: Double(red), green: Double(green), blue: Double(blue)).hex
    }
}
