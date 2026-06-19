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
    /// `nil` cuando se monta fuera del Panel (TrendsTabView / CategoriesTabView):
    /// el sheet oculta el segmento de tamaño, la preview y el botón Save —
    /// muestra solo chips + Q&A. En el Panel se pasa el VM para habilitar el
    /// flujo completo de cambiar tamaño del widget.
    var viewModel: PanelViewModel? = nil
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

extension WidgetInfoButton where Preview == EmptyView {
    /// Atajo para callsites fuera del Panel (sin VM, sin preview): el sheet
    /// renderiza solo chips + Q&A. Evita repetir `{ _ in EmptyView() }`.
    init(kind: WidgetInfoKind) {
        self.init(kind: kind, viewModel: nil, previewContent: { _ in EmptyView() })
    }
}
