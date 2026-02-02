//
//  InboxDraftRowView.swift
//  Neto
//
//  Fila individual para drafts en la bandeja de entrada.
//  Fase 8: Registro Inteligente
//

import SwiftData
import SwiftUI

struct InboxDraftRowView: View {
    let draft: InboxDraft
    let currencyCode: String
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.ListRow.spacing) {
                // Selection circle (only in selection mode)
                if isSelectionMode {
                    selectionCircle
                }

                // Icon: status-based for archived, subcategory-based for complete pending, source for incomplete
                leadingIcon

                // Text content - different layout based on completeness
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    if draft.hasAllRequiredFields {
                        // Complete draft: show like RecordRowView
                        completeContentView
                    } else {
                        // Incomplete draft: show missing fields
                        incompleteContentView
                    }
                }

                Spacer()

                // Amount column
                amountColumn
            }
            .padding(.vertical, DS.ListRow.paddingV)
            .padding(.horizontal, DS.ListRow.paddingH)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : DS.Opacity.faint),
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Complete Content View (like RecordRowView)

    @ViewBuilder
    private var completeContentView: some View {
        // Use display properties that fall back to cached values
        let subcategoryName = draft.displaySubcategoryName ?? L10n.Common.uncategorized
        let accountName = draft.displayAccountName ?? ""

        // Line 1: Note (primary text) OR Subcategory (if no note)
        if !draft.note.isEmpty {
            Text(draft.note)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Line 2: Subcategory • Account
            Text("\(subcategoryName) • \(accountName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            // Fallback: Line 1 = Subcategory
            Text(subcategoryName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Line 2: Account name
            if !accountName.isEmpty {
                Text(accountName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }

        // Line 3: Tags (if any) - only for pending drafts (archived may have invalid tag references)
        if draft.status == .pending && !(draft.tags ?? []).isEmpty {
            tagsRow
        }
    }

    // MARK: - Incomplete Content View

    @ViewBuilder
    private var incompleteContentView: some View {
        // Line 1: Note or placeholder
        Text(draft.note.isEmpty ? L10n.Inbox.noDescription : draft.note)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(draft.note.isEmpty ? .secondary : .primary)
            .lineLimit(1)

        // Line 2: Missing fields indicators
        if !draft.needsUserInput.isEmpty {
            missingFieldsRow
        }

        // Line 3: Date
        Text(formattedDate)
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Amount Column

    private var amountColumn: some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
            if let amount = draft.amount {
                Text(YalaFormatter.currency(value: amount, currencyCode: currencyCode, forceFullPrecision: true))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amount >= 0 ? Color.electricIndigo : Color.hotPink)
            } else {
                Text(L10n.Inbox.noAmount)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Date for complete drafts, confidence for incomplete
            if draft.hasAllRequiredFields {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if let confidence = draft.confidenceAmount, confidence < 0.7 {
                // Confidence indicator for incomplete drafts with low confidence
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("\(Int(confidence * 100))%")
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Tags Row

    private var tagsRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array((draft.tags ?? []).prefix(3)), id: \.persistentModelID) { tag in
                Text(tag.name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.contrastingText(for: Color(hex: tag.colorHex)))
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(Color(hex: tag.colorHex))
                    )
            }

            if (draft.tags ?? []).count > 3 {
                Text("+\((draft.tags ?? []).count - 3)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }


    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .fill(Color.yalaCard)
    }

    // MARK: - Selection Circle

    private var selectionCircle: some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected ? Color.electricIndigo : Color.secondary.opacity(0.3),
                    lineWidth: 2
                )
                .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)

            if isSelected {
                Circle()
                    .fill(Color.electricIndigo)
                    .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)

                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Leading Icon

    @ViewBuilder
    private var leadingIcon: some View {
        switch draft.status {
        case .approved:
            // Show green check or warning if transaction was deleted
            if draft.wasTransactionDeleted {
                // Transaction was deleted - show warning icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                }
            } else {
                // Normal approved - show green check
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.green)
                }
            }

        case .rejected:
            // Show red X
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                Image(systemName: "xmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.red)
            }

        case .pending:
            // For pending: show subcategory icon if complete, source icon if incomplete
            if draft.hasAllRequiredFields {
                // Complete: show subcategory icon with category color (like RecordRowView)
                // Use display properties that fall back to cached values
                let colorHex = draft.displayCategoryColorHex
                let iconName = draft.displaySubcategoryIcon

                ZStack {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                    Image(systemName: iconName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                }
            } else {
                // Incomplete: show source type icon
                ZStack {
                    Circle()
                        .fill(sourceColor.opacity(0.15))
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                    Image(systemName: draft.sourceIcon)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(sourceColor)
                }
            }
        }
    }

    private var sourceColor: Color {
        switch draft.sourceType {
        case .voice:
            return .electricIndigo
        case .receiptPhoto:
            return .orange
        case .screenshotList, .screenshotSingle:
            return .teal
        case .emailAlert:
            return .blue
        case .scheduledPayment:
            return .purple
        case .subscription:
            return .indigo
        case .applePay:
            return .pink
        case .automation:
            return .gray
        }
    }

    // MARK: - Missing Fields Row

    private var missingFieldsRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(L10n.Inbox.missingLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(draft.needsUserInput.prefix(2), id: \.self) { field in
                Text(localizedFieldName(field))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(Color.hotPink.opacity(0.8))
                    )
            }

            if draft.needsUserInput.count > 2 {
                Text("+\(draft.needsUserInput.count - 2)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func localizedFieldName(_ field: String) -> String {
        switch field {
        case "account":
            return L10n.Inbox.needsAccount
        case "subcategory":
            return L10n.Inbox.needsSubcategory
        case "amount":
            return L10n.Inbox.noAmount
        default:
            return field
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let date = draft.effectiveDate
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return L10n.Date.today
        } else if calendar.isDateInYesterday(date) {
            return L10n.Date.yesterday
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = AppLocale.current
            return formatter.string(from: date)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.yalaBackground.ignoresSafeArea()

        VStack(spacing: DS.Spacing.md) {
            Text("InboxDraftRowView Preview")
                .font(.headline)
        }
        .padding()
    }
}
