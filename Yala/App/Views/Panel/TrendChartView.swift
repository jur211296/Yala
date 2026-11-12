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
    /// `true` si el saldo vivo salió de alguna tasa que no era la de hoy. Viaja con el desglose
    /// porque lo consume la misma hoja. Default `false`: un callsite sin saldo vivo no marca nada.
    var liveAnchorIsApproximate: Bool = false
    /// Muestra el marcador "Hoy" (línea vertical) y la pill "Hoy ⓘ". Default
    /// `true` (Panel/Tendencias). Se pasa `false` en históricos sin saldo vivo
    /// (p. ej. la tendencia de un grupo) donde esos indicadores no aplican.
    var showTodayIndicators: Bool = true
    /// Dibuja un `PointMark` visible en cada punto de la serie sólida. Default
    /// `false` (Panel/Tendencias). Útil en series con pocos puntos (meses).
    var showPointMarks: Bool = false
    /// Fechas en las que mostrar la etiqueta de valor sobre el punto (subconjunto
    /// inteligente para no saturar). Default vacío. Usa el formatter puro (sin
    /// `@Environment` → seguro dentro de `.annotation`).
    var dataLabelDates: Set<Date> = []
    /// «Ver proyectado» (card «Flujo proyectado en Tendencias y Panel»): la continuación estimada desde hoy hasta el
    /// final del período, punteada en el color de la métrica. El primer punto es el de hoy. Vacío = sin proyección; con
    /// ella, quien llama pasa la curva real cortada en hoy (los movimientos con fecha futura van en la proyección).
    var projectedPoints: [PanelViewModel.BarPoint] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(AppPreferences.self) private var appPreferences
    /// «Ocultar montos» del Panel (`AmountPrivacy`): ejes, promedio y etiquetas de la gráfica sin cifras; la línea y las
    /// barras se quedan.
    @Environment(\.amountsHidden) private var amountsHidden
    @State private var draggingDate: Date?  // For transient drag state
    @State private var pulseAnimate = false
    @State private var showEducationSheet = false
    /// Ancho de la píldora «Hoy»: con él se mantiene dentro del área de dibujo y no tapa la escala de la derecha
    /// (UX 2.2 · L3-17).
    @State private var todayPillWidth: CGFloat = 0
    /// Ancho de la gráfica: con él se sabe cuánto ocupa cada etiqueta del eje X y cuáles se pisarían (UX 2.2 · L3-17).
    @State private var chartWidth: CGFloat = 0

    /// La hoja «Tu saldo hoy» explica la diferencia por tipo de cambio; sin saldo en otra moneda no
    /// hay ninguna y ni la píldora ni el punto la abren.
    private var explainsCurrencyDifference: Bool {
        LiveAnchorEducationLogic.explainsCurrencyDifference(
            liveAnchorBreakdown, preferredCurrencyCode: currencyCode
        )
    }

    /// Los puntos que se dicen: los reales (sin suavizar) y, con saldo vivo, el de hoy, que es la cifra de la tarjeta.
    private var spokenPoints: [(date: Date, value: Double)] {
        var points = (rawPoints.isEmpty ? trendPoints : rawPoints).map { (date: $0.date, value: $0.value) }
        if let liveAnchor, liveAnchor.date > (points.map(\.date).max() ?? .distantPast) {
            points.append((date: liveAnchor.date, value: liveAnchor.value))
        }
        return points
    }

    private var amountFormat: ChartAmountFormat {
        appPreferences.chartAmountFormat(currencyCode: currencyCode, hidden: amountsHidden)
    }

    /// V1 de la decisión 26 de 2.3: de dónde a dónde fue y el punto más alto o más bajo, con cifras («7 puntos» antes).
    private var spokenSummary: String {
        ChartSpokenSummary.trend(points: spokenPoints, grouping: grouping, format: amountFormat)
    }

    /// V2: la línea para el rotor «Describir gráfica» y el sonido.
    private var chartDescriptor: ChartAccessibilityDescriptor {
        ChartAccessibilityDescriptor(
            title: L10n.Accessibility.trendChart(trendType.displayName),
            summary: spokenSummary,
            xTitle: L10n.Accessibility.Chart.axisDate,
            xAxis: .dates(grouping: grouping),
            yTitle: trendType.displayName,
            series: [.init(name: trendType.displayName, isContinuous: true,
                           points: spokenPoints.map { .at($0.date, $0.value) })],
            format: amountFormat
        )
    }

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

            let yBase = min(max(displayYDomain.lowerBound, 0), displayYDomain.upperBound)

            // Interpolation Logic:
            // Use .monotone to prevent overshoots at extreme points
            // (.catmullRom can cause visual distortion at first/last points)
            let interpolation: InterpolationMethod = .monotone
            let solidLineWidth: CGFloat = compact ? 3 : 2

            // Los rótulos de los ejes, traducidos UNA vez por repintado y no en cada punto: con «Todo» son cientos de
            // puntos y seis búsquedas de `L10n` por punto (2026-10-30, encargo `eficiencia-carga-por-vista`).
            let dateLabel = L10n.Common.date
            let amountLabel = L10n.Common.amount
            let baseLabel = L10n.Common.base

            // Past & Today: Solid Line & Area
            ForEach(pastPoints, id: \.date) { point in
                AreaMark(
                    x: .value(dateLabel, point.date),
                    yStart: .value(baseLabel, yBase),
                    yEnd: .value(amountLabel, point.value)
                )
                .interpolationMethod(interpolation)
                .foregroundStyle(areaGradient.opacity(dimOpacity))

                LineMark(
                    x: .value(dateLabel, point.date),
                    y: .value(amountLabel, point.value)
                )
                .interpolationMethod(interpolation)
                .lineStyle(StrokeStyle(lineWidth: solidLineWidth))
                .foregroundStyle(primaryLineColor.opacity(dimOpacity))

                // DATA ANNOTATIONS FOR WEEK VIEW
                if period == .thisWeek || period == .last7Days {
                    PointMark(
                        x: .value(dateLabel, point.date),
                        y: .value(amountLabel, point.value)
                    )
                    .symbolSize(0)  // Invisible point just for annotation context
                    .annotation(position: .top, spacing: DS.Spacing.xs) {
                        Text(formattedAmountShort(point.value))
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(.thSecondaryText)
                    }
                }

                // Visible markers per point (short series, e.g. group months)
                if showPointMarks {
                    PointMark(
                        x: .value(dateLabel, point.date),
                        y: .value(amountLabel, point.value)
                    )
                    .symbolSize(30)
                    .foregroundStyle(primaryLineColor.opacity(dimOpacity))
                }

                // Value labels on selected dates (smart subset to avoid clutter)
                if dataLabelDates.contains(point.date) {
                    PointMark(
                        x: .value(dateLabel, point.date),
                        y: .value(amountLabel, point.value)
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
                    x: .value(dateLabel, point.date),
                    y: .value(amountLabel, point.value)
                )
                .interpolationMethod(interpolation)
                .lineStyle(StrokeStyle(lineWidth: solidLineWidth, dash: [5, 5]))
                .foregroundStyle(.thSecondaryText)  // Explicit Gray for distinction
            }

            // Proyección: punteada en el color de la métrica, más tenue que la real, y en su propia serie para que no
            // se una a la curva gris de los movimientos futuros (que con la proyección no se pasan).
            ForEach(projectedPoints, id: \.date) { point in
                LineMark(
                    x: .value(dateLabel, point.date),
                    y: .value(amountLabel, point.value),
                    series: .value("Serie", "projected")
                )
                .interpolationMethod(interpolation)
                .lineStyle(StrokeStyle(lineWidth: solidLineWidth, lineCap: .round, dash: [2, 4]))
                .foregroundStyle(primaryLineColor.opacity(0.75 * dimOpacity))
            }
            if let lastProjected = projectedPoints.last, projectedPoints.count > 1, !compact {
                PointMark(
                    x: .value(dateLabel, lastProjected.date),
                    y: .value(amountLabel, lastProjected.value)
                )
                .symbolSize(30)
                .foregroundStyle(primaryLineColor.opacity(0.75 * dimOpacity))
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
                let tooltipAnchorY = displayYDomain.upperBound
                    - (displayYDomain.upperBound - displayYDomain.lowerBound) * 0.35
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
                        // «S/ 65,879» como el resto del Panel, no «65,879 PEN» (decisión 11 de 2.3).
                        Text(tooltipAmount(rawValue))
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(.thPrimaryText)

                        // Average in tooltip: «Promedio S/ 66,287», no «x̄» (decisión 11 de 2.3).
                        if let avg = totalAverageValue {
                            Divider()
                            Text(L10n.Panel.trendAverageLabel(tooltipAmount(avg)))
                                .font(DS.Typography.labelTiny)
                                .foregroundStyle(.thSecondaryText)
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
                        Text(AmountPrivacy.text(YalaFormatter.axisK(doubleValue, domain: displayYDomain), hidden: amountsHidden))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.thSecondaryText)
                            .opacity(labelOpacity)
                    }
                }
            }
        }
        // Y-Axis Scale from ViewModel
        .chartYScale(domain: displayYDomain)
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
        // Una vibración por punto al recorrer la gráfica, no por fotograma del arrastre (card C4).
        .sensoryFeedback(.selection, trigger: scrubbedPointDate) { old, new in new != nil && old != new }
        .chartOverlay { proxy in
            ZStack {
                todayHintPillOverlay(proxy: proxy)
                liveAnchorOverlay(proxy: proxy)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Accessibility.trendChart(trendType.displayName))
        .accessibilityValue(spokenSummary)
        .accessibilityChartDescriptor(chartDescriptor)
        .accessibilityIdentifier("trend_chart")
        .compactChartAxes(compact: compact)
        .frame(height: chartHeight)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chartWidth = $0 }
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
                    liveAnchorIsApproximate: liveAnchorIsApproximate,
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
                // La píldora no sale del área de dibujo: con «hoy» pegado al borde derecho, la mitad caía sobre la
                // etiqueta más alta de la escala («Hoy ⓘ 00K», UX 2.2 · L3-17).
                let halfWidth = todayPillWidth / 2
                let absoluteX = min(max(xPos + frame.origin.x, frame.minX + halfWidth), frame.maxX - halfWidth)
                let absoluteY = frame.origin.y + DS.Spacing.md

                TodayHintGlassPill(action: explainsCurrencyDifference ? { showEducationSheet = true } : nil)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { todayPillWidth = $0 }
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
                // Sin hoja que abrir, VoiceOver no puede prometer «Toca para ver el detalle».
                .accessibilityLabel(
                    explainsCurrencyDifference
                        ? L10n.Panel.LiveAnchorEducation.dotA11yLabel
                        : L10n.Widget.today
                )
                .accessibilityAddTraits(explainsCurrencyDifference ? .isButton : [])
                .coachMarkAnchor("todayFXHint")
                // Sin otra moneda no hay hoja que abrir (B1, lote 3): el punto se dibuja, no se toca.
                .allowsHitTesting(explainsCurrencyDifference)
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
        let effectiveLastDate = max(lastDate, liveAnchor?.date ?? lastDate, projectedPoints.last?.date ?? lastDate)
        let span = effectiveLastDate.timeIntervalSince(firstDate)
        let padding = max(span * 0.05, 86400)  // At least 1 day padding
        return firstDate.addingTimeInterval(-padding)...effectiveLastDate.addingTimeInterval(padding)
    }

    /// El dominio Y que se pinta: el del ViewModel, ensanchado para que quepa la proyección (un saldo que baja de cero a
    /// fin de mes no puede salirse de la gráfica).
    private var displayYDomain: ClosedRange<Double> {
        guard let low = projectedPoints.map(\.value).min(),
              let high = projectedPoints.map(\.value).max() else { return yDomain }
        guard low < yDomain.lowerBound || high > yDomain.upperBound else { return yDomain }
        let lower: Double = min(yDomain.lowerBound, low)
        let upper: Double = max(yDomain.upperBound, high)
        let padding: Double = (upper - lower) * 0.05
        let paddedLower: Double = low < yDomain.lowerBound ? lower - padding : lower
        let paddedUpper: Double = high > yDomain.upperBound ? upper + padding : upper
        return paddedLower...paddedUpper
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

    /// Las fechas que reparten el eje X: las de la curva y, con «Ver proyectado», las de la proyección (sin la de hoy,
    /// que ya está en la curva).
    private var axisDataDates: [Date] {
        guard projectedPoints.count > 1 else { return trendPoints.map(\.date) }
        let last = trendPoints.last?.date ?? .distantPast
        return trendPoints.map(\.date) + projectedPoints.map(\.date).filter { $0 > last }
    }

    /// Axis dates for compact mode: first + last data point only (empty if <2 points).
    private var compactAxisDates: [Date] {
        guard let firstDate = axisDataDates.first,
              let lastDate = axisDataDates.last,
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
            case .year: return .year
            }
        }()

        let rawDates = SmartAxisHelper.calculateSmartAxisDates(
            forDataDates: axisDataDates,
            grouping: calendarUnit
        )

        guard let firstDate = axisDataDates.first,
              let lastDate = axisDataDates.last else { return rawDates }
        let deduplicated = SmartAxisHelper.deduplicatedAxisDates(
            rawDates, firstDate: firstDate, lastDate: lastDate,
            forceGrouping: grouping.forceAxisGrouping)
        // Con «Todo el tiempo» la penúltima fecha caía pegada a la última y se pisaban («abr 26oct 26», UX 2.2 · L3-17).
        // Lo que ocupa una etiqueta sale de su texto más largo (~7,5 pt por carácter a `labelTiny`, medido: «abr 26» son
        // 45 pt) y del ancho del área de dibujo: el medido menos la escala de la derecha (~44 pt).
        guard chartWidth > 0 else { return deduplicated }
        let longest = deduplicated.map { smartAxisLabel(for: $0).count }.max() ?? 0
        let plotWidth = max(1, Double(chartWidth) - (compact ? 0 : 44))
        let fraction = min(0.5, Double(longest) * 7.5 / plotWidth)
        return SmartAxisHelper.droppingCrowdedNeighbors(deduplicated, labelWidthFraction: fraction)
    }

    /// Format axis label based on data span (include year if multiple years)
    private func smartAxisLabel(for date: Date) -> String {
        guard let firstDate = axisDataDates.first,
            let lastDate = axisDataDates.last
        else {
            return formatDayNumber(date)
        }

        return SmartAxisHelper.formatAxisLabel(
            for: date, startDate: firstDate, endDate: lastDate, forceGrouping: grouping.forceAxisGrouping)
    }

    private func formattedAmountShort(_ value: Double) -> String {
        if amountsHidden { return AmountPrivacy.mask }
        let absValue = abs(value)
        let formattedNumber = absValue.formatted(.number.precision(.fractionLength(0)))
        // Lo que se pinta como cero no lleva signo («-0» o «+0» de un saldo que suma cero en coma flotante).
        let shownAsZero = formattedNumber == Double(0).formatted(.number.precision(.fractionLength(0)))

        if value < 0 && !shownAsZero {
            return "-\(formattedNumber)"
        } else if value > 0 && trendType == .balance && !shownAsZero {
            return "+\(formattedNumber)"
        } else {
            return formattedNumber
        }
    }

    private func formatK(_ value: Double) -> String {
        if amountsHidden { return AmountPrivacy.mask }
        let absValue = abs(value)
        let sign = value < 0 && absValue >= 0.5 ? "-" : ""  // «-0» de un residuo de coma flotante: sin signo

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

    /// El punto bajo el dedo mientras se recorre la gráfica: cambia solo al pasar de un punto al siguiente.
    private var scrubbedPointDate: Date? {
        guard let draggingDate else { return nil }
        return closestPoint(to: draggingDate, in: trendPoints)?.date
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

    private static let periodMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        // El año con cuatro cifras: «nov 26» se leía como el día 26 (decisión 11 de la revisión 2.3).
        f.setLocalizedDateFormatFromTemplate("MMMyyyy")
        return f
    }()

    /// Format day as number only (1, 2, 3, etc.)
    private func formatDayNumber(_ date: Date) -> String {
        Self.dayNumberFormatter.string(from: date)
    }

    /// La fecha del globo: «7 nov», con el año (cuatro cifras) solo si no es el de hoy, como el chip de la gráfica.
    private func periodLabel(for date: Date) -> String {
        switch grouping {
        case .day, .week:
            return PanelTrendSummaryLogic.shortDate(date, today: .now, calendar: .current, locale: AppLocale.current)
        case .month:
            return Self.periodMonthFormatter.string(from: date).lowercased().replacing(".", with: "")
        case .year:
            return TrendGrouping.yearLabel(for: date)
        }
    }

    /// La cifra del globo: con el símbolo de la moneda (o su código, si la persona lo eligió así en Ajustes) y sin
    /// decimales. Texto ya resuelto: dentro de un `.annotation` no llega el entorno (`swiftui-ds.md`).
    private func tooltipAmount(_ value: Double) -> String {
        if amountsHidden { return AmountPrivacy.mask }
        return CurrencyFormattingHelper.currency(
            abs(value) < 0.5 ? 0 : value,
            decimals: 0,
            identifier: appPreferences.currencyIdentifier(for: currencyCode),
            forceSign: false,
            isEstimate: false
        )
    }

    private func formattedAmount(_ value: Double) -> String {
        if amountsHidden { return AmountPrivacy.mask }
        // Sin signo para lo que se pinta como cero («-0» de un saldo que suma cero en coma flotante).
        return (abs(value) < 0.5 ? 0 : value).formatted(
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
                    // Con su nombre: sola, «99K» no decía qué era la línea discontinua (UX 2.2 · L3-17).
                    Text(L10n.Panel.trendAverageLabel(formatK(avg)))
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
