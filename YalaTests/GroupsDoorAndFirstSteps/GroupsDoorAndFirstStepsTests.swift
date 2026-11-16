//
//  GroupsDoorAndFirstStepsTests.swift
//  YalaTests
//
//  Recorrido de la bienvenida en el iPhone 14 (13-nov), escenarios E03, E13 y E14
//  (`docs/qa/recorrido-bienvenida-2026-11-13/`). Cada suite cae sin su arreglo:
//
//  · E13 · «¡Hola de nuevo!» desde la puerta de Grupos sin «Restaurar desde iCloud» ni la nota del faro, y sus dos
//    entradas por el acceso único (el consentimiento dentro de la hoja que sigue a la firma, no en una hoja aparte).
//  · E03 · quien recupera sus datos responde las tres preguntas enteras: la conversación no propone nada de lo restaurado.
//  · E14 · «Ver los 7 pasos» abre grande y cualquier paso sin hacer se abre tocándolo; la guía de foco retira la
//    tarjeta «Este es tu resumen»; las partes del paso 7 duran más; los puntos de un tutorial son sus pasos.
//

import Foundation
import SwiftUI
import Testing

@testable import Yala

private enum Source {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // GroupsDoorAndFirstSteps/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    /// El fichero sin las líneas de comentario: documentar lo que el test busca no lo pone en verde.
    static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo entre la llave que sigue al marcador y la que la cierra.
    static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1, i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<i])
    }
}

// MARK: - E13 · la puerta de Grupos

@Suite("E13 · «¡Hola de nuevo!» desde la puerta de Grupos")
struct GroupsDoorExistingChooserTests {
    typealias Logic = WelcomeAccountChoiceLogic
    private let all: [Logic.ExistingOption] = [.restoreICloud, .cloudSignIn, .googleSignIn]

    @Test("desde Grupos no se ofrece iCloud ni la nota del faro, aunque el faro diga Apple")
    func fromGroupsDoor_dropsICloudAndTheBeaconNote() {
        let order = Logic.existingChooserOrder(all, fromGroupsDoor: true, beaconLinked: true, beaconProvider: "apple")
        #expect(order.options == [.cloudSignIn, .googleSignIn])
        #expect(order.usedOnThisDevice == nil)
    }

    @Test("control: fuera de la puerta de Grupos, el orden y la nota del faro de siempre")
    func elsewhere_keepsTheBeaconOrder() {
        let order = Logic.existingChooserOrder(all, fromGroupsDoor: false, beaconLinked: true, beaconProvider: "google")
        #expect(order == Logic.orderExistingOptions(all, beaconLinked: true, beaconProvider: "google"))
        #expect(order.options.contains(.restoreICloud))
        #expect(order.usedOnThisDevice == .googleSignIn)
    }

    @Test("sin entradas a una cuenta (interruptor remoto apagado), la puerta conserva lo que había")
    func withoutAccountEntries_keepsRestore() {
        #expect(Logic.existingOptions([.restoreICloud], fromGroupsDoor: true) == [.restoreICloud])
        #expect(Logic.bypass(Logic.existingOptions([.restoreICloud], fromGroupsDoor: true)) == .restoreICloud)
    }

    @Test("el contenedor pinta y salta el sub-elector con las opciones de la puerta")
    func containerUsesTheDoorOptions() throws {
        let src = try Source.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let branch = try Source.body(of: "private func handleExistingBranch() {", in: src)
        #expect(branch.contains("WelcomeAccountChoiceLogic.existingOptions("))
        #expect(branch.contains("fromGroupsDoor: step == .groupsChooser"))
        #expect(branch.contains("WelcomeAccountChoiceLogic.bypass(options)"))
        #expect(src.contains("fromGroupsDoor: WelcomeGroupsDoorLanding.isArmed || existingChooserOrigin == .groupsChooser"))
    }

    @Test("sin «Restaurar desde iCloud», el subtítulo no promete iCloud")
    func subtitleOnlyWithRestore() throws {
        let view = try Source.code("Yala/App/Views/Onboarding/WelcomeExistingChooserView.swift")
        #expect(view.contains("subtitle: offersRestore ? L10n.Welcome.Existing.subtitle : nil"))
    }

    @Test("las dos entradas de «¡Hola de nuevo!» y la vuelta de la puerta van por el acceso único")
    func entriesGoThroughTheUnifiedAccess() throws {
        let src = try Source.code("Yala/App/ContentView.swift")
        #expect(src.contains("welcomeCloudEntry = .unified(option == .googleSignIn ? .google : .apple)"))
        let proceed = try Source.body(of: "onGroupsGateCloudAccountProceed: { provider, fromExistingChooser in", in: src)
        #expect(proceed.contains("welcomeCloudEntry = .unified(provider)"))
        #expect(proceed.contains("adoptStartsAtConsent = false"))
        #expect(!proceed.contains(".reentry("))
    }
}

// MARK: - E03 · las tres preguntas enteras

@Suite("E03 · quien recupera sus datos responde las tres preguntas enteras")
struct ConversationAsksEverythingTests {

    @Test("la conversación no recibe ni propone lo que trajo el resumen de iCloud")
    func conversationIgnoresTheRestoredSummary() throws {
        let view = try Source.code("Yala/App/Views/Onboarding/WelcomeConversationView.swift")
        #expect(!view.contains("prefilledData"))
        #expect(!view.contains("restoredName:"))
        #expect(view.contains("WelcomeConversationLogic.proposedName(fromProviderName: providerName)"))
        #expect(view.contains("WelcomeConversationLogic.proposedCurrency(restoredCode: nil, region: regionCurrency)"))
        let cover = try Source.body(of: "private var onboardingCover: some View {", in: try Source.code("Yala/App/ContentView.swift"))
        #expect(cover.contains("WelcomeConversationView("))
        #expect(!cover.contains("prefilledData:"))
    }

    @Test("con el nombre del proveedor, se propone igual que a cualquiera")
    func providerNameIsStillProposed() {
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: "Ana García") == "Ana")
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: nil) == nil)
    }
}

// MARK: - E14 · Primeros pasos en el iPhone 14

@Suite("E14 · «Ver los 7 pasos»")
struct SetupStepsListTests {

    @Test("abre grande, para que se vean los siete en un iPhone 14")
    func opensLarge() {
        #expect(SetupStepsListLogic.initialDetent == .large)
    }

    @Test("se abre cualquier paso sin hacer, también omitido o no siguiente; uno hecho, no")
    func opensAnyStepNotDone() {
        #expect(SetupStepsListLogic.opens(SetupStep(id: .firstBudget, isCompleted: false)))
        #expect(SetupStepsListLogic.opens(SetupStep(id: .homeScreen, isCompleted: false, isSkipped: true)))
        #expect(!SetupStepsListLogic.opens(SetupStep(id: .firstAccount, isCompleted: true)))
    }

    @Test("el paso tocado se abre al terminar de cerrarse la hoja, por el mismo camino que el mazo")
    func tappedStepOpensAfterTheSheetCloses() throws {
        let card = try Source.code("Yala/App/Views/Panel/SetupChecklistCard.swift")
        #expect(card.contains(".sheet(isPresented: $showsAllSteps, onDismiss: openStepTappedInList)"))
        #expect(card.contains("SetupStepsListSheet(manager: manager, onOpenStep: { stepOpenedFromList = $0 })"))
        let open = try Source.body(of: "private func openStepTappedInList() {", in: card)
        #expect(open.contains("onStepTapped(step)"))
        #expect(open.contains("stepOpenedFromList = nil"))
    }
}

@Suite("E14 · las guías no se apilan", .serialized)
@MainActor
struct PlaceGuideRetiresPanelBannerTests {

    @Test("arrancar una guía de foco retira «Este es tu resumen»")
    func startingAGuideRetiresThePanelBanner() throws {
        let defaults = try #require(testDefaults(suiteName: "PlaceGuideRetiresPanelBanner-\(UUID().uuidString)"))
        let center = PlaceGuideCenter(defaults: defaults)
        #expect(!defaults.bool(forKey: PlaceGuideLogic.panelBeginnerGuideKey))
        #expect(center.start(.inbox))
        #expect(defaults.bool(forKey: PlaceGuideLogic.panelBeginnerGuideKey))
    }

    @Test("control: si ya hay una guía en pantalla y no arranca otra, no toca nada más")
    func aRejectedStartDoesNotTouchTheBanner() throws {
        let defaults = try #require(testDefaults(suiteName: "PlaceGuideRetiresPanelBanner-\(UUID().uuidString)"))
        let center = PlaceGuideCenter(defaults: defaults)
        #expect(center.start(.inbox))
        defaults.set(false, forKey: PlaceGuideLogic.panelBeginnerGuideKey)
        #expect(!center.start(.groups))
        #expect(!defaults.bool(forKey: PlaceGuideLogic.panelBeginnerGuideKey))
    }

    @Test("la clave es la de la tarjeta del Panel")
    func keyMatchesThePanelBanner() throws {
        #expect(PlaceGuideLogic.panelBeginnerGuideKey == "guide.panel.dismissed")
        let banner = try Source.code("Yala/App/Views/Shared/ContextualGuideBanner.swift")
        #expect(banner.contains("\"guide.\\(guideID).dismissed\""))
        #expect(banner.contains("guideID: \"panel\""))
        let panel = try Source.code("Yala/App/Views/Panel/PanelView.swift")
        #expect(panel.contains("@AppStorage(\"guide.panel.dismissed\")"))
    }
}

@Suite("E14 · el paso 7 y los tutoriales")
struct StepSevenAndTutorialDotsTests {

    @Test("las partes de «Anota sin abrir Yala» duran más que las otras")
    func stepSevenIsSlower() throws {
        #expect(TutorialStoryLogic.slowPartDuration > TutorialStoryLogic.partDuration)
        #expect(TutorialStoryLogic.slowPartDuration >= .seconds(6))
        let flow = try Source.code("Yala/App/Views/Onboarding/PrimerosPasos/HomeScreenTutorialFlowView.swift")
        #expect(flow.contains("partDuration: TutorialStoryLogic.slowPartDuration"))
        let page = try Source.code("Yala/App/Views/Onboarding/PrimerosPasos/TutorialStoryPage.swift")
        #expect(page.contains("try await Task.sleep(for: partDuration)"))
        #expect(!page.contains(".linear(duration: 3.4)"))
    }

    @Test("un tutorial de cuatro pasos enseña cuatro puntos")
    func dotsAreTheSteps() {
        #expect(TutorialProgressDots.count(steps: 4) == 4)
    }

    @Test("portada: todos por venir; paso 2: uno hecho y el actual; final: todos hechos")
    func dotStates() {
        typealias D = TutorialProgressDots
        #expect((0..<4).map { D.state(dot: $0, page: 0, steps: 4) } == [.upcoming, .upcoming, .upcoming, .upcoming])
        #expect((0..<4).map { D.state(dot: $0, page: 2, steps: 4) } == [.done, .current, .upcoming, .upcoming])
        #expect((0..<4).map { D.state(dot: $0, page: 5, steps: 4) } == [.done, .done, .done, .done])
    }

    @Test("la vista pinta un punto por paso")
    func viewUsesTheDots() throws {
        let view = try Source.code("Yala/App/Views/Settings/TutorialDetailView.swift")
        #expect(view.contains("ForEach(0..<TutorialProgressDots.count(steps: steps.count), id: \\.self)"))
        #expect(!view.contains("ForEach(0..<totalPages, id: \\.self) { page in"))
    }
}
