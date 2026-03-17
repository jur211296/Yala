//
//  CashFlowCellView.swift
//  Yala
//
//  Individual cell in the cash flow table showing planned/real amounts.
//

import SwiftUI

struct CashFlowCellView: View {
    let lineResult: CashFlowLineResult
    let month: CashFlowMonth
    let currencyCode: String
    let width: CGFloat
    let height: CGFloat

    @State private var showPopover = false

    var body: some View {
        VStack(spacing: 2) {
            amountText
            if month.isCurrent, let progress = lineResult.progress {
                progressBar(progress: progress)
            }
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .onTapGesture { showPopover = true }
        .popover(isPresented: $showPopover) {
            CashFlowCellPopover(
                lineResult: lineResult,
                month: month,
                currencyCode: currencyCode,
                onAdjust: {
                    showPopover = false
                    // Override handled via config sheet
                }
            )
        }
    }

    // MARK: - Amount

    private var displayAmount: Double {
        if let real = lineResult.realAmount, (month.isPast || month.isCurrent) {
            return real
        }
        return lineResult.plannedAmount
    }

    private var amountText: some View {
        Text(formattedCompact(displayAmount))
            .font(DS.Typography.amountSmall)
            .foregroundStyle(amountColor)
            .fontWeight(lineResult.isOverride ? .bold : .regular)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var amountColor: Color {
        if lineResult.isOverride {
            return .primary
        }
        if month.isPast, let diff = lineResult.difference {
            if abs(diff) > lineResult.plannedAmount * 0.1 {
                return diff > 0 ? DS.Semantic.errorForeground : DS.Semantic.successForeground
            }
        }
        return .secondary
    }

    // MARK: - Progress Bar

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            let barWidth = min(geo.size.width - 8, geo.size.width * min(1.0, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 3)
                Capsule()
                    .fill(progressColor(progress))
                    .frame(width: max(3, barWidth), height: 3)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, DS.Spacing.xs)
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress > 1.0 { return DS.Semantic.errorForeground }
        if progress > 0.8 { return DS.Semantic.warningForeground }
        return DS.Semantic.successForeground
    }

    // MARK: - Formatting

    private func formattedCompact(_ value: Double) -> String {
        if abs(value) >= 10000 {
            let k = value / 1000
            return String(format: "%.1fk", k)
        }
        return YalaFormatter.currency(value: value, currencyCode: currencyCode)
    }
}
