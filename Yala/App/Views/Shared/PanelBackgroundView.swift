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
    var ignoredEdges: Edge.Set = .all

    var body: some View {
        Group {
            if theme.usesMaterial {
                LinearGradient(
                    colors: DS.Gradients.themeHero(for: theme),
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else if theme.hasGradient {
                // Arriba, el fondo del tema (el gris claro neutro desde el 19-nov-2026, para que las tarjetas blancas
                // se despeguen); abajo, el tinte índigo de siempre.
                LinearGradient(
                    colors: [
                        theme.background,
                        Color.financeBackgroundBottom,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                theme.background
            }
        }
        .ignoresSafeArea(edges: ignoredEdges)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("LiquidGlass + 3 translucent backgrounds") {
    HStack(spacing: 0) {
        ForEach(
            [
                ("liquidGlass", YalaTheme.liquidGlass),
                ("translucent", YalaTheme.translucent),
                ("rosa", YalaTheme.translucentRosa),
                ("teal", YalaTheme.translucentTeal),
            ],
            id: \.0
        ) { name, theme in
            ZStack {
                PanelBackgroundView()
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
            .environment(\.yalaTheme, theme)
        }
    }
    .ignoresSafeArea()
}
#endif
