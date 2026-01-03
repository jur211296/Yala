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
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            if records.isEmpty {
                emptyState
            } else {
                mediumLayout
            }
        }
        .padding(DesignSystem.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
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

            // Lines - reordered: Note, Subcategory, Account
            VStack(alignment: .leading, spacing: 2) {
                // Line 1: Note (primary) or Subcategory as fallback
                if let note = record.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else {
                    Text(record.subcategory?.name ?? record.category?.name ?? "Sin categoría")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                // Line 2: Subcategory · Account (when note exists, show subcategory)
                Text(secondaryLine(for: record))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Right Column: Amount + Date
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount(record.amount, currencyCode: record.currencyCode))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor(for: record))

                Text(shortDateTime(record.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Subcategory Icon

    private func subcategoryIcon(for record: TransactionItem, size iconSize: CGFloat) -> some View {
        let colorHex =
            record.subcategory?.colorHex
            ?? record.category?.colorHex
            ?? "#6366F1"

        return ZStack {
            Circle()
                .fill(Color(hex: colorHex).opacity(0.15))
                .frame(width: iconSize, height: iconSize)

            Image(systemName: "tag.fill")
                .font(.system(size: iconSize * 0.4))
                .foregroundStyle(Color(hex: colorHex))
        }
    }

    // MARK: - Helpers

    private func secondaryLine(for record: TransactionItem) -> String {
        var parts: [String] = []

        // If note exists, show subcategory first
        if record.note != nil && !(record.note?.isEmpty ?? true) {
            if let subcategory = record.subcategory {
                parts.append(subcategory.name)
            } else if let category = record.category {
                parts.append(category.name)
            }
        }

        // Then account
        if let account = record.account {
            parts.append(account.name)
        }

        return parts.joined(separator: " · ")
    }

    private func amountColor(for record: TransactionItem) -> Color {
        let isIncome = record.category?.isIncome ?? (record.amount >= 0)
        return isIncome ? Color.electricIndigo : Color.hotPink
    }

    private func formattedAmount(_ value: Double, currencyCode: String) -> String {
        NetoFormatter.currency(value: value, currencyCode: currencyCode)
    }

    private func shortDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d MMM · HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.bottom, 4)

            Text("Aún no hay registros para este periodo y filtros")
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text("Cuando registres movimientos, aparecerán aquí.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}
