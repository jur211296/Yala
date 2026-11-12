//
//  UXAudit22Lote3LogicTests.swift
//  YalaTests
//
//  La lógica pura de lo que implementa el lote 3 de la auditoría UX 2.2 (el Panel): la cola de avisos (L3-8), los
//  presupuestos sin favoritos (L3-13), la parte que más sube la nota (L3-14), el calendario de «Personalizado» (L3-4)
//  y las fechas del eje que se pisaban (L3-17).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("UX 2.2 · lote 3 · lógica")
struct UXAudit22Lote3LogicTests {

    // MARK: - L3-1 · el mes en el rótulo

    @Test func monthName_isLowercaseWhereTheLanguageWritesItSo() {
        #expect(PanelHeroFigureLogic.lowercasesMonthNames(Locale(identifier: "es_PE")))
        #expect(PanelHeroFigureLogic.lowercasesMonthNames(Locale(identifier: "pt_BR")))
        #expect(!PanelHeroFigureLogic.lowercasesMonthNames(Locale(identifier: "de_DE")))
        #expect(!PanelHeroFigureLogic.lowercasesMonthNames(Locale(identifier: "en_US")))
    }

    // MARK: - L3-8 · avisos de uno en uno

    @Test func notices_keepTheirPriorityOrder() {
        var flags = PanelNoticeQueueLogic.Flags()
        flags.siriTip = true
        flags.setupChecklist = true
        flags.panelGuide = true
        #expect(PanelNoticeQueueLogic.visible(flags) == [.panelGuide, .setupChecklist, .siriTip])
    }

    @Test func notices_noneVisible_showsNothing() {
        #expect(PanelNoticeQueueLogic.visible(.init()).isEmpty)
        #expect(PanelNoticeQueueLogic.current(in: [], selected: .siriTip) == nil)
    }

    /// Cerrar el aviso que se está viendo pasa al primero que queda, sin índice fuera de rango.
    @Test func notices_closingTheShownOne_fallsBackToTheFirst() {
        #expect(PanelNoticeQueueLogic.current(in: [.setupChecklist, .siriTip], selected: .panelGuide) == .setupChecklist)
        #expect(PanelNoticeQueueLogic.current(in: [.setupChecklist, .siriTip], selected: .siriTip) == .siriTip)
    }

    @Test func notices_nextWrapsAround() {
        let visible: [PanelNotice] = [.panelGuide, .proOffer, .siriTip]
        #expect(PanelNoticeQueueLogic.next(after: .panelGuide, in: visible) == .proOffer)
        #expect(PanelNoticeQueueLogic.next(after: .siriTip, in: visible) == .panelGuide)
    }

    // MARK: - L3-13 · presupuestos sin favoritos

    @Test func budgetsFallback_takesTheTwoMostUsed() {
        let budgets = [("Comida", 40.0), ("Taxi", 95.0), ("Ocio", 70.0), ("Casa", 10.0)]
        let shown = PanelBudgetsFallbackLogic.mostUsed(budgets, percentage: \.1)
        #expect(shown.map(\.0) == ["Taxi", "Ocio"])
    }

    @Test func budgetsFallback_tieKeepsListOrder() {
        let budgets = [("A", 50.0), ("B", 50.0), ("C", 50.0)]
        #expect(PanelBudgetsFallbackLogic.mostUsed(budgets, percentage: \.1).map(\.0) == ["A", "B"])
    }

    // MARK: - L3-14 · qué mejorar

    @Test func weakestPart_isTheLowestScored() {
        let score = FinancialScore(total: 80, budget: 92, activity: 60, bills: 75)
        #expect(FinancialScoreCalculator.weakestPart(of: score) == .activity)
    }

    /// No es la nota más baja: es la que más suma al total si llega a 100 (80 en presupuestos con peso 40 suma 8; 75 en
    /// ritmo con peso 25, 6,25).
    @Test func weakestPart_isTheOneThatAddsMostToTheTotal() {
        let score = FinancialScore(total: 79, budget: 80, activity: 75, bills: 95)
        #expect(FinancialScoreCalculator.weakestPart(of: score) == .budget)
    }

    @Test func weakestPart_ignoresPartsWithoutData() {
        let score = FinancialScore(total: 85, budget: nil, activity: 95, bills: 70)
        #expect(FinancialScoreCalculator.weakestPart(of: score) == .bills)
    }

    @Test func weakestPart_nilWhenEverythingIsFine() {
        let score = FinancialScore(total: 95, budget: 90, activity: 99, bills: 93)
        #expect(FinancialScoreCalculator.weakestPart(of: score) == nil)
    }

    /// Los pesos que enseña la hoja suman 100 %: si cambian en el cálculo, cambian en pantalla.
    @Test func weights_addUpToOneHundredPercent() {
        let sum = FinancialScoreCalculator.weightBudget + FinancialScoreCalculator.weightRhythm
            + FinancialScoreCalculator.weightCommitments
        #expect(abs(sum - 1.0) < 0.0001)
    }

    // MARK: - L3-4 · «Personalizado» hasta hoy

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? .distantPast
    }

    /// Una cuenta nueva con un solo movimiento podía elegir un solo día. Ahora llega hasta hoy y veinte años atrás.
    @Test func customPeriod_newAccount_reachesTodayAndTheYearsBefore() {
        let now = date(2026, 10, 17)
        let bounds = CustomPeriodPickerSheet.pickerBounds(
            firstRecord: date(2026, 10, 1), lastRecord: date(2026, 10, 1), now: now, calendar: calendar
        )
        #expect(bounds.max == now)
        #expect(calendar.component(.year, from: bounds.min) == 2006)
    }

    /// Un movimiento con fecha futura sigue siendo elegible, y uno muy antiguo baja el suelo.
    @Test func customPeriod_keepsFutureAndVeryOldRecords() {
        let now = date(2026, 10, 17)
        let bounds = CustomPeriodPickerSheet.pickerBounds(
            firstRecord: date(1999, 1, 5), lastRecord: date(2026, 12, 24), now: now, calendar: calendar
        )
        #expect(bounds.min == date(1999, 1, 5))
        #expect(bounds.max == date(2026, 12, 24))
    }

    // MARK: - L3-17 · fechas del eje que se pisaban

    @Test func axis_dropsTheDateGluedToTheLast() {
        let dates = [date(2024, 10, 1), date(2025, 4, 1), date(2025, 10, 1), date(2026, 4, 1), date(2026, 5, 2)]
        let kept = SmartAxisHelper.droppingCrowdedNeighbors(dates)
        #expect(kept == [date(2024, 10, 1), date(2025, 4, 1), date(2025, 10, 1), date(2026, 5, 2)])
    }

    @Test func axis_keepsWellSpacedDates() {
        let dates = [date(2026, 10, 1), date(2026, 10, 8), date(2026, 10, 15), date(2026, 10, 22), date(2026, 10, 29)]
        #expect(SmartAxisHelper.droppingCrowdedNeighbors(dates) == dates)
    }

    @Test func axis_twoDatesStayAsTheyAre() {
        let dates = [date(2026, 10, 1), date(2026, 10, 2)]
        #expect(SmartAxisHelper.droppingCrowdedNeighbors(dates) == dates)
    }
}
