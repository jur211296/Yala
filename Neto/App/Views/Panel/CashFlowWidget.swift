//
//  CashFlowWidget.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Charts
import SwiftUI

struct CashFlowWidget: View {
    let summary: CashFlowSummary
    let size: WidgetSize
    let period: String
    let grouping: TrendGrouping
    let interval: DateInterval
    let onShowDetail: (() -> Void)?

    init(
        summary: CashFlowSummary,
        size: WidgetSize,
        period: String,
        grouping: TrendGrouping,
        interval: DateInterval,
        onShowDetail: (() -> Void)? = nil
    ) {
        self.summary = summary
        self.size = size
        self.period = period
        self.grouping = grouping
        self.interval = interval
        self.onShowDetail = onShowDetail
    }

    @Environment(\.colorScheme) var colorScheme

    // ... (imports)

    var body: some View {
        VStack(spacing: 0) {
            // Header with title, subtitle and value
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.CashFlow.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.bottom, 2)

                    Text("Flujo Neto")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(
                        NetoFormatter.currency(
                            value: summary.netFlow, currencyCode: summary.currencyCode,
                            forceSign: true)
                    )
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                }

                Spacer()

                if onShowDetail != nil {
                    Button(action: { onShowDetail?() }) {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundStyle(Color.gray.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding([.horizontal, .top], DesignSystem.Spacing.large)
            .padding(.bottom, DesignSystem.Spacing.medium)

            contentView
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge)
                .fill(Color.netoCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    @State private var selectedDate: Date?

    @ViewBuilder
    private var contentView: some View {
        if size == .large {
            // Large - Chart View
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                // Chart
                Chart {
                    // Zero Baseline
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(Color.netoSecondaryText.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                    ForEach(summary.chartData) { data in
                        // Income (Up)
                        BarMark(
                            x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                            y: .value("Income", data.income)
                        )
                        .foregroundStyle(Color.brandPrimary.gradient)
                        .cornerRadius(4)

                        // Expense (Down)
                        BarMark(
                            x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                            y: .value("Expense", -data.expense)
                        )
                        .foregroundStyle(Color.expenseGraph.gradient)
                        .cornerRadius(4)

                        // Net Flow Line
                        LineMark(
                            x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                            y: .value("Net", data.net)
                        )
                        .foregroundStyle(Color.incomeGraph)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)

                        // Points on Line
                        PointMark(
                            x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                            y: .value("Net", data.net)
                        )
                        .foregroundStyle(Color.incomeGraph)
                        .symbolSize(20)
                    }
                }  // Close Chart
                .chartXScale(domain: interval.start...interval.end)
                .chartXAxis {
                    AxisMarks(values: .stride(by: calendarUnit(for: grouping))) { value in
                        AxisGridLine().foregroundStyle(.clear)  // Explicitly hide gridlines
                        AxisTick().foregroundStyle(.clear)  // Explicitly hide ticks

                        if grouping == .day {
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                        } else if grouping == .week {
                            AxisValueLabel(
                                format: .dateTime.day().month(.abbreviated), centered: true)
                        } else {
                            // Use abbreviated (3 letters: Jan, Feb...) instead of narrow
                            AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(dash: [5, 5]))
                            .foregroundStyle(Color.netoSecondaryText.opacity(0.2))
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(formatK(doubleValue))
                                    .font(.caption2)
                                    .foregroundStyle(Color.netoSecondaryText)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        let plotFrame = proxy.plotFrame.map { geo[$0] } ?? geo.frame(in: .local)

                        ZStack(alignment: .topLeading) {
                            // 1. Gesture Handler (Invisible)
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let x = value.location.x - plotFrame.origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                // Find EXACT match based on grouping granularity
                                                let granularity: Calendar.Component =
                                                    grouping == .month
                                                    ? .month
                                                    : (grouping == .week ? .weekOfYear : .day)

                                                if let match = summary.chartData.first(where: {
                                                    Calendar.current.isDate(
                                                        $0.date, equalTo: date,
                                                        toGranularity: granularity)
                                                }) {
                                                    self.selectedDate = match.date
                                                }
                                            }
                                        }
                                        .onEnded { _ in
                                            self.selectedDate = nil
                                        }
                                )

                            // 2. Hover Visuals (Line + Tooltip)
                            if let selectedDate = selectedDate,
                                let selectedData = summary.chartData.first(where: {
                                    Calendar.current.isDate(
                                        $0.date, equalTo: selectedDate,
                                        toGranularity: grouping == .month
                                            ? .month : (grouping == .week ? .weekOfYear : .day))
                                }),
                                let xPos = proxy.position(forX: selectedData.date)
                            {  // Position line at the exact data point center

                                // Tooltip Card
                                VStack(spacing: 6) {
                                    Group {
                                        if grouping == .day {
                                            Text(
                                                selectedData.date,
                                                format: .dateTime.weekday(.abbreviated).day().month(
                                                    .abbreviated
                                                ).year())
                                        } else if grouping == .week {
                                            Text(
                                                selectedData.date,
                                                format: .dateTime.day().month(.abbreviated).year())
                                        } else {
                                            Text(
                                                selectedData.date,
                                                format: .dateTime.month(.abbreviated).year())
                                        }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(Color.netoSecondaryText)

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Circle().fill(Color.brandPrimary).frame(
                                                width: 6, height: 6)
                                            Text(
                                                NetoFormatter.currency(
                                                    value: selectedData.income,
                                                    currencyCode: summary.currencyCode,
                                                    forceSign: true)
                                            )
                                            .font(.caption2.bold())
                                            .foregroundStyle(Color.brandPrimary)
                                        }
                                        HStack {
                                            Circle().fill(Color.expenseGraph).frame(
                                                width: 6, height: 6)
                                            Text(
                                                NetoFormatter.currency(
                                                    value: selectedData.expense,
                                                    currencyCode: summary.currencyCode
                                                )
                                            )
                                            .font(.caption2.bold())
                                            .foregroundStyle(Color.expenseGraph)
                                        }
                                        Divider()
                                        HStack {
                                            Circle().fill(Color.incomeGraph).frame(
                                                width: 6, height: 6)
                                            Text(
                                                NetoFormatter.currency(
                                                    value: selectedData.net,
                                                    currencyCode: summary.currencyCode,
                                                    forceSign: true)
                                            )
                                            .font(.caption2.bold())
                                            .foregroundStyle(Color.incomeGraph)
                                        }
                                    }
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                                        .fill(Color.netoCard)
                                        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                                )
                                .fixedSize()  // Prevent expansion
                                .position(
                                    x: max(80, min(xPos + plotFrame.origin.x, geo.size.width - 80)),
                                    y: plotFrame.minY + 20
                                )
                                .offset(y: -50)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.bottom, DesignSystem.Spacing.large)

        } else {
            // Small & Medium - Summary Layout (With Bars)
            VStack(alignment: .leading, spacing: 16) {
                // Bars Section
                // Calculate max value for normalization
                let maxVal = max(summary.totalIncome, summary.totalExpense)

                VStack(spacing: 12) {
                    // Income Group
                    VStack(spacing: 6) {
                        HStack {
                            Text(L10n.CashFlow.income)
                                .font(.subheadline)
                                .foregroundStyle(Color.netoSecondaryText)
                            Spacer()
                            Text(
                                NetoFormatter.currency(
                                    value: summary.totalIncome, currencyCode: summary.currencyCode)
                            )
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.netoPrimaryText)
                        }
                        // Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Track
                                Capsule()
                                    .fill(Color.netoPrimaryText.opacity(0.05))
                                    .frame(height: 8)

                                // Fill
                                let width =
                                    maxVal > 0 ? (summary.totalIncome / maxVal) * geo.size.width : 0
                                Capsule()
                                    .fill(Color.brandPrimary)
                                    .frame(width: max(width, 6), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }

                    // Expense Group
                    VStack(spacing: 6) {
                        HStack {
                            Text("Gastos")
                                .font(.subheadline)
                                .foregroundStyle(Color.netoSecondaryText)
                            Spacer()
                            Text(
                                NetoFormatter.currency(
                                    value: summary.totalExpense, currencyCode: summary.currencyCode)
                            )
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        // Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Track
                                Capsule()
                                    .fill(Color.netoPrimaryText.opacity(0.05))
                                    .frame(height: 8)

                                // Fill
                                let width =
                                    maxVal > 0
                                    ? (summary.totalExpense / maxVal) * geo.size.width : 0
                                Capsule()
                                    .fill(Color.expenseGraph)
                                    .frame(width: max(width, 6), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.bottom, DesignSystem.Spacing.xLarge)
        }
    }

    // Consistent Widget Background Logic
    private var cardBackgroundColor: Color {
        if colorScheme == .dark {
            return Color.deepSlate.opacity(0.6)
        } else {
            return Color.white.opacity(0.7)
        }
    }

    // Helpers
    private func formatK(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : (value > 0 ? "" : "")  // Only negative sign for Y axis usually
        // Note: User image had "-40K".

        if absValue >= 1000 {
            let kValue = absValue / 1000.0
            return String(format: "%@%.0fK", sign, kValue)
        } else {
            return String(format: "%@%.0f", sign, absValue)
        }
    }

    private func calendarUnit(for grouping: TrendGrouping) -> Calendar.Component {
        switch grouping {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }
}
