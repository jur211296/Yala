//
//  ComparisonModeSelector.swift
//  Yala
//
//  Con qué se comparan las cifras de Estadísticas. Lo usan Resumen (Tus cifras), Tendencias (Comparativa) y
//  Distribución (Análisis del gasto).
//
//  UX 2.2 · L11-4: antes eran dos círculos de 32 pt con «P-1» y «A-1» y, debajo, «vs Set 26». Pasó a ser una frase que
//  hacía de botón —«Comparado con el 1–15 de septiembre ▾»— y abría las dos opciones en un menú.
//
//  2026-10-23 (Jürgen, card gvvl): Estadísticas elige con el MISMO control que la Comparativa de Reportes (L18-3,
//  opción D, variante 3): la frase «Comparado con…» queda como título y debajo van los dos chips
//  («Con el mes anterior» / «Con octubre de 2025»), `ComparisonModeChips`.
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
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(phrase)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("comparison_phrase")

                ComparisonModeChips(
                    previousTitle: ComparativeLabelsLogic.previousChipTitle(for: period),
                    yearAgoTitle: L10n.UXL18.chipYearAgo(
                        ComparativeLabelsLogic.yearAgoChipName(period: period, customRange: customRange)
                    ),
                    identifierPrefix: "comparison_chip"
                )
                .popoverTip(comparisonTip)
                // El globo se arma cuando los chips SE VEN enteros, no al montarse: en Estadísticas › Resumen se montan
                // por debajo del borde, y el globo salía cortado en la esquina, encima de la barra de pestañas, y se
                // iba al primer desplazamiento sin poder leerse (medido el 2026-10-14, iPhone 17 Pro).
                .onScrollVisibilityChange(threshold: 1.0) { isVisible in
                    if isVisible { ComparisonTip.hasVisitedStatistics = true }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
