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
///
/// Sin `action` es solo la etiqueta «Hoy» del marcador: sin «ⓘ» y sin toque. Pasa cuando no hay
/// diferencia por tipo de cambio que explicar (`LiveAnchorEducationLogic`): la hoja diría «tienes
/// dinero en otras monedas» a quien no tiene.
struct TodayHintGlassPill: View {
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            label(showsInfo: true)
                .glassEffect(.regular.interactive(), in: Capsule())
                .contentShape(Capsule())
                .onTapGesture(perform: action)
                .accessibilityElement()
                .accessibilityLabel(L10n.Widget.today)
                .accessibilityHint(L10n.Panel.LiveAnchorEducation.dotA11yLabel)
                .accessibilityAddTraits(.isButton)
        } else {
            label(showsInfo: false)
                .glassEffect(.regular, in: Capsule())
                .accessibilityElement()
                .accessibilityLabel(L10n.Widget.today)
        }
    }

    private func label(showsInfo: Bool) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Text(L10n.Widget.today)
                .font(DS.Typography.labelTiny)
            if showsInfo {
                Image(systemName: "info.circle")
                    .font(DS.Typography.captionSmall)
                    .fontWeight(.semibold)
            }
        }
        .foregroundStyle(.thPrimaryText)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
    }
}
