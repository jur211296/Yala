//
//  InfoHintButton.swift
//  Yala
//
//  Optional info button for widgets that displays a hint tooltip.
//

import SwiftUI

/// A small info button that shows a tooltip overlay with contextual help.
/// Visibility is controlled by `appPreferences.showWidgetHints`.
///
/// Cuando se renderiza dentro del recuadro de preview de `WidgetInfoSheet`
/// (`Environment(\.isWidgetPreviewMode) == true`), el botón se oculta para
/// evitar recursión visual de info-circles anidados.
struct InfoHintButton: View {
    let title: String
    let message: String

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.isWidgetPreviewMode) private var isPreviewMode
    @Environment(\.yalaTheme) private var theme
    @State private var showTooltip = false

    var body: some View {
        if appPreferences.showWidgetHints && !isPreviewMode {
            Button {
                DS.Haptic.light()
                showTooltip.toggle()
            } label: {
                WidgetHelpCircleLabel()
            }
            .buttonStyle(.plain)
            .widgetHelpCircleAlignment()
            .accessibilityLabel(title)
            .popover(isPresented: $showTooltip, arrowEdge: .top) {
                HintPopoverContent(
                    iconName: "info.circle.fill",
                    iconColor: theme.accent,
                    title: title,
                    message: message
                )
                .presentationCompactAdaptation(.popover)
            }
        }
    }
}

#Preview {
    HStack {
        Text("Widget Title")
            .font(DS.Typography.headline)

        InfoHintButton(
            title: "Tendencias",
            message: "Muestra la evolucion de tu balance, ingresos o gastos en el periodo seleccionado"
        )

        Spacer()
    }
    .padding()
    .previewAppPreferences()
}
