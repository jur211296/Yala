//
//  Bienvenida23AltaTests.swift
//  YalaTests
//
//  Lote 02 de la bienvenida 2.3 (`docs/onboarding-2-3/SPEC.md`): la vitrina y sus accesos (Y23-01), la puerta de Grupos
//  (Y23-06) y la conversación de tres preguntas (Y23-04). Lo que se decide sin pintar: qué enseña cada puerta, cuándo
//  rota sola, qué propone la conversación y qué guarda al terminar.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite("Bienvenida 2.3 · vitrina y accesos (Y23-01, Y23-06)")
struct Bienvenida23ShowcaseTests {

    @Test("«Mis finanzas» enseña seis funciones, con Grupos dentro de la vitrina")
    func financesDoorShowsSixWithGroupsInside() {
        let demos = WelcomeShowcaseLogic.demos(for: .finances)
        #expect(demos == [.receipt, .voice, .organize, .splitAny, .budget, .whoOwes])
        #expect(demos.filter(\.isPro) == [.receipt, .voice], "Foto y voz llevan el rótulo PRO; nada más.")
        #expect(demos.filter(\.isGroups).count == 2)
    }

    @Test("La puerta de Grupos enseña sus tres funciones y solo Google y Apple: Grupos exige cuenta de Yala")
    func groupsDoorHasNoICloud() {
        #expect(WelcomeShowcaseLogic.demos(for: .groups) == [.splitAny, .whoOwes, .settle])
        #expect(WelcomeShowcaseLogic.accesses(for: .groups) == [.google, .apple])
        #expect(WelcomeShowcaseLogic.accesses(for: .finances) == [.google, .apple, .iCloud])
    }

    @Test("«Dividir gastos con amigos» sale solo en las funciones de grupos y solo desde «Mis finanzas»")
    func groupsDoorShortcut() {
        #expect(WelcomeShowcaseLogic.offersGroupsDoor(.splitAny, on: .finances))
        #expect(WelcomeShowcaseLogic.offersGroupsDoor(.whoOwes, on: .finances))
        #expect(!WelcomeShowcaseLogic.offersGroupsDoor(.receipt, on: .finances))
        #expect(!WelcomeShowcaseLogic.offersGroupsDoor(.splitAny, on: .groups))
    }

    @Test("Rota sola solo sin pausa, sin Reducir movimiento y sin VoiceOver",
          arguments: [(false, false, false, true), (true, false, false, false),
                      (false, true, false, false), (false, false, true, false)])
    func rotation(paused: Bool, reduceMotion: Bool, voiceOver: Bool, rotates: Bool) {
        #expect(WelcomeShowcaseLogic.rotatesOnItsOwn(paused: paused, reduceMotion: reduceMotion,
                                                     voiceOver: voiceOver) == rotates)
    }

    @Test("Avanzar y retroceder dan la vuelta; cambiar de puerta no deja un índice fuera")
    func indices() {
        #expect(WelcomeShowcaseLogic.next(after: 5, count: 6) == 0)
        #expect(WelcomeShowcaseLogic.previous(before: 0, count: 6) == 5)
        #expect(WelcomeShowcaseLogic.clamped(4, count: 3) == 0)
        #expect(WelcomeShowcaseLogic.clamped(2, count: 3) == 2)
    }

}

@Suite("Bienvenida 2.3 · conversación de tres preguntas (Y23-04)", .serialized)
@MainActor
struct Bienvenida23ConversationTests {

    @Test("Propone el primer nombre de Google o Apple; sin nombre útil, se escribe")
    func proposedName() {
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: "Ana García") == "Ana")
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: "  Luis  ") == "Luis")
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: nil) == nil)
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: "   ") == nil)
        #expect(WelcomeConversationLogic.proposedName(fromProviderName: "ana@gmail.com") == nil)
    }

    @Test("El nombre restaurado de iCloud se propone entero y gana al del proveedor")
    func restoredNameWins() {
        #expect(WelcomeConversationLogic.proposedName(providerName: "Ana García", restoredName: "Juan Pérez") == "Juan Pérez")
        #expect(WelcomeConversationLogic.proposedName(providerName: "Ana García", restoredName: "  ") == "Ana")
        #expect(WelcomeConversationLogic.proposedName(providerName: nil, restoredName: nil) == nil)
    }

    @Test("La moneda propuesta es la del iCloud restaurado si la trae; si no, la de la región")
    func proposedCurrency() {
        let restored = WelcomeConversationLogic.proposedCurrency(restoredCode: "EUR", region: .pen)
        #expect(restored.currency == .eur && !restored.fromRegion)
        #expect(WelcomeConversationLogic.currencyOptions(region: restored.currency) == [.eur, .usd])
        let region = WelcomeConversationLogic.proposedCurrency(restoredCode: nil, region: .pen)
        #expect(region.currency == .pen && region.fromRegion)
        #expect(WelcomeConversationLogic.proposedCurrency(restoredCode: "XXX", region: .pen).currency == .pen)
    }

    @Test("Un nombre vacío no deja seguir; el escrito se guarda sin espacios a los lados")
    func acceptedName() {
        #expect(WelcomeConversationLogic.acceptedName("  ") == nil)
        #expect(WelcomeConversationLogic.acceptedName(" Ana ") == "Ana")
    }

    @Test("Las preguntas van en orden: nombre, moneda, qué llevar y listo")
    func order() {
        #expect(WelcomeConversationLogic.step(after: .name) == .currency)
        #expect(WelcomeConversationLogic.step(after: .currency) == .tracking)
        #expect(WelcomeConversationLogic.step(after: .tracking) == .done)
        #expect(WelcomeConversationLogic.step(after: .done) == .done)
    }

    @Test("La moneda de la región va primero y dólares después, sin repetirse")
    func currencyOptions() {
        #expect(WelcomeConversationLogic.currencyOptions(region: .pen) == [.pen, .usd])
        #expect(WelcomeConversationLogic.currencyOptions(region: .usd) == [.usd])
    }

    @Test("«Solo gastos» crea la cuenta de gastos; categorías siempre por defecto",
          arguments: [WelcomeConversationLogic.Tracking.expensesOnly, .incomeAndExpenses])
    func storeGetsWhatTheAltaWrites(tracking: WelcomeConversationLogic.Tracking) throws {
        let context = try makeTestContext()

        WelcomeConversationCommit.writeStore(currency: .pen, tracking: tracking, context: context)

        let categories = try context.fetch(FetchDescriptor<Yala.Category>())
        #expect(!categories.isEmpty, "Las categorías van siempre por defecto: «Prefiero crearlas yo» salió del alta.")
        let accounts = try context.fetch(FetchDescriptor<Account>())
        if tracking == .expensesOnly {
            #expect(accounts.count == 1, "Con «Solo gastos» Yala crea sola la cuenta de gastos.")
            #expect(accounts.first?.currencyCode == "PEN")
        } else {
            #expect(accounts.isEmpty, "Con «Gastos e ingresos» la primera cuenta es el paso 1 de «Primeros pasos».")
        }
    }

    @Test("Cada modo guarda el modo de uso y la mentalidad del alta de siempre")
    func trackingMapsToTheUsageModes() {
        #expect(WelcomeConversationLogic.Tracking.expensesOnly.usageMode == .expensesOnly)
        #expect(WelcomeConversationLogic.Tracking.expensesOnly.mindset == "cashFlow")
        #expect(WelcomeConversationLogic.Tracking.incomeAndExpenses.usageMode == .dayToDay)
        #expect(WelcomeConversationLogic.Tracking.incomeAndExpenses.mindset == "patrimonial")
    }
}

@Suite("Bienvenida 2.3 · acceso único con Google o Apple (Y23-02)")
struct Bienvenida23UnifiedAccessTests {

    @Test("Sin cuenta, el acceso único ofrece crearla en la misma hoja; sin la puerta del alta, «No encontramos»")
    func withoutAccount() {
        #expect(UnifiedAccessLogic.phaseWithoutAccount(isUnifiedAccess: true, offersSignUp: true) == .createAccount)
        #expect(UnifiedAccessLogic.phaseWithoutAccount(isUnifiedAccess: true, offersSignUp: false) == .notFound)
        #expect(UnifiedAccessLogic.phaseWithoutAccount(isUnifiedAccess: false, offersSignUp: true) == .notFound,
                "«Ya tengo una cuenta» y el faro siguen con su «No encontramos una cuenta».")
    }

    @Test("Con cuenta, el acceso único pregunta antes de traer los datos, una sola vez")
    func asksBeforeLoading() {
        #expect(UnifiedAccessLogic.asksBeforeLoading(isUnifiedAccess: true, loadConfirmed: false, origin: .reentry))
        #expect(!UnifiedAccessLogic.asksBeforeLoading(isUnifiedAccess: true, loadConfirmed: true, origin: .reentry))
        #expect(!UnifiedAccessLogic.asksBeforeLoading(isUnifiedAccess: false, loadConfirmed: false, origin: .reentry))
        #expect(!UnifiedAccessLogic.asksBeforeLoading(isUnifiedAccess: true, loadConfirmed: false,
                                                      origin: .signUpFoundExistingAccount),
                "El alta que encontró la cuenta ya creada no vuelve a preguntar: su terminal lo dice.")
    }

    @Test("La vitrina abre el acceso único sin consentimiento previo, y la hoja de crear lo lleva dentro (source-scan)")
    func wiring() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let container = try String(contentsOf: root.appendingPathComponent(
            "Yala/App/Views/Onboarding/WelcomeFlowContainer.swift"), encoding: .utf8)
        #expect(container.contains("case (.google, .finances):\n            enterWithProvider(.google)"))
        #expect(container.contains("case (.apple, .finances):\n            enterWithProvider(.apple)"))
        let content = try String(contentsOf: root.appendingPathComponent("Yala/App/ContentView.swift"), encoding: .utf8)
        #expect(content.contains("welcomeCloudEntry = .unified(provider)"))
        let view = try String(contentsOf: root.appendingPathComponent(
            "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"), encoding: .utf8)
        // Los tres puntos del consentimiento de siempre, con sus textos, y la aceptación que lo deja pendiente.
        for detail in ["L10n.Storage.Consent.pointServers", "L10n.Storage.Consent.pointPhotos",
                       "L10n.Storage.Consent.pointAccess", "L10n.Storage.Consent.privacyLink"] {
            #expect(view.contains(detail), "«Vamos a crear tu cuenta» perdió \(detail)")
        }
        #expect(view.contains("acceptConsentInThisSheet()\n                        switchToSignUp(with: signUpProvider)"))
        // «Cargar mis datos y entrar» también acepta el consentimiento (lo escribe el guard antes del adopt).
        #expect(view.contains("consentCard(id: \"welcome_cloud_confirm_load_consent\")"))
        #expect(view.contains("consentPendingPersistence = true\n        MetricsService.cloudConsentAccepted(path: CloudMigrationController.ConsentPath.adopt.rawValue)"))
    }
}
