//
//  YalaIACloudExploreConsentTests.swift
//  YalaTests
//
//  El texto N1 de Yala IA con la cuenta en la nube (decisión 1A de Jürgen, 2026-10-18):
//
//  1. Sale una sola vez, antes de la primera pregunta, y solo con el camino ampliado disponible.
//  2. La respuesta se guarda en el teléfono con un formato que no cambia (`accepted` / `declined`).
//  3. En el chat, la pregunta espera a N1; «Política de privacidad» no es una respuesta y le devuelve el texto a la caja.
//  4. El texto de N1 y el del aviso privado (P1) son los del documento, palabra por palabra, en los 16 idiomas.
//
//  Que sin N1 aceptado la pregunta sale por el camino de siempre lo fija `YalaIAChatRoutingTests`.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@MainActor
@Suite(.serialized)
struct YalaIACloudExploreConsentTests {

    // MARK: - Cuándo sale N1

    @Test("tabla: N1 sale solo con el camino disponible y sin respuesta", arguments: [
        (false, YalaIACloudExploreConsent?.none, false),
        (false, .accepted, false),
        (false, .declined, false),
        (true, nil, true),
        (true, .accepted, false),
        (true, .declined, false),
    ])
    func promptTable(available: Bool, consent: YalaIACloudExploreConsent?, prompts: Bool) {
        #expect(YalaIAChatRouteLogic.needsCloudExploreConsentPrompt(available: available, consent: consent) == prompts)
    }

    @Test("el camino existe solo en la nube con el flag encendido", arguments: [
        (StorageMode.icloud, false, false), (.icloud, true, false), (.cloud, false, false), (.cloud, true, true),
    ])
    func availabilityTable(mode: StorageMode, flagOn: Bool, available: Bool) {
        #expect(YalaIAChatRouteLogic.cloudExploreAvailable(storageMode: mode, flagOn: flagOn) == available)
    }

    // MARK: - Dónde se guarda

    @Test("la respuesta se guarda con su formato y se puede borrar")
    func storeRoundTrip() throws {
        let defaults = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        #expect(YalaIACloudExploreConsentStore.read(defaults) == nil)
        YalaIACloudExploreConsentStore.write(.accepted, defaults)
        #expect(defaults.string(forKey: "aiCloudExploreConsent") == "accepted")
        #expect(YalaIACloudExploreConsentStore.read(defaults) == .accepted)
        YalaIACloudExploreConsentStore.write(.declined, defaults)
        #expect(defaults.string(forKey: "aiCloudExploreConsent") == "declined")
        YalaIACloudExploreConsentStore.write(nil, defaults)
        #expect(defaults.object(forKey: "aiCloudExploreConsent") == nil)
    }

    @Test("un valor que no se entiende cuenta como «sin preguntar», nunca como aceptado")
    func unknownValueIsNotAccepted() throws {
        let defaults = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        defaults.set("yes", forKey: AppPreferences.Keys.aiCloudExploreConsent)
        #expect(YalaIACloudExploreConsentStore.read(defaults) == nil)
    }

    @Test("AppPreferences lee y escribe la misma key que la ruta")
    func appPreferencesSharesTheKey() throws {
        let defaults = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        defaults.set("accepted", forKey: AppPreferences.Keys.aiCloudExploreConsent)
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.aiCloudExploreConsent == .accepted)
        prefs.aiCloudExploreConsent = .declined
        #expect(YalaIACloudExploreConsentStore.read(defaults) == .declined)
    }

    // MARK: - En el chat

    private func makeChat(available: Bool) throws -> (ChatAssistantViewModel, UserDefaults) {
        let defaults = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        let vm = ChatAssistantViewModel(defaults: defaults, cloudExploreAvailable: { available })
        vm.setContext(try makeTestContext(), autoLoadSuggestions: false)
        return (vm, defaults)
    }

    @Test("nube sin respuesta: la pregunta espera a N1 y no sale todavía")
    func firstQuestionWaitsForN1() async throws {
        let (vm, defaults) = try makeChat(available: true)
        vm.inputText = "¿Cuánto gasté en Uber en marzo?"
        await vm.sendQuestion(vm.inputText)
        #expect(vm.showsCloudExploreConsent)
        #expect(vm.messages.isEmpty, "La pregunta no puede salir antes de contestar N1.")
        #expect(!vm.isLoading)
        #expect(vm.inputText.isEmpty)
        #expect(YalaIACloudExploreConsentStore.read(defaults) == nil)
    }

    @Test("«Política de privacidad» no contesta: no se apunta nada, el texto vuelve a la caja y N1 sale otra vez")
    func privacyPolicyIsNotAnAnswer() async throws {
        let (vm, defaults) = try makeChat(available: true)
        await vm.sendQuestion("¿Cuándo pagué la matrícula?")
        vm.showsCloudExploreConsent = false  // lo hace el alert al tocar el botón
        vm.postponeCloudExploreConsent()
        #expect(vm.inputText == "¿Cuándo pagué la matrícula?")
        #expect(YalaIACloudExploreConsentStore.read(defaults) == nil)
        #expect(vm.messages.isEmpty)

        await vm.sendQuestion(vm.inputText)
        #expect(vm.showsCloudExploreConsent, "Sin respuesta, N1 vuelve a salir.")
        #expect(vm.messages.isEmpty)
    }

    @Test("con una respuesta guardada N1 no vuelve a salir", arguments: [YalaIACloudExploreConsent.accepted, .declined])
    func answeredN1DoesNotShowAgain(consent: YalaIACloudExploreConsent) throws {
        let defaults = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        YalaIACloudExploreConsentStore.write(consent, defaults)
        #expect(!YalaIAChatRouteLogic.needsCloudExploreConsentPrompt(
            available: true, consent: YalaIACloudExploreConsentStore.read(defaults)
        ))
    }

    /// Aceptar y rechazar guardan su respuesta ANTES de enviar: lo fija el cuerpo, porque enviar llama a la red.
    @Test("aceptar y rechazar guardan la respuesta y después envían la pregunta que esperaba")
    func answersAreStoredBeforeSending() throws {
        let source = try String(contentsOf: repoURL("Yala/App/ViewModels/ChatAssistantViewModel.swift"), encoding: .utf8)
        #expect(source.contains(
            "    func acceptCloudExploreConsent() async {\n"
                + "        YalaIACloudExploreConsentStore.write(.accepted, defaults)\n"
                + "        await sendQuestionAwaitingCloudExploreConsent()\n    }"
        ))
        #expect(source.contains(
            "    func declineCloudExploreConsent() async {\n"
                + "        YalaIACloudExploreConsentStore.write(.declined, defaults)\n"
                + "        await sendQuestionAwaitingCloudExploreConsent()\n    }"
        ))
    }

    @Test("el chat presenta N1 y el tema elegido sale al cerrarse la hoja de Temas")
    func chatSheetWiring() throws {
        let source = try String(contentsOf: repoURL("Yala/App/Views/Chat/ChatSheetView.swift"), encoding: .utf8)
        #expect(source.contains(".cloudExploreConsentAlert(\n            isPresented: $viewModel.showsCloudExploreConsent,"))
        #expect(source.contains("onAccept: { Task { await viewModel.acceptCloudExploreConsent() } },"))
        #expect(source.contains("onDecline: { Task { await viewModel.declineCloudExploreConsent() } },"))
        #expect(source.contains("onPrivacyPolicy: { viewModel.postponeCloudExploreConsent() }"))
        #expect(source.contains(".sheet(isPresented: $showTopicsSheet, onDismiss: sendTopicAwaitingSheetDismissal)"))
        #expect(source.contains("onSelect: { suggestion in topicAwaitingSheetDismissal = suggestion }"))
    }

    // MARK: - Los textos

    private static let languages = [
        "es", "es-419", "es-AR", "es-ES", "en", "en-GB", "de", "fr", "it", "nl", "pl", "pt", "pt-BR", "pt-PT", "ja", "zh-Hans",
    ]

    /// Las tablas del anexo de `docs/ai-cloud-vs-private-2026-10.md`, por idioma.
    private func annexTable(_ heading: String) throws -> [String: String] {
        let doc = try String(contentsOf: repoURL("docs/ai-cloud-vs-private-2026-10.md"), encoding: .utf8)
        let start = try #require(doc.range(of: heading))
        var rows: [String: String] = [:]
        for line in doc[start.upperBound...].split(separator: "\n").dropFirst() {
            if line.hasPrefix("### ") { break }
            let cells = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count == 4, cells[1] != "Idioma", !cells[1].hasPrefix("---") else { continue }
            for lang in cells[1].split(separator: ",") { rows[lang.trimmingCharacters(in: .whitespaces)] = cells[2] }
        }
        return rows
    }

    private func value(_ key: String, in lang: String) throws -> String {
        let content = try String(contentsOf: repoURL("Yala/Resources/\(lang).lproj/Localizable.strings"), encoding: .utf8)
        let prefix = "\"\(key)\" = \""
        let line = try #require(content.split(separator: "\n").first { $0.hasPrefix(prefix) }, "\(lang): falta \(key)")
        return String(line.dropFirst(prefix.count).dropLast(2)).replacingOccurrences(of: "\\\"", with: "\"")
    }

    @Test("P1 y N1 son los del documento, en los 16 idiomas")
    func annexTextsAreTheOnesInTheApp() throws {
        let p1 = try annexTable("### P1")
        let n1 = try annexTable("### N1")
        #expect(p1.count == 16 && n1.count == 16, "El anexo debe traer los 16 idiomas.")
        for lang in Self.languages {
            #expect(try value("aiConsent.chatMessage", in: lang) == p1[lang], "\(lang): el aviso privado no es P1.")
            #expect(try value("aiConsent.cloudExploreMessage", in: lang) == n1[lang], "\(lang): N1 no es el del documento.")
            #expect(!(try value("aiConsent.cloudExploreTitle", in: lang)).isEmpty)
            #expect(!(try value("aiPrivacy.cloudExploreRow", in: lang)).isEmpty)
        }
    }

    private func repoURL(_ relative: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(relative)
    }
}
