//
//  TagsPieWidget.swift
//  Neto
//
//  Widget de pie chart para distribución por etiquetas.
//

import Charts
import SwiftData
import SwiftUI

struct TagsPieWidget: View {
    let tags: [TagSpendingSummary]
    let currencyCode: String

    // Filter State
    var selectedTagID: PersistentIdentifier?
    var onSelectTag: ((PersistentIdentifier) -> Void)?
    var onShowDetail: (() -> Void)? = nil

    var size: WidgetSize = .medium

    // Computed Properties
    private var totalExpense: Double {
        tags.reduce(0) { $0 + $1.amount }
    }

    private var filteredTotalExpense: Double {
        if let selectedID = selectedTagID,
            let selectedTag = tags.first(where: { $0.tag.persistentModelID == selectedID })
        {
            return selectedTag.amount
        }
        return totalExpense
    }

    private var chartData: [PieChartData] {
        processChartData()
    }

    @State private var selectedAngle: Double?
    @State private var hoveredItem: PieChartData?

    private let innerRadiusRatio: CGFloat = 0.50

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if chartData.isEmpty {
                emptyState
            } else {
                contentForSize
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "tag")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(L10n.Empty.noData)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content Switcher

    @ViewBuilder
    private var contentForSize: some View {
        switch size {
        case .medium:
            mediumLayout
        case .large:
            largeLayout
        }
    }

    // MARK: - Layouts

    private var largeLayout: some View {
        VStack(spacing: 8) {
            headerView
                .padding(.horizontal, 0)

            HStack(alignment: .center, spacing: 16) {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let diameter = min(width, height)
                    let radius = diameter / 2
                    let center = CGPoint(x: width / 2, y: height / 2)
                    let chartRadius = radius * 0.65

                    ZStack {
                        connectorLines(center: center, chartRadius: chartRadius)

                        chartView(innerRadiusRatio: innerRadiusRatio)
                            .frame(width: chartRadius * 2, height: chartRadius * 2)
                            .position(center)

                        bubblesLayer(center: center, chartRadius: chartRadius)

                        if let hovered = hoveredItem {
                            hoverTooltip(for: hovered)
                                .position(center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                simpleLegendList
                    .frame(width: 140)
            }
        }
        .padding(.top, DS.Spacing.lg)
    }

    private var simpleLegendList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chartData) { item in
                simpleLegendRow(for: item)
            }
        }
    }

    private func simpleLegendRow(for item: PieChartData) -> some View {
        let isDimmedItem = isDimmed(item)

        return Button {
            handleTap(item)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: item.colorHex))
                    .frame(width: 8, height: 8)

                Text(item.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text(formattedPercentage(item.percentage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .opacity(isDimmedItem ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Connector Lines

    private func connectorLines(center: CGPoint, chartRadius: CGFloat) -> some View {
        Path { path in
            for item in chartData {
                if shouldShowLabel(for: item) {
                    let angle = item.midAngle
                    let startX = center.x + cos(angle) * chartRadius
                    let startY = center.y + sin(angle) * chartRadius
                    let offset: CGFloat = size == .large ? 30.0 : 20.0
                    let bubbleDistance = chartRadius + offset
                    let endX = center.x + cos(angle) * bubbleDistance
                    let endY = center.y + sin(angle) * bubbleDistance

                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
            }
        }
        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
    }

    // MARK: - Bubbles Layer

    private func bubblesLayer(center: CGPoint, chartRadius: CGFloat) -> some View {
        ZStack {
            ForEach(Array(chartData.enumerated()), id: \.element.identity) { _, item in
                bubbleView(for: item, center: center, chartRadius: chartRadius)
            }
        }
    }

    @ViewBuilder
    private func bubbleView(for item: PieChartData, center: CGPoint, chartRadius: CGFloat)
        -> some View
    {
        if shouldShowLabel(for: item) {
            let angle = item.midAngle
            let offset: CGFloat = size == .large ? 30.0 : 20.0
            let bubbleDistance = chartRadius + offset
            let iconSize: CGFloat = size == .large ? 32 : 24
            let fontSize: CGFloat = size == .large ? 10 : 8

            let bubbleX = center.x + cos(angle) * bubbleDistance
            let bubbleY = center.y + sin(angle) * bubbleDistance

            ZStack {
                Circle()
                    .fill(Color(hex: item.colorHex))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                    .frame(width: iconSize, height: iconSize)

                Image(systemName: item.iconName)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.white)
            }
            .position(x: bubbleX, y: bubbleY)
            .onTapGesture {
                handleTap(item)
            }
            .onLongPressGesture(
                minimumDuration: 0.3,
                pressing: { isPressing in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoveredItem = isPressing ? item : nil
                    }
                }, perform: {})
        }
    }

    // MARK: - Hover Tooltip

    private func hoverTooltip(for item: PieChartData) -> some View {
        Text(item.name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: item.colorHex))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func shouldShowLabel(for item: PieChartData) -> Bool {
        if let selectedID = selectedTagID {
            return item.id == selectedID
        } else {
            return item.percentage > 4.0
        }
    }

    // MARK: - Medium Layout

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            headerView

            HStack(alignment: .top, spacing: 0) {
                if let selectedID = selectedTagID,
                    let selectedItem = chartData.first(where: { $0.id == selectedID })
                {
                    Spacer()
                    VStack(alignment: .center, spacing: 4) {
                        Text(selectedItem.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: selectedItem.colorHex))
                            .lineLimit(1)

                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedItem.colorHex).opacity(0.15))
                            Image(systemName: selectedItem.iconName)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: selectedItem.colorHex))
                        }
                        .frame(width: 32, height: 32)

                        Text(
                            "\(formattedPercentage(selectedItem.percentage)) (\(formattedAmountCompact(selectedItem.amount)))"
                        )
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let id = selectedItem.id {
                            onSelectTag?(id)
                        }
                    }
                    Spacer()
                } else {
                    ForEach(Array(chartData.prefix(3).enumerated()), id: \.element.identity) {
                        _, item in
                        VStack(alignment: .center, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color(hex: item.colorHex))
                                .lineLimit(1)

                            ZStack {
                                Circle()
                                    .fill(Color(hex: item.colorHex).opacity(0.15))
                                Image(systemName: item.iconName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: item.colorHex))
                            }
                            .frame(width: 24, height: 24)

                            Text(formattedPercentage(item.percentage))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let id = item.id {
                                onSelectTag?(id)
                            }
                        }
                    }
                }
            }

            GeometryReader { geo in
                let segmentSpacing: CGFloat = 2
                let totalSpacing = segmentSpacing * CGFloat(max(0, chartData.count - 1))
                let availableWidth = geo.size.width - totalSpacing

                HStack(spacing: segmentSpacing) {
                    ForEach(chartData) { item in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: item.colorHex))
                            .frame(width: availableWidth * CGFloat(item.percentage / 100))
                            .opacity(isDimmed(item) ? 0.3 : 1.0)
                            .onTapGesture {
                                handleTap(item)
                            }
                    }
                }
            }
            .frame(height: 28)
        }
        .padding(.top, DS.Spacing.lg)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Widget.distributionByTag)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 2)

                Text(formattedCurrency(filteredTotalExpense))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            if onShowDetail != nil {
                Button {
                    onShowDetail?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Color.gray.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Chart View

    @ViewBuilder
    private func chartView(innerRadiusRatio: CGFloat) -> some View {
        let safeData = chartData.filter { $0.amount.isFinite && $0.amount > 0 }
        let totalAmount = safeData.reduce(0) { $0 + $1.amount }

        if safeData.isEmpty || !totalAmount.isFinite || totalAmount <= 0 {
            Color.clear
        } else {
            let dataHash = safeData.map { "\($0.id?.hashValue ?? 0)-\($0.amount)" }.joined()

            Chart(safeData) { item in
                SectorMark(
                    angle: .value("Gasto", item.amount),
                    innerRadius: .ratio(innerRadiusRatio),
                    angularInset: 1.5
                )
                .cornerRadius(5)
                .foregroundStyle(Color(hex: item.colorHex))
                .opacity(isDimmed(item) ? 0.3 : 1.0)
            }
            .id(dataHash)
            .chartLegend(.hidden)
            .chartAngleSelection(value: $selectedAngle)
            .animation(nil, value: dataHash)
            .onChange(of: selectedAngle) {
                if let angle = selectedAngle {
                    selectTag(at: angle)
                    selectedAngle = nil
                }
            }
        }
    }

    // MARK: - Helpers

    private func formattedAmountCompact(_ value: Double) -> String {
        NetoFormatter.currency(value: value, currencyCode: currencyCode)
    }

    private func formattedCurrency(_ value: Double) -> String {
        NetoFormatter.currency(value: value, currencyCode: currencyCode)
    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }

    private func selectTag(at angle: Double) {
        var currentSum: Double = 0
        for item in chartData {
            let nextSum = currentSum + item.amount
            if angle >= currentSum && angle <= nextSum {
                handleTap(item)
                return
            }
            currentSum = nextSum
        }
    }

    private func handleTap(_ item: PieChartData) {
        if let id = item.id {
            onSelectTag?(id)
        }
    }

    private func isDimmed(_ item: PieChartData) -> Bool {
        guard let selected = selectedTagID else { return false }
        return item.id != selected
    }

    // MARK: - Data Processing

    struct PieChartData: Identifiable {
        let id: PersistentIdentifier?
        let name: String
        let iconName: String
        let amount: Double
        let percentage: Double
        let colorHex: String
        fileprivate var startAngle: Double = 0
        fileprivate var endAngle: Double = 0

        var midAngle: Double {
            (startAngle + endAngle) / 2
        }

        var identity: String {
            id?.hashValue.description ?? name
        }
    }

    private func processChartData() -> [PieChartData] {
        let threshold = size == .large ? 12 : 20
        let validTags = tags

        var finalItems: [PieChartData] = []

        if validTags.count <= threshold {
            finalItems = validTags.map {
                PieChartData(
                    id: $0.tag.persistentModelID,
                    name: $0.tag.name,
                    iconName: $0.tag.iconName,
                    amount: $0.amount,
                    percentage: $0.percentage,
                    colorHex: $0.tag.colorHex
                )
            }
        } else {
            let top = validTags.prefix(threshold)
            let others = validTags.dropFirst(threshold)

            finalItems = top.map {
                PieChartData(
                    id: $0.tag.persistentModelID,
                    name: $0.tag.name,
                    iconName: $0.tag.iconName,
                    amount: $0.amount,
                    percentage: $0.percentage,
                    colorHex: $0.tag.colorHex
                )
            }

            let othersAmount = others.reduce(0) { $0 + $1.amount }
            let othersPercentage = (othersAmount / totalExpense) * 100

            if othersAmount > 0 {
                finalItems.append(
                    PieChartData(
                        id: nil,
                        name: "Otros",
                        iconName: "ellipsis.circle.fill",
                        amount: othersAmount,
                        percentage: othersPercentage,
                        colorHex: "#8E8E93"
                    ))
            }
        }

        var currentAngle: Double = -Double.pi / 2
        var result: [PieChartData] = []
        let total = finalItems.reduce(0) { $0 + $1.amount }

        for var item in finalItems {
            let ratio = total > 0 ? item.amount / total : 0
            let sweep = ratio * 2 * Double.pi

            item.startAngle = currentAngle
            item.endAngle = currentAngle + sweep
            result.append(item)
            currentAngle += sweep
        }

        return result
    }
}
