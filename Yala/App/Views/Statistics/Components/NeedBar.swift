//
//  NeedBar.swift
//  Yala
//
//  Stacked horizontal bar showing essential/priority/optional percentages.
//

import SwiftUI

struct NeedBar: View {
    let distribution: NeedDistribution

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if distribution.essentialPercent > 0 {
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(Color.essentialNeed)
                            .frame(width: geo.size.width * distribution.essentialPercent / 100)
                    }
                    if distribution.priorityPercent > 0 {
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(Color.priorityNeedNew)
                            .frame(width: geo.size.width * distribution.priorityPercent / 100)
                    }
                    if distribution.optionalPercent > 0 {
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(Color.optionalNeed)
                            .frame(width: geo.size.width * distribution.optionalPercent / 100)
                    }
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))

            // Legend
            HStack(spacing: DS.Spacing.lg) {
                legendItem(color: .essentialNeed, label: L10n.Need.essential, percent: distribution.essentialPercent)
                legendItem(color: .priorityNeedNew, label: L10n.Need.priority, percent: distribution.priorityPercent)
                legendItem(color: .optionalNeed, label: L10n.Need.optional, percent: distribution.optionalPercent)
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
