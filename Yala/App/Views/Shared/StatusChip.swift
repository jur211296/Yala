//
//  StatusChip.swift
//  Yala
//
//  Pill capsule con icono SF Symbol + texto sobre fondo tinte. Usado para
//  comunicar estados (warning/error/info) en cards y rows compactos.
//

import SwiftUI

struct StatusChip: View {
    let icon: String
    let text: String
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.Typography.captionSmall)
            Text(text)
                .font(DS.Typography.captionSmall)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(Capsule().fill(backgroundColor))
    }
}
