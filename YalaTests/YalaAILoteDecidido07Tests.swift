//
//  YalaAILoteDecidido07Tests.swift
//  YalaTests
//
//  UX 2.2 · lote decidido 07 (Yala IA), lo que se prueba sin store:
//  - L14-1: «Yala IA» (el `chat.assistantName` de cada idioma) en todas las cadenas que nombraban la función de otra
//    forma, en los 16 idiomas.
//  - L14-6: los Temas por áreas (`ChatTopicAreasLogic`).
//  L14-7 y L14-9 (con store) van en `YalaAILoteDecidido07ChatTests`.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct YalaAILoteDecidido07Tests {

    // MARK: - L14-1 · un solo nombre

    /// Cadenas cuyo valor ES el nombre de la función.
    private static let nameKeys = [
        "featureGate.chatAssistant", "aiConsent.chatTitle", "aiPrivacy.chatRow", "widget.chatFab.toggle",
        "tipkit.pro.chatFab.title", "subscription.feature.aiAssistant",
    ]

    /// Cadenas que nombran la función dentro de una frase. Los textos del permiso (`aiConsent.chatMessage`,
    /// `aiConsent.cloudExploreMessage`) no están: son los del anexo legal de `docs/ai-cloud-vs-private-2026-10.md` y
    /// no se tocan sin cambiar ese documento (`YalaIACloudExploreConsentTests`). Su título sí dice «Yala IA».
    private static let sentenceKeys = [
        "chat.errorOffline", "tipkit.pro.quickAI.message",
        "welcome.hero.cards.assistant.title", "aiSettings.title", "aiSettings.appliesHint", "widget.chatFab.hint",
        "aiPrivacy.l14d.cloudExploreLine",
    ]

    @Test func everyLocale_namesTheFeatureYalaIA() throws {
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            let name = try #require(strings["chat.assistantName"], "\(locale.code) sin chat.assistantName")
            for key in Self.nameKeys {
                #expect(strings[key] == name, "\(locale.code) \(key): \(strings[key] ?? "nil")")
            }
            for key in Self.sentenceKeys {
                let value = strings[key] ?? ""
                #expect(value.contains(name), "\(locale.code) \(key): \(value)")
            }
        }
    }

    /// Los nombres viejos ya no salen en ninguna de esas cadenas (en español, donde la auditoría los midió).
    @Test func spanish_dropsTheOldNames() {
        let old = ["Asistente", "asistente", "Pregúntale a Yala", "Preguntale a Yala", "Toca IA", "Tocá IA"]
        for code in ["es", "es-419", "es-AR", "es-ES"] {
            let strings = StringsFileParser.parseStrings(forLocale: code)
            for key in Self.nameKeys + Self.sentenceKeys + ["aiPrivacy.footerHint", "aiPrivacy.processingRow"] {
                let value = strings[key] ?? ""
                #expect(!old.contains { value.contains($0) }, "\(code) \(key): \(value)")
            }
        }
    }

    /// El VoiceOver del botón flotante leía `chat.title` («Pregúntale a Yala»); se retiró para que nadie vuelva a
    /// apuntarlo a un segundo nombre.
    @Test func chatTitleKey_isGoneEverywhere() {
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            #expect(strings["chat.title"] == nil, "\(locale.code)")
        }
    }

    // MARK: - L14-6 · Temas por áreas

    @Test func areas_followTheDecidedOrder_whenTheUserHasEverything() {
        let areas = ChatTopicAreasLogic.areas(for: ChatTopicAreasInput(
            topExpenseCategories: ["Comida", "Transporte"],
            frequentExpenseSubcategories: ["Supermercado", "Taxis y apps", "Cine"],
            activeBudgets: ["Mercado", "Ocio"],
            activeScheduledPayments: ["Netflix"]
        ))
        #expect(areas.map(\.area) == [.spending, .budgets, .payments, .log])
        #expect(areas.allSatisfy { (2...3).contains($0.examples.count) })
    }

    @Test func examples_comeFromTheUsersOwnNames() throws {
        let areas = ChatTopicAreasLogic.areas(for: ChatTopicAreasInput(
            topExpenseCategories: ["Comida"],
            frequentExpenseSubcategories: ["Supermercado", "Taxis y apps"],
            activeBudgets: ["Mercado"],
            activeScheduledPayments: ["Netflix"]
        ))
        let byArea = Dictionary(uniqueKeysWithValues: areas.map { ($0.area, $0.examples.map(\.text)) })
        #expect(byArea[.spending]?.contains(L10n.UXL14D.spendingCategory("Comida")) == true)
        #expect(byArea[.budgets] == [L10n.UXL14D.budgetLeft("Mercado"), L10n.UXL14D.budgetOnTrack("Mercado")])
        #expect(byArea[.payments]?.contains(L10n.UXL14D.paymentWhen("Netflix")) == true)
        #expect(byArea[.log] == [L10n.UXL14D.logExample("Supermercado"), L10n.UXL14D.logExample("Taxis y apps")])
    }

    /// Con dos presupuestos la segunda pregunta compara; con uno, pregunta por ese.
    @Test func budgets_secondQuestionDependsOnHowManyThereAre() {
        let two = ChatTopicAreasLogic.areas(for: ChatTopicAreasInput(activeBudgets: ["A", "B"]))
        #expect(two.first { $0.area == .budgets }?.examples.last?.text == L10n.UXL14D.budgetWorst)
        let one = ChatTopicAreasLogic.areas(for: ChatTopicAreasInput(activeBudgets: ["A"]))
        #expect(one.first { $0.area == .budgets }?.examples.last?.text == L10n.UXL14D.budgetOnTrack("A"))
    }

    /// Sin presupuestos ni pagos planificados esas áreas no salen: preguntar por algo que no existe no lleva a nada.
    /// Gastos y Apuntar salen siempre, también con el store vacío.
    @Test func emptyStore_offersSpendingAndLogOnly() {
        let areas = ChatTopicAreasLogic.areas(for: ChatTopicAreasInput())
        #expect(areas.map(\.area) == [.spending, .log])
        #expect(areas[0].examples.map(\.text) == [L10n.UXL14D.spendingTop, L10n.UXL14D.spendingVsLastMonth])
        #expect(areas[1].examples.map(\.text) == [L10n.UXL14D.logExampleDefault])
    }

    /// Apuntar no se envía: se escribe en la caja. Las demás se envían.
    @Test func onlyLogExamples_stayInTheBox() {
        let areas = ChatTopicAreasLogic.areas(for: ChatTopicAreasInput(
            frequentExpenseSubcategories: ["Cine"], activeBudgets: ["A"], activeScheduledPayments: ["P"]
        ))
        for content in areas {
            #expect(content.examples.allSatisfy { $0.sends == (content.area != .log) }, "\(content.area)")
        }
        // Una sola subcategoría: su ejemplo y el de siempre.
        #expect(areas.last?.examples.map(\.text) == [L10n.UXL14D.logExample("Cine"), L10n.UXL14D.logExampleDefault])
    }

    @Test func ranked_ordersByAmount_thenByName_andDropsEmpty() {
        let ranked = ChatTopicAreasLogic.ranked(["B": 10, "A": 10, "C": 30, "": 50, "Cero": 0])
        #expect(ranked == ["C", "A", "B"])
    }
}

/// L14-12: un Pro puede ocultar el botón de Yala IA, y el arranque no se lo vuelve a encender.
struct ChatButtonVisibilityOnProTests {
    @Test func aRelaunchOfAProUser_doesNotShowTheButtonAgain() {
        // En cada lanzamiento el valor en memoria arranca en `false`; lo persistido dice que ya era Pro.
        #expect(!StoreKitManager.forcesChatButtonVisible(nowPro: true, wasProInMemory: false, wasProPersisted: true))
    }

    @Test func buyingPro_showsTheButton() {
        #expect(StoreKitManager.forcesChatButtonVisible(nowPro: true, wasProInMemory: false, wasProPersisted: false))
    }

    @Test func stayingProOrStayingFree_changesNothing() {
        #expect(!StoreKitManager.forcesChatButtonVisible(nowPro: true, wasProInMemory: true, wasProPersisted: true))
        #expect(!StoreKitManager.forcesChatButtonVisible(nowPro: false, wasProInMemory: false, wasProPersisted: false))
    }
}
