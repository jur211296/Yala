import Charts
import SwiftData
import SwiftUI

struct TrendChartView: View {
    /// Points for chart visualization (may be smoothed)
    let trendPoints: [PanelViewModel.BarPoint]
    /// Original unsmoothed points for tooltip/hover display
    let rawPoints: [PanelViewModel.BarPoint]
    let yDomain: ClosedRange<Double>
    let grouping: TrendGrouping
    let interval: DateInterval
    let currencyCode: String
    let trendType: TrendType
    @Binding var focusedDate: Date?

    let period: DetailPeriod
    var chartHeight: CGFloat = 220
    /// PP2-06c: compact mode for `.small` widget — hides Y-axis, the "today" marker
    /// and caps the X-axis to at most 2 labels (first + last data point).
    var compact: Bool = false
    /// Dot suelto en `Date.now` con saldo vivo (LiveBalanceCalculator). No-nil
    /// solo en métricas de balance cuando el período cubre hoy. Se renderiza
    /// como un PointMark con anillo, sin annotation propia (el `todayMarker`
    /// ya marca el contexto temporal con texto "Hoy"). En compact se omite.
    var liveAnchor: PanelViewModel.BarPoint? = nil
    /// Desglose por moneda nativa del `liveAnchor`. Habilita el sheet
    /// educativo "Tu saldo hoy" en multi-currency. Nil → tap no abre sheet.
    var liveAnchorBreakdown: [String: Decimal]? = nil
    /// Muestra el marcador "Hoy" (línea vertical) y la pill "Hoy ⓘ". Default
    /// `true` (Panel/Tendencias). Se pasa `false` en históricos sin saldo vivo
    /// (p. ej. la tendencia de un grupo) donde esos indicadores no aplican.
    var showTodayIndicators: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(AppPreferences.self) private var appPreferences
    @State private var draggingDate: Date?  // For transient drag state
    @State private var pulseAnimate = false
    @State private var showEducationSheet = false

    var body: some View {
        // Disable animations completely to prevent interpolation between data states
        // This fixes the visual glitch when switching between Balance/Income/Expense
        liquidTrendChart
            .dsAnimation(nil, value: trendPoints.count, reduceMotion: reduceMotion)
    }

    // MARK: - Gráfico Trend (Financial Grid Style)

    private var liquidTrendChart: some View {
        Chart {
            // Colors based on TrendType (Using Semantic Colors from TrendType)
            let primaryLineColor: Color = trendType.color
            let areaStartColor = primaryLineColor.opacity(0.1)
            let areaEndColor = primaryLineColor.opacity(0.05)

            // Dimming Factor: If focusedDate is set, reduce opacity of line/area
            let dimOpacity = focusedDate != nil ? 0.3 : 1.0

            let areaGradient = LinearGradient(
                colors: [areaStartColor, areaEndColor],
                startPoint: .top,
                endPoint: .bottom
            )

            let today = Calendar.current.startOfDay(for: Date.now)
            let calendar = Calendar.current

            // --- USE PROCESSED DATA ---
            let data = trendPoints

            // Split into Past and Future with overlapping connection at 'today'
            let pastPoints = data.filter {
                calendar.compare($0.date, to: today, toGranularity: .day) != .orderedDescending
            }
            let futurePoints = data.filter {
                calendar.compare($0.date, to: today, toGranularity: .day) != .orderedAscending
            }

            let yBase = min(max(yDomain.lowerBound, 0), yDomain.upperBound)

            // Interpolation Logic:
            // Use .monotone to prevent overshoots at extreme points
            // (.catmullRom can cause visual distortion at first/last points)
            let interpolation: InterpolationMethod = .monotone
            let solidLineWidth: CGFloat = compact ? 3 : 2

            // Past & Today: Solid Line & Area
            ForEach(pastPoints, id: \.date) { point in
                AreaMark(
                    x: .value(L10n.Common.date, point.date),
                    yStart: .value(L10n.Common.base, yBase),
                    yEnd: .value(L10n.Common.amount, point.value)
                )
                .interpolationMethod(interpolation)
                .foregroundStyle(areaGradient.opacity(dimOpacity))

                LineMark(
                    x: .value(L10n.Common.date, point.date),
                    y: .value(L10n.Common.amount, point.value)
                )
                .interpolationMethod(interpolation)
                .lineStyle(StrokeStyle(lineWidth: solidLineWidth))
                .foregroundStyle(primaryLineColor.opacity(dimOpacity))

                // DATA ANNOTATIONS FOR WEEK VIEW
                if period == .thisWeek || period == .last7Days {
                    PointMark(
                        x: .value(L10n.Common.date, point.date),
                        y: .value(L10n.Common.amount, point.value)
                    )
                    .symbolSize(0)  // Invisible point just for annotation context
                    .annotation(position: .top, spacing: DS.Spacing.xs) {
                        Text(formattedAmountShort(point.value))
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(.thSecondaryText)
                    }
                }
            }

            // Future: Dashed Line (Overlaps at Today to connect)
            ForEach(futurePoints, id: \.date) { point in
                LineMark(
                    x: .value(L10n.Common.date, point.date),
                    y: .value(L10n.Common.amount, point.value)
                )
                .interpolationMethod(interpolation)
                .lineStyle(StrokeStyle(lineWidth: solidLineWidth, dash: [5, 5]))
                .foregroundStyle(.thSecondaryText)  // Explicit Gray for distinction
            }

            // Single point: LineMark is invisible with 1 point, show a dot instead
            if trendPoints.count == 1, let singlePoint = trendPoints.first {
                PointMark(
                    x: .value(L10n.Common.date, singlePoint.date),
                    y: .value(L10n.Common.amount, singlePoint.value)
                )
                .foregroundStyle(primaryLineColor)
                .symbolSize(64)
            }

            // Marker for "Today" (omitted entirely in compact mode)
            todayMarker(today: today)

            // Dot del saldo vivo en `today` se renderiza FUERA del Chart{} en
            // `.chartOverlay` más abajo — PointMark no soporta animación de
            // scale/opacity para el pulse, ni `.onTapGesture` para abrir el
            // sheet educativo.

            // Average line
            averageLineMarks

            // Interaction: Scrubbing Rule Mark
            if let activeDate = draggingDate ?? focusedDate,
                let selectedPoint = closestPoint(to: activeDate, in: data),
                let rawValue = value(for: activeDate, in: rawPoints)  // Use raw points for actual value
            {
                // Vertical dashed line
                RuleMark(x: .value(L10n.Common.selectedDate, activeDate))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.thSecondaryText)

                // Ring Border (Background) at SMOOTHED position
                PointMark(
                    x: .value(L10n.Common.selectedDate, activeDate),
                    y: .value(L10n.Common.selectedValue, selectedPoint.value)
                )
                .symbolSize(140)
                .foregroundStyle(primaryLineColor)

                // Main Dot (Foreground) at SMOOTHED position
                PointMark(
                    x: .value(L10n.Common.selectedDate, activeDate),
                    y: .value(L10n.Common.selectedValue, selectedPoint.value)
                )
                .symbolSize(100)
                .foregroundStyle(.thCard)

                // Invisible anchor point for tooltip — placed ~35% below the chart top
                // so the bubble doesn't choque con el KPI del header del card (Statistics
                // tab + Panel widget) ni se salga off-canvas.
                let tooltipAnchorY = yDomain.upperBound
                    - (yDomain.upperBound - yDomain.lowerBound) * 0.35
                PointMark(
                    x: .value(L10n.Common.selectedDate, activeDate),
                    y: .value("TooltipAnchor", tooltipAnchorY)
                )
                .symbolSize(0)
                .annotation(
                    position: .top,
                    alignment: tooltipAlignment(for: activeDate)
                ) {
                    VStack(alignment: .center, spacing: DS.Spacing.xs) {
                        Text(periodLabel(for: activeDate))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.thSecondaryText)
                        Text("\(formattedAmount(rawValue)) \(currencyCode)")
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(.thPrimaryText)

                        // Average in tooltip
                        if let avg = totalAverageValue {
                            Divider()
                            HStack {
                                Text("x̄")
                                    .font(DS.Typography.labelTiny)
                                    .foregroundStyle(.thSecondaryText)
                                    .frame(width: 10)
                                Text("\(formattedAmount(avg)) \(currencyCode)")
                                    .font(DS.Typography.labelTiny)
                                    .foregroundStyle(.primary)
                            }
                        }
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
        // Y-Axis: Trailing with minimal gridlines; hidden via opacity in compact mode.
        .chartYAxis {
            let gridOpacity: Double = compact ? 0 : 0.1
            let labelOpacity: Double = compact ? 0 : 1
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.thSecondaryText.opacity(gridOpacity))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatK(doubleValue))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.thSecondaryText)
                            .opacity(labelOpacity)
                    }
                }
            }
        }
        // Y-Axis Scale from ViewModel
        .chartYScale(domain: yDomain)
        // X-Axis Scale from Interval
        .chartXScale(domain: paddedXDomain)
        .chartXAxis {
            // Compact mode caps the X-axis to first + last data labels only.
            let axisValues = compact ? compactAxisDates : smartAxisDates
            let gridOpacity: Double = compact ? 0 : 0.1
            AxisMarks(values: axisValues) { value in
                AxisGridLine()
                    .foregroundStyle(.thSecondaryText.opacity(gridOpacity))

                if let date = value.as(Date.self) {
                    let isLast = date == axisValues.last
                    let isFirst = date == axisValues.first
                    let anchor: UnitPoint = isLast ? .topTrailing : (isFirst ? .topLeading : .top)

                    AxisValueLabel(anchor: anchor) {
                        Text(smartAxisLabel(for: date))
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(.thSecondaryText)
                    }
                }
            }
        }
        .chartXSelection(value: $draggingDate)  // Native iOS 17+ selection - works with scroll
        .chartOverlay { proxy in
            ZStack {
                todayHintPillOverlay(proxy: proxy)
                liveAnchorOverlay(proxy: proxy)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Accessibility.trendChart(trendType.displayName))
        .accessibilityValue(trendPoints.isEmpty ? L10n.Accessibility.noData :
            L10n.Accessibility.dataPoints(trendPoints.count))
        .compactChartAxes(compact: compact)
        .frame(height: chartHeight)
        .onAppear {
            if !reduceMotion { pulseAnimate = true }
        }
        .onDisappear {
            pulseAnimate = false
        }
        .sheet(isPresented: $showEducationSheet) {
            if let breakdown = liveAnchorBreakdown,
               let anchor = liveAnchor {
                BalanceLiveAnchorEducationSheet(
                    liveAnchorValue: anchor.value,
                    historicalValue: rawPoints.last?.value,
                    nativeBalances: breakdown,
                    preferredCurrencyCode: currencyCode
                )
            }
        }
    }

    /// Overlay de la pill "Hoy ⓘ" — vive fuera del `Chart{}` para que el tap
    /// no sea capturado por `.chartXSelection`. Posicionada cerca del top del
    /// plot area, alineada con la línea vertical del `todayMarker`.
    @ViewBuilder
    private func todayHintPillOverlay(proxy: ChartProxy) -> some View {
        let today = Calendar.current.startOfDay(for: Date.now)
        GeometryReader { geo in
            if showTodayIndicators,
               !compact,
               paddedXDomain.contains(today),
               let plotFrame = proxy.plotFrame,
               let xPos = proxy.position(forX: today)
            {
                let frame = geo[plotFrame]
                let absoluteX = xPos + frame.origin.x
                let absoluteY = frame.origin.y + DS.Spacing.md

                TodayHintGlassPill { showEducationSheet = true }
                    .position(x: absoluteX, y: absoluteY)
            }
        }
    }

    /// Overlay del dot "Hoy" — ring fino + halo pulsante + tap area amplia.
    /// Vive fuera del `Chart{}` porque PointMark no soporta animaciones de
    /// scale/opacity ni gestos de tap. La posición se calcula vía ChartProxy.
    @ViewBuilder
    private func liveAnchorOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            if let anchor = liveAnchor,
               !compact,
               paddedXDomain.contains(anchor.date),
               let plotFrame = proxy.plotFrame,
               let xPos = proxy.position(forX: anchor.date),
               let yPos = proxy.position(forY: anchor.value)
            {
                let frame = geo[plotFrame]
                let absoluteX = xPos + frame.origin.x
                let absoluteY = yPos + frame.origin.y

                ZStack {
                    // Halo pulsante (escala 1.0→1.3, opacity 0.25→0)
                    Circle()
                        .fill(trendType.color)
                        .frame(width: 18, height: 18)
                        .scaleEffect(pulseAnimate ? 1.3 : 1.0)
                        .opacity(pulseAnimate ? 0.0 : 0.25)
                        .animation(
                            reduceMotion ? nil :
                                .easeInOut(duration: 1.4)
                                .repeatForever(autoreverses: false),
                            value: pulseAnimate
                        )

                    // Ring exterior fino
                    Circle()
                        .stroke(trendType.color, lineWidth: 1.5)
                        .frame(width: 10, height: 10)

                    // Centro hueco (color del card)
                    Circle()
                        .fill(.thCard)
                        .frame(width: 7, height: 7)
                }
                .frame(width: 48, height: 48)
                .contentShape(Circle())
                .position(x: absoluteX, y: absoluteY)
                .onTapGesture { showEducationSheet = true }
                .accessibilityElement()
                .accessibilityLabel(L10n.Panel.LiveAnchorEducation.dotA11yLabel)
                .accessibilityAddTraits(.isButton)
                .coachMarkAnchor("todayFXHint")
                .allowsHitTesting(true)
            }
        }
    }

    // Padded X Domain Logic - Use actual data range when available
    private var paddedXDomain: ClosedRange<Date> {
        // Use actual data range if available
        guard let firstDate = trendPoints.first?.date,
            let lastDate = trendPoints.last?.date
        else {
            // Fallback to interval if no data
            let span = interval.end.timeIntervalSince(interval.start)
            let padding = span * 0.05
            return interval.start.addingTimeInterval(
                -padding)...interval.end.addingTimeInterval(padding)
        }

        // Extender hasta liveAnchor.date si cae fuera del rango de datos (caso
        // típico: última tx hace varios días pero el período cubre hoy). Esto
        // beneficia también al `todayMarker` que verifica `paddedXDomain.contains(today)`.
        let effectiveLastDate = max(lastDate, liveAnchor?.date ?? lastDate)
        let span = effectiveLastDate.timeIntervalSince(firstDate)
        let padding = max(span * 0.05, 86400)  // At least 1 day padding
        return firstDate.addingTimeInterval(-padding)...effectiveLastDate.addingTimeInterval(padding)
    }

    // MARK: - Smart Axis Labels

    /// Today marker — omitted when `compact` OR when `today` falls outside the
    /// chart's X-axis range (no point rendering a marker the user can't see).
    /// La pill "Hoy ⓘ" vive en `chartOverlay` (no en annotation interna del
    /// `Chart{}`) porque `.chartXSelection` captura los taps del área del
    /// plot antes de que lleguen a las annotations — el overlay se procesa
    /// en una capa por encima del selection gesture.
    @ChartContentBuilder
    private func todayMarker(today: Date) -> some ChartContent {
        if showTodayIndicators && !compact && paddedXDomain.contains(today) {
            RuleMark(x: .value(L10n.Widget.today, today))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .foregroundStyle(.thSecondaryText.opacity(0.5))
        }
    }

    /// Axis dates for compact mode: first + last data point only (empty if <2 points).
    private var compactAxisDates: [Date] {
        guard let firstDate = trendPoints.first?.date,
              let lastDate = trendPoints.last?.date,
              firstDate != lastDate
        else { return trendPoints.first.map { [$0.date] } ?? [] }
        return [firstDate, lastDate]
    }

    /// Calculate smart axis dates aligned with actual data points
    private var smartAxisDates: [Date] {
        let calendarUnit: Calendar.Component = {
            switch grouping {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            }
        }()

        let rawDates = SmartAxisHelper.calculateSmartAxisDates(
            forDataDates: trendPoints.map(\.date),
            grouping: calendarUnit
        )

        guard let firstDate = trendPoints.first?.date,
              let lastDate = trendPoints.last?.date else { return rawDates }
        return SmartAxisHelper.deduplicatedAxisDates(
            rawDates, firstDate: firstDate, lastDate: lastDate,
            forceGrouping: grouping.forceAxisGrouping)
    }

    /// Format axis label based on data span (include year if multiple years)
    private func smartAxisLabel(for date: Date) -> String {
        guard let firstDate = trendPoints.first?.date,
            let lastDate = trendPoints.last?.date
        else {
            return formatDayNumber(date)
        }

        return SmartAxisHelper.formatAxisLabel(
            for: date, startDate: firstDate, endDate: lastDate, forceGrouping: grouping.forceAxisGrouping)
    }

    private func formattedAmountShort(_ value: Double) -> String {
        let absValue = abs(value)
        let formattedNumber = absValue.formatted(.number.precision(.fractionLength(0)))

        if value < 0 {
            return "-\(formattedNumber)"
        } else if value > 0 && trendType == .balance {
            return "+\(formattedNumber)"
        } else {
            return formattedNumber
        }
    }

    private func formatK(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""

        if absValue >= 1000 {
            let kValue = absValue / 1000.0
            return String(format: "%@%.0fK", sign, kValue)
        } else {
            return String(format: "%@%.0f", sign, absValue)
        }
    }

    private func value(for date: Date, in data: [PanelViewModel.BarPoint]) -> Double? {
        data.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })?.value
    }

    private func closestPoint(to date: Date, in data: [PanelViewModel.BarPoint]) -> PanelViewModel
        .BarPoint?
    {
        return data.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    // MARK: - Utilidades de escala

    /// Safe tooltip alignment based on date position in interval
    private func tooltipAlignment(for date: Date) -> Alignment {
        // Calculate position as percentage of interval
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

    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private static let periodDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "d MMM yy"
        return f
    }()

    private static let periodMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "MMM yy"
        return f
    }()

    /// Format day as number only (1, 2, 3, etc.)
    private func formatDayNumber(_ date: Date) -> String {
        Self.dayNumberFormatter.string(from: date)
    }

    private func periodLabel(for date: Date) -> String {
        let formatter: DateFormatter
        switch grouping {
        case .day, .week: formatter = Self.periodDayFormatter
        case .month: formatter = Self.periodMonthFormatter
        }
        return formatter.string(from: date).lowercased().replacing(".", with: "")
    }

    private func formattedAmount(_ value: Double) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(0))
        )
    }

    // MARK: - Average Line (balance only, always total — no segmented for line charts)

    /// Total average of raw point values (nil when off or not balance)
    private var totalAverageValue: Double? {
        guard trendType == .balance, appPreferences.averageLineMode >= 1, rawPoints.count >= 2 else { return nil }
        let sum = rawPoints.reduce(0.0) { $0 + $1.value }
        return sum / Double(rawPoints.count)
    }

    @ChartContentBuilder
    private var averageLineMarks: some ChartContent {
        if let avg = totalAverageValue {
            RuleMark(y: .value("Avg", avg))
                .foregroundStyle(.thSecondaryText.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text(formatK(avg))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thSecondaryText)
                }
        }
    }
}

// MARK: - Compact chart modifier

private extension View {
    /// Hides the Y axis when `compact` so the plot area fills the card edge-to-edge.
    /// The X axis remains (first + last labels) — that's configured inside `TrendChartView`.
    @ViewBuilder
    func compactChartAxes(compact: Bool) -> some View {
        if compact {
            self.chartYAxis(.hidden)
        } else {
            self
        }
    }
}
