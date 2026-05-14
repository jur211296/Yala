//
//  SankeyChartView.swift
//  Yala
//
//  Custom SwiftUI Canvas-based Sankey diagram for the Distribution tab.
//  Renders income → pool (Gastos + optional Disponible) → expense categories
//  → expense subcategories as proportional flows. Labels are SwiftUI views
//  (Dynamic Type + a11y friendly) and carry the tap gesture — the Canvas is
//  rendered behind them but is NOT hit-tested.
//

import SwiftData
import SwiftUI

struct SankeyChartView: View {

    // MARK: - Inputs

    let data: SankeyData
    let currencyCode: String
    @Binding var labelMode: SankeyLabelMode
    let selectedCategoryIDs: Set<PersistentIdentifier>
    let selectedSubcategoryIDs: Set<PersistentIdentifier>
    let onTapCategory: (PersistentIdentifier) -> Void
    let onTapSubcategory: (PersistentIdentifier) -> Void

    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - Layout constants

    private let columnWidth: CGFloat = 140
    /// Subcategory column gets extra width: names like "Belleza y estética" or
    /// "Servicios del hogar" need the room to avoid mid-word truncation.
    private let subcategoryColumnWidth: CGFloat = 220
    private let columnGap: CGFloat = 56
    private let nodeWidth: CGFloat = 8
    private let nodeGap: CGFloat = 6
    private let minNodeHeight: CGFloat = 4
    private let verticalPadding: CGFloat = 8
    private let rowHeightEstimate: CGFloat = 24
    private let dimmedOpacity: Double = 0.25

    private func width(for column: SankeyColumn) -> CGFloat {
        column == .expenseSubcategory ? subcategoryColumnWidth : columnWidth
    }

    /// Cumulative origin X of the given column — sums prior column widths and gaps.
    private func originX(for column: SankeyColumn) -> CGFloat {
        var x: CGFloat = 0
        for c in SankeyColumn.allCases where c.rawValue < column.rawValue {
            x += width(for: c) + columnGap
        }
        return x
    }

    private var totalWidth: CGFloat {
        let sumWidths = SankeyColumn.allCases.reduce(0.0) { $0 + width(for: $1) }
        return sumWidths + CGFloat(SankeyColumn.allCases.count - 1) * columnGap
    }

    /// Adaptive height based on the tallest column's node count.
    /// Hugs content so a sparse data set doesn't leave a huge gap and a
    /// dense column still fits comfortably.
    private var cardHeight: CGFloat {
        let maxNodes = SankeyColumn.allCases
            .map { visibleData.nodes(in: $0).count }
            .max() ?? 0
        let estimate = CGFloat(max(maxNodes, 3)) * rowHeightEstimate + verticalPadding * 2
        // Cap at 340pt to match NeedTrendWidget's large size for visual balance.
        return min(max(estimate, 200), 340)
    }

    /// View-level filter: when a cat/subcat is selected, restrict col 3 to the
    /// matching subcats only (parentCategoryID in selection OR persistentID in selection).
    private var visibleData: SankeyData {
        guard !selectedCategoryIDs.isEmpty || !selectedSubcategoryIDs.isEmpty else {
            return data
        }
        let subcatNodes = data.nodes(in: .expenseSubcategory)
        let subcatNodeIDs = Set(subcatNodes.map(\.id))
        let keptSubcatIDs = Set(subcatNodes.filter { sub in
            if !selectedSubcategoryIDs.isEmpty {
                guard let id = sub.persistentID else { return false }
                return selectedSubcategoryIDs.contains(id)
            }
            if let parent = sub.parentCategoryID {
                return selectedCategoryIDs.contains(parent)
            }
            return false
        }.map(\.id))
        let filteredLinks = data.links.filter { link in
            subcatNodeIDs.contains(link.targetID) ? keptSubcatIDs.contains(link.targetID) : true
        }
        let nodes = data.nodes.filter { n in
            n.column != .expenseSubcategory || keptSubcatIDs.contains(n.id)
        }
        return SankeyData(
            nodes: nodes,
            links: filteredLinks,
            totalIncome: data.totalIncome,
            totalExpense: data.totalExpense,
            pool: data.pool
        )
    }

    // MARK: - Layout cache

    @State private var layout: SankeyLayout?
    @State private var scrollProgress: CGFloat = 0
    @State private var visibleRatio: CGFloat = 1

    // MARK: - Body

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in
                        guard let layout else { return }
                        drawLinks(context: context, layout: layout)
                        drawNodes(context: context, layout: layout)
                    }
                    .frame(width: totalWidth, height: cardHeight)
                    .allowsHitTesting(false)

                    if let layout {
                        ForEach(layout.nodes, id: \.node.id) { placed in
                            nodeLabel(for: placed)
                                .frame(width: width(for: placed.node.column) - nodeWidth - DS.Spacing.sm)
                                .position(x: placed.labelOrigin.x, y: placed.labelOrigin.y)
                        }
                    }
                }
                .frame(width: totalWidth, height: cardHeight)
            }
            .frame(height: cardHeight)
            .onScrollGeometryChange(for: ScrollMetrics.self) { geom in
                ScrollMetrics(
                    offsetX: geom.contentOffset.x,
                    contentW: geom.contentSize.width,
                    containerW: geom.containerSize.width
                )
            } action: { _, m in
                let scrollable = max(m.contentW - m.containerW, 0)
                scrollProgress = scrollable > 0 ? m.offsetX / scrollable : 0
                visibleRatio = m.contentW > 0
                    ? min(max(m.containerW / m.contentW, 0), 1)
                    : 1
            }

            if visibleRatio < 1 {
                scrollIndicator
            }
        }
        .onAppear { layout = buildLayout() }
        .onChange(of: visibleData) { layout = buildLayout() }
    }

    private var scrollIndicator: some View {
        GeometryReader { geom in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(Color.secondary.opacity(0.55))
                    .frame(width: max(geom.size.width * visibleRatio, 24))
                    .offset(
                        x: max(0, geom.size.width - max(geom.size.width * visibleRatio, 24))
                            * scrollProgress
                    )
            }
        }
        .frame(height: 3)
        .frame(maxWidth: 140)
        .accessibilityHidden(true)
    }

    // MARK: - Label rendering

    @ViewBuilder
    private func nodeLabel(for placed: PlacedNode) -> some View {
        let node = placed.node
        let valueString = formattedValue(for: node)

        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(node.name)
                .font(DS.Typography.captionSmall)
                .fontWeight(.medium)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(valueString)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(placed.dim)
        .contentShape(Rectangle())
        .onTapGesture { handleTap(on: node) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(node.name), \(valueString)"))
        .accessibilityAddTraits(node.isTappable ? .isButton : [])
    }

    private func dimOpacity(for node: SankeyNode) -> Double {
        guard !selectedCategoryIDs.isEmpty || !selectedSubcategoryIDs.isEmpty else {
            return 1.0
        }
        switch node.column {
        case .income, .pool:
            return 1.0
        case .expenseCategory:
            if let id = node.persistentID, selectedCategoryIDs.contains(id) {
                return 1.0
            }
            // When a subcat is selected, the parent cat stays lit too.
            if !selectedSubcategoryIDs.isEmpty,
               let parent = node.persistentID,
               data.nodes(in: .expenseSubcategory).contains(where: {
                   $0.parentCategoryID == parent && selectedSubcategoryIDs.contains($0.persistentID ?? parent)
               }) {
                return 1.0
            }
            return dimmedOpacity
        case .expenseSubcategory:
            if !selectedSubcategoryIDs.isEmpty {
                guard let id = node.persistentID else { return dimmedOpacity }
                return selectedSubcategoryIDs.contains(id) ? 1.0 : dimmedOpacity
            }
            return 1.0
        }
    }

    private func handleTap(on node: SankeyNode) {
        guard node.isTappable else { return }
        switch node.column {
        case .expenseCategory:
            if let id = node.persistentID { onTapCategory(id) }
        case .expenseSubcategory:
            if let id = node.persistentID { onTapSubcategory(id) }
        case .income, .pool:
            break
        }
    }

    private func formattedValue(for node: SankeyNode) -> String {
        switch labelMode {
        case .amount:
            return appPreferences.currency(node.amount, currencyCode: currencyCode)
        case .percentage:
            let base = max(data.totalExpense, data.totalIncome)
            guard base > 0 else { return "—" }
            let pct = (node.amount / base) * 100
            return String(format: "%.0f%%", pct)
        }
    }

    // MARK: - Drawing

    private func drawNodes(context: GraphicsContext, layout: SankeyLayout) {
        for placed in layout.nodes {
            let rect = placed.rect
            let path = Path(roundedRect: rect, cornerRadius: nodeWidth / 2)
            context.fill(
                path,
                with: .color(Color(hex: placed.node.colorHex).opacity(placed.dim))
            )
        }
    }

    private func drawLinks(context: GraphicsContext, layout: SankeyLayout) {
        for placed in layout.links {
            let path = linkPath(placed)
            let color = Color(hex: placed.colorHex).opacity(0.28 * placed.dim)
            context.fill(path, with: .color(color))
        }
    }

    private func linkPath(_ placed: PlacedLink) -> Path {
        let s = placed.sourceOrigin
        let t = placed.targetOrigin
        let h = placed.height
        let midX = (s.x + t.x) / 2

        var path = Path()
        path.move(to: s)
        path.addCurve(
            to: t,
            control1: CGPoint(x: midX, y: s.y),
            control2: CGPoint(x: midX, y: t.y)
        )
        path.addLine(to: CGPoint(x: t.x, y: t.y + h))
        path.addCurve(
            to: CGPoint(x: s.x, y: s.y + h),
            control1: CGPoint(x: midX, y: t.y + h),
            control2: CGPoint(x: midX, y: s.y + h)
        )
        path.closeSubpath()
        return path
    }

    // MARK: - Layout

    private func buildLayout() -> SankeyLayout {
        let source = visibleData
        let columnBuckets: [(column: SankeyColumn, nodes: [SankeyNode])] =
            SankeyColumn.allCases.map { ($0, source.nodes(in: $0)) }

        // Size the chart to fit the tallest column IN PIXELS — i.e. the column
        // whose `scale × sum + gaps` is largest. Using gaps from the max-nodes
        // column (when that column has less sum) wastes vertical space.
        let columnSums = columnBuckets.map { $0.nodes.reduce(0.0) { $0 + $1.amount } }
        let maxColumnSum = columnSums.max() ?? 0
        let heaviestIndex = columnSums.firstIndex(of: maxColumnSum) ?? 0
        let nodesInHeaviest = columnBuckets[heaviestIndex].nodes.count

        let availableHeight = cardHeight - verticalPadding * 2
            - CGFloat(max(nodesInHeaviest - 1, 0)) * nodeGap
        let scale = maxColumnSum > 0 ? availableHeight / maxColumnSum : 0

        var placedNodes: [PlacedNode] = []
        var rectByID: [String: CGRect] = [:]
        var dimByID: [String: Double] = [:]

        for (column, nodes) in columnBuckets {
            let colX = originX(for: column)
            let colW = width(for: column)
            // Top-align columns: each column starts at verticalPadding and grows
            // downward. Avoids the empty space a centered layout creates when one
            // column has many thin nodes (tallest) and another has few fat ones.
            var y = verticalPadding

            for node in nodes {
                let height = max(scale * node.amount, minNodeHeight)
                let rect = CGRect(x: colX, y: y, width: nodeWidth, height: height)
                let labelOrigin = CGPoint(
                    x: colX + nodeWidth + DS.Spacing.sm + (colW - nodeWidth - DS.Spacing.sm) / 2,
                    y: y + height / 2
                )
                let dim = dimOpacity(for: node)
                placedNodes.append(PlacedNode(
                    node: node,
                    rect: rect,
                    labelOrigin: labelOrigin,
                    dim: dim
                ))
                rectByID[node.id] = rect
                dimByID[node.id] = dim
                y += height + nodeGap
            }
        }

        var sourceOffsets: [String: CGFloat] = [:]
        var targetOffsets: [String: CGFloat] = [:]
        var placedLinks: [PlacedLink] = []

        for link in source.links {
            guard let srcRect = rectByID[link.sourceID],
                  let tgtRect = rectByID[link.targetID] else { continue }

            let linkHeight = max(scale * link.amount, 0.5)
            let srcY = srcRect.minY + (sourceOffsets[link.sourceID] ?? 0)
            let tgtY = tgtRect.minY + (targetOffsets[link.targetID] ?? 0)
            let linkDim = min(dimByID[link.sourceID] ?? 1, dimByID[link.targetID] ?? 1)

            placedLinks.append(PlacedLink(
                link: link,
                sourceOrigin: CGPoint(x: srcRect.maxX, y: srcY),
                targetOrigin: CGPoint(x: tgtRect.minX, y: tgtY),
                height: linkHeight,
                colorHex: link.sourceColorHex,
                dim: linkDim
            ))

            sourceOffsets[link.sourceID, default: 0] += linkHeight
            targetOffsets[link.targetID, default: 0] += linkHeight
        }

        return SankeyLayout(nodes: placedNodes, links: placedLinks)
    }
}

// MARK: - Layout primitives

private struct SankeyLayout: Equatable {
    let nodes: [PlacedNode]
    let links: [PlacedLink]
}

private struct PlacedNode: Equatable {
    let node: SankeyNode
    let rect: CGRect
    let labelOrigin: CGPoint
    let dim: Double
}

private struct PlacedLink: Equatable {
    let link: SankeyLink
    let sourceOrigin: CGPoint
    let targetOrigin: CGPoint
    let height: CGFloat
    let colorHex: String
    let dim: Double
}

private struct ScrollMetrics: Equatable {
    let offsetX: CGFloat
    let contentW: CGFloat
    let containerW: CGFloat
}
