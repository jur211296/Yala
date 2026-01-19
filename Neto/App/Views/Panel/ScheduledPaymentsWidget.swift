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
    let size: WidgetSize
    let currentMonth: Date

    /// Filter state (all/recurring/subscriptions)
    @Binding var filter: ScheduledPaymentsWidgetFilter

    /// View mode for medium size (summary/list)
    @Binding var viewMode: ScheduledPaymentsWidgetMode

    /// Callback when user taps to show more
    var onShowMore: (() -> Void)?

    @Namespace private var filterNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            headerSection

            if size == .large {
                calendarContent
            } else {
                // Medium size: summary or list based on viewMode
                if viewMode == .summary {
                    summaryContent
                } else {
                    listContent
                }
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
            Text(L10n.WidgetType.scheduledPayments)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                // View mode selector (only for medium size)
                if size == .medium {
                    viewModeSelector
                }

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

    private var viewModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ScheduledPaymentsWidgetMode.allCases) { mode in
                viewModeButton(for: mode)
            }
        }
        .padding(DS.Spacing.xxs)
        .background(Color.netoSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func viewModeButton(for mode: ScheduledPaymentsWidgetMode) -> some View {
        let isSelected = viewMode == mode

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewMode = mode
            }
        } label: {
            Image(systemName: mode.iconName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .foregroundStyle(isSelected ? .white : Color.netoSecondaryText)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.electricIndigo)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
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
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
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

    // MARK: - Summary Content (Medium - Summary Mode)

    private var summaryContent: some View {
        let monthlyTotal = calculateMonthlyTotal()
        let activeCount = filteredPayments.count

        return VStack(spacing: DS.Spacing.md) {
            // Month label
            Text(monthYearLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

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

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth).capitalized
    }

    private func paymentCountLabel(_ count: Int) -> String {
        let format = NSLocalizedString("scheduled.widget.count", comment: "")
        return String(format: format, count)
    }

    private func calculateMonthlyTotal() -> Double {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return 0
        }

        var total: Double = 0

        for payment in filteredPayments {
            let occurrences = getPaymentDatesInMonth(payment: payment, month: currentMonth)
            total += payment.amount * Double(occurrences.count)
        }

        return total
    }

    // MARK: - List Content (Medium - List Mode)

    private var listContent: some View {
        // Placeholder - will be implemented in Increment 3
        VStack(spacing: DS.Spacing.md) {
            Text("Lista de pagos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Calendar Content (Large)

    private var calendarContent: some View {
        // Placeholder - will be implemented in Increment 4
        VStack(spacing: DS.Spacing.md) {
            Text("Calendario")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
