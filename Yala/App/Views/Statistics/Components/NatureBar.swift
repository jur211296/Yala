//
//  NatureBar.swift
//  Yala
//
//  Stacked horizontal bar showing essential/priority/optional percentages.
//

import SwiftUI

struct NatureBar: View {
    let distribution: NatureDistribution

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if distribution.essentialPercent > 0 {
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(Color.teal)
                            .frame(width: geo.size.width * distribution.essentialPercent / 100)
                    }
                    if distribution.priorityPercent > 0 {
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(Color.orange)
                            .frame(width: geo.size.width * distribution.priorityPercent / 100)
                    }
                    if distribution.optionalPercent > 0 {
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(Color.purple)
                            .frame(width: geo.size.width * distribution.optionalPercent / 100)
                    }
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))

            // Legend
            HStack(spacing: DS.Spacing.lg) {
                legendItem(color: .teal, label: L10n.Nature.essential, percent: distribution.essentialPercent)
                legendItem(color: .orange, label: L10n.Nature.priority, percent: distribution.priorityPercent)
                legendItem(color: .purple, label: L10n.Nature.optional, percent: distribution.optionalPercent)
            }
        }
    }

    private func legendItem(color: Color, label: String, percent: Double) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label) \(Int(percent))%")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }
}
