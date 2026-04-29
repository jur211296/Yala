//
//  InfoHintButton.swift
//  Yala
//
//  Optional info button for widgets that displays a hint tooltip.
//

import SwiftUI

/// A small info button that shows a tooltip overlay with contextual help.
/// Visibility is controlled by the showWidgetHints AppStorage setting.
///
/// Cuando se renderiza dentro del recuadro de preview de `WidgetInfoSheet`
/// (`Environment(\.isWidgetPreviewMode) == true`), el botón se oculta para
/// evitar recursión visual de info-circles anidados.
struct InfoHintButton: View {
    let title: String
    let message: String

    @AppStorage("showWidgetHints") private var showWidgetHints: Bool = true
    @Environment(\.isWidgetPreviewMode) private var isPreviewMode
    @State private var showTooltip = false

    var body: some View {
        if showWidgetHints && !isPreviewMode {
            Button {
                showTooltip.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .popover(isPresented: $showTooltip, arrowEdge: .top) {
                HintPopoverContent(
                    iconName: "info.circle.fill",
                    iconColor: Color.accentColor,
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
}
