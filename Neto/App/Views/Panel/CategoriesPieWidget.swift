//
//  CategoriesPieWidget.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Charts
import SwiftData
import SwiftUI

struct CategoriesPieWidget: View {
    let categories: [CategorySpendingSummary]
    let currencyCode: String

    // Filter State
    var selectedCategoryID: PersistentIdentifier?
    var onSelectCategory: ((PersistentIdentifier) -> Void)?
    var onShowDetail: (() -> Void)? = nil

    var size: WidgetSize = .medium

    // Computed Properties
    private var totalExpense: Double {
        categories.reduce(0) { $0 + $1.amount }
    }

    // Filtered total based on selected category
    private var filteredTotalExpense: Double {
        if let selectedID = selectedCategoryID,
            let selectedCategory = categories.first(where: {
                $0.category.persistentModelID == selectedID
            })
        {
            return selectedCategory.amount
        }
        return totalExpense
    }

    private var chartData: [PieChartData] {
        processChartData()
    }

    // Chart Selection State - Internal tracking for chart interaction
    @State private var selectedAngle: Double?

    // Hover State - For long-press tooltip
    @State private var hoveredItem: PieChartData?

    // Configuration Constants
    private let innerRadiusRatio: CGFloat = 0.50
    // Relative to the Chart's frame radius (half of smaller dimension)
    // We'll calculate exact pixels in GeometryReader

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Guard against empty chartData (Charts framework crashes on empty array)
            if chartData.isEmpty {
                emptyState
            } else {
                contentForSize
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: size == .large ? 320 : (size == .medium ? 220 : nil))
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Sin datos")
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

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Categorías")
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(Color.gray.opacity(0.7))
        }
    }

    // MARK: - Layouts

    private var largeLayout: some View {
        VStack(spacing: 8) {
            // Header
            headerView
                .padding(.horizontal, 0)

            // Chart (2/3) on left, Legend (1/3) on right
            HStack(alignment: .center, spacing: 16) {
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
                        connectorLines(center: center, chartRadius: chartRadius)

                        // 2. The Chart Itself
                        chartView(innerRadiusRatio: innerRadiusRatio)
                            .frame(width: chartRadius * 2, height: chartRadius * 2)
                            .position(center)

                        // 3. Floating Bubbles & Labels Layer
                        bubblesLayer(center: center, chartRadius: chartRadius)

                        // 4. Hover Tooltip (on top)
                        if let hovered = hoveredItem {
                            hoverTooltip(for: hovered)
                                .position(center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Right: Simple Legend List (1/3 width)
                simpleLegendList
                    .frame(width: 140)
            }
        }
        .padding(.top, DS.Spacing.lg)
    }

    // MARK: - Simple Legend List for Large Layout

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
                // Color dot
                Circle()
                    .fill(Color(hex: item.colorHex))
                    .frame(width: 8, height: 8)

                // Category name
                Text(item.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                // Percentage
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

    // Logic: If selection exists, ONLY show selected. Else, show all > threshold.
    private func shouldShowLabel(for item: PieChartData) -> Bool {
        if let selectedID = selectedCategoryID {
            return item.id == selectedID
        } else {
            // "Show for even small categories" requested? User said: "ensure even small categories have label WHEN FILTERING".
            // So if NO filter, use threshold to avoid clutter.
            // If FILTERED (Selected), show only that one (even if small).
            return item.percentage > 4.0
        }
    }

    // MARK: - Medium Layout (Focus Bar Chart)

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView

            // 1. Category Labels
            HStack(alignment: .top, spacing: 0) {
                if let selectedID = selectedCategoryID,
                    let selectedItem = chartData.first(where: { $0.id == selectedID })
                {
                    // Filtered: Show only selected category (centered)
                    Spacer()
                    VStack(alignment: .center, spacing: 4) {
                        // Name (top, colored)
                        Text(selectedItem.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: selectedItem.colorHex))
                            .lineLimit(1)

                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedItem.colorHex).opacity(0.15))
                            Image(systemName: selectedItem.iconName)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: selectedItem.colorHex))
                        }
                        .frame(width: 32, height: 32)

                        // Percentage + Amount (on same line)
                        Text(
                            "\(formattedPercentage(selectedItem.percentage)) (\(formattedAmountCompact(selectedItem.amount)))"
                        )
                        .font(.system(size: 16, weight: .bold))
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
                        VStack(alignment: .center, spacing: 4) {
                            // Name (top, colored)
                            Text(item.name)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color(hex: item.colorHex))
                                .lineLimit(1)

                            // Icon
                            ZStack {
                                Circle()
                                    .fill(Color(hex: item.colorHex).opacity(0.15))
                                Image(systemName: item.iconName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: item.colorHex))
                            }
                            .frame(width: 24, height: 24)

                            // Percentage
                            Text(formattedPercentage(item.percentage))
                                .font(.system(size: 14, weight: .bold))
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
        .padding(.top, 16)
    }

    // MARK: - Shared Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Distribución de gastos")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 2)

                // Dynamic subtitle based on filter state
                Text(selectedCategoryID != nil ? "Categoría seleccionada" : "Total del periodo")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formattedCurrency(filteredTotalExpense))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            HStack(spacing: 8) {
                Text("\(categories.count) categorías")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())

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
    }

    // MARK: - Small Layout (Existing)

    private var smallLayout: some View {
        chartView(innerRadiusRatio: 0.65)
            .chartBackground { proxy in
                GeometryReader { innerGeo in
                    if let centerItem = currentCenterItem() {
                        // Calculate safe width for center content (inside donut hole)
                        let chartSize = min(innerGeo.size.width, innerGeo.size.height)
                        let innerRadius = chartSize * 0.65 * 0.5  // innerRadiusRatio * radius
                        let safeWidth = innerRadius * 1.4  // 70% of diameter for text

                        VStack(spacing: 2) {
                            // Category Name - truncated to fit
                            Text(centerItem.name)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color(hex: centerItem.colorHex))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: safeWidth)

                            // Icon
                            Image(systemName: centerItem.iconName)
                                .font(.caption2)
                                .foregroundStyle(Color(hex: centerItem.colorHex))

                            // Percentage
                            Text(formattedPercentage(centerItem.percentage))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.primary)

                            // Amount - truncated to fit
                            Text(formattedAmountCompact(centerItem.amount))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: safeWidth)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
    }

    // MARK: - Shared Chart View

    @ViewBuilder
    private func chartView(innerRadiusRatio: CGFloat) -> some View {
        // Defensive: capture and validate data before passing to Chart
        let safeData = chartData.filter { $0.amount.isFinite && $0.amount > 0 }
        let totalAmount = safeData.reduce(0) { $0 + $1.amount }

        if safeData.isEmpty || !totalAmount.isFinite || totalAmount <= 0 {
            // Return empty view instead of crashing Chart
            Color.clear
        } else {
            // Create a stable ID based on data content to force complete rebuild
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
            .id(dataHash)  // Force complete rebuild when data changes
            .chartLegend(.hidden)
            .chartAngleSelection(value: $selectedAngle)
            .animation(nil, value: dataHash)  // Disable animation to prevent interpolation crashes
            .onChange(of: selectedAngle) {
                if let angle = selectedAngle {
                    selectCategory(at: angle)
                    selectedAngle = nil
                }
            }
        }
    }

    // MARK: - Helpers

    private func formattedAmountCompact(_ value: Double) -> String {
        NetoFormatter.currency(value: value, currencyCode: currencyCode, decimals: 0)
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

    private func selectCategory(at angle: Double) {
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

    private func isSelected(_ item: PieChartData) -> Bool {
        return selectedCategoryID == item.id
    }

    private func isDimmed(_ item: PieChartData) -> Bool {
        guard let selected = selectedCategoryID else { return false }
        return item.id != selected
    }

    private func currentCenterItem() -> PieChartData? {
        if let id = selectedCategoryID {
            return chartData.first { $0.id == id }
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

        let validCategories = categories
        var finalItems: [PieChartData] = []

        if validCategories.count <= threshold {
            finalItems = validCategories.map {
                PieChartData(
                    id: $0.category.persistentModelID,
                    name: $0.category.name,
                    iconName: $0.category.iconName ?? "tag.fill",
                    amount: $0.amount,
                    percentage: $0.percentage,
                    colorHex: $0.category.colorHex
                )
            }
        } else {
            let top = validCategories.prefix(threshold)
            let others = validCategories.dropFirst(threshold)

            finalItems = top.map {
                PieChartData(
                    id: $0.category.persistentModelID,
                    name: $0.category.name,
                    iconName: $0.category.iconName ?? "tag.fill",
                    amount: $0.amount,
                    percentage: $0.percentage,
                    colorHex: $0.category.colorHex
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
}
