//
//  InsightCard.swift
//  Yala
//
//  Card with icon + text + sentiment color accent for rule-based/AI insights.
//

import SwiftUI

struct InsightCard: View {
    let insight: InsightResult

    @Environment(\.yalaTheme) private var theme

    private var accentColor: Color {
        switch insight.sentiment {
        case .positive: return DS.Semantic.successForeground
        case .neutral: return .primary
        case .attention: return DS.Semantic.warningForeground
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Main row: icon + text
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: insight.icon)
                    .font(DS.Typography.body)
                    .foregroundStyle(accentColor)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                Text(insight.text)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }

            // Tip row: lightbulb aligned with main icon
            if let tip = insight.tip {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    Image(systemName: "lightbulb")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    Text(tip)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .yalaCard(padding: 0, radius: DS.Radius.lg, shadow: false)
    }
}
