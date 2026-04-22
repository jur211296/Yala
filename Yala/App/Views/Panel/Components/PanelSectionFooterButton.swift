//
//  PanelSectionFooterButton.swift
//  Yala
//
//  Capsule full-width con tint sutil del accent del theme. Rol: CTA de
//  sección en el Panel ("Ver más en Tendencias / Distribución", "Ver todos",
//  "Ver presupuestos"…). Solid sin glass — contraste intencional con
//  YalaPrimaryButton (glass + fill) para no competir con los KPIs de widgets.
//

import SwiftUI

struct PanelSectionFooterButton: View {
    enum Style { case prominent, subtle }

    @Environment(\.yalaTheme) private var theme
    let title: String
    let hint: String
    var style: Style = .prominent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.label)
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(backgroundFill)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }

    private var backgroundFill: some View {
        switch style {
        case .prominent:
            Capsule().fill(theme.accent.opacity(0.12))
        case .subtle:
            Capsule().fill(Color.clear)
        }
    }
}

#if DEBUG
#Preview("Light") {
    VStack(spacing: 20) {
        PanelSectionFooterButton(
            title: "Ver más en Tendencias",
            hint: "Abre la pantalla de Tendencias",
            action: {}
        )
        PanelSectionFooterButton(
            title: "Ver más en Distribución",
            hint: "Abre la pantalla de Distribución",
            action: {}
        )
        PanelSectionFooterButton(
            title: "Ver todos",
            hint: "Abre la pantalla de Registros",
            style: .subtle,
            action: {}
        )
    }
    .padding()
}

#Preview("Dark") {
    VStack(spacing: 20) {
        PanelSectionFooterButton(
            title: "Ver más en Tendencias",
            hint: "Abre la pantalla de Tendencias",
            action: {}
        )
        PanelSectionFooterButton(
            title: "Ver todos",
            hint: "Abre la pantalla de Registros",
            action: {}
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}
#endif
