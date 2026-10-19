//
//  UXAudit22Lote11DecididasTests.swift
//  YalaTests
//
//  Lo que no es pantalla de las decisiones de Jürgen sobre el lote 11 (2026-10-18): el informe por notificación
//  (L11-12) y el «Resumen con IA» guardado por huella (L11-7).
//

import Foundation
import Testing
import UserNotifications

@testable import Yala

// MARK: - L11-12 · Lo que llegará y de qué días habla

@MainActor
struct ReportUpcomingTests {

    /// Calendario fijo (Lima, lunes primero) para que las fechas no dependan de la máquina.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima")!
        cal.firstWeekday = 2
        return cal
    }()

    /// 2026-10-12 es lunes.
    private func date(_ day: Int, month: Int = 10, hour: Int = 12, minute: Int = 0, second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    // MARK: La semana cerrada

    /// El ejemplo de la decisión: el lunes a las 9:00, del lunes 6 al domingo 12 (aquí, del 12 al 18).
    @Test func mondayReport_countsTheWeekThatJustClosed() {
        let week = ReportNotificationService.closedWeek(before: date(19, hour: 9), calendar: calendar)
        #expect(week.start == date(12, hour: 0))
        #expect(week.end == date(18, hour: 23, minute: 59, second: 59))
    }

    /// El domingo cuenta todavía la semana anterior: la de esta semana no ha cerrado.
    @Test func closedWeek_onASunday_isTheWeekBefore() {
        let week = ReportNotificationService.closedWeek(before: date(18, hour: 21), calendar: calendar)
        #expect(week.start == date(5, hour: 0))
        #expect(week.end == date(11, hour: 23, minute: 59, second: 59))
    }

    /// Hasta el 2026-10-18 el del lunes contaba hoy y los seis días anteriores: de martes a lunes por la mañana.
    @Test func mondayInterval_isTheClosedWeek_notTheLastSevenDays() {
        let config = ReportConfig(dataType: .expenses, dayPreference: .monday)
        let interval = ReportNotificationService.getIntervalForReportType(
            config, type: .weeklyReport, now: date(19, hour: 9), calendar: calendar
        )
        #expect(interval.start == date(12, hour: 0))
        #expect(interval.end == date(18, hour: 23, minute: 59, second: 59))
    }

    /// El del domingo no cambia: hoy y los seis días anteriores.
    @Test func sundayInterval_isUnchanged() {
        let config = ReportConfig(dataType: .expenses, dayPreference: .sunday)
        let now = date(18, hour: 21)
        let interval = ReportNotificationService.getIntervalForReportType(
            config, type: .weeklyReport, now: now, calendar: calendar
        )
        #expect(interval.start == date(12, hour: 0))
        #expect(interval.end == now)
    }

    // MARK: El próximo envío

    @Test func nextSend_weeklyMonday_fromAWednesday_isNextMonday() {
        let next = ReportUpcomingLogic.nextSendDate(
            type: .weeklyReport, dayPreference: .monday, hour: 9, minute: 0, now: date(14, hour: 15), calendar: calendar
        )
        #expect(next == date(19, hour: 9))
    }

    /// El mismo lunes antes de la hora sale hoy; un minuto después, el lunes siguiente.
    @Test func nextSend_onTheDay_dependsOnTheHour() {
        let before = ReportUpcomingLogic.nextSendDate(
            type: .weeklyReport, dayPreference: .monday, hour: 9, minute: 0, now: date(12, hour: 8, minute: 59),
            calendar: calendar
        )
        #expect(before == date(12, hour: 9))
        let after = ReportUpcomingLogic.nextSendDate(
            type: .weeklyReport, dayPreference: .monday, hour: 9, minute: 0, now: date(12, hour: 9, minute: 1),
            calendar: calendar
        )
        #expect(after == date(19, hour: 9))
    }

    @Test func nextSend_monthlyFirstDay_isTheFirstOfNextMonth_andCountsThisMonth() throws {
        let upcoming = try #require(ReportUpcomingLogic.upcoming(
            type: .monthlyReport, config: ReportConfig(dataType: .expenses, dayPreference: .firstDay),
            hour: 9, minute: 0, now: date(18), calendar: calendar
        ))
        #expect(upcoming.sendDate == date(1, month: 11, hour: 9))
        #expect(upcoming.interval.start == date(1, hour: 0))
        #expect(upcoming.interval.end == date(31, hour: 23, minute: 59, second: 59))
    }

    @Test func nextSend_monthlyLastDay_isTheLastDayOfThisMonth() {
        let next = ReportUpcomingLogic.nextSendDate(
            type: .monthlyReport, dayPreference: .lastDay, hour: 20, minute: 0, now: date(18), calendar: calendar
        )
        #expect(next == date(31, hour: 20))
    }

    @Test func upcoming_isNil_forTheDailyReport() {
        let upcoming = ReportUpcomingLogic.upcoming(
            type: .dailyReport, config: .default, hour: 21, minute: 0, now: date(18), calendar: calendar
        )
        #expect(upcoming == nil)
    }

    // MARK: El texto del período cerrado

    private let data = ReportData(
        balance: 1200, totalExpense: 350, totalIncome: 0, topCategory: "Hogar",
        hasExpenseActivity: true, hasIncomeActivity: false
    )

    /// El mensual del día 1 nombra el mes cerrado; el del último día sigue con su texto de siempre.
    @Test func monthlyFirstDay_namesTheClosedMonth() {
        let firstDay = ReportConfig(dataType: .balance, dayPreference: .firstDay)
        let body = ReportNotificationService.formatReportBody(
            firstDay, reportType: .monthlyReport, data: data, now: date(1, month: 11, hour: 9), calendar: calendar
        )
        let currency = CurrencyDefaults.currentPreferred
        let amount = YalaFormatterStatic.currency(value: 1200, currencyCode: currency, forceFullPrecision: true)
        let october = L10n.UXL11D.monthName(of: date(1, hour: 0))
        #expect(body == L10n.UXL11D.closedReport(.balance, .month(october), value: amount))

        let lastDay = ReportConfig(dataType: .balance, dayPreference: .lastDay)
        let thisMonth = ReportNotificationService.formatReportBody(
            lastDay, reportType: .monthlyReport, data: data, now: date(31, hour: 20), calendar: calendar
        )
        #expect(thisMonth == L10n.Notifications.reportData(.balance, period: "monthly", value: amount))
    }

    @Test func weeklyMonday_saysLastWeek_andSundayKeepsItsText() {
        let currency = CurrencyDefaults.currentPreferred
        let amount = YalaFormatterStatic.currency(value: 350, currencyCode: currency, forceFullPrecision: true)
        let monday = ReportNotificationService.formatReportBody(
            ReportConfig(dataType: .expenses, dayPreference: .monday), reportType: .weeklyReport, data: data,
            now: date(19, hour: 9), calendar: calendar
        )
        #expect(monday == L10n.UXL11D.closedReport(.expenses, .lastWeek, value: amount))
        let sunday = ReportNotificationService.formatReportBody(
            ReportConfig(dataType: .expenses, dayPreference: .sunday), reportType: .weeklyReport, data: data,
            now: date(18, hour: 21), calendar: calendar
        )
        #expect(sunday == L10n.Notifications.reportData(.expenses, period: "weekly", value: amount))
    }

    /// Sin gastos, el período cerrado también se nombra.
    @Test func closedMonth_withoutExpenses_namesTheMonth() {
        let quiet = ReportData(
            balance: 0, totalExpense: 0, totalIncome: 0, topCategory: nil,
            hasExpenseActivity: false, hasIncomeActivity: false
        )
        let body = ReportNotificationService.formatReportBody(
            ReportConfig(dataType: .expenses, dayPreference: .firstDay), reportType: .monthlyReport, data: quiet,
            now: date(1, month: 11, hour: 9), calendar: calendar
        )
        #expect(body == L10n.UXL11D.closedReportNoExpenses(.month(L10n.UXL11D.monthName(of: date(1, hour: 0)))))
    }

    // MARK: «Probar» y el permiso

    @Test func testButton_asksForPermission_orExplainsWhenDenied() {
        #expect(ReportUpcomingLogic.testStep(for: .authorized) == .send)
        #expect(ReportUpcomingLogic.testStep(for: .provisional) == .send)
        #expect(ReportUpcomingLogic.testStep(for: .notDetermined) == .askThenSend)
        #expect(ReportUpcomingLogic.testStep(for: .denied) == .explainAndOfferSettings)
    }
}

// MARK: - L11-7 · El «Resumen con IA» guardado por huella

@MainActor
struct InsightsAIResultStoreTests {

    private func store() -> InsightsAIResultStore {
        InsightsAIResultStore(
            defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!, storageKey: "insightsAI.savedResults"
        )
    }

    private func fingerprint(_ data: [String: Any], period: String = "thisMonth") -> String? {
        InsightsAIResultStore.fingerprint(
            aggregatedData: data, period: period, customRange: nil, tone: .normal, focus: .balanced,
            currencyFormat: "code"
        )
    }

    private let response = LLMInsightResponse(
        heroText: "Tu mes va bien.",
        cards: [LLMInsightCard(icon: "sparkles", text: "Gastaste menos en Hogar.", sentiment: "positive", tip: nil)],
        funFact: nil
    )

    /// La huella no depende del orden de las claves ni del lanzamiento: `hashValue` cambia en cada arranque, y por eso
    /// la caché en memoria no servía para «reusar el último resultado».
    @Test func fingerprint_isStable_forTheSameData() {
        let a = fingerprint(["total_expense": 100, "locale": "es", "top_categories": [["name": "Hogar", "amount": 40]]])
        let b = fingerprint(["top_categories": [["amount": 40, "name": "Hogar"]], "locale": "es", "total_expense": 100])
        #expect(a != nil)
        #expect(a == b)
    }

    /// Un número que se mueve, otro período o otro idioma piden un resumen nuevo.
    @Test func fingerprint_changes_whenWhatIsSentChanges() {
        let base = fingerprint(["total_expense": 100, "locale": "es"])
        #expect(base != fingerprint(["total_expense": 101, "locale": "es"]))
        #expect(base != fingerprint(["total_expense": 100, "locale": "en"]))
        #expect(base != fingerprint(["total_expense": 100, "locale": "es"], period: "lastMonth"))
        let otherTone = InsightsAIResultStore.fingerprint(
            aggregatedData: ["total_expense": 100, "locale": "es"], period: "thisMonth", customRange: nil,
            tone: .sarcastic, focus: .balanced, currencyFormat: "code"
        )
        #expect(base != otherTone)
    }

    @Test func savedResponse_comesBack_forItsFingerprintOnly() throws {
        let store = store()
        let key = try #require(fingerprint(["total_expense": 100]))
        let other = try #require(fingerprint(["total_expense": 200]))
        store.save(response, for: key)
        #expect(store.response(for: key) == response)
        #expect(store.response(for: other) == nil)
    }

    /// Se guardan los más recientes, no todos.
    @Test func store_keepsTheMostRecent_upToItsCapacity() throws {
        let store = store()
        var keys: [String] = []
        for i in 0...InsightsAIResultStore.capacity {
            let key = try #require(fingerprint(["total_expense": i]))
            keys.append(key)
            store.save(response, for: key)
        }
        #expect(store.response(for: keys[0]) == nil)
        #expect(store.response(for: keys[keys.count - 1]) == response)
        #expect(store.response(for: keys[1]) == response)
    }
}
