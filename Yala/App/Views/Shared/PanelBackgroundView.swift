//
//  PanelBackgroundView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

// MARK: - Fondo general tipo Liquid Glass claro

struct PanelBackgroundView: View {
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Group {
            if theme.hasGradient {
                LinearGradient(
                    colors: [
                        Color.financeBackgroundTop,
                        Color.financeBackgroundBottom,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                theme.background
            }
        }
        .ignoresSafeArea()
    }
}
