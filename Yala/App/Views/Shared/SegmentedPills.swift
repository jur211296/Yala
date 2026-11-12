//
//  SegmentedPills.swift
//  Yala
//
//  Cápsula segmentada con texto sobre contenedor `.thCard`. Closures providers
//  para color/label/a11y permiten callsites theme-dependent (`theme.accent`) y
//  enum-dependent (`type.color`) sin acoplar el enum a SwiftUI environment.
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
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(spacing: DS.Spacing.none) {
            ForEach(options, id: \.self) { option in
                Button {
                    guard option != selection else { return }
                    DS.Haptic.selection()
                    selection = option
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
        .overlay(Capsule().stroke(theme.cardBorder, lineWidth: 1))
        // Implícita: la píldora vive en pestañas (Estadísticas), donde un `withAnimation` no anima y la cápsula
        // saltaba en vez de deslizarse (card pjum). Solo la píldora: lo que cambia debajo con la selección, como siempre.
        .dsAnimation(DS.Animation.selection, value: selection, reduceMotion: reduceMotion)
    }
}
