//
//  WelcomeUnfinishedAccountEntryTests.swift
//  YalaTests
//
//  Card 7e60 (decisión de Jürgen, 2026-11-06): quien elige entrar en una cuenta en el Welcome y ve Yala cerrarse antes de
//  terminar, al reabrir vuelve a «¿Qué quieres hacer?», no al Paso 1 del alta privada. La decisión, la tabla; el cableado
//  de `ContentView` (que no se puede conducir hasta el arranque en un test), leer el fuente.
//

import Foundation
import Testing

@testable import Yala

@Suite("Reabrir con la entrada en una cuenta a medias")
struct WelcomeUnfinishedAccountEntryTests {

    // MARK: - La decisión

    @Test("Chooser visto y entrada a medias: vuelve al chooser")
    func unfinishedEntry_reopensAtChooser() {
        #expect(WelcomeUnfinishedAccountEntry.reopensAtChooser(hasShownWelcomeChooser: true, accountEntryUnfinished: true))
    }

    @Test("Chooser visto sin entrada a medias (eligió el alta privada): sigue al Paso 1")
    func privateChoice_staysInOnboarding() {
        #expect(!WelcomeUnfinishedAccountEntry.reopensAtChooser(hasShownWelcomeChooser: true, accountEntryUnfinished: false))
    }

    @Test("Sin chooser visto la marca no decide nada (el arranque va a la portada)")
    func chooserNotShown_markIsIgnored() {
        #expect(!WelcomeUnfinishedAccountEntry.reopensAtChooser(hasShownWelcomeChooser: false, accountEntryUnfinished: true))
    }

    // MARK: - El store

    @Test("La marca se pone y se quita")
    func store_marksAndClears() throws {
        let defaults = try #require(testDefaults(suiteName: "test.\(UUID().uuidString)"))
        #expect(!WelcomeUnfinishedAccountEntry.isMarked(defaults))
        WelcomeUnfinishedAccountEntry.mark(defaults)
        #expect(WelcomeUnfinishedAccountEntry.isMarked(defaults))
        WelcomeUnfinishedAccountEntry.clear(defaults)
        #expect(!WelcomeUnfinishedAccountEntry.isMarked(defaults))
    }

    // MARK: - El cableado (source-scan)

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func codeLines(_ path: String) throws -> [String] {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    @Test("Cada camino de cuenta del Welcome marca la entrada, pegada a la marca del chooser")
    func everyAccountPath_marksTheEntry() throws {
        let lines = try Self.codeLines("Yala/App/ContentView.swift")
        let marks = lines.indices.filter { lines[$0] == "WelcomeUnfinishedAccountEntry.mark()" }
        // Restaurar (nivel 1), «Ya tengo cuenta» (Google, Apple, iCloud), cuenta en la nube nueva, el faro y el acceso
        // único de la vitrina (bienvenida 2.3).
        #expect(marks.count == 5)
        for mark in marks {
            #expect(lines[mark - 1] == "hasShownWelcomeChooser = true")
        }
    }

    @Test("El alta privada quita la marca nada más empezar")
    func privateOnboarding_clearsTheMark() throws {
        let lines = try Self.codeLines("Yala/App/ContentView.swift")
        let start = try #require(lines.firstIndex(of: "private func startFreshPrivateOnboarding() {"))
        #expect(lines[start + 1] == "WelcomeUnfinishedAccountEntry.clear()")
    }

    @Test("Terminar el onboarding quita la marca")
    func completedOnboarding_clearsTheMark() throws {
        let lines = try Self.codeLines("Yala/App/ContentView.swift")
        let onChange = try #require(lines.firstIndex(of: ".onChange(of: hasCompletedOnboarding) { _, newValue in"))
        #expect(lines[onChange + 1] == "if newValue { WelcomeUnfinishedAccountEntry.clear() }")
    }

    @Test("El arranque consulta la marca entre la portada y el alta privada")
    func routing_checksTheMarkBeforeOnboarding() throws {
        let lines = try Self.codeLines("Yala/App/ContentView.swift")
        let branch = try #require(lines.firstIndex(of: "} else if WelcomeUnfinishedAccountEntry.reopensAtChooser("))
        #expect(lines[branch - 1] == "showWelcomeFlow = true")
        #expect(lines[branch - 2] == "welcomeFlowInitialStep = .hero")
        #expect(lines[branch + 2] == "accountEntryUnfinished: WelcomeUnfinishedAccountEntry.isMarked()) {")
        #expect(lines[branch + 3] == "welcomeFlowInitialStep = .chooser")
        #expect(lines[branch + 4] == "showWelcomeFlow = true")
        #expect(lines[branch + 5] == "} else {")
        #expect(lines[branch + 6] == "showOnboarding = true")
    }

    @Test("El borrado quita la marca junto a la del chooser")
    func wipe_clearsTheMark() throws {
        let src = try String(contentsOf: Self.root.appendingPathComponent("Yala/Utils/DataWipeService.swift"), encoding: .utf8)
        #expect(src.contains("defaults.removeObject(forKey: WelcomeUnfinishedAccountEntry.key)"))
    }
}
