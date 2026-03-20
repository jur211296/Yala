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

    @Environment(\.yalaTheme) private var theme
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
                currencyCode: currencyCode
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
        Text(YalaFormatter.amountCashFlowCell(value: displayAmount, currencyCode: currencyCode))
            .font(DS.Typography.labelSmall)
            .foregroundStyle(amountColor)
            .fontWeight(lineResult.isOverride ? .bold : .regular)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var amountColor: Color {
        if lineResult.isOverride {
            return .primary
        }
        if month.isPast, let diff = lineResult.difference {
            if abs(diff) > lineResult.plannedAmount * 0.1 {
                if lineResult.isIncome {
                    return diff >= 0 ? Color.electricIndigo : Color.hotPink
                }
                return diff > 0 ? Color.hotPink : Color.electricIndigo
            }
        }
        return .secondary
    }

    // MARK: - Progress Bar

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            let clampedProgress = min(1.0, max(0, progress))
            let barWidth = geo.size.width * clampedProgress
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
        if progress > 1.0 { return Color.hotPink }
        return theme.accent
    }

}
