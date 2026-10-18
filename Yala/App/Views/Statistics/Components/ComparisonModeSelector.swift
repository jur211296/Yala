//
//  ComparisonModeSelector.swift
//  Yala
//
//  Con qué se comparan las cifras de Estadísticas. Lo usan Resumen (Tus cifras), Tendencias (Comparativa) y
//  Distribución (Análisis del gasto).
//
//  UX 2.2 · L11-4: antes eran dos círculos de 32 pt con «P-1» y «A-1» y, debajo, «vs Set 26». Ahora es una frase que
//  hace de botón —«Comparado con el 1–15 de septiembre ▾»— y abre las dos opciones con su nombre de persona.
//

import SwiftUI
import TipKit

struct ComparisonModeSelector: View {
    /// El período que se mira: decide el tramo de la frase y el nombre de la opción «anterior».
    let period: DetailPeriod
    /// El rango si el período es `.custom`. Estadísticas usa el de la sesión; Informes lleva el suyo.
    let customRange: DateInterval?
    /// El último día con movimientos, en las pestañas que alinean con él (Tendencias, Distribución). `nil`: hoy.
    var dataEnd: Date? = nil

    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    private let comparisonTip = ComparisonTip()

    private var phrase: String? {
        ComparisonPhraseLogic.phrase(
            period: period,
            mode: sessionState.comparisonMode,
            customRange: customRange,
            dataEnd: dataEnd
        )
    }

    var body: some View {
        if let phrase {
            Menu {
                option(.month, title: ComparisonPhraseLogic.previousOptionTitle(for: period))
                option(.year, title: L10n.UXL11.optionPreviousYear)
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(DS.Typography.caption)
                        .accessibilityHidden(true)
                    Text(phrase)
                        .font(DS.Typography.labelSmall.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "chevron.down")
                        .font(DS.Typography.captionSmall.weight(.bold))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .foregroundStyle(theme.accent)
                .background(Capsule().fill(theme.accent.opacity(0.14)))
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(Capsule())
            }
            .accessibilityHint(L10n.UXL11.comparisonHint)
            .accessibilityIdentifier("comparison_mode_selector")
            .popoverTip(comparisonTip)
            // El globo se arma cuando el selector SE VE entero, no al montarse: en Estadísticas › Resumen el selector
            // se monta por debajo del borde, y el globo salía cortado en la esquina, encima de la barra de pestañas, y
            // se iba al primer desplazamiento sin poder leerse (medido el 2026-10-14, iPhone 17 Pro).
            .onScrollVisibilityChange(threshold: 1.0) { isVisible in
                if isVisible { ComparisonTip.hasVisitedStatistics = true }
            }
        }
    }

    private func option(_ mode: ComparisonMode, title: String) -> some View {
        Button {
            dsWithAnimation(reduceMotion) {
                sessionState.comparisonMode = mode
            }
        } label: {
            if sessionState.comparisonMode == mode {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
        .accessibilityIdentifier("comparison_option_\(mode.rawValue)")
    }
}
