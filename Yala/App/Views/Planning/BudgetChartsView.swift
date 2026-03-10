//
//  BudgetChartsView.swift
//  Yala
//
//  Charts view for a budget showing compliance history, daily spending, and category breakdown.
//  Pushed from BudgetDetailView toolbar.
//

import Charts
import SwiftData
import SwiftUI

struct BudgetChartsView: View {
    @Environment(\.yalaTheme) private var theme
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen.rawValue

    let budget: Budget
    @Bindable var viewModel: BudgetsViewModel

    @State private var selectedCategory: String?

    private var periodType: BudgetPeriodType? {
        BudgetPeriodType(rawValue: budget.periodType)
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // 1. Compliance history (hidden for .unique)
                    if periodType != .unique {
                        complianceChart
                    }

                    // 2. Daily cumulative spending
                    dailySpendingChart

                    // 3. Category breakdown
                    categoryBreakdownSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
        }
        .navigationTitle(L10n.BudgetDetail.chartsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Compliance History Chart

    private var complianceChart: some View {
        let data = viewModel.getHistoricalSpending(
            budget: budget,
            periods: 6,
            defaultCurrencyCode: defaultCurrencyCode
        )

        return chartCard(title: L10n.BudgetDetail.chartsCompliance) {
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(Array(data.enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("Period", item.label),
                        y: .value("Spent", item.spent)
                    )
                    .foregroundStyle(item.spent >= item.limit ? Color.hotPink.gradient : Color.expenseGraph.gradient)
                    .cornerRadius(DS.Radius.xs)

                    if let first = data.first, first.limit > 0 {
                        RuleMark(y: .value("Limit", first.limit))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(DS.Typography.labelTiny)
                                    .foregroundStyle(.thSecondaryText)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.thSecondaryText.opacity(0.1))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(YalaFormatter.axisK(amount))
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.thSecondaryText)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - Daily Cumulative Spending Chart

    private var dailySpendingChart: some View {
        let data = viewModel.getDailyCumulativeSpending(
            budget: budget
        )
        let primaryColor = theme.accent

        return chartCard(title: L10n.BudgetDetail.chartsDailySpending) {
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("Cumulative", item.cumulative)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            .linearGradient(
                                colors: [primaryColor.opacity(0.1), primaryColor.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Cumulative", item.cumulative)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(primaryColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    // Limit line
                    RuleMark(y: .value("Limit", budget.limitAmount))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.hotPink.opacity(0.7))
                        .annotation(position: .trailing, alignment: .trailing) {
                            Text(YalaFormatter.axisK(budget.limitAmount))
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(Color.hotPink)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, data.count / 5))) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(dayLabel(date))
                                    .font(DS.Typography.labelTiny)
                                    .foregroundStyle(.thSecondaryText)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.thSecondaryText.opacity(0.1))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(YalaFormatter.axisK(amount))
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.thSecondaryText)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - Category Breakdown (Interactive)

    private var categoryBreakdownSection: some View {
        let breakdown = viewModel.getCombinedBreakdown(budget: budget)
        let parentData = breakdown.parentCategories
        let subData = breakdown.subcategories
        let maxParentAmount = parentData.max(by: { $0.amount < $1.amount })?.amount ?? 1

        let filteredSubs: [(name: String, icon: String, color: String, amount: Double, parentCategoryName: String)]
        if let selected = selectedCategory {
            filteredSubs = subData.filter { $0.parentCategoryName == selected }
        } else {
            filteredSubs = subData
        }
        let maxSubAmount = filteredSubs.max(by: { $0.amount < $1.amount })?.amount ?? 1

        return chartCard(title: L10n.BudgetDetail.chartsCategoryBreakdown) {
            if parentData.isEmpty {
                emptyChartPlaceholder
            } else {
                VStack(spacing: DS.Spacing.lg) {
                    // Parent categories
                    ForEach(Array(parentData.enumerated()), id: \.offset) { _, item in
                        let isSelected = selectedCategory == item.name
                        let isDimmed = selectedCategory != nil && !isSelected

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = isSelected ? nil : item.name
                            }
                        } label: {
                            breakdownRow(
                                name: item.name,
                                icon: item.icon,
                                color: item.color,
                                amount: item.amount,
                                maxAmount: maxParentAmount
                            )
                            .opacity(isDimmed ? 0.4 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }

                    // Subcategories
                    if !filteredSubs.isEmpty {
                        SubsectionDivider()

                        Text(L10n.BudgetDetail.subcategories)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(Array(filteredSubs.enumerated()), id: \.offset) { _, item in
                            breakdownRow(
                                name: item.name,
                                icon: item.icon,
                                color: item.color,
                                amount: item.amount,
                                maxAmount: maxSubAmount
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Breakdown Row

    private func breakdownRow(
        name: String,
        icon: String,
        color: String,
        amount: Double,
        maxAmount: Double
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

                Image(systemName: icon)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and Amount
                HStack {
                    Text(name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(YalaFormatter.currency(value: amount, currencyCode: budget.currencyCode))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                }

                // Bar
                GeometryReader { geo in
                    let width = maxAmount > 0 ? (amount / maxAmount) * geo.size.width : 0

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DS.Semantic.neutralBackground)
                            .frame(height: 6)

                        Capsule()
                            .fill(Color(hex: color))
                            .frame(width: width, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    // MARK: - Chart Card Container

    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)

            content()
        }
        .padding(DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(.thCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Colors.borderDark, lineWidth: 0.8)
        )
    }

    private var emptyChartPlaceholder: some View {
        Text(L10n.BudgetDetail.chartsNoData)
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 100)
    }

    // MARK: - Helpers

    private static let dayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private func dayLabel(_ date: Date) -> String {
        Self.dayLabelFormatter.string(from: date)
    }

}

#Preview {
    NavigationStack {
        Text("Preview requires Budget instance")
    }
}
