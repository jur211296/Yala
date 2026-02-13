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
    }

    // MARK: - Filtered Payments

    private var activePayments: [ScheduledPayment] {
        payments.filter { $0.isActive }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let monthlyTotal = viewModel.calculateMonthlyTotal(
            subscriptions: activePayments,
            for: viewModel.calendarDisplayedMonth,
            preferredCurrencyCode: currencyCode
        )

        return VStack(spacing: DS.Spacing.md) {
            // Month label
            Text(monthYearLabel)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)

            // Amount
            Text(YalaFormatter.currency(value: monthlyTotal, currencyCode: currencyCode))
                .font(.system(size: scaledAmountSize, weight: .bold, design: .rounded))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(.primary)

            // Payment count
            Text(paymentCountLabel)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
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

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: viewModel.calendarDisplayedMonth).capitalized
    }

    private var paymentCountLabel: String {
        let activeCount = activePayments.count
        let format = NSLocalizedString("scheduled.payments.count", comment: "")
        return String(format: format, activeCount)
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
            if viewModel.groupedPayments.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.groupedPayments, id: \.status) { section in
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
            // Month navigation
            monthNavigationHeader

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
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthYearLabel)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                dsWithAnimation(reduceMotion) {
                    selectedDay = nil
                    viewModel.nextMonth()
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
    }

    private var calendarGrid: some View {
        let calendar = Calendar.current
        let month = viewModel.calendarDisplayedMonth
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
                            .frame(minHeight: 70)
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
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("\(day)")
                    .font(.caption2.weight(isToday || isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : (isToday ? Color.electricIndigo : .secondary))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if hasPayments {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        ForEach(payments.prefix(2), id: \.persistentModelID) { payment in
                            paymentPill(payment, isSelected: isSelected)
                        }
                        if payments.count > 2 {
                            Text("+\(payments.count - 2)")
                                .font(DS.Typography.captionSmall).fontWeight(.medium)
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                                .padding(.leading, 2)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.xs)
            .frame(minHeight: 70)
            .frame(maxWidth: .infinity, alignment: .topLeading)
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

    private func paymentPill(_ payment: ScheduledPayment, isSelected: Bool = false) -> some View {
        let color = payment.subcategory?.colorHex ?? payment.subcategory?.category?.colorHex ?? "#6366F1"

        return HStack(spacing: DS.Spacing.xxs) {
            Circle()
                .fill(isSelected ? Color.white : Color(hex: color))
                .frame(width: 6, height: 6)

            Text(payment.name)
                .font(DS.Typography.captionSmall).fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xxs)
        .background(
            Capsule()
                .fill(isSelected ? Color.white.opacity(0.2) : Color(hex: color).opacity(0.15))
        )
    }

    private func isCurrentDay(_ day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let displayedMonth = viewModel.calendarDisplayedMonth

        return calendar.component(.day, from: today) == day &&
               calendar.component(.month, from: today) == calendar.component(.month, from: displayedMonth) &&
               calendar.component(.year, from: today) == calendar.component(.year, from: displayedMonth)
    }

    private var monthPaymentsList: some View {
        let calendar = Calendar.current
        let month = viewModel.calendarDisplayedMonth

        var paymentsToShow: [(ScheduledPayment, [Date])] = []

        for payment in activePayments {
            let dates = viewModel.getPaymentDatesInMonth(payment: payment, month: month)

            if let selectedDay = selectedDay {
                let filteredDates = dates.filter { calendar.component(.day, from: $0) == selectedDay }
                if !filteredDates.isEmpty {
                    paymentsToShow.append((payment, filteredDates))
                }
            } else {
                if !dates.isEmpty {
                    paymentsToShow.append((payment, dates))
                }
            }
        }

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

            if paymentsToShow.isEmpty {
                Text(selectedDay != nil
                     ? NSLocalizedString("scheduled.calendar.day.empty", comment: "")
                     : NSLocalizedString("scheduled.calendar.month.empty", comment: ""))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xl)
            } else {
                ForEach(paymentsToShow.sorted { $0.1.first ?? Date() < $1.1.first ?? Date() }, id: \.0.persistentModelID) { payment, dates in
                    calendarPaymentRow(payment: payment, dates: dates)
                }
            }
        }
        .padding(.top, DS.Spacing.md)
    }

    private func selectedDayLabel(day: Int) -> String {
        let calendar = Calendar.current
        let month = viewModel.calendarDisplayedMonth
        let components = calendar.dateComponents([.year, .month], from: month)

        if let date = calendar.date(from: DateComponents(year: components.year, month: components.month, day: day)) {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return "\(day)"
    }

    private func calendarPaymentRow(payment: ScheduledPayment, dates: [Date]) -> some View {
        let color = payment.subcategory?.colorHex ?? payment.subcategory?.category?.colorHex ?? "#6366F1"
        let icon = payment.subcategory?.iconName ?? payment.subcategory?.category?.iconName ?? "calendar.badge.clock"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM"

        return NavigationLink(value: payment.persistentModelID) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(payment.name)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)

                    Text(dates.map { dateFormatter.string(from: $0) }.joined(separator: ", "))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(YalaFormatter.currency(value: payment.amount, currencyCode: currencyCode, forceFullPrecision: true))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.Spacing.md)
            .background(Color.yalaCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
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
