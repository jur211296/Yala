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

    /// Cached paid status to avoid N+1 SwiftData queries per render
    @State private var paidStatus: [String: Int] = [:]

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
        .onAppear { paidStatus = loadPaidStatus(for: filteredPayments, month: displayMonth) }
        .onChange(of: displayMonth) { paidStatus = loadPaidStatus(for: filteredPayments, month: displayMonth) }
        .onChange(of: filter) { paidStatus = loadPaidStatus(for: filteredPayments, month: displayMonth) }
    }

    // MARK: - Filtered Payments

    private var filteredPayments: [ScheduledPayment] {
        guard let categoryFilter = filter.paymentCategoryFilter else {
            return payments.filter { $0.isActive }
        }
        return payments.filter { $0.isActive && $0.paymentCategory == categoryFilter }
    }

    // MARK: - Paid Status

    private func loadPaidStatus(for payments: [ScheduledPayment], month: Date) -> [String: Int] {
        ScheduledPaymentPaidStatusHelper.loadPaidStatus(for: payments, month: month, context: modelContext)
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
                            .foregroundStyle(.secondary)
                            .padding(.leading, DS.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Formatted period label for display
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private var periodLabel: String {
        Self.monthYearFormatter.string(from: displayMonth).capitalized
    }

    private var filterSelector: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(ScheduledPaymentsWidgetFilter.allCases) { filterOption in
                filterButton(for: filterOption)
            }
        }
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
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : theme.secondaryText)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .matchedGeometryEffect(id: "filterSelector", in: filterNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filterOption == .all ? L10n.Accessibility.filterScheduledAll : filterOption == .recurring ? L10n.Accessibility.filterScheduledRecurring : L10n.Accessibility.filterScheduledSubscriptions)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        return String(format: L10n.Scheduled.Widget.count, count)
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

            Text(L10n.Scheduled.Widget.emptyTitle)
                .font(DS.Typography.label)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text(L10n.Scheduled.Widget.emptyMessage)
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
                ?? AppConstants.defaultColorHex

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

        // Filter out paid and skipped items — widget only shows pending payments
        let pending = items.filter { !$0.isPaid && !$0.isSkipped }

        // Sort by date
        let sorted = pending.sorted { $0.dueDate < $1.dueDate }

        return Array(sorted.prefix(limit))
    }

    private func formatDueDate(days: Int, date: Date) -> String {
        if days < 0 {
            return String(format: L10n.Scheduled.Widget.daysAgo, abs(days))
        } else if days == 0 {
            return L10n.Date.today
        } else if days == 1 {
            return L10n.Scheduled.Widget.tomorrow
        } else if days <= 7 {
            return String(format: L10n.Scheduled.Widget.inDays, days)
        } else {
            return Self.shortDateFormatter.string(from: date)
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

        return VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            // Day number
            Text("\(day)")
                .font(DS.Typography.captionSmall.weight(isToday ? .bold : .medium))
                .foregroundStyle(isToday ? theme.accent : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Payment names (show up to 2 with truncation)
            if hasPayments {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    ForEach(Array(entries.prefix(2).enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: DS.Spacing.xxs) {
                            if entry.isSkipped {
                                Image(systemName: "arrow.uturn.forward")
                                    .font(.system(size: 6, weight: .bold)) // A11Y-DT: fixed size — calendar micro-badge
                                    .foregroundStyle(.secondary)
                            } else if entry.isPaid {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 6, weight: .bold)) // A11Y-DT: fixed size — calendar micro-badge
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
            return DS.Semantic.neutralBackground
        } else {
            return DS.Semantic.neutralBackground
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
        ScheduledPaymentDateCalculator.paymentDatesInMonth(
            params: payment.dateCalculatorParams, month: month
        )
    }
}
