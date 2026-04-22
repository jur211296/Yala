//
//  CashFlowChartsSheet.swift
//  Yala
//
//  Charts sheet: projection, savings, deviation — with AI + rule-based comments.
//

import Charts
import SwiftUI
import TipKit

struct CashFlowChartsSheet: View {
    let viewModel: CashFlowPlanViewModel
    let currencyCode: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    private var projection: CashFlowProjection {
        viewModel.projection ?? CashFlowProjection(
            months: [], startingBalance: 0,
            totalProjectedIncome: 0, totalProjectedExpense: 0, totalProjectedNet: 0
        )
    }

    @State private var draggingDate: Date?
    @State private var showInsightsConsentAlert = false

    @Environment(AppPreferences.self) private var appPreferences

    // Cached computed data (computed once on appear)
    @State private var cachedPastMonths: [CashFlowMonth] = []
    @State private var cachedDeviations: [DeviationItem] = []
    @State private var cachedSavings: [SavingsPoint] = []
    @State private var cachedCombinedComment: String = ""
    @State private var cachedDeviationRuleComment: String = ""
    @State private var showUpgradePrompt = false

    private var isPro: Bool {
        FeatureGateService.shared.isProUser
    }

    private var isAIEnabled: Bool {
        appPreferences.cashFlowAIEnabled && appPreferences.aiInsightsEnabled
    }

    private let aiProTip = AIChartsProTip()
    private let aiFreeUpsellTip = AIChartsFreeUpsellTip()

    private let primaryLineColor: Color = TrendType.balance.color

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.Spacing.xl) {
                    // Projection + Savings section
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        HStack {
                            Text(L10n.CashFlowPlan.chartsSectionTitle)
                                .font(DS.Typography.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.thPrimaryText)
                            Spacer()
                            aiChip
                        }
                        projectionChart
                        savingsChart
                        projectionCommentCard
                    }

                    deviationChart
                    deviationCommentCard
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .yalaSafeBottomPadding()
            }
            .background(Color(.systemGroupedBackground))
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
        .onAppear {
            cacheData()
            AIChartsProTip.hasSeenCharts = true
            AIChartsFreeUpsellTip.hasSeenCharts = true
        }
        .task(id: isAIEnabled) {
            guard isAIEnabled else { return }
            let deviationData = cachedDeviations.map {
                (name: $0.name, planned: $0.plannedAmount, actual: $0.total, excess: $0.deviation)
            }
            async let cfTask: () = viewModel.loadCashFlowComment(currencyCode: currencyCode)
            async let devTask: () = viewModel.loadDeviationComment(deviations: deviationData, currencyCode: currencyCode)
            _ = await (cfTask, devTask)
        }
        .alert(L10n.AIConsent.insightsTitle, isPresented: $showInsightsConsentAlert) {
            Button(L10n.AIConsent.accept) {
                appPreferences.acceptAIInsightsConsent()
                appPreferences.cashFlowAIEnabled = true
            }
            Button(L10n.AIConsent.privacyPolicy) {
                UIApplication.shared.open(AppConstants.privacyURL)
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.AIConsent.insightsMessage)
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradePromptSheet(feature: .smartInsightsAI, context: .proFeature, source: "cashFlowCharts")
        }
    }

    private func cacheData() {
        cachedPastMonths = projection.months.filter { $0.isPast || $0.isCurrent }

        let iconLookup: [UUID: (iconName: String?, colorHex: String?)] = {
            guard let lines = viewModel.plan?.lines else { return [:] }
            var lookup: [UUID: (iconName: String?, colorHex: String?)] = [:]
            for line in lines {
                let icon = line.subcategory?.iconName ?? line.category?.iconName
                let color = line.subcategory?.colorHex ?? line.category?.colorHex
                lookup[line.id] = (iconName: icon, colorHex: color)
            }
            return lookup
        }()

        cachedDeviations = Self.buildDeviations(from: cachedPastMonths, iconLookup: iconLookup)

        cachedSavings = projection.months.map { month in
            let isPastOrCurrent = month.isPast || month.isCurrent
            let realInc: Double
            let realExp: Double
            if isPastOrCurrent {
                realInc = month.incomeLines.reduce(0.0) { $0 + ($1.realAmount ?? $1.plannedAmount) }
                    + (month.otherIncome?.realAmount ?? 0)
                realExp = month.expenseLines.reduce(0.0) { $0 + ($1.realAmount ?? $1.plannedAmount) }
                    + (month.otherExpenses?.realAmount ?? 0)
            } else {
                realInc = month.totalIncome
                realExp = month.totalExpense
            }
            return SavingsPoint(
                monthKey: month.monthKey, date: month.date,
                actual: realInc - realExp, planned: month.netFlow,
                isPast: isPastOrCurrent
            )
        }

        let pastSavings = cachedSavings.filter(\.isPast)
        let savingsForComment = pastSavings.map { (actual: $0.actual, planned: $0.planned) }
        cachedCombinedComment = CashFlowPlanViewModel.generateCombinedComment(
            projection, savings: savingsForComment, currencyCode: currencyCode
        )
        cachedDeviationRuleComment = CashFlowPlanViewModel.generateDeviationRuleComment(
            cachedDeviations.map { (name: $0.name, amount: $0.deviation) },
            currencyCode: currencyCode
        )

    }

    // MARK: - Shared Helpers

    private var barSmartAxisDates: [Date] {
        SmartAxisHelper.calculateSmartAxisDates(
            forDataDates: cachedPastMonths.map(\.date),
            grouping: .month
        )
    }

    private func barSmartAxisLabel(for date: Date) -> String {
        guard let first = cachedPastMonths.first?.date,
              let last = cachedPastMonths.last?.date else { return "" }
        return SmartAxisHelper.formatAxisLabel(
            for: date, startDate: first, endDate: last,
            forceGrouping: .month
        )
    }

    private var barCenteredDates: [Date] {
        SmartAxisHelper.centerDatesInCalendarUnit(barSmartAxisDates, unit: .month)
    }

    /// X-axis dates for the savings chart — identical to projection (every other month)
    private var savingsAxisLabelDates: [Date] {
        let dates = cachedSavings.map(\.date)
        return stride(from: 0, to: dates.count, by: 2).map { dates[$0] }
    }

    private var barYAxisContent: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(.thSecondaryText.opacity(0.1))
            AxisValueLabel {
                if let doubleValue = value.as(Double.self) {
                    Text(YalaFormatter.axisK(doubleValue))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thSecondaryText)
                }
            }
        }
    }

    private var barXAxisContent: some AxisContent {
        AxisMarks(values: barCenteredDates) { value in
            AxisGridLine()
                .foregroundStyle(.thSecondaryText.opacity(0.1))

            if let date = value.as(Date.self) {
                let anchor = SmartAxisHelper.axisLabelAnchor(
                    for: date, in: barCenteredDates, dataPointCount: cachedPastMonths.count
                )
                AxisValueLabel(anchor: anchor) {
                    Text(barSmartAxisLabel(for: date))
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(.thSecondaryText)
                }
            }
        }
    }

    private func dataLabel(_ value: Double) -> some View {
        Text(value.formatted(.number.precision(.fractionLength(0))))
            .font(DS.Typography.labelTiny)
            .fontWeight(.medium)
            .foregroundStyle(.thPrimaryText)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                    .fill(.thCard.opacity(0.9))
            )
    }

    private func closestMonth(to date: Date) -> CashFlowMonth? {
        projection.months.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    private var projectionYDomain: ClosedRange<Double> {
        let values = projection.months.compactMap(\.accumulatedBalance)
        let minVal = min(values.min() ?? 0, 0)
        let maxVal = values.max() ?? 0
        let headroom = max(abs(maxVal - minVal), 1) * 0.1
        return minVal...(maxVal + headroom)
    }

    private var paddedProjectionXDomain: ClosedRange<Date> {
        guard let first = projection.months.first?.date,
              let last = projection.months.last?.date else { return Date.now...Date.now }
        let span = last.timeIntervalSince(first)
        let padding = max(span * 0.05, 86400)
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }

    private func tooltipAlignment(for date: Date, firstDate: Date, lastDate: Date) -> Alignment {
        let total = lastDate.timeIntervalSince(firstDate)
        guard total > 0 else { return .center }
        let pct = date.timeIntervalSince(firstDate) / total
        if pct < 0.25 { return .leading }
        else if pct > 0.75 { return .trailing }
        else { return .center }
    }

    // MARK: - 1. Balance Projection (Free) — TrendChartView style

    private var projectionChart: some View {
        chartCard(
            title: L10n.CashFlowPlan.chartProjection,
            subtitle: L10n.CashFlowPlan.chartProjectionSubtitle,
            kpiValue: YalaFormatter.currency(value: projection.months.last(where: { $0.accumulatedBalance != nil })?.accumulatedBalance ?? 0, currencyCode: currencyCode)
        ) {
            let today = Calendar.current.startOfDay(for: Date.now)
            let data = projection.months.filter { $0.accumulatedBalance != nil }

            let pastPoints = data.filter { $0.isPast || $0.isCurrent }
            let futurePoints = data.filter { !$0.isPast } // current + future for connection

            let yDomain = projectionYDomain
            let yBase = min(max(yDomain.lowerBound, 0), yDomain.upperBound)
            let midY = yDomain.lowerBound + (yDomain.upperBound - yDomain.lowerBound) * 0.5
            let areaGradient = LinearGradient(
                colors: [primaryLineColor.opacity(0.15), primaryLineColor.opacity(0.03)],
                startPoint: .top, endPoint: .bottom
            )

            // Key months for data labels: first, current, last
            let labelMonthKeys: Set<String> = {
                var keys = Set<String>()
                if let first = data.first { keys.insert(first.monthKey) }
                if let current = data.first(where: { $0.isCurrent }) { keys.insert(current.monthKey) }
                if let last = data.last { keys.insert(last.monthKey) }
                return keys
            }()

            // X-axis labels: every other month from actual data
            let monthDates = data.map(\.date)
            let axisLabelDates = stride(from: 0, to: monthDates.count, by: 2).map { monthDates[$0] }

            Chart {
                // Area fill (past only)
                ForEach(pastPoints, id: \.monthKey) { month in
                    AreaMark(
                        x: .value("Month", month.date),
                        yStart: .value("Base", yBase),
                        yEnd: .value("Balance", month.accumulatedBalance ?? 0)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(areaGradient)
                }

                // Past line: solid (series "actual") + dots
                ForEach(pastPoints, id: \.monthKey) { month in
                    LineMark(
                        x: .value("Month", month.date),
                        y: .value("Balance", month.accumulatedBalance ?? 0)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(by: .value("Period", "actual"))
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Month", month.date),
                        y: .value("Balance", month.accumulatedBalance ?? 0)
                    )
                    .foregroundStyle(primaryLineColor)
                    .symbolSize(20)

                    // Data labels on key months
                    if labelMonthKeys.contains(month.monthKey) {
                        PointMark(
                            x: .value("Month", month.date),
                            y: .value("Balance", month.accumulatedBalance ?? 0)
                        )
                        .symbolSize(0)
                        .annotation(position: month.accumulatedBalance ?? 0 > midY ? .bottom : .top, spacing: DS.Spacing.xs) {
                            dataLabel(month.accumulatedBalance ?? 0)
                        }
                    }
                }

                // Future line: dashed (series "projected") + dots
                ForEach(futurePoints, id: \.monthKey) { month in
                    LineMark(
                        x: .value("Month", month.date),
                        y: .value("Balance", month.accumulatedBalance ?? 0)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(by: .value("Period", "projected"))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))

                    PointMark(
                        x: .value("Month", month.date),
                        y: .value("Balance", month.accumulatedBalance ?? 0)
                    )
                    .foregroundStyle(Color.secondary)
                    .symbolSize(16)

                    // Data label on last month
                    if month.monthKey == data.last?.monthKey {
                        PointMark(
                            x: .value("Month", month.date),
                            y: .value("Balance", month.accumulatedBalance ?? 0)
                        )
                        .symbolSize(0)
                        .annotation(position: month.accumulatedBalance ?? 0 > midY ? .bottom : .top, spacing: DS.Spacing.xs) {
                            dataLabel(month.accumulatedBalance ?? 0)
                        }
                    }
                }

                // Today marker
                RuleMark(x: .value("Today", today))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .foregroundStyle(.thSecondaryText.opacity(0.5))

                // Danger zone (zero line)
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.hotPink.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                // Hover/selection
                if let activeDate = draggingDate,
                   let selectedMonth = closestMonth(to: activeDate),
                   let selectedBalance = selectedMonth.accumulatedBalance {
                    let isUpperHalf = selectedBalance > midY

                    RuleMark(x: .value("Selected", selectedMonth.date))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(.thSecondaryText)

                    PointMark(
                        x: .value("Selected", selectedMonth.date),
                        y: .value("Balance", selectedBalance)
                    )
                    .symbolSize(140)
                    .foregroundStyle(primaryLineColor)

                    PointMark(
                        x: .value("Selected", selectedMonth.date),
                        y: .value("Balance", selectedBalance)
                    )
                    .symbolSize(100)
                    .foregroundStyle(.thCard)
                    .annotation(
                        position: isUpperHalf ? .bottom : .top,
                        alignment: tooltipAlignment(for: selectedMonth.date, firstDate: projection.months.first?.date ?? .now, lastDate: projection.months.last?.date ?? .now)
                    ) {
                        VStack(alignment: .center, spacing: DS.Spacing.xs) {
                            Text(selectedMonth.date.formatted(.dateTime.month(.abbreviated).year()))
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.thSecondaryText)
                            Text(YalaFormatter.currency(value: selectedBalance, currencyCode: currencyCode))
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.thPrimaryText)
                            Divider()
                            Text(YalaFormatter.currency(value: selectedMonth.netFlow, currencyCode: currencyCode, forceSign: true))
                                .font(DS.Typography.labelTiny)
                                .foregroundStyle(.thSecondaryText)
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
            .chartForegroundStyleScale(["actual": primaryLineColor, "projected": Color.secondary])
            .chartLegend(.hidden)
            .chartYAxis { barYAxisContent }
            .chartYScale(domain: yDomain)
            .chartXScale(domain: paddedProjectionXDomain)
            // X-axis: every other month from data
            .chartXAxis {
                AxisMarks(values: axisLabelDates) { value in
                    AxisGridLine()
                        .foregroundStyle(.thSecondaryText.opacity(0.1))

                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(.dateTime.month(.abbreviated)).lowercased().replacing(".", with: ""))
                                .font(DS.Typography.labelTiny)
                                .foregroundStyle(.thSecondaryText)
                        }
                    }
                }
            }
            .chartXSelection(value: $draggingDate)
            .frame(height: 220)
        }
    }

    // MARK: - AI Chip Toggle

    private var aiChipLabel: some View {
        HStack(spacing: DS.Chip.spacing) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
            Text("IA")
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
        }
        .foregroundStyle(appPreferences.cashFlowAIEnabled ? AnyShapeStyle(Color.white) : AnyShapeStyle(.thSecondaryText))
        .padding(.horizontal, DS.Chip.paddingH)
        .padding(.vertical, DS.Chip.paddingV)
        .background {
            Capsule()
                .fill(appPreferences.cashFlowAIEnabled ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.thSecondaryText.opacity(0.08)))
        }
        .overlay(
            Capsule()
                .stroke(appPreferences.cashFlowAIEnabled ? theme.accent.opacity(0.3) : .clear, lineWidth: 1)
        )
    }

    private var aiChip: some View {
        Button {
            if isPro {
                if appPreferences.aiInsightsEnabled {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        appPreferences.cashFlowAIEnabled.toggle()
                    }
                } else {
                    showInsightsConsentAlert = true
                }
            } else {
                showUpgradePrompt = true
            }
        } label: {
            if isPro {
                aiChipLabel.popoverTip(aiProTip, arrowEdge: .top)
            } else {
                aiChipLabel.popoverTip(aiFreeUpsellTip, arrowEdge: .top)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }

    // MARK: - Comment Cards

    @ViewBuilder
    private func aiOrRuleComment(isLoading: Bool, aiComment: String?, ruleComment: String) -> some View {
        if isAIEnabled && isLoading {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(theme.accent)
                    .font(DS.Typography.subheadline)
                Text(L10n.CashFlowPlan.analyzingProjection)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thPrimaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .solidCard()
        } else if isAIEnabled, let comment = aiComment {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(theme.accent)
                    .font(DS.Typography.subheadline)
                Text(LocalizedStringKey(comment))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thPrimaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .solidCard()
        } else {
            ruleCommentCard(ruleComment)
        }
    }

    private var projectionCommentCard: some View {
        aiOrRuleComment(
            isLoading: viewModel.isLoadingComment,
            aiComment: viewModel.cashFlowComment,
            ruleComment: cachedCombinedComment
        )
    }

    // MARK: - 2. Where You Exceed the Plan

    private var deviationChart: some View {
        chartCard(
            title: L10n.CashFlowPlan.chartDeviation,
            subtitle: L10n.CashFlowPlan.chartDeviationSubtitle,
            kpiValue: nil
        ) {
            if cachedDeviations.isEmpty {
                if cachedPastMonths.count < 2 {
                    needMoreDataView
                } else {
                    allWithinPlanView
                }
            } else {
                let maxTotal = cachedDeviations.map(\.total).max() ?? 1

                VStack(spacing: DS.Spacing.md) {
                    ForEach(cachedDeviations, id: \.lineID) { item in
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: item.iconName)
                                    .font(.system(size: DS.Icon.sizeSmall, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                                    .background(Color(hex: item.colorHex))
                                    .clipShape(Circle())

                                GeometryReader { geo in
                                    let barWidthRatio: CGFloat = 0.55
                                    let barAreaWidth = geo.size.width * barWidthRatio
                                    let totalBarWidth = max(4, barAreaWidth * (item.total / maxTotal))
                                    let planLineX = barAreaWidth * (item.plannedAmount / maxTotal)

                                    HStack(spacing: DS.Spacing.xs) {
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: DS.Radius.xs)
                                                .fill(Color.hotPink.gradient)
                                                .frame(width: totalBarWidth)

                                            // Plan dotted line
                                            Path { path in
                                                path.move(to: CGPoint(x: planLineX, y: 0))
                                                path.addLine(to: CGPoint(x: planLineX, y: geo.size.height))
                                            }
                                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                                            .foregroundStyle(.thPrimaryText.opacity(0.7))
                                        }
                                        .frame(width: totalBarWidth)

                                        Text(YalaFormatter.axisK(item.total) + " (+" + YalaFormatter.axisK(item.deviation) + ")")
                                            .font(DS.Typography.labelTiny)
                                            .foregroundStyle(Color.hotPink)
                                            .fixedSize()
                                    }
                                }
                                .frame(height: DS.Icon.badgeSmall)
                            }

                            Text(item.name + " · Plan: " + YalaFormatter.currency(value: item.plannedAmount, currencyCode: currencyCode))
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.thSecondaryText)
                                .padding(.leading, DS.Icon.badgeSmall + DS.Spacing.sm)
                        }
                    }
                }
            }
        }
    }

    private var deviationCommentCard: some View {
        aiOrRuleComment(
            isLoading: viewModel.isLoadingDeviationComment,
            aiComment: viewModel.deviationComment,
            ruleComment: cachedDeviationRuleComment
        )
    }

    // MARK: - 3. Monthly Savings (Pro) — actual vs planned

    private var savingsChart: some View {
        let pastSavings = cachedSavings.filter(\.isPast)
        let avgSavings = pastSavings.isEmpty ? 0.0
            : pastSavings.map(\.actual).reduce(0, +) / Double(pastSavings.count)

        return chartCard(
            title: L10n.CashFlowPlan.chartSavings,
            subtitle: L10n.CashFlowPlan.chartSavingsSubtitle,
            kpiValue: pastSavings.count >= 2
                ? YalaFormatter.currency(value: avgSavings, currencyCode: currencyCode)
                : nil
        ) {
            if cachedSavings.count < 2 {
                needMoreDataView
            } else {
                let showLabels = cachedSavings.count <= 10

                Chart {
                    ForEach(cachedSavings, id: \.monthKey) { point in
                        if point.isPast {
                            // Past: actual savings bar (teal/hotPink)
                            BarMark(
                                x: .value("Month", point.date, unit: .month),
                                y: .value("Net", point.actual)
                            )
                            .foregroundStyle(
                                point.actual >= 0
                                    ? Color.incomeGraph.gradient
                                    : Color.expenseGraph.gradient
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))

                            // Plan reference tick
                            RuleMark(
                                xStart: .value("Start", point.date, unit: .month),
                                xEnd: .value("End", point.date, unit: .month),
                                y: .value("Plan", point.planned)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 2]))
                            .foregroundStyle(.thPrimaryText.opacity(0.5))
                        } else {
                            // Future: planned savings bar (grey)
                            BarMark(
                                x: .value("Month", point.date, unit: .month),
                                y: .value("Net", point.planned)
                            )
                            .foregroundStyle(Color.gray.opacity(0.3).gradient)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        }

                        // Data labels
                        if showLabels {
                            let displayValue = point.isPast ? point.actual : point.planned
                            PointMark(
                                x: .value("Month", point.date, unit: .month),
                                y: .value("Net", displayValue)
                            )
                            .symbolSize(0)
                            .annotation(
                                position: displayValue >= 0 ? .top : .bottom,
                                spacing: DS.Spacing.xs
                            ) {
                                Text(YalaFormatter.axisK(displayValue))
                                    .font(DS.Typography.labelTiny)
                                    .foregroundStyle(.thSecondaryText)
                            }
                        }
                    }

                    // Zero baseline
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(.thSecondaryText.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                .chartYAxis { barYAxisContent }
                .chartXAxis {
                    AxisMarks(values: savingsAxisLabelDates) { value in
                        AxisGridLine()
                            .foregroundStyle(.thSecondaryText.opacity(0.1))

                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.month(.abbreviated)).lowercased().replacing(".", with: ""))
                                    .font(DS.Typography.labelTiny)
                                    .foregroundStyle(.thSecondaryText)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: - Chart Card Container

    private func chartCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        kpiValue: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                }
                if let kpi = kpiValue {
                    Text(kpi)
                        .font(DS.Typography.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(.thPrimaryText)
                }
            }
            content()
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }

    private var needMoreDataView: some View {
        chartPlaceholder(L10n.CashFlowPlan.chartNeedMoreData)
    }

    private var allWithinPlanView: some View {
        chartPlaceholder(L10n.CashFlowPlan.chartAllWithinPlan)
    }

    private func chartPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 120)
    }

    @ViewBuilder
    private func ruleCommentCard(_ comment: String) -> some View {
        if !comment.isEmpty {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.secondary)
                    .font(DS.Typography.subheadline)
                Text(LocalizedStringKey(comment))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thPrimaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .solidCard()
        }
    }

    // MARK: - Cached Data Builders

    private struct DeviationItem {
        let lineID: UUID
        let name: String
        let plannedAmount: Double
        let deviation: Double
        let iconName: String
        let colorHex: String

        var total: Double { plannedAmount + deviation }
    }

    private static func buildDeviations(
        from pastMonths: [CashFlowMonth],
        iconLookup: [UUID: (iconName: String?, colorHex: String?)]
    ) -> [DeviationItem] {
        guard !pastMonths.isEmpty else { return [] }

        var deviations: [UUID: (name: String, totalDeviation: Double, totalPlanned: Double, count: Int)] = [:]

        for month in pastMonths {
            for line in month.expenseLines {
                guard let real = line.realAmount else { continue }
                let diff = real - line.plannedAmount
                var entry = deviations[line.lineID] ?? (name: line.name, totalDeviation: 0, totalPlanned: 0, count: 0)
                entry.totalDeviation += diff
                entry.totalPlanned += line.plannedAmount
                entry.count += 1
                deviations[line.lineID] = entry
            }
        }

        return deviations
            .map { id, entry in
                let count = Double(max(1, entry.count))
                let icons = iconLookup[id]
                return DeviationItem(
                    lineID: id,
                    name: entry.name,
                    plannedAmount: entry.totalPlanned / count,
                    deviation: entry.totalDeviation / count,
                    iconName: icons?.iconName ?? "creditcard.fill",
                    colorHex: icons?.colorHex ?? "#9CA3AF"
                )
            }
            .filter { $0.deviation > 0 }
            .sorted { $0.deviation > $1.deviation }
    }

    private struct SavingsPoint {
        let monthKey: String
        let date: Date
        let actual: Double
        let planned: Double
        let isPast: Bool
    }

}
