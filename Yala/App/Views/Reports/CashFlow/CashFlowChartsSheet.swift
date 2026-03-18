//
//  CashFlowChartsSheet.swift
//  Yala
//
//  Charts sheet with 5 cash flow visualizations.
//

import Charts
import SwiftUI

struct CashFlowChartsSheet: View {
    let projection: CashFlowProjection
    let currencyCode: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    private var isPro: Bool {
        FeatureGateService.shared.canAccess(.cashFlowAdvanced)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.Spacing.xl) {
                    accumulatedBalanceChart
                    proChartSection(L10n.CashFlowPlan.incomeVsExpense) {
                        incomeVsExpenseChart
                    }
                    proChartSection(L10n.CashFlowPlan.composition) {
                        compositionChart
                    }
                    proChartSection(L10n.CashFlowPlan.realVsPlan) {
                        realVsPlanChart
                    }
                    proChartSection(L10n.CashFlowPlan.trendByLine) {
                        trendByLineChart
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .yalaSafeBottomPadding()
            }
            .navigationTitle(L10n.CashFlowPlan.chartsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 1. Accumulated Balance (Free)

    private var accumulatedBalanceChart: some View {
        chartCard(title: L10n.CashFlowPlan.accumulatedBalance) {
            Chart(projection.months, id: \.monthKey) { month in
                LineMark(
                    x: .value("Month", month.date),
                    y: .value("Balance", month.accumulatedBalance)
                )
                .foregroundStyle(theme.accent)
                .lineStyle(month.isPast || month.isCurrent ? StrokeStyle(lineWidth: 2) : StrokeStyle(lineWidth: 2, dash: [5, 3]))

                AreaMark(
                    x: .value("Month", month.date),
                    y: .value("Balance", month.accumulatedBalance)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.accent.opacity(0.3), theme.accent.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - 2. Income vs Expense (Pro)

    private var incomeVsExpenseChart: some View {
        chartCard(title: L10n.CashFlowPlan.incomeVsExpense) {
            Chart(projection.months, id: \.monthKey) { month in
                BarMark(
                    x: .value("Month", month.date),
                    y: .value("Amount", month.totalIncome)
                )
                .foregroundStyle(DS.Semantic.successForeground.opacity(0.8))
                .position(by: .value("Type", "Income"))

                BarMark(
                    x: .value("Month", month.date),
                    y: .value("Amount", month.totalExpense)
                )
                .foregroundStyle(DS.Semantic.errorForeground.opacity(0.8))
                .position(by: .value("Type", "Expense"))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - 3. Expense Composition (Pro)

    private var compositionChart: some View {
        chartCard(title: L10n.CashFlowPlan.composition) {
            Chart {
                ForEach(projection.months, id: \.monthKey) { month in
                    ForEach(month.expenseLines, id: \.lineID) { line in
                        BarMark(
                            x: .value("Month", month.date),
                            y: .value("Amount", line.plannedAmount)
                        )
                        .foregroundStyle(by: .value("Line", line.name))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - 4. Real vs Plan (Pro)

    private var realVsPlanChart: some View {
        let pastMonths = projection.months.filter { $0.isPast || $0.isCurrent }

        return chartCard(title: L10n.CashFlowPlan.realVsPlan) {
            if pastMonths.isEmpty {
                Text(L10n.CashFlowPlan.emptyState)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
            } else {
                Chart(pastMonths, id: \.monthKey) { month in
                    BarMark(
                        x: .value("Month", month.date),
                        y: .value("Plan", month.totalExpense)
                    )
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .position(by: .value("Type", "Plan"))

                    let realExpense = month.expenseLines.reduce(0.0) { $0 + ($1.realAmount ?? 0) }
                    BarMark(
                        x: .value("Month", month.date),
                        y: .value("Real", realExpense)
                    )
                    .foregroundStyle(realExpense > month.totalExpense ? DS.Semantic.errorForeground.opacity(0.8) : DS.Semantic.successForeground.opacity(0.8))
                    .position(by: .value("Type", "Real"))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - 5. Trend by Line (Pro)

    private var trendByLineChart: some View {
        chartCard(title: L10n.CashFlowPlan.trendByLine) {
            Chart {
                ForEach(allExpenseLines, id: \.id) { line in
                    ForEach(projection.months, id: \.monthKey) { month in
                        let amount = lineAmount(id: line.id, in: month)
                        LineMark(
                            x: .value("Month", month.date),
                            y: .value("Amount", amount)
                        )
                        .foregroundStyle(by: .value("Line", line.name))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - Helpers

    private var allExpenseLines: [(id: UUID, name: String)] {
        guard let first = projection.months.first else { return [] }
        return first.expenseLines.map { (id: $0.lineID, name: $0.name) }
    }

    private func lineAmount(id: UUID, in month: CashFlowMonth) -> Double {
        month.expenseLines.first(where: { $0.lineID == id })?.plannedAmount ?? 0
    }

    // MARK: - Card Container

    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Typography.headline)
            content()
        }
        .padding(DS.Spacing.lg)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .yalaCard(padding: 0)
    }

    // MARK: - Pro Gate

    @ViewBuilder
    private func proChartSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        if isPro {
            content()
        } else {
            ZStack {
                content()
                    .blur(radius: 6)
                    .allowsHitTesting(false)

                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "lock.fill")
                        .font(DS.Typography.title)
                        .foregroundStyle(.secondary)
                    Text(L10n.FeatureGate.upgradeToPro)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
