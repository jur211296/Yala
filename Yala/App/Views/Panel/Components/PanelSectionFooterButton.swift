//
//  PanelSectionFooterButton.swift
//  Yala
//
//  P20-11: CTA footer reutilizable para secciones del Panel. Aparece bajo
//  el último widget y redirige a la pantalla correspondiente (Statistics,
//  Budgets, Scheduled Payments, Groups). Reemplaza los chevrones internos
//  de cada widget — ahora la navegación vive a nivel de sección, no widget.
//
//  Estilo: centrado, color primary, icono chevron.right pequeño al final.
//  Tap area full-width (44pt mínimo vertical).
//

import SwiftUI

struct PanelSectionFooterButton: View {
    let title: String
    /// Accessibility hint que describe el destino ("Abre la pantalla de X").
    let hint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.label)
                    .foregroundStyle(Color.primary)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(Color.primary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        PanelSectionFooterButton(
            title: "Ver más en Tendencias",
            hint: "Abre la pantalla de Tendencias",
            action: {}
        )
        Divider()
        PanelSectionFooterButton(
            title: "Ver todos",
            hint: "Abre la pantalla de Registros",
            action: {}
        )
    }
    .padding()
}
#endif
