//
//  ScheduledPaymentRowView.swift
//  Neto
//
//  Individual scheduled payment card component
//

import SwiftData
import SwiftUI

struct ScheduledPaymentRowView: View {
    let summary: ScheduledPaymentSummary
    let currencyCode: String
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                // Icon badge
                paymentIcon

                // Payment info
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(summary.payment.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Due date info
                    dueInfo
                }

                Spacer()

                // Amount (right-aligned)
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    Text(formattedAmount)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(amountColor)

                    // Recurrence badge
                    recurrenceBadge
                }
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
            )
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
        Color.netoCard
    }

    private var paymentIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: summary.color))
                .frame(width: 40, height: 40)

            Image(systemName: summary.icon)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
        }
    }

    private var dueInfo: some View {
        HStack(spacing: 4) {
            // Due status indicator
            Circle()
                .fill(dueStatusColor)
                .frame(width: 6, height: 6)

            Text(dueText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(dueStatusColor)

            if let accountName = summary.payment.account?.name {
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.5))

                Text(accountName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var recurrenceBadge: some View {
        let recurrenceText: String
        if let recurrence = RecurrenceType(rawValue: summary.payment.recurrenceType) {
            recurrenceText = recurrence.localizedName
        } else {
            recurrenceText = summary.payment.recurrenceType
        }

        return Text(recurrenceText)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    // MARK: - Computed Properties

    private var dueText: String {
        switch summary.dueStatus {
        case .past:
            let days = abs(summary.daysUntilDue)
            if days == 1 {
                return NSLocalizedString("scheduled.due.yesterday", comment: "Yesterday")
            } else {
                return String(format: NSLocalizedString("scheduled.due.days.ago", comment: ""), days)
            }
        case .today:
            return NSLocalizedString("scheduled.due.today", comment: "Today")
        case .upcoming:
            if summary.daysUntilDue == 1 {
                return NSLocalizedString("scheduled.due.tomorrow", comment: "Tomorrow")
            } else {
                return String(format: NSLocalizedString("scheduled.due.in.days", comment: ""), summary.daysUntilDue)
            }
        }
    }

    private var dueStatusColor: Color {
        switch summary.dueStatus {
        case .past:
            return Color.hotPink
        case .today:
            return Color.orange
        case .upcoming:
            return Color.electricIndigo
        }
    }

    private var amountColor: Color {
        if summary.payment.transactionType == "income" {
            return Color.teal
        } else {
            return summary.dueStatus == .past ? Color.hotPink : .primary
        }
    }

    private var formattedAmount: String {
        let prefix = summary.payment.transactionType == "income" ? "+" : "-"
        return prefix + NetoFormatter.currency(value: summary.payment.amount, currencyCode: currencyCode)
    }
}
