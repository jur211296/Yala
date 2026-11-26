//
//  OfertaProMazoCentradoTests.swift
//  YalaTests
//
//  Decisión de Jürgen del 25-nov-2026 («C y B») sobre las maquetas de `docs/propuestas/maquetas-oferta-pro-y-mazo-
//  centrado-2026-11-25/`: (C) el mes gratis de Pro va DENTRO de la tarjeta «¡Primeros pasos completos!», solo para quien
//  tiene derecho, y los días siguientes la tarjeta de Pro del Panel usa el texto de la maqueta A; (B) mientras se está en
//  el paso 1, el mazo va centrado con «Hola, <nombre>» encima, y el saludo se va al crear la cuenta.
//

import Foundation
import Testing
@testable import Yala

private enum OfertaSource {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // OfertaProMazoCentrado/
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
}

// MARK: - C · El mes gratis en la tarjeta final

@Suite("Oferta Pro · el mes gratis dentro de «¡Primeros pasos completos!»")
struct OfertaProTarjetaFinalTests {

    @Test("con derecho medido y prueba de un mes, se anuncia el mes gratis")
    func announcesWithEligibility() {
        #expect(SetupCompleteTrialOfferLogic.announcesFreeMonth(
            isPro: false, eligibilityKnown: true, offeredTrialDays: 30, trialIsOneMonth: true))
    }

    @Test("sin derecho, sin medir, con Pro o con otra duración, no se anuncia",
          arguments: [
            (false, true, nil as Int?, true),   // ya usó la prueba
            (false, false, 30, true),           // Yala Dev: sin precios no se sabe
            (true, true, 30, true),             // ya es Pro
            (false, true, 7, false),            // una prueba de 7 días no es «1 mes»
          ])
    func doesNotAnnounceWithoutEligibility(isPro: Bool, known: Bool, days: Int?, oneMonth: Bool) {
        #expect(!SetupCompleteTrialOfferLogic.announcesFreeMonth(
            isPro: isPro, eligibilityKnown: known, offeredTrialDays: days, trialIsOneMonth: oneMonth))
    }

    @Test("la tarjeta final lleva la oferta solo con derecho y sin «Ahora no»")
    func cardCarriesOfferOnlyWithEligibility() {
        #expect(SetupCompleteTrialOfferLogic.showsOfferInCard(announcesFreeMonth: true, declined: false))
        #expect(!SetupCompleteTrialOfferLogic.showsOfferInCard(announcesFreeMonth: true, declined: true))
        #expect(!SetupCompleteTrialOfferLogic.showsOfferInCard(announcesFreeMonth: false, declined: false))
    }

    @Test("con la oferta en la tarjeta, la hoja no sube además al completar; sin ella, como hoy")
    func completionSheetYieldsToTheCard() {
        #expect(!SetupCompleteTrialOfferLogic.completionSubmitsSheet(offeredAfterRecordStep: false, offerInCard: true))
        #expect(SetupCompleteTrialOfferLogic.completionSubmitsSheet(offeredAfterRecordStep: false, offerInCard: false))
        // La del paso 2 ya salió: el final no la repite (opción B del 20-nov), con o sin tarjeta.
        #expect(!SetupCompleteTrialOfferLogic.completionSubmitsSheet(offeredAfterRecordStep: true, offerInCard: false))
    }

    @Test("«Empezar mi mes gratis» pide la hoja de Primeros pasos por el router")
    func ctaRequestsTheOfferSheet() throws {
        let code = try OfertaSource.code("Yala/App/Logic/SetupCompleteTrialOfferLogic.swift")
        #expect(code.contains("defaults.set(true, forKey: pendingOfferKey)"))
        #expect(code.contains("RouterEntryGate.shared.submit(.presentTrialOffer)"))
        let card = try OfertaSource.code("Yala/App/Views/Panel/SetupChecklistCard.swift")
        #expect(card.contains("SetupCompleteTrialOfferLogic.requestOfferSheet()"))
        #expect(card.contains("manager.declineCompletedOffer()"))
        #expect(card.contains("manager.dismissCompleted()"))
    }

    @Test("«Ahora no» se recuerda y el reinicio del gestor lo borra")
    func notNowPersistsAndResets() throws {
        let code = try OfertaSource.code("Yala/App/Models/SetupChecklistManager.swift")
        #expect(code.contains("defaults.removeObject(forKey: SetupCompleteTrialOfferLogic.cardOfferDeclinedKey)"))
        #expect(code.contains("isCompletedOfferDeclined = defaults.bool(forKey: SetupCompleteTrialOfferLogic.cardOfferDeclinedKey)"))
    }

    @Test("mientras la tarjeta final lleva la oferta, la tarjeta de Pro del Panel no sale a la vez")
    func panelProBannerYields() throws {
        let code = try OfertaSource.code("Yala/App/Views/Panel/PanelView.swift")
        #expect(code.contains("if finalCardCarriesOffer { flags.proOffer = false }"))
    }

    @Test("los días siguientes, la tarjeta de Pro usa el texto de A con derecho y el de hoy sin él")
    func proBannerUsesTextA() throws {
        let code = try OfertaSource.code("Yala/App/Views/Shared/ProUpgradeBanner.swift")
        #expect(code.contains("SetupCompleteTrialOfferLogic.announcesFreeMonthNow"))
        #expect(code.contains("offersFreeMonth ? L10n.PrimerosPasos23.ProBannerFreeMonth.title : L10n.ProBanner.title"))
        #expect(code.contains("offersFreeMonth ? L10n.PrimerosPasos23.ProBannerFreeMonth.cta : ProPresentation.upgradeButtonTitle"))
    }
}

// MARK: - B · El mazo centrado con saludo

@Suite("Mazo centrado · «Hola, <nombre>» durante el paso 1")
struct MazoCentradoSaludoTests {

    private let placeholders: Set<String> = ["Usuario", "User"]

    @Test("con nombre, el primer nombre")
    func greetsWithName() {
        #expect(PrimerosPasosGreetingLogic.greetingName(stored: "Jürgen Schmidt", placeholders: placeholders) == "Jürgen")
        #expect(PrimerosPasosGreetingLogic.greetingName(stored: "  Ana  ", placeholders: placeholders) == "Ana")
    }

    @Test("sin nombre o con el de relleno, solo «Hola»", arguments: [nil, "", "   ", "Usuario", "usuario", "User"])
    func greetsWithoutName(stored: String?) {
        #expect(PrimerosPasosGreetingLogic.greetingName(stored: stored, placeholders: placeholders) == nil)
    }

    @Test("el título dice el nombre o solo «Hola»; el nombre nunca es fijo")
    func titleUsesTheName() {
        #expect(L10n.PrimerosPasos23.Greeting.title(name: nil) == L10n.PrimerosPasos23.Greeting.hello)
        let withName = L10n.PrimerosPasos23.Greeting.title(name: "Lucía")
        #expect(withName.contains("Lucía"))
        #expect(!withName.contains("Jürgen"))
    }

    @Test("centrado y saludo solo en el paso 1; al crear la cuenta desaparecen")
    func centersOnlyDuringStepOne() {
        #expect(PrimerosPasosGreetingLogic.centersDeck(showsDeck: true, isAllComplete: false, accountStepResolved: false))
        #expect(!PrimerosPasosGreetingLogic.centersDeck(showsDeck: true, isAllComplete: false, accountStepResolved: true))
        #expect(!PrimerosPasosGreetingLogic.centersDeck(showsDeck: true, isAllComplete: true, accountStepResolved: false))
        #expect(!PrimerosPasosGreetingLogic.centersDeck(showsDeck: false, isAllComplete: false, accountStepResolved: false))
    }

    @Test("la regla vale igual en «Solo gastos» y en «Ingresos y gastos»: la puerta del paso 1 es la misma")
    func sameRuleInBothModes() {
        let stepOne = PrimerosPasosPanelGate.make(deckInProgress: true, accountStepResolved: false,
                                                  recordStepResolved: false, planningShown: false)
        let afterAccount = PrimerosPasosPanelGate.make(deckInProgress: true, accountStepResolved: true,
                                                       recordStepResolved: false, planningShown: false)
        #expect(PrimerosPasosGreetingLogic.centersDeck(showsDeck: true, isAllComplete: false,
                                                      accountStepResolved: stepOne.showsAccounts))
        #expect(!PrimerosPasosGreetingLogic.centersDeck(showsDeck: true, isAllComplete: false,
                                                       accountStepResolved: afterAccount.showsAccounts))
    }

    @Test("el desplazamiento centra el bloque en lo visible y nunca es negativo")
    func centeringOffset() {
        // iPhone 14: ~690 pt entre barras, bloque de 300, empieza 24 pt abajo → baja 171.
        #expect(PrimerosPasosGreetingLogic.centeringOffset(visibleHeight: 690, blockHeight: 300, naturalTop: 24) == 171)
        #expect(PrimerosPasosGreetingLogic.centeringOffset(visibleHeight: 400, blockHeight: 600, naturalTop: 24) == 0)
        #expect(PrimerosPasosGreetingLogic.centeringOffset(visibleHeight: 0, blockHeight: 300, naturalTop: 24) == 0)
    }

    @Test("el Panel enseña el saludo y centra solo con `centersSetupDeck`, y lo anima al cambiar")
    func panelWiring() throws {
        let code = try OfertaSource.code("Yala/App/Views/Panel/PanelView.swift")
        #expect(code.contains("if centersSetupDeck {"))
        #expect(code.contains(".padding(.top, setupDeckCenteringOffset)"))
        #expect(code.contains(".animation(reduceMotion ? nil : DS.Animation.appear, value: centersSetupDeck)"))
        #expect(code.contains("stored: appPreferences.userName"))
    }
}

// MARK: - Los textos, en los 16 idiomas

@Suite("Oferta Pro y mazo centrado · textos")
struct OfertaProMazoCentradoTextosTests {

    private static let locales = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl",
                                  "pt", "pt-BR", "pt-PT", "zh-Hans"]

    private static let keys = [
        "pasos23.final.cardOffer.chip", "pasos23.final.cardOffer.title", "pasos23.final.cardOffer.voice.title",
        "pasos23.final.cardOffer.ai.title", "pasos23.final.cardOffer.unlimited.title",
        "pasos23.final.cardOffer.cta", "pasos23.final.cardOffer.footnote", "pasos23.final.cardOffer.notNow",
        "proBanner.freeMonth.chip", "proBanner.freeMonth.title", "proBanner.freeMonth.subtitle", "proBanner.freeMonth.cta",
        "pasos23.greeting.hello", "pasos23.greeting.helloName", "pasos23.greeting.subtitle",
    ]

    private static func table(_ locale: String) throws -> [String: String] {
        let url = OfertaSource.repoRoot.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale) sin tabla")
    }

    @Test("cada idioma tiene todas las claves, no vacías y con el mismo formato", arguments: locales)
    func everyLocaleHasTheKeys(locale: String) throws {
        let table = try Self.table(locale)
        for key in Self.keys {
            let value = try #require(table[key], "\(locale): falta \(key)")
            #expect(!value.isEmpty, "\(locale): \(key) vacía")
            #expect(value.components(separatedBy: "%@").count == (key.hasSuffix("helloName") ? 2 : 1),
                    "\(locale): \(key) con otro formato")
        }
    }

    @Test("el español neutro dice lo de las maquetas")
    func neutralSpanishMatchesTheMockups() throws {
        for locale in ["es", "es-419"] {
            let table = try Self.table(locale)
            #expect(table["pasos23.final.cardOffer.title"] == "Para seguir: prueba Yala Pro 1 mes gratis")
            #expect(table["pasos23.final.cardOffer.cta"] == "Empezar mi mes gratis")
            #expect(table["pasos23.final.cardOffer.footnote"] == "Hoy no pagas · te avisamos antes de cobrar")
            #expect(table["proBanner.freeMonth.title"] == "Prueba Yala Pro gratis 1 mes")
            #expect(table["proBanner.freeMonth.cta"] == "Empezar mes gratis")
            #expect(table["pasos23.greeting.helloName"] == "Hola, %@")
            #expect(table["pasos23.greeting.subtitle"] == "Siete pasos cortos para dejar Yala a tu medida.")
        }
    }
}
