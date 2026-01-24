//
//  PanelBackgroundView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

// MARK: - Fondo general tipo Liquid Glass claro

struct PanelBackgroundView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                Color.yalaBackground
            } else {
                LinearGradient(
                    colors: [
                        Color.financeBackgroundTop,
                        Color.financeBackgroundBottom,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}
