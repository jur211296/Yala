//
//  ScheduledPaymentsWidget.swift
//  Yala
//
//  Widget displaying scheduled payments summary, list, or calendar in PanelView.
//  Reads from PanelScheduledPaymentsData (pre-computed in PanelViewModel) —
//  zero iteration over @Observable models in body.
//

import SwiftUI

struct ScheduledPaymentsWidget: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let data: PanelScheduledPaymentsData
    let currencyCode: String
    let mode: ScheduledPaymentsWidgetMode

    /// PP2-06b: tamaño del card. `.small` fuerza summary compacto y oculta el filter selector.
    var size: WidgetSize = .medium

    /// Filter state (all/recurring/subscriptions)
    @Binding var filter: ScheduledPaymentsWidgetFilter

    /// Callback when user taps to show more
    var onShowMore: (() -> Void)?

    @Namespace private var filterNamespace

    var body: some View {
        Group {
            if size == .small {
                smallCardContent
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    headerSection

                    switch mode {
                    case .summary:
                        if data.activeCount == 0 {
                            emptyListState
                        } else {
                            summaryContent
                        }
                    case .list:
                        listContent
                    case .calendar:
                        if data.activeCount == 0 {
                            emptyListState
                        } else {
                            calendarContent
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .solidCard(padding: DS.Card.paddingCompact)
        .frame(height: size == .small ? WidgetSize.smallHeight : nil)
    }

    // MARK: - Small Layout (PP2-06b)

    private var smallCardContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            PanelSmallWidgetHeader(
                title: smallDynamicTitle,
                accessibilityLabel: L10n.Panel.seeMoreHintScheduled,
                action: onShowMore
            )

            if data.activeCount == 0 || data.monthlyTotal == 0 {
                smallEmptyState
            } else {
                HStack(alignment: .center, spacing: DS.Spacing.sm) {
                    smallKPIBlock
                    Spacer(minLength: 0)
                    smallRing
                        .accessibilityLabel(ringAccessibilityLabel)
                }

                smallInfoText

                Spacer(minLength: 0)

                filterSelector
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var smallKPIBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(appPreferences.currency(smallToPayAmount, currencyCode: currencyCode))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(L10n.Scheduled.Widget.smallToPay)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }

    private var smallRing: some View {
        ZStack {
            ScoreRingView(
                progress: smallProgress,
                size: 56,
                lineWidth: 7,
                foreground: smallRingColor
            )
            Text("\(smallPercentPaid)%")
                .font(DS.Typography.captionSmall.bold())
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(width: 56, height: 56)
    }

    /// % se omite: ya vive dentro del ring.
    private var smallInfoText: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(String(
                format: L10n.Scheduled.Widget.smallPaidAmount,
                appPreferences.currency(data.paidAmount, currencyCode: currencyCode)
            ))
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Text(String(
                format: L10n.Scheduled.Widget.smallActivePending,
                data.activeCount,
                data.pendingCount
            ))
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Small derived values

    private var smallToPayAmount: Double {
        max(0, data.monthlyTotal - data.paidAmount)
    }

    private var smallProgress: Double {
        guard data.monthlyTotal > 0 else { return 0 }
        return max(0, min(1, data.paidAmount / data.monthlyTotal))
    }

    private var smallPercentPaid: Int {
        Int((smallProgress * 100).rounded())
    }

    private var ringAccessibilityLabel: String {
        "\(smallPercentPaid)%"
    }

    private var smallDynamicTitle: String {
        switch filter {
        case .all: return L10n.Scheduled.Widget.smallTitle
        case .recurring: return L10n.Scheduled.Tab.recurring
        case .subscriptions: return L10n.Scheduled.Tab.subscriptions
        }
    }

    /// Large mode title — mirror dynamic behavior of `smallDynamicTitle` but
    /// uses the full-form labels ("Pagos planificados" / "Pagos recurrentes")
    /// that read better in the wider layout.
    private var largeDynamicTitle: String {
        switch filter {
        case .all: return L10n.WidgetType.scheduledPayments
        case .recurring: return L10n.Scheduled.Widget.largeTitleRecurring
        case .subscriptions: return L10n.Scheduled.Tab.subscriptions
        }
    }

    private static let ringFromRGB: (r: CGFloat, g: CGFloat, b: CGFloat) = {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color.hotPink).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }()

    private static let ringToRGB: (r: CGFloat, g: CGFloat, b: CGFloat) = {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color.indigo).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }()

    /// Color del ring interpolado entre hotPink (0%) e indigo (100%).
    private var smallRingColor: Color {
        let t = smallProgress
        let from = Self.ringFromRGB
        let to = Self.ringToRGB
        return Color(
            red: from.r + (to.r - from.r) * t,
            green: from.g + (to.g - from.g) * t,
            blue: from.b + (to.b - from.b) * t
        )
    }

    private var smallEmptyState: some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(L10n.Scheduled.Widget.emptyTitle)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xxs) {
                    Text(largeDynamicTitle)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    InfoHintButton(
                        title: largeDynamicTitle,
                        message: L10n.Widget.Hint.scheduledPayments
                    )
                }

                // Period label
                Text(data.periodLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                // Filter selector
                filterSelector
            }
        }
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
            dsWithAnimation(reduceMotion, .spring(response: 0.3, dampingFraction: 0.7)) {
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
        VStack(spacing: DS.Spacing.md) {
            // Amount
            Text(appPreferences.currency(data.monthlyTotal, currencyCode: currencyCode))
                .font(DS.Typography.amountLarge)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(.primary)

            // Payment count
            Text(String(format: L10n.Scheduled.Widget.count, data.activeCount))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
    }

    // MARK: - List Content

    private var listContent: some View {
        VStack(spacing: DS.Spacing.md) {
            if data.upcomingPayments.isEmpty {
                emptyListState
            } else {
                ForEach(data.upcomingPayments) { item in
                    paymentRow(item)
                }
            }
        }
    }

    private var emptyListState: some View {
        YalaEmptyState(
            icon: "calendar.badge.clock",
            title: L10n.Scheduled.Widget.emptyTitle,
            message: L10n.Scheduled.Widget.emptyMessage,
            style: .widget
        )
    }

    private func paymentRow(_ item: ScheduledPaymentListItem) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color(hex: item.color))
                    .frame(width: 36, height: 36)

                Image(systemName: item.icon)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            // Info
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(item.name)
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
                let prefix = item.isIncome ? "+" : "-"
                Text(prefix + appPreferences.currency(item.amount, currencyCode: item.currencyCode, forceFullPrecision: true, isEstimate: item.isVariableAmount))
                    .font(DS.Typography.headline)
                    .foregroundStyle(item.isIncome ? Color.priorityNeed : Color.hotPink)
                    .opacity(item.isPaid || item.isSkipped ? 0.6 : 1.0)

                if item.isSkipped {
                    Image(systemName: "arrow.uturn.forward.circle")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                } else if item.isPaid {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: - Calendar Content

    /// First day of week from app settings (1 = Sunday, 2 = Monday, etc.)
    @Environment(AppPreferences.self) private var appPreferences

    private var calendarContent: some View {
        VStack(spacing: DS.Spacing.sm) {
            weekdayHeaders
            calendarGrid
        }
    }

    private var weekdayHeaders: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let startIndex = appPreferences.firstWeekday - 1
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
        let displayMonth = data.displayMonth
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayMonth)?.count ?? 30

        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)) ?? displayMonth
        let firstDayWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let emptyCellsCount = (firstDayWeekday - appPreferences.firstWeekday + 7) % 7

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
                    calendarDayCell(day: day, entries: data.paymentsByDay[day] ?? [])
                } else {
                    Color.clear
                        .frame(minHeight: 56)
                }
            }
        }
    }

    private func calendarDayCell(day: Int, entries: [ScheduledPaymentCalendarEntry]) -> some View {
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
                                    .accessibilityHidden(true)
                            } else if entry.isPaid {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 6, weight: .bold)) // A11Y-DT: fixed size — calendar micro-badge
                                    .foregroundStyle(theme.accent)
                                    .accessibilityHidden(true)
                            }
                            Text(entry.name)
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
        let today = Date.now

        return calendar.component(.day, from: today) == day &&
               calendar.component(.month, from: today) == calendar.component(.month, from: data.displayMonth) &&
               calendar.component(.year, from: today) == calendar.component(.year, from: data.displayMonth)
    }
}
