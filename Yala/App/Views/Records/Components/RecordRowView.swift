//
//  RecordRowView.swift
//  Yala
//
//  Created by Yala - Records Feature.
//

import SwiftData
import SwiftUI

// MARK: - Record Row View

/// Individual record card for the Records list - Card-based design with depth
struct RecordRowView: View {
    let record: TransactionItem
    let currencyCode: String
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onToggleSelection: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            if isSelectionMode {
                DS.Haptic.selection()
                onToggleSelection()
            } else {
                onTap()
            }
        } label: {
            HStack(spacing: DS.ListRow.spacing) {
                // Selection circle (only in selection mode)
                if isSelectionMode {
                    selectionCircle
                }

                // Subcategory icon with category color
                subcategoryIcon

                // Text content - reordered: Note, Subcategory • Account
                VStack(alignment: .leading, spacing: 3) { // DS: intentional non-token value
                    // Line 1: Note (primary text) OR Category (if no note)
                    if let note = record.note, !note.isEmpty {
                        Text(note)
                            .font(DS.Typography.label)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        // Line 2: Category • Account (Compact)
                        let categoryName =
                            record.subcategory?.name ?? record.category?.name ?? L10n.Common.uncategorized
                        let accountName = record.account?.name ?? ""

                        Text("\(categoryName) • \(accountName)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        // Fallback: Line 1 = Category
                        Text(record.subcategory?.name ?? record.category?.name ?? L10n.Common.uncategorized)
                            .font(DS.Typography.label)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        // Line 2: Account name
                        if let account = record.account {
                            Text(account.name)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }

                    // Line 4: Tags (if any)
                    if !(record.tags ?? []).isEmpty {
                        tagsRow
                    }
                }

                Spacer()

                // Right column: Amount + Nature
                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    // Amount with currency
                    Text(formattedAmount)
                        .font(DS.Typography.headline)
                        .foregroundStyle(amountColor)

                    // Nature indicator
                    if let subcategory = record.subcategory {
                        natureIndicator(for: subcategory.nature)
                    }
                }
            }
            .padding(.vertical, DS.ListRow.paddingV)
            .padding(.horizontal, DS.ListRow.paddingH)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .shadow(
                color: Color.black.opacity(theme.shadowOpacity),
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .fill(.thCard)
    }

    // MARK: - Selection Circle

    private var selectionCircle: some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected ? theme.accent : Color.secondary.opacity(0.3), lineWidth: 2
                )
                .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)

            if isSelected {
                Circle()
                    .fill(theme.accent)
                    .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                    .transition(.scale.combined(with: .opacity))

                Image(systemName: "checkmark")
                    .font(DS.Typography.badgeLabel)
                    .foregroundStyle(.white)
                    .transition(.scale)
            }
        }
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Subcategory Icon

    private var subcategoryIcon: some View {
        // Use category color for the icon background
        let colorHex = record.category?.colorHex ?? "#6366F1"
        // Use subcategory icon if available, fallback to category icon, then default tag
        let iconName =
            record.subcategory?.iconName
            ?? record.category?.iconName
            ?? "tag.fill"

        return ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

            Image(systemName: iconName)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Tags Row

    private var tagsRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array((record.tags ?? []).prefix(3)), id: \.persistentModelID) { tag in
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

            if (record.tags ?? []).count > 3 {
                Text("+\((record.tags ?? []).count - 3)")
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Nature Indicator

    private func natureIndicator(for nature: SubcategoryNature) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(nature.color)
                .frame(width: DS.Chip.dotSize - 2, height: DS.Chip.dotSize - 2)

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
        // Individual records always show full precision (2 decimals) regardless of user preference
        YalaFormatter.currency(value: record.amount, currencyCode: record.currencyCode, forceFullPrecision: true)
    }

    private var amountColor: Color {
        let isIncome = record.category?.isIncome ?? (record.amount >= 0)
        return isIncome ? Color.electricIndigo : Color.hotPink
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()

        VStack(spacing: DS.Spacing.md) {
            Text("RecordRowView Preview")
                .font(DS.Typography.headline)
        }
        .padding()
    }
}
