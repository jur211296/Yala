//
//  TagsPieWidget.swift
//  Yala
//
//  Widget de pie chart para distribución por etiquetas.
//

import Charts
import SwiftData
import SwiftUI

struct TagsPieWidget: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var scaledEmptyIconSize: CGFloat = 32

    let tags: [TagSpendingSummary]
    let currencyCode: String

    // Filter State
    var selectedTagIDs: Set<PersistentIdentifier> = []
    var onSelectTag: ((PersistentIdentifier) -> Void)?
    var onShowDetail: (() -> Void)? = nil

    var size: WidgetSize = .medium

    // Period Comparison (optional - for use in CategoriesTabView)
    var period: DetailPeriod = .thisMonth
    var customRange: DateInterval? = nil
    var previousTotalAmount: Double? = nil
    var comparisonMode: ComparisonMode = .month
    var showVariationHeader: Bool = false  // Always show variation header (with N/A if no data)

    // Check if variation header should be shown
    private var showComparison: Bool {
        showVariationHeader  // Show header even when previousAmount is nil (displays N/A)
    }

    // Computed Properties
    private var totalExpense: Double {
        tags.reduce(0) { $0 + $1.amount }
    }

    private var filteredTotalExpense: Double {
        guard !selectedTagIDs.isEmpty else { return totalExpense }
        return tags
            .filter { selectedTagIDs.contains($0.tag.persistentModelID) }
            .reduce(0) { $0 + $1.amount }
    }

    private var chartData: [PieChartData] {
        processChartData()
    }

    @State private var selectedAngle: Double?
    @State private var hoveredItem: PieChartData?

    private let innerRadiusRatio: CGFloat = 0.50

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            if chartData.isEmpty {
                emptyState
            } else {
                contentForSize
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.yalaCard)
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
            Image(systemName: "tag.fill")
                .font(.system(size: scaledEmptyIconSize))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(.secondary)
            Text(L10n.Empty.noData)
                .font(DS.Typography.subheadline)
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
        VStack(spacing: DS.Spacing.sm) {
            headerView

            HStack(alignment: .center, spacing: DS.Spacing.lg) {
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
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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
                    dsWithAnimation(reduceMotion, .easeInOut(duration: 0.15)) {
                        hoveredItem = isPressing ? item : nil
                    }
                }, perform: {})
        }
    }

    // MARK: - Hover Tooltip

    private func hoverTooltip(for item: PieChartData) -> some View {
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

    private func shouldShowLabel(for item: PieChartData) -> Bool {
        if !selectedTagIDs.isEmpty {
            guard let id = item.id else { return false }
            return selectedTagIDs.contains(id)
        } else {
            return item.percentage > 4.0
        }
    }

    // MARK: - Medium Layout

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            headerView

            HStack(alignment: .top, spacing: DS.Spacing.none) {
                if !selectedTagIDs.isEmpty,
                    let selectedItem = chartData.first(where: { guard let id = $0.id else { return false }; return selectedTagIDs.contains(id) })
                {
                    Spacer()
                    VStack(alignment: .center, spacing: DS.Spacing.xs) {
                        Text(selectedItem.name)
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(Color(hex: selectedItem.colorHex))
                            .lineLimit(1)

                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedItem.colorHex).opacity(0.15))
                            Image(systemName: selectedItem.iconName)
                                .font(DS.Typography.labelTiny).fontWeight(.bold)
                                .foregroundStyle(Color(hex: selectedItem.colorHex))
                        }
                        .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)

                        Text(
                            "\(formattedPercentage(selectedItem.percentage)) (\(formattedCurrency(selectedItem.amount)))"
                        )
                        .font(DS.Typography.headline)
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
                        VStack(alignment: .center, spacing: DS.Spacing.xs) {
                            Text(item.name)
                                .font(DS.Typography.labelTiny)
                                .foregroundStyle(Color(hex: item.colorHex))
                                .lineLimit(1)

                            ZStack {
                                Circle()
                                    .fill(Color(hex: item.colorHex).opacity(0.15))
                                Image(systemName: item.iconName)
                                    .font(DS.Typography.captionSmall).fontWeight(.bold)
                                    .foregroundStyle(Color(hex: item.colorHex))
                            }
                            .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)

                            Text(formattedPercentage(item.percentage))
                                .font(DS.Typography.label)
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
                let segmentSpacing: CGFloat = DS.Spacing.xxs
                let totalSpacing = segmentSpacing * CGFloat(max(0, chartData.count - 1))
                let availableWidth = geo.size.width - totalSpacing

                HStack(spacing: segmentSpacing) {
                    ForEach(chartData) { item in
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
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
        Group {
            if showComparison {
                HStack(alignment: .top) {
                    PieChartVariationHeader(
                        title: L10n.Widget.distributionByTag,
                        totalAmount: filteredTotalExpense,
                        previousAmount: previousTotalAmount,
                        currencyCode: currencyCode,
                        period: period,
                        customRange: customRange,
                        comparisonMode: comparisonMode,
                        onShowDetail: onShowDetail
                    )

                    InfoHintButton(
                        title: L10n.WidgetType.expensesByNature,
                        message: L10n.Widget.Hint.tagsPie
                    )
                }
            } else {
                // Original header without comparison
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(L10n.Widget.distributionByTag)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .padding(.bottom, DS.Spacing.xxs)

                        Text(formattedCurrency(filteredTotalExpense))
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    InfoHintButton(
                        title: L10n.WidgetType.expensesByNature,
                        message: L10n.Widget.Hint.tagsPie
                    )

                    Spacer()
                    if onShowDetail != nil {
                        Button {
                            onShowDetail?()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(DS.Typography.headline)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
                .cornerRadius(DS.Radius.xs)
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

    private func formattedCurrency(_ value: Double) -> String {
        YalaFormatter.currency(value: value, currencyCode: currencyCode)
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
        guard !selectedTagIDs.isEmpty else { return false }
        guard let id = item.id else { return true }
        return !selectedTagIDs.contains(id)
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
            let othersPercentage = totalExpense > 0 ? (othersAmount / totalExpense) * 100 : 0

            if othersAmount > 0 {
                finalItems.append(
                    PieChartData(
                        id: nil,
                        name: L10n.Common.others,
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
