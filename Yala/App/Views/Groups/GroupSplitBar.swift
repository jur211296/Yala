//
//  GroupSplitBar.swift
//  Yala
//
//  Barra del reparto de un gasto de grupo: un tramo por persona, ancho proporcional a su
//  parte, con su monto debajo. La comparten el detalle del gasto y el editor (propuesta B
//  de `group-expense-views-redesign`), así que el color de cada persona es el mismo en los
//  dos lados: lo fija `GroupMemberPalette` a partir del orden de los miembros, no de la vista.
//

import SwiftUI

/// Color estable por persona dentro de un grupo.
///
/// El orden lo decide quién eres (tú primero) y después el nombre, para que una persona tenga
/// el mismo color en el detalle y en el editor aunque cada vista liste a la gente distinto.
/// Colores de la paleta de marca: van en superficies RELLENAS (tramos, avatares), nunca como
/// color de texto sobre tarjeta (regla de contraste de `swiftui-ds.md`).
enum GroupMemberPalette {
    static let colors: [Color] = [
        .electricIndigo,
        .priorityNeedNew,
        .hotPink,
        .priorityNeed,
        .essentialNeed,
        .optionalNeed
    ]

    /// `[memberID: color]` para todos los ids dados.
    static func colors(
        for memberIDs: [String],
        currentMemberID: String?,
        names: [String: String]
    ) -> [String: Color] {
        let ordered = memberIDs.sorted { lhs, rhs in
            let lhsIsMe = lhs == currentMemberID
            let rhsIsMe = rhs == currentMemberID
            if lhsIsMe != rhsIsMe { return lhsIsMe }
            let lhsName = names[lhs] ?? ""
            let rhsName = names[rhs] ?? ""
            if lhsName != rhsName {
                return lhsName.localizedStandardCompare(rhsName) == .orderedAscending
            }
            return lhs < rhs
        }
        var map: [String: Color] = [:]
        for (index, id) in ordered.enumerated() {
            map[id] = colors[index % colors.count]
        }
        return map
    }
}

/// Un tramo de la barra: quién, cuánto y de qué color.
struct GroupSplitBarSegment: Identifiable {
    let id: String
    let amount: Double
    let color: Color
}

/// Barra partida en tramos proporcionales, con el monto de cada tramo debajo.
///
/// Los tramos en cero no se dibujan: quien no participa no ocupa sitio. Con más de cuatro
/// personas los montos de debajo se omiten (no caben legibles) y quedan en la lista de la
/// tarjeta, que es la que lleva el dato completo.
struct GroupSplitBar: View {
    let segments: [GroupSplitBarSegment]
    let currencyCode: String

    @Environment(AppPreferences.self) private var appPreferences

    private static let barHeight: CGFloat = 10
    @ScaledMetric(relativeTo: .caption2) private var labelHeight: CGFloat = 16 // A11Y-DT: @ScaledMetric
    private static let maxLabeledSegments = 4

    private var visibleSegments: [GroupSplitBarSegment] {
        segments.filter { $0.amount > 0.004 }
    }

    private var total: Double {
        visibleSegments.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        let visible = visibleSegments
        let showsLabels = visible.count <= Self.maxLabeledSegments
        VStack(spacing: DS.Spacing.xs) {
            proportionalBar(visible)

            if showsLabels {
                labelsRow(visible)
            }
        }
        .accessibilityHidden(true)
    }

    private func weight(of segment: GroupSplitBarSegment) -> Double {
        total > 0 ? segment.amount / total : 0
    }

    /// `GeometryReader` reparte el ancho por peso. Alto fijo: el lector no toma alto propio.
    private func proportionalBar(_ visible: [GroupSplitBarSegment]) -> some View {
        GeometryReader { proxy in
            let gaps = DS.Spacing.xxs * CGFloat(max(visible.count - 1, 0))
            let usable = max(proxy.size.width - gaps, 0)
            HStack(spacing: DS.Spacing.xxs) {
                ForEach(visible) { segment in
                    Capsule()
                        .fill(segment.color)
                        .frame(width: max(usable * weight(of: segment), Self.barHeight))
                }
            }
        }
        .frame(height: Self.barHeight)
    }

    private func labelsRow(_ visible: [GroupSplitBarSegment]) -> some View {
        GeometryReader { proxy in
            let gaps = DS.Spacing.xxs * CGFloat(max(visible.count - 1, 0))
            let usable = max(proxy.size.width - gaps, 0)
            HStack(alignment: .top, spacing: DS.Spacing.xxs) {
                ForEach(visible) { segment in
                    Text(appPreferences.currency(segment.amount, currencyCode: currencyCode))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: max(usable * weight(of: segment), Self.barHeight))
                }
            }
        }
        .frame(height: labelHeight)
    }
}
