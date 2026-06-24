//
//  DonutChartView.swift
//  Yala
//
//  Donut con leyenda lateral, burbujas de iconos flotantes y líneas conectoras.
//  Gemelo visual del `.large` de `CategoriesPieWidget` (mismo layout y medidas),
//  pero de presentación PURA y read-only: recibe los slices ya calculados y NO
//  conoce selección / dimming / exclude. Si se ajusta el aspecto de uno, replicar
//  en el otro a mano (no comparten código por el riesgo de tocar el widget del Panel).
//

import Charts
import SwiftUI

/// Slice genérico del donut compartido.
struct DonutSlice: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    let amount: Double
    let percentage: Double
    fileprivate var startAngle: Double = 0
    fileprivate var endAngle: Double = 0
    fileprivate var midAngle: Double { (startAngle + endAngle) / 2 }

    // Init explícito: el memberwise sintetizado sería `fileprivate` por los campos de ángulo.
    init(id: String, name: String, iconName: String, colorHex: String, amount: Double, percentage: Double) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.amount = amount
        self.percentage = percentage
    }
}

struct DonutChartView: View {
    let slices: [DonutSlice]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredItem: DonutSlice?

    private let innerRadiusRatio: CGFloat = 0.50

    var body: some View {
        let data = withAngles(slices)
        HStack(alignment: .center, spacing: DS.Spacing.lg) {
            // Chart (2/3) — donut + conectores + burbujas
            GeometryReader { geo in
                let diameter = min(geo.size.width, geo.size.height)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let chartRadius = (diameter / 2) * 0.65

                ZStack {
                    connectorLines(data, center: center, chartRadius: chartRadius)

                    chartView(data)
                        .frame(width: chartRadius * 2, height: chartRadius * 2)
                        .position(center)

                    bubblesLayer(data, center: center, chartRadius: chartRadius)

                    if let hovered = hoveredItem {
                        hoverTooltip(for: hovered).position(center)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // Leyenda (1/3)
            legendList(data)
                .frame(width: 140)
        }
    }

    // MARK: - Angles (12 en punto, sentido horario)

    private func withAngles(_ items: [DonutSlice]) -> [DonutSlice] {
        let total = items.reduce(0) { $0 + $1.amount }
        var currentAngle = -Double.pi / 2
        return items.map { item in
            var copy = item
            let ratio = total > 0 ? item.amount / total : 0
            let sweep = ratio * 2 * Double.pi
            copy.startAngle = currentAngle
            copy.endAngle = currentAngle + sweep
            currentAngle += sweep
            return copy
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private func chartView(_ data: [DonutSlice]) -> some View {
        let safeData = data.filter { $0.amount.isFinite && $0.amount > 0 }
        let totalAmount = safeData.reduce(0) { $0 + $1.amount }
        if safeData.isEmpty || !totalAmount.isFinite || totalAmount <= 0 {
            Color.clear
        } else {
            let angularInset: CGFloat = safeData.count == 1 ? 0 : 1.5
            Chart(safeData) { item in
                SectorMark(
                    angle: .value("Monto", item.amount),
                    innerRadius: .ratio(innerRadiusRatio),
                    angularInset: angularInset
                )
                .cornerRadius(DS.Radius.xs)
                .foregroundStyle(Color(hex: item.colorHex))
            }
            .chartLegend(.hidden)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Connector Lines

    private func connectorLines(_ data: [DonutSlice], center: CGPoint, chartRadius: CGFloat) -> some View {
        Path { path in
            for item in data where shouldShowLabel(item) {
                let angle = item.midAngle
                let startX = center.x + cos(angle) * chartRadius
                let startY = center.y + sin(angle) * chartRadius
                let bubbleDistance = chartRadius + 30.0
                let endX = center.x + cos(angle) * bubbleDistance
                let endY = center.y + sin(angle) * bubbleDistance
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
        }
        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
    }

    // MARK: - Bubbles

    private func bubblesLayer(_ data: [DonutSlice], center: CGPoint, chartRadius: CGFloat) -> some View {
        ZStack {
            ForEach(data) { item in
                bubbleView(for: item, center: center, chartRadius: chartRadius)
            }
        }
    }

    @ViewBuilder
    private func bubbleView(for item: DonutSlice, center: CGPoint, chartRadius: CGFloat) -> some View {
        if shouldShowLabel(item) {
            let angle = item.midAngle
            let bubbleDistance = chartRadius + 30.0
            let iconSize: CGFloat = 32
            let bubbleX = center.x + cos(angle) * bubbleDistance
            let bubbleY = center.y + sin(angle) * bubbleDistance

            ZStack {
                Circle()
                    .fill(Color(hex: item.colorHex))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                    .frame(width: iconSize, height: iconSize)

                Image(systemName: item.iconName)
                    .font(.system(size: 10, weight: .bold)) // A11Y-DT: fixed-layout pie chart icon bubble
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .position(x: bubbleX, y: bubbleY)
            .onLongPressGesture(
                minimumDuration: 0.3,
                pressing: { isPressing in
                    dsWithAnimation(reduceMotion, .easeInOut(duration: 0.15)) {
                        hoveredItem = isPressing ? item : nil
                    }
                }, perform: {})
        }
    }

    private func hoverTooltip(for item: DonutSlice) -> some View {
        Text(item.name)
            .font(DS.Typography.label)
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(Color(hex: item.colorHex))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Legend

    private func legendList(_ data: [DonutSlice]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(data) { item in
                HStack(spacing: DS.Spacing.sm) {
                    Circle()
                        .fill(Color(hex: item.colorHex))
                        .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)

                    Text(item.name)
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(formattedPercentage(item.percentage))
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func shouldShowLabel(_ item: DonutSlice) -> Bool {
        item.percentage > 4.0
    }

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 0
        return f
    }()

    private func formattedPercentage(_ value: Double) -> String {
        Self.percentFormatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}
