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
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: insight.icon)
                .font(DS.Typography.body)
                .foregroundStyle(accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 0) {
                Text(insight.text)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)

                if let tip = insight.tip {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "lightbulb")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text(tip)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, DS.Spacing.xs)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.lg)
        .yalaCard(padding: 0, radius: DS.Radius.lg, shadow: false)
    }
}
