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

    /// Pide y enseña las frases de IA. Exige Pro: la preferencia del chip sobrevive al fin de la suscripción.
    private var isAIEnabled: Bool {
        CashFlowAICommentGate.isEnabled(
            toggleOn: appPreferences.cashFlowAIEnabled,
            consentAccepted: appPreferences.aiInsightsConsentAccepted,
            isPro: isPro
        )
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
            // Excepción a «una hoja nunca es `.panel`» (2026-10-30, card bvpn): las tarjetas de gráficas son `panelCard`,
            // translúcidas en los temas oscuros, y sobre el fondo plano de una hoja salían grises; sobre el degradado
            // salen como las de Tendencias y las del Flujo de caja de debajo («el fondo de las cards es gris», Jürgen).
            .yalaScreenBackground(.panel)
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
        .insightsConsentAlert(isPresented: $showInsightsConsentAlert) {
            appPreferences.cashFlowAIEnabled = true
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
            .padding(.vertical, DS.Spacing.xxs)
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
            subtitle: projectionPeriodText,
            kpiLabel: projection.months.last(where: { $0.accumulatedBalance != nil }).map {
                L10n.UXL18.projectionKPI(CashFlowMonthSummaryLogic.monthName($0.date))
            },
            kpiValue: appPreferences.currency(projection.months.last(where: { $0.accumulatedBalance != nil })?.accumulatedBalance ?? 0, currencyCode: currencyCode)
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

                // Today marker, con su «Hoy» como la tarjeta de Tendencias.
                RuleMark(x: .value("Today", today))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .foregroundStyle(.thSecondaryText.opacity(0.5))
                    .annotation(position: .top, alignment: .center) {
                        Text(L10n.Widget.today)
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(.thSecondaryText)
                    }

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
                            // `.annotation` no propaga environment objects — AmountText (lee
                            // @Environment(AppPreferences.self)) dispara SIGTRAP aquí. Text pre-resuelto.
                            Text(appPreferences.currency(selectedBalance, currencyCode: currencyCode))
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.primary)
                            Divider()
                            Text(appPreferences.currency(selectedMonth.netFlow, currencyCode: currencyCode, forceSign: true))
                                .font(DS.Typography.labelTiny)
                                .foregroundStyle(.secondary)
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
            .modifier(AdaptiveChartFrame(base: 220))
        }
    }

    // MARK: - AI Chip Toggle

    private var aiChipLabel: some View {
        HStack(spacing: DS.Chip.spacing) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
            Text(L10n.CashFlowPlan.aiChipLabel)
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
        }
        .foregroundStyle(isAIEnabled ? AnyShapeStyle(theme.onAccent) : AnyShapeStyle(.thSecondaryText))
        .padding(.horizontal, DS.Chip.paddingH)
        .padding(.vertical, DS.Chip.paddingV)
        .background {
            Capsule()
                .fill(isAIEnabled ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.thSecondaryText.opacity(0.08)))
        }
        .overlay(
            Capsule()
                .stroke(isAIEnabled ? theme.accent.opacity(0.3) : .clear, lineWidth: 1)
        )
    }

    private var aiChip: some View {
        Button {
            if isPro {
                if appPreferences.aiInsightsConsentAccepted {
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
                    .foregroundStyle(theme.accentText)
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
                    .foregroundStyle(theme.accentText)
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
            subtitle: cachedPastMonths.isEmpty
                ? L10n.CashFlowPlan.chartDeviationSubtitle
                : L10n.UXL18.deviationPeriod(rangeText(cachedPastMonths.map(\.date))),
            kpiValue: nil
        ) {
            if cachedDeviations.isEmpty {
                if cachedPastMonths.count < 2 {
                    needMoreDataView
                } else {
                    allWithinPlanView
                }
            } else {
                // Lienzo «Una sola Yala» (6A): cada línea con la fila de Presupuestos, y no barras rosas sueltas.
                // Son promedios por mes de los meses que ya pasaron (L18-12): el subtítulo lo dice.
                VStack(spacing: DS.Spacing.md) {
                    ForEach(cachedDeviations, id: \.lineID) { item in
                        deviationRow(item)
                    }
                }
            }
        }
    }

    private func deviationRow(_ item: DeviationItem) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: item.iconName)
                    .font(DS.Typography.label)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(hex: item.colorHex)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(item.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thPrimaryText)
                        .lineLimit(1)
                    Text(L10n.UXL18.deviationLine(
                        appPreferences.currency(item.total, currencyCode: currencyCode),
                        appPreferences.currency(item.plannedAmount, currencyCode: currencyCode)
                    ))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                Spacer(minLength: DS.Spacing.sm)
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    Text(L10n.UXL9.overLabel)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(Color.overBudgetText)
                    Text(appPreferences.currency(item.deviation, currencyCode: currencyCode))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            BudgetProgressBar(percentage: 100, color: "", isExceeded: true, simplified: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cashflow_chart_deviation_row")
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
            kpiLabel: pastSavings.count >= 2
                ? L10n.UXL18.savingsKPI(pastSavings.count, rangeText(pastSavings.map(\.date)))
                : nil,
            kpiValue: pastSavings.count >= 2
                ? appPreferences.currency(avgSavings, currencyCode: currencyCode)
                : nil
        ) {
            if cachedSavings.count < 2 {
                needMoreDataView
            } else {
                let showLabels = cachedSavings.count <= 10

                Chart {
                    // Past: actual savings bars + plan reference tick
                    ForEach(cachedSavings.filter(\.isPast), id: \.monthKey) { point in
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
                    }

                    // Future: planned savings bars (grey)
                    ForEach(cachedSavings.filter { !$0.isPast }, id: \.monthKey) { point in
                        BarMark(
                            x: .value("Month", point.date, unit: .month),
                            y: .value("Net", point.planned)
                        )
                        .foregroundStyle(theme.secondaryText.opacity(0.3).gradient)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                    }

                    // Data labels (past = actual, future = planned)
                    ForEach(showLabels ? cachedSavings : [], id: \.monthKey) { point in
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
                .modifier(AdaptiveChartFrame(base: 180))
            }
        }
    }

    // MARK: - Chart Card Container

    private func chartCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        kpiLabel: String? = nil,
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
                        .fixedSize(horizontal: false, vertical: true)
                }
                // L18-12: la cifra dice de qué es («Saldo a fin de febrero», «Promedio de 3 meses…»).
                if let kpiLabel, kpiValue != nil {
                    Text(kpiLabel)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .padding(.top, DS.Spacing.xs)
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
        // La tarjeta de las gráficas de Tendencias (lienzo «Una sola Yala», 6A).
        .panelCard()
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
            // El aviso de la app (lienzo «Una sola Yala»): icono en su círculo y el texto al lado.
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "lightbulb.fill")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(theme.accentText)
                    .frame(width: 32, height: 32)
                    .background(theme.accent.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                Text(LocalizedStringKey(comment))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.lg)
        }
    }

    // MARK: - Períodos (L18-12)

    /// «De agosto a febrero de 2027»: del primer al último mes con saldo.
    private var projectionPeriodText: String {
        let dates = projection.months.filter { $0.accumulatedBalance != nil }.map(\.date)
        return dates.count >= 2 ? rangeText(dates) : L10n.CashFlowPlan.chartProjectionSubtitle
    }

    /// Del primer al último mes de `dates`.
    private func rangeText(_ dates: [Date]) -> String {
        guard let first = dates.min(), let last = dates.max() else { return "" }
        return L10n.UXL18.periodRange(
            CashFlowMonthSummaryLogic.monthName(first),
            CashFlowMonthSummaryLogic.monthName(last)
        )
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
                    // A11Y-DM: gris neutro fallback cuando la línea aún no tiene color propio
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

/// El alto adaptable de las gráficas de Tendencias (`AdaptiveChartHeight`), como modificador.
private struct AdaptiveChartFrame: ViewModifier {
    let base: CGFloat

    func body(content: Content) -> some View {
        AdaptiveChartHeight(base: base) { height in
            content.frame(height: height)
        }
    }
}
