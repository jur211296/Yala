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
    let selectedPoolNodeIDs: Set<String>
    let onTapCategory: (PersistentIdentifier) -> Void
    let onTapSubcategory: (PersistentIdentifier) -> Void
    let onTapPoolNode: (String) -> Void

    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - Layout constants

    /// Uniform width across columns so long names (categorías + subcategorías)
    /// don't truncate mid-word.
    private let columnWidth: CGFloat = 220
    private let columnGap: CGFloat = 10
    private let nodeWidth: CGFloat = 8
    private let nodeGap: CGFloat = 6
    private let minNodeHeight: CGFloat = 4
    /// Floor per node so even tiny amounts keep room for a readable caption.
    /// `buildLayout` distributes leftover height proportionally on top of this.
    private let minLabelHeight: CGFloat = 20
    private let verticalPadding: CGFloat = 8
    private let rowHeightEstimate: CGFloat = 24
    private let dimmedOpacity: Double = 0.25

    private func originX(for column: SankeyColumn) -> CGFloat {
        CGFloat(column.rawValue) * (columnWidth + columnGap)
    }

    private var totalWidth: CGFloat {
        let count = CGFloat(SankeyColumn.allCases.count)
        return count * columnWidth + (count - 1) * columnGap
    }

    /// Adaptive height: reserves `minLabelHeight` on every node of the densest
    /// column PLUS a `flexBudget` of leftover space that gets prorated by
    /// amount in `buildLayout`. Without the budget, dense columns would
    /// collapse every node to exactly `minLabelHeight` and lose hierarchy.
    /// Cap sized for typical phones — past ~18 subcategorías the layout starts
    /// to degrade to pure proportional (small ones lose their floor).
    private var cardHeight: CGFloat {
        let maxNodes = SankeyColumn.allCases
            .map { visibleData.nodes(in: $0).count }
            .max() ?? 0
        let estimate = CGFloat(max(maxNodes, 3)) * rowHeightEstimate + verticalPadding * 2
        let flexBudget: CGFloat = 100
        let requiredForFloor = CGFloat(maxNodes) * minLabelHeight
            + CGFloat(max(maxNodes - 1, 0)) * nodeGap
            + verticalPadding * 2
        return min(max(estimate, requiredForFloor + flexBudget, 200), 480)
    }

    /// View-level filter: combines pool, category, and subcategory selections.
    /// - Pool selection restricts cols 2/3 to the categories/subcategories reached
    ///   by links from the selected pool nodes (Hybrid: pool nodes stay visible with
    ///   dimming, cols downstream get filtered).
    /// - Cat/subcat selection restricts col 3 as before.
    private var visibleData: SankeyData {
        var kept = data

        // Pool filter (applies first, narrows the universe of cats/subs)
        if !selectedPoolNodeIDs.isEmpty {
            let catNodes = kept.nodes(in: .expenseCategory)
            let subcatNodes = kept.nodes(in: .expenseSubcategory)
            let catNodeIDs = Set(catNodes.map(\.id))
            let subcatNodeIDSet = Set(subcatNodes.map(\.id))
            let keptCatIDs = Set(
                kept.links
                    .filter { catNodeIDs.contains($0.targetID) && selectedPoolNodeIDs.contains($0.sourceID) }
                    .map(\.targetID)
            )
            let keptCatPersistentIDs = Set(
                catNodes
                    .filter { keptCatIDs.contains($0.id) }
                    .compactMap(\.persistentID)
            )
            let keptSubNodeIDs = Set(
                subcatNodes
                    .filter { sub in
                        guard let parent = sub.parentCategoryID else { return false }
                        return keptCatPersistentIDs.contains(parent)
                    }
                    .map(\.id)
            )

            let filteredNodes = kept.nodes.filter { n in
                switch n.column {
                case .income, .pool: return true
                case .expenseCategory: return keptCatIDs.contains(n.id)
                case .expenseSubcategory: return keptSubNodeIDs.contains(n.id)
                }
            }
            let filteredLinks = kept.links.filter { link in
                if catNodeIDs.contains(link.targetID) {
                    return selectedPoolNodeIDs.contains(link.sourceID) && keptCatIDs.contains(link.targetID)
                }
                if subcatNodeIDSet.contains(link.targetID) {
                    return keptCatIDs.contains(link.sourceID) && keptSubNodeIDs.contains(link.targetID)
                }
                return true
            }
            kept = SankeyData(
                nodes: filteredNodes,
                links: filteredLinks,
                totalIncome: kept.totalIncome,
                totalExpense: kept.totalExpense,
                pool: kept.pool
            )
        }

        // Cat/subcat filter (existing behavior, applied over pool-filtered universe)
        guard !selectedCategoryIDs.isEmpty || !selectedSubcategoryIDs.isEmpty else {
            return kept
        }
        let subcatNodes = kept.nodes(in: .expenseSubcategory)
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
        let filteredLinks = kept.links.filter { link in
            subcatNodeIDs.contains(link.targetID) ? keptSubcatIDs.contains(link.targetID) : true
        }
        let nodes = kept.nodes.filter { n in
            n.column != .expenseSubcategory || keptSubcatIDs.contains(n.id)
        }
        return SankeyData(
            nodes: nodes,
            links: filteredLinks,
            totalIncome: kept.totalIncome,
            totalExpense: kept.totalExpense,
            pool: kept.pool
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
                                .frame(width: columnWidth - nodeWidth - DS.Spacing.sm)
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
            switch labelMode {
            case .amount:
                AmountText(
                    value: node.amount,
                    currencyCode: currencyCode,
                    font: DS.Typography.captionSmall,
                    secondaryFont: DS.Typography.captionSmall,
                    tint: .secondary
                )
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
            case .percentage:
                Text(valueString)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
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
        guard !selectedCategoryIDs.isEmpty
                || !selectedSubcategoryIDs.isEmpty
                || !selectedPoolNodeIDs.isEmpty else {
            return 1.0
        }
        switch node.column {
        case .income:
            return 1.0
        case .pool:
            return selectedPoolNodeIDs.isEmpty || selectedPoolNodeIDs.contains(node.id)
                ? 1.0
                : dimmedOpacity
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
        case .pool:
            onTapPoolNode(node.id)
        case .income:
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
        let hs = placed.sourceHeight
        let ht = placed.targetHeight
        let midX = (s.x + t.x) / 2

        var path = Path()
        path.move(to: s)
        path.addCurve(
            to: t,
            control1: CGPoint(x: midX, y: s.y),
            control2: CGPoint(x: midX, y: t.y)
        )
        path.addLine(to: CGPoint(x: t.x, y: t.y + ht))
        path.addCurve(
            to: CGPoint(x: s.x, y: s.y + hs),
            control1: CGPoint(x: midX, y: t.y + ht),
            control2: CGPoint(x: midX, y: s.y + hs)
        )
        path.closeSubpath()
        return path
    }

    // MARK: - Layout

    private func buildLayout() -> SankeyLayout {
        let source = visibleData
        let columnBuckets: [(column: SankeyColumn, nodes: [SankeyNode])] =
            SankeyColumn.allCases.map { ($0, source.nodes(in: $0)) }

        // Each column fills its full available height. Reserve `minLabelHeight`
        // per node first so even tiny amounts stay readable, then distribute
        // the remaining height proportionally to amount. When the column is too
        // dense to honor the floor, fall back to pure proportional sizing.
        var nodeHeights: [String: CGFloat] = [:]
        for (_, nodes) in columnBuckets {
            let sum = nodes.reduce(0.0) { $0 + $1.amount }
            let gaps = CGFloat(max(nodes.count - 1, 0)) * nodeGap
            let avail = max(cardHeight - verticalPadding * 2 - gaps, 0)
            let minTotal = CGFloat(nodes.count) * minLabelHeight
            let useFloor = sum > 0 && avail >= minTotal
            let flex = avail - minTotal

            for node in nodes {
                let h: CGFloat
                if useFloor {
                    h = minLabelHeight + flex * CGFloat(node.amount / sum)
                } else if sum > 0 {
                    h = max(CGFloat(node.amount / sum) * avail, minNodeHeight)
                } else {
                    h = minNodeHeight
                }
                nodeHeights[node.id] = h
            }
        }

        var placedNodes: [PlacedNode] = []
        var rectByID: [String: CGRect] = [:]
        var dimByID: [String: Double] = [:]

        for (column, nodes) in columnBuckets {
            let colX = originX(for: column)
            var y = verticalPadding

            for node in nodes {
                let height = nodeHeights[node.id] ?? minNodeHeight
                let rect = CGRect(x: colX, y: y, width: nodeWidth, height: height)
                let labelOrigin = CGPoint(
                    x: colX + nodeWidth + DS.Spacing.sm + (columnWidth - nodeWidth - DS.Spacing.sm) / 2,
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

        // Link heights are a share of the source/target node heights, not of
        // the raw column scale — keeps the band inside the node bounds even
        // when nodes use the min-floor scheme above.
        var outgoingSum: [String: Double] = [:]
        var incomingSum: [String: Double] = [:]
        for link in source.links {
            outgoingSum[link.sourceID, default: 0] += link.amount
            incomingSum[link.targetID, default: 0] += link.amount
        }

        var sourceOffsets: [String: CGFloat] = [:]
        var targetOffsets: [String: CGFloat] = [:]
        var placedLinks: [PlacedLink] = []

        for link in source.links {
            guard let srcRect = rectByID[link.sourceID],
                  let tgtRect = rectByID[link.targetID] else { continue }

            let srcH = nodeHeights[link.sourceID] ?? 0
            let tgtH = nodeHeights[link.targetID] ?? 0
            let srcSum = outgoingSum[link.sourceID] ?? 0
            let tgtSum = incomingSum[link.targetID] ?? 0
            let srcHeight = srcSum > 0 ? max(srcH * CGFloat(link.amount / srcSum), 0.5) : 0.5
            let tgtHeight = tgtSum > 0 ? max(tgtH * CGFloat(link.amount / tgtSum), 0.5) : 0.5
            let srcY = srcRect.minY + (sourceOffsets[link.sourceID] ?? 0)
            let tgtY = tgtRect.minY + (targetOffsets[link.targetID] ?? 0)
            let linkDim = min(dimByID[link.sourceID] ?? 1, dimByID[link.targetID] ?? 1)

            placedLinks.append(PlacedLink(
                link: link,
                sourceOrigin: CGPoint(x: srcRect.maxX, y: srcY),
                targetOrigin: CGPoint(x: tgtRect.minX, y: tgtY),
                sourceHeight: srcHeight,
                targetHeight: tgtHeight,
                colorHex: link.sourceColorHex,
                dim: linkDim
            ))

            sourceOffsets[link.sourceID, default: 0] += srcHeight
            targetOffsets[link.targetID, default: 0] += tgtHeight
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
    let sourceHeight: CGFloat
    let targetHeight: CGFloat
    let colorHex: String
    let dim: Double
}

private struct ScrollMetrics: Equatable {
    let offsetX: CGFloat
    let contentW: CGFloat
    let containerW: CGFloat
}
