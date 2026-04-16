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
            .solidCard()
        }
    }
}
