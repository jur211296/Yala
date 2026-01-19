//
//  SubscriptionsContentView.swift
//  Neto
//
//  Content view for subscriptions tab with summary card, view mode toggle, and calendar/list
//

import SwiftData
import SwiftUI

struct SubscriptionsContentView: View {
    @Bindable var viewModel: ScheduledPaymentsViewModel
    let subscriptions: [ScheduledPayment]
    let currencyCode: String

    @Environment(\.colorScheme) private var colorScheme
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
        .padding(.bottom, 100) // Space for FAB
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let monthlyTotal = viewModel.calculateMonthlyTotal(
            subscriptions: subscriptions,
            for: viewModel.calendarDisplayedMonth
        )

        return VStack(spacing: DS.Spacing.md) {
            // Month label
            Text(monthYearLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            // Amount
            Text(NetoFormatter.currency(value: monthlyTotal, currencyCode: currencyCode))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.electricIndigo, Color.hotPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Subscription count
            Text(subscriptionCountLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .padding(.horizontal, DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(Color.netoCard)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.electricIndigo.opacity(0.3), Color.hotPink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.electricIndigo.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: viewModel.calendarDisplayedMonth).capitalized
    }

    private var subscriptionCountLabel: String {
        let activeCount = subscriptions.filter { $0.isActive }.count
        let format = NSLocalizedString("subscriptions.count", comment: "")
        return String(format: format, activeCount)
    }

    // MARK: - View Mode Header

    private var viewModeHeader: some View {
        HStack {
            Text(NSLocalizedString("subscriptions.title", comment: ""))
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            viewModeSelector
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var viewModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(PaymentsViewMode.allCases) { mode in
                viewModeButton(for: mode)
            }
        }
        .padding(DS.Spacing.xxs)
        .background(Color.netoSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func viewModeButton(for mode: PaymentsViewMode) -> some View {
        let isSelected = viewModel.paymentsViewMode == mode

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.paymentsViewMode = mode
            }
        } label: {
            Image(systemName: mode.iconName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.sm)
                .foregroundStyle(isSelected ? .white : Color.netoSecondaryText)
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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if subscriptions.isEmpty {
                emptyState
            } else {
                ForEach(subscriptions.sorted { $0.nextDueDate < $1.nextDueDate }) { subscription in
                    let (icon, color) = viewModel.getPaymentDisplayProperties(payment: subscription)
                    let summary = ScheduledPaymentSummary(
                        payment: subscription,
                        dueStatus: getDueStatus(for: subscription),
                        daysUntilDue: getDaysUntilDue(for: subscription),
                        icon: icon,
                        color: color
                    )
                    ScheduledPaymentRowView(
                        summary: summary,
                        currencyCode: currencyCode
                    )
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func getDueStatus(for payment: ScheduledPayment) -> DueStatus {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDate = calendar.startOfDay(for: payment.nextDueDate)
        let days = calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0

        if days < 0 { return .past }
        if days == 0 { return .today }
        return .upcoming
    }

    private func getDaysUntilDue(for payment: ScheduledPayment) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDate = calendar.startOfDay(for: payment.nextDueDate)
        return calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0
    }

    // MARK: - Calendar Content

    private var calendarContent: some View {
        VStack(spacing: DS.Spacing.md) {
            // Month navigation
            monthNavigationHeader

            // Calendar grid
            calendarGrid

            // Subscriptions for selected month
            monthSubscriptionsList
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDay = nil
                    viewModel.previousMonth()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.electricIndigo)
                    .frame(width: 36, height: 36)
                    .background(Color.electricIndigo.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthYearLabel)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDay = nil
                    viewModel.nextMonth()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.electricIndigo)
                    .frame(width: 36, height: 36)
                    .background(Color.electricIndigo.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private var calendarGrid: some View {
        let calendar = Calendar.current
        let month = viewModel.calendarDisplayedMonth
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30

        // Get the weekday of the first day of the month (1 = Sunday, 7 = Saturday)
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let firstDayWeekday = calendar.component(.weekday, from: firstDayOfMonth)

        // Use app's first day of week setting (1 = Sunday, 2 = Monday, etc.)
        let emptyCellsCount = (firstDayWeekday - appFirstWeekday + 7) % 7

        // Build payment dates map with full subscription info
        var paymentsByDay: [Int: [ScheduledPayment]] = [:]
        for subscription in subscriptions where subscription.isActive {
            let dates = viewModel.getPaymentDatesInMonth(payment: subscription, month: month)
            for date in dates {
                let day = calendar.component(.day, from: date)
                paymentsByDay[day, default: []].append(subscription)
            }
        }

        // Build array of cell data: nil for empty cells, day number for day cells
        var cellData: [Int?] = []
        for _ in 0..<emptyCellsCount {
            cellData.append(nil)
        }
        for day in 1...daysInMonth {
            cellData.append(day)
        }

        return VStack(spacing: DS.Spacing.sm) {
            // Weekday headers
            weekdayHeaders

            // Calendar days grid - 7 columns
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(cellData.enumerated()), id: \.offset) { index, dayOrNil in
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
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    private var weekdayHeaders: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols

        // Reorder symbols based on app's first day of week setting
        // symbols is always [Sun, Mon, Tue, Wed, Thu, Fri, Sat] (indices 0-6)
        // appFirstWeekday: 1 = Sunday, 2 = Monday, etc.
        let startIndex = appFirstWeekday - 1
        let reorderedSymbols = Array(symbols[startIndex...]) + Array(symbols[..<startIndex])

        return HStack(spacing: 4) {
            ForEach(Array(reorderedSymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
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
            withAnimation(.easeInOut(duration: 0.2)) {
                if selectedDay == day {
                    selectedDay = nil  // Deselect if tapping same day
                } else {
                    selectedDay = day
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                // Day number
                Text("\(day)")
                    .font(.caption2.weight(isToday || isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : (isToday ? Color.electricIndigo : .secondary))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Subscription pills (show up to 2, then +N)
                if hasPayments {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(payments.prefix(2), id: \.persistentModelID) { subscription in
                            subscriptionPill(subscription, isSelected: isSelected)
                        }
                        if payments.count > 2 {
                            Text("+\(payments.count - 2)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                                .padding(.leading, 2)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(4)
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

    private func subscriptionPill(_ subscription: ScheduledPayment, isSelected: Bool = false) -> some View {
        let color = subscription.subcategory?.colorHex ?? subscription.subcategory?.category.colorHex ?? "#6366F1"

        return HStack(spacing: 2) {
            Circle()
                .fill(isSelected ? Color.white : Color(hex: color))
                .frame(width: 6, height: 6)

            Text(subscription.name)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
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

    private var monthSubscriptionsList: some View {
        let calendar = Calendar.current
        let month = viewModel.calendarDisplayedMonth

        // Get subscriptions filtered by selected day or all for the month
        var subscriptionsToShow: [(ScheduledPayment, [Date])] = []

        for subscription in subscriptions where subscription.isActive {
            let dates = viewModel.getPaymentDatesInMonth(payment: subscription, month: month)

            if let selectedDay = selectedDay {
                // Filter dates to only those matching selected day
                let filteredDates = dates.filter { calendar.component(.day, from: $0) == selectedDay }
                if !filteredDates.isEmpty {
                    subscriptionsToShow.append((subscription, filteredDates))
                }
            } else {
                // Show all for the month
                if !dates.isEmpty {
                    subscriptionsToShow.append((subscription, dates))
                }
            }
        }

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header showing selected day or month
            if let day = selectedDay {
                HStack {
                    Text(selectedDayLabel(day: day))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDay = nil
                        }
                    } label: {
                        Text(NSLocalizedString("subscriptions.show.all", comment: ""))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.electricIndigo)
                    }
                    .buttonStyle(.plain)
                }
            }

            if subscriptionsToShow.isEmpty {
                Text(selectedDay != nil
                     ? NSLocalizedString("subscriptions.day.empty", comment: "")
                     : NSLocalizedString("subscriptions.calendar.empty", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xl)
            } else {
                ForEach(subscriptionsToShow.sorted { $0.1.first ?? Date() < $1.1.first ?? Date() }, id: \.0.persistentModelID) { subscription, dates in
                    calendarSubscriptionRow(subscription: subscription, dates: dates)
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

    private func calendarSubscriptionRow(subscription: ScheduledPayment, dates: [Date]) -> some View {
        let color = subscription.subcategory?.colorHex ?? subscription.subcategory?.category.colorHex ?? "#6366F1"
        let icon = subscription.subcategory?.iconName ?? subscription.subcategory?.category.iconName ?? "creditcard.and.123"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM"

        return NavigationLink(value: subscription.persistentModelID) {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(dates.map { dateFormatter.string(from: $0) }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Amount
                Text(NetoFormatter.currency(value: subscription.amount, currencyCode: currencyCode))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)

                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.Spacing.md)
            .background(Color.netoCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.xxl) {
            ZStack {
                Circle()
                    .fill(Color.electricIndigo.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.electricIndigo, Color.hotPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: DS.Spacing.sm) {
                Text(NSLocalizedString("subscriptions.empty.title", comment: ""))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("subscriptions.empty.message", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxxl)
    }
}
