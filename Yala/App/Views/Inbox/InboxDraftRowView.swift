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
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.ListRow.spacing) {
                // Source type icon
                sourceIcon

                // Text content
                VStack(alignment: .leading, spacing: 3) {
                    // Line 1: Note or placeholder
                    Text(draft.note.isEmpty ? L10n.Common.uncategorized : draft.note)
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

                Spacer()

                // Amount
                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    if let amount = draft.amount {
                        Text(YalaFormatter.currency(value: amount, currencyCode: currencyCode))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(amount >= 0 ? Color.electricIndigo : Color.hotPink)
                    } else {
                        Text(L10n.Inbox.noAmount)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    // Confidence indicator (if low)
                    if let confidence = draft.confidenceAmount, confidence < 0.7 {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("\(Int(confidence * 100))%")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                    }
                }
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

    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .fill(Color.yalaCard)
    }

    // MARK: - Source Icon

    private var sourceIcon: some View {
        ZStack {
            Circle()
                .fill(sourceColor.opacity(0.15))
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

            Image(systemName: draft.sourceIcon)
                .font(.callout.weight(.medium))
                .foregroundStyle(sourceColor)
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
        }
    }

    // MARK: - Missing Fields Row

    private var missingFieldsRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(draft.needsUserInput.prefix(2), id: \.self) { field in
                Text(localizedFieldName(field))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
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
