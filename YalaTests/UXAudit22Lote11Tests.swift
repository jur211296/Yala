//
//  UXAudit22Lote11Tests.swift
//  YalaTests
//
//  Implementación de la auditoría UX 2.2, lote 11 (Estadísticas): las flechas del período y su rango (L11-3), la frase
//  de con qué se compara (L11-4) y los enlaces del informe con su pestaña y su período (L11-2).
//

import Foundation
import Testing

@testable import Yala

// MARK: - L11-3 · Flechas del período

@MainActor
struct PeriodStepLogicTests {

    /// Calendario fijo (Lima, lunes primero) para que el test no dependa del runner.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima")!
        cal.firstWeekday = 2
        return cal
    }

    /// Sábado 18 de octubre de 2026, 10:00.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 10))!
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    private func sel(_ period: DetailPeriod, _ range: DateInterval? = nil) -> PeriodStepLogic.Selection {
        PeriodStepLogic.Selection(period: period, customRange: range)
    }

    private func step(
        _ s: PeriodStepLogic.Selection, _ d: PeriodStepLogic.Direction, hint: PeriodStepLogic.Unit? = nil
    ) -> PeriodStepLogic.Selection? {
        PeriodStepLogic.step(s, d, unitHint: hint, now: now, calendar: calendar)
    }

    @Test func thisMonth_previousIsLastMonth_andNextIsUnavailable() {
        #expect(step(sel(.thisMonth), .previous) == sel(.lastMonth))
        #expect(step(sel(.thisMonth), .next) == nil)
    }

    @Test func lastMonth_previousIsAugustAsAWholeMonth_andNextIsThisMonth() {
        let august = DateInterval(start: date(2026, 8, 1), end: date(2026, 8, 31, 23, 59, 59))
        #expect(step(sel(.lastMonth), .previous) == sel(.custom, august))
        #expect(step(sel(.lastMonth), .next) == sel(.thisMonth))
    }

    @Test func aWholeMonthRange_stepsByMonth_andComesBackToLastMonth() {
        let august = DateInterval(start: date(2026, 8, 1), end: date(2026, 8, 31, 23, 59, 59))
        let july = DateInterval(start: date(2026, 7, 1), end: date(2026, 7, 31, 23, 59, 59))
        #expect(step(sel(.custom, august), .previous) == sel(.custom, july))
        #expect(step(sel(.custom, august), .next) == sel(.lastMonth))
    }

    @Test func last7Days_previousIsTheSevenDaysBefore_andNextComesBack() {
        // «Últimos 7 días» el domingo 18-oct = 12–18 oct. El anterior: 5–11 oct, que además es una semana entera: sin
        // recordar que se llegó por días, la vuelta daría «Esta semana».
        let previous = DateInterval(start: date(2026, 10, 5), end: date(2026, 10, 11, 23, 59, 59))
        #expect(step(sel(.last7Days), .previous) == sel(.custom, previous))
        #expect(step(sel(.custom, previous), .next, hint: .days(7)) == sel(.last7Days))
        #expect(step(sel(.custom, previous), .next) == sel(.thisWeek))
        #expect(step(sel(.last7Days), .next) == nil)
    }

    @Test func theStepUnitIsRemembered_andForgottenOnAnyOtherChoice() {
        // `customDateRange` se guarda en `UserDefaults.standard`: se deja como estaba.
        let defaults = UserDefaults.standard
        let savedStart = defaults.object(forKey: "customPeriodStart")
        let savedEnd = defaults.object(forKey: "customPeriodEnd")
        defer {
            defaults.set(savedStart, forKey: "customPeriodStart")
            defaults.set(savedEnd, forKey: "customPeriodEnd")
        }
        let state = SessionState()
        state.choosePeriod(.custom, customRange: DateInterval(start: date(2026, 10, 5), end: date(2026, 10, 11, 23, 59, 59)), stepUnit: .days(7))
        #expect(state.periodStepUnit == .days(7))
        state.choosePeriod(.thisMonth)
        #expect(state.periodStepUnit == nil)
    }

    @Test func thisYear_previousIsLastYear_andAllTimeHasNoArrows() {
        #expect(step(sel(.thisYear), .previous) == sel(.lastYear))
        #expect(step(sel(.lastYear), .next) == sel(.thisYear))
        #expect(step(sel(.allTime), .previous) == nil)
        #expect(!PeriodStepLogic.isSteppable(.allTime))
    }

    @Test func thisWeek_previousIsLastWeek_andComesBack() {
        // Semana del lunes 12 al domingo 18.
        let lastWeek = DateInterval(start: date(2026, 10, 5), end: date(2026, 10, 11, 23, 59, 59))
        #expect(step(sel(.thisWeek), .previous) == sel(.custom, lastWeek))
        #expect(step(sel(.custom, lastWeek), .next) == sel(.thisWeek))
    }

    @Test func aFreeRange_stepsByItsOwnLength_andStopsAtToday() {
        // 1–10 oct (diez días): el anterior es 21–30 sept; el siguiente, 11–20 oct cortado hoy (18).
        let range = DateInterval(start: date(2026, 10, 1), end: date(2026, 10, 10, 23, 59, 59))
        #expect(step(sel(.custom, range), .previous)
            == sel(.custom, DateInterval(start: date(2026, 9, 21), end: date(2026, 9, 30, 23, 59, 59))))
        #expect(step(sel(.custom, range), .next)
            == sel(.custom, DateInterval(start: date(2026, 10, 11), end: date(2026, 10, 18, 23, 59, 59))))
    }

    @Test func rangeText_saysTheDaysCovered_withoutYearWhenItIsThisYear() {
        let locale = Locale(identifier: "es_PE")
        let thisMonth = PeriodStepLogic.rangeText(period: .thisMonth, customRange: nil, now: now, calendar: calendar, locale: locale)
        #expect(thisMonth?.contains("18") == true)
        #expect(thisMonth?.contains("1") == true)
        #expect(thisMonth?.contains("2026") == false)
        #expect(PeriodStepLogic.rangeText(period: .allTime, customRange: nil, now: now, calendar: calendar, locale: locale) == nil)
        let lastYear = PeriodStepLogic.rangeText(period: .lastYear, customRange: nil, now: now, calendar: calendar, locale: locale)
        #expect(lastYear?.contains("2025") == true)
    }

    @Test func customTitle_namesAWholeMonth() {
        let august = DateInterval(start: date(2026, 8, 1), end: date(2026, 8, 31, 23, 59, 59))
        let title = PeriodStepLogic.customTitle(august, now: now, calendar: calendar, locale: Locale(identifier: "es_PE"))
        #expect(title.lowercased().contains("agosto"))
        #expect(title.contains("2026"))
    }
}

// MARK: - L11-4 · Con qué se compara

@MainActor
struct ComparisonPhraseLogicTests {

    @Test func thisMonth_comparesWithTheSameDaysOfLastMonth() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)))
        let interval = try #require(ComparisonPhraseLogic.comparedInterval(
            period: .thisMonth, mode: .month, customRange: nil, now: now, calendar: calendar
        ))
        #expect(interval.start == calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let lastDay = PeriodStepLogic.displayEnd(of: interval, calendar: calendar)
        #expect(calendar.component(.day, from: lastDay) == 15)
        #expect(calendar.component(.month, from: lastDay) == 9)
    }

    /// Tendencias y Distribución cortan en el último día con datos: con el último gasto el 10-oct, el tramo es 1–10 sept.
    @Test func withALastDataDay_theTramoStopsAtItsEquivalent() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 12)))
        let lastData = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 9)))
        let interval = try #require(ComparisonPhraseLogic.comparedInterval(
            period: .thisMonth, mode: .month, customRange: nil, dataEnd: lastData, now: now, calendar: calendar
        ))
        let lastDay = PeriodStepLogic.displayEnd(of: interval, calendar: calendar)
        #expect(calendar.component(.day, from: lastDay) == 10)
        #expect(calendar.component(.month, from: lastDay) == 9)
    }

    @Test func allTime_hasNothingToCompareWith() {
        #expect(ComparisonPhraseLogic.comparedInterval(period: .allTime, mode: .month, customRange: nil) == nil)
        #expect(ComparisonPhraseLogic.phrase(period: .allTime, mode: .month, customRange: nil) == nil)
    }

    @Test func rangeText_inOneMonth_usesTheFullMonthName() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 16)))
        let text = ComparisonPhraseLogic.rangeText(
            DateInterval(start: start, end: end), now: now, calendar: calendar, locale: Locale(identifier: "es_PE")
        )
        #expect(text.contains("septiembre") || text.contains("setiembre"))
        #expect(text.contains("15"))
        #expect(!text.contains("2026"))
    }

    @Test func previousOption_saysWeekForAWeek_andMonthForAMonth() {
        #expect(ComparisonPhraseLogic.previousOptionTitle(for: .thisWeek) == L10n.UXL11.optionPreviousWeek)
        #expect(ComparisonPhraseLogic.previousOptionTitle(for: .thisMonth) == L10n.UXL11.optionPreviousMonth)
        #expect(ComparisonPhraseLogic.previousOptionTitle(for: .last7Days) == L10n.UXL11.optionPrevious7Days)
        #expect(ComparisonPhraseLogic.previousOptionTitle(for: .custom) == L10n.UXL11.optionPreviousPeriod)
    }

    /// «vs Sept 26» se leía como «el 26 de septiembre»: el año va entero.
    @Test func comparisonLabel_writesTheFullYear() throws {
        let calendar = Calendar.current
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let label = PreviousPeriodHelper.formatComparisonText(
            previousInterval: DateInterval(start: start, duration: 86_400), period: .thisMonth, mode: .month
        )
        #expect(label.hasSuffix("2026"))
    }
}

// MARK: - L11-2 · El informe abre su pestaña y su período

@MainActor
struct StatisticsDeepLinkTests {

    @Test func eachReportOpensWhatItTalksAbout() {
        #expect(StatisticsDeepLink.reportRequest(type: .dailyReport, dayPreference: .monday)
            == .init(tab: .records, period: .today))
        #expect(StatisticsDeepLink.reportRequest(type: .weeklyReport, dayPreference: .sunday)
            == .init(tab: .insights, period: .last7Days))
        #expect(StatisticsDeepLink.reportRequest(type: .monthlyReport, dayPreference: .firstDay)
            == .init(tab: .insights, period: .lastMonth))
        #expect(StatisticsDeepLink.reportRequest(type: .monthlyReport, dayPreference: .lastDay)
            == .init(tab: .insights, period: .thisMonth))
    }

    @Test func reportLink_roundTripsThroughTheNotificationParser() {
        let link = StatisticsDeepLink.reportDeepLink(type: .weeklyReport, dayPreference: .monday)
        #expect(link == "statistics/insights/last7Days")
        #expect(StatisticsDeepLink.request(fromDeepLink: link) == .init(tab: .insights, period: .last7Days))
        #expect(NotificationService.parseDestination(link) == .statistics)
    }

    @Test func plainStatistics_stillOpensStatistics_withoutARequest() {
        #expect(StatisticsDeepLink.request(fromDeepLink: "statistics") == nil)
        #expect(NotificationService.parseDestination("statistics") == .statistics)
    }

    /// `yala://statistics/trends` abría la última pestaña usada: solo se entendían `records` y `categories`.
    @Test func urlLinks_acceptTheFourTabs() {
        #expect(StatisticsDeepLink.request(fromComponents: ["/", "trends"]) == .init(tab: .trends, period: nil))
        #expect(StatisticsDeepLink.request(fromComponents: ["/", "insights"]) == .init(tab: .insights, period: nil))
        #expect(StatisticsDeepLink.request(fromComponents: ["/", "records"])?.tab == .records)
        #expect(StatisticsDeepLink.request(fromComponents: ["/", "categories"])?.tab == .categories)
        #expect(StatisticsDeepLink.request(fromComponents: ["/"]) == nil)
    }

    @Test func today_isARangeOfOneWholeDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Lima"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 9)))
        let selection = StatisticsDeepLink.Period.today.selection(now: now, calendar: calendar)
        #expect(selection.period == .custom)
        let range = try #require(selection.customRange)
        #expect(range.start == calendar.startOfDay(for: now))
        #expect(calendar.isDate(range.end, inSameDayAs: now))
    }

    @Test func target_isConsumedOnce_andExpires() {
        let target = StatisticsDeepLinkTarget()
        let now = Date()
        target.request(.init(tab: .trends, period: nil), now: now)
        #expect(target.consume(now: now) == .init(tab: .trends, period: nil))
        #expect(target.consume(now: now) == nil)

        target.request(.init(tab: .trends, period: nil), now: now)
        #expect(target.consume(now: now.addingTimeInterval(StatisticsDeepLinkTarget.maxAge + 1)) == nil)
    }
}

// MARK: - L11-2 · El período del aviso vale para esa visita

@MainActor
@Suite(.serialized)
struct VisitPeriodTests {

    /// `SessionState.customDateRange` se guarda en `UserDefaults.standard`: el test lo deja como estaba.
    private func keepingStoredRange(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let start = defaults.object(forKey: "customPeriodStart")
        let end = defaults.object(forKey: "customPeriodEnd")
        defer {
            if let start { defaults.set(start, forKey: "customPeriodStart") } else { defaults.removeObject(forKey: "customPeriodStart") }
            if let end { defaults.set(end, forKey: "customPeriodEnd") } else { defaults.removeObject(forKey: "customPeriodEnd") }
        }
        try body()
    }

    @Test func leavingRestoresWhatThePersonHad() {
        let state = SessionState()
        state.choosePeriod(.thisYear)

        state.applyVisitPeriod(.last7Days)
        #expect(state.selectedPeriod == .last7Days)

        state.endVisitPeriod()
        #expect(state.selectedPeriod == .thisYear)
        #expect(state.periodBeforeVisit == nil)
    }

    @Test func twoReportsInARow_keepTheOriginal() {
        let state = SessionState()
        state.choosePeriod(.thisYear)
        state.applyVisitPeriod(.last7Days)
        state.applyVisitPeriod(.lastMonth)
        state.endVisitPeriod()
        #expect(state.selectedPeriod == .thisYear)
    }

    /// Sin rango propio antes del aviso, el «hoy» del informe diario no se queda guardado.
    @Test func theDailyReportsRange_doesNotStayBehind() {
        keepingStoredRange {
            UserDefaults.standard.removeObject(forKey: "customPeriodStart")
            UserDefaults.standard.removeObject(forKey: "customPeriodEnd")
            let fresh = SessionState()
            fresh.choosePeriod(.thisYear)
            #expect(fresh.customDateRange == nil)

            let today = StatisticsDeepLink.Period.today.selection()
            fresh.applyVisitPeriod(today.period, customRange: today.customRange)
            fresh.endVisitPeriod()
            #expect(fresh.selectedPeriod == .thisYear)
            #expect(fresh.customDateRange == nil)
        }
    }

    @Test func choosingDuringTheVisit_makesThePeriodTheirs() {
        let state = SessionState()
        state.choosePeriod(.thisYear)
        state.applyVisitPeriod(.last7Days)
        state.choosePeriod(.lastMonth)
        state.endVisitPeriod()
        #expect(state.selectedPeriod == .lastMonth)
    }

    @Test func aCustomRangeComesBackWithItsDates() throws {
        try keepingStoredRange { try customRangeRoundTrip() }
    }

    private func customRangeRoundTrip() throws {
        let state = SessionState()
        let calendar = Calendar.current
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 1)))
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 23, minute: 59, second: 59)))
        let august = DateInterval(start: start, end: end)
        state.choosePeriod(.custom, customRange: august)

        let today = StatisticsDeepLink.Period.today.selection()
        state.applyVisitPeriod(today.period, customRange: today.customRange)
        #expect(state.customDateRange == today.customRange)

        state.endVisitPeriod()
        #expect(state.selectedPeriod == .custom)
        #expect(state.customDateRange == august)
    }

    @Test func leavingStatistics_endsTheVisit() {
        keepingStoredRange { leavingStatisticsRoundTrip() }
    }

    private func leavingStatisticsRoundTrip() {
        let state = SessionState.shared
        let saved = PeriodStepLogic.Selection(period: state.selectedPeriod, customRange: state.customDateRange)
        defer { state.choosePeriod(saved.period, customRange: saved.customRange) }

        state.choosePeriod(.thisYear)
        let navigation = SceneNavigation()
        navigation.selectedMainTab = .statistics
        state.applyVisitPeriod(.last7Days)

        navigation.selectedMainTab = .panel
        #expect(state.selectedPeriod == .thisYear)
    }
}
