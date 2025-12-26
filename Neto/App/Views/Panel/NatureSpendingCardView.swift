//
//  NatureSpendingCardView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Charts
import SwiftUI

struct NatureSpendingCardView: View {
    let trendPoints: [NatureTrendPoint]
    let selectedNature: SubcategoryNature?
    let currencyCode: String
    let size: TopSpendingCardView.CardSize  // Reusing comparable size enum or WidgetSize
    let grouping: TrendGrouping
    let onSelectNature: (SubcategoryNature) -> Void

    // View State
    @State private var showingDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gastos por naturaleza")
                        .font(.headline)
                        .foregroundStyle(Color.netoPrimaryText)

                    // Total amount summary or Period subtitle
                    // "Este mes", etc. logic is usually outside, but here we can sum
                    let total = trendPoints.reduce(0) { $0 + $1.total }
                    Text(
                        NetoFormatter.currency(
                            value: total, currencyCode: currencyCode)
                    )
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.netoPrimaryText)
                }

                Spacer()

                // Navigation / Detail
                Button {
                    showingDetail = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Color.secondary.opacity(0.7))
                }
                .padding(.top, 4)
            }

            // Content
            if trendPoints.isEmpty {
                Spacer()
                Text("No hay gastos registrados para este periodo y filtros.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                chartView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.large)
                .fill(Color.netoCard)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        // Detail Navigation
        .navigationDestination(isPresented: $showingDetail) {
            // Placeholder for Detail View
            Text("Detalle de Naturaleza (Próximamente)")
        }
    }

    @ViewBuilder
    private var chartView: some View {
        if size == .large {
            // Large: Chart + Legend (legend handles filtering)
            VStack(spacing: 16) {
                NatureTrendChartView(
                    points: trendPoints, selectedNature: selectedNature, currencyCode: currencyCode,
                    grouping: grouping,
                    onSelectNature: nil  // Legend handles it
                )
                .frame(height: 200)

                NatureLegendView(
                    points: trendPoints, selectedNature: selectedNature, onSelect: onSelectNature)
            }
        } else {
            // Medium: Compact Chart + Mini Legend (bars handle filtering)
            VStack(spacing: 8) {
                NatureTrendChartView(
                    points: trendPoints, selectedNature: selectedNature, currencyCode: currencyCode,
                    grouping: grouping,
                    onSelectNature: onSelectNature  // Chart bars handle it
                )

                // Mini Legend
                CompactNatureLegendView(selectedNature: selectedNature, onSelect: onSelectNature)
            }
        }
    }

    // formattedAmount removed

}

struct NatureTrendChartView: View {
    let points: [NatureTrendPoint]
    let selectedNature: SubcategoryNature?
    let currencyCode: String
    let grouping: TrendGrouping
    let onSelectNature: ((SubcategoryNature) -> Void)?
    @State private var selectedDate: Date?

    // Flattened data struct for the chart
    struct ChartItem: Identifiable {
        let id = UUID()
        let date: Date
        let nature: SubcategoryNature
        let amount: Double
    }

    var body: some View {
        let data = flattenData(points)
        let chartUnit = mapGroupingToUnit(grouping)

        Chart(data) { item in
            BarMark(
                x: .value("Fecha", item.date, unit: chartUnit),
                y: .value("Monto", item.amount)
            )
            .foregroundStyle(item.nature.color.gradient)
            .cornerRadius(4)
        }
        .chartForegroundStyleScale([
            "Esencial": Color.electricIndigo,
            "Prioritaria": Color.priorityNature,
            "Opcional": Color.hotPink,
            "Sin clasificación": Color.gray,
        ])
        .chartLegend(.hidden)
        // X-Axis: Logic matching TrendChartView
        .chartXAxis {
            if grouping == .month {  // "This Year" (Year view) -> Months
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.netoSecondaryText.opacity(0.1))
                    if value.as(Date.self) != nil {
                        AxisValueLabel(
                            format: .dateTime.month(.abbreviated).locale(Locale(identifier: "es"))
                        )
                        .font(.caption2.bold())
                        .foregroundStyle(Color.netoSecondaryText)
                    }
                }
            } else if grouping == .week {  // "This Month" (Month view) -> Weeks/Days?
                // User request: "si es 'Este mes' los ejes son semanas"
                // TrendGrouping.week usually means the data is grouped by week.
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.netoSecondaryText.opacity(0.1))
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatDate(date, grouping: grouping))
                                .font(.caption2.bold())
                                .foregroundStyle(Color.netoSecondaryText)
                        }
                    }
                }
            } else {  // "This Week" -> Days
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.netoSecondaryText.opacity(0.1))
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.day().locale(Locale(identifier: "es")))
                                .font(.caption2.bold())
                                .foregroundStyle(Color.netoSecondaryText)
                        }
                    }
                }
            }
        }
        // Y-Axis: Right (Trailing), grid dashed, limited count
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(dash: [5, 5]))
                    .foregroundStyle(Color.netoSecondaryText.opacity(0.2))
                if let amount = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatAxisAmount(amount))
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
                    // 1. Gesture Handler - Long Press for Hover, Tap for Filter
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            LongPressGesture(minimumDuration: 0.3)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onChanged { value in
                                    switch value {
                                    case .second(true, let drag):
                                        guard let drag = drag else { return }
                                        let x = drag.location.x - plotFrame.origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            let granularity: Calendar.Component =
                                                grouping == .month
                                                ? .month
                                                : (grouping == .week ? .weekOfYear : .day)

                                            if let match = points.first(where: {
                                                Calendar.current.isDate(
                                                    $0.date, equalTo: date,
                                                    toGranularity: granularity)
                                            }) {
                                                self.selectedDate = match.date
                                            }
                                        }
                                    default:
                                        break
                                    }
                                }
                                .onEnded { _ in
                                    self.selectedDate = nil
                                }
                        )
                        .simultaneousGesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    // Disabled in Large mode (legend handles it)
                                    guard let onSelectNature = onSelectNature else { return }

                                    // Get tap location relative to plot
                                    let tapX = value.location.x - plotFrame.origin.x
                                    let tapY = value.location.y - plotFrame.origin.y

                                    // 1. Find which date was tapped
                                    guard let date: Date = proxy.value(atX: tapX) else { return }
                                    let granularity: Calendar.Component =
                                        grouping == .month
                                        ? .month : (grouping == .week ? .weekOfYear : .day)

                                    guard
                                        let dataPoint = points.first(where: {
                                            Calendar.current.isDate(
                                                $0.date, equalTo: date, toGranularity: granularity)
                                        })
                                    else { return }

                                    // 2. Detect which segment was tapped based on Y position
                                    // Stacked bars stack from bottom, so we calculate from bottom up
                                    let total = dataPoint.total
                                    guard total > 0 else { return }

                                    // Get Y range for the chart (inverted: 0 at top, max at bottom in SwiftUI)
                                    let chartHeight = plotFrame.height

                                    // Calculate proportional Y position (0 = bottom, 1 = top of data range)
                                    // In SwiftUI Charts, Y=0 is at bottom of chart
                                    let yRatio = 1.0 - (tapY / chartHeight)  // Invert: tap at bottom = ratio 0
                                    let tappedValue = yRatio * total  // Approximate value at tap point

                                    // Determine segment based on stacking order (bottom to top):
                                    // Essential -> Priority -> Optional -> Unclassified
                                    var cumulativeHeight: Double = 0
                                    var tappedNature: SubcategoryNature? = nil

                                    if dataPoint.essential > 0 {
                                        cumulativeHeight += dataPoint.essential
                                        if tappedValue <= cumulativeHeight {
                                            tappedNature = .essential
                                        }
                                    }
                                    if tappedNature == nil && dataPoint.priority > 0 {
                                        cumulativeHeight += dataPoint.priority
                                        if tappedValue <= cumulativeHeight {
                                            tappedNature = .priority
                                        }
                                    }
                                    if tappedNature == nil && dataPoint.optional > 0 {
                                        cumulativeHeight += dataPoint.optional
                                        if tappedValue <= cumulativeHeight {
                                            tappedNature = .optional
                                        }
                                    }
                                    if tappedNature == nil && dataPoint.unclassified > 0 {
                                        tappedNature = .unclassified
                                    }

                                    if let nature = tappedNature {
                                        onSelectNature(nature)
                                    }
                                }
                        )

                    // 2. Hover Visuals (Line + Tooltip)
                    if let selectedDate = selectedDate,
                        let selectedData = points.first(where: {
                            Calendar.current.isDate(
                                $0.date, equalTo: selectedDate,
                                toGranularity: grouping == .month
                                    ? .month : (grouping == .week ? .weekOfYear : .day))
                        }),
                        let xPos = proxy.position(forX: selectedData.date)
                    {
                        // Vertical Line
                        Rectangle()
                            .fill(Color.netoSecondaryText.opacity(0.3))
                            .frame(width: 1, height: plotFrame.height)
                            .position(x: xPos + plotFrame.origin.x, y: plotFrame.midY)

                        // Tooltip Card
                        VStack(spacing: 6) {
                            Text(formatDateFull(selectedData.date, grouping: grouping))
                                .font(.caption2)
                                .foregroundStyle(Color.netoSecondaryText)

                            VStack(alignment: .leading, spacing: 4) {
                                if selectedData.essential > 0 {
                                    TooltipRow(
                                        nature: .essential, amount: selectedData.essential,
                                        currencyCode: currencyCode)
                                }
                                if selectedData.priority > 0 {
                                    TooltipRow(
                                        nature: .priority, amount: selectedData.priority,
                                        currencyCode: currencyCode)
                                }
                                if selectedData.optional > 0 {
                                    TooltipRow(
                                        nature: .optional, amount: selectedData.optional,
                                        currencyCode: currencyCode)
                                }
                                if selectedData.unclassified > 0 {
                                    TooltipRow(
                                        nature: .unclassified, amount: selectedData.unclassified,
                                        currencyCode: currencyCode)
                                }
                                Divider()
                                HStack {
                                    Text("Total")
                                        .font(.caption2)
                                        .foregroundStyle(Color.secondary)
                                    Spacer()
                                    Text(formatAxisAmount(selectedData.total))
                                        .font(.caption2.bold())
                                        .foregroundStyle(Color.primary)
                                }
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                                .fill(Color.netoCard)
                                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                        )
                        .fixedSize()
                        .position(
                            x: max(80, min(xPos + plotFrame.origin.x, geo.size.width - 80)),
                            y: 40  // Fixed Y position near top of chart
                        )
                    }
                }
            }
        }
    }

    private func formatDateFull(_ date: Date, grouping: TrendGrouping) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        switch grouping {
        case .day: formatter.dateFormat = "EEEE d MMM, yyyy"
        case .week: formatter.dateFormat = "'Semana del' d MMM"
        case .month: formatter.dateFormat = "MMMM yyyy"
        }
        return formatter.string(from: date)
    }

    struct TooltipRow: View {
        let nature: SubcategoryNature
        let amount: Double
        let currencyCode: String

        var body: some View {
            HStack {
                Circle().fill(nature.color).frame(width: 6, height: 6)
                Text(nature.displayName)
                    .font(.caption2)
                    .foregroundStyle(Color.primary)
                Spacer()
                // Simple formatting for tooltip
                Text(NetoFormatter.currency(value: amount, currencyCode: currencyCode, decimals: 0))
                    .font(.caption2.bold())
                    .foregroundStyle(Color.primary)
            }
        }
    }

    private func mapGroupingToUnit(_ grouping: TrendGrouping) -> Calendar.Component {
        switch grouping {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }

    private func formatDate(_ date: Date, grouping: TrendGrouping) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        switch grouping {
        case .day: formatter.dateFormat = "d"
        case .week: formatter.dateFormat = "d MMM"
        case .month: formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }

    private func flattenData(_ points: [NatureTrendPoint]) -> [ChartItem] {
        var items: [ChartItem] = []
        for point in points {
            // Add all natures
            if shouldShow(.essential) {
                items.append(
                    ChartItem(date: point.date, nature: .essential, amount: point.essential))
            }
            if shouldShow(.priority) {
                items.append(ChartItem(date: point.date, nature: .priority, amount: point.priority))
            }
            if shouldShow(.optional) {
                items.append(ChartItem(date: point.date, nature: .optional, amount: point.optional))
            }
            if shouldShow(.unclassified) {  // Only show if > 0 or if logic requires?
                items.append(
                    ChartItem(date: point.date, nature: .unclassified, amount: point.unclassified))
            }
        }
        return items
    }

    private func shouldShow(_ nature: SubcategoryNature) -> Bool {
        if let selected = selectedNature {
            return selected == nature
        }
        return true
    }

    private func formatAxisAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if value >= 1000 {
            let kValue = value / 1000
            return formatter.string(from: NSNumber(value: kValue))! + "k"
        }
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }
}

struct NatureLegendView: View {
    let points: [NatureTrendPoint]
    let selectedNature: SubcategoryNature?
    let onSelect: (SubcategoryNature) -> Void

    var body: some View {
        // Horizontal Grid or Flex
        let essentials = points.reduce(0) { $0 + $1.essential }
        let priorities = points.reduce(0) { $0 + $1.priority }
        let optionals = points.reduce(0) { $0 + $1.optional }
        let unclassified = points.reduce(0) { $0 + $1.unclassified }
        let total = essentials + priorities + optionals + unclassified

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            LegendItem(
                nature: .essential, amount: essentials, total: total,
                isSelected: selectedNature == .essential || selectedNature == nil,
                onTap: { onSelect(.essential) })
            LegendItem(
                nature: .priority, amount: priorities, total: total,
                isSelected: selectedNature == .priority || selectedNature == nil,
                onTap: { onSelect(.priority) })
            LegendItem(
                nature: .optional, amount: optionals, total: total,
                isSelected: selectedNature == .optional || selectedNature == nil,
                onTap: { onSelect(.optional) })
            if unclassified > 0 {
                LegendItem(
                    nature: .unclassified, amount: unclassified, total: total,
                    isSelected: selectedNature == .unclassified || selectedNature == nil,
                    onTap: { onSelect(.unclassified) })
            }
        }
    }
}

struct LegendItem: View {
    let nature: SubcategoryNature
    let amount: Double
    let total: Double
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(extensionColor(for: nature))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 0) {
                    Text(nature.displayName)
                        .font(.caption)
                        .foregroundStyle(Color.primary)

                    Text("\(formattedPercent(amount, total))")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
            }
            .padding(8)
            .background(isSelected ? Color.netoBackground : Color.clear)
            .cornerRadius(8)
            .opacity(isSelected ? 1.0 : 0.4)
        }
    }

    private func extensionColor(for nature: SubcategoryNature) -> Color {
        switch nature {
        case .essential: return .electricIndigo
        case .priority: return .priorityNature
        case .optional: return .hotPink
        case .unclassified: return .gray
        }
    }

    private func formattedPercent(_ value: Double, _ total: Double) -> String {
        guard total > 0 else { return "0%" }
        let pct = value / total
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: pct)) ?? "0%"
    }
}

// MARK: - Compact Mini Legend for Medium Size

struct CompactNatureLegendView: View {
    let selectedNature: SubcategoryNature?
    let onSelect: (SubcategoryNature) -> Void

    private let allNatures: [SubcategoryNature] = [.essential, .priority, .optional, .unclassified]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(allNatures, id: \.self) { nature in
                Button {
                    onSelect(nature)
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(nature.color)
                            .frame(width: 8, height: 8)

                        Text(nature.displayName)
                            .font(.caption2)
                            .foregroundStyle(Color.primary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected(nature) ? nature.color.opacity(0.15) : Color.clear)
                    )
                    .opacity(isActiveOrNoFilter(nature) ? 1.0 : 0.4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isSelected(_ nature: SubcategoryNature) -> Bool {
        selectedNature == nature
    }

    private func isActiveOrNoFilter(_ nature: SubcategoryNature) -> Bool {
        selectedNature == nil || selectedNature == nature
    }
}

// Extension to map nature to color in View
extension SubcategoryNature {
    var color: Color {
        switch self {
        case .essential: return .electricIndigo
        case .priority: return .priorityNature
        case .optional: return .hotPink
        case .unclassified: return .gray
        }
    }
}
