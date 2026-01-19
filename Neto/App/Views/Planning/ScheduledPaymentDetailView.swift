//
//  ScheduledPaymentDetailView.swift
//  Neto
//
//  Detail view for a scheduled payment showing history and upcoming occurrences.
//  Accessed from ScheduledPaymentsListView in Planning tab.
//

import SwiftData
import SwiftUI

struct ScheduledPaymentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let payment: ScheduledPayment

    @State private var showEditor = false

    // Calculate occurrences
    private var pastOccurrences: [Date] {
        calculatePastOccurrences(for: payment, limit: 10)
    }

    private var upcomingOccurrences: [Date] {
        calculateUpcomingOccurrences(for: payment, count: 3)
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Summary Card
                    summaryCard

                    // Upcoming Section
                    if payment.isRecurring && !upcomingOccurrences.isEmpty {
                        upcomingSection
                    }

                    // History Section
                    if !pastOccurrences.isEmpty {
                        historySection
                    }

                    // Info note
                    infoNote
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
        }
        .navigationTitle(payment.name)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NetoToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NetoToolbarButton(systemName: "pencil") {
                    showEditor = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ScheduledPaymentEditorView(payment: payment)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Amount
            VStack(spacing: DS.Spacing.xs) {
                Text(payment.currencyCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formatAmount(payment.amount))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(payment.transactionType == "income" ? Color.teal : .primary)
            }

            Divider()
                .padding(.horizontal, DS.Spacing.xl)

            // Details grid
            VStack(spacing: DS.Spacing.md) {
                detailRow(
                    icon: "repeat",
                    label: NSLocalizedString("scheduled.detail.frequency", comment: ""),
                    value: frequencyDescription
                )

                if payment.isRecurring {
                    detailRow(
                        icon: "calendar",
                        label: NSLocalizedString("scheduled.detail.next.date", comment: ""),
                        value: formatDate(payment.nextDueDate)
                    )

                    if let endDate = payment.endDate {
                        detailRow(
                            icon: "calendar.badge.minus",
                            label: NSLocalizedString("scheduled.detail.end.date", comment: ""),
                            value: formatDate(endDate)
                        )
                    }
                } else {
                    detailRow(
                        icon: "calendar",
                        label: NSLocalizedString("scheduled.payment.date", comment: ""),
                        value: formatDate(payment.nextDueDate)
                    )
                }

                if let account = payment.account {
                    detailRow(
                        icon: "creditcard",
                        label: NSLocalizedString("scheduled.editor.account", comment: ""),
                        value: account.name
                    )
                }

                if let subcategory = payment.subcategory {
                    detailRow(
                        icon: "tag",
                        label: NSLocalizedString("scheduled.editor.subcategory", comment: ""),
                        value: subcategory.name
                    )
                }
            }

            // Status
            if !payment.isActive {
                HStack {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.orange)
                    Text(NSLocalizedString("scheduled.status.inactive", comment: ""))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .padding(.top, DS.Spacing.sm)
            }
        }
        .padding(DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(Color.netoCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
        )
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "arrow.forward.circle.fill")
                    .foregroundStyle(Color.electricIndigo)
                Text(NSLocalizedString("scheduled.detail.upcoming", comment: ""))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, DS.Spacing.xs)

            VStack(spacing: 0) {
                ForEach(Array(upcomingOccurrences.enumerated()), id: \.offset) { index, date in
                    occurrenceRow(date: date, isPast: false, index: index + 1)

                    if index < upcomingOccurrences.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.netoCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                Text(NSLocalizedString("scheduled.detail.history", comment: ""))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, DS.Spacing.xs)

            VStack(spacing: 0) {
                ForEach(Array(pastOccurrences.enumerated()), id: \.offset) { index, date in
                    occurrenceRow(date: date, isPast: true, index: nil)

                    if index < pastOccurrences.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.netoCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
        }
    }

    private func occurrenceRow(date: Date, isPast: Bool, index: Int?) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Date indicator
            VStack(spacing: 2) {
                Text(dayOfMonth(date))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isPast ? .secondary : .primary)
                Text(monthAbbrev(date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 40)

            // Full date
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(formatFullDate(date))
                    .font(.subheadline)
                    .foregroundStyle(isPast ? .secondary : .primary)

                if !isPast, let idx = index {
                    Text(ordinalText(idx))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Amount
            Text(formatAmount(payment.amount))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isPast ? .secondary : (payment.transactionType == "income" ? Color.teal : .primary))
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Info Note

    private var infoNote: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(Color.electricIndigo)

            Text(NSLocalizedString("scheduled.detail.info.note", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color.electricIndigo.opacity(0.1))
        )
    }

    // MARK: - Helpers

    private var frequencyDescription: String {
        if !payment.isRecurring {
            return NSLocalizedString("scheduled.recurrence.onetime", comment: "")
        }

        let type = RecurrenceType(rawValue: payment.recurrenceType) ?? .monthly
        let interval = payment.recurrenceInterval

        if interval == 1 {
            return type.localizedName
        } else {
            return "\(NSLocalizedString("scheduled.every", comment: "")) \(interval) \(type.localizedNamePlural)"
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = payment.currencyCode
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: date)
    }

    private func dayOfMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func monthAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    private func ordinalText(_ n: Int) -> String {
        switch n {
        case 1: return NSLocalizedString("scheduled.next.first", comment: "")
        case 2: return NSLocalizedString("scheduled.next.second", comment: "")
        case 3: return NSLocalizedString("scheduled.next.third", comment: "")
        default: return ""
        }
    }

    // MARK: - Occurrence Calculations

    private func calculatePastOccurrences(for payment: ScheduledPayment, limit: Int) -> [Date] {
        guard payment.isRecurring else {
            // One-time payment: show if in the past
            if payment.nextDueDate < Date() {
                return [payment.nextDueDate]
            }
            return []
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let createdAt = calendar.startOfDay(for: payment.createdAt)

        var occurrences: [Date] = []
        var currentDate = createdAt

        // Generate occurrences from creation date until today
        while currentDate < today && occurrences.count < limit {
            if currentDate >= createdAt {
                occurrences.append(currentDate)
            }
            currentDate = nextOccurrence(after: currentDate, for: payment)
        }

        // Return in reverse order (most recent first)
        return occurrences.reversed()
    }

    private func calculateUpcomingOccurrences(for payment: ScheduledPayment, count: Int) -> [Date] {
        guard payment.isRecurring else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var occurrences: [Date] = []
        var currentDate = payment.nextDueDate

        // If nextDueDate is in the past, find the next future occurrence
        while currentDate < today {
            currentDate = nextOccurrence(after: currentDate, for: payment)
        }

        // Generate next 'count' occurrences
        while occurrences.count < count {
            // Check if we've passed the end date
            if let endDate = payment.endDate, currentDate > endDate {
                break
            }

            occurrences.append(currentDate)
            currentDate = nextOccurrence(after: currentDate, for: payment)
        }

        return occurrences
    }

    private func nextOccurrence(after date: Date, for payment: ScheduledPayment) -> Date {
        let calendar = Calendar.current
        let type = RecurrenceType(rawValue: payment.recurrenceType) ?? .monthly
        let interval = payment.recurrenceInterval

        switch type {
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date) ?? date
        }
    }
}

#Preview {
    NavigationStack {
        Text("Preview requires ScheduledPayment instance")
    }
}
