//
//  PanelProgresivoTests.swift
//  YalaTests
//
//  Panel progresivo durante Primeros pasos (acuerdo de Jürgen del 19-nov-2026, «Ingresos y gastos» y «Solo gastos»):
//  al entrar solo el mazo; tras la primera cuenta, esa cuenta en «Tus finanzas»; tras aprender a registrar, «Últimos
//  registros»; Presupuestos y Pagos planificados solo si dijo que sí en su paso. Sin guías ni coach tips.
//

import Foundation
import Testing

@testable import Yala

// MARK: - La puerta

@MainActor
@Suite("Panel progresivo · lo que el Panel deja ver con el mazo a medias")
struct PanelProgresivoGateTests {

    typealias Gate = PrimerosPasosPanelGate

    /// Lo que la persona dejó de fábrica: salud, tendencias, planificación y «Últimos registros» a la vista.
    private let factory: Set<PanelSectionKind> = [.distribucion, .tools]
    private let all = Set(PanelSectionKind.allCases)

    private func gate(expensesOnly: Bool = false, account: Bool = false, record: Bool = false,
                      planning: Bool = false, inProgress: Bool = true) -> Gate {
        Gate.make(deckInProgress: inProgress, expensesOnly: expensesOnly, accountStepResolved: account,
                  recordStepResolved: record, planningShown: planning)
    }

    /// Al entrar por primera vez: solo el mazo. Ni «Tus finanzas» ni ningún widget, en los dos modos.
    @Test func arrival_hidesEverySection_inBothModes() {
        #expect(gate().hiddenSections(factory) == all)
        #expect(gate(expensesOnly: true, account: true).hiddenSections(factory) == all)
    }

    /// «Ingresos y gastos», tras el paso 1: la cuenta, nada más.
    @Test func afterTheFirstAccount_onlyTheAccountShows() {
        let hidden = gate(account: true).hiddenSections(factory)
        #expect(all.subtracting(hidden) == [.accounts])
    }

    /// «Solo gastos»: Yala crea la cuenta y el paso 1 sale hecho solo; la cuenta aparece con el primer paso que hace la
    /// persona, aprender a registrar.
    @Test func expensesOnly_theAccountWaitsForTheRecordStep() {
        #expect(all.subtracting(gate(expensesOnly: true, account: true).hiddenSections(factory)).isEmpty)
        let afterRecord = gate(expensesOnly: true, account: true, record: true).hiddenSections(factory)
        #expect(all.subtracting(afterRecord) == [.accounts, .latestRecords])
    }

    /// Tras aprender a registrar: «Últimos registros» y nada más.
    @Test func afterTheRecordStep_latestRecordsJoins() {
        let hidden = gate(account: true, record: true).hiddenSections(factory)
        #expect(all.subtracting(hidden) == [.accounts, .latestRecords])
    }

    /// Planificación solo si dijo que sí en el paso 3 o en el 4.
    @Test func planning_onlyAfterAYes() {
        let withoutYes = gate(account: true, record: true).hiddenSections(factory)
        #expect(withoutYes.contains(.planificacion))
        let withYes = gate(account: true, record: true, planning: true).hiddenSections(factory)
        #expect(all.subtracting(withYes) == [.accounts, .latestRecords, .planificacion])
    }

    /// Lo que la persona ocultó a mano sigue oculto aunque el mazo lo abra.
    @Test func whatThePersonHid_staysHidden() {
        let hidden = gate(account: true, record: true).hiddenSections([.latestRecords])
        #expect(hidden.contains(.latestRecords))
    }

    /// Sin mazo a medias (terminado, de 2.2, o callado bajo `-uitest`): el Panel de siempre.
    @Test func inactive_changesNothing() {
        let off = gate(inProgress: false)
        #expect(off == .inactive)
        #expect(off.hiddenSections(factory) == factory)
        #expect(off.showsFilterBar)
        #expect(off.showsExchangeResultCard)
        #expect(off.allowsCoachMarks)
        #expect(PanelNotice.allCases.allSatisfy { off.allows($0) })
    }

    /// Con el mazo a medias: sin barra de filtros, sin la tarjeta de tipo de cambio y sin coach marks.
    @Test func active_hidesTheFilterBarTheFXCardAndCoachMarks() {
        let on = gate(account: true, record: true)
        #expect(!on.showsFilterBar)
        #expect(!on.showsExchangeResultCard)
        #expect(!on.allowsCoachMarks)
    }

    /// Avisos: siguen los que hablan de los datos (la nube) y la versión nueva; la guía, la oferta Pro, el empujón de
    /// grupos y Siri esperan.
    @Test func notices_keepOnlyDataAndUpdate() {
        var flags = PanelNoticeQueueLogic.Flags()
        flags.cloudAdoptOffer = true
        flags.panelGuide = true
        flags.updateAvailable = true
        flags.proOffer = true
        flags.nudge = true
        flags.siriTip = true
        let visible = PanelNoticeQueueLogic.visible(gate().filtering(flags))
        #expect(visible == [.cloudAdoptOffer, .updateAvailable])
        #expect(PanelNoticeQueueLogic.visible(Gate.inactive.filtering(flags)) == PanelNotice.allCases)
    }
}

// MARK: - «¿Lo ponemos en tu Panel?» con el Panel progresivo

@MainActor
@Suite("Panel progresivo · el «Sí» de los pasos 3 y 4")
struct PanelProgresivoPlanningYesTests {

    /// Con la lista de fábrica (Planificación a la vista y sus dos widgets), el primer «Sí» con el mazo a medias abre
    /// solo ESE widget. Sin la regla, el Panel enseñaba también el del otro paso, que no se había hecho.
    @Test func firstYesWhileProgressive_opensOnlyThatWidget() {
        let change = PrimerosPasosPanelWidgetLogic.show(
            .budgets, sectionsHidden: ["distribucion", "tools"], planningHidden: [],
            firstYesWhileProgressive: true)
        #expect(change.planningHidden == [WidgetType.scheduledPayments.rawValue])
        #expect(!change.sectionsHidden.contains(PanelSectionKind.planificacion.rawValue))
    }

    /// Control: sin el mazo, el «Sí» con la sección a la vista solo quita ese widget de los ocultos (lo de siempre).
    @Test func yesWithoutTheDeck_keepsTheOldRule() {
        let change = PrimerosPasosPanelWidgetLogic.show(
            .budgets, sectionsHidden: ["distribucion", "tools"], planningHidden: [])
        #expect(change.planningHidden.isEmpty)
    }

    /// El segundo «Sí» (la sección ya abierta por el primero) suma su widget al que ya estaba.
    @Test func secondYes_addsItsWidget() {
        let change = PrimerosPasosPanelWidgetLogic.show(
            .scheduledPayments, sectionsHidden: ["distribucion", "tools"],
            planningHidden: [WidgetType.scheduledPayments.rawValue])
        #expect(change.planningHidden.isEmpty)
    }

    /// Terminar el paso 2 después de un «Sí» (pasos abiertos desde «Ver los 7 pasos») no deshace ese sí.
    @Test func finishingTheRecordStep_keepsPlanningAfterAYes() {
        let hidden = PrimerosPasosPanelPresentations.sectionsHiddenAfterLearningToRecord(
            current: ["distribucion", "tools"], keepsPlanning: true)
        #expect(!hidden.contains("planificacion"))
        let control = PrimerosPasosPanelPresentations.sectionsHiddenAfterLearningToRecord(
            current: ["distribucion", "tools"])
        #expect(control.contains("planificacion"))
    }
}

// MARK: - Guías y consejos

@Suite("Panel progresivo · sin guías de más con el mazo a medias")
struct PanelProgresivoGuidesTests {

    /// La guía de «días después» (Y23-15) no sale con Primeros pasos a medias, aunque se cumpla todo lo demás.
    @Test func laterChartsGuide_waitsForTheDeck() {
        var inputs = LaterChartsGuideLogic.Inputs(
            isFreshInstall: true, alreadyShown: false, statisticsInBar: false, hasMoreTab: true,
            guideOnScreen: false, stepSixResolved: false, silencedForUITest: false)
        #expect(LaterChartsGuideLogic.mayCheck(inputs))
        inputs.primerosPasosShown = true
        #expect(!LaterChartsGuideLogic.mayCheck(inputs))
    }
}

// MARK: - Cableado

@Suite("Panel progresivo · cableado (source-scan)")
struct PanelProgresivoWiringTests {

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// El código sin comentarios, para que documentar no cuente como usar.
    private static func code(_ relativePath: String) throws -> String {
        try source(relativePath).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
            .joined(separator: "\n")
    }

    /// Las dos lecturas de las secciones ocultas del Panel (al aparecer y al cambiar la lista) pasan por la puerta, y
    /// la puerta tiene quien la vuelva a aplicar al avanzar el mazo.
    @Test func panel_hiddenSectionsGoThroughTheGate() throws {
        let panel = try Self.code("Yala/App/Views/Panel/PanelView.swift")
        #expect(panel.components(separatedBy: "panelGate.hiddenSections(").count - 1 == 2)
        #expect(panel.contains("PrimerosPasosPanelGateObserver(gate: panelGate"))
        #expect(panel.contains("return panelGate.filtering(flags)"))
        #expect(panel.contains("showsFilterBar: panelGate.showsFilterBar"))
        #expect(panel.contains("if panelGate.showsExchangeResultCard {"))
        #expect(panel.contains("guard panelGate.allowsCoachMarks else { return false }"))
        // El segundo guard era el de la fase del Panel del tour Pro, retirado el 20-nov-2026 (opción B de Jürgen).
        #expect(!panel.contains("ProTourManager"))
        let observer = try Self.code("Yala/App/Views/Panel/PrimerosPasosPanelPresentations.swift")
        #expect(observer.contains("newGate.hiddenSections(PanelView.parseHiddenSections("))
        #expect(observer.contains("PrimerosPasosTipGate.update(primerosPasosShown: gate.isActive)"))
    }

    /// La barra de filtros solo se pinta si la puerta la deja.
    @Test func filterBar_obeysTheGate() throws {
        let section = try Self.code("Yala/App/Views/Panel/PanelFilterAndWidgetsSection.swift")
        #expect(section.contains("if showsFilterBar {\nPanelFilterControlBar("))
    }

    /// Las guías de cada pantalla (las que llevan X) se callan con el mazo a medias.
    @Test func contextualGuides_waitForTheDeck() throws {
        let banner = try Self.code("Yala/App/Views/Shared/ContextualGuideBanner.swift")
        #expect(banner.contains("!isDismissible || !SetupChecklistManager.shared.isPrimerosPasosShown {"))
    }

    /// Cada consejo de TipKit lleva la regla del mazo.
    @Test func everyTipKitTip_carriesTheDeckRule() throws {
        let tips = try Self.code("Yala/App/Tips/YalaTips.swift")
        let tipCount = tips.components(separatedBy: ": Tip {").count - 1
        let ruleCount = tips.components(separatedBy: "#Rule(PrimerosPasosTipGate.$primerosPasosShown) { $0 == false }")
            .count - 1
        #expect(tipCount == 3)
        #expect(ruleCount == tipCount)
    }

    /// La guía de «días después» recibe el estado del mazo.
    @Test func laterChartsGuide_readsTheDeck() throws {
        let overlay = try Self.code("Yala/App/Tips/PlaceGuideOverlay.swift")
        #expect(overlay.contains("primerosPasosShown: SetupChecklistManager.shared.isPrimerosPasosShown)"))
    }
}
