//
//  RecentRecordsWidget.swift
//  Yala
//
//  Created by Yala Refactoring.
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

    // MARK: - Static Formatters (avoid recreation on each render)

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private static let secondaryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            headerSection

            if records.isEmpty {
                emptyState
            } else {
                mediumLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(.regular, radius: DS.Radius.xl, padding: DS.Spacing.xl)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            Text(L10n.Records.latest)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            InfoHintButton(
                title: L10n.WidgetType.latestRecords,
                message: L10n.Widget.Hint.recentRecords
            )

            Spacer()

            // Chevron always visible if action exists (since M size always has it)
            if onShowMore != nil {
                Button {
                    onShowMore?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, DS.Spacing.xs)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Accessibility.viewAllRecords)
            }
        }
    }

    // MARK: - Layout (Medium Style: 5 records)

    private var mediumLayout: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(Array(records.prefix(5).enumerated()), id: \.element.persistentModelID) {
                _, record in
                recordRow(record)
            }
        }
    }

    // MARK: - Record Rows

    private func recordRow(_ record: TransactionItem) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon
            subcategoryIcon(for: record, size: 36)

            // Lines - Note, Subcategory • Account
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                // Line 1: Note (bold) or Subcategory as fallback
                if let note = record.note, !note.isEmpty {
                    Text(note)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Line 2: Subcategory • Account
                    Text(secondaryLine(for: record))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(
                        record.subcategory?.name ?? record.category?.name
                            ?? L10n.Common.uncategorized
                    )
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                    // Date as secondary
                    Text(shortDateFormat(record.date))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right Column: Amount + Nature (matches CompactRecordRow and RecordRowView)
            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                Text(formattedAmount(record.amount, currencyCode: record.currencyCode))
                    .font(DS.Typography.headline)
                    .foregroundStyle(amountColor(for: record))

                // Nature indicator (if available)
                if let subcategory = record.subcategory {
                    needIndicator(for: subcategory.need)
                }
            }
        }
    }

    // MARK: - Nature Indicator

    private func needIndicator(for need: SubcategoryNeed) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(need.color)
                .frame(width: 6, height: 6)

            Text(need.displayName)
                .font(DS.Typography.labelTiny)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xxs)
        .background(
            Capsule()
                .fill(need.color.opacity(0.1))
        )
    }

    // MARK: - Subcategory Icon

    private func subcategoryIcon(for record: TransactionItem, size iconSize: CGFloat) -> some View {
        let colorHex =
            record.subcategory?.colorHex
            ?? record.category?.colorHex
            ?? AppConstants.defaultColorHex

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
                .font(.system(size: iconSize * 0.4)) // A11Y-DT: fixed size — icon from caller parameter
                .foregroundStyle(.white)
                .accessibilityHidden(true)
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
        let dateStr = Self.secondaryDateFormatter.string(from: record.date).replacing(".", with: "")
        parts.append(dateStr)

        return parts.joined(separator: " • ")
    }

    private func amountColor(for record: TransactionItem) -> Color {
        if record.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer { return Color(.label) }
        let isIncome = record.category?.isIncome ?? (record.amount >= 0)
        return isIncome ? Color.electricIndigo : Color.hotPink
    }

    private func shortDateFormat(_ date: Date) -> String {
        Self.shortDateFormatter.string(from: date).replacing(".", with: "")
    }

    private func formattedAmount(_ value: Double, currencyCode: String) -> String {
        YalaFormatter.currency(value: value, currencyCode: currencyCode, forceFullPrecision: true)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        YalaEmptyState(
            icon: "list.bullet.rectangle",
            title: L10n.Widget.noRecordsForFilters,
            message: L10n.Widget.recordsWillAppear,
            style: .widget
        )
    }
}
