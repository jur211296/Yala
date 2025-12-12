//
//  SectionBox.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

// MARK: - Contenedor visual de secciones (Liquid Glass)

struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.netoSecondaryText)
                .padding(.leading, DesignSystem.Spacing.standard)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous)
                    .fill(Color.netoCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
    }
}
