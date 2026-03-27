//
//  SectionBox.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

// MARK: - Contenedor visual de secciones (Liquid Glass)

struct SectionBox<Content: View>: View {
    @Environment(\.yalaTheme) private var theme
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Typography.headline)
                .foregroundStyle(.thSecondaryText)
                .padding(.leading, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.none) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(.thCardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
        }
    }
}
