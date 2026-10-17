//
//  UXAudit22Lote5LogicTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 5 (primeros días, guías y tips): la lógica pura de las decisiones de Jürgen.
//  El orden y el «saltado» de «Primeros pasos» (L5-1, L5-2) viven en `SetupChecklistManagerTests`.
//

import Foundation
import Testing
import UserNotifications

@testable import Yala

@MainActor
@Suite("UX 2.2 · lote 5")
struct UXAudit22Lote5LogicTests {

    // MARK: - L5-3 · el último paso se llama por lo que abre

    @Test(arguments: [
        (pro: false, eligible: true, title: SetupStepID.DiscoverTitle.freeTrial),
        (pro: false, eligible: false, title: .knowPro),
        (pro: true, eligible: true, title: .alreadyPro),
        (pro: true, eligible: false, title: .alreadyPro),
    ])
    func discoverStepTitle(_ c: (pro: Bool, eligible: Bool, title: SetupStepID.DiscoverTitle)) {
        #expect(SetupStepID.discoverTitle(isProUser: c.pro, trialEligible: c.eligible) == c.title)
    }

    /// Quien ya usó la prueba no lee «gratis 30 días» (no la vuelve a tener).
    @Test func discoverStepTitle_withoutTrial_doesNotPromiseFree() {
        let key = "setup.step5.title.knowPro"
        let value = NSLocalizedString(key, comment: "")
        #expect(value != key)
        #expect(!value.contains("30"))
    }

    // MARK: - L5-13 · el anillo del hito

    @Test(arguments: [
        (milestone: 10, next: Int?.some(50), fraction: 0.2),
        (milestone: 50, next: Int?.some(100), fraction: 0.5),
        (milestone: 100, next: Int?.none, fraction: 1.0),
    ])
    func milestoneProgress(_ c: (milestone: Int, next: Int?, fraction: Double)) {
        let progress = MilestoneProgress(milestone: c.milestone)
        #expect(progress.nextMilestone == c.next)
        #expect(abs(Double(progress.fraction) - c.fraction) < 0.0001)
    }

    /// El título cuenta registros, no «gastos»: el hito cuenta también los ingresos.
    @Test func milestoneTitle_saysRecords() {
        let title = L10n.Milestone.title(10)
        #expect(title.contains("10"))
        #expect(!title.localizedCaseInsensitiveContains("gasto"))
        #expect(!title.localizedCaseInsensitiveContains("expense"))
    }

    // MARK: - L5-14 · el permiso de notificaciones, en contexto

    @Test(arguments: [
        // En contexto, la primera vez, sin esperar al tercer registro.
        (context: NotificationPrimerContext.scheduledPayment, seen: false, records: 0, moment: true),
        (context: .budgetAlert, seen: false, records: 0, moment: true),
        // El respaldo del tercer registro, con sus dos vecinos.
        (context: .records, seen: false, records: 2, moment: false),
        (context: .records, seen: false, records: 3, moment: true),
        // Un solo aviso para los tres momentos: el primero lo gasta.
        (context: .scheduledPayment, seen: true, records: 0, moment: false),
        (context: .budgetAlert, seen: true, records: 9, moment: false),
        (context: .records, seen: true, records: 9, moment: false),
    ])
    func primerMoment(_ c: (context: NotificationPrimerContext, seen: Bool, records: Int, moment: Bool)) {
        #expect(NotificationPrimerMomentLogic.isMoment(c.context, hasSeen: c.seen, savedRecords: c.records) == c.moment)
    }

    @Test(arguments: [
        (status: UNAuthorizationStatus.notDetermined, present: true),
        (status: .authorized, present: false),
        (status: .denied, present: false),
        (status: .provisional, present: false),
    ])
    func primerOnlyWhenIOSHasNotAsked(_ c: (status: UNAuthorizationStatus, present: Bool)) {
        #expect(NotificationPrimerMomentLogic.shouldPresent(authorization: c.status) == c.present)
    }

    // MARK: - L5-15 · Novedades

    @Test func whatsNew_2_2_hasContent_andHotfixesShareIt() throws {
        let features = try #require(WhatsNewConfig.features(for: "2.2"))
        #expect(features.count == 3)
        #expect(WhatsNewConfig.features(for: "2.2.1") == features)
    }

    /// Ajustes › Ayuda › Novedades enseña la hoja de la versión que corre, con su versión en el subtítulo.
    @Test func whatsNew_current_forTheRunningVersion() throws {
        let current = try #require(WhatsNewConfig.current(version: "2.1.3"))
        #expect(current.features == WhatsNewConfig.features(for: "2.1"))
        #expect(current.version == "2.1.3")
        #expect(WhatsNewConfig.current(version: "9.9") == nil, "sin entrada, la fila no se pinta")
    }

    // MARK: - L5-11 · el globo dice qué es P-1 y A-1

    @Test func comparisonTip_namesBothCircles() {
        let message = L10n.TipKit.comparisonMessage
        #expect(message.contains(L10n.Comparison.monthShort))
        #expect(message.contains(L10n.Comparison.yearShort))
        #expect(!message.contains("%"))
    }

    // MARK: - L5-12 · el tour Pro señala la fila de arriba

    @Test func proTourPanelSteps_pointAtTheQuickActionsRow() {
        let withAI = ProTourSteps.panelSteps(includesAssistant: true).map(\.id)
        #expect(withAI == [ProTourSteps.panelVoiceImageAnchor, ProTourSteps.panelAssistantAnchor])
        // Sin la píldora de IA, su paso no se monta (apuntaría a una vista que no existe).
        #expect(ProTourSteps.panelSteps(includesAssistant: false).map(\.id) == [ProTourSteps.panelVoiceImageAnchor])
    }

    // MARK: - L5-9 · la guía de Ajustes son tres pasos

    @Test func settingsTour_isThreeSteps() {
        #expect(SettingsTourSteps.steps.map(\.id) == ["settingsAccounts", "settingsPersonalization", "settingsTutorials"])
    }

    // MARK: - Cableado (source-scan)

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// L5-6: los editores y el flujo de caja ya traen su explicación; sus banners se retiraron (el resumen del filtro
    /// del presupuesto, que no se cierra, sigue).
    @Test(arguments: [
        ("Yala/App/Views/Shared/ContextualGuideBanner.swift", "static func budgetEditor()"),
        ("Yala/App/Views/Shared/ContextualGuideBanner.swift", "static func scheduledEditor()"),
        ("Yala/App/Views/Shared/ContextualGuideBanner.swift", "static func cashflow()"),
        ("Yala/App/Views/Planning/ScheduledPaymentEditorView.swift", "ContextualGuideBanner."),
    ])
    func noSecondExplanation(_ c: (file: String, banner: String)) throws {
        #expect(!(try Self.source(c.file)).contains(c.banner))
    }

    /// L5-12: el tour ya no fuerza los botones flotantes (el «+» que el Panel no tiene arriba).
    @Test func proTour_doesNotForceTheFloatingButtons() throws {
        let code = try Self.source("Yala/App/Views/Panel/PanelView.swift")
        #expect(!code.contains("showFloatingActions || showProFabTour"))
        #expect(code.contains("if showFloatingActions {"))
    }

    /// L5-9: tocar la zona oscura cierra la guía (como «Omitir guía»), ya no avanza.
    @Test func coachMark_tapOutsideCloses() throws {
        let code = try Self.source("Yala/App/Tips/CoachMarkOverlay.swift")
        let tap = try #require(code.range(of: ".onTapGesture {"))
        let body = String(code[tap.upperBound...].prefix(160))
        #expect(body.contains("dismissAndComplete(skipped: true)"))
        #expect(!body.contains("advance()"))
    }

    /// L5-10: sin brillo alrededor del foco.
    @Test func coachMark_hasNoGlow() throws {
        let code = try Self.source("Yala/App/Tips/CoachMarkOverlay.swift")
        #expect(!code.contains(".shadow(color: theme.accent"))
    }

    /// L5-13: el hito ya no lleva degradado ni halo.
    @Test func milestoneSheet_hasNoGradientNorHalo() throws {
        let code = try Self.source("Yala/App/Views/Shared/MilestoneUpgradeSheet.swift")
        #expect(!code.contains("LinearGradient"))
        #expect(!code.contains(".blur("))
    }

    /// L5-2: «Ahora no» en la práctica salta el paso, no lo da por hecho.
    @Test func practiceSkip_marksSkipped() throws {
        let code = try Self.source("Yala/App/Views/Panel/PanelSheetsModifier.swift")
        #expect(code.contains("SetupChecklistManager.shared.markSkipped(.tryVoiceInput)"))
        #expect(code.contains("SetupChecklistManager.shared.markSkipped(.tryImageInput)"))
    }

    /// L5-5: Planificación pregunta «¿era de prueba?» al cerrar el editor, por cada uno de sus dos pasos.
    @Test(arguments: [
        ("Yala/App/Views/Planning/BudgetsListView.swift", ".practiceCleanupPrompt(for: [.firstBudget]", "budgetEditorClosedToken += 1"),
        ("Yala/App/Views/Planning/ScheduledPaymentsView.swift", ".practiceCleanupPrompt(for: [.scheduledPayment]", "paymentEditorClosedToken += 1"),
    ])
    func planningAsksAtTheMoment(_ c: (file: String, prompt: String, token: String)) throws {
        let code = try Self.source(c.file)
        #expect(code.contains(c.prompt))
        #expect(code.contains(c.token))
    }
}
