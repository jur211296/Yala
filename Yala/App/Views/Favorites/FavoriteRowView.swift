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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                // Icon with category color
                favoriteIcon

                // Text content
                VStack(alignment: .leading, spacing: 3) { // DS: intentional non-token value
                    // Line 1: Favorite name
                    Text(favorite.name)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Line 2: Subcategory • Account (or placeholders)
                    secondaryLine

                    // Line 3: Tags (if any)
                    if !(favorite.tags ?? []).isEmpty {
                        tagsRow
                    }
                }

                Spacer()

                // Right column: Amount + Nature (if set)
                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    if let amount = favorite.amount, amount > 0 {
                        Text(formattedAmount)
                            .font(DS.Typography.headline)
                            .foregroundStyle(amountColor)
                    }

                    if let nature = favorite.effectiveNature {
                        natureIndicator(for: nature)
                    }
                }
            }
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.FormRow.paddingV)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : DS.Opacity.faint),
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Components

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            .fill(Color.yalaCard)
    }

    private var favoriteIcon: some View {
        let colorHex =
            favorite.subcategory?.category?.colorHex
            ?? favorite.subcategory?.colorHex
            ?? "#6366F1"
        let iconName =
            favorite.subcategory?.iconName
            ?? favorite.subcategory?.category?.iconName
            ?? "star.fill"

        return ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 40, height: 40)

            Image(systemName: iconName)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
        }
    }

    private var secondaryLine: some View {
        let parts: [String] = [
            favorite.subcategory?.name,
            favorite.account?.name,
        ].compactMap { $0 }

        let text = parts.isEmpty ? L10n.Favorites.notConfigured : parts.joined(separator: " • ")

        return Text(text)
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var tagsRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array((favorite.tags ?? []).prefix(3)), id: \.persistentModelID) { tag in
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

            if (favorite.tags ?? []).count > 3 {
                Text("+\((favorite.tags ?? []).count - 3)")
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func natureIndicator(for nature: SubcategoryNature) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(nature.color)
                .frame(width: 6, height: 6)

            Text(nature.displayName)
                .font(DS.Typography.labelTiny)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Chip.paddingV)
        .padding(.vertical, DS.Spacing.xxs)
        .background(
            Capsule()
                .fill(nature.color.opacity(0.1))
        )
    }

    // MARK: - Helpers

    private var formattedAmount: String {
        guard let amount = favorite.amount else { return "" }
        let code = favorite.currencyCode ?? CurrencyDefaults.defaultCode
        return YalaFormatter.currency(value: amount, currencyCode: code, forceFullPrecision: true)
    }

    private var amountColor: Color {
        favorite.type == .income ? Color.electricIndigo : Color.hotPink
    }
}
