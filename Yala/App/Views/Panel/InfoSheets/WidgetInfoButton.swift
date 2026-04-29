//
//  WidgetInfoButton.swift
//  Yala
//
//  Disparador de `WidgetInfoSheet` para widgets del Panel. Equivalente al
//  legacy `InfoHintButton` pero abre una sheet pedagógica completa en lugar
//  de un popover compacto.
//
//  Reusa el `@AppStorage("showWidgetHints")` legacy: el toggle en Settings
//  controla la visibilidad de ambos botones.
//

import SwiftUI

struct WidgetInfoButton<Preview: View>: View {
    let kind: WidgetInfoKind
    let viewModel: PanelViewModel
    @ViewBuilder let previewContent: (WidgetSize) -> Preview

    @AppStorage("showWidgetHints") private var showWidgetHints: Bool = true
    @Environment(\.isWidgetPreviewMode) private var isPreviewMode
    @State private var showSheet = false

    var body: some View {
        if showWidgetHints && !isPreviewMode {
            Button {
                showSheet = true
            } label: {
                Image(systemName: "info.circle")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WidgetInfoContent.content(for: kind).title)
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
