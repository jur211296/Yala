//
//  TodayHintGlassPill.swift
//  Yala
//

import SwiftUI

/// Glass pill capsule con ícono info + texto "Hoy". Reemplaza el `Text("Hoy")`
/// plano del `todayMarker` en `TrendChartView`. El ícono `info.circle` +
/// `glassEffect.interactive` comunican affordance: hay información que ver
/// al tap. Abre el sheet educativo "Tu saldo hoy" (multi-currency FX).
struct TodayHintGlassPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: "info.circle")
                    .font(DS.Typography.captionSmall)
                Text(L10n.Widget.today)
                    .font(DS.Typography.labelTiny)
            }
            .foregroundStyle(.thPrimaryText)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .glassEffect(.regular.interactive(), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
