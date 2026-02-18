//
//  ScheduledPaymentsListView.swift
//  Yala
//
//  Unified content view for scheduled payments with summary card, view mode toggle, and calendar/list
//  Used by All, Recurring, and Subscriptions tabs
//

import SwiftData
import SwiftUI

struct ScheduledPaymentsListView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var scaledAmountSize: CGFloat = 36

    @Bindable var viewModel: ScheduledPaymentsViewModel
    let payments: [ScheduledPayment]
    let tab: ScheduledPaymentsTab
    let currencyCode: String
    let onRefresh: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var viewModeNamespace

    /// First day of week from app settings (1 = Sunday, 2 = Monday, etc.)
    @AppStorage("firstWeekday") private var appFirstWeekday: Int = 2

    /// Selected day in calendar (nil = show all for the month)
    @State private var selectedDay: Int? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Month navigation (visible in both list and calendar modes)
            monthNavigationHeader

            // Summary card
            summaryCard

            // View mode header with selector
            viewModeHeader

            // Content based on view mode
            if viewModel.paymentsViewMode == .list {
                listContent
            } else {
                calendarContent
            }
        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.safeBottom) // Space for FAB
        .sheet(isPresented: $viewModel.showPeriodSelector) {
            ScheduledPaymentPeriodSelectorSheet(
                viewModel: viewModel,
                payments: payments,
                onPeriodChange: { onRefresh() }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Filtered Payments

    private var activePayments: [ScheduledPayment] {
        payments.filter { $0.isActive }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let monthlyTotal = viewModel.calculateMonthlyTotal(
            subscriptions: activePayments,
            for: viewModel.selectedMonth,
            preferredCurrencyCode: currencyCode
        )

        return VStack(spacing: DS.Spacing.md) {
            // Total amount
            Text(YalaFormatter.currency(value: monthlyTotal, currencyCode: currencyCode))
                .font(.system(size: scaledAmountSize, weight: .bold, design: .rounded))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(.primary)

            // Paid / Pending breakdown (clickable as filters)
            HStack(spacing: DS.Spacing.lg) {
                Button {
                    dsWithAnimation(reduceMotion) {
                        viewModel.paymentStatusFilter = viewModel.paymentStatusFilter == .paid ? .all : .paid
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(Color.electricIndigo)
                            .frame(width: 8, height: 8)
                        Text(NSLocalizedString("scheduled.summary.paid", comment: ""))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                        Text(YalaFormatter.currency(value: viewModel.monthlyTotalPaid, currencyCode: currencyCode))
                            .font(DS.Typography.label)
                            .foregroundStyle(Color.electricIndigo)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(
                        Capsule().fill(viewModel.paymentStatusFilter == .paid ? Color.electricIndigo.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    dsWithAnimation(reduceMotion) {
                        viewModel.paymentStatusFilter = viewModel.paymentStatusFilter == .pending ? .all : .pending
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(Color.hotPink)
                            .frame(width: 8, height: 8)
                        Text(NSLocalizedString("scheduled.summary.pending", comment: ""))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                        Text(YalaFormatter.currency(value: viewModel.monthlyTotalPending, currencyCode: currencyCode))
                            .font(DS.Typography.label)
                            .foregroundStyle(Color.hotPink)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(
                        Capsule().fill(viewModel.paymentStatusFilter == .pending ? Color.hotPink.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .padding(.horizontal, DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(Color.yalaCard)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - View Mode Header

    private var viewModeHeader: some View {
        HStack {
            Text(tab.localizedName)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)

            Spacer()

            viewModeSelector
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var viewModeSelector: some View {
        HStack(spacing: DS.Spacing.none) {
            ForEach(PaymentsViewMode.allCases) { mode in
                viewModeButton(for: mode)
            }
        }
        .padding(DS.Spacing.xxs)
        .background(Color.yalaSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func viewModeButton(for mode: PaymentsViewMode) -> some View {
        let isSelected = viewModel.paymentsViewMode == mode

        return Button {
            dsWithAnimation(reduceMotion) {
                viewModel.paymentsViewMode = mode
            }
        } label: {
            Image(systemName: mode.iconName)
                .font(DS.Typography.labelSmall)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.sm)
                .foregroundStyle(isSelected ? .white : Color.yalaSecondaryText)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.electricIndigo)
                                .matchedGeometryEffect(id: "viewModeSelector", in: viewModeNamespace)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - List Content

    private var listContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            if viewModel.filteredGroupedPayments.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.filteredGroupedPayments, id: \.status) { section in
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        // Section header
                        HStack(spacing: DS.Spacing.sm) {
                            if section.status == .past {
                                Circle()
                                    .fill(Color.hotPink)
                                    .frame(width: 8, height: 8)
                            }

                            Text(section.status.localizedName)
                                .font(DS.Typography.headline)
                                .foregroundStyle(.primary)
                        }

                        // Payment cards
                        ForEach(section.payments) { summary in
                            ScheduledPaymentRowView(
                                summary: summary,
                                currencyCode: summary.payment.currencyCode
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }


    // MARK: - Calendar Content

    private var calendarContent: some View {
        VStack(spacing: DS.Spacing.md) {
            // Calendar grid
            calendarGrid

            // Payments for selected month
            monthPaymentsList
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                dsWithAnimation(reduceMotion) {
                    selectedDay = nil
                    viewModel.previousMonth()
                    onRefresh()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                viewModel.showPeriodSelector = true
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(viewModel.monthYearLabel)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.down")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                dsWithAnimation(reduceMotion) {
                    selectedDay = nil
                    viewModel.nextMonth()
                    onRefresh()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var calendarGrid: some View {
        let calendar = Calendar.current
        let month = viewModel.selectedMonth
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30

        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let firstDayWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let emptyCellsCount = (firstDayWeekday - appFirstWeekday + 7) % 7

        // Build payment dates map
        var paymentsByDay: [Int: [ScheduledPayment]] = [:]
        for payment in activePayments {
            let dates = viewModel.getPaymentDatesInMonth(payment: payment, month: month)
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

        return VStack(spacing: DS.Spacing.sm) {
            weekdayHeaders

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.xs), count: 7), spacing: DS.Spacing.xs) {
                ForEach(Array(cellData.enumerated()), id: \.offset) { _, dayOrNil in
                    if let day = dayOrNil {
                        calendarDayCell(day: day, payments: paymentsByDay[day] ?? [])
                    } else {
                        Color.clear
                            .frame(minHeight: 50)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    private var weekdayHeaders: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let startIndex = appFirstWeekday - 1
        let reorderedSymbols = Array(symbols[startIndex...]) + Array(symbols[..<startIndex])

        return HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(reorderedSymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func calendarDayCell(day: Int, payments: [ScheduledPayment]) -> some View {
        let isToday = isCurrentDay(day)
        let isSelected = selectedDay == day
        let hasPayments = !payments.isEmpty

        return Button {
            dsWithAnimation(reduceMotion) {
                if selectedDay == day {
                    selectedDay = nil
                } else {
                    selectedDay = day
                }
            }
        } label: {
            VStack(spacing: DS.Spacing.xxs) {
                Text("\(day)")
                    .font(.caption2.weight(isToday || isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : (isToday ? Color.electricIndigo : .secondary))

                if hasPayments {
                    HStack(spacing: 3) {
                        ForEach(Array(payments.prefix(3).enumerated()), id: \.offset) { _, payment in
                            Circle()
                                .fill(dotColor(for: payment, day: day, isSelected: isSelected))
                                .frame(width: 6, height: 6)
                        }
                        if payments.count > 3 {
                            Text("+\(payments.count - 3)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xs)
            .frame(minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                    .fill(backgroundColor(isToday: isToday, isSelected: isSelected, hasPayments: hasPayments))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                    .stroke(isSelected ? Color.electricIndigo : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    /// Dot color: electricIndigo if paid, hotPink if overdue, subcategory color otherwise
    private func dotColor(for payment: ScheduledPayment, day: Int, isSelected: Bool) -> Color {
        if isSelected { return .white }
        let isPaid = (viewModel.paidStatusForMonth[payment.id.uuidString] ?? 0) > 0
        if isPaid { return Color.electricIndigo }
        // Check if overdue (this specific day is past today in the current month)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let isCurrentMonth = calendar.isDate(viewModel.selectedMonth, equalTo: today, toGranularity: .month)
        if isCurrentMonth {
            let todayDay = calendar.component(.day, from: today)
            if day < todayDay { return Color.hotPink }
        }
        let color = payment.subcategory?.colorHex ?? payment.subcategory?.category?.colorHex ?? "#6366F1"
        return Color(hex: color)
    }

    private func backgroundColor(isToday: Bool, isSelected: Bool, hasPayments: Bool) -> Color {
        if isSelected {
            return Color.electricIndigo
        } else if isToday {
            return Color.electricIndigo.opacity(0.08)
        } else if hasPayments {
            return Color(.tertiarySystemFill).opacity(0.7)
        } else {
            return Color(.tertiarySystemFill).opacity(0.3)
        }
    }

    private func isCurrentDay(_ day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let displayedMonth = viewModel.selectedMonth

        return calendar.component(.day, from: today) == day &&
               calendar.component(.month, from: today) == calendar.component(.month, from: displayedMonth) &&
               calendar.component(.year, from: today) == calendar.component(.year, from: displayedMonth)
    }

    private var monthPaymentsList: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let month = viewModel.selectedMonth
        let isCurrentMonth = calendar.isDate(month, equalTo: today, toGranularity: .month)
        let isPastMonth = calendar.startOfMonth(for: month) < calendar.startOfMonth(for: today)
        let paidStatus = viewModel.paidStatusForMonth

        // Build one summary per occurrence, filtered by selectedDay
        var summaries: [ScheduledPaymentSummary] = []
        for payment in activePayments {
            let dates = viewModel.getPaymentDatesInMonth(payment: payment, month: month)
            let relevantDates: [Date]
            if let selectedDay = selectedDay {
                relevantDates = dates.filter { calendar.component(.day, from: $0) == selectedDay }
            } else {
                relevantDates = dates
            }
            guard !relevantDates.isEmpty else { continue }

            let paidCount = paidStatus[payment.id.uuidString] ?? 0
            var remainingPaid = paidCount
            let (icon, color) = viewModel.getPaymentDisplayProperties(payment: payment)

            for date in relevantDates.sorted() {
                let dueStatus: DueStatus
                if isPastMonth {
                    dueStatus = .past
                } else if isCurrentMonth {
                    let dueDate = calendar.startOfDay(for: date)
                    let daysUntil = calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0
                    if daysUntil < 0 { dueStatus = .past }
                    else if daysUntil == 0 { dueStatus = .today }
                    else { dueStatus = .upcoming }
                } else {
                    dueStatus = .upcoming
                }

                let daysUntilDue = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                let isPaid = remainingPaid > 0
                if isPaid { remainingPaid -= 1 }

                summaries.append(ScheduledPaymentSummary(
                    payment: payment,
                    dueDate: date,
                    dueStatus: dueStatus,
                    daysUntilDue: daysUntilDue,
                    icon: icon,
                    color: color,
                    isPaidForMonth: isPaid
                ))
            }
        }

        let sorted = summaries.sorted { $0.dueDate < $1.dueDate }

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let day = selectedDay {
                HStack {
                    Text(selectedDayLabel(day: day))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        dsWithAnimation(reduceMotion) {
                            selectedDay = nil
                        }
                    } label: {
                        Text(NSLocalizedString("scheduled.calendar.show.all", comment: ""))
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(Color.electricIndigo)
                    }
                    .buttonStyle(.plain)
                }
            }

            if sorted.isEmpty {
                Text(selectedDay != nil
                     ? NSLocalizedString("scheduled.calendar.day.empty", comment: "")
                     : NSLocalizedString("scheduled.calendar.month.empty", comment: ""))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xl)
            } else {
                ForEach(sorted) { summary in
                    ScheduledPaymentRowView(
                        summary: summary,
                        currencyCode: summary.payment.currencyCode
                    )
                }
            }
        }
        .padding(.top, DS.Spacing.md)
    }

    private func selectedDayLabel(day: Int) -> String {
        let calendar = Calendar.current
        let month = viewModel.selectedMonth
        let components = calendar.dateComponents([.year, .month], from: month)

        if let date = calendar.date(from: DateComponents(year: components.year, month: components.month, day: day)) {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return "\(day)"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        YalaEmptyState.noScheduledPayments(icon: emptyStateIcon)
            .padding(.top, DS.Spacing.xxxl)
    }

    private var emptyStateIcon: String {
        switch tab {
        case .recurring:
            return "arrow.trianglehead.2.clockwise.rotate.90"
        case .subscriptions:
            return "creditcard.and.123"
        case .all:
            return "calendar.badge.clock"
        }
    }
}
