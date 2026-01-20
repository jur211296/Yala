//
//  ScheduledPaymentsWidget.swift
//  Neto
//
//  Widget displaying scheduled payments summary, list, or calendar in PanelView
//

import SwiftData
import SwiftUI

struct ScheduledPaymentsWidget: View {
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
                summaryContent
            case .list:
                listContent
            case .calendar:
                calendarContent
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.netoCard)
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

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.WidgetType.scheduledPayments)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Period label
                Text(periodLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            InfoHintButton(
                title: L10n.WidgetType.scheduledPayments,
                message: L10n.Widget.Hint.scheduledPayments
            )

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
                            .font(.headline)
                            .foregroundStyle(Color.gray.opacity(0.7))
                            .padding(.leading, 4)
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
        HStack(spacing: 0) {
            ForEach(ScheduledPaymentsWidgetFilter.allCases) { filterOption in
                filterButton(for: filterOption)
            }
        }
        .padding(DS.Spacing.xxs)
        .background(Color.netoSecondaryText.opacity(0.08))
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
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : Color.netoSecondaryText)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.electricIndigo)
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
            Text(NetoFormatter.currency(value: monthlyTotal, currencyCode: currencyCode))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.electricIndigo, Color.hotPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Payment count
            Text(paymentCountLabel(activeCount))
                .font(.caption)
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

        for payment in filteredPayments {
            let occurrences = getPaymentDatesInMonth(payment: payment, month: displayMonth)
            total += payment.amount * Double(occurrences.count)
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
                ForEach(upcomingPayments, id: \.payment.persistentModelID) { item in
                    paymentRow(item)
                }
            }
        }
    }

    private var emptyListState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.bottom, DS.Spacing.xs)

            Text(NSLocalizedString("scheduled.widget.empty.title", comment: ""))
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text(NSLocalizedString("scheduled.widget.empty.message", comment: ""))
                .font(.caption)
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
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.payment.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.dueDateLabel)
                    .font(.caption)
                    .foregroundStyle(item.dueStatus == .past ? Color.hotPink : .secondary)
            }

            Spacer()

            // Amount
            Text(NetoFormatter.currency(value: item.payment.amount, currencyCode: currencyCode))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Upcoming Payments Helper

    private struct UpcomingPaymentItem {
        let payment: ScheduledPayment
        let icon: String
        let color: String
        let dueStatus: DueStatus
        let dueDateLabel: String
    }

    private func getUpcomingPayments(limit: Int) -> [UpcomingPaymentItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return filteredPayments
            .sorted { $0.nextDueDate < $1.nextDueDate }
            .prefix(limit)
            .map { payment in
                let dueDate = calendar.startOfDay(for: payment.nextDueDate)
                let days = calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0

                let dueStatus: DueStatus
                if days < 0 {
                    dueStatus = .past
                } else if days == 0 {
                    dueStatus = .today
                } else {
                    dueStatus = .upcoming
                }

                let icon = payment.subcategory?.iconName
                    ?? payment.subcategory?.category.iconName
                    ?? "creditcard.fill"
                let color = payment.subcategory?.colorHex
                    ?? payment.subcategory?.category.colorHex
                    ?? "#6366F1"

                let dueDateLabel = formatDueDate(days: days, date: payment.nextDueDate)

                return UpcomingPaymentItem(
                    payment: payment,
                    icon: icon,
                    color: color,
                    dueStatus: dueStatus,
                    dueDateLabel: dueDateLabel
                )
            }
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

        return HStack(spacing: 2) {
            ForEach(Array(reorderedSymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayMonth)?.count ?? 30

        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth))!
        let firstDayWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let emptyCellsCount = (firstDayWeekday - appFirstWeekday + 7) % 7

        // Build payment dates map
        var paymentsByDay: [Int: [ScheduledPayment]] = [:]
        for payment in filteredPayments {
            let dates = getPaymentDatesInMonth(payment: payment, month: displayMonth)
            for date in dates {
                let day = calendar.component(.day, from: date)
                paymentsByDay[day, default: []].append(payment)
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

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
            ForEach(Array(cellData.enumerated()), id: \.offset) { _, dayOrNil in
                if let day = dayOrNil {
                    calendarDayCell(day: day, payments: paymentsByDay[day] ?? [])
                } else {
                    Color.clear
                        .frame(minHeight: 56)
                }
            }
        }
    }

    private func calendarDayCell(day: Int, payments: [ScheduledPayment]) -> some View {
        let isToday = isCurrentDay(day)
        let hasPayments = !payments.isEmpty

        return VStack(alignment: .leading, spacing: 1) {
            // Day number
            Text("\(day)")
                .font(.caption2.weight(isToday ? .bold : .medium))
                .foregroundStyle(isToday ? Color.electricIndigo : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Payment names (show up to 2 with truncation)
            if hasPayments {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(payments.prefix(2), id: \.persistentModelID) { payment in
                        Text(payment.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if payments.count > 2 {
                        Text("+\(payments.count - 2)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(3)
        .frame(minHeight: 56)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                .fill(backgroundColor(isToday: isToday, hasPayments: hasPayments))
        )
    }

    private func backgroundColor(isToday: Bool, hasPayments: Bool) -> Color {
        if isToday {
            return Color.electricIndigo.opacity(0.12)
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
