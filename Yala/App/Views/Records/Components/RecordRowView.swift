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
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tagCatalog) private var tagCatalog

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

                    // Line 4: Tags (if any) — resolved via CSV-mirror SSOT + catalog.
                    let resolvedTags = TagDisplayResolver.tags(for: record, catalog: tagCatalog)
                    if !resolvedTags.isEmpty {
                        tagsRow(resolvedTags)
                    }
                }

                Spacer()

                // Right column: Amount + Nature
                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    // Amount with currency
                    AmountText(
                        value: record.amount,
                        currencyCode: record.currencyCode,
                        font: DS.Typography.headline, secondaryFont: DS.Typography.caption,
                        tint: .color(amountColor),
                        forceFullPrecision: true
                    )

                    // Nature indicator + split badge
                    HStack(spacing: DS.Spacing.xs) {
                        if record.splitType != nil {
                            Image(systemName: "percent")
                                .font(DS.Typography.chipIcon)
                                .padding(.horizontal, DS.Chip.paddingV)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(Capsule().fill(Color.secondary.opacity(0.1)))
                        }
                        if let subcategory = record.subcategory {
                            needIndicator(for: subcategory.need)
                        }
                    }
                }
            }
            .listRowCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier("record_row")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        let note = record.note ?? ""
        let amount = appPreferences.currency(abs(record.amount), currencyCode: currencyCode)
        let category = record.subcategory?.name ?? record.category?.name ?? ""
        let account = record.account?.name ?? ""
        return "\(note), \(amount), \(category), \(account)"
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
                    .accessibilityHidden(true)
            }
        }
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Subcategory Icon

    /// Registro de grupo bridgeado que aún no tiene subcategoría — al tocarlo enruta a
    /// "asignar subcategoría". Se marca con un badge para señalar la acción pendiente.
    /// Excluye los registros manuales sin clasificar (su tap NO va al Inbox).
    private var needsClassification: Bool {
        record.splitExpenseID != nil && record.subcategory == nil
    }

    private var subcategoryIcon: some View {
        // Use category color for the icon background
        let colorHex = record.category?.colorHex ?? AppConstants.defaultColorHex
        // Use subcategory icon if available, fallback to category icon, then default tag
        let iconName =
            record.subcategory?.iconName
            ?? record.category?.iconName
            ?? "tag.fill"

        return ZStack {
            Circle()
                .fill(needsClassification ? Color.hotPink : Color(hex: colorHex))
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

            Image(systemName: needsClassification ? "exclamationmark" : iconName)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
        // Solo el badge de "falta clasificar" se anuncia en VoiceOver; el icono normal
        // queda oculto porque el texto de la fila ya nombra la categoría.
        .accessibilityElement()
        .accessibilityLabel(L10n.Inbox.needsSubcategory)
        .accessibilityHidden(!needsClassification)
    }

    // MARK: - Tags Row

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
                    .accessibilityHint(String(localized: "Tag"))
            }

            if tags.count > 3 {
                Text("+\(tags.count - 3)")
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Nature Indicator

    private func needIndicator(for need: SubcategoryNeed) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(need.color)
                .frame(width: DS.Chip.dotSize - 2, height: DS.Chip.dotSize - 2)

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
        // Individual records always show full precision (2 decimals) regardless of user preference
        appPreferences.currency(record.amount, currencyCode: record.currencyCode, forceFullPrecision: true)
    }

    private var amountColor: Color {
        let isIncome = record.category?.isIncome ?? (record.amount >= 0)
        return isIncome ? Color.electricIndigo : Color.hotPink
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        DS.Semantic.neutralBackground
            .ignoresSafeArea()

        VStack(spacing: DS.Spacing.md) {
            Text("RecordRowView Preview")
                .font(DS.Typography.headline)
        }
        .padding()
    }
}
