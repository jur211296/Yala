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
    let tags: [TagSpendingSummary]
    let currencyCode: String

    // Filter State
    var selectedTagIDs: Set<PersistentIdentifier> = []
    var onSelectTag: ((PersistentIdentifier) -> Void)?
    var onShowDetail: (() -> Void)? = nil
    var isExcludeMode: Bool = false

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
        if isExcludeMode {
            return tags
                .filter { !selectedTagIDs.contains($0.tag.persistentModelID) }
                .reduce(0) { $0 + $1.amount }
        }
        return tags
            .filter { selectedTagIDs.contains($0.tag.persistentModelID) }
            .reduce(0) { $0 + $1.amount }
    }

    @State private var selectedAngle: Double?
    @State private var hoveredItem: PieChartData?

    /// Ancho medido de la barra segmentada — observado con onGeometryChange (no causa reflow).
    /// Reemplaza GeometryReader para permitir el widget tanto en fullWidth como halfWidthPair.
    @State private var segmentedBarWidth: CGFloat = 0

    private let innerRadiusRatio: CGFloat = 0.50

    var body: some View {
        let chartData = processChartData()
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            if chartData.isEmpty {
                emptyState
            } else {
                contentForSize(chartData)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320, maxHeight: .infinity, alignment: .topLeading)
        .solidCard(radius: DS.Radius.xl)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            HStack {
                Text(L10n.Widget.distributionByTag)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                InfoHintButton(
                    title: L10n.WidgetType.expensesByTag,
                    message: L10n.Widget.Hint.tagsPie
                )

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)

            YalaEmptyState(icon: "tag.fill", title: L10n.Empty.noData, style: .widget)
        }
    }

    // MARK: - Content Switcher

    @ViewBuilder
    private func contentForSize(_ chartData: [PieChartData]) -> some View {
        switch size {
        case .medium:
            mediumLayout(chartData)
        case .large:
            largeLayout(chartData)
        }
    }

    // MARK: - Layouts

    private func largeLayout(_ chartData: [PieChartData]) -> some View {
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
                        connectorLines(chartData, center: center, chartRadius: chartRadius)

                        chartView(chartData, innerRadiusRatio: innerRadiusRatio)
                            .frame(width: chartRadius * 2, height: chartRadius * 2)
                            .position(center)

                        bubblesLayer(chartData, center: center, chartRadius: chartRadius)

                        if let hovered = hoveredItem {
                            hoverTooltip(for: hovered)
                                .position(center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                simpleLegendList(chartData)
                    .frame(width: 140)
            }
        }
        .padding(.top, DS.Spacing.lg)
    }

    private func simpleLegendList(_ chartData: [PieChartData]) -> some View {
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

    private func connectorLines(_ chartData: [PieChartData], center: CGPoint, chartRadius: CGFloat) -> some View {
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

    private func bubblesLayer(_ chartData: [PieChartData], center: CGPoint, chartRadius: CGFloat) -> some View {
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
                    .font(.system(size: fontSize, weight: .bold)) // A11Y-DT: fixed-layout pie chart icon bubble
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
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
        if isExcludeMode {
            // Excluded items already removed; show labels by percentage threshold
            return item.percentage > 4.0
        }
        if !selectedTagIDs.isEmpty {
            guard let id = item.id else { return false }
            return selectedTagIDs.contains(id)
        } else {
            return item.percentage > 4.0
        }
    }

    // MARK: - Medium Layout

    private func mediumLayout(_ chartData: [PieChartData]) -> some View {
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
                                .accessibilityHidden(true)
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
                                    .accessibilityHidden(true)
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

            segmentedBar(chartData: chartData)
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
                        title: L10n.WidgetType.expensesByTag,
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
                        title: L10n.WidgetType.expensesByTag,
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
                        .accessibilityLabel(L10n.Accessibility.viewDetails)
                    }
                }
            }
        }
    }

    // MARK: - Chart View

    @ViewBuilder
    private func chartView(_ chartData: [PieChartData], innerRadiusRatio: CGFloat) -> some View {
        let safeData = chartData.filter { $0.amount.isFinite && $0.amount > 0 }
        let totalAmount = safeData.reduce(0) { $0 + $1.amount }

        if safeData.isEmpty || !totalAmount.isFinite || totalAmount <= 0 {
            Color.clear
        } else {
            let dataHash = safeData.map { "\($0.id?.hashValue ?? 0)-\($0.amount)" }.joined()
            let angularInset: CGFloat = safeData.count == 1 ? 0 : 1.5

            Chart(safeData) { item in
                SectorMark(
                    angle: .value("Gasto", item.amount),
                    innerRadius: .ratio(innerRadiusRatio),
                    angularInset: angularInset
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
                    selectTag(in: chartData, at: angle)
                    selectedAngle = nil
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.Accessibility.tagPieChart)
            .accessibilityValue(safeData.isEmpty ? L10n.Accessibility.noData :
                L10n.Accessibility.tagsCount(safeData.count, formattedCurrency(safeData.reduce(0) { $0 + $1.amount })))
        }
    }

    // MARK: - Helpers

    private func formattedCurrency(_ value: Double) -> String {
        YalaFormatter.currency(value: value, currencyCode: currencyCode)
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

    private func selectTag(in chartData: [PieChartData], at angle: Double) {
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
        // In exclude mode, excluded items are already removed — no dimming needed
        if isExcludeMode { return false }
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

        // In exclude mode, remove excluded items entirely
        let visibleTags: [TagSpendingSummary]
        if isExcludeMode && !selectedTagIDs.isEmpty {
            visibleTags = tags.filter { !selectedTagIDs.contains($0.tag.persistentModelID) }
        } else {
            visibleTags = tags
        }

        // Recalculate total from visible items
        let visibleTotal = visibleTags.reduce(0) { $0 + $1.amount }

        var finalItems: [PieChartData] = []

        if visibleTags.count <= threshold {
            finalItems = visibleTags.map {
                let pct = visibleTotal > 0 ? ($0.amount / visibleTotal) * 100 : 0
                return PieChartData(
                    id: $0.tag.persistentModelID,
                    name: $0.tag.name,
                    iconName: $0.tag.iconName,
                    amount: $0.amount,
                    percentage: pct,
                    colorHex: $0.tag.colorHex
                )
            }
        } else {
            let top = visibleTags.prefix(threshold)
            let others = visibleTags.dropFirst(threshold)

            finalItems = top.map {
                let pct = visibleTotal > 0 ? ($0.amount / visibleTotal) * 100 : 0
                return PieChartData(
                    id: $0.tag.persistentModelID,
                    name: $0.tag.name,
                    iconName: $0.tag.iconName,
                    amount: $0.amount,
                    percentage: pct,
                    colorHex: $0.tag.colorHex
                )
            }

            let othersAmount = others.reduce(0) { $0 + $1.amount }
            let othersPercentage = visibleTotal > 0 ? (othersAmount / visibleTotal) * 100 : 0

            if othersAmount > 0 {
                finalItems.append(
                    PieChartData(
                        id: nil,
                        name: L10n.Common.others,
                        iconName: "ellipsis.circle.fill",
                        amount: othersAmount,
                        percentage: othersPercentage,
                        colorHex: AppConstants.othersColorHex
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

    /// Barra segmentada con ancho medido vía `onGeometryChange` — reemplaza `GeometryReader`
    /// para evitar reflow loops durante scroll vertical y permitir el widget en halfWidthPair.
    @ViewBuilder
    private func segmentedBar(chartData: [PieChartData]) -> some View {
        let segmentSpacing: CGFloat = DS.Spacing.xxs
        let totalSpacing = segmentSpacing * CGFloat(max(0, chartData.count - 1))
        let availableWidth = max(0, segmentedBarWidth - totalSpacing)

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
        .frame(height: 28)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { newWidth in
            segmentedBarWidth = newWidth
        }
    }
}
