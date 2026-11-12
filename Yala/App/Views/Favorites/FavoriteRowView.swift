//
//  FavoriteRowView.swift
//  Yala
//
//  Card-based row for favorite payment templates.
//

import SwiftData
import SwiftUI

// MARK: - Favorite Row View

/// Card-style row for a favorite payment template
struct FavoriteRowView: View {
    let favorite: FavoritePayment
    let onTap: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.tagCatalog) private var tagCatalog
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onTap) {
            rowContent
                .padding(.vertical, DS.Spacing.md)
                .padding(.horizontal, DS.FormRow.paddingV)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .shadow(
                    color: Color.black.opacity(theme.shadowOpacity),
                    radius: 6,
                    x: 0,
                    y: 3
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Components

    /// Con texto de accesibilidad el importe (y su necesidad) baja a su propia línea, entero: al lado del nombre se partía
    /// en «S/ / 3,000. / 00» (decisión 63 de la revisión 2.3, el molde de «Esto entendí» en 2.2). A tamaño normal, la
    /// fila de siempre, con los mismos hijos en el mismo `HStack`.
    @ViewBuilder
    private var rowContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.md) {
                    favoriteIcon
                    rowTexts
                }
                if hasAmountColumn {
                    amountColumn(alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: DS.Spacing.md) {
                // Icon with category color
                favoriteIcon

                // Text content
                rowTexts

                Spacer()

                // Right column: Amount + Nature (if set)
                amountColumn(alignment: .trailing)
            }
        }
    }

    private var rowTexts: some View {
        VStack(alignment: .leading, spacing: 3) { // DS: intentional non-token value
            // Line 1: Favorite name
            Text(favorite.name)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .accessibilityIdentifier("favorite_row_name_\(favorite.name)")

            // Line 2: Subcategory • Account (or placeholders)
            secondaryLine

            // Line 3: Tags (if any) — resolved via CSV-mirror SSOT + catalog.
            let resolvedTags = TagDisplayResolver.tags(for: favorite, catalog: tagCatalog, order: appPreferences.tagsSortOrderNames)
            if !resolvedTags.isEmpty {
                tagsRow(resolvedTags)
            }
        }
    }

    private var hasAmountColumn: Bool {
        (favorite.amount ?? 0) > 0 || favorite.effectiveNeed != nil
    }

    private func amountColumn(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: DS.Spacing.xs) {
            if let amount = favorite.amount, amount > 0 {
                Text(formattedAmount)
                    .font(DS.Typography.headline)
                    .foregroundStyle(amountColor)
                    .accessibilityIdentifier("favorite_row_amount_\(favorite.name)")
            }

            if let need = favorite.effectiveNeed {
                needIndicator(for: need)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            .fill(.thCard)
    }

    /// Icono y color de su categoría; los de transferencia, los de transferencia (UX 2.2 · L2-14). Los comparte con
    /// la fila de chips del formulario (`FavoriteChipStyle`).
    private var favoriteIcon: some View {
        let style = FavoriteChipStyle(favorite: favorite)
        return ZStack {
            Circle()
                .fill(style.color)
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

            Image(systemName: style.iconName)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
        }
    }

    private var secondaryLine: some View {
        let text: String
        if favorite.type == .transfer {
            text = FavoriteRowLine.transfer(origin: favorite.account?.name, destination: favorite.destinationAccount?.name)
        } else {
            let parts: [String] = [
                favorite.subcategory?.name,
                favorite.account?.name,
            ].compactMap { $0 }
            text = parts.isEmpty ? L10n.Favorites.notConfigured : parts.joined(separator: " • ")
        }

        return Text(text)
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func tagsRow(_ tags: [Tag]) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(tags.prefix(3)), id: \.persistentModelID) { tag in
                Text(tag.name)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(Color.contrastingText(for: Color(hex: tag.colorHex)))
                    .padding(.horizontal, DS.Chip.paddingV)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(Color(hex: tag.colorHex))
                    )
            }

            if tags.count > 3 {
                Text("+\(tags.count - 3)")
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func needIndicator(for need: SubcategoryNeed) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(need.color)
                .frame(width: 6, height: 6)

            Text(need.displayName)
                .font(DS.Typography.labelTiny)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Chip.paddingV)
        .padding(.vertical, DS.Spacing.xxs)
        .background(
            Capsule()
                .fill(need.color.opacity(0.1))
        )
    }

    // MARK: - Helpers

    private var formattedAmount: String {
        guard let amount = favorite.amount else { return "" }
        let code = favorite.currencyCode ?? CurrencyDefaults.defaultCode
        return appPreferences.currency(amount, currencyCode: code, forceFullPrecision: true)
    }

    private var amountColor: Color {
        Color.amountTint(isIncome: favorite.type == .income)
    }
}

/// La segunda línea de un favorito de transferencia (decisión 72 de la revisión 2.3). «Cuenta Principal → Ahorros» con
/// las dos cuentas; con una sola (un favorito de antes de 2.2 no tiene destino), su nombre, sin «→ …»; sin ninguna,
/// «Transferencia».
enum FavoriteRowLine {
    static func transfer(origin: String?, destination: String?) -> String {
        switch (origin, destination) {
        case let (origin?, destination?): return "\(origin) → \(destination)"
        case let (origin?, nil): return origin
        case let (nil, destination?): return destination
        case (nil, nil): return TransactionType.transfer.displayName
        }
    }
}
