//
//  WidgetCategoryBreakdown.swift
//  YalaWidgets
//
//  Las piezas de los cuatro widgets de reparto del gasto (tanda 3 del rediseño 2.2, S35f2,
//  `docs/widgets/AUDITORIA-WIDGETS-2-2.md`): el ranking de «Categorías / Subcategorías que más gastan» y la tarta de
//  «Categorías / Subcategorías en círculo». Categorías y subcategorías llegan en DTO distintos y se pintan igual, así que
//  cada widget traduce los suyos a `WidgetBreakdownItem` y el resto es común.
//
//  Reglas que siguen (`.claude/rules/widgets.md`): solo `WidgetDS` y `WidgetColors`; el color de la categoría va en
//  rellenos (insignia, barra, porción, punto) y nunca en el texto, que es primario o gris; una cosa teñida por widget
//  (las barras en el ranking, el total en la tarta).
//

import SwiftUI
import WidgetKit

/// Una categoría o subcategoría con lo que se gastó en ella y su parte del gasto del período.
struct WidgetBreakdownItem: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    let amount: Double
    /// 0…100.
    let percentage: Double
    /// Un color que no sale de un hex de la foto: el gris de «Otros».
    var fixedColor: Color? = nil

    /// El mismo para la porción del aro, la insignia, la barra y el punto de la leyenda.
    var color: Color { fixedColor ?? WidgetColors.fill(hex: colorHex) }
}

/// «31 %», «31%» o «31 %» según el idioma, sin decimales.
enum WidgetPercentText {
    static func text(_ percentage: Double) -> String {
        (percentage / 100).formatted(.percent.precision(.fractionLength(0)))
    }
}

// MARK: - Cabecera

/// La cabecera con el título largo («Categorías que más gastan») si cabe junto al período, y si no, el corto
/// («Categorías»): el largo se truncaba («Categorías que más gas…») y en alemán o en subcategorías no cabe nunca.
struct WidgetBreakdownHeader: View {
    let title: String
    let shortTitle: String
    let systemImage: String
    let period: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            header(title)
            header(shortTitle)
        }
    }

    private func header(_ text: String) -> some View {
        WidgetCardHeader(title: text, systemImage: systemImage, tint: WidgetColors.electricIndigo) {
            WidgetHeaderDetail(text: period)
        }
    }
}

// MARK: - Ranking

/// Una fila del ranking: insignia sólida con el icono, nombre, importe y porcentaje, y debajo la barra de su parte del
/// gasto. El importe no encoge (antes bajaba a 7 pt en los largos): lo que cede es el nombre. Lo teñido son las barras.
struct WidgetRankingRow: View {
    let item: WidgetBreakdownItem
    let currencyCode: String
    let displayFormat: String

    var body: some View {
        HStack(spacing: WidgetDS.Spacing.sm) {
            WidgetBadge(systemImage: item.iconName, color: item.color)

            VStack(alignment: .leading, spacing: WidgetDS.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: WidgetDS.Spacing.xs) {
                    Text(item.name)
                        .font(WidgetDS.Typography.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: WidgetDS.Spacing.xs)

                    // Sin marca «≈» a propósito: es un SUBCONJUNTO del gasto del período y su calculador
                    // (`buildTopCategories`) no acumula la calidad de las conversiones que lo forman. Heredar la señal del
                    // total diría que ESTA categoría es dudosa sin haberlo medido (`fx-category-totals-unmarked`).
                    WidgetAmountText(
                        value: item.amount,
                        currencyCode: currencyCode,
                        displayFormat: displayFormat,
                        font: WidgetDS.Typography.label,
                        secondaryFont: WidgetDS.Typography.captionSmall
                    )
                    .fixedSize()

                    Text(WidgetPercentText.text(item.percentage))
                        .font(WidgetDS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(minWidth: WidgetDS.Chart.legendPercentWidth, alignment: .trailing)
                        .fixedSize()
                }

                WidgetMeterBar(fraction: item.percentage / 100, color: item.color)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// El ranking entero: las filas reparten el alto que deja la cabecera. Los huecos mínimos son pequeños para que las tres
/// quepan en el mediano de un iPhone SE (321 × 148); en uno más alto los reparten los `Spacer`.
struct WidgetRankingList: View {
    let items: [WidgetBreakdownItem]
    let currencyCode: String
    let displayFormat: String

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Spacer(minLength: WidgetDS.Spacing.xxs) }
                WidgetRankingRow(item: item, currencyCode: currencyCode, displayFormat: displayFormat)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Tarta

/// El aro con el total en el centro y debajo la leyenda: hasta cinco filas con importe y porcentaje (con más trozos, las
/// cuatro primeras y «Otros», y el aro se agrupa igual: `WidgetInsightsLogic.pieLegend`). Lo que los trozos no cubren
/// del total también va a «Otros», así que aro, leyenda y centro suman lo mismo. Sustituye a las burbujas, que se
/// solapaban y se salían del widget. Lo teñido es el total.
///
/// La leyenda pide su alto y el aro se queda con lo que sobra, hasta `donutSizeLarge`: en el grande de un iPhone SE
/// (321 × 324) o con el texto más grande, encoge el aro y no se corta la leyenda.
struct WidgetPieBreakdown: View {
    static let maxLegendRows = 5

    let items: [WidgetBreakdownItem]
    let total: Double
    let isEstimate: Bool
    let currencyCode: String
    let displayFormat: String

    var body: some View {
        let legend = WidgetInsightsLogic.pieLegend(
            items, maxRows: Self.maxLegendRows, total: total, amount: \.amount, percentage: \.percentage
        )
        let rows = legend.shown + (legend.others.map { [Self.othersItem($0)] } ?? [])

        VStack(spacing: WidgetDS.Spacing.md) {
            // El aro pinta las MISMAS filas que la leyenda (`rows`), no los trozos sueltos.
            WidgetDonut(slices: rows.map { WidgetDonutSlice(id: $0.id, value: $0.amount, color: $0.color) }) {
                GeometryReader { geo in
                    center(diameter: min(geo.size.width, geo.size.height))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: WidgetDS.Chart.donutSizeLarge, maxHeight: WidgetDS.Chart.donutSizeLarge)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
                ForEach(rows) { row in
                    WidgetLegendRow(item: row, currencyCode: currencyCode, displayFormat: displayFormat)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// «Total» y la cifra, dentro del hueco del aro (que mide `diameter × donutInnerRatio`).
    private func center(diameter: CGFloat) -> some View {
        VStack(spacing: WidgetDS.Spacing.none) {
            Text("widget.ui.total", bundle: .main)
                .font(WidgetDS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            WidgetAmountText(
                value: total,
                currencyCode: currencyCode,
                displayFormat: displayFormat,
                font: WidgetDS.Typography.headline,
                secondaryFont: WidgetDS.Typography.captionSmall,
                isEstimate: isEstimate
            )
            .widgetNumericTransition(total)
            .widgetAccentable()
        }
        .frame(width: max(diameter * WidgetDS.Chart.donutInnerRatio - WidgetDS.Spacing.sm, 0))
        .accessibilityElement(children: .combine)
    }

    private static func othersItem(_ others: WidgetInsightsLogic.PieOthers) -> WidgetBreakdownItem {
        WidgetBreakdownItem(
            id: "\u{1}legend-others",
            name: String(localized: "widget.ui.others", bundle: .main),
            iconName: "ellipsis.circle.fill",
            colorHex: "",
            amount: others.amount,
            percentage: others.percentage,
            fixedColor: WidgetColors.othersFill
        )
    }
}

/// Una fila de la leyenda: punto de su color, nombre, importe y porcentaje.
struct WidgetLegendRow: View {
    let item: WidgetBreakdownItem
    let currencyCode: String
    let displayFormat: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: WidgetDS.Spacing.sm) {
            Circle()
                .fill(item.color)
                .frame(width: WidgetDS.Chart.legendDot, height: WidgetDS.Chart.legendDot)
                .accessibilityHidden(true)

            Text(item.name)
                .font(WidgetDS.Typography.labelSmall)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: WidgetDS.Spacing.xs)

            // Sin «≈»: como las filas del ranking, un subconjunto sin señal propia (`fx-category-totals-unmarked`).
            WidgetAmountText(
                value: item.amount,
                currencyCode: currencyCode,
                displayFormat: displayFormat,
                font: WidgetDS.Typography.labelSmall,
                secondaryFont: WidgetDS.Typography.captionSmall
            )
            .fixedSize()

            Text(WidgetPercentText.text(item.percentage))
                .font(WidgetDS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .frame(minWidth: WidgetDS.Chart.legendPercentWidth, alignment: .trailing)
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sin gastos

/// «Sin gastos en este período», legible y centrado (antes, gris terciario con un icono de bandeja).
struct WidgetBreakdownEmpty: View {
    var body: some View {
        Text("widget.ui.noExpenses", bundle: .main)
            .font(WidgetDS.Typography.label)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
