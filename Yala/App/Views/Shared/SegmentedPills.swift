//
//  SegmentedPills.swift
//  Yala
//
//  Componente shared `GenericSegmentedPill` para cápsulas con texto sobre
//  contenedor `.thCard` (TransactionType, contentMode de Stats
//  Insights/Distribución). Usa closures providers para color/label/a11y,
//  permitiendo callsites theme-dependent sin acoplar el enum a SwiftUI
//  environment.
//
//  Family B (Circle + Icon) — metricSelector, cashFlowSelector,
//  listViewSelector, Sankey — queda como deuda documentada: cada callsite
//  tiene particularidades (drift de font Sankey 14pt vs 12pt; unselected
//  foreground theme.secondaryText vs color enum; disabled/locked logic;
//  setter side-effects; popover externo) que requerirían múltiples closures
//  diluyendo la abstracción. La unificación no rinde sin acomodar todos
//  estos casos.
//

import SwiftUI

struct GenericSegmentedPill<S: Hashable>: View {
    let options: [S]
    @Binding var selection: S
    let labelProvider: (S) -> String
    let selectedFillColorProvider: (S) -> Color
    var a11yLabelProvider: ((S) -> String)? = nil

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DS.Spacing.none) {
            ForEach(options, id: \.self) { option in
                Button {
                    dsWithAnimation(reduceMotion) {
                        selection = option
                    }
                } label: {
                    Text(labelProvider(option))
                        .font(DS.Typography.label.weight(option == selection ? .semibold : .medium))
                        .foregroundStyle(option == selection ? Color.white : Color.primary)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Chip.paddingV)
                        .frame(maxWidth: .infinity)
                        .background {
                            if option == selection {
                                Capsule()
                                    .fill(selectedFillColorProvider(option))
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(a11yLabelProvider?(option) ?? labelProvider(option))
                .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
        }
        .padding(DS.Spacing.xs)
        .background(Capsule().fill(.thCard))
        .overlay(Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }
}
