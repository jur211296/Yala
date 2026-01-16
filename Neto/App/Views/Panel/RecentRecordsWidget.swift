//
//  RecentRecordsWidget.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

struct RecentRecordsWidget: View {
    let records: [TransactionItem]
    let currencyCode: String

    // We keep 'size' compatible with init from PanelView but ignore it,
    // or we can remove it if we update PanelView.
    // Given the task is to "leave only M option", the view itself should just render M.
    // I will remove 'size' property and update PanelView callsite to be cleaner.

    var onShowMore: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            headerSection

            if records.isEmpty {
                emptyState
            } else {
                mediumLayout
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            Text(L10n.Records.latest)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            // Chevron always visible if action exists (since M size always has it)
            if onShowMore != nil {
                Button {
                    onShowMore?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Color.gray.opacity(0.7))
                        .padding(.leading, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Layout (Medium Style: 5 records)

    private var mediumLayout: some View {
        VStack(spacing: 10) {
            ForEach(Array(records.prefix(5).enumerated()), id: \.element.persistentModelID) {
                _, record in
                recordRow(record)
            }
        }
    }

    // MARK: - Record Rows

    private func recordRow(_ record: TransactionItem) -> some View {
        HStack(spacing: 10) {
            // Icon
            subcategoryIcon(for: record, size: 36)

            // Lines - Note, Subcategory • Account
            VStack(alignment: .leading, spacing: 2) {
                // Line 1: Note (bold) or Subcategory as fallback
                if let note = record.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Line 2: Subcategory • Account
                    Text(secondaryLine(for: record))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(
                        record.subcategory?.name ?? record.category?.name
                            ?? L10n.Common.uncategorized
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                    // Date as secondary
                    Text(shortDateFormat(record.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right Column: Amount + Nature (matches CompactRecordRow and RecordRowView)
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount(record.amount, currencyCode: record.currencyCode))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor(for: record))

                // Nature indicator (if available)
                if let subcategory = record.subcategory {
                    natureIndicator(for: subcategory.nature)
                }
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

    // MARK: - Subcategory Icon

    private func subcategoryIcon(for record: TransactionItem, size iconSize: CGFloat) -> some View {
        let colorHex =
            record.subcategory?.colorHex
            ?? record.category?.colorHex
            ?? "#6366F1"

        // Use subcategory icon if available, fallback to category icon, then default tag
        let iconName =
            record.subcategory?.iconName
            ?? record.category?.iconName
            ?? "tag.fill"

        return ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: iconSize, height: iconSize)

            Image(systemName: iconName)
                .font(.system(size: iconSize * 0.4))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Helpers

    private func secondaryLine(for record: TransactionItem) -> String {
        var parts: [String] = []

        // Show subcategory/category
        if record.note != nil && !(record.note?.isEmpty ?? true) {
            if let subcategory = record.subcategory {
                parts.append(subcategory.name)
            } else if let category = record.category {
                parts.append(category.name)
            }
        }

        // Then date (instead of account)
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateFormat = "d MMM"
        let dateStr = formatter.string(from: record.date).replacingOccurrences(of: ".", with: "")
        parts.append(dateStr)

        return parts.joined(separator: " • ")
    }

    private func amountColor(for record: TransactionItem) -> Color {
        let isIncome = record.category?.isIncome ?? (record.amount >= 0)
        return isIncome ? Color.electricIndigo : Color.hotPink
    }

    private func shortDateFormat(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private func formattedAmount(_ value: Double, currencyCode: String) -> String {
        NetoFormatter.currency(value: value, currencyCode: currencyCode)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.bottom, DS.Spacing.xs)

            Text(L10n.Widget.noRecordsForFilters)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text(L10n.Widget.recordsWillAppear)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
    }
}
