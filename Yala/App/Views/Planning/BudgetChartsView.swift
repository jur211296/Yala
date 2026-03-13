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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen.rawValue

    let budget: Budget
    @Bindable var viewModel: BudgetsViewModel

    @State private var selectedCategory: String?

    // Local period state (independent from viewModel's global period)
    @State private var localSelectedWeek: Date = Date.now
    @State private var localSelectedMonth: Date = Date.now
    @State private var localSelectedYear: Int = Calendar.current.component(.year, from: Date.now)
    @State private var showLocalPeriodSelector: Bool = false

    // Scrub interaction
    @State private var draggingDate: Date?

    private var periodType: BudgetPeriodType? {
        BudgetPeriodType(rawValue: budget.periodType)
    }

    // MARK: - Local Period Computed Properties

    private var localDateInterval: DateInterval {
        let calendar = Calendar.current

        guard let pType = periodType else {
            let start = localSelectedMonth
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        }

        switch pType {
        case .weekly:
            let weekStart = localSelectedWeek
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            return DateInterval(start: weekStart, end: weekEnd)

        case .monthly:
            let monthStart = localSelectedMonth
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            return DateInterval(start: monthStart, end: monthEnd)

        case .yearly:
            let yearStart = calendar.date(from: DateComponents(year: localSelectedYear, month: 1, day: 1)) ?? Date.now
            let yearEnd = calendar.date(from: DateComponents(year: localSelectedYear + 1, month: 1, day: 1)) ?? yearStart
            return DateInterval(start: yearStart, end: yearEnd)

        case .unique:
            guard let start = budget.startDate, let end = budget.endDate else {
                let start = localSelectedMonth
                let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
                return DateInterval(start: start, end: end)
            }
            return DateInterval(start: start, end: end)
        }
    }

    private var localPeriodLabel: String {
        let calendar = Calendar.current

        guard let pType = periodType else { return "" }

        switch pType {
        case .weekly:
            let currentWeek = calendar.startOfWeek(for: Date.now)
            if calendar.isDate(localSelectedWeek, equalTo: currentWeek, toGranularity: .weekOfYear) {
                return L10n.Period.thisWeek
            } else if let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek),
                      calendar.isDate(localSelectedWeek, equalTo: prev, toGranularity: .weekOfYear) {
                return L10n.Period.lastWeek
            } else if let next = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek),
                      calendar.isDate(localSelectedWeek, equalTo: next, toGranularity: .weekOfYear) {
                return L10n.Period.nextWeek
            } else {
                let start = Self.weekDateFormatter.string(from: localSelectedWeek)
                let end = calendar.date(byAdding: .day, value: 6, to: localSelectedWeek) ?? localSelectedWeek
                return "\(start) - \(Self.weekDateFormatter.string(from: end))"
            }

        case .monthly:
            let currentMonth = calendar.startOfMonth(for: Date.now)
            if calendar.isDate(localSelectedMonth, equalTo: currentMonth, toGranularity: .month) {
                return L10n.Period.thisMonth
            } else if let prev = calendar.date(byAdding: .month, value: -1, to: currentMonth),
                      calendar.isDate(localSelectedMonth, equalTo: prev, toGranularity: .month) {
                return L10n.Period.lastMonth
            } else if let next = calendar.date(byAdding: .month, value: 1, to: currentMonth),
                      calendar.isDate(localSelectedMonth, equalTo: next, toGranularity: .month) {
                return L10n.Period.nextMonth
            } else {
                return Self.monthYearFormatter.string(from: localSelectedMonth).capitalized
            }

        case .yearly:
            let currentYear = calendar.component(.year, from: Date.now)
            if localSelectedYear == currentYear {
                return L10n.Period.thisYear
            } else if localSelectedYear == currentYear - 1 {
                return L10n.Period.lastYear
            } else if localSelectedYear == currentYear + 1 {
                return L10n.Period.nextYear
            } else {
                return "\(localSelectedYear)"
            }

        case .unique:
            return ""
        }
    }

    private func localPreviousPeriod() {
        let calendar = Calendar.current
        draggingDate = nil
        switch periodType {
        case .weekly:
            if let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: localSelectedWeek) {
                localSelectedWeek = prev
            }
        case .monthly:
            if let prev = calendar.date(byAdding: .month, value: -1, to: localSelectedMonth) {
                localSelectedMonth = prev
            }
        case .yearly:
            localSelectedYear -= 1
        default:
            break
        }
    }

    private func localNextPeriod() {
        let calendar = Calendar.current
        draggingDate = nil
        switch periodType {
        case .weekly:
            if let next = calendar.date(byAdding: .weekOfYear, value: 1, to: localSelectedWeek) {
                localSelectedWeek = next
            }
        case .monthly:
            if let next = calendar.date(byAdding: .month, value: 1, to: localSelectedMonth) {
                localSelectedMonth = next
            }
        case .yearly:
            localSelectedYear += 1
        default:
            break
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // 1. Compliance history (hidden for .unique)
                    if periodType != .unique {
                        complianceChart
                    }

                    // 2. Local period navigation (hidden for .unique)
                    if periodType != .unique {
                        localPeriodNavigationHeader
                    }

                    // 3. Daily cumulative spending
                    dailySpendingChart

                    // 4. Category breakdown
                    categoryBreakdownSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
        }
        .navigationTitle(L10n.BudgetDetail.chartsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize local period from viewModel's current selection
            localSelectedWeek = viewModel.selectedWeek
            localSelectedMonth = viewModel.selectedMonth
            localSelectedYear = viewModel.selectedYear
        }
        .sheet(isPresented: $showLocalPeriodSelector) {
            if let pType = periodType {
                BudgetChartsPeriodSelector(
                    periodType: pType,
                    selectedWeek: $localSelectedWeek,
                    selectedMonth: $localSelectedMonth,
                    selectedYear: $localSelectedYear,
                    transactions: viewModel.allTransactions
                )
                .presentationDetents(DS.Adaptive.sheetDetents([.medium]))
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Local Period Navigation Header

    private var localPeriodNavigationHeader: some View {
        HStack {
            Button {
                dsWithAnimation(reduceMotion) {
                    localPreviousPeriod()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showLocalPeriodSelector = true
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(localPeriodLabel)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.down")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                dsWithAnimation(reduceMotion) {
                    localNextPeriod()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.sm)
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
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))

                    // Data label on top of each bar
                    PointMark(
                        x: .value("Period", item.label),
                        y: .value("Spent", item.spent)
                    )
                    .symbolSize(0)
                    .annotation(position: .top, spacing: DS.Spacing.xs) {
                        Text(YalaFormatter.currency(value: item.spent, currencyCode: budget.currencyCode))
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(.thSecondaryText)
                    }

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
            budget: budget,
            in: localDateInterval
        )
        let primaryColor = theme.accent
        let yTop = max(budget.limitAmount, data.last?.cumulative ?? 0) * 1.1

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

                    // Scrub interaction
                    if let activeDate = draggingDate,
                       let point = closestCumulativePoint(to: activeDate, in: data) {
                        // Vertical dashed line
                        RuleMark(x: .value("Selected", activeDate))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundStyle(.thSecondaryText)

                        // Ring border
                        PointMark(
                            x: .value("Selected", point.date),
                            y: .value("Value", point.cumulative)
                        )
                        .symbolSize(140)
                        .foregroundStyle(primaryColor)

                        // White dot
                        PointMark(
                            x: .value("Selected", point.date),
                            y: .value("Value", point.cumulative)
                        )
                        .symbolSize(100)
                        .foregroundStyle(.thCard)

                        // Invisible anchor for tooltip
                        PointMark(
                            x: .value("Selected", point.date),
                            y: .value("Top", yTop)
                        )
                        .symbolSize(0)
                        .annotation(
                            position: .top,
                            alignment: tooltipAlignment(for: point.date)
                        ) {
                            VStack(alignment: .center, spacing: DS.Spacing.xs) {
                                Text(dayMonthLabel(point.date))
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.thSecondaryText)
                                Text(YalaFormatter.currency(value: point.cumulative, currencyCode: budget.currencyCode))
                                    .font(DS.Typography.labelSmall)
                                    .foregroundStyle(.thPrimaryText)
                            }
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .fill(.thCard.opacity(0.95))
                                    .shadow(radius: 2)
                            )
                        }
                    }
                }
                .chartXSelection(value: $draggingDate)
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
        let breakdown = viewModel.getCombinedBreakdown(budget: budget, in: localDateInterval)
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

    // MARK: - Scrub Helpers

    private func closestCumulativePoint(to date: Date, in data: [(date: Date, cumulative: Double)]) -> (date: Date, cumulative: Double)? {
        data.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    private func tooltipAlignment(for date: Date) -> Alignment {
        let interval = localDateInterval
        let intervalDuration = interval.end.timeIntervalSince(interval.start)
        guard intervalDuration > 0 else { return .center }

        let datePosition = date.timeIntervalSince(interval.start)
        let percentage = datePosition / intervalDuration

        if percentage < 0.25 {
            return .leading
        } else if percentage > 0.75 {
            return .trailing
        } else {
            return .center
        }
    }

    // MARK: - Formatters

    private static let dayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private static let weekDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private func dayLabel(_ date: Date) -> String {
        Self.dayLabelFormatter.string(from: date)
    }

    private func dayMonthLabel(_ date: Date) -> String {
        Self.dayMonthFormatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        Text("Preview requires Budget instance")
    }
}
