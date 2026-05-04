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

    /// Slot pedagógico opcional inyectado en el header (Panel Polish #2).
    var headerInfoButton: AnyView? = nil

    init(
        data: ExchangeRateWidgetData?,
        preferredCurrency: String,
        selectedCurrencies: Binding<[CurrencyCode]>,
        grouping: TrendGrouping,
        headerInfoButton: AnyView? = nil
    ) {
        self.data = data
        self.preferredCurrency = preferredCurrency
        self._selectedCurrencies = selectedCurrencies
        self.grouping = grouping
        self.headerInfoButton = headerInfoButton
    }

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDate: Date?
    @State private var filteredCurrency: CurrencyCode?

    // Colors for currency lines (max 2 secondary currencies — see PanelViewModel.selectedComparisonCurrencies).
    private static let currencyColors: [Color] = [.electricIndigo, .hotPink]

    private func colorForIndex(_ index: Int) -> Color {
        Self.currencyColors[index % Self.currencyColors.count]
    }

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            // Header
            headerView
                .padding([.horizontal, .top], DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)

            // Content
            contentView
        }
        .solidCard(radius: DS.Panel.widgetRadius)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.ExchangeRate.title)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)

                    WidgetHeaderInfoSlot(
                        injected: headerInfoButton,
                        legacyTitle: L10n.WidgetType.exchangeRate,
                        legacyMessage: L10n.Widget.Hint.exchangeRate
                    )
                }
                .padding(.bottom, DS.Spacing.xxs)

                // Subtitle: "Hoy, HH:mm" or "d MMM, HH:mm"
                if let data = data, !data.hasError {
                    Text(formatSubtitleDate(data.currentRatesDate))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.Empty.noData)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.Accessibility.exchangeRateChart)
                    .accessibilityValue(data.chartPoints.isEmpty ? L10n.Accessibility.noData :
                        L10n.Accessibility.currenciesCount(data.currentRates.count))
            }
        } else {
            loadingView
        }
    }

    // MARK: - Date Formatting

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateDayTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    /// Formats date for subtitle: "Hoy, 15:45" or "19 dic, 15:45"
    private func formatSubtitleDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let timeStr = Self.timeFormatter.string(from: date)
            return "\(L10n.Widget.today), \(timeStr)"
        } else {
            return Self.dateDayTimeFormatter.string(from: date)
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
                            let lineColor = colorForIndex(originalIndex)
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Rate", rate),
                                series: .value("Currency", currency.rawValue)
                            )
                            .foregroundStyle(lineColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.monotone)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Rate", rate)
                            )
                            .foregroundStyle(lineColor)
                            .symbolSize(20)
                            .annotation(position: originalIndex % 2 == 0 ? .top : .bottom, spacing: DS.Spacing.xxs) {
                                // Only show labels on first, last, and middle points to avoid clutter
                                if shouldShowLabel(for: point, in: data.chartPoints) {
                                    Text(formatRateCompact(rate))
                                        .font(DS.Typography.captionSmall).fontWeight(.medium)
                                        .foregroundStyle(lineColor)
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
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.thSecondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(dash: [5, 5]))
                        .foregroundStyle(.thSecondaryText.opacity(0.2))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatRate(doubleValue))
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.thSecondaryText)
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
                                            let granularity = grouping.calendarComponent
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
                                    toGranularity: grouping.calendarComponent)
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
                        let color = colorForIndex(index)
                        let isSelected = filteredCurrency == nil || filteredCurrency == currency

                        Button {
                            dsWithAnimation(reduceMotion, .easeInOut(duration: 0.2)) {
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
                                    .font(DS.Typography.labelTiny)
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
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.thSecondaryText)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                ForEach(visibleCurrencies, id: \.rawValue) { currency in
                    // Use original index from allActiveCurrencies for consistent colors
                    let originalIndex = allActiveCurrencies.firstIndex(of: currency) ?? 0
                    if let rate = point.rate(for: currency.rawValue) {
                        let tooltipColor = colorForIndex(originalIndex)
                        HStack(spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(tooltipColor)
                                .frame(width: 5, height: 5)
                            Text(
                                "1 \(currency.rawValue) = \(formatRate(rate)) \(preferredCurrency)"
                            )
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(tooltipColor)
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.thCard)
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
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
    }

    private var emptyChartView: some View {
        YalaEmptyState(icon: "chart.line.downtrend.xyaxis", title: L10n.Widget.noDataForPeriod, style: .widget)
            .frame(height: 120)
    }

    private var noSecondaryCurrenciesView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(DS.Typography.title)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(L10n.ExchangeRate.noSecondaryCurrenciesHint)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(L10n.ExchangeRate.noSecondaryCurrenciesPath)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(theme.accent)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(DS.Typography.title)
                .foregroundStyle(DS.Semantic.warningForeground)
                .accessibilityHidden(true)
            Text(message)
                .font(DS.Typography.caption)
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

    private static let tooltipDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private static let tooltipWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private static let tooltipMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "MMM yyyy"
        return f
    }()

    private func formatTooltipDate(_ date: Date) -> String {
        let formatter: DateFormatter
        switch grouping {
        case .day: formatter = Self.tooltipDayFormatter
        case .week: formatter = Self.tooltipWeekFormatter
        case .month: formatter = Self.tooltipMonthFormatter
        }
        return formatter.string(from: date)
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
            let now = Date.now
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
