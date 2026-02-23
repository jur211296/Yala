//
//  ScheduledPaymentDetailView.swift
//  Yala
//
//  Detail view for a scheduled payment showing history and upcoming occurrences.
//  Accessed from ScheduledPaymentsListView in Planning tab.
//

import SwiftData
import SwiftUI

struct ScheduledPaymentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var scaledAmountSize: CGFloat = 36

    let payment: ScheduledPayment
    @Bindable var viewModel: ScheduledPaymentsViewModel

    @State private var showEditor = false
    @State private var showAssociationSheet = false
    @State private var showOccurrenceActions = false
    @State private var selectedOccurrenceDate: Date?

    // Calculate occurrences using getPaymentDatesInMonth (SSOT for date generation)
    private var pastOccurrences: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Selected month past dates
        let selectedMonthDates = viewModel.getPaymentDatesInMonth(payment: payment, month: viewModel.selectedMonth)
            .filter { calendar.startOfDay(for: $0) <= today }

        // Previous months (up to 3)
        var olderDates: [Date] = []
        for offset in 1...3 {
            guard let prevMonth = calendar.date(byAdding: .month, value: -offset, to: viewModel.selectedMonth) else { continue }
            let dates = viewModel.getPaymentDatesInMonth(payment: payment, month: prevMonth)
            olderDates.append(contentsOf: dates)
        }

        // Most recent first, limit 10
        return Array((selectedMonthDates + olderDates).sorted(by: >).prefix(10))
    }

    private var upcomingOccurrences: [Date] {
        guard payment.isRecurring else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Selected month future dates
        var futureDates = viewModel.getPaymentDatesInMonth(payment: payment, month: viewModel.selectedMonth)
            .filter { calendar.startOfDay(for: $0) > today }

        // Next months until we have 3
        var nextMonth = viewModel.selectedMonth
        while futureDates.count < 3 {
            guard let nm = calendar.date(byAdding: .month, value: 1, to: nextMonth) else { break }
            nextMonth = nm
            let dates = viewModel.getPaymentDatesInMonth(payment: payment, month: nm)
                .filter { $0 > today }
            futureDates.append(contentsOf: dates)
            // Safety: don't look more than 6 months ahead
            if calendar.dateComponents([.month], from: viewModel.selectedMonth, to: nm).month ?? 0 > 6 { break }
        }

        return Array(futureDates.sorted().prefix(3))
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Summary Card
                    summaryCard

                    // Associate transaction button (if not paid for this month)
                    if !isPaidForSelectedMonth {
                        associateTransactionButton
                    }

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
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                YalaToolbarButton(systemName: "pencil", label: L10n.Action.edit) {
                    showEditor = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ScheduledPaymentEditorView(payment: payment, onDelete: {
                dismiss()
            })
        }
        .sheet(isPresented: $showAssociationSheet) {
            TransactionAssociationSheet(
                payment: payment,
                selectedMonth: viewModel.selectedMonth,
                viewModel: viewModel
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Amount
            VStack(spacing: DS.Spacing.xs) {
                Text(payment.currencyCode)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                Text(formatAmount(payment.amount))
                    .font(.system(size: scaledAmountSize, weight: .bold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(payment.transactionType == "income" ? Color.electricIndigo : .primary)
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
                        .foregroundStyle(DS.Semantic.warningForeground)
                    Text(NSLocalizedString("scheduled.status.inactive", comment: ""))
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Semantic.warningForeground)
                }
                .padding(.top, DS.Spacing.sm)
            }
        }
        .padding(DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(.thCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Colors.borderDark, lineWidth: 0.8)
        )
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "arrow.forward.circle.fill")
                    .foregroundStyle(.thAccent)
                Text(NSLocalizedString("scheduled.detail.upcoming", comment: ""))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(upcomingOccurrences.enumerated()), id: \.offset) { index, date in
                    occurrenceRow(date: date, isPast: false, index: index + 1)

                    if index < upcomingOccurrences.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Colors.borderDark, lineWidth: 0.8)
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
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(pastOccurrences.enumerated()), id: \.offset) { index, date in
                    occurrenceRow(date: date, isPast: true, index: nil)

                    if index < pastOccurrences.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Colors.borderDark, lineWidth: 0.8)
            )
        }
    }

    private func occurrenceRow(date: Date, isPast: Bool, index: Int?) -> some View {
        let isSkipped = payment.isDateSkipped(date)
        let isPaidForDate = occurrenceIsPaid(date: date, isPast: isPast)
        // Tappable if skipped (to undo) or not paid (to skip)
        let hasTapAction = isSkipped || !isPaidForDate

        // Binding: true only when THIS row's date is the selected one
        let isDialogPresented = Binding<Bool>(
            get: { showOccurrenceActions && selectedOccurrenceDate.map { Calendar.current.isDate($0, inSameDayAs: date) } == true },
            set: { newValue in
                if !newValue {
                    showOccurrenceActions = false
                    selectedOccurrenceDate = nil
                }
            }
        )

        return Button {
            guard hasTapAction else { return }
            selectedOccurrenceDate = date
            showOccurrenceActions = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Date indicator
                VStack(spacing: DS.Spacing.xxs) {
                    Text(dayOfMonth(date))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isSkipped || isPast ? .secondary : .primary)
                    Text(monthAbbrev(date))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 40)

                // Full date + status
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(formatFullDate(date))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(isSkipped || isPast ? .secondary : .primary)

                    if isSkipped {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "arrow.uturn.forward.circle")
                                .font(DS.Typography.captionSmall)
                            Text(NSLocalizedString("scheduled.status.skipped", comment: ""))
                                .font(DS.Typography.captionSmall)
                        }
                        .foregroundStyle(.secondary)
                    } else if isPaidForDate {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(DS.Typography.captionSmall)
                            Text(NSLocalizedString("scheduled.status.paid", comment: ""))
                                .font(DS.Typography.captionSmall)
                        }
                        .foregroundStyle(theme.accent)
                    } else if isPast {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "exclamationmark.circle")
                                .font(DS.Typography.captionSmall)
                            Text(NSLocalizedString("scheduled.status.overdue", comment: ""))
                                .font(DS.Typography.captionSmall)
                        }
                        .foregroundStyle(Color.hotPink)
                    } else if let idx = index {
                        Text(ordinalText(idx))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Amount + chevron
                HStack(spacing: DS.Spacing.sm) {
                    Text(formatAmount(payment.amount))
                        .font(DS.Typography.label)
                        .foregroundStyle(isSkipped ? .secondary : (isPast ? .secondary : (payment.transactionType == "income" ? Color.electricIndigo : .primary)))

                    if hasTapAction {
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isSkipped ? 0.6 : 1.0)
        .confirmationDialog(
            formatFullDate(date),
            isPresented: isDialogPresented,
            titleVisibility: .visible
        ) {
            if isSkipped {
                Button(NSLocalizedString("scheduled.skip.undo", comment: "")) {
                    viewModel.unskipOccurrence(payment: payment, date: date)
                }
            } else {
                Button(NSLocalizedString("scheduled.skip", comment: ""), role: .destructive) {
                    viewModel.skipOccurrence(payment: payment, date: date)
                }
            }
        }
    }

    /// Check if a specific occurrence date has been paid
    private func occurrenceIsPaid(date: Date, isPast: Bool) -> Bool {
        let paidCount = viewModel.paidStatusForMonth[payment.id.uuidString] ?? 0
        guard paidCount > 0 else { return false }
        // Simple heuristic: if paid count > 0 and this is a past occurrence, mark earliest as paid
        let dates = viewModel.getPaymentDatesInMonth(payment: payment, month: viewModel.selectedMonth)
            .filter { !payment.isDateSkipped($0) }
            .sorted()
        guard let index = dates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: date) }) else { return false }
        return index < paidCount
    }

    // MARK: - Info Note

    private var infoNote: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "info.circle")
                .font(DS.Typography.body)
                .foregroundStyle(.thAccent)

            Text(NSLocalizedString("scheduled.detail.info.note", comment: ""))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(theme.accent.opacity(0.1))
        )
    }

    // MARK: - Transaction Association

    private var isPaidForSelectedMonth: Bool {
        let dates = viewModel.getPaymentDatesInMonth(payment: payment, month: viewModel.selectedMonth)
        let skippedCount = dates.filter { payment.isDateSkipped($0) }.count
        let requiredOccurrences = dates.count - skippedCount
        let paidCount = viewModel.paidStatusForMonth[payment.id.uuidString] ?? 0
        return requiredOccurrences > 0 ? paidCount >= requiredOccurrences : true
    }

    private var associateTransactionButton: some View {
        Button {
            showAssociationSheet = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "link.badge.plus")
                    .font(DS.Typography.body)
                    .foregroundStyle(.thAccent)

                Text(NSLocalizedString("scheduled.associate.title", comment: ""))
                    .font(DS.Typography.label)
                    .foregroundStyle(.thAccent)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(theme.accent.opacity(0.1))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        YalaFormatter.currency(value: amount, currencyCode: payment.currencyCode, forceFullPrecision: true)
    }

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.mediumDateFormatter.string(from: date)
    }

    private func formatFullDate(_ date: Date) -> String {
        Self.fullDateFormatter.string(from: date)
    }

    private func dayOfMonth(_ date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private func monthAbbrev(_ date: Date) -> String {
        Self.monthFormatter.string(from: date).uppercased()
    }

    private func ordinalText(_ n: Int) -> String {
        switch n {
        case 1: return NSLocalizedString("scheduled.next.first", comment: "")
        case 2: return NSLocalizedString("scheduled.next.second", comment: "")
        case 3: return NSLocalizedString("scheduled.next.third", comment: "")
        default: return ""
        }
    }

}

#Preview {
    NavigationStack {
        Text("Preview requires ScheduledPayment instance")
    }
}
