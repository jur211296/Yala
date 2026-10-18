//
//  ScheduledPaymentsListView.swift
//  Yala
//
//  Contenido de Pagos planificados: cabecera con lo que falta pagar, navegador de mes y tres vistas del mes (lista,
//  línea de tiempo y calendario). Lo usan las pestañas Recurrentes, Suscripciones y Todos.
//
//  Auditoría UX 2.2, lote 10 (Jürgen, 2026-10-15): la lista separa lo que falta de lo hecho (L10-1 B) y suma la línea
//  de tiempo como otra vista (L10-1 C); la cabecera contesta «¿cuánto me falta?» (L10-2 B); el calendario pinta un
//  punto por estado con leyenda y el importe del día (L10-3 B).
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var viewModeNamespace

    @Environment(AppPreferences.self) private var appPreferences

    /// Selected day in calendar (nil = show all for the month)
    @State private var selectedDay: Int? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            heroSection
                .padding(.bottom, DS.Spacing.xs)

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

            // Sin el rótulo de la pestaña: repetía «Todos», que ya está elegido arriba (L10-1).
            HStack {
                Spacer()
                viewModeSelector
            }
            .padding(.horizontal, DS.Spacing.lg)

            Group {
                switch viewModel.paymentsViewMode {
                case .list: listContent
                case .timeline: timelineContent
                case .calendar: calendarContent
                }
            }
            .padding(.top, DS.Spacing.xs)
        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.safeBottom) // Space for FAB
        .sheet(isPresented: $viewModel.showPeriodSelector) {
            ScheduledPaymentPeriodSelectorSheet(
                viewModel: viewModel,
                payments: payments,
                onPeriodChange: { onRefresh() }
            )
            .yalaSheetDetents([.medium])
        }
    }

    /// Todas las fechas del mes (una entrada por fecha), ya filtradas por pestaña.
    private var monthSummaries: [ScheduledPaymentSummary] {
        viewModel.groupedPayments.flatMap(\.payments).sorted { $0.dueDate < $1.dueDate }
    }

    // MARK: - Hero (L10-2)

    private var heroSection: some View {
        let hero = ScheduledPaymentListLogic.Hero(
            pending: viewModel.monthlyTotalPending(preferredCurrencyCode: currencyCode),
            paid: viewModel.monthlyTotalPaid(preferredCurrencyCode: currencyCode)
        )
        // El hero del Panel (`HeroHeader`): rótulo, cifra y detalle a la izquierda. El mes lo dice el navegador de debajo.
        return HeroHeader {
            HeroHeaderLabel(text: L10n.UXL10.heroToPay)
        } period: {
            EmptyView()
        } content: {
            AmountText(
                value: hero.pending,
                currencyCode: currencyCode,
                font: DS.Typography.panelHeroAmount, secondaryFont: DS.Typography.panelHeroAmountSecondary
            )
            .contentTransition(.numericText())
            .accessibilityIdentifier("scheduled_hero_pending")

            if !hero.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    progressBar(fraction: hero.paidFraction)
                    Text(L10n.UXL10.heroPaidOf(
                        appPreferences.currency(hero.paid, currencyCode: currencyCode),
                        appPreferences.currency(hero.total, currencyCode: currencyCode)
                    ))
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("scheduled_hero_paid_of")
                    Text(L10n.UXL10.heroScope)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, DS.Spacing.xxs)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.md)
        .accessibilityElement(children: .contain)
    }

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule().fill(theme.accent).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    // MARK: - View Mode

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
                .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
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
        .accessibilityLabel(mode.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("scheduled_view_mode_\(mode.rawValue)")
    }

    // MARK: - List (L10-1 B)

    private var listContent: some View {
        let sections = ScheduledPaymentListLogic.sections(monthSummaries, date: \.dueDate, state: \.rowState)
        return VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            if sections.isEmpty {
                emptyState
            } else {
                ForEach(sections, id: \.section) { section in
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("\(title(for: section.section)) · \(section.items.count)")
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .accessibilityIdentifier("scheduled_section_\(section.section.rawValue)")

                        ForEach(section.items) { summary in
                            row(summary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func title(for section: ScheduledPaymentListSection) -> String {
        switch section {
        case .toPay: return L10n.UXL10.sectionToPay
        case .paid: return L10n.UXL10.sectionPaid
        case .skipped: return L10n.UXL10.sectionSkipped
        case .paused: return L10n.UXL10.sectionPaused
        }
    }

    /// La fila, con «Pausar» / «Reanudar» en la pulsación larga (L10-7).
    private func row(_ summary: ScheduledPaymentSummary) -> some View {
        ScheduledPaymentRowView(summary: summary, currencyCode: summary.payment.currencyCode)
            .contextMenu { pauseMenu(for: summary.payment) }
    }

    @ViewBuilder
    private func pauseMenu(for payment: ScheduledPayment) -> some View {
        if payment.isPausedByUser {
            Button {
                viewModel.setPaused(payment, paused: false)
            } label: {
                Label(L10n.UXL10.actionResume, systemImage: "play.circle")
            }
        } else if payment.isActive {
            Button {
                viewModel.setPaused(payment, paused: true)
            } label: {
                Label(L10n.UXL10.actionPause, systemImage: "pause.circle")
            }
        }
    }

    // MARK: - Timeline (L10-1 C)

    private var timelineContent: some View {
        let summaries = monthSummaries
        return Group {
            if summaries.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.none) {
                    ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                        timelineRow(summary, isLast: index == summaries.count - 1)
                    }
                }
                .padding(DS.Spacing.lg)
                .panelCard()
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func timelineRow(_ summary: ScheduledPaymentSummary, isLast: Bool) -> some View {
        let state = summary.rowState
        let isToday = Calendar.current.isDateInToday(summary.dueDate)
        let dotColor = ScheduledPaymentListLogic.dotStatus(for: state).color(accent: theme.accent)
        let isFilled = state == .paid || state == .overdue

        return NavigationLink(value: summary.payment.persistentModelID) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                VStack(spacing: DS.Spacing.none) {
                    ZStack {
                        Circle()
                            .fill(isFilled ? dotColor : Color(.tertiarySystemFill))
                            .frame(width: 34, height: 34)
                        if isToday {
                            Circle()
                                .stroke(theme.accent, lineWidth: 2)
                                .frame(width: 34, height: 34)
                        }
                        Text(ScheduledPaymentDateText.day(summary.dueDate))
                            .font(DS.Typography.labelSmall)
                            .fontWeight(.bold)
                            .foregroundStyle(isFilled ? .white : .primary)
                    }
                    if !isLast {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 2)
                            .frame(minHeight: DS.Spacing.xl)
                    }
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(summary.payment.name)
                            .font(DS.Typography.label)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: DS.Spacing.sm)
                        Text(ScheduledPaymentRowView.amountText(summary, appPreferences: appPreferences))
                            .font(DS.Typography.label)
                            .foregroundStyle(ScheduledPaymentRowView.amountColor(state: state, isIncome: summary.payment.isIncome))
                            .lineLimit(1)
                    }
                    HStack(spacing: DS.Spacing.sm) {
                        ScheduledPaymentStatusPill(state: state, isIncome: summary.payment.isIncome)
                        if let account = summary.payment.account?.name, !summary.payment.isGroupPayment {
                            Text(account)
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.bottom, isLast ? DS.Spacing.none : DS.Spacing.lg)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { pauseMenu(for: summary.payment) }
        .accessibilityIdentifier("scheduled_timeline_row")
    }

    // MARK: - Calendar (L10-3 B)

    private var calendarContent: some View {
        VStack(spacing: DS.Spacing.md) {
            calendarGrid
            monthPaymentsList
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var summariesByDay: [Int: [ScheduledPaymentSummary]] {
        Dictionary(grouping: monthSummaries) { Calendar.current.component(.day, from: $0.dueDate) }
    }

    private var calendarGrid: some View {
        let calendar = Calendar.current
        let month = viewModel.selectedMonth
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30

        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let firstDayWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let emptyCellsCount = (firstDayWeekday - appPreferences.firstWeekday.rawValue + 7) % 7
        let byDay = summariesByDay

        var cellData: [Int?] = Array(repeating: nil, count: emptyCellsCount)
        for day in 1...daysInMonth {
            cellData.append(day)
        }

        return VStack(spacing: DS.Spacing.sm) {
            weekdayHeaders

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.xs), count: 7), spacing: DS.Spacing.xs) {
                ForEach(Array(cellData.enumerated()), id: \.offset) { _, dayOrNil in
                    if let day = dayOrNil {
                        calendarDayCell(day: day, summaries: byDay[day] ?? [])
                    } else {
                        Color.clear
                            .frame(minHeight: 50)
                    }
                }
            }

            ScheduledPaymentCalendarLegend()
                .padding(.top, DS.Spacing.xs)
        }
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    private var weekdayHeaders: some View {
        var localeCalendar = Calendar.current
        localeCalendar.locale = AppLocale.current // las iniciales en el idioma de la app, no en el del sistema
        let symbols = localeCalendar.veryShortWeekdaySymbols
        let startIndex = appPreferences.firstWeekday.rawValue - 1
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

    private func calendarDayCell(day: Int, summaries: [ScheduledPaymentSummary]) -> some View {
        let isToday = isCurrentDay(day)
        let isSelected = selectedDay == day
        let hasPayments = !summaries.isEmpty
        let dayAmount = ScheduledPaymentListLogic.dayAmount(summaries.map { ($0.displayAmount, $0.displayCurrencyCode) })

        return Button {
            dsWithAnimation(reduceMotion) {
                selectedDay = selectedDay == day ? nil : day
            }
        } label: {
            VStack(spacing: DS.Spacing.xxs) {
                Text("\(day)")
                    .font(.caption2.weight(isToday || isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : (isToday ? theme.accent : .secondary))

                if hasPayments {
                    HStack(spacing: 3) {
                        ForEach(Array(summaries.prefix(3).enumerated()), id: \.offset) { _, summary in
                            Circle()
                                .fill(isSelected
                                      ? .white
                                      : ScheduledPaymentListLogic.dotStatus(for: summary.rowState).color(accent: theme.accent))
                                .frame(width: 6, height: 6)
                        }
                        if summaries.count > 3 {
                            Text("+\(summaries.count - 3)")
                                .font(.system(size: 8, weight: .medium)) // A11Y-DT: fixed size — calendar micro-badge
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                    }
                    // El importe del día, cuando cabe y comparte divisa (L10-3).
                    if let dayAmount {
                        Text(YalaFormatter.amountCompactTable(value: dayAmount.value))
                            .font(.system(size: 9, weight: .medium)) // A11Y-DT: fixed size — cifra del día en la celda
                            .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
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
        let summaries: [ScheduledPaymentSummary]
        if let selectedDay {
            summaries = summariesByDay[selectedDay]?.sorted { $0.dueDate < $1.dueDate } ?? []
        } else {
            summaries = monthSummaries
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
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if summaries.isEmpty {
                Text(selectedDay != nil
                     ? NSLocalizedString("scheduled.calendar.day.empty", comment: "")
                     : NSLocalizedString("scheduled.calendar.month.empty", comment: ""))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xl)
            } else {
                ForEach(summaries) { summary in
                    row(summary)
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
            formatter.locale = AppLocale.current // en el idioma de la app; por llamada, porque el idioma cambia en caliente
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return "\(day)"
    }

    // MARK: - Empty State

    /// Con pagos que caen otros meses, «Sin pagos este mes»: «Aún no tienes pagos planificados» se lo decía a quien
    /// acababa de crear uno para el día 1 del mes que viene.
    @ViewBuilder
    private var emptyState: some View {
        Group {
            if payments.isEmpty {
                YalaEmptyState.noScheduledPayments(icon: emptyStateIcon)
            } else {
                YalaEmptyState(
                    icon: emptyStateIcon,
                    title: NSLocalizedString("scheduled.calendar.month.empty", comment: ""),
                    message: nil
                )
            }
        }
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
