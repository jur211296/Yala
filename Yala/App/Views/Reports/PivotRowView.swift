//
//  PivotRowView.swift
//  Yala
//
//  Row view for a single pivot table node with indentation.
//
//  UX 2.2 · L18-3 (variante 3): una cabecera nombra el período y el cambio (`PivotHeaderRow`), bajo cada monto va el
//  anterior con su nombre («en 1–21 sept S/ 11,249») y VoiceOver lee de qué período es cada monto. Con tres columnas
//  separadas (la captura de la variante, con solo dos filas) los nombres de las categorías se cortaban; el texto de la
//  decisión pide «en setiembre» bajo cada monto, que es lo que cabe. L18-4: los gastos van sin signo menos.
//

import SwiftUI

/// Los anchos de las columnas de la tabla, compartidos por la cabecera y las filas para que casen.
struct PivotColumnWidths {
    let current: CGFloat
    let change: CGFloat
}

struct PivotRowView: View {

    let node: PivotNode
    let level: Int
    let preferredCurrency: String
    /// `false` en «Todo el tiempo»: no hay período anterior y el chip diría «N/A» en cada fila.
    var showsComparison: Bool = true
    let widths: PivotColumnWidths
    /// Nombres de los dos períodos, para lo que lee VoiceOver («S/ 12,666 en octubre, S/ 9,976 en setiembre»).
    var currentPeriodName: String = ""
    var previousPeriodName: String = ""
    /// El período anterior en corto («1–21 sept», «Septiembre»), para el «en …» bajo cada monto.
    var previousPeriodColumnName: String = ""

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var showVariations: Bool { appPreferences.showVariations }

    /// Currency to use for formatting this node
    private var displayCurrency: String {
        node.currencyCode ?? preferredCurrency
    }

    /// Un gasto se pinta en positivo: ya está bajo «Gastos». Si en ese período entró más de lo que salió (devoluciones),
    /// sale con signo menos, que es lo que pasó.
    private var shownAmount: Double { node.isIncome ? node.amount : -node.amount }
    private var shownPrevious: Double? { node.previousAmount.map { node.isIncome ? $0 : -$0 } }

    var body: some View {
        rowContent
            .padding(.leading, DS.Spacing.lg + CGFloat(max(0, level - 1)) * (DS.Spacing.lg / 2))
            .padding(.trailing, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityIdentifier("pivot_row_\(node.dimension.rawValue)_\(node.label)")
    }

    /// Con texto de accesibilidad la fila se apila: el nombre a todo lo ancho y las cifras debajo. En una sola fila la
    /// cifra (con prioridad) dejaba al nombre sin sitio y desaparecía, y aun así se cortaba («S/3,….00»; lote 05 de 2.3,
    /// zona 36 P5). A tamaño normal, la fila de siempre.
    @ViewBuilder
    private var rowContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    iconView
                    nameText
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    currentAmount
                    Spacer(minLength: DS.Spacing.sm)
                    variationChip(minWidth: nil)
                }
                if showsComparison {
                    previousLine
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: DS.Spacing.sm) {
                iconView

                nameText
                    // Con el monto anterior debajo, la fila ya tiene dos líneas: el nombre largo usa la segunda en vez
                    // de cortarse («Supermerca…»).
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // El monto del período y, debajo, el anterior con su nombre («en 1–21 sept S/ 11,249»): con tres
                // columnas los nombres de las subcategorías se cortaban («Factura…»).
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    currentAmount

                    if showsComparison {
                        previousLine
                    }
                }
                .frame(minWidth: widths.current, alignment: .trailing)
                // Con la fila justa (texto grande) cede el nombre y no la cifra.
                .layoutPriority(1)

                variationChip(minWidth: widths.change)
            }
        }
    }

    private var nameText: some View {
        Text(node.label)
            .font(level == 0 ? DS.Typography.label : DS.Typography.caption)
            .fontWeight(level == 0 ? .semibold : .regular)
            .foregroundStyle(.primary)
    }

    private var currentAmount: some View {
        AmountText(
            value: shownAmount,
            currencyCode: displayCurrency,
            font: level == 0
                ? DS.Typography.label.weight(.semibold)
                : DS.Typography.labelSmall.weight(.medium),
            isEstimate: node.isApproximate
        )
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// «en 1–21 sept S/ 11,249»: el monto del período anterior con su nombre.
    private var previousLine: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Text(L10n.UXL18.inPeriod(previousPeriodColumnName))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            if let previous = shownPrevious {
                AmountText(
                    value: previous,
                    currencyCode: displayCurrency,
                    font: DS.Typography.captionSmall,
                    secondaryFont: DS.Typography.captionSmall,
                    tint: .secondary,
                    isEstimate: node.previousIsApproximate
                )
                .lineLimit(1)
            } else {
                Text("—")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }
        }
        .minimumScaleFactor(0.6)
    }

    /// `minWidth`: la columna «Cambio» en la fila de siempre; apilada, sin columna.
    @ViewBuilder
    private func variationChip(minWidth: CGFloat?) -> some View {
        if showsComparison && showVariations {
            VariationChip(
                variation: node.variation,
                size: .small,
                showNAWhenNil: node.previousAmount == nil,
                isExpenseContext: !node.isIncome,
                usesWords: true
            )
            // Un cambio largo («+385.2%») no se parte en dos líneas: la columna crece y el nombre cede.
            .fixedSize()
            .frame(minWidth: minWidth, alignment: .trailing)
        }
    }

    /// Lo que lee VoiceOver: el nombre, cada monto con su período y el cambio («Sin cambio» si no cambió).
    private var accessibilityText: String {
        let current = appPreferences.currency(shownAmount, currencyCode: displayCurrency, isEstimate: node.isApproximate)
        guard showsComparison else { return "\(node.label), \(current)" }
        let previous = shownPrevious.map {
            appPreferences.currency($0, currencyCode: displayCurrency, isEstimate: node.previousIsApproximate)
        } ?? "—"
        var parts = [node.label, L10n.UXL18.rowAmountsA11y(current, currentPeriodName, previous, previousPeriodName)]
        if showVariations, let variation = node.variation {
            parts.append(VariationChip.accessibilityText(for: variation))
        } else if showVariations, node.previousAmount == nil {
            // Sin nada antes, el chip dice «nuevo» (decisión 32 de 2.3); VoiceOver también.
            parts.append(L10n.UXL18.changeNew)
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Icon View

    @ViewBuilder
    private var iconView: some View {
        if node.dimension.isEntityDimension, let colorHex = node.colorHex, let iconName = node.iconName {
            // Entity dimension: colored circle with white icon
            let badgeSize = level == 0 ? DS.Icon.badgeMedium : DS.Icon.badgeSmall
            let iconSize = level == 0 ? DS.Icon.sizeMedium : DS.Icon.sizeSmall

            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: badgeSize, height: badgeSize)

                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(.white)
            }
        } else if let colorHex = node.colorHex {
            // Has color but no icon (or non-entity) — color dot
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)
        } else if let iconName = node.iconName {
            // Non-entity dimension icon (tipo, divisa, naturaleza)
            Image(systemName: iconName)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(node.isIncome ? Color.electricIndigo : Color.hotPink)
                .frame(width: DS.Chip.dotSize)
        }
    }
}

/// La cabecera de las columnas de la tabla (UX 2.2 · L18-3): el período que se mira sobre los montos y «Cambio» sobre
/// los chips. El anterior lo dice cada fila («en septiembre …»).
struct PivotHeaderRow: View {
    let currentName: String
    let widths: PivotColumnWidths

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stackedHeader
        } else {
            columnsHeader
        }
    }

    /// Con texto de accesibilidad las filas se apilan (cifra a la izquierda, cambio a la derecha) y la cabecera sigue
    /// esa forma: con sus columnas fijas «Cambio» se salía por la derecha (lote 05 de 2.3, zona 36 P5).
    private var stackedHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(currentName)
                .font(DS.Typography.captionSmall.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: DS.Spacing.sm)
            if appPreferences.showVariations {
                Text(L10n.UXL18.columnChange)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityHidden(true)
        .accessibilityIdentifier("pivot_header_row")
    }

    private var columnsHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            Spacer(minLength: 0)
            Text(currentName)
                .font(DS.Typography.captionSmall.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: widths.current, alignment: .trailing)
            if appPreferences.showVariations {
                Text(L10n.UXL18.columnChange)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: widths.change, alignment: .trailing)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityHidden(true)
        .accessibilityIdentifier("pivot_header_row")
    }
}
