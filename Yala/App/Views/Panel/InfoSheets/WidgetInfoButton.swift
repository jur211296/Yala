//
//  WidgetInfoButton.swift
//  Yala
//
//  Disparador de `WidgetInfoSheet` para widgets del Panel. Equivalente al
//  legacy `InfoHintButton` pero abre una sheet pedagógica completa en lugar
//  de un popover compacto.
//
//  Lee `appPreferences.showWidgetHints`: el toggle en Settings controla la
//  visibilidad de ambos botones (este y `InfoHintButton`).
//

import SwiftUI

struct WidgetInfoButton<Preview: View>: View {
    let kind: WidgetInfoKind
    let viewModel: PanelViewModel
    @ViewBuilder let previewContent: (WidgetSize) -> Preview

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.isWidgetPreviewMode) private var isPreviewMode
    @State private var showSheet = false

    var body: some View {
        if appPreferences.showWidgetHints && !isPreviewMode {
            Button {
                DS.Haptic.light()
                showSheet = true
            } label: {
                WidgetHelpCircleLabel()
            }
            .buttonStyle(.plain)
            .widgetHelpCircleAlignment()
            .accessibilityLabel(kind.title)
            .sheet(isPresented: $showSheet) {
                WidgetInfoSheet(
                    kind: kind,
                    viewModel: viewModel,
                    previewContent: previewContent
                )
            }
        }
    }
}
