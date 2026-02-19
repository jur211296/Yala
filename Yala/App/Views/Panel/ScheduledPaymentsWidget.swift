//
//  ScheduledPaymentsWidget.swift
//  Yala
//
//  Widget displaying scheduled payments summary, list, or calendar in PanelView
//

import SwiftData
import SwiftUI

struct ScheduledPaymentsWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    let payments: [ScheduledPayment]
    let currencyCode: String
    let period: DetailPeriod
    let customDateRange: DateInterval?
    let mode: ScheduledPaymentsWidgetMode

    /// Filter state (all/recurring/subscriptions)
    @Binding var filter: ScheduledPaymentsWidgetFilter

    /// Callback when user taps to show more
    var onShowMore: (() -> Void)?

    @Namespace private var filterNamespace

    /// Computed month based on period selection (intelligent mapping)
    private var displayMonth: Date {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .thisWeek, .last7Days, .last30Days, .thisMonth:
            return now
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .thisYear:
            return now
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime:
            return now
        case .custom:
            return customDateRange?.start ?? now
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            headerSection

            switch mode {
            case .summary:
                if filteredPayments.isEmpty {
                    emptyListState
                } else {
                    summaryContent
                }
            case .list:
                listContent
            case .calendar:
                if filteredPayments.isEmpty {
                    emptyListState
                } else {
                    calendarContent
                }
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    // MARK: - Filtered Payments

    private var filteredPayments: [ScheduledPayment] {
        guard let categoryFilter = filter.paymentCategoryFilter else {
            return payments.filter { $0.isActive }
        }
        return payments.filter { $0.isActive && $0.paymentCategory == categoryFilter }
    }

    // MARK: - Paid Status

    /// Batch load paid count for filtered payments in the display month.
    /// Checks InboxDraft (approved) and TransactionItem (linked).
    private var paidStatus: [String: Int] {
        loadPaidStatus(for: filteredPayments, month: displayMonth)
    }

    private func loadPaidStatus(for payments: [ScheduledPayment], month: Date) -> [String: Int] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [:] }

        var result: [String: Int] = [:]
        let paymentIDs = Set(payments.map { $0.id.uuidString })

        // Query 1: InboxDrafts approved with sourceScheduledPaymentID
        do {
            var draftDescriptor = FetchDescriptor<InboxDraft>(
                predicate: #Predicate<InboxDraft> { draft in
                    draft.statusRaw == "approved" && draft.sourceScheduledPaymentID != nil
                }
            )
            draftDescriptor.propertiesToFetch = [\.sourceScheduledPaymentID, \.date]
            let approvedDrafts = try modelContext.fetch(draftDescriptor)

            for draft in approvedDrafts {
                guard let spID = draft.sourceScheduledPaymentID, paymentIDs.contains(spID) else { continue }
                let draftDate = draft.approvedTransaction?.date ?? draft.date ?? draft.createdAt
                if draftDate >= monthInterval.start && draftDate < monthInterval.end {
                    result[spID, default: 0] += 1
                }
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentsWidget: Error loading draft paid status: \(error)")
            #endif
        }

        // Query 2: TransactionItems with scheduledPaymentID
        do {
            var txDescriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { tx in
                    tx.scheduledPaymentID != nil
                }
            )
            txDescriptor.propertiesToFetch = [\.scheduledPaymentID, \.date]
            let linkedTransactions = try modelContext.fetch(txDescriptor)

            for tx in linkedTransactions {
                guard let spID = tx.scheduledPaymentID, paymentIDs.contains(spID) else { continue }
                if tx.date >= monthInterval.start && tx.date < monthInterval.end {
                    result[spID, default: 0] += 1
                }
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentsWidget: Error loading tx paid status: \(error)")
            #endif
        }

        return result
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xxs) {
                    Text(L10n.WidgetType.scheduledPayments)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    InfoHintButton(
                        title: L10n.WidgetType.scheduledPayments,
                        message: L10n.Widget.Hint.scheduledPayments
                    )
                }

                // Period label
                Text(periodLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                // Filter selector
                filterSelector

                // Chevron
                if onShowMore != nil {
                    Button {
                        onShowMore?()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.headline)
                            .foregroundStyle(Color.gray.opacity(0.7))
                            .padding(.leading, DS.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Formatted period label for display
    private var periodLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayMonth).capitalized
    }

    private var filterSelector: some View {
        HStack(spacing: DS.Spacing.none) {
            ForEach(ScheduledPaymentsWidgetFilter.allCases) { filterOption in
                filterButton(for: filterOption)
            }
        }
        .padding(DS.Spacing.xxs)
        .background(.thSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func filterButton(for filterOption: ScheduledPaymentsWidgetFilter) -> some View {
        let isSelected = filter == filterOption

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                filter = filterOption
            }
        } label: {
            Image(systemName: filterOption.iconName)
                .font(DS.Typography.labelSmall)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .foregroundStyle(isSelected ? .white : theme.secondaryText)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(theme.accent)
                                .matchedGeometryEffect(id: "filterSelector", in: filterNamespace)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Summary Content

    private var summaryContent: some View {
        let monthlyTotal = calculateMonthlyTotal()
        let activeCount = filteredPayments.count

        return VStack(spacing: DS.Spacing.md) {
            // Amount
            Text(YalaFormatter.currency(value: monthlyTotal, currencyCode: currencyCode))
                .font(DS.Typography.amountLarge)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(.primary)

            // Payment count
            Text(paymentCountLabel(activeCount))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
    }

    private func paymentCountLabel(_ count: Int) -> String {
        let format = NSLocalizedString("scheduled.widget.count", comment: "")
        return String(format: format, count)
    }

    private func calculateMonthlyTotal() -> Double {
        let calendar = Calendar.current
        guard calendar.dateInterval(of: .month, for: displayMonth) != nil else {
            return 0
        }

        var total: Double = 0
        let converter = CurrencyConverter.shared

        // Only count expenses (exclude income payments)
        let expensePayments = filteredPayments.filter { $0.transactionType != "income" }

        for payment in expensePayments {
            let occurrences = getPaymentDatesInMonth(payment: payment, month: displayMonth)
            let rawAmount = payment.amount * Double(occurrences.count)

            // Convert currency if needed
            if payment.currencyCode != currencyCode, rawAmount > 0 {
                let converted = converter.convertWithLatestRate(
                    Decimal(rawAmount),
                    from: payment.currencyCode,
                    to: currencyCode,
                    context: modelContext
                )
                total += NSDecimalNumber(decimal: converted).doubleValue
            } else {
                total += rawAmount
            }
        }

        return total
    }

    // MARK: - List Content (Medium - List Mode)

    private var listContent: some View {
        let upcomingPayments = getUpcomingPayments(limit: 3)

        return VStack(spacing: DS.Spacing.md) {
            if upcomingPayments.isEmpty {
                emptyListState
            } else {
                ForEach(upcomingPayments, id: \.id) { item in
                    paymentRow(item)
                }
            }
        }
    }

    private var emptyListState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.bottom, DS.Spacing.xs)

            Text(NSLocalizedString("scheduled.widget.empty.title", comment: ""))
                .font(DS.Typography.label)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text(NSLocalizedString("scheduled.widget.empty.message", comment: ""))
                .font(DS.Typography.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

    private func paymentRow(_ item: UpcomingPaymentItem) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color(hex: item.color))
                    .frame(width: 36, height: 36)

                Image(systemName: item.icon)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(item.payment.name)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .opacity(item.isPaid ? 0.6 : 1.0)

                Text(item.dueDateLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(item.dueStatus == .past ? Color.hotPink : .secondary)
            }

            Spacer()

            // Amount + status badge
            HStack(spacing: DS.Spacing.xs) {
                Text(YalaFormatter.currency(value: item.payment.amount, currencyCode: currencyCode, forceFullPrecision: true))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .opacity(item.isPaid || item.isSkipped ? 0.6 : 1.0)

                if item.isSkipped {
                    Image(systemName: "arrow.uturn.forward.circle")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                } else if item.isPaid {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }

    // MARK: - Upcoming Payments Helper

    private struct UpcomingPaymentItem: Identifiable {
        let payment: ScheduledPayment
        let dueDate: Date
        let icon: String
        let color: String
        let dueStatus: DueStatus
        let dueDateLabel: String
        let isPaid: Bool
        let isSkipped: Bool

        var id: String {
            "\(payment.persistentModelID)-\(dueDate.timeIntervalSince1970)"
        }
    }

    private func getUpcomingPayments(limit: Int) -> [UpcomingPaymentItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var items: [UpcomingPaymentItem] = []

        for payment in filteredPayments {
            let dates = getPaymentDatesInMonth(payment: payment, month: displayMonth)
            let paidCount = paidStatus[payment.id.uuidString] ?? 0
            var remainingPaid = paidCount

            let icon = payment.subcategory?.iconName
                ?? payment.subcategory?.category?.iconName
                ?? "creditcard.fill"
            let color = payment.subcategory?.colorHex
                ?? payment.subcategory?.category?.colorHex
                ?? "#6366F1"

            for date in dates.sorted() {
                let dueDate = calendar.startOfDay(for: date)
                let days = calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0
                let dueStatus: DueStatus = days < 0 ? .past : (days == 0 ? .today : .upcoming)
                let isSkipped = payment.isDateSkipped(date)
                let isPaid = remainingPaid > 0 && !isSkipped
                if isPaid { remainingPaid -= 1 }

                items.append(UpcomingPaymentItem(
                    payment: payment,
                    dueDate: dueDate,
                    icon: icon,
                    color: color,
                    dueStatus: dueStatus,
                    dueDateLabel: formatDueDate(days: days, date: date),
                    isPaid: isPaid,
                    isSkipped: isSkipped
                ))
            }
        }

        // Sort: unpaid first, then paid, then skipped; within each group by date
        items.sort { a, b in
            let orderA = a.isSkipped ? 2 : (a.isPaid ? 1 : 0)
            let orderB = b.isSkipped ? 2 : (b.isPaid ? 1 : 0)
            if orderA != orderB { return orderA < orderB }
            return a.dueDate < b.dueDate
        }

        return Array(items.prefix(limit))
    }

    private func formatDueDate(days: Int, date: Date) -> String {
        if days < 0 {
            let format = NSLocalizedString("scheduled.widget.daysAgo", comment: "")
            return String(format: format, abs(days))
        } else if days == 0 {
            return NSLocalizedString("date.today", comment: "")
        } else if days == 1 {
            return NSLocalizedString("scheduled.widget.tomorrow", comment: "")
        } else if days <= 7 {
            let format = NSLocalizedString("scheduled.widget.inDays", comment: "")
            return String(format: format, days)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }

    // MARK: - Calendar Content

    /// First day of week from app settings (1 = Sunday, 2 = Monday, etc.)
    @AppStorage("firstWeekday") private var appFirstWeekday: Int = 2

    private var calendarContent: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Weekday headers
            weekdayHeaders

            // Calendar grid
            calendarGrid
        }
    }

    private var weekdayHeaders: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let startIndex = appFirstWeekday - 1
        let reorderedSymbols = Array(symbols[startIndex...]) + Array(symbols[..<startIndex])

        return HStack(spacing: DS.Spacing.xxs) {
            ForEach(Array(reorderedSymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayMonth)?.count ?? 30

        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)) ?? displayMonth
        let firstDayWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let emptyCellsCount = (firstDayWeekday - appFirstWeekday + 7) % 7

        // Build payment dates map with paid/skipped status
        var paymentsByDay: [Int: [(payment: ScheduledPayment, isPaid: Bool, isSkipped: Bool)]] = [:]
        for payment in filteredPayments {
            let dates = getPaymentDatesInMonth(payment: payment, month: displayMonth).sorted()
            let paidCount = paidStatus[payment.id.uuidString] ?? 0
            var remainingPaid = paidCount

            for date in dates {
                let day = calendar.component(.day, from: date)
                let isSkipped = payment.isDateSkipped(date)
                let isPaid = remainingPaid > 0 && !isSkipped
                if isPaid { remainingPaid -= 1 }
                paymentsByDay[day, default: []].append((payment: payment, isPaid: isPaid, isSkipped: isSkipped))
            }
        }

        // Build cell data array
        var cellData: [Int?] = []
        for _ in 0..<emptyCellsCount {
            cellData.append(nil)
        }
        for day in 1...daysInMonth {
            cellData.append(day)
        }

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.xxs), count: 7), spacing: DS.Spacing.xxs) {
            ForEach(Array(cellData.enumerated()), id: \.offset) { _, dayOrNil in
                if let day = dayOrNil {
                    calendarDayCell(day: day, entries: paymentsByDay[day] ?? [])
                } else {
                    Color.clear
                        .frame(minHeight: 56)
                }
            }
        }
    }

    private func calendarDayCell(day: Int, entries: [(payment: ScheduledPayment, isPaid: Bool, isSkipped: Bool)]) -> some View {
        let isToday = isCurrentDay(day)
        let hasPayments = !entries.isEmpty

        return VStack(alignment: .leading, spacing: 1) {
            // Day number
            Text("\(day)")
                .font(.caption2.weight(isToday ? .bold : .medium))
                .foregroundStyle(isToday ? theme.accent : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Payment names (show up to 2 with truncation)
            if hasPayments {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    ForEach(Array(entries.prefix(2).enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 2) {
                            if entry.isSkipped {
                                Image(systemName: "arrow.uturn.forward")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundStyle(.secondary)
                            } else if entry.isPaid {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundStyle(theme.accent)
                            }
                            Text(entry.payment.name)
                                .font(DS.Typography.captionSmall).fontWeight(.medium)
                                .foregroundStyle(entry.isSkipped ? .secondary : (entry.isPaid ? theme.accent : .primary))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    if entries.count > 2 {
                        Text("+\(entries.count - 2)")
                            .font(DS.Typography.captionSmall).fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.xs)
        .frame(minHeight: 56)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                .fill(backgroundColor(isToday: isToday, hasPayments: hasPayments))
        )
    }

    private func backgroundColor(isToday: Bool, hasPayments: Bool) -> Color {
        if isToday {
            return theme.accent.opacity(0.12)
        } else if hasPayments {
            return Color(.tertiarySystemFill).opacity(0.7)
        } else {
            return Color(.tertiarySystemFill).opacity(0.3)
        }
    }

    private func isCurrentDay(_ day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()

        return calendar.component(.day, from: today) == day &&
               calendar.component(.month, from: today) == calendar.component(.month, from: displayMonth) &&
               calendar.component(.year, from: today) == calendar.component(.year, from: displayMonth)
    }

    // MARK: - Payment Date Calculation

    private func getPaymentDatesInMonth(payment: ScheduledPayment, month: Date) -> [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }

        var dates: [Date] = []

        // For one-time payments
        if !payment.isRecurring {
            let paymentDate = calendar.startOfDay(for: payment.nextDueDate)
            if monthInterval.contains(paymentDate) {
                dates.append(paymentDate)
            }
            return dates
        }

        // For recurring payments
        guard let recurrenceType = RecurrenceType(rawValue: payment.recurrenceType) else { return [] }

        switch recurrenceType {
        case .daily:
            var date = calendar.startOfDay(for: payment.nextDueDate)
            while date > monthInterval.start {
                date = calendar.date(byAdding: .day, value: -payment.recurrenceInterval, to: date) ?? date
            }
            while date < monthInterval.end {
                if date >= monthInterval.start {
                    dates.append(date)
                }
                date = calendar.date(byAdding: .day, value: payment.recurrenceInterval, to: date) ?? monthInterval.end
            }

        case .weekly:
            let weekdays = parseWeekdays(payment.selectedWeekdays)
            if weekdays.isEmpty { return dates }

            var date = monthInterval.start
            while date < monthInterval.end {
                let weekday = calendar.component(.weekday, from: date)
                if weekdays.contains(weekday) {
                    dates.append(date)
                }
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? monthInterval.end
            }

        case .monthly:
            let dayOfMonth = payment.dayOfMonth ?? calendar.component(.day, from: payment.nextDueDate)
            let monthComponents = calendar.dateComponents([.year, .month], from: month)
            if var paymentDate = calendar.date(from: DateComponents(
                year: monthComponents.year,
                month: monthComponents.month,
                day: min(dayOfMonth, calendar.range(of: .day, in: .month, for: month)?.count ?? 28)
            )) {
                paymentDate = calendar.startOfDay(for: paymentDate)
                if monthInterval.contains(paymentDate) {
                    dates.append(paymentDate)
                }
            }

        case .yearly:
            let targetMonth = payment.yearlyMonth ?? calendar.component(.month, from: payment.nextDueDate)
            let targetDay = payment.yearlyDay ?? calendar.component(.day, from: payment.nextDueDate)
            let monthComponents = calendar.dateComponents([.year, .month], from: month)

            if monthComponents.month == targetMonth {
                if let paymentDate = calendar.date(from: DateComponents(
                    year: monthComponents.year,
                    month: targetMonth,
                    day: targetDay
                )) {
                    let startOfPayment = calendar.startOfDay(for: paymentDate)
                    if monthInterval.contains(startOfPayment) {
                        dates.append(startOfPayment)
                    }
                }
            }
        }

        return dates
    }

    private func parseWeekdays(_ weekdaysString: String?) -> Set<Int> {
        guard let string = weekdaysString, !string.isEmpty else { return [] }
        return Set(string.split(separator: ",").compactMap { Int($0) })
    }
}
