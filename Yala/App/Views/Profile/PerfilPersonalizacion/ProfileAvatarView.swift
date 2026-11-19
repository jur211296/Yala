//
//  ProfileAvatarView.swift
//  Yala
//
//  El avatar de perfil, el mismo en las tres superficies: el botón de la barra, la cabecera de Ajustes y la tarjeta de
//  «Detalles personales». Foto si la hay; si no, símbolo, emoji o iniciales sobre el color elegido. Sin color elegido, el
//  relleno y el tinte que cada superficie pintaba antes: quien no personalizó nada ve exactamente lo de siempre.
//

import SwiftUI
import UIKit

/// Lo que el avatar necesita, ya leído de las preferencias (o del borrador de la hoja).
struct ProfileAvatarAppearance: Equatable {
    var photo: UIImage?
    var content: ProfileAvatarContent
    /// `nil` = el relleno de siempre de cada superficie.
    var colorHex: String?

    /// Lo guardado: foto local, `userProfileIcon` y `userProfileStyle`.
    @MainActor
    static func stored(_ preferences: AppPreferences, photo: UIImage?) -> ProfileAvatarAppearance {
        let style = ProfileStyleLogic.decode(preferences.userProfileStyle)
        return ProfileAvatarAppearance(
            photo: photo,
            content: ProfileStyleLogic.content(
                style: style, symbol: preferences.userProfileIcon, name: preferences.userName,
                defaultName: L10n.Profile.defaultName),
            colorHex: style.avatarColorHex
        )
    }
}

struct ProfileAvatarView: View {
    let appearance: ProfileAvatarAppearance
    let size: CGFloat
    /// Relleno y tinte cuando no hay color elegido (los de siempre de la superficie).
    let defaultFill: Color
    let defaultForeground: Color
    /// La letra del símbolo en esa superficie (la de siempre). `nil` = proporcional al círculo.
    var symbolFont: Font?

    var body: some View {
        ZStack {
            if let photo = appearance.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .fill(fill)
                    .frame(width: size, height: size)
                glyph
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var fill: Color {
        guard let hex = appearance.colorHex, let rgb = CardRGB(hex: hex) else { return defaultFill }
        return Color(card: rgb)
    }

    private var foreground: Color {
        guard let hex = appearance.colorHex else { return defaultForeground }
        return Color(card: ProfileStyleLogic.foreground(onFill: hex))
    }

    @ViewBuilder
    private var glyph: some View {
        switch appearance.content {
        case .symbol(let name):
            Image(systemName: name)
                .font(symbolFont ?? .system(size: size * 0.44, weight: .semibold)) // A11Y-DT: el glifo va con su círculo.
                .foregroundStyle(foreground)
        case .emoji(let emoji):
            Text(verbatim: emoji)
                .font(.system(size: size * 0.56)) // A11Y-DT: el emoji llena su círculo, que tiene tamaño fijo.
        case .initials(let letters):
            Text(verbatim: letters)
                .font(.system(size: size * (letters.count > 1 ? 0.38 : 0.46), weight: .bold, design: .rounded)) // A11Y-DT: ídem.
                .foregroundStyle(foreground)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }
}
