//
//  ScheduledPaymentRowView.swift
//  Yala
//
//  Individual scheduled payment card component
//

import SwiftData
import SwiftUI

struct ScheduledPaymentRowView: View {
    let summary: ScheduledPaymentSummary
    let currencyCode: String

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        NavigationLink(value: summary.payment.persistentModelID) {
            HStack(spacing: DS.Spacing.md) {
                // Icon badge
                paymentIcon

                // Payment info
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(summary.payment.name)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Due date info
                    dueInfo
                }

                Spacer()

                // Amount (right-aligned)
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    Text(formattedAmount)
                        .font(DS.Typography.headline)
                        .foregroundStyle(amountColor)

                    // Recurrence badge
                    recurrenceBadge
                }
            }
            .contentShape(Rectangle())
            .panelCard(small: true)
            .opacity(summary.isPaidForMonth || summary.isSkippedForMonth ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scheduled_payment_row")
    }

    // MARK: - Components

    private var paymentIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: summary.color))
                .frame(width: 40, height: 40)

            Image(systemName: summary.icon)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
        }
    }

    private var dueInfo: some View {
        HStack(spacing: DS.Spacing.xs) {
            // Skipped badge
            if summary.isSkippedForMonth {
                Image(systemName: "arrow.uturn.forward.circle")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)

                Text(NSLocalizedString("scheduled.status.skipped", comment: ""))
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
            // Paid badge (if paid for current cycle)
            else if summary.isPaidForMonth {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(theme.accent)

                Text(L10n.Scheduled.paid)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(theme.accent)
            } else {
                // Due status indicator (only for past due)
                if summary.dueStatus == .past {
                    Circle()
                        .fill(Color.hotPink)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)

                    Text(NSLocalizedString("scheduled.overdue", comment: "Overdue label"))
                        .font(DS.Typography.badgeLabel)
                        .foregroundStyle(Color.hotPink)
                }

                Text(dueText)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(summary.dueStatus == .past ? Color.hotPink : .secondary)
            }

            if let accountName = summary.payment.account?.name {
                Text("•")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary.opacity(0.5))

                Text(accountName)
                    .font(DS.Typography.captionSmall)
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
            .font(DS.Typography.captionSmall)
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


    private var amountColor: Color {
        if summary.payment.transactionType == "income" {
            return Color.priorityNeed
        }
        return summary.dueStatus == .past ? Color.hotPink.opacity(0.8) : Color.hotPink
    }

    private var formattedAmount: String {
        let prefix = summary.payment.transactionType == "income" ? "+" : "-"
        let isEstimate = summary.paidAmount == nil && summary.payment.isVariableAmount
        return prefix + appPreferences.currency(summary.displayAmount, currencyCode: summary.displayCurrencyCode, forceFullPrecision: true, isEstimate: isEstimate)
    }
}
