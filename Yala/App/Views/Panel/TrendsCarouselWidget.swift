//
//  TrendsCarouselWidget.swift
//  Yala
//
//  Unified Trends widget with 2-page carousel:
//  - Page 1: trend line chart (balance / income / expense)
//  - Page 2: period comparison chart (current vs previous)
//
//  Both pages share a single metric selector that writes to
//  `SessionState.selectedTransactionNatures` — the SSOT that also drives
//  the TrendsTab in Statistics.
//

import Charts
import SwiftData
import SwiftUI

struct TrendsCarouselWidget: View {
    @Bindable var viewModel: PanelViewModel
    @Bindable var sessionState: SessionState
    var currencyCode: String
    var currentBalance: Double
    var size: WidgetSize = .large
    var onShowMore: (() -> Void)? = nil

    /// Botón pedagógico opcional renderizado al lado del título del header.
    /// Cuando `nil` (callsites legacy), no se muestra nada. El wrapper Panel
    /// inyecta un `WidgetInfoButton` aquí para abrir la sheet pedagógica.
    var headerInfoButton: AnyView? = nil

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.amountsHidden) private var amountsHidden
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Días 1 y 2 de «Este mes»: sin comparaciones, solo el monto (decisión 10 de 2.3).
    @Environment(\.hidesPeriodVariations) private var hidesPeriodVariations

    @Namespace private var animationNamespace
    @State private var showFilterBlockedMessage: Bool = false

    // MARK: - Data

    /// Solo lo INCLUIDO («Solo Comida») convierte la vista en gastos; ocultar una categoría no.
    private var hasCategoryFilters: Bool {
        return !sessionState.selectedCategoryIDs.isEmpty
            || !sessionState.selectedSubcategoryIDs.isEmpty
            || !sessionState.selectedNeeds.isEmpty
    }

    private var hasNoTrendData: Bool {
        viewModel.processedTrendPoints.isEmpty
    }

    /// «Ver proyectado» encendido (preferencia compartida con Tendencias) y con algo que enseñar.
    private var isShowingProjection: Bool {
        size != .small && appPreferences.showsProjectedFlow && viewModel.trendProjection != nil
    }

    /// La curva real: con la proyección, cortada en hoy (los movimientos con fecha futura van en la línea punteada).
    private var displayedTrendPoints: [BarPoint] {
        guard isShowingProjection else { return viewModel.processedTrendPoints }
        return ProjectedFlowCalculator.pointsUpToToday(
            viewModel.processedTrendPoints, today: .now, grouping: viewModel.trendGrouping, calendar: .current
        )
    }

    private var displayedRawTrendPoints: [BarPoint] {
        guard isShowingProjection else { return viewModel.rawTrendPoints }
        return ProjectedFlowCalculator.pointsUpToToday(
            viewModel.rawTrendPoints, today: .now, grouping: viewModel.trendGrouping, calendar: .current
        )
    }

    // MARK: - Body

    var body: some View {
        if size == .small {
            smallBody
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header
                if !hasNoTrendData, viewModel.trendProjection != nil {
                    ProjectedFlowToggle(isOn: isShowingProjection) {
                        appPreferences.showsProjectedFlow.toggle()
                    }
                }
                // Más alta en los iPhone grandes, con la misma proporción que en el pequeño (`AdaptiveChartHeight`).
                AdaptiveChartHeight(base: 170) { chartHeight in
                    trendPage(chartHeight: chartHeight)
                        .frame(height: chartHeight)
                }
                startEndRow
                if isShowingProjection, let projection = viewModel.trendProjection {
                    ProjectedFlowCaption(projection: projection, currencyCode: currencyCode)
                }
            }
            // La píldora funde la línea punteada y la cifra (implícita: en el Panel un `withAnimation` no anima).
            .dsAnimation(DS.Animation.appear, value: isShowingProjection, reduceMotion: reduceMotion)
            .panelCard()
        }
    }

    // MARK: - Small layout (PP2-06c)
    // Refleja el filtro global (income/expense/balance) vía `viewModel.trendType`,
    // sincronizado por `enforceTrendLock`. Sin metric-switcher propio — el selector
    // vive en medium/large; aquí seguimos el SSOT de `selectedTransactionNatures`.

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PanelSmallWidgetHeader(
                title: viewModel.trendType.displayName,
                accessibilityLabel: viewModel.trendType.displayName,
                action: onShowMore,
                headerInfoButton: headerInfoButton
            )

            if hasNoTrendData {
                YalaEmptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    title: L10n.Empty.noData,
                    style: .widget
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                AmountText(
                    value: trendTotalForCurrentMetric,
                    currencyCode: currencyCode,
                    font: DS.Typography.headline, secondaryFont: DS.Typography.caption
                )

                TrendChartView(
                    trendPoints: viewModel.processedTrendPoints,
                    rawPoints: viewModel.rawTrendPoints,
                    yDomain: viewModel.processedYDomain,
                    grouping: viewModel.trendGrouping,
                    interval: viewModel.currentInterval,
                    currencyCode: currencyCode,
                    trendType: viewModel.trendType,
                    focusedDate: .constant(nil),   // scrubbing disabled in .small
                    period: viewModel.currentPeriod,
                    chartHeight: 90,
                    compact: true
                )
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panelCard(small: true)
        .frame(height: WidgetSize.smallHeight)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityHeader
        } else {
            regularHeader
        }
    }

    /// Con el texto al máximo, el selector de métrica le quitaba el ancho a la cifra y la elipsis caía en medio
    /// («S/54,5….64», barrido final 2.2): título, cifra y selector, uno debajo del otro.
    private var accessibilityHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Text(viewModel.trendType.displayName)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.thPrimaryText)
                if let headerInfoButton {
                    headerInfoButton
                }
            }

            if !hasNoTrendData {
                AmountText(
                    value: currentKPIValue,
                    currencyCode: currencyCode,
                    font: DS.Typography.title
                )
                .padding(.top, DS.Spacing.xs)

                variationChip
            }

            if !sessionState.isExpensesOnlyMode {
                metricSelector
                    .padding(.top, DS.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var regularHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(viewModel.trendType.displayName)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.thPrimaryText)
                    if let headerInfoButton {
                        headerInfoButton
                    }
                }

                if !hasNoTrendData {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        AmountText(
                            value: currentKPIValue,
                            currencyCode: currencyCode,
                            font: DS.Typography.title
                        )

                        // Variation chip right of the "vs" label.
                        variationChip
                    }
                    .padding(.top, DS.Spacing.xs)
                }
            }

            Spacer()

            if !sessionState.isExpensesOnlyMode {
                metricSelector
            }
        }
    }

    /// Delta % chip rendered inline next to the KPI in regular layouts. Dice contra qué fecha compara («vs 20 oct»,
    /// decisión 11 de 2.3): solo, el «+10.3 %» no decía con qué, y con la línea bajando se leía como un error.
    @ViewBuilder
    private var variationChip: some View {
        let data = viewModel.periodComparisonWidget
        if data.supportsComparison, let delta = data.deltaPercent {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                VariationChip(
                    variation: delta,
                    size: .small,
                    isExpenseContext: data.trendType == .expense
                )
                // El chip se esconde solo (preferencia o mes recién empezado); su «vs» se va con él.
                if appPreferences.showVariations, !hidesPeriodVariations, let date = data.previousReferenceDate {
                    Text(L10n.Panel.trendVersusDate(
                        PanelTrendSummaryLogic.shortDate(date, today: .now, calendar: .current, locale: AppLocale.current)
                    ))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.thSecondaryText)
                    .lineLimit(1)
                    .accessibilityIdentifier("panel_trend_versus_date")
                }
            }
        }
    }

    // MARK: - Inicio y fin (decisión 11 de 2.3, opción B)

    /// Bajo la gráfica de saldo, de dónde partió y dónde está, con el % del cambio: el eje no arranca en cero y la línea
    /// exageraba la caída. Con montos ocultos queda el %; los días 1 y 2 del mes, solo los montos.
    @ViewBuilder
    private var startEndRow: some View {
        if viewModel.dataTrendType == .balance,
           !hasNoTrendData,
           let summary = PanelTrendSummaryLogic.startEnd(
               rawPoints: viewModel.rawTrendPoints,
               liveAnchor: viewModel.trendLiveAnchor,
               today: .now,
               calendar: .current
           ) {
            let startDate = PanelTrendSummaryLogic.shortDate(
                summary.startDate, today: .now, calendar: .current, locale: AppLocale.current)
            let endDate = summary.endIsToday
                ? L10n.Panel.trendToday
                : PanelTrendSummaryLogic.shortDate(summary.endDate, today: .now, calendar: .current, locale: AppLocale.current)
            let variation = hidesPeriodVariations ? nil : summary.variation
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    startEndSide(date: startDate, value: summary.startValue)
                    startEndArrow
                    startEndSide(date: endDate, value: summary.endValue, isEstimate: summary.endIsToday && viewModel.trendLiveAnchorIsApproximate)
                    startEndVariation(variation)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    startEndSide(date: startDate, value: summary.startValue)
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        startEndArrow
                        startEndSide(date: endDate, value: summary.endValue, isEstimate: summary.endIsToday && viewModel.trendLiveAnchorIsApproximate)
                        startEndVariation(variation)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(startEndAccessibilityLabel(summary, startDate: startDate, endDate: endDate, variation: variation))
            .accessibilityIdentifier("panel_trend_start_end")
        }
    }

    private func startEndSide(date: String, value: Double, isEstimate: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
            Text(date)
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
            AmountText(
                value: value,
                currencyCode: currencyCode,
                font: DS.Typography.labelSmall,
                secondaryFont: DS.Typography.captionSmall,
                isEstimate: isEstimate
            )
        }
        .lineLimit(1)
        .fixedSize()
    }

    private var startEndArrow: some View {
        Image(systemName: "arrow.right")
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.thSecondaryText)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func startEndVariation(_ variation: Double?) -> some View {
        if let variation {
            Text("· \(PreviousPeriodHelper.formatVariationValue(variation))")
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.thSecondaryText)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private func startEndAccessibilityLabel(
        _ summary: PanelTrendSummaryLogic.StartEnd, startDate: String, endDate: String, variation: Double?
    ) -> String {
        let amount: (Double) -> String = { value in
            AmountPrivacy.text(appPreferences.currency(value, currencyCode: currencyCode), hidden: amountsHidden)
        }
        let base = L10n.Panel.trendStartEndAccessibility(
            startDate, amount(summary.startValue), endDate, amount(summary.endValue))
        guard let variation else { return base }
        return "\(base). \(VariationChip.accessibilityText(for: variation))"
    }

    // MARK: - Trend chart page

    @ViewBuilder
    private func trendPage(chartHeight: CGFloat) -> some View {
        if hasNoTrendData {
            YalaEmptyState(
                icon: "chart.line.uptrend.xyaxis",
                title: L10n.Empty.noData,
                style: .widget
            )
            .frame(maxWidth: .infinity)
        } else {
            TrendChartView(
                trendPoints: displayedTrendPoints,
                rawPoints: displayedRawTrendPoints,
                yDomain: viewModel.processedYDomain,
                grouping: viewModel.trendGrouping,
                interval: viewModel.currentInterval,
                currencyCode: currencyCode,
                trendType: viewModel.dataTrendType,
                focusedDate: $viewModel.focusedDate,
                period: viewModel.currentPeriod,
                chartHeight: chartHeight,
                liveAnchor: viewModel.trendLiveAnchor,
                liveAnchorBreakdown: viewModel.trendLiveAnchorBreakdown,
                liveAnchorIsApproximate: viewModel.trendLiveAnchorIsApproximate,
                projectedPoints: isShowingProjection ? (viewModel.trendProjection?.points ?? []) : []
            )
        }
    }

    // MARK: - Metric selector (writes to SessionState SSOT)

    private var metricSelector: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(TrendType.allCases) { type in
                metricButton(for: type)
            }
        }
        // El círculo de la métrica elegida se desliza (card C2). Implícita: en el Panel un `withAnimation` no anima.
        .dsAnimation(DS.Animation.selection, value: viewModel.trendType, reduceMotion: reduceMotion)
        .filterBlockedPopover(
            isPresented: $showFilterBlockedMessage,
            title: L10n.Trend.filterBlockedTitle,
            message: L10n.Trend.filterBlockedMessage
        )
    }

    private func metricButton(for type: TrendType) -> some View {
        let isSelected = viewModel.trendType == type
        let isBlocked: Bool = {
            guard hasCategoryFilters else { return false }
            guard let nature = sessionState.activeFilterNature else { return false }
            switch nature {
            case .expense: return type != .expense
            case .income: return type != .income
            }
        }()

        return Button {
            if isBlocked {
                showFilterBlockedMessage = true
            } else {
                switch type {
                case .balance: sessionState.selectedTransactionNatures.removeAll()
                case .income:  sessionState.selectedTransactionNatures = [.income]
                case .expense: sessionState.selectedTransactionNatures = [.expense]
                }
            }
        } label: {
            Image(systemName: type.iconName)
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : (isBlocked ? type.color.opacity(0.4) : type.color))
                .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                .background {
                    if isSelected {
                        Circle()
                            .fill(type.color)
                            .matchedGeometryEffect(id: "metricBg", in: animationNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
    }

    // MARK: - KPI

    private var currentKPIValue: Double {
        if let focusedDate = viewModel.focusedDate,
           let point = viewModel.rawTrendPoints.first(where: {
               Calendar.current.isDate($0.date, inSameDayAs: focusedDate)
           }) {
            return point.value
        }
        return trendTotalForCurrentMetric
    }

    private var trendTotalForCurrentMetric: Double {
        switch viewModel.trendType {
        case .balance: return viewModel.trendFinalBalance
        case .income:  return viewModel.trendTotalIncome
        case .expense: return viewModel.trendTotalExpense
        }
    }

}
