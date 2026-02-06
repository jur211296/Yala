//
//  ExchangeRateWidget.swift
//  Yala
//
//  Exchange Rate Widget for the Panel.
//  Shows exchange rate trends with currency selection.
//

import Charts
import SwiftUI

struct ExchangeRateWidget: View {
    let data: ExchangeRateWidgetData?
    let preferredCurrency: String
    @Binding var selectedCurrencies: [CurrencyCode]
    let grouping: TrendGrouping
    let onShowDetail: (() -> Void)?

    init(
        data: ExchangeRateWidgetData?,
        preferredCurrency: String,
        selectedCurrencies: Binding<[CurrencyCode]>,
        grouping: TrendGrouping,
        onShowDetail: (() -> Void)? = nil
    ) {
        self.data = data
        self.preferredCurrency = preferredCurrency
        self._selectedCurrencies = selectedCurrencies
        self.grouping = grouping
        self.onShowDetail = onShowDetail
    }

    @Environment(\.colorScheme) var colorScheme
    @State private var selectedDate: Date?
    @State private var filteredCurrency: CurrencyCode?

    // Colors for currency lines
    private let currencyAColor = Color.electricIndigo
    private let currencyBColor = Color.hotPink

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding([.horizontal, .top], DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)

            // Content
            contentView
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(Color.yalaCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.ExchangeRate.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 2)

                // Subtitle: "Hoy, HH:mm" or "d MMM, HH:mm"
                if let data = data, !data.hasError {
                    Text(formatSubtitleDate(data.currentRatesDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.Empty.noData)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            InfoHintButton(
                title: L10n.WidgetType.exchangeRate,
                message: L10n.Widget.Hint.exchangeRate
            )

            Spacer()

            // Optional Detail Chevron
            if onShowDetail != nil {
                Button {
                    onShowDetail?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Color.gray.opacity(0.7))
                        .padding(.leading, DS.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        // Check if there are no secondary currencies selected
        if selectedCurrencies.filter({ $0.rawValue != preferredCurrency }).isEmpty {
            noSecondaryCurrenciesView
        } else if let data = data {
            if data.hasError {
                errorView(message: data.errorMessage ?? L10n.Common.unknownError)
            } else if data.chartPoints.isEmpty {
                emptyChartView
            } else {
                chartView(data: data)
            }
        } else {
            loadingView
        }
    }

    // MARK: - Date Formatting

    /// Formats date for subtitle: "Hoy, 15:45" or "19 dic, 15:45"
    /// Formats date for subtitle: "Hoy, 15:45" or "19 dic, 15:45"
    private func formatSubtitleDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current

        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            let timeStr = formatter.string(from: date)
            return "\(L10n.Widget.today), \(timeStr)"
        } else {
            formatter.dateFormat = "d MMM, HH:mm"
            return formatter.string(from: date)
        }
    }

    // MARK: - Chart View

    @ViewBuilder
    private func chartView(data: ExchangeRateWidgetData) -> some View {
        let activeCurrencies = selectedCurrencies.filter { $0.rawValue != preferredCurrency }
        // Filter currencies based on legend selection
        let visibleCurrencies: [CurrencyCode] = {
            if let filtered = filteredCurrency {
                return activeCurrencies.filter { $0 == filtered }
            }
            return activeCurrencies
        }()
        let yDomain = calculateYDomain(data: data, currencies: visibleCurrencies)
        let smartDates = calculateSmartAxisDates(for: data.chartPoints)
        let xDomain = calculateXDomain(for: data.chartPoints)

        VStack(spacing: DS.Spacing.md) {
            Chart {
                ForEach(data.chartPoints) { point in
                    ForEach(Array(visibleCurrencies.enumerated()), id: \.element.rawValue) {
                        index, currency in
                        // Get original index for consistent colors
                        let originalIndex = activeCurrencies.firstIndex(of: currency) ?? index
                        if let rate = point.rate(for: currency.rawValue) {
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Rate", rate),
                                series: .value("Currency", currency.rawValue)
                            )
                            .foregroundStyle(originalIndex == 0 ? currencyAColor : currencyBColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.monotone)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Rate", rate)
                            )
                            .foregroundStyle(originalIndex == 0 ? currencyAColor : currencyBColor)
                            .symbolSize(20)
                            .annotation(position: originalIndex == 0 ? .top : .bottom, spacing: 2) {
                                // Only show labels on first, last, and middle points to avoid clutter
                                if shouldShowLabel(for: point, in: data.chartPoints) {
                                    Text(formatRateCompact(rate))
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(originalIndex == 0 ? currencyAColor : currencyBColor)
                                }
                            }
                        }
                    }
                }
            }
            .chartYScale(domain: yDomain)
            .chartXScale(domain: xDomain)
            .chartXAxis {
                // Smart dynamic X-axis labels (same approach as TrendChartView)
                AxisMarks(values: smartDates) { value in
                    AxisGridLine().foregroundStyle(.clear)
                    AxisTick().foregroundStyle(.clear)

                    if let date = value.as(Date.self) {
                        let isLast = date == smartDates.last
                        let isFirst = date == smartDates.first
                        let anchor: UnitPoint = isLast ? .topTrailing : (isFirst ? .topLeading : .top)

                        AxisValueLabel(anchor: anchor) {
                            Text(smartAxisLabel(for: date, in: data.chartPoints))
                                .font(.caption2)
                                .foregroundStyle(Color.yalaSecondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(dash: [5, 5]))
                        .foregroundStyle(Color.yalaSecondaryText.opacity(0.2))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatRate(doubleValue))
                                .font(.caption2)
                                .foregroundStyle(Color.yalaSecondaryText)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    let plotFrame = proxy.plotFrame.map { geo[$0] } ?? geo.frame(in: .local)

                    ZStack(alignment: .topLeading) {
                        // Gesture Handler
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let x = value.location.x - plotFrame.origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            let granularity: Calendar.Component = calendarComponent(
                                                for: grouping)
                                            if let match = data.chartPoints.first(where: {
                                                Calendar.current.isDate(
                                                    $0.date, equalTo: date, toGranularity: granularity)
                                            }) {
                                                self.selectedDate = match.date
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        self.selectedDate = nil
                                    }
                            )

                        // Tooltip
                        if let selectedDate = selectedDate,
                            let selectedPoint = data.chartPoints.first(where: {
                                Calendar.current.isDate(
                                    $0.date, equalTo: selectedDate,
                                    toGranularity: calendarComponent(for: grouping))
                            }),
                            let xPos = proxy.position(forX: selectedPoint.date)
                        {
                            tooltipView(
                                point: selectedPoint,
                                visibleCurrencies: visibleCurrencies,
                                allActiveCurrencies: activeCurrencies
                            )
                            .position(
                                x: max(70, min(xPos + plotFrame.origin.x, geo.size.width - 70)),
                                y: plotFrame.minY + 20
                            )
                            .offset(y: -40)
                        }
                    }
                }
            }

            // Interactive Legend below chart
            exchangeRateLegendView(data: data, activeCurrencies: activeCurrencies)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
    }

    // MARK: - Legend View

    @ViewBuilder
    private func exchangeRateLegendView(data: ExchangeRateWidgetData, activeCurrencies: [CurrencyCode]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(Array(activeCurrencies.enumerated()), id: \.element.rawValue) { index, currency in
                    if let rate = data.currentRates[currency.rawValue] {
                        let color = index == 0 ? currencyAColor : currencyBColor
                        let isSelected = filteredCurrency == nil || filteredCurrency == currency

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if filteredCurrency == currency {
                                    // Deselect: show all
                                    filteredCurrency = nil
                                } else {
                                    // Select: show only this one
                                    filteredCurrency = currency
                                }
                            }
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 6, height: 6)

                                Text("1 \(currency.rawValue) = \(formatRate(rate)) \(preferredCurrency)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(color)
                            }
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(isSelected ? color.opacity(0.1) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .opacity(isSelected ? 1.0 : 0.4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Y Domain Calculation

    /// Calculate dynamic Y-axis domain based on data range with padding
    private func calculateYDomain(data: ExchangeRateWidgetData, currencies: [CurrencyCode])
        -> ClosedRange<Double>
    {
        var allValues: [Double] = []

        for point in data.chartPoints {
            for currency in currencies {
                if let rate = point.rate(for: currency.rawValue) {
                    allValues.append(rate)
                }
            }
        }

        guard let minVal = allValues.min(), let maxVal = allValues.max() else {
            return 0...1
        }

        // Calculate range and add padding (10% on each side)
        let range = maxVal - minVal
        let padding = max(range * 0.15, 0.01)  // At minimum 0.01 padding

        return (minVal - padding)...(maxVal + padding)
    }

    /// Determines if a label should be shown for this point (first, last, and optionally middle)
    private func shouldShowLabel(
        for point: ExchangeRateChartPoint, in points: [ExchangeRateChartPoint]
    ) -> Bool {
        guard points.count > 1 else { return true }

        let sortedPoints = points.sorted { $0.date < $1.date }

        // Show on first and last points
        if point.date == sortedPoints.first?.date || point.date == sortedPoints.last?.date {
            return true
        }

        // Show on middle point if we have 5 or more points
        if points.count >= 5 {
            let midIndex = points.count / 2
            if point.date == sortedPoints[midIndex].date {
                return true
            }
        }

        return false
    }

    /// Format rate in a more compact way for inline labels
    private func formatRateCompact(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    // MARK: - Tooltip

    @ViewBuilder
    private func tooltipView(
        point: ExchangeRateChartPoint,
        visibleCurrencies: [CurrencyCode],
        allActiveCurrencies: [CurrencyCode]
    ) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(formatTooltipDate(point.date))
                .font(.caption2)
                .foregroundStyle(Color.yalaSecondaryText)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                ForEach(visibleCurrencies, id: \.rawValue) { currency in
                    // Use original index from allActiveCurrencies for consistent colors
                    let originalIndex = allActiveCurrencies.firstIndex(of: currency) ?? 0
                    if let rate = point.rate(for: currency.rawValue) {
                        HStack(spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(originalIndex == 0 ? currencyAColor : currencyBColor)
                                .frame(width: 5, height: 5)
                            Text(
                                "1 \(currency.rawValue) = \(formatRate(rate)) \(preferredCurrency)"
                            )
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(originalIndex == 0 ? currencyAColor : currencyBColor)
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(Color.yalaCard)
                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
        )
        .fixedSize()
    }

    // MARK: - Helper Views

    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text(L10n.Common.loading)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
    }

    private var emptyChartView: some View {
        VStack {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(L10n.Widget.noDataForPeriod)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
    }

    private var noSecondaryCurrenciesView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(L10n.ExchangeRate.noSecondaryCurrenciesHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(L10n.ExchangeRate.noSecondaryCurrenciesPath)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.electricIndigo)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
    }

    // MARK: - Helpers

    private func formatRate(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    private func formatTooltipDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current

        switch grouping {
        case .day:
            formatter.dateFormat = "EEE d MMM"
        case .week:
            formatter.dateFormat = "d MMM yyyy"
        case .month:
            formatter.dateFormat = "MMM yyyy"
        }

        return formatter.string(from: date)
    }

    private func calendarUnit(for grouping: TrendGrouping) -> Calendar.Component {
        switch grouping {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }

    private func calendarComponent(for grouping: TrendGrouping) -> Calendar.Component {
        switch grouping {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }

    // MARK: - Smart Axis Helpers

    /// Calculate smart axis dates based on actual data range (same approach as TrendChartView)
    private func calculateSmartAxisDates(for chartPoints: [ExchangeRateChartPoint]) -> [Date] {
        guard let firstDate = chartPoints.first?.date,
              let lastDate = chartPoints.last?.date else {
            return []
        }
        return SmartAxisHelper.calculateSmartAxisDates(from: firstDate, to: lastDate)
    }

    /// Calculate X-axis domain from chart points
    private func calculateXDomain(for chartPoints: [ExchangeRateChartPoint]) -> ClosedRange<Date> {
        guard let firstDate = chartPoints.first?.date,
              let lastDate = chartPoints.last?.date else {
            let now = Date()
            return now...now
        }
        // Add small padding to avoid clipping edge points
        let padding: TimeInterval = 86400 * 2  // 2 days
        return firstDate.addingTimeInterval(-padding)...lastDate.addingTimeInterval(padding)
    }

    /// Format axis label using SmartAxisHelper (shows year when spanning multiple years)
    private func smartAxisLabel(for date: Date, in chartPoints: [ExchangeRateChartPoint]) -> String {
        guard let firstDate = chartPoints.first?.date,
              let lastDate = chartPoints.last?.date else {
            return ""
        }
        return SmartAxisHelper.formatAxisLabel(for: date, startDate: firstDate, endDate: lastDate)
    }
}

