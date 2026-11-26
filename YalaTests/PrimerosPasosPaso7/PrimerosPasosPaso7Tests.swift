//
//  PrimerosPasosPaso7Tests.swift
//  YalaTests
//
//  Encargo del 2026-11-20: Jürgen eligió la opción B en los cuatro temas de las maquetas de Primeros pasos
//  (`docs/maquetas/primeros-pasos-paso-7-y-prueba/`). (1) El paso 7 son historias con ejemplo y beneficio; (2) sin la hoja
//  «Ver los 7 pasos», el progreso va en el mazo; (3) sin tour de Ajustes ni tour Pro, «¡Listo! Tienes Pro» trae
//  «Pruébalo ahora»; (4) la oferta del mes de Pro sale al terminar el paso 2.
//

import Foundation
import Testing
@testable import Yala

private enum Paso7Source {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PrimerosPasosPaso7/
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

    static func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent(path).path)
    }

    /// El cuerpo que sigue a `marker`, hasta la llave que lo cierra. Si el marcador acaba en «{», esa llave ya cuenta.
    static func body(after marker: String, in code: String) throws -> String {
        let start = try #require(code.range(of: marker))
        var depth = marker.hasSuffix("{") ? 1 : 0
        var opened = depth > 0
        var result = ""
        for char in code[start.upperBound...] {
            if char == "{" { depth += 1; opened = true }
            if char == "}" { depth -= 1 }
            result.append(char)
            if opened && depth == 0 { break }
        }
        return result
    }
}

// MARK: - 4 · La oferta del mes de Pro, al terminar el paso 2

@Suite("Paso 7 · la oferta sale al terminar «Aprender a registrar»")
struct PrimerosPasosPaso7OfferTests {
    typealias L = TrialOfferMomentLogic

    @Test("terminar el paso 2 arma la oferta y la pide, salvo con Pro")
    func recordStepFinished_armsAndSubmits() {
        #expect(L.arms(.recordStepFinished, isProUser: false))
        #expect(!L.arms(.recordStepFinished, isProUser: true))
        #expect(L.reachesTheMoment(.recordStepFinished))
        #expect(L.shouldSubmit(.recordStepFinished, armed: true, momentReached: false, isProUser: false))
        #expect(!L.shouldSubmit(.recordStepFinished, armed: true, momentReached: false, isProUser: true))
    }

    @Test("con Primeros pasos a medias, guardar un registro no la pide; sin el mazo, como en 2.2")
    func recordSaved_isHeldWhilePrimerosPasosIsShown() {
        #expect(L.isHeldByPrimerosPasos(.recordSaved(firstRecordPracticePending: false), primerosPasosShown: true))
        #expect(L.isHeldByPrimerosPasos(.firstRecordPracticeAnswered, primerosPasosShown: true))
        #expect(!L.isHeldByPrimerosPasos(.recordStepFinished, primerosPasosShown: true))
        #expect(!L.isHeldByPrimerosPasos(.setupChecklistCompleted, primerosPasosShown: true))
        #expect(!L.isHeldByPrimerosPasos(.launch, primerosPasosShown: true))
        #expect(!L.isHeldByPrimerosPasos(.recordSaved(firstRecordPracticePending: false), primerosPasosShown: false))
        #expect(!L.isHeldByPrimerosPasos(.firstRecordPracticeAnswered, primerosPasosShown: false))
    }

    @Test("si salió tras el paso 2, el final de Primeros pasos no la repite; si no, es la red")
    func completion_offersOnlyIfTheRecordStepDidNot() {
        #expect(!SetupCompleteTrialOfferLogic.offersAtCompletion(offeredAfterRecordStep: true))
        #expect(SetupCompleteTrialOfferLogic.offersAtCompletion(offeredAfterRecordStep: false))
    }

    @Test("lo probado se guarda en orden, sin «a mano», y vuelve igual; lo desconocido se ignora")
    func triedMethods_roundTrip() {
        let stored = SetupCompleteTrialOfferLogic.storedTriedMethods([.ai, .manual, .voice])
        #expect(stored == ["voice", "ai"])
        #expect(SetupCompleteTrialOfferLogic.triedMethods(stored: stored + ["manual", "fax"]) == [.voice, .ai])
        #expect(SetupCompleteTrialOfferLogic.triedMethods(stored: nil).isEmpty)
    }

    @Test("la hoja nombra la primera manera de Pro probada: voz, luego foto, luego Yala IA")
    func headlineMethod_order() {
        typealias O = SetupCompleteTrialOfferLogic
        #expect(O.headlineMethod([.ai, .photo]) == .photo)
        #expect(O.headlineMethod([.ai, .voice, .photo]) == .voice)
        #expect(O.headlineMethod([.ai]) == .ai)
        #expect(O.headlineMethod([.manual]) == nil)
        #expect(O.headlineMethod([]) == nil)
    }

    @Test("lo probado se consume al presentar")
    func takeTriedMethods_consumes() throws {
        let defaults = try #require(testDefaults(suiteName: "PrimerosPasosPaso7.tried.\(UUID().uuidString)"))
        defaults.set(["photo"], forKey: SetupCompleteTrialOfferLogic.triedMethodsKey)
        #expect(SetupCompleteTrialOfferLogic.takeTriedMethods(defaults: defaults) == [.photo])
        #expect(SetupCompleteTrialOfferLogic.takeTriedMethods(defaults: defaults).isEmpty)
    }

    @Test("el paso 2 pide la oferta después de la guía de la Bandeja, con lo que probó leído antes de vaciar la sesión")
    func wiring_recordStepFinishedAfterTheGuide() throws {
        let code = try Paso7Source.code("Yala/App/Views/Panel/PrimerosPasosPanelPresentations.swift")
        let finish = try Paso7Source.body(after: "private func finishRecordTutorial(deleted: Int) {", in: code)
        let tried = try #require(finish.range(of: "let tried = RecordTutorialLogic.Method.allCases"))
        let clear = try #require(finish.range(of: "RecordTutorialSession.shared.finish()"))
        #expect(tried.lowerBound < clear.lowerBound, "Lo probado se lee después de vaciar la sesión: saldría vacío.")
        let notice = try Paso7Source.body(after: "let notice: () -> Void = {", in: finish)
        #expect(notice.contains("TrialOfferMoments.noteRecordStepFinished("))
        // Con el aviso de lo borrado a la vista, la oferta espera a que se vaya.
        #expect(notice.contains("submitDelay: deleted > 0 ? DraftDiscardUndoNotice.visibleDuration : nil"))
        #expect(finish.contains("PlaceGuideCenter.shared.start(.inbox, onFinish: notice)"))
    }

    @Test("el momento del paso 2 apunta la oferta del mazo, lo probado y que ya salió")
    func wiring_noteRecordStepFinished() throws {
        let code = try Paso7Source.code("Yala/App/Logic/TrialOfferMomentLogic.swift")
        let note = try Paso7Source.body(after: "static func noteRecordStepFinished(", in: code)
        #expect(note.contains("guard SetupChecklistManager.shared.showsDeck else { return }"))
        #expect(note.contains("SetupCompleteTrialOfferLogic.pendingOfferKey"))
        #expect(note.contains("SetupCompleteTrialOfferLogic.offeredAfterRecordStepKey"))
        #expect(note.contains("SetupCompleteTrialOfferLogic.triedMethodsKey"))
        #expect(note.contains("note(.recordStepFinished, submitDelay: submitDelay)"))
        let gate = try Paso7Source.body(after: "static func note(_ moment: TrialOfferMoment, submitDelay: Duration? = nil) {", in: code)
        #expect(gate.contains("primerosPasosShown: SetupChecklistManager.shared.isPrimerosPasosShown"))
        let manager = try Paso7Source.code("Yala/App/Models/SetupChecklistManager.swift")
        // Desde la opción C (25-nov-2026) el guard pasa también por la oferta dentro de la tarjeta final; la regla del paso
        // 2 sigue dentro (`completionSubmitsSheet` llama a `offersAtCompletion`).
        #expect(manager.contains("guard SetupCompleteTrialOfferLogic.completionSubmitsSheetNow else { return }"))
        let logic = try Paso7Source.code("Yala/App/Logic/SetupCompleteTrialOfferLogic.swift")
        #expect(logic.contains("offersAtCompletion(offeredAfterRecordStep: offeredAfterRecordStep) && !offerInCard"))
        #expect(logic.contains("offeredAfterRecordStep: UserDefaults.standard.bool(forKey: offeredAfterRecordStepKey)"))
    }

    @Test("la hoja: «Ahora no» arriba, el botón de empezar solo y fijo abajo, los cuatro bloques de Pro")
    func sheet_layout() throws {
        let sheet = try Paso7Source.code("Yala/App/Views/Subscription/SetupCompleteTrialOfferSheet.swift")
        #expect(sheet.contains("ToolbarItem(placement: .topBarLeading)"))
        #expect(sheet.contains("Button(P.notNow)"))
        #expect(sheet.contains(".safeAreaBar(edge: .bottom"))
        #expect(!sheet.contains("T.keepFree"), "«Seguir con la versión gratis» iba debajo del botón de empezar.")
        let bottom = try Paso7Source.body(after: "private var bottomButton: some View {", in: sheet)
        #expect(bottom.components(separatedBy: "YalaPrimaryButton(").count - 1 == 2, "Un botón por estado, nunca dos.")
        #expect(bottom.components(separatedBy: "Button(").count - 1 == 2, "Nada más abajo.")
        // Desde la opción A de «Oferta Pro: más beneficios» (20-nov-2026), cuatro bloques con las ocho puertas Pro en
        // vez de tres funciones: lo fija `OfertaProBeneficiosTests`.
        #expect(sheet.contains("OfertaProBeneficiosCard {"))
        let content = try Paso7Source.code("Yala/App/ContentView.swift")
        #expect(content.contains("trialOfferTriedMethods = SetupCompleteTrialOfferLogic.takeTriedMethods()"))
        #expect(content.contains("SetupCompleteTrialOfferSheet(triedMethods: trialOfferTriedMethods,"))
    }
}

// MARK: - 3 · Sin coach tips de Ajustes; Pro en «¡Listo! Tienes Pro»

@Suite("Paso 7 · sin tour de Ajustes ni tour Pro; «Pruébalo ahora»")
struct PrimerosPasosPaso7TipsTests {

    @Test("el gestor del tour Pro y su seam ya no existen")
    func proTourIsGone() throws {
        #expect(!Paso7Source.exists("Yala/App/Tips/ProTourManager.swift"))
        let hooks = try Paso7Source.code("Yala/App/UITestHooks.swift")
        #expect(!hooks.contains("-uitest-pro-tour-panel"))
        for file in ["Yala/App/Views/Profile/ProfileView.swift", "Yala/App/Views/Panel/PanelView.swift",
                     "Yala/App/Views/Statistics/InsightsTabView.swift", "Yala/App/Tips/PlaceGuideOverlay.swift",
                     "Yala/App/Views/Settings/SubscriptionView.swift",
                     "Yala/App/Views/Subscription/ProTrialOfferSheet.swift",
                     "Yala/App/Views/Subscription/SetupCompleteTrialOfferSheet.swift"] {
            #expect(!(try Paso7Source.code(file)).contains("ProTourManager"), "\(file) sigue con el tour Pro")
        }
    }

    @Test("Ajustes no saca su tour al abrirse")
    func settingsTourIsGone() throws {
        let profile = try Paso7Source.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(!profile.contains("coachMarkOverlay"))
        #expect(!profile.contains("showSettingsTour"))
        #expect(!profile.contains("SettingsTourSteps"))
        let tips = try Paso7Source.code("Yala/App/Tips/YalaTips.swift")
        #expect(!tips.contains("enum SettingsTourSteps"))
        #expect(!tips.contains("profileSteps"))
        #expect(!tips.contains("insightsSteps"))
    }

    @Test("los tres accesos de «Pruébalo ahora», en orden, y cada uno abre su función por la puerta de siempre")
    func tryNow_actions() throws {
        #expect(ProTryNowAction.allCases == [.voice, .photo, .yalaAI])
        let code = try Paso7Source.code("Yala/App/Views/Subscription/ProTryNowSection.swift")
        let open = try Paso7Source.body(after: "static func open(_ action: ProTryNowAction) {", in: code)
        #expect(open.contains("AppBootstrapper.shared.performPanelAction(.voiceEntry)"))
        #expect(open.contains("AppBootstrapper.shared.performPanelAction(.imageEntry)"))
        #expect(open.contains("navigation.pendingKeyboardPanelRequest = .yalaAI"))
    }

    @Test("«¡Listo! Tienes Pro» trae «Pruébalo ahora» y la función se abre al cerrarse la hoja")
    func tryNow_wiring() throws {
        let sheet = try Paso7Source.code("Yala/App/Views/Subscription/SetupCompleteTrialOfferSheet.swift")
        let success = try Paso7Source.body(after: "private var success: some View {", in: sheet)
        #expect(success.contains("ProTryNowSection"))
        #expect(success.contains("onTryNow(action)"))
        let content = try Paso7Source.code("Yala/App/ContentView.swift")
        #expect(content.contains(".sheet(isPresented: $showProTrialOffer, onDismiss: openPendingProTryNow)"))
        let pending = try Paso7Source.body(after: "fileprivate func openPendingProTryNow() {", in: content)
        #expect(pending.contains("pendingProTryNow = nil"))
        #expect(pending.contains("ProTryNow.open(action)"))
        // La otra puerta que presenta el mismo ancla: la oferta de tras guardar un registro.
        let success2 = try Paso7Source.code("Yala/App/Views/Subscription/SubscriptionSuccessView.swift")
        #expect(success2.contains("if feature == nil, let onTryNow {"))
        let offer = try Paso7Source.code("Yala/App/Views/Subscription/ProTrialOfferSheet.swift")
        #expect(offer.contains("SubscriptionSuccessView(onTryNow: onTryNow)"))
    }
}

// MARK: - 2 · El progreso dentro del mazo

@Suite("Paso 7 · el progreso va en el mazo")
struct PrimerosPasosPaso7DeckTests {
    typealias P = SetupDeckProgressLogic

    @Test("hecho, para después, el de ahora y pendiente se distinguen")
    func states() {
        #expect(P.state(of: SetupStep(id: .firstAccount, isCompleted: true), current: .homeScreen) == .done)
        #expect(P.state(of: SetupStep(id: .firstBudget, isCompleted: false, isSkipped: true), current: .homeScreen) == .later)
        #expect(P.state(of: SetupStep(id: .homeScreen, isCompleted: false), current: .homeScreen) == .current)
        #expect(P.state(of: SetupStep(id: .groups, isCompleted: false), current: .homeScreen) == .pending)
        // Hecho manda sobre omitido.
        #expect(P.state(of: SetupStep(id: .groups, isCompleted: true, isSkipped: true), current: nil) == .done)
    }

    @Test("cuenta los hechos y los de después, y los nombra en orden")
    func countsAndLater() {
        let steps = [
            SetupStep(id: .firstAccount, isCompleted: true),
            SetupStep(id: .firstExpense, isCompleted: true),
            SetupStep(id: .firstBudget, isCompleted: false, isSkipped: true),
            SetupStep(id: .scheduledPayment, isCompleted: false, isSkipped: true),
            SetupStep(id: .groups, isCompleted: false),
        ]
        let counts = P.counts(steps)
        #expect(counts.done == 2)
        #expect(counts.later == 2)
        #expect(P.later(steps) == [.firstBudget, .scheduledPayment])
    }

    @Test("sin hoja: la carta lleva los segmentos y «Seguir donde iba», y debajo va la fila que abre los pasos")
    func card_wiring() throws {
        #expect(!Paso7Source.exists("Yala/App/Views/Panel/SetupStepsListSheet.swift"))
        let card = try Paso7Source.code("Yala/App/Views/Panel/SetupChecklistCard.swift")
        #expect(!card.contains(".sheet("))
        #expect(!card.contains("showAllSteps"))
        let deck = try Paso7Source.body(after: "private func deckView(_ deck: SetupDeckLogic.Deck) -> some View {", in: card)
        #expect(deck.contains("SetupDeckSegments(steps: manager.steps, current: deck.current, ink: theme.onAccent)"))
        #expect(deck.contains("Text(L10n.SetupChecklist.Deck.resume)"))
        #expect(deck.contains("SetupDeckStepsRow(steps: manager.steps, current: deck.current, onOpen: onStepTapped)"))
        let done = try Paso7Source.body(after: "private var deckCompletedView: some View {", in: card)
        #expect(done.contains("SetupDeckStepsRow(steps: manager.steps, current: nil"))
    }

    @Test("los nombres cortos de los siete pasos existen")
    func shortNames() {
        for step in SetupStepID.deck {
            let name = PrimerosPasosPaso7Text.Deck.shortName(step)
            #expect(!name.isEmpty)
            #expect(!name.hasPrefix("primerosPasosPaso7."), "\(step) sin texto")
        }
    }
}

// MARK: - 1 · El paso 7 como historias

@Suite("Paso 7 · historias con ejemplo y beneficio")
struct PrimerosPasosPaso7StoriesTests {

    @Test("no avanza sola, la ✕ cierra, pasar la última termina y no hay «Omitir»")
    func flow_wiring() throws {
        let flow = try Paso7Source.code("Yala/App/Views/Onboarding/PrimerosPasos/HomeScreenTutorialFlowView.swift")
        let stories = try Paso7Source.body(after: "private var stories: some View {", in: flow)
        #expect(stories.contains("autoAdvances: false"))
        #expect(stories.contains("backSystemImage: \"xmark\""))
        #expect(stories.contains("onAdvancePastLast: finish"))
        #expect(stories.contains("onBack: { onClose(.closed) }"))
        #expect(!flow.contains("skipStep"))
        #expect(!flow.contains("case between"))
        // Un solo botón abajo, suave.
        let footer = try Paso7Source.body(after: "footer: {", in: stories)
        #expect(footer.components(separatedBy: "Button(").count - 1 == 1)
        #expect(footer.contains("YalaSecondaryButton("))
    }

    @Test("el mini tutorial vuelve a su historia y deja un solo botón abajo")
    func methodPage_singleButton() throws {
        let pages = try Paso7Source.code("Yala/App/Views/Onboarding/PrimerosPasos/HomeScreenTutorialPages.swift")
        let footer = try Paso7Source.body(after: "private var footer: some View {", in: pages)
        #expect(!footer.contains("YalaSecondaryButton"), "«Abrir Atajos» iba encima de «Listo».")
        #expect(pages.contains("let onBack: () -> Void"))
        #expect(!pages.contains("home_tutorial_method_skip"))
    }

    @Test("la página de historias termina al pasar la última solo si se le pide; las intros siguen igual")
    func storyPage_pastLast() throws {
        let page = try Paso7Source.code("Yala/App/Views/Onboarding/PrimerosPasos/TutorialStoryPage.swift")
        #expect(page.contains("var autoAdvances: Bool = true"))
        #expect(page.contains("var onAdvancePastLast: (() -> Void)?"))
        #expect(page.contains("if step > 0, isLastPart, let onAdvancePastLast {"))
        #expect(page.contains("private var canRun: Bool { autoAdvances && !reduceMotion && !voiceOver }"))
    }

    @MainActor @Test("terminar un mini tutorial no resetea lo hecho; la ✕ conserva la historia")
    func close_keepsTheStory() throws {
        let presentation = try Paso7Source.code("Yala/App/Views/Panel/PrimerosPasosHomeScreenPresentation.swift")
        let after = try Paso7Source.body(after: "private func afterTutorial() {", in: presentation)
        let reset = after.components(separatedBy: "progress.reset()").count - 1
        #expect(reset == 2, "Solo se reinicia al resolver el paso (hecho u omitido).")
        #expect(after.contains("case nil:\n            progress.phase = .story"))
        let progress = HomeScreenTutorialProgress()
        progress.part = 2
        progress.phase = .method(.share)
        progress.reset()
        #expect(progress.part == 0)
        #expect(progress.phase == .story)
    }
}

// MARK: - Textos

@Suite("Paso 7 · textos en su tabla y en los 16 idiomas")
struct PrimerosPasosPaso7TextTests {

    private static let locales = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl",
                                  "pt", "pt-BR", "pt-PT", "zh-Hans"]

    private static func table(_ locale: String) throws -> [String: String] {
        let url = Paso7Source.repoRoot.appendingPathComponent("Yala/Resources/\(locale).lproj/PrimerosPasosPaso7.strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale) sin tabla")
    }

    private static func specifiers(_ text: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: "%(\\d\\$)?[@d]")
        let range = NSRange(text.startIndex..., in: text)
        return (regex?.matches(in: text, range: range) ?? []).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
            .sorted()
    }

    @Test("las mismas claves y los mismos formatos que es-419, en su tabla y no en Localizable", arguments: locales)
    func everyLocaleMatchesTheBase(locale: String) throws {
        let base = try Self.table("es-419")
        let table = try Self.table(locale)
        #expect(Set(table.keys) == Set(base.keys), "\(locale): claves distintas")
        for (key, value) in base {
            let translated = try #require(table[key], "\(locale): falta \(key)")
            #expect(!translated.isEmpty)
            #expect(Self.specifiers(translated) == Self.specifiers(value), "\(locale): \(key) cambia los formatos")
        }
        let localizable = try String(
            contentsOf: Paso7Source.repoRoot.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings"),
            encoding: .utf8)
        #expect(!localizable.contains("primerosPasosPaso7."), "\(locale): textos nuevos en Localizable")
    }

    @Test("cada lector apunta a una clave que existe")
    func readersResolve() throws {
        let base = try Self.table("es-419")
        let code = try Paso7Source.code("Yala/App/Views/Onboarding/PrimerosPasos/PrimerosPasosPaso7Text.swift")
        let regex = try NSRegularExpression(pattern: "(?:string|format)\\(\"([a-zA-Z.]+)\"")
        let range = NSRange(code.startIndex..., in: code)
        let keys = regex.matches(in: code, range: range).compactMap { Range($0.range(at: 1), in: code).map { String(code[$0]) } }
        #expect(keys.count >= 50)
        for key in keys {
            #expect(base["primerosPasosPaso7.\(key)"] != nil, "Falta \(key) en la tabla")
        }
    }
}
