//
//  TodayHintGlassPill.swift
//  Yala
//

import SwiftUI

/// Etiqueta "Hoy" + glass circle `info.circle` tappable. Abre el sheet
/// educativo del saldo al tipo de cambio actual.
///
/// Usa `.onTapGesture` en lugar de `Button` porque los gestos de `Button`
/// no propagan dentro de annotations de `Chart`.
struct TodayHintGlassPill: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(L10n.Widget.today)
                .font(DS.Typography.labelTiny)
                .foregroundStyle(.thPrimaryText)

            WidgetHelpCircleLabel(systemName: "info.circle")
                .contentShape(Circle())
                .onTapGesture(perform: action)
                .accessibilityElement()
                .accessibilityLabel(L10n.Widget.today)
                .accessibilityHint(L10n.Panel.LiveAnchorEducation.dotA11yLabel)
                .accessibilityAddTraits(.isButton)
        }
    }
}
