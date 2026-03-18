//
//  CashFlowCellPopover.swift
//  Yala
//
//  Popover showing plan vs real details when tapping a cell.
//

import SwiftUI

struct CashFlowCellPopover: View {
    let lineResult: CashFlowLineResult
    let month: CashFlowMonth
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Title
            Text("\(lineResult.name) — \(monthLabel)")
                .font(DS.Typography.label)
                .foregroundStyle(.primary)

            Divider()

            // Plan
            detailRow(label: L10n.CashFlowPlan.plan, value: lineResult.plannedAmount)

            // Real (only for past/current)
            if let real = lineResult.realAmount {
                detailRow(label: L10n.CashFlowPlan.real, value: real)

                // Difference
                if let diff = lineResult.difference {
                    HStack {
                        Text(L10n.CashFlowPlan.difference)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: DS.Spacing.xs) {
                            Text(YalaFormatter.currency(value: diff, currencyCode: currencyCode))
                                .font(DS.Typography.amountSmall)
                                .foregroundStyle(differenceColor(diff))
                            if isOnTrack(diff) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(DS.Semantic.successForeground)
                            }
                        }
                    }
                }
            } else {
                // Method label for future months
                HStack {
                    Text(L10n.CashFlowPlan.estimationMethod)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(methodLabel)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 240)
    }

    // MARK: - Helpers

    private func detailRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(YalaFormatter.currency(value: value, currencyCode: currencyCode))
                .font(DS.Typography.amountSmall)
                .monospacedDigit()
        }
    }

    /// For income: diff > 0 means earned more → green. For expense: diff < 0 means spent less → green.
    private func differenceColor(_ diff: Double) -> Color {
        if lineResult.isIncome {
            return diff >= 0 ? DS.Semantic.successForeground : DS.Semantic.errorForeground
        }
        return diff > 0 ? DS.Semantic.errorForeground : DS.Semantic.successForeground
    }

    /// On track: income earned >= plan (diff >= 0), expense spent <= plan (diff <= 0)
    private func isOnTrack(_ diff: Double) -> Bool {
        lineResult.isIncome ? diff >= 0 : diff < 0
    }

    private var monthLabel: String {
        month.date.formatted(.dateTime.month(.abbreviated))
    }

    private var methodLabel: String {
        lineResult.estimationMethod.displayName
    }
}
