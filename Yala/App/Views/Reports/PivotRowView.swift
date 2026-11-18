//
//  PivotRowView.swift
//  Yala
//
//  Row view for a single pivot table node with indentation.
//
//  UX 2.2 · L18-3 (variante 3): una cabecera nombra el período y el cambio (`PivotHeaderRow`). L18-4: los gastos van sin
//  signo menos.
//
//  Comparativa simple (pedido de Jürgen del 17-nov, variante A): cada fila se lee como una tabla dinámica. El monto actual
//  y, debajo, el anterior en pequeño, sin el «en 1–17 de oct.» repetido en cada fila: los dos períodos los nombra una sola
//  vez la cabecera, también en dos líneas. A la derecha, la marca de cambio con flecha y color
//  (`ComparisonChangeBadge`): verde si el cambio te favorece, rosa si no. En ventana ancha el anterior va en su columna.
//

import SwiftUI

/// Los anchos de las columnas de la tabla, compartidos por la cabecera y las filas para que casen.
struct PivotColumnWidths {
    let current: CGFloat
    let change: CGFloat
    /// La columna del período anterior en ventana ancha (`showsPreviousColumn`).
    var previous: CGFloat = 0

    /// Desde XXL la fila se apila (nombre arriba, cifras debajo). Con la marca de cambio de la Comparativa simple, a XXL
    /// el nombre se quedaba con ~50 pt y se partía por sílabas («Ingre-sos»), medido en el iPhone 17 Pro. La cabecera
    /// sigue la misma regla.
    static func stacks(_ size: DynamicTypeSize) -> Bool { size >= .xxLarge }
}

struct PivotRowView: View {

    let node: PivotNode
    let level: Int
    let preferredCurrency: String
    /// `false` en «Todo el tiempo»: no hay período anterior y la marca diría «nuevo» en cada fila.
    var showsComparison: Bool = true
    let widths: PivotColumnWidths
    /// Ventana ancha (iPad, Duo abierto): el monto anterior va en su propia columna en vez de debajo del actual.
    var showsPreviousColumn: Bool = false
    /// Nombres de los dos períodos, para lo que lee VoiceOver («S/ 12,666 en octubre, S/ 9,976 en setiembre»).
    var currentPeriodName: String = ""
    var previousPeriodName: String = ""
    /// El período anterior es un tramo de días: VoiceOver dice «frente al 1–17 de octubre».
    var previousIsDayRange: Bool = false
    /// El período anterior en corto («1–21 sept», «Septiembre»), para el «en …» de la fila apilada (texto grande).
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

    private var change: ComparisonChange {
        ComparisonChange.make(
            variation: node.variation,
            hasPrevious: node.previousAmount != nil,
            currentAmount: node.amount,
            isExpense: !node.isIncome
        )
    }

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

    /// Con texto grande (`PivotColumnWidths.stacks`) la fila se apila: el nombre a todo lo ancho, el monto con su marca debajo y el anterior
    /// con su nombre («en 1–21 sept S/ 11,249»), porque ahí la cabecera no tiene columnas. En una sola fila la cifra (con
    /// prioridad) dejaba al nombre sin sitio (lote 05 de 2.3, zona 36 P5). A tamaño normal, la tabla.
    @ViewBuilder
    private var rowContent: some View {
        if PivotColumnWidths.stacks(dynamicTypeSize) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    iconView
                    nameText
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    currentAmount
                    Spacer(minLength: DS.Spacing.sm)
                    changeBadge(minWidth: nil)
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

                if showsComparison && showsPreviousColumn {
                    currentAmount
                        .frame(minWidth: widths.current, alignment: .trailing)
                        .layoutPriority(1)
                    previousAmount
                        .frame(minWidth: widths.previous, alignment: .trailing)
                } else {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        currentAmount
                        if showsComparison {
                            previousAmount
                        }
                    }
                    .frame(minWidth: widths.current, alignment: .trailing)
                    // Con la fila justa cede el nombre y no la cifra.
                    .layoutPriority(1)
                }

                changeBadge(minWidth: widths.change)
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

    /// El monto del período anterior, en pequeño y gris: lo que dice de qué período es, lo dice la cabecera.
    @ViewBuilder
    private var previousAmount: some View {
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
            .minimumScaleFactor(0.6)
        } else {
            Text("—")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.tertiary)
        }
    }

    /// «en 1–21 sept S/ 11,249»: solo en la fila apilada (texto grande), donde la cabecera no nombra el anterior.
    private var previousLine: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Text(L10n.UXL18.inPeriod(previousPeriodColumnName))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            previousAmount
        }
        .minimumScaleFactor(0.6)
    }

    /// `minWidth`: la columna «Cambio» en la tabla; apilada, sin columna.
    @ViewBuilder
    private func changeBadge(minWidth: CGFloat?) -> some View {
        if showsComparison && showVariations {
            ComparisonChangeBadge(change: change)
                .frame(minWidth: minWidth, alignment: .trailing)
        }
    }

    /// Lo que lee VoiceOver: «Gastos, S/ 12,642, subió 27 % frente a octubre, antes S/ 9,976».
    private var accessibilityText: String {
        let current = appPreferences.currency(shownAmount, currencyCode: displayCurrency, isEstimate: node.isApproximate)
        guard showsComparison else { return "\(node.label), \(current)" }
        let previous = shownPrevious.map {
            appPreferences.currency($0, currencyCode: displayCurrency, isEstimate: node.previousIsApproximate)
        }
        guard showVariations else {
            return [node.label, L10n.UXL18.rowAmountsA11y(current, currentPeriodName, previous ?? "—", previousPeriodName)]
                .joined(separator: ", ")
        }
        var parts = [node.label, current]
        let versus = ComparativaSimpleText.versus(previousPeriodName, isDayRange: previousIsDayRange)
        parts.append(change.accessibilityText(versus: versus))
        if let previous { parts.append(ComparativaSimpleText.before(previous)) }
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

/// La cabecera de las columnas de la tabla. Sobre los montos, los dos períodos en dos líneas, igual que cada fila: el
/// actual arriba y el anterior debajo, en gris («1–17 nov» / «1–17 oct»). En ventana ancha, uno por columna. Y «Cambio»
/// sobre las marcas.
struct PivotHeaderRow: View {
    let currentName: String
    /// El período anterior en corto; vacío si no se compara (no hay cabecera entonces).
    var previousName: String = ""
    let widths: PivotColumnWidths
    var showsPreviousColumn: Bool = false

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if PivotColumnWidths.stacks(dynamicTypeSize) {
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
            if showsPreviousColumn {
                currentTitle
                    .frame(minWidth: widths.current, alignment: .trailing)
                previousTitle
                    .frame(minWidth: widths.previous, alignment: .trailing)
            } else {
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    currentTitle
                    if !previousName.isEmpty { previousTitle }
                }
                .frame(minWidth: widths.current, alignment: .trailing)
            }
            if appPreferences.showVariations {
                Text(L10n.UXL18.columnChange)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minWidth: widths.change, alignment: .trailing)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityHidden(true)
        .accessibilityIdentifier("pivot_header_row")
    }

    private var currentTitle: some View {
        Text(currentName)
            .font(DS.Typography.captionSmall.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var previousTitle: some View {
        Text(previousName)
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
