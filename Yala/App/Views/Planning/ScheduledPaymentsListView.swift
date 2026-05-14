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
    @Environment(\.yalaTheme) private var theme
    @Bindable var viewModel: ScheduledPaymentsViewModel
    let payments: [ScheduledPayment]
    let tab: ScheduledPaymentsTab
    let currencyCode: String
    let onRefresh: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var viewModeNamespace

    @Environment(AppPreferences.self) private var appPreferences

    /// Selected day in calendar (nil = show all for the month)
    @State private var selectedDay: Int? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Hero edge-to-edge centrado (total + chips paid/pending)
            heroSection

            // PeriodNavigationHeader shared (TX-P2)
            PeriodNavigationHeader(
                currentLabel: viewModel.monthYearLabel,
                onPrevious: {
                    selectedDay = nil
                    viewModel.previousMonth()
                    onRefresh()
                },
                onNext: {
                    selectedDay = nil
                    viewModel.nextMonth()
                    onRefresh()
                },
                onTapLabel: { viewModel.showPeriodSelector = true }
            )
            .padding(.horizontal, DS.Spacing.lg)

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
            .presentationDetents(DS.Adaptive.sheetDetents([.medium]))
        }
    }

    // MARK: - Filtered Payments

    private var activePayments: [ScheduledPayment] {
        payments.filter { $0.isActive }
    }

    // MARK: - Hero Section (polish panel-aligned, Bloque C)

    private var heroSection: some View {
        let monthlyTotal = viewModel.calculateMonthlyTotal(
            subscriptions: activePayments,
            for: viewModel.selectedMonth,
            preferredCurrencyCode: currencyCode
        )
        let paidTotal = viewModel.monthlyTotalPaid(preferredCurrencyCode: currencyCode)
        let pendingTotal = viewModel.monthlyTotalPending(preferredCurrencyCode: currencyCode)

        return VStack(alignment: .center, spacing: DS.Spacing.sm) {
            // Total label + monto (centrado)
            VStack(alignment: .center, spacing: DS.Spacing.xxs) {
                Text("\(L10n.Planning.Scheduled.totalLabel) · \(viewModel.monthYearLabel)")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                Text(appPreferences.currency(monthlyTotal, currencyCode: currencyCode))
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }

            // Paid / Pending chips (tap toggles filter)
            HStack(spacing: DS.Spacing.lg) {
                paidPendingChip(
                    status: .paid,
                    dotColor: theme.accent,
                    label: NSLocalizedString("scheduled.summary.paid", comment: ""),
                    value: paidTotal
                )
                paidPendingChip(
                    status: .pending,
                    dotColor: Color.hotPink,
                    label: NSLocalizedString("scheduled.summary.pending", comment: ""),
                    value: pendingTotal
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(heroAccessibilityLabel(
            total: monthlyTotal,
            paid: paidTotal,
            pending: pendingTotal
        ))
    }

    private func paidPendingChip(
        status: PaymentStatusFilter,
        dotColor: Color,
        label: String,
        value: Double
    ) -> some View {
        let isActive = viewModel.paymentStatusFilter == status
        return Button {
            dsWithAnimation(reduceMotion) {
                viewModel.paymentStatusFilter = isActive ? .all : status
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                Text(label)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                Text(appPreferences.currency(value, currencyCode: currencyCode))
                    .font(DS.Typography.label)
                    .foregroundStyle(dotColor)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(
                Capsule().fill(isActive ? dotColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    /// Agrupa hero en un único anuncio VoiceOver coherente (compensa eliminar el card).
    private func heroAccessibilityLabel(
        total: Double,
        paid: Double,
        pending: Double
    ) -> String {
        let totalLine = "\(L10n.Planning.Scheduled.totalLabel) \(viewModel.monthYearLabel): \(appPreferences.currency(total, currencyCode: currencyCode))"
        let paidLine = "\(NSLocalizedString("scheduled.summary.paid", comment: "")) \(appPreferences.currency(paid, currencyCode: currencyCode))"
        let pendingLine = "\(NSLocalizedString("scheduled.summary.pending", comment: "")) \(appPreferences.currency(pending, currencyCode: currencyCode))"
        return [totalLine, paidLine, pendingLine].joined(separator: ". ")
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
        HStack(spacing: DS.Spacing.sm) {
            ForEach(PaymentsViewMode.allCases) { mode in
                viewModeButton(for: mode)
            }
        }
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
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : theme.secondaryText)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .matchedGeometryEffect(id: "viewModeSelector", in: viewModeNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
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

    private var calendarGrid: some View {
        let calendar = Calendar.current
        let month = viewModel.selectedMonth
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30

        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let firstDayWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let emptyCellsCount = (firstDayWeekday - appPreferences.firstWeekday + 7) % 7

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
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    private var weekdayHeaders: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let startIndex = appPreferences.firstWeekday - 1
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
                    .foregroundStyle(isSelected ? .white : (isToday ? theme.accent : .secondary))

                if hasPayments {
                    HStack(spacing: 3) {
                        ForEach(Array(payments.prefix(3).enumerated()), id: \.offset) { _, payment in
                            Circle()
                                .fill(dotColor(for: payment, day: day, isSelected: isSelected))
                                .frame(width: 6, height: 6)
                        }
                        if payments.count > 3 {
                            Text("+\(payments.count - 3)")
                                .font(.system(size: 8, weight: .medium)) // A11Y-DT: fixed size — calendar micro-badge
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
                    .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    /// Dot color: electricIndigo if paid, hotPink if overdue, subcategory color otherwise
    private func dotColor(for payment: ScheduledPayment, day: Int, isSelected: Bool) -> Color {
        if isSelected { return .white }
        let isPaid = (viewModel.paidStatusForMonth[payment.id.uuidString] ?? 0) > 0
        if isPaid { return theme.accent }
        // Check if overdue (this specific day is past today in the current month)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        let isCurrentMonth = calendar.isDate(viewModel.selectedMonth, equalTo: today, toGranularity: .month)
        if isCurrentMonth {
            let todayDay = calendar.component(.day, from: today)
            if day < todayDay { return Color.hotPink }
        }
        let color = payment.subcategory?.colorHex ?? payment.subcategory?.category?.colorHex ?? AppConstants.defaultColorHex
        return Color(hex: color)
    }

    private func backgroundColor(isToday: Bool, isSelected: Bool, hasPayments: Bool) -> Color {
        if isSelected {
            return theme.accent
        } else if isToday {
            return theme.accent.opacity(0.08)
        } else if hasPayments {
            return Color(.tertiarySystemFill).opacity(0.7)
        } else {
            return Color(.tertiarySystemFill).opacity(0.3)
        }
    }

    private func isCurrentDay(_ day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date.now
        let displayedMonth = viewModel.selectedMonth

        return calendar.component(.day, from: today) == day &&
               calendar.component(.month, from: today) == calendar.component(.month, from: displayedMonth) &&
               calendar.component(.year, from: today) == calendar.component(.year, from: displayedMonth)
    }

    private var monthPaymentsList: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
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
                let isSkipped = payment.isDateSkipped(date)
                let isPaid = remainingPaid > 0 && !isSkipped
                if isPaid { remainingPaid -= 1 }

                summaries.append(ScheduledPaymentSummary(
                    payment: payment,
                    dueDate: date,
                    dueStatus: dueStatus,
                    daysUntilDue: daysUntilDue,
                    icon: icon,
                    color: color,
                    isPaidForMonth: isPaid,
                    isSkippedForMonth: isSkipped
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
                            .foregroundStyle(theme.accent)
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

    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    private func selectedDayLabel(day: Int) -> String {
        let calendar = Calendar.current
        let month = viewModel.selectedMonth
        let components = calendar.dateComponents([.year, .month], from: month)

        if let date = calendar.date(from: DateComponents(year: components.year, month: components.month, day: day)) {
            return Self.longDateFormatter.string(from: date)
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
