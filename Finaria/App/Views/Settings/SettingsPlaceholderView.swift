//
//  SettingsPlaceholderView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftUI

// MARK: - Vista placeholder genérica para opciones futuras de Ajustes

struct SettingsPlaceholderView: View {
    let title: String
    let message: String

    init(title: String, message: String = "Próximamente") {
        self.title = title
        self.message = message
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: 16) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.secondary)

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
