//
//  ProjectedFlowViews.swift
//  Yala
//
//  Las dos piezas de «Ver proyectado» que comparten Tendencias y el Panel (card «Flujo proyectado en Tendencias y
//  Panel», respuesta 9A): la píldora de la tarjeta y la línea con la cifra al cierre y su fuente.
//

import SwiftUI

/// «Ver proyectado»: la píldora de la tarjeta de tendencia. Misma forma que «Ver el mes anterior», con la que es
/// excluyente (respuesta 8A): eso lo resuelve quien la monta.
struct ProjectedFlowToggle: View {
    let isOn: Bool
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: isOn ? "checkmark" : "chart.line.uptrend.xyaxis")
                    .font(DS.Typography.caption)
                    .accessibilityHidden(true)
                Text(L10n.ProjectedFlow.toggle)
                    .font(DS.Typography.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .foregroundStyle(isOn ? theme.onAccent : theme.accentText)
            .background(
                Capsule().fill(isOn ? theme.accent : theme.accent.opacity(0.12))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("trend_projected_toggle")
    }
}

/// Bajo la gráfica: «Proyectado al cierre  S/ 3.200» y de dónde sale la estimación. La cifra se oculta con «Ocultar
/// montos» (lo hace `AmountText`), y lleva «≈» si alguna tasa fue aproximada (respuesta 11A).
struct ProjectedFlowCaption: View {
    let projection: ProjectedFlowCalculator.Projection
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(L10n.ProjectedFlow.closing)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                AmountText(
                    value: projection.closingValue,
                    currencyCode: currencyCode,
                    font: DS.Typography.subheadlineEmphasized,
                    isEstimate: projection.isApproximate
                )
            }
            Text(L10n.ProjectedFlow.source(projection.source))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.thSecondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trend_projected_caption")
    }
}

/// Las dos píldoras de la tarjeta en una fila; con texto grande, una debajo de otra.
struct TrendTogglesRow<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.sm) {
                leading
                trailing
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                leading
                trailing
            }
        }
    }
}
