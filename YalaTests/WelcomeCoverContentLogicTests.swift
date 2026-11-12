//
//  WelcomeCoverContentLogicTests.swift
//  YalaTests
//
//  Card 4gfj (decisión A de Jürgen, 2026-10-25): el Welcome y la entrada a una cuenta de Yala viven en UN cover y se
//  funden en vez de cerrarse y abrirse enteros. La lógica es pura y se prueba de frente; el cableado vive en
//  `WelcomeFlowModifier` y se fija con un escáner acotado a su cuerpo (`.claude/rules/testing.md`).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Cover del Welcome: pasos y entrada a la cuenta en un solo cover")
struct WelcomeCoverContentLogicTests {

    typealias Logic = WelcomeCoverContentLogic

    // MARK: - Lógica

    @Test("lo pedido sale de los flags, y con los dos encendidos gana la entrada a la cuenta")
    func requested_truthTable() {
        #expect(Logic.requested(showsFlow: true, showsCloudSignIn: false) == .flow)
        #expect(Logic.requested(showsFlow: false, showsCloudSignIn: true) == .cloudSignIn)
        #expect(Logic.requested(showsFlow: true, showsCloudSignIn: true) == .cloudSignIn)
        #expect(Logic.requested(showsFlow: false, showsCloudSignIn: false) == nil)
    }

    @Test("bajando, el cover sigue enseñando lo último: la entrada que termina no se cambia por el Hero")
    func displayed_keepsTheLastWhileDismissing() {
        #expect(Logic.displayed(showsFlow: false, showsCloudSignIn: false, last: .cloudSignIn) == .cloudSignIn)
        #expect(Logic.displayed(showsFlow: false, showsCloudSignIn: false, last: .flow) == .flow)
        // Con un flag puesto manda el flag, no lo último: la entrada pedida desde fuera del Welcome (Grupos) sale sin
        // pasar por el Hero.
        #expect(Logic.displayed(showsFlow: false, showsCloudSignIn: true, last: .flow) == .cloudSignIn)
        #expect(Logic.displayed(showsFlow: true, showsCloudSignIn: false, last: .cloudSignIn) == .flow)
    }

    @Test("el cover se presenta con cualquiera de los dos flags y nunca con la invitación de grupo delante")
    func isPresented_truthTable() {
        for flow in [false, true] {
            for cloud in [false, true] {
                #expect(Logic.isPresented(showsFlow: flow, showsCloudSignIn: cloud, inhibited: false) == (flow || cloud))
                #expect(!Logic.isPresented(showsFlow: flow, showsCloudSignIn: cloud, inhibited: true))
            }
        }
    }

    @Test("solo el paso de la entrada a los pasos del Welcome repone el estado de la entrada")
    func cloudSignInLeftForFlow_onlyFromCloudToFlow() {
        #expect(Logic.cloudSignInLeftForFlow(last: .cloudSignIn, now: .flow))
        #expect(!Logic.cloudSignInLeftForFlow(last: .cloudSignIn, now: .cloudSignIn))
        // Bajando (nil): lo repone el `onDismiss`, que además decide el respaldo.
        #expect(!Logic.cloudSignInLeftForFlow(last: .cloudSignIn, now: nil))
        #expect(!Logic.cloudSignInLeftForFlow(last: .flow, now: .flow))
        #expect(!Logic.cloudSignInLeftForFlow(last: .flow, now: .cloudSignIn))
    }

    @Test("el respaldo de la entrada solo corre si lo último que enseñó el cover fue la entrada")
    func dismissFallback_onlyAfterTheCloudSignIn() {
        #expect(Logic.runsCloudSignInDismissFallback(last: .cloudSignIn))
        // Cerrado desde los pasos del Welcome (Restaurar, la invitación, el onboarding): sin respaldo, como el cover del
        // Welcome de antes. Con él, devolvería al elector encima de la pantalla siguiente.
        #expect(!Logic.runsCloudSignInDismissFallback(last: .flow))
    }

    @Test("el fundido dura 0,35 s, el de la propuesta A")
    func crossfadeDuration() {
        #expect(Logic.crossfadeSeconds == 0.35)
    }

    // MARK: - Cableado

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo entre la llave que sigue al marcador y la que la cierra.
    private static func body(of marker: String, in source: String) throws -> String {
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

    private static func flat(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static var modifier: String {
        get throws {
            try body(of: "private struct WelcomeFlowModifier: ViewModifier {", in: code("Yala/App/ContentView.swift"))
        }
    }

    @Test("un solo cover: ni el Welcome ni la entrada vuelven a tener el suyo")
    func singleCover() throws {
        let modifier = try Self.modifier
        #expect(modifier.components(separatedBy: ".fullScreenCover(").count == 2,
                "el modifier vuelve a tener más de un cover: el salto vuelve a cerrar y abrir pantallas enteras")
        #expect(!modifier.contains("isPresented: $showWelcomeCloudSignIn"))
        #expect(!modifier.contains("isPresented: $showWelcomeFlow"))
        let body = Self.flat(try Self.body(of: "func body(content: Content) -> some View {", in: modifier))
        #expect(body.contains(".fullScreenCover(isPresented: welcomeCoverIsPresented, onDismiss: welcomeCoverDidDismiss) { welcomeCover }"))
        #expect(body.contains(".onChange(of: requestedWelcomeCoverContent, initial: true) { _, now in noteWelcomeCoverContent(now) }"))
    }

    @Test("el contenido se funde sobre el degradado quieto, con la duración de la lógica")
    func crossfadeOverAStillGradient() throws {
        let cover = Self.flat(try Self.body(of: "private var welcomeCover: some View {", in: try Self.modifier))
        #expect(cover.hasPrefix("ZStack { LinearGradient(colors: DS.Gradients.heroIndigoBlack, startPoint: .top, endPoint: .bottom) .ignoresSafeArea() switch displayedWelcomeCoverContent {"),
                "el degradado tiene que ir DEBAJO de las dos pantallas: \(cover)")
        // El `zIndex` es lo que deja ver fundirse a la pantalla que SALE (card feer): sin él, en el `ZStack` se pinta por
        // debajo del degradado opaco y desaparece en un fotograma.
        #expect(cover.contains("case .flow: welcomeFlowContainer .transition(.opacity) .zIndex(1)"))
        #expect(cover.contains("case .cloudSignIn: welcomeCloudSignIn .transition(.opacity) .zIndex(1)"))
        #expect(cover.hasSuffix(".animation(.easeInOut(duration: WelcomeCoverContentLogic.crossfadeSeconds), value: displayedWelcomeCoverContent) .welcomeNavigationHost()"),
                "la pila de navegación va UNA vez, por encima de los pasos: \(cover)")
        // Con «Reducir movimiento» el fundido se queda (decisión A): nada lo apaga.
        #expect(!cover.contains("reduceMotion"))
    }

    // MARK: - Una pila para todos los pasos (card feer)

    @Test("dentro de la pila del recorrido, el «‹» de un paso no abre otra pila; fuera, sí")
    func backButtonReusesTheHostStack() throws {
        let source = try Self.code("Yala/App/Views/Onboarding/WelcomeBackButton.swift")
        let host = Self.flat(try Self.body(of: "private struct WelcomeNavigationHost: ViewModifier {", in: source))
        #expect(host == "func body(content: Content) -> some View { NavigationStack { content .environment(\\.isInsideWelcomeNavigationHost, true) } }")
        let button = try Self.body(of: "private struct WelcomeBackButton: ViewModifier {", in: source)
        let body = Self.flat(try Self.body(of: "func body(content: Content) -> some View {", in: button))
        #expect(body == "if isInsideHost { withBackButton(content) } else { NavigationStack { withBackButton(content) } }")
        #expect(button.contains("@Environment(\\.isInsideWelcomeNavigationHost) private var isInsideHost"))
    }

    @Test("ningún paso del cover vuelve a montar su propia pila: la que sale desaparecería de golpe")
    func noStepOfTheCoverOwnsAStack() throws {
        let steps = ["WelcomeHeroView", "WelcomeChooserView", "WelcomeExistingChooserView", "WelcomeNewChooserView",
                     "WelcomeGroupsChooserView", "WelcomeGroupsGateView", "WelcomePrivateICloudGateView",
                     "WelcomeMirrorRelaunchView", "WelcomeInviteOpeningView", "WelcomeCloudSignInView",
                     "WelcomeFlowContainer", "WelcomeForm", "WelcomeFlowLayout"]
        for step in steps {
            let source = try Self.code("Yala/App/Views/Onboarding/\(step).swift")
            #expect(!source.contains("NavigationStack"), "\(step) monta una NavigationStack propia dentro del cover")
        }
    }

    @Test("entre pasos, el mismo fundido que el cover, también con «Reducir movimiento»")
    func stepsCrossfadeLikeTheCover() throws {
        let container = try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let goTo = Self.flat(try Self.body(of: "private func goTo(_ next: WelcomeFlowStep) {", in: container))
        #expect(goTo == "guard step != next else { return } withAnimation(.easeInOut(duration: WelcomeCoverContentLogic.crossfadeSeconds)) { step = next }")
    }

    @Test("la limpieza del onDismiss viejo corre también al volver sin cerrar el cover, y el respaldo solo tras la entrada")
    func cleanupAndFallbackWiring() throws {
        let modifier = try Self.modifier
        let note = Self.flat(try Self.body(of: "private func noteWelcomeCoverContent(_ now: WelcomeCoverContentLogic.Content?) {", in: modifier))
        #expect(note == "if WelcomeCoverContentLogic.cloudSignInLeftForFlow(last: lastWelcomeCoverContent, now: now) { resetCloudSignInEntry() } if let now { lastWelcomeCoverContent = now }")
        let reset = Self.flat(try Self.body(of: "private func resetCloudSignInEntry() {", in: modifier))
        #expect(reset == "adoptStartsAtConsent = false cloudSignInFromExistingChooser = false")
        let dismiss = Self.flat(try Self.body(of: "private func welcomeCoverDidDismiss() {", in: modifier))
        #expect(dismiss.hasPrefix("guard WelcomeCoverContentLogic.runsCloudSignInDismissFallback(last: lastWelcomeCoverContent) else { return } resetCloudSignInEntry()"))
        #expect(dismiss.hasSuffix("if !hasCompletedOnboarding && !showGroupInviteOnboarding && !showOnboarding && !showWelcomeFlow { welcomeFlowInitialStep = .chooser showWelcomeFlow = true }"))
    }

    @Test("si UIKit cierra el cover, se apaga el flag de lo que enseñaba, no los dos")
    func systemDismissClearsTheDisplayedFlag() throws {
        let binding = Self.flat(try Self.body(of: "private var welcomeCoverIsPresented: Binding<Bool> {", in: try Self.modifier))
        #expect(binding.contains("WelcomeCoverContentLogic.isPresented( showsFlow: showWelcomeFlow, showsCloudSignIn: showWelcomeCloudSignIn, inhibited: showGroupInviteOnboarding)"))
        #expect(binding.contains("guard !presented else { return } switch displayedWelcomeCoverContent { case .flow: showWelcomeFlow = false case .cloudSignIn: showWelcomeCloudSignIn = false }"))
    }
}
