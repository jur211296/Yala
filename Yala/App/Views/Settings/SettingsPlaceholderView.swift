//
//  SettingsPlaceholderView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

// MARK: - Vista placeholder genérica para opciones futuras de Ajustes

struct SettingsPlaceholderView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 44

    let title: String
    let message: String

    init(title: String, message: String = "Próximamente") {
        self.title = title
        self.message = message
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: DS.Spacing.lg) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: heroIconSize, weight: .regular))
                    .foregroundStyle(.secondary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(title)
                    .font(.title3.weight(.semibold))

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
