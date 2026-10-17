//
//  FilterChipView.swift
//  Yala
//
//  Unified filter chip component for displaying applied filters.
//  Used across PanelView, TrendsTabView, CategoriesTabView, and RecordsTabView.
//

import SwiftUI

/// Filter chip indicator type
enum FilterChipIndicator {
    case none
    case colorDot(Color)
    case iconWithColor(iconName: String, color: Color)
    case iconOnly(iconName: String)  // Icon without background color
}

/// Reusable filter chip showing applied filter with clear action
struct FilterChipView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let text: String
    var indicator: FilterChipIndicator = .none
    var isExcludeMode: Bool = false
    /// Tocar la cápsula (fuera de la X) abre la hoja de Filtros del host (UX 2.2 · L8-17). `nil`: no hace nada, como
    /// antes; la X sigue quitando el filtro con su propia área de toque.
    var onOpen: (() -> Void)? = nil
    let onClear: () -> Void

    /// Lo que dice la cápsula: «Sin Ahorros USD» si se está ocultando. Un «−» de 9 pt no decía «excluido» y
    /// «Ahorros USD» bajo «Filtros aplicados» se leía como «solo Ahorros USD» (L8-17).
    static func displayText(_ text: String, isExcluded: Bool) -> String {
        isExcluded ? L10n.UXL8C.Chip.excluded(text) : text
    }

    private var displayText: String { Self.displayText(text, isExcluded: isExcludeMode) }

    var body: some View {
        HStack(spacing: DS.Chip.spacing) {
            if let onOpen {
                Button(action: onOpen) {
                    chipLabel
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(displayText)
                .accessibilityValue(isExcludeMode ? L10n.UXL8C.Chip.excludedValue : "")
                .accessibilityHint(L10n.UXL8C.Chip.openHint)
                .accessibilityIdentifier("applied_filter_chip")
            } else {
                chipLabel
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(displayText)
                    .accessibilityValue(isExcludeMode ? L10n.UXL8C.Chip.excludedValue : "")
            }

            Button {
                dsWithAnimation(reduceMotion) {
                    onClear()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(DS.Typography.chipClose)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Accessibility.removeFilter)
        }
        .padding(.horizontal, DS.Chip.paddingH)
        .padding(.vertical, DS.Chip.paddingV)
        // Lo oculto lleva contorno rojo: el texto sigue en `.primary`, que sí se lee sobre el cristal. Va ANTES del
        // `glassEffect`, como contenido: colgado después, el cristal lo tapaba y no se veía (medido en el simulador).
        .overlay {
            if isExcludeMode {
                Capsule()
                    .strokeBorder(DS.Semantic.errorForeground, lineWidth: 1.5)
                    .accessibilityHidden(true)
            }
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .pointerHighlight(cornerRadius: nil)
    }

    private var chipLabel: some View {
        HStack(spacing: DS.Chip.spacing) {
            // Indicator (icon or color dot)
            indicatorView

            Text(displayText)
                .font(DS.Typography.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    /// Fluent API: tocar la cápsula abre Filtros.
    func opensFilters(_ action: (() -> Void)?) -> FilterChipView {
        var copy = self
        copy.onOpen = action
        return copy
    }

    /// Fluent API to set exclude mode on any chip
    func excludeMode(_ isExclude: Bool) -> FilterChipView {
        var copy = self
        copy.isExcludeMode = isExclude
        return copy
    }

    @ViewBuilder
    private var indicatorView: some View {
        switch indicator {
        case .none:
            EmptyView()
        case .colorDot(let color):
            Circle()
                .fill(color)
                .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)
        case .iconWithColor(let iconName, let color):
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: DS.Chip.iconCircleSize, height: DS.Chip.iconCircleSize)
                Image(systemName: iconName)
                    .font(DS.Typography.chipIcon)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
        case .iconOnly(let iconName):
            Image(systemName: iconName)
                .font(DS.Typography.chipIconOnly)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Unified Convenience Initializers

extension FilterChipView {

    // MARK: - Account chip (icon, no color, supports count)

    /// Account filter chip with icon, supports grouping
    /// - Format: "Cuenta" or "Cuenta +N"
    init(
        accountName: String,
        count: Int = 1,
        onClear: @escaping () -> Void
    ) {
        self.text = count > 1 ? "\(accountName) +\(count - 1)" : accountName
        self.indicator = .iconOnly(iconName: "creditcard.fill")
        self.onClear = onClear
    }

    // MARK: - Category chip (icon + color, supports count)

    /// Category filter chip with icon and color
    /// - Format: "Categoría" or "Primera +N" with icon/color of first category
    init(
        categoryName: String,
        iconName: String?,
        colorHex: String,
        count: Int = 1,
        onClear: @escaping () -> Void
    ) {
        self.text = count > 1 ? "\(categoryName) +\(count - 1)" : categoryName
        self.indicator = .iconWithColor(
            iconName: iconName ?? "tag.fill",
            color: Color(hex: colorHex)
        )
        self.onClear = onClear
    }

    // MARK: - Subcategory chip (icon + color, supports count)

    /// Subcategory filter chip with icon and color
    /// - Format: "Subcategoría" or "Primera +N" with icon/color of first subcategory
    init(
        subcategoryName: String,
        iconName: String?,
        colorHex: String?,
        count: Int = 1,
        onClear: @escaping () -> Void
    ) {
        self.text = count > 1 ? "\(subcategoryName) +\(count - 1)" : subcategoryName
        self.indicator = .iconWithColor(
            iconName: iconName ?? "list.bullet.indent",
            color: Color(hex: colorHex ?? AppConstants.defaultColorHex)
        )
        self.onClear = onClear
    }

    // MARK: - Nature chip (color dot, always individual)

    /// Nature filter chip with color dot
    /// - Each need is shown as a separate chip
    init(
        need: SubcategoryNeed,
        onClear: @escaping () -> Void
    ) {
        self.text = need.displayName
        self.indicator = .colorDot(need.color)
        self.onClear = onClear
    }

    // MARK: - Transaction Nature chip (income/expense with color dot)

    /// Transaction nature filter chip with color dot
    /// - Shows "Ingresos" or "Gastos" with teal/pink dot
    init(
        transactionNature: TransactionNature,
        onClear: @escaping () -> Void
    ) {
        self.text = transactionNature.displayName
        self.indicator = .colorDot(transactionNature.color)
        self.onClear = onClear
    }

    // MARK: - Tag chip (icon + color, always individual)

    /// Tag filter chip with icon and color
    /// - Each tag is shown as a separate chip with its icon
    init(
        tagName: String,
        iconName: String?,
        colorHex: String?,
        onClear: @escaping () -> Void
    ) {
        self.text = tagName
        self.indicator = .iconWithColor(
            iconName: iconName ?? "tag.fill",
            color: Color(hex: colorHex ?? "#FF9F0A")
        )
        self.onClear = onClear
    }

    // MARK: - Currency chip (text only, supports count)

    /// Currency filter chip (text only)
    /// - Format: "USD" or "USD +N"
    init(
        currencyCode: String,
        count: Int = 1,
        onClear: @escaping () -> Void
    ) {
        self.text = count > 1 ? "\(currencyCode) +\(count - 1)" : currencyCode
        self.indicator = .none
        self.onClear = onClear
    }

    // MARK: - Amount chip (text only with condition symbol)

    /// Amount filter chip showing condition
    /// - Format: ">100" or "<50" or "=100" (truncated if too long)
    init(
        amountText: String,
        maxChars: Int = 12,
        onClear: @escaping () -> Void
    ) {
        let truncated =
            amountText.count > maxChars
            ? String(amountText.prefix(maxChars)) + "…"
            : amountText
        self.text = truncated
        self.indicator = .none
        self.onClear = onClear
    }

    // MARK: - Note/Search chip (text only, truncated)

    /// Note or search text filter chip
    /// - Truncated to maxChars with ellipsis
    init(
        noteText: String,
        maxChars: Int = 15,
        onClear: @escaping () -> Void
    ) {
        let truncated =
            noteText.count > maxChars
            ? String(noteText.prefix(maxChars)) + "…"
            : noteText
        self.text = "\"\(truncated)\""
        self.indicator = .none
        self.onClear = onClear
    }

    // MARK: - Simple text chip (backward compatible)

    /// Simple text chip without indicator
    init(text: String, onClear: @escaping () -> Void) {
        self.text = text
        self.indicator = .none
        self.onClear = onClear
    }

    /// Simple text chip with exclude mode support
    init(text: String, isExcludeMode: Bool, onClear: @escaping () -> Void) {
        self.text = text
        self.indicator = .none
        self.isExcludeMode = isExcludeMode
        self.onClear = onClear
    }

    /// Transaction nature chip with exclude mode support
    init(transactionNature: TransactionNature, isExcludeMode: Bool, onClear: @escaping () -> Void) {
        self.text = transactionNature.displayName
        self.indicator = .colorDot(transactionNature.color)
        self.isExcludeMode = isExcludeMode
        self.onClear = onClear
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.md) {
        FilterChipView(accountName: "BCP", onClear: {})
        FilterChipView(accountName: "BCP", count: 3, onClear: {})
        FilterChipView(
            categoryName: "Transporte",
            iconName: "car.fill",
            colorHex: "#FF6B6B",
            onClear: {}
        )
        FilterChipView(
            categoryName: "Transporte",
            iconName: "car.fill",
            colorHex: "#FF6B6B",
            count: 2,
            onClear: {}
        )
        FilterChipView(
            subcategoryName: "Uber",
            iconName: "app.fill",
            colorHex: AppConstants.defaultColorHex,
            onClear: {}
        )
        FilterChipView(
            need: .essential,
            onClear: {}
        )
        FilterChipView(
            tagName: "Vacaciones",
            iconName: "airplane",
            colorHex: "#22C55E",
            onClear: {}
        )
        FilterChipView(currencyCode: "USD", onClear: {})
        FilterChipView(currencyCode: "PEN", count: 2, onClear: {})
        FilterChipView(amountText: ">1000", onClear: {})
        FilterChipView(noteText: "compra de supermercado", onClear: {})
    }
    .padding()
    .background(.thCard)
}
