//
//  GroupIconBadge.swift
//  Yala
//
//  Badge circular con icono SF Symbol blanco sobre fondo coloreado. Usado
//  para representar la identidad visual de un SplitGroup en cards, headers
//  y otros contextos donde se muestra el grupo.
//

import SwiftUI

struct GroupIconBadge: View {
    let colorHex: String
    let iconName: String
    let size: CGFloat
    let iconFont: Font

    init(
        colorHex: String,
        iconName: String,
        size: CGFloat = DS.Icon.badgeLarge,
        iconFont: Font = DS.Typography.label
    ) {
        self.colorHex = colorHex
        self.iconName = iconName
        self.size = size
        self.iconFont = iconFont
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: size, height: size)

            Image(systemName: iconName)
                .font(iconFont)
                .foregroundStyle(.white)
        }
    }
}
