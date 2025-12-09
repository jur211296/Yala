//
//  PanelBackgroundView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

// MARK: - Fondo general tipo Liquid Glass claro

struct PanelBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.financeBackgroundTop,
                Color.financeBackgroundBottom,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
