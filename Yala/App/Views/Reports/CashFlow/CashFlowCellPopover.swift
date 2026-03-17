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
    let onAdjust: () -> Void

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
                            if diff < 0 {
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

            Divider()

            // Adjust button
            Button(action: onAdjust) {
                Text(L10n.CashFlowPlan.adjustAmount)
                    .font(DS.Typography.label)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
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

    private func differenceColor(_ diff: Double) -> Color {
        diff > 0 ? DS.Semantic.errorForeground : DS.Semantic.successForeground
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month.date)
    }

    private var methodLabel: String {
        switch lineResult.estimationMethod {
        case "average3m": return L10n.CashFlowPlan.average3m
        case "average6m": return L10n.CashFlowPlan.average6m
        case "average12m": return L10n.CashFlowPlan.average12m
        case "lastMonth": return L10n.CashFlowPlan.lastMonth
        case "manual": return L10n.CashFlowPlan.manual
        case "scheduled": return L10n.CashFlowPlan.scheduled
        case "trend": return L10n.CashFlowPlan.trend
        case "custom": return L10n.CashFlowPlan.custom
        default: return lineResult.estimationMethod
        }
    }
}
