//
//  PanelSmallWidgetHeader.swift
//  Yala
//
//  Header estándar para widgets del Panel en tamaño `.small` (PP2-05+).
//  Título subheadlineEmphasized + chevron de navegación opcional.
//  El chevron es el único elemento interactivo por defecto del header;
//  dispara `action` (típicamente navegación a la pestaña Estadísticas).
//

import SwiftUI

struct PanelSmallWidgetHeader: View {
    let title: String
    let accessibilityLabel: String
    let action: (() -> Void)?
    /// Botón pedagógico opcional renderizado entre el título y el chevron.
    /// Lo inyecta el wrapper Panel cuando el widget está dentro de la
    /// jerarquía del Panel (acceso a `WidgetInfoButton`).
    var headerInfoButton: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.primary)
                .lineLimit(1)

            if let headerInfoButton {
                headerInfoButton
            }

            Spacer(minLength: 0)

            if let action {
                Button {
                    DS.Haptic.light()
                    action()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
            }
        }
    }
}
