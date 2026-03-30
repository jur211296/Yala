//
//  CashFlowChartsSheet.swift
//  Yala
//
//  Charts sheet with 4 cash flow visualizations matching PanelView style.
//

import Charts
import SwiftUI

struct CashFlowChartsSheet: View {
    let projection: CashFlowProjection
    let currencyCode: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    @State private var selectedMonth: Date?

    // Cached computed data (computed once on appear)
    @State private var cachedPastMonths: [CashFlowMonth] = []
    @State private var cachedDeviations: [DeviationItem] = []
    @State private var cachedRollingAvg: [RollingPoint] = []

    private var isPro: Bool {
        FeatureGateService.shared.canAccess(.cashFlowAdvanced)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.Spacing.xl) {
                    projectionChart
                    proChartSection { deviationChart }
                    proChartSection { savingsChart }
                    proChartSection { accuracyChart }
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
        .onAppear { cacheData() }
    }

    private func cacheData() {
        cachedPastMonths = projection.months.filter { $0.isPast || $0.isCurrent }
        cachedDeviations = Self.buildDeviations(from: cachedPastMonths)
        cachedRollingAvg = Self.buildRollingAverage(from: cachedPastMonths)
    }

    private var selectedProjectionMonth: CashFlowMonth? {
        guard let selectedDate = selectedMonth else { return nil }
        return projection.months.first(where: {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .month)
        })
    }

    // MARK: - 1. Balance Projection (Free)

    private var projectionChart: some View {
        chartCard(
            title: L10n.CashFlowPlan.chartProjection,
            kpiValue: YalaFormatter.currency(value: projection.months.last?.accumulatedBalance ?? 0, currencyCode: currencyCode)
        ) {
            Chart {
                ForEach(projection.months, id: \.monthKey) { month in
                    LineMark(
                        x: .value("Month", month.date),
                        y: .value("Balance", month.accumulatedBalance)
                    )
                    .foregroundStyle(theme.accent)
                    .lineStyle(month.isPast || month.isCurrent
                        ? StrokeStyle(lineWidth: 2)
                        : StrokeStyle(lineWidth: 2, dash: [5, 3]))

                    AreaMark(
                        x: .value("Month", month.date),
                        y: .value("Balance", month.accumulatedBalance)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent.opacity(0.2), theme.accent.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }

                if let month = selectedProjectionMonth {
                    PointMark(
                        x: .value("Month", month.date),
                        y: .value("Balance", month.accumulatedBalance)
                    )
                    .foregroundStyle(theme.accent)
                    .symbolSize(40)

                    RuleMark(x: .value("Month", month.date))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }

                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.hotPink.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .topLeading) {
                        Text(L10n.CashFlowPlan.chartDangerZone)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(Color.hotPink.opacity(0.7))
                    }
            }
            .yalaChartYAxis()
            .yalaChartXAxisMonthly()
            .chartXSelection(value: $selectedMonth)
            .frame(height: 180)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if let month = selectedProjectionMonth,
                       let xPos = proxy.position(forX: month.date) {
                        let plotFrame = proxy.plotFrame.map { geo[$0] } ?? geo.frame(in: .local)
                        VStack(spacing: DS.Spacing.xxs) {
                            Text(month.date.formatted(.dateTime.month(.abbreviated).year()))
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                            Text(YalaFormatter.currency(value: month.accumulatedBalance, currencyCode: currencyCode))
                                .font(DS.Typography.label)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        )
                        .position(
                            x: min(max(xPos + plotFrame.minX, 40), plotFrame.maxX - 40),
                            y: plotFrame.minY - 8
                        )
                    }
                }
            }
        }
    }

    // MARK: - 2. Where You Exceed the Plan (Pro)

    private var deviationChart: some View {
        chartCard(
            title: L10n.CashFlowPlan.chartDeviation,
            kpiValue: nil
        ) {
            if cachedDeviations.isEmpty {
                needMoreDataView
            } else {
                Chart(cachedDeviations, id: \.name) { item in
                    BarMark(
                        x: .value("Deviation", item.deviation),
                        y: .value("Line", item.name)
                    )
                    .foregroundStyle(item.deviation > 0 ? Color.hotPink.opacity(0.8) : Color.electricIndigo.opacity(0.8))
                }
                .yalaChartYAxis()
                .frame(height: max(120, CGFloat(cachedDeviations.count) * 36))
            }
        }
    }

    // MARK: - 3. Monthly Savings (Pro)

    private var savingsChart: some View {
        chartCard(
            title: L10n.CashFlowPlan.chartSavings,
            kpiValue: cachedPastMonths.last.map { YalaFormatter.currency(value: $0.netFlow, currencyCode: currencyCode) }
        ) {
            if cachedPastMonths.count < 2 {
                needMoreDataView
            } else {
                Chart {
                    ForEach(cachedPastMonths, id: \.monthKey) { month in
                        BarMark(
                            x: .value("Month", month.date),
                            y: .value("Net", month.netFlow)
                        )
                        .foregroundStyle(month.netFlow >= 0 ? Color.electricIndigo.opacity(0.7) : Color.hotPink.opacity(0.7))
                    }

                    ForEach(cachedRollingAvg, id: \.monthKey) { point in
                        LineMark(
                            x: .value("Month", point.date),
                            y: .value("Avg", point.value)
                        )
                        .foregroundStyle(theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Month", point.date),
                            y: .value("Avg", point.value)
                        )
                        .foregroundStyle(theme.accent)
                        .symbolSize(20)
                    }
                }
                .yalaChartYAxis()
                .yalaChartXAxisMonthly()
                .frame(height: 180)
            }
        }
    }

    // MARK: - 4. Plan Accuracy (Pro)

    private var accuracyChart: some View {
        chartCard(
            title: L10n.CashFlowPlan.chartAccuracy,
            kpiValue: nil
        ) {
            if cachedPastMonths.count < 2 {
                needMoreDataView
            } else {
                Chart(cachedPastMonths, id: \.monthKey) { month in
                    BarMark(
                        x: .value("Month", month.date),
                        y: .value("Plan", month.totalExpense)
                    )
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .position(by: .value("Type", L10n.CashFlowPlan.plan))

                    let realExpense = month.expenseLines.reduce(0.0) { $0 + ($1.realAmount ?? 0) }
                    BarMark(
                        x: .value("Month", month.date),
                        y: .value("Real", realExpense)
                    )
                    .foregroundStyle(realExpense > month.totalExpense
                        ? Color.hotPink.opacity(0.8)
                        : Color.electricIndigo.opacity(0.8))
                    .position(by: .value("Type", L10n.CashFlowPlan.real))
                }
                .yalaChartYAxis()
                .yalaChartXAxisMonthly()
                .frame(height: 180)
            }
        }
    }

    // MARK: - Chart Card Container

    private func chartCard<Content: View>(
        title: String,
        kpiValue: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(DS.Typography.headline)
                Spacer()
                if let kpi = kpiValue {
                    Text(kpi)
                        .font(DS.Typography.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }
            content()
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }

    private var needMoreDataView: some View {
        Text(L10n.CashFlowPlan.chartNeedMoreData)
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 120)
    }

    // MARK: - Pro Gate

    @ViewBuilder
    private func proChartSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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

    // MARK: - Cached Data Builders

    private struct DeviationItem {
        let name: String
        let deviation: Double
    }

    private struct RollingPoint {
        let monthKey: String
        let date: Date
        let value: Double
    }

    private static func buildDeviations(from pastMonths: [CashFlowMonth]) -> [DeviationItem] {
        guard !pastMonths.isEmpty else { return [] }

        var deviations: [UUID: (name: String, totalDeviation: Double, count: Int)] = [:]

        for month in pastMonths {
            for line in month.expenseLines {
                guard let real = line.realAmount else { continue }
                let diff = real - line.plannedAmount
                var entry = deviations[line.lineID] ?? (name: line.name, totalDeviation: 0, count: 0)
                entry.totalDeviation += diff
                entry.count += 1
                deviations[line.lineID] = entry
            }
        }

        return deviations.values
            .map { DeviationItem(name: $0.name, deviation: $0.totalDeviation / Double(max(1, $0.count))) }
            .sorted { abs($0.deviation) > abs($1.deviation) }
    }

    private static func buildRollingAverage(from pastMonths: [CashFlowMonth]) -> [RollingPoint] {
        guard pastMonths.count >= 2 else { return [] }

        var result: [RollingPoint] = []
        for i in 0..<pastMonths.count {
            let windowStart = max(0, i - 2)
            let window = pastMonths[windowStart...i]
            let avg = window.map(\.netFlow).reduce(0, +) / Double(window.count)
            result.append(RollingPoint(monthKey: pastMonths[i].monthKey, date: pastMonths[i].date, value: avg))
        }
        return result
    }
}

// MARK: - Shared Chart Axis Modifiers

private extension View {
    func yalaChartYAxis() -> some View {
        self.chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.1))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(YalaFormatter.amountCompactTable(value: v))
                            .font(DS.Typography.captionSmall)
                    }
                }
            }
        }
    }

    func yalaChartXAxisMonthly() -> some View {
        self.chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
    }
}
