//
//  AppLanguageSyncTests.swift
//  YalaTests
//
//  Tests para LanguageManager: storage en App Group, migración desde standard,
//  notificación .languageDidChange.
//

import Foundation
import Testing

@testable import Yala

// `.serialized`: los tests `async` mutan el singleton global `LanguageManager.overrideLanguage`
// y esperan `.languageDidChange`; el setter NO postea si el valor no cambia
// (`guard newValue != current`) → en paralelo, un test deja "fr" y otro no recibe notif.
@Suite(.serialized)
@MainActor
struct AppLanguageSyncTests {

    // MARK: - Helpers

    private static let testSuiteName = "test.yala.languageManager"

    private func makeCleanSuite() -> UserDefaults {
        let suite = UserDefaults(suiteName: Self.testSuiteName)!
        suite.removePersistentDomain(forName: Self.testSuiteName)
        return suite
    }

    private func cleanStandard() {
        UserDefaults.standard.removeObject(forKey: LanguageManager.overrideKey)
    }

    // MARK: - storage roundtrip

    @Test func setOverride_writesToSharedDefaults_andReadsBack() {
        cleanStandard()
        // El sharedDefaults real (App Group) — los tests escriben/leen ahí.
        // Limpieza al final.
        let original = LanguageManager.overrideLanguage
        defer {
            LanguageManager.overrideLanguage = original
        }

        LanguageManager.overrideLanguage = "es"
        #expect(LanguageManager.overrideLanguage == "es")

        LanguageManager.overrideLanguage = nil
        #expect(LanguageManager.overrideLanguage == nil)
    }

    @Test func setOverride_postsLanguageDidChange() async {
        let original = LanguageManager.overrideLanguage
        defer { LanguageManager.overrideLanguage = original }

        let expectation = NotificationExpectation(name: .languageDidChange)
        LanguageManager.overrideLanguage = "fr"
        let received = await expectation.waitForNotification(timeout: 1.0)
        #expect(received)
    }

    @Test func setOverride_nilAlsoPostsLanguageDidChange() async {
        let original = LanguageManager.overrideLanguage
        defer { LanguageManager.overrideLanguage = original }

        LanguageManager.overrideLanguage = "fr"
        // Drain notif del set previo
        try? await Task.sleep(for: .milliseconds(50))

        let expectation = NotificationExpectation(name: .languageDidChange)
        LanguageManager.overrideLanguage = nil
        let received = await expectation.waitForNotification(timeout: 1.0)
        #expect(received)
    }

    // MARK: - migration

    @Test func bootstrapMigration_emptyStandardAndSuite_setsSentinel() {
        cleanStandard()
        // Limpieza del sentinel para forzar migración
        let suite = LanguageManager.sharedDefaults
        suite.removeObject(forKey: "appLanguageOverrideMigratedV1")
        suite.removeObject(forKey: LanguageManager.overrideKey)

        LanguageManager.bootstrapMigrationIfNeeded()

        #expect(suite.bool(forKey: "appLanguageOverrideMigratedV1") == true)
        #expect(suite.string(forKey: LanguageManager.overrideKey) == nil)
    }

    @Test func bootstrapMigration_legacyValueInStandard_movesToSuite() {
        let suite = LanguageManager.sharedDefaults
        suite.removeObject(forKey: "appLanguageOverrideMigratedV1")
        suite.removeObject(forKey: LanguageManager.overrideKey)
        // Usar "fr" (no se remappea — es código canónico ya).
        UserDefaults.standard.set("fr", forKey: LanguageManager.overrideKey)

        LanguageManager.bootstrapMigrationIfNeeded()

        #expect(suite.string(forKey: LanguageManager.overrideKey) == "fr")
        #expect(UserDefaults.standard.string(forKey: LanguageManager.overrideKey) == nil)
        #expect(suite.bool(forKey: "appLanguageOverrideMigratedV1") == true)
    }

    @Test func bootstrapMigration_legacyPt_isRemappedToPtBR() {
        let suite = LanguageManager.sharedDefaults
        suite.removeObject(forKey: "appLanguageOverrideMigratedV1")
        suite.removeObject(forKey: LanguageManager.overrideKey)
        UserDefaults.standard.set("pt", forKey: LanguageManager.overrideKey)

        LanguageManager.bootstrapMigrationIfNeeded()

        // Step 1 copia "pt" → suite. Step 2 lo remappea a "pt-BR".
        #expect(suite.string(forKey: LanguageManager.overrideKey) == "pt-BR")
        #expect(UserDefaults.standard.string(forKey: LanguageManager.overrideKey) == nil)
    }

    @Test func bootstrapMigration_aliasRemap_idempotent() {
        // Si el remap ya se aplicó (sentinel set + valor canónico), correr de nuevo
        // no cambia nada.
        let suite = LanguageManager.sharedDefaults
        suite.set(true, forKey: "appLanguageOverrideMigratedV1")
        suite.set("pt-BR", forKey: LanguageManager.overrideKey)

        LanguageManager.bootstrapMigrationIfNeeded()

        #expect(suite.string(forKey: LanguageManager.overrideKey) == "pt-BR")
    }

    @Test func bootstrapMigration_alreadyMigrated_skipsStandardCopy() {
        // Usa un valor canónico (no alias) para verificar específicamente Step 1
        // del bootstrap. El alias remap (Step 2) es idempotente y siempre corre
        // — su comportamiento se cubre en bootstrapMigration_aliasRemap_idempotent.
        let suite = LanguageManager.sharedDefaults
        suite.set(true, forKey: "appLanguageOverrideMigratedV1")
        suite.set("de", forKey: LanguageManager.overrideKey)
        UserDefaults.standard.set("legacy_value_should_be_ignored", forKey: LanguageManager.overrideKey)

        LanguageManager.bootstrapMigrationIfNeeded()

        // Suite intacto (de no es alias remappeable)
        #expect(suite.string(forKey: LanguageManager.overrideKey) == "de")
        // Standard NO se borró porque la migración Step 1 ya había corrido
        #expect(UserDefaults.standard.string(forKey: LanguageManager.overrideKey) == "legacy_value_should_be_ignored")

        UserDefaults.standard.removeObject(forKey: LanguageManager.overrideKey)
    }

    // MARK: - notification name

    @Test func notificationName_languageDidChange_isStable() {
        #expect(Notification.Name.languageDidChange.rawValue == "LanguageDidChange")
    }
}

// MARK: - Test helpers

@MainActor
private final class NotificationExpectation: @unchecked Sendable {
    private var fulfilled = false
    private var observer: NSObjectProtocol?

    init(name: Notification.Name) {
        observer = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fulfilled = true
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func waitForNotification(timeout: TimeInterval) async -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if fulfilled { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return fulfilled
    }
}
