//
//  TodayHintGlassPill.swift
//  Yala
//

import SwiftUI

/// Capsule glass tappable "Hoy ⓘ" que abre el sheet educativo del saldo al
/// tipo de cambio actual.
///
/// Toda la capsule es la zona tappable (no solo el ícono): asegura que el
/// gesto funcione dentro de annotations de `Chart`, donde `Button` no
/// propaga eventos y los efectos visuales por elemento individual son
/// inestables.
struct TodayHintGlassPill: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Text(L10n.Widget.today)
                .font(DS.Typography.labelTiny)
            Image(systemName: "info.circle")
                .font(DS.Typography.captionSmall)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.thPrimaryText)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .glassEffect(.regular.interactive(), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture(perform: action)
        .accessibilityElement()
        .accessibilityLabel(L10n.Widget.today)
        .accessibilityHint(L10n.Panel.LiveAnchorEducation.dotA11yLabel)
        .accessibilityAddTraits(.isButton)
    }
}
