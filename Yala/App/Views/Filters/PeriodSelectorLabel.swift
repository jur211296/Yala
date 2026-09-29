//
//  PeriodSelectorLabel.swift
//  Yala
//
//  Shared period selector label component.
//

import SwiftUI

/// Period selector dropdown label used in control bars.
/// Animation explicitly disabled to prevent clipping issues during period changes.
struct PeriodSelectorLabel: View {
    let title: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "calendar")
                .font(DS.Typography.labelSmall)
                .accessibilityHidden(true)
            Text(title)
                .font(DS.Typography.labelSmall)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .foregroundStyle(.thPrimaryText)
        .glassEffect(.regular.interactive(), in: .capsule)
        // Ensure entire capsule is tappable
        .contentShape(Capsule())
        // CRITICAL: Prevent truncation even if parent animates/constrains width
        // Salvo a tamaños de accesibilidad: ahí «Todo el tiempo» ya no cabe en el ancho de un iPhone SE, y con el
        // ancho fijo la píldora ensanchaba la columna entera del Panel y de Registros, que se salía por los dos
        // bordes (medido el 2026-09-28). Sin ese tope horizontal, el título pasa a dos líneas dentro de la píldora.
        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
        // CRITICAL: Disable animation to prevent clipping during period changes
        .transaction { $0.animation = nil }
    }
}

#Preview {
    VStack(spacing: DS.Spacing.lg) {
        PeriodSelectorLabel(title: "Este mes")
        PeriodSelectorLabel(title: "Últimos 30 días")
    }
    .padding()
    .background(.thCard)
}
