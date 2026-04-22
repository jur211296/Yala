//
//  SankeyLabelModeToggle.swift
//  Yala
//
//  Two-segment glass pill for switching Sankey labels between currency amount
//  and percentage. Reuses the P-1/A-1 pattern (Circle + matchedGeometryEffect).
//

import SwiftUI

struct SankeyLabelModeToggle: View {

    @Binding var mode: SankeyLabelMode
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            button(for: .amount, systemImage: "dollarsign", accessibilityLabel: L10n.Statistics.Sankey.toggleAmount)
            button(for: .percentage, systemImage: "percent", accessibilityLabel: L10n.Statistics.Sankey.togglePercentage)
        }
    }

    private func button(
        for target: SankeyLabelMode,
        systemImage: String,
        accessibilityLabel: String
    ) -> some View {
        let isSelected = mode == target

        return Button {
            dsWithAnimation(reduceMotion) {
                mode = target
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : theme.secondaryText)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .matchedGeometryEffect(id: "sankeyToggle", in: pillNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
