//
//  RecordsCalendarLayoutTests.swift
//  YalaTests
//
//  Unit tests for RecordsCalendarLayout (continuous vs paged decision + week/month
//  generation). Pure logic, deterministic calendar (gregorian/UTC).
//

import Foundation
import Testing

@testable import Yala

struct RecordsCalendarLayoutTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func interval(_ start: (Int, Int, Int), _ end: (Int, Int, Int)) -> DateInterval {
        DateInterval(
            start: calendar.startOfDay(for: date(start.0, start.1, start.2)),
            end: calendar.startOfDay(for: date(end.0, end.1, end.2))
        )
    }

    // MARK: - Continuous (≤ 6 week rows)

    @Test func fullMonth_isContinuous() {
        let layout = RecordsCalendarLayout.resolve(
            range: interval((2026, 1, 1), (2026, 2, 1)), firstWeekday: 2, calendar: calendar)
        guard case .continuous(let weeks) = layout else { Issue.record("expected continuous"); return }
        #expect(weeks.count >= 5 && weeks.count <= 6)
    }

    @Test func sevenDays_isContinuous() {
        let layout = RecordsCalendarLayout.resolve(
            range: interval((2026, 1, 10), (2026, 1, 17)), firstWeekday: 2, calendar: calendar)
        guard case .continuous(let weeks) = layout else { Issue.record("expected continuous"); return }
        #expect(weeks.count <= 2)
    }

    @Test func crossingMonth_staysContinuous() {
        let layout = RecordsCalendarLayout.resolve(
            range: interval((2026, 1, 28), (2026, 2, 4)), firstWeekday: 2, calendar: calendar)
        guard case .continuous(let weeks) = layout else { Issue.record("expected continuous"); return }
        let months = Set(weeks.flatMap { $0 }.map { calendar.component(.month, from: $0) })
        #expect(months.count >= 2)  // enero y febrero en la misma tira
    }

    @Test func singleDay_isContinuousOneWeek() {
        let layout = RecordsCalendarLayout.resolve(
            range: interval((2026, 1, 15), (2026, 1, 16)), firstWeekday: 2, calendar: calendar)
        guard case .continuous(let weeks) = layout else { Issue.record("expected continuous"); return }
        #expect(weeks.count == 1)
        #expect(weeks[0].contains(calendar.startOfDay(for: date(2026, 1, 15))))
    }

    // MARK: - Paged (> 6 week rows)

    @Test func fullYear_isPaged() {
        let layout = RecordsCalendarLayout.resolve(
            range: interval((2026, 1, 1), (2027, 1, 1)), firstWeekday: 2, calendar: calendar)
        guard case .paged(let months) = layout else { Issue.record("expected paged"); return }
        #expect(months.count == 12)
    }

    @Test func multiMonth_pagedMonthsCoverRange() {
        let layout = RecordsCalendarLayout.resolve(
            range: interval((2026, 2, 1), (2026, 5, 1)), firstWeekday: 2, calendar: calendar)
        guard case .paged(let months) = layout else { Issue.record("expected paged"); return }
        #expect(months.count == 3)
        #expect(calendar.component(.month, from: months[0]) == 2)
        #expect(calendar.component(.month, from: months[2]) == 4)
    }

    // MARK: - firstWeekday alignment

    @Test func firstWeekday_monday_alignsToMonday() {
        let layout = RecordsCalendarLayout.resolve(
            range: interval((2026, 1, 15), (2026, 1, 16)), firstWeekday: 2, calendar: calendar)
        guard case .continuous(let weeks) = layout, let first = weeks.first?.first else {
            Issue.record("expected continuous"); return
        }
        #expect(calendar.component(.weekday, from: first) == 2)  // 2 = lunes (weekday absoluto)
    }

    @Test func firstWeekday_sunday_alignsToSunday() {
        let layout = RecordsCalendarLayout.resolve(
            range: interval((2026, 1, 15), (2026, 1, 16)), firstWeekday: 1, calendar: calendar)
        guard case .continuous(let weeks) = layout, let first = weeks.first?.first else {
            Issue.record("expected continuous"); return
        }
        #expect(calendar.component(.weekday, from: first) == 1)  // 1 = domingo
    }
}
