//
//  InboxDraftRowView.swift
//  Yala
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

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

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
                color: Color.black.opacity(theme.shadowOpacity),
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Accessibility.draftRow(draft.note.isEmpty ? L10n.Inbox.noDescription : draft.note, draft.amount.map { appPreferences.currency($0, currencyCode: currencyCode) } ?? L10n.Inbox.noAmount, draft.status.rawValue))
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
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Line 2: Subcategory • Account
            Text("\(subcategoryName) • \(accountName)")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            // Fallback: Line 1 = Subcategory
            Text(subcategoryName)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Line 2: Account name
            if !accountName.isEmpty {
                Text(accountName)
                    .font(DS.Typography.caption)
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
            .font(DS.Typography.label)
            .foregroundStyle(draft.note.isEmpty ? .secondary : .primary)
            .lineLimit(1)

        // Line 2: Missing fields indicators
        if !draft.needsUserInput.isEmpty {
            missingFieldsRow
        }

        // Line 3: Date
        Text(formattedDate)
            .font(DS.Typography.caption)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Amount Column

    private var amountColumn: some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
            if let amount = draft.amount {
                Text(appPreferences.currency(amount, currencyCode: currencyCode, forceFullPrecision: true))
                    .font(DS.Typography.headline)
                    .foregroundStyle(amount >= 0 ? Color.electricIndigo : Color.hotPink)
            } else {
                Text(L10n.Inbox.noAmount)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
            }

            // Date for complete drafts, confidence for incomplete
            if draft.hasAllRequiredFields {
                Text(formattedDate)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            } else if let confidence = draft.confidenceAmount, confidence < 0.7 {
                // Confidence indicator for incomplete drafts with low confidence
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DS.Typography.captionSmall)
                    Text("\(Int(confidence * 100))%")
                        .font(DS.Typography.captionSmall)
                }
                .foregroundStyle(DS.Semantic.warningForeground)
            }
        }
    }

    // MARK: - Tags Row

    private var tagsRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array((draft.tags ?? []).prefix(3)), id: \.persistentModelID) { tag in
                Text(tag.name)
                    .font(DS.Typography.labelTiny)
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
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
        }
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
                    isSelected ? theme.accent : Color.secondary.opacity(0.3),
                    lineWidth: 2
                )
                .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)

            if isSelected {
                Circle()
                    .fill(theme.accent)
                    .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)

                Image(systemName: "checkmark")
                    .font(DS.Typography.badgeLabel)
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
                        .fill(DS.Semantic.warningBackground)
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Semantic.warningForeground)
                }
            } else {
                // Normal approved - show green check
                ZStack {
                    Circle()
                        .fill(DS.Semantic.successBackground)
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Semantic.successForeground)
                }
            }

        case .rejected:
            // Show red X
            ZStack {
                Circle()
                    .fill(DS.Semantic.errorBackground)
                    .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                Image(systemName: "xmark.circle.fill")
                    .font(DS.Typography.label)
                    .foregroundStyle(DS.Semantic.errorForeground)
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
                        .font(DS.Typography.label)
                        .foregroundStyle(.white)
                }
            } else {
                // Incomplete: show source type icon
                ZStack {
                    Circle()
                        .fill(sourceColor.opacity(0.15))
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

                    Image(systemName: draft.sourceIcon)
                        .font(DS.Typography.label)
                        .foregroundStyle(sourceColor)
                }
            }
        }
    }

    private var sourceColor: Color {
        switch draft.sourceType {
        case .voice:
            return .hotPink
        case .receiptPhoto, .screenshotList, .screenshotSingle:
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
        case .siri:
            return .blue
        }
    }

    // MARK: - Missing Fields Row

    private var missingFieldsRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(L10n.Inbox.missingLabel)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)

            ForEach(draft.needsUserInput.prefix(2), id: \.self) { field in
                Text(localizedFieldName(field))
                    .font(DS.Typography.labelTiny)
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
                    .font(DS.Typography.labelTiny)
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

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = AppLocale.current
        return f
    }()

    private var formattedDate: String {
        let date = draft.effectiveDate
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return L10n.Date.today
        } else if calendar.isDateInYesterday(date) {
            return L10n.Date.yesterday
        } else {
            return Self.mediumDateFormatter.string(from: date)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()

        VStack(spacing: DS.Spacing.md) {
            Text("InboxDraftRowView Preview")
                .font(DS.Typography.headline)
        }
        .padding()
    }
}
