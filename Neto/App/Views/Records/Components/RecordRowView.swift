//
//  RecordRowView.swift
//  Neto
//
//  Created by Neto - Records Feature.
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            if isSelectionMode {
                onToggleSelection()
            } else {
                onTap()
            }
        } label: {
            HStack(spacing: 12) {
                // Selection circle (only in selection mode)
                if isSelectionMode {
                    selectionCircle
                }

                // Subcategory icon with category color
                subcategoryIcon

                // Text content - reordered: Note, Subcategory • Account
                VStack(alignment: .leading, spacing: 3) {
                    // Line 1: Note (primary text) OR Category (if no note)
                    if let note = record.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        // Line 2: Category • Account (Compact)
                        let categoryName =
                            record.subcategory?.name ?? record.category?.name ?? "Sin categoría"
                        let accountName = record.account?.name ?? ""

                        Text("\(categoryName) • \(accountName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        // Fallback: Line 1 = Category
                        Text(record.subcategory?.name ?? record.category?.name ?? "Sin categoría")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        // Line 2: Account name
                        if let account = record.account {
                            Text(account.name)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }

                    // Line 4: Tags (if any)
                    if !record.tags.isEmpty {
                        tagsRow
                    }
                }

                Spacer()

                // Right column: Amount + Nature
                VStack(alignment: .trailing, spacing: 4) {
                    // Amount with currency
                    Text(formattedAmount)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(amountColor)

                    // Nature indicator
                    if let subcategory = record.subcategory {
                        natureIndicator(for: subcategory.nature)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06),
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(colorScheme == .dark ? Color(white: 0.12) : Color.white)
    }

    // MARK: - Selection Circle

    private var selectionCircle: some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected ? Color.electricIndigo : Color.secondary.opacity(0.3), lineWidth: 2
                )
                .frame(width: 24, height: 24)

            if isSelected {
                Circle()
                    .fill(Color.electricIndigo)
                    .frame(width: 24, height: 24)

                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Subcategory Icon

    private var subcategoryIcon: some View {
        // Use category color for the icon background
        let colorHex = record.category?.colorHex ?? "#6366F1"
        // Use income/expense arrow as the icon
        let iconName = record.category?.isIncome == true ? "arrow.down" : "arrow.up"

        return ZStack {
            Circle()
                .fill(Color(hex: colorHex).opacity(0.15))
                .frame(width: 40, height: 40)

            Image(systemName: iconName)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color(hex: colorHex))
        }
    }

    // MARK: - Tags Row

    private var tagsRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(record.tags.prefix(3)), id: \.persistentModelID) { tag in
                Text(tag.name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.contrastingText(for: Color(hex: tag.colorHex)))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(hex: tag.colorHex))
                    )
            }

            if record.tags.count > 3 {
                Text("+\(record.tags.count - 3)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Nature Indicator

    private func natureIndicator(for nature: SubcategoryNature) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(nature.color)
                .frame(width: 6, height: 6)

            Text(nature.displayName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(nature.color.opacity(0.1))
        )
    }

    // MARK: - Helpers

    private var formattedAmount: String {
        NetoFormatter.currency(value: record.amount, currencyCode: record.currencyCode)
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

        VStack(spacing: 12) {
            Text("RecordRowView Preview")
                .font(.headline)
        }
        .padding()
    }
}
