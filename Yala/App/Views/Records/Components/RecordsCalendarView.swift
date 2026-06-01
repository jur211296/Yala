//
//  RecordsCalendarView.swift
//  Yala
//
//  Vista de calendario para Registros: barras de gasto diario con gradiente,
//  modo continuo (tira de semanas) o paginado por mes según el periodo.
//

import SwiftData
import SwiftUI

// MARK: - View Mode

enum RecordsViewMode: String, CaseIterable, Identifiable {
    case list
    case calendar

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .list: return "list.bullet"
        case .calendar: return "calendar"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .list: return L10n.Records.viewModeListA11y
        case .calendar: return L10n.Records.viewModeCalendarA11y
        }
    }
}

// MARK: - Records Calendar View

/// Calendario de gasto diario. Comparte el render de celda entre el modo continuo
/// (tira de semanas que cubren el rango) y el paginado (un grid mensual navegable);
/// la única diferencia es el predicado `inRange`.
struct RecordsCalendarView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences

    let groups: [(date: Date, records: [TransactionItem])]
    let period: DetailPeriod
    let customDateRange: DateInterval?
    let currencyCode: String
    @Binding var selectedDay: Date?
    @Binding var calendarMonth: Date

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = appPreferences.firstWeekday.rawValue
        return c
    }

    var body: some View {
        let spending = DailySpendingCalculator.compute(groups: groups)
        let range = effectiveRange
        let layout = RecordsCalendarLayout.resolve(
            range: range, firstWeekday: appPreferences.firstWeekday.rawValue, calendar: calendar)

        return Group {
            switch layout {
            case .continuous(let weeks):
                continuousCalendar(weeks: weeks, range: range, spending: spending)
            case .paged(let months):
                pagedCalendar(months: months, spending: spending)
            }
        }
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    // MARK: - Effective range (acotado a los datos visibles)

    /// Intersección del rango del periodo con el rango real de datos — evita semanas o
    /// páginas vacías en `allTime`/custom largos.
    private var effectiveRange: DateInterval {
        let periodRange = period.dateInterval(customRange: customDateRange)
        let dates = groups.map(\.date)
        guard let minDate = dates.min(), let maxDate = dates.max() else { return periodRange }
        let dataStart = calendar.startOfDay(for: minDate)
        let dataEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: maxDate)) ?? maxDate
        let start = max(periodRange.start, dataStart)
        let end = min(periodRange.end, dataEnd)
        guard start < end else { return periodRange }
        return DateInterval(start: start, end: end)
    }

    // MARK: - Weekday headers

    private var weekdayHeaders: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        let startIndex = appPreferences.firstWeekday.rawValue - 1
        let reordered = Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
        return HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(reordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Continuous mode

    private func continuousCalendar(
        weeks: [[Date]], range: DateInterval, spending: DailySpendingCalculator.Result
    ) -> some View {
        let showMonthLabels = monthsSpanned(weeks: weeks, range: range) > 1
        return VStack(spacing: DS.Spacing.xs) {
            weekdayHeaders
            ForEach(Array(weeks.enumerated()), id: \.offset) { idx, week in
                if showMonthLabels,
                    let label = monthLabel(week: week, previous: idx > 0 ? weeks[idx - 1] : nil, range: range) {
                    monthSeparator(label)
                }
                weekRow(week, spending: spending, inRange: { range.contains($0) })
            }
        }
    }

    private func monthsSpanned(weeks: [[Date]], range: DateInterval) -> Int {
        let keys = weeks.flatMap { $0 }
            .filter { range.contains($0) }
            .map { calendar.component(.year, from: $0) * 12 + calendar.component(.month, from: $0) }
        return Set(keys).count
    }

    /// Etiqueta de mes para la primera semana de cada mes (cuando el rango cruza ≥2 meses),
    /// para que los números reiniciados (28, 29, 30, 1, 2…) no confundan.
    private func monthLabel(week: [Date], previous: [Date]?, range: DateInterval) -> String? {
        guard let current = representativeMonth(week, range: range) else { return nil }
        if let previous, let prev = representativeMonth(previous, range: range), prev == current {
            return nil
        }
        return monthName(current, withYear: false)
    }

    private func representativeMonth(_ week: [Date], range: DateInterval) -> Date? {
        let day = week.first { range.contains($0) } ?? week.first
        guard let day else { return nil }
        return calendar.dateInterval(of: .month, for: day)?.start
    }

    private func monthSeparator(_ label: String) -> some View {
        HStack {
            Text(label)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, DS.Spacing.xs)
    }

    // MARK: - Paged mode

    private func pagedCalendar(
        months: [Date], spending: DailySpendingCalculator.Result
    ) -> some View {
        let monthInterval = calendar.dateInterval(of: .month, for: calendarMonth)
            ?? DateInterval(start: calendarMonth, duration: 86_400)
        let weeks = RecordsCalendarLayout.weekRows(in: monthInterval, calendar: calendar)

        return VStack(spacing: DS.Spacing.sm) {
            monthNavigationHeader(months: months)
            VStack(spacing: DS.Spacing.xs) {
                weekdayHeaders
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    weekRow(week, spending: spending, inRange: {
                        calendar.isDate($0, equalTo: calendarMonth, toGranularity: .month)
                    })
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(monthSwipeGesture(months: months))
        }
    }

    /// Header de navegación: chevrons (prev/next) + `Menu` nativo para saltar a cualquier
    /// mes del rango. El swipe sobre el grid lo añade `monthSwipeGesture`.
    private func monthNavigationHeader(months: [Date]) -> some View {
        let idx = months.firstIndex { calendar.isDate($0, equalTo: calendarMonth, toGranularity: .month) } ?? 0
        return HStack {
            chevronButton("chevron.left", enabled: idx > 0, label: L10n.Accessibility.previousPeriod) {
                navigate(months: months, to: idx - 1)
            }
            Spacer()
            Menu {
                ForEach(Array(months.enumerated()), id: \.offset) { _, month in
                    Button {
                        selectMonth(month)
                    } label: {
                        if calendar.isDate(month, equalTo: calendarMonth, toGranularity: .month) {
                            Label(monthName(month, withYear: true), systemImage: "checkmark")
                        } else {
                            Text(monthName(month, withYear: true))
                        }
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(monthName(calendarMonth, withYear: true))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            chevronButton("chevron.right", enabled: idx < months.count - 1, label: L10n.Accessibility.nextPeriod) {
                navigate(months: months, to: idx + 1)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private func chevronButton(
        _ systemName: String, enabled: Bool, label: String, action: @escaping () -> Void
    ) -> some View {
        Button {
            dsWithAnimation(reduceMotion) { action() }
        } label: {
            Image(systemName: systemName)
                .font(DS.Typography.headline)
                .foregroundStyle(enabled ? .secondary : .tertiary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func monthSwipeGesture(months: [Date]) -> some Gesture {
        DragGesture(minimumDistance: 60)
            .onEnded { value in
                guard abs(value.translation.width) > 60,
                    abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                let idx = months.firstIndex {
                    calendar.isDate($0, equalTo: calendarMonth, toGranularity: .month)
                } ?? 0
                navigate(months: months, to: value.translation.width > 0 ? idx - 1 : idx + 1)
            }
    }

    private func navigate(months: [Date], to index: Int) {
        guard months.indices.contains(index) else { return }
        dsWithAnimation(reduceMotion) {
            calendarMonth = months[index]
            selectedDay = nil
        }
    }

    private func selectMonth(_ month: Date) {
        dsWithAnimation(reduceMotion) {
            calendarMonth = month
            selectedDay = nil
        }
    }

    // MARK: - Week row + day cell (shared)

    private func weekRow(
        _ week: [Date], spending: DailySpendingCalculator.Result, inRange: @escaping (Date) -> Bool
    ) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(week, id: \.self) { date in
                dayCell(
                    date: date,
                    expense: spending.spendingByDay[date] ?? 0,
                    maxSpending: spending.maxSpending,
                    inRange: inRange(date)
                )
            }
        }
    }

    private func dayCell(date: Date, expense: Double, maxSpending: Double, inRange: Bool) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let dayNum = calendar.component(.day, from: date)
        let hasExpense = expense > 0 && inRange

        return Button {
            dsWithAnimation(reduceMotion) {
                selectedDay = isSelected ? nil : calendar.startOfDay(for: date)
            }
        } label: {
            VStack(spacing: DS.Spacing.xxs) {
                dayNumber(dayNum, isSelected: isSelected, isToday: isToday, inRange: inRange)

                if hasExpense {
                    DailySpendingBar(value: expense, maxValue: maxSpending)
                        .padding(.horizontal, 2)
                    Text(CompactAmountFormatter.string(expense))
                        // A11Y-DT: micro-monto en celda de 7 columnas; el a11yLabel da el monto completo.
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56, alignment: .top)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                    .fill(cellBackground(isSelected: isSelected, isToday: isToday))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                    .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 2)
            )
            .opacity(inRange ? 1 : 0.3)
        }
        .buttonStyle(.plain)
        .disabled(!inRange)
        .accessibilityLabel(a11yLabel(date: date, expense: hasExpense ? expense : nil))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func dayNumber(_ dayNum: Int, isSelected: Bool, isToday: Bool, inRange: Bool) -> some View {
        let text = Text("\(dayNum)").font(.caption2.weight(isToday || isSelected ? .bold : .medium))
        if isSelected {
            text.foregroundStyle(.white)
        } else if isToday {
            text.foregroundStyle(theme.accent)
        } else if inRange {
            text.foregroundStyle(.primary)
        } else {
            text.foregroundStyle(.secondary)
        }
    }

    private func cellBackground(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return theme.accent }
        if isToday { return theme.accent.opacity(0.08) }
        return .clear
    }

    // MARK: - Formatting

    private static let monthFormatter = makeMonthFormatter(template: "MMMM")
    private static let monthYearFormatter = makeMonthFormatter(template: "MMMMyyyy")

    private static func makeMonthFormatter(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private func monthName(_ date: Date, withYear: Bool) -> String {
        (withYear ? Self.monthYearFormatter : Self.monthFormatter).string(from: date).capitalized
    }

    private func a11yLabel(date: Date, expense: Double?) -> String {
        let dateStr = date.formatted(.dateTime.day().month(.wide))
        if let expense {
            return "\(dateStr), \(appPreferences.currency(expense, currencyCode: currencyCode))"
        }
        return "\(dateStr), \(L10n.Records.noRecordsThisDay)"
    }
}
