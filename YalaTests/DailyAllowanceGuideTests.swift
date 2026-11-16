//
//  DailyAllowanceGuideTests.swift
//  YalaTests
//
//  El cupo del día como guía neutra (decisión 23 de la revisión 2.3, Jürgen 2026-11-09): «Quedan 5 días y S/ 400: unos
//  S/ 80 al día. Hoy llevas S/ 120, S/ 40 más que eso». La fórmula no cambia (la fijan `DailyAllowanceLogicTests`);
//  aquí, las cifras de la frase, qué frase sale en cada caso y que la línea ya no avisa en rosa.
//

import Foundation
import Testing

@testable import Yala

struct DailyAllowanceGuideTests {

    // MARK: - Las cifras

    /// El ejemplo de la decisión: 5 días y S/ 400 al empezar el día, S/ 120 hoy.
    @Test func decisionExample() throws {
        // Límite 1.000; antes de hoy se gastaron 600 (quedaban 400); hoy, 120.
        let guide = try #require(DailyAllowanceLogic.guide(limit: 1_000, spent: 720, spentToday: 120, daysRemaining: 5))
        #expect(guide.daysRemaining == 5)
        #expect(guide.leftAtStartOfDay == 400)
        #expect(guide.perDay == 80)
        #expect(guide.spentToday == 120)
        #expect(guide.overPerDay == 40)
    }

    /// El caso de la revisión: al 90 % y con el cupo de hoy superado, el mes NO se pasó y la línea sigue saliendo.
    @Test func at90Percent_overTodayButNotOverTheMonth() throws {
        let guide = try #require(DailyAllowanceLogic.guide(limit: 1_000, spent: 900, spentToday: 100, daysRemaining: 20))
        #expect(guide.leftAtStartOfDay == 200)
        #expect(guide.perDay == 10)
        #expect(guide.overPerDay == 90)
    }

    @Test func nothingSpentToday_hasNoTodayPart() throws {
        let guide = try #require(DailyAllowanceLogic.guide(limit: 3_000, spent: 1_000, spentToday: 0, daysRemaining: 20))
        #expect(guide.perDay == 100)
        #expect(guide.spentToday == 0)
        #expect(guide.overPerDay == 0)
    }

    @Test func underTheAllowance_isNotOver() throws {
        let guide = try #require(DailyAllowanceLogic.guide(limit: 3_000, spent: 1_030, spentToday: 30, daysRemaining: 20))
        #expect(guide.spentToday == 30)
        #expect(guide.overPerDay == 0)
        // Justo el cupo, con medio céntimo de holgura, tampoco.
        let exact = try #require(DailyAllowanceLogic.guide(limit: 3_000, spent: 1_100.004, spentToday: 100.004, daysRemaining: 20))
        #expect(exact.overPerDay == 0)
    }

    /// Con el mes agotado la línea no sale: ni al 100 % justo ni pasado.
    @Test func exhaustedMonth_hasNoGuide() {
        #expect(DailyAllowanceLogic.guide(limit: 1_000, spent: 1_000, spentToday: 0, daysRemaining: 10) == nil)
        #expect(DailyAllowanceLogic.guide(limit: 1_000, spent: 1_180, spentToday: 0, daysRemaining: 10) == nil)
        #expect(DailyAllowanceLogic.guide(limit: 100, spent: 100, spentToday: 20, daysRemaining: 5) == nil)
        #expect(DailyAllowanceLogic.guide(limit: 1_000, spent: 0, spentToday: 0, daysRemaining: -1) == nil)
    }

    /// `state` y `guide` son la misma cuenta.
    @Test func stateAndGuide_agree() {
        for today in stride(from: 0.0, through: 200.0, by: 2.5) {
            let state = DailyAllowanceLogic.state(limit: 1_000, spent: 800 + today, spentToday: today, daysRemaining: 10)
            let guide = DailyAllowanceLogic.guide(limit: 1_000, spent: 800 + today, spentToday: today, daysRemaining: 10)
            switch state {
            case .overToday(let over): #expect(guide?.overPerDay == over, "hoy \(today)")
            case .available(let left): #expect(guide?.overPerDay == 0 && abs((guide?.perDay ?? 0) - today - left) < 0.0001)
            case nil: #expect(guide == nil)
            }
        }
    }

    // MARK: - Qué frase sale (marcadores en vez de importes: vale en cualquier idioma)

    private func text(days: Int, today: String?, over: String?) -> String {
        L10n.DailyAllowance.guide(daysRemaining: days, leftAtStartOfDay: "‹LEFT›", perDay: "‹DAY›", spentToday: today, overPerDay: over)
    }

    @Test func withoutSpendingToday_saysTheDaysTheAmountAndThePerDay() {
        let line = text(days: 5, today: nil, over: nil)
        #expect(line.contains("‹LEFT›"))
        #expect(line.contains("‹DAY›"))
        #expect(line.contains(L10n.UXL9.shortDays(5)))
        #expect(!line.contains("‹TODAY›"))
    }

    @Test func withSpendingToday_addsWhatYouSpentAndHowMuchMore() {
        let over = text(days: 5, today: "‹TODAY›", over: "‹OVER›")
        #expect(over.contains("‹LEFT›") && over.contains("‹DAY›") && over.contains("‹TODAY›") && over.contains("‹OVER›"))
        let under = text(days: 5, today: "‹TODAY›", over: nil)
        #expect(under.contains("‹TODAY›"))
        #expect(!under.contains("‹OVER›"))
        // «Al empezar el día» con gasto hoy, y la frase de siempre sin él: son dos plantillas distintas.
        #expect(text(days: 5, today: "‹TODAY›", over: nil).hasPrefix(text(days: 5, today: nil, over: nil)) == false)
    }

    /// El último día el cupo es todo lo que queda: no se repite la cifra ni se cuentan «1 día».
    @Test func lastDay_doesNotRepeatThePerDay() {
        let line = text(days: 1, today: nil, over: nil)
        #expect(line.contains("‹LEFT›"))
        #expect(!line.contains("‹DAY›"))
        #expect(text(days: 1, today: "‹TODAY›", over: nil).contains("‹TODAY›"))
    }

    // MARK: - Tono neutro: ni rosa ni icono de alerta (source-scan)

    @Test func line_hasNoPinkAndNoAlertIcon() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let code = try String(
            contentsOf: root.appendingPathComponent("Yala/App/Views/Planning/Components/DailyAllowanceLine.swift"),
            encoding: .utf8
        )
        .components(separatedBy: "\n")
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n")
        #expect(!code.contains("overBudgetText"))
        #expect(!code.contains("hotPink"))
        #expect(!code.contains("exclamationmark"))
        #expect(code.contains("DailyAllowanceLogic.guide("))
    }
}
