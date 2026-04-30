//
//  CategoriesPieWidget.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Charts
import SwiftData
import SwiftUI

struct CategoriesPieWidget: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences
    let categories: [CategorySpendingSummary]
    let currencyCode: String

    // Filter State
    var selectedCategoryIDs: Set<PersistentIdentifier> = []
    var onSelectCategory: ((PersistentIdentifier) -> Void)?
    var onShowDetail: (() -> Void)? = nil
    var isExcludeMode: Bool = false

    var size: WidgetSize = .medium

    /// Slot pedagógico opcional inyectado en el header (Panel Polish #2). Si está
    /// presente, reemplaza al `InfoHintButton` legacy.
    var headerInfoButton: AnyView? = nil

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
        categories.reduce(0) { $0 + $1.amount }
    }

    // Filtered total based on selected categories
    private var filteredTotalExpense: Double {
        guard !selectedCategoryIDs.isEmpty else { return totalExpense }
        if isExcludeMode {
            // Excluded items removed — total is sum of remaining visible items
            return categories
                .filter { !selectedCategoryIDs.contains($0.category.persistentModelID) }
                .reduce(0) { $0 + $1.amount }
        }
        return categories
            .filter { selectedCategoryIDs.contains($0.category.persistentModelID) }
            .reduce(0) { $0 + $1.amount }
    }

    // Chart Selection State - Internal tracking for chart interaction
    @State private var selectedAngle: Double?

    // Hover State - For long-press tooltip
    @State private var hoveredItem: PieChartData?

    /// Ancho medido de la barra segmentada — reemplaza GeometryReader para soportar halfWidthPair.
    @State private var segmentedBarWidth: CGFloat = 0

    // Configuration Constants
    private let innerRadiusRatio: CGFloat = 0.50
    // Relative to the Chart's frame radius (half of smaller dimension)
    // We'll calculate exact pixels in GeometryReader

    var body: some View {
        let chartData = processChartData()
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            // Guard against empty chartData (Charts framework crashes on empty array)
            if chartData.isEmpty {
                if size == .small {
                    smallEmptyState
                } else {
                    emptyState
                }
            } else {
                contentForSize(chartData)
                    .padding(.horizontal, size == .small ? DS.Spacing.md : DS.Spacing.lg)
                    .padding(.bottom, size == .small ? DS.Spacing.md : DS.Spacing.xxl)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: size == .small ? 0 : 320,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .solidCard(radius: DS.Radius.xl)
        .frame(height: size == .small ? WidgetSize.smallHeight : nil)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            // Header (same as content)
            HStack(spacing: DS.Spacing.xs) {
                Text(L10n.Widget.categories)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let headerInfoButton {
                    headerInfoButton
                } else {
                    InfoHintButton(
                        title: L10n.WidgetType.categoriesPie,
                        message: L10n.Widget.Hint.categoriesPie
                    )
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)

            // Empty content
            YalaEmptyState(icon: "folder.fill", title: L10n.Empty.noExpenses, style: .widget)
        }
    }

    // MARK: - Content Switcher

    @ViewBuilder
    private func contentForSize(_ chartData: [PieChartData]) -> some View {
        switch size {
        case .small:
            smallLayout(chartData)
        case .medium:
            mediumLayout(chartData)
        case .large:
            largeLayout(chartData)
        }
    }

    // MARK: - Layouts

    /// Layout compacto para el tamaño `.small` (PP2-05).
    /// El donut central es decorativo (`.allowsHitTesting(false)`); las bubbles conservan
    /// su tap de `largeLayout` y filtran por categoría. El chevron del header navega
    /// a Estadísticas → Distribución.
    private func smallLayout(_ chartData: [PieChartData]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            PanelSmallWidgetHeader(
                title: L10n.Widget.categories,
                accessibilityLabel: L10n.Panel.seeMoreInDistribution,
                action: onShowDetail,
                headerInfoButton: headerInfoButton
            )

            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let diameter = min(width, height)
                let radius = diameter / 2
                let center = CGPoint(x: width / 2, y: height / 2)
                // Radio menor al large (0.65) para dejar espacio a las bubbles alrededor.
                let chartRadius = radius * 0.55

                ZStack {
                    connectorLines(chartData, center: center, chartRadius: chartRadius)

                    chartView(chartData, innerRadiusRatio: innerRadiusRatio)
                        .frame(width: chartRadius * 2, height: chartRadius * 2)
                        .position(center)
                        .allowsHitTesting(false)

                    bubblesLayer(chartData, center: center, chartRadius: chartRadius)
                }
            }
        }
        .padding(.top, DS.Spacing.lg)
    }

    /// PP2-05: empty state compacto para `.small`. Evita `YalaEmptyState(style: .widget)`
    /// que desborda el alto fijo de 140pt.
    private var smallEmptyState: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Text(L10n.WidgetType.categoriesPie)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Image(systemName: "chart.pie")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.md)
    }

    private func largeLayout(_ chartData: [PieChartData]) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            // Header
            headerView

            // Chart (2/3) on left, Legend (1/3) on right
            HStack(alignment: .center, spacing: DS.Spacing.lg) {
                // Left: Original Chart with connector lines and bubbles (2/3 width)
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let diameter = min(width, height)
                    let radius = diameter / 2
                    let center = CGPoint(x: width / 2, y: height / 2)
                    let chartRadius = radius * 0.65

                    ZStack {
                        // 1. Connector Lines Layer (Behind Chart)
                        connectorLines(chartData, center: center, chartRadius: chartRadius)

                        // 2. The Chart Itself
                        chartView(chartData, innerRadiusRatio: innerRadiusRatio)
                            .frame(width: chartRadius * 2, height: chartRadius * 2)
                            .position(center)

                        // 3. Floating Bubbles & Labels Layer
                        bubblesLayer(chartData, center: center, chartRadius: chartRadius)

                        // 4. Hover Tooltip (on top)
                        if let hovered = hoveredItem {
                            hoverTooltip(for: hovered)
                                .position(center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Right: Simple Legend List (1/3 width)
                simpleLegendList(chartData)
                    .frame(width: 140)
            }
        }
        .padding(.top, DS.Spacing.lg)
    }

    // MARK: - Simple Legend List for Large Layout

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
                // Color dot
                Circle()
                    .fill(Color(hex: item.colorHex))
                    .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)

                // Category name
                Text(item.name)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                // Percentage
                Text(formattedPercentage(item.percentage))
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
            .opacity(isDimmedItem ? 0.4 : 1.0)
            .dsAnimation(.easeInOut(duration: 0.2), value: selectedCategoryIDs, reduceMotion: reduceMotion)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Connector Lines

    private func connectorLines(_ chartData: [PieChartData], center: CGPoint, chartRadius: CGFloat) -> some View {
        Path { path in
            for item in chartData {
                // Logic: Only show line if visible (threshold) AND (no selection OR selected)
                // Actually user said: "If I click a segment, ONLY that label appears, others disappear".
                // So lines should also follow this visibility logic.
                if shouldShowLabel(for: item) {
                    let angle = item.midAngle

                    // Line Start: Edge of the pie slice
                    let startX = center.x + cos(angle) * chartRadius
                    let startY = center.y + sin(angle) * chartRadius

                    // Line End: Center of the bubble icon
                    // Bubble is pushed out by some distance.
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

    // MARK: - Bubbles & Labels Layer

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

    // Logic: In exclude mode, excluded items are removed — show labels normally by percentage.
    // In include mode, show only selected items' labels.
    private func shouldShowLabel(for item: PieChartData) -> Bool {
        if isExcludeMode {
            // Excluded items already removed from data; show labels by percentage threshold
            return item.percentage > 4.0
        }
        if !selectedCategoryIDs.isEmpty {
            guard let id = item.id else { return false }
            return selectedCategoryIDs.contains(id)
        } else {
            return item.percentage > 4.0
        }
    }

    // MARK: - Medium Layout (Focus Bar Chart)

    private func mediumLayout(_ chartData: [PieChartData]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            headerView

            // 1. Category Labels
            HStack(alignment: .top, spacing: DS.Spacing.none) {
                if !selectedCategoryIDs.isEmpty,
                    let selectedItem = chartData.first(where: { guard let id = $0.id else { return false }; return selectedCategoryIDs.contains(id) })
                {
                    // Filtered: Show highlighted category (centered)
                    Spacer()
                    VStack(alignment: .center, spacing: DS.Spacing.xs) {
                        // Name (top, colored)
                        Text(selectedItem.name)
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(Color(hex: selectedItem.colorHex))
                            .lineLimit(1)

                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedItem.colorHex).opacity(0.15))
                            Image(systemName: selectedItem.iconName)
                                .font(DS.Typography.labelTiny).fontWeight(.bold)
                                .foregroundStyle(Color(hex: selectedItem.colorHex))
                                .accessibilityHidden(true)
                        }
                        .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)

                        // Percentage + Amount (on same line)
                        Text(
                            "\(formattedPercentage(selectedItem.percentage)) (\(formattedCurrency(selectedItem.amount)))"
                        )
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let id = selectedItem.id {
                            onSelectCategory?(id)
                        }
                    }
                    Spacer()
                } else {
                    // Default: Show top 3 categories
                    ForEach(Array(chartData.prefix(3).enumerated()), id: \.element.identity) {
                        _, item in
                        VStack(alignment: .center, spacing: DS.Spacing.xs) {
                            // Name (top, colored)
                            Text(item.name)
                                .font(DS.Typography.labelTiny)
                                .foregroundStyle(Color(hex: item.colorHex))
                                .lineLimit(1)

                            // Icon
                            ZStack {
                                Circle()
                                    .fill(Color(hex: item.colorHex).opacity(0.15))
                                Image(systemName: item.iconName)
                                    .font(DS.Typography.captionSmall).fontWeight(.bold)
                                    .foregroundStyle(Color(hex: item.colorHex))
                                    .accessibilityHidden(true)
                            }
                            .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)

                            // Percentage
                            Text(formattedPercentage(item.percentage))
                                .font(DS.Typography.label)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let id = item.id {
                                onSelectCategory?(id)
                            }
                        }
                    }
                }
            }

            // 2. Stacked Bar (with segment separation)
            segmentedBar(chartData: chartData)
        }
        .padding(.top, DS.Spacing.lg)
    }

    // MARK: - Shared Header

    private var headerView: some View {
        Group {
            if showComparison {
                PieChartVariationHeader(
                    title: L10n.Widget.distributionByCategory,
                    totalAmount: totalExpense,  // Use total (not filtered) for consistent comparison
                    previousAmount: previousTotalAmount,
                    currencyCode: currencyCode,
                    period: period,
                    customRange: customRange,
                    comparisonMode: comparisonMode,
                    onShowDetail: onShowDetail
                )
            } else {
                // Original header without comparison
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(L10n.Widget.distributionByCategory)
                                .font(DS.Typography.subheadlineEmphasized)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if let headerInfoButton {
                                headerInfoButton
                            } else {
                                InfoHintButton(
                                    title: L10n.WidgetType.categoriesPie,
                                    message: L10n.Widget.Hint.categoriesPie
                                )
                            }
                        }
                        .padding(.bottom, DS.Spacing.xxs)

                        Text(formattedCurrency(filteredTotalExpense))
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Shared Chart View

    @ViewBuilder
    private func chartView(_ chartData: [PieChartData], innerRadiusRatio: CGFloat) -> some View {
        // Defensive: capture and validate data before passing to Chart
        let safeData = chartData.filter { $0.amount.isFinite && $0.amount > 0 }
        let totalAmount = safeData.reduce(0) { $0 + $1.amount }

        if safeData.isEmpty || !totalAmount.isFinite || totalAmount <= 0 {
            // Return empty view instead of crashing Chart
            Color.clear
        } else {
            // Create a stable ID based on data content to force complete rebuild
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
            .id(dataHash)  // Force complete rebuild when data changes
            .chartLegend(.hidden)
            .chartAngleSelection(value: $selectedAngle)
            .dsAnimation(.easeInOut(duration: 0.2), value: selectedCategoryIDs, reduceMotion: reduceMotion)  // Smooth dimming
            .animation(nil, value: dataHash)  // Disable animation to prevent interpolation crashes
            .onChange(of: selectedAngle) {
                if let angle = selectedAngle {
                    selectCategory(in: chartData, at: angle)
                    selectedAngle = nil
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.Accessibility.categoryPieChart)
            .accessibilityValue(safeData.isEmpty ? L10n.Accessibility.noData :
                L10n.Accessibility.categoriesCount(safeData.count, formattedCurrency(safeData.reduce(0) { $0 + $1.amount })))
        }
    }

    // MARK: - Helpers

    private func formattedCurrency(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: currencyCode)
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

    private func selectCategory(in chartData: [PieChartData], at angle: Double) {
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
            // ViewModel handles toggle logic (select if new, deselect if same)
            onSelectCategory?(id)
        }
    }

    private func isDimmed(_ item: PieChartData) -> Bool {
        // In exclude mode, excluded items are already removed from chart data — no dimming needed
        if isExcludeMode { return false }
        guard !selectedCategoryIDs.isEmpty else { return false }
        guard let id = item.id else { return true }
        return !selectedCategoryIDs.contains(id)
    }

    private func currentCenterItem(_ chartData: [PieChartData]) -> PieChartData? {
        if isExcludeMode {
            // Excluded items already removed; show first visible item
            return chartData.first
        }
        if !selectedCategoryIDs.isEmpty {
            return chartData.first { $0.id == selectedCategoryIDs.first }
        }
        return chartData.first
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
        // For Medium, show all categories (no grouping). For Large, allow more slices.
        let threshold = size == .large ? 12 : 20

        // In exclude mode, remove excluded items entirely (they disappear from the chart)
        let visibleCategories: [CategorySpendingSummary]
        if isExcludeMode && !selectedCategoryIDs.isEmpty {
            visibleCategories = categories.filter { !selectedCategoryIDs.contains($0.category.persistentModelID) }
        } else {
            visibleCategories = categories
        }

        // Recalculate total from visible items only
        let visibleTotal = visibleCategories.reduce(0) { $0 + $1.amount }

        var finalItems: [PieChartData] = []

        if visibleCategories.count <= threshold {
            finalItems = visibleCategories.map {
                let pct = visibleTotal > 0 ? ($0.amount / visibleTotal) * 100 : 0
                return PieChartData(
                    id: $0.category.persistentModelID,
                    name: $0.category.name,
                    iconName: $0.category.iconName ?? "tag.fill",
                    amount: $0.amount,
                    percentage: pct,
                    colorHex: $0.category.colorHex
                )
            }
        } else {
            let top = visibleCategories.prefix(threshold)
            let others = visibleCategories.dropFirst(threshold)

            finalItems = top.map {
                let pct = visibleTotal > 0 ? ($0.amount / visibleTotal) * 100 : 0
                return PieChartData(
                    id: $0.category.persistentModelID,
                    name: $0.category.name,
                    iconName: $0.category.iconName ?? "tag.fill",
                    amount: $0.amount,
                    percentage: pct,
                    colorHex: $0.category.colorHex
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

        // Calculate Angles (0 to 2*pi)
        // Adjust Start Angle: -90 degrees (12 o'clock)
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
                    .dsAnimation(.easeInOut(duration: 0.2), value: selectedCategoryIDs, reduceMotion: reduceMotion)
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
