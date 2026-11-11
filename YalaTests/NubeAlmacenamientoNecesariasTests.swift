//
//  NubeAlmacenamientoNecesariasTests.swift
//  YalaTests
//
//  Revisión por vistas 2.3, zona 41 («Dónde viven tus datos»), lote 11 de las mejoras necesarias. Cuatro de los cinco
//  puntos se fijan aquí; el del texto grande lo fija `NubeAlmacenamientoNecesariasUITests`.
//
//  - Punto 2: el consentimiento manda a la fila que existe («Exportar registros»), no a «Exportar datos».
//  - Punto 3: «Salir de mis grupos» no enseña palabras internas («Salidos», «Transferidos», «Sin procesar») y su
//    «puedes retomarlo» nombra el botón y la pantalla donde se usó, no «Vaciar datos».
//  - Punto 4: las cifras de la pantalla salen con un solo formato, el del idioma de la app (`AppLocale`), y no con el
//    de la región de formato ni sin agrupar.
//  - Punto 5: en la tarjeta de activar, ningún texto se pinta en `warningForeground` (en el tema claro no llega a AA).
//
//  Los textos se leen de los `.strings` FUENTE de los 16 idiomas (`#filePath`, como `LocalizationParityTests`): el
//  catálogo del bundle del host solo enseña uno.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite(.serialized, .appLanguageStateIsolated)
struct NubeAlmacenamientoNecesariasTests {

    // MARK: - Lectura de los catálogos

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // YalaTests/
        .deletingLastPathComponent()  // raíz del repo

    /// `idioma → (clave → valor)` de los 16 `Localizable.strings` de la app.
    private static func catalogs() throws -> [String: [String: String]] {
        let root = repoRoot.appendingPathComponent("Yala/Resources")
        let lprojs = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "lproj" }
        var result: [String: [String: String]] = [:]
        for lproj in lprojs {
            let url = lproj.appendingPathComponent("Localizable.strings")
            guard let dictionary = NSDictionary(contentsOf: url) as? [String: String] else { continue }
            result[lproj.deletingPathExtension().lastPathComponent] = dictionary
        }
        return result
    }

    @Test("los 16 catálogos se leen")
    func catalogsAreRead() throws {
        #expect(try Self.catalogs().count == 16)
    }

    // MARK: - Punto 2

    @Test("el consentimiento nombra la fila de exportar que existe, en los 16 idiomas")
    func consentNamesTheExportRow() throws {
        for (language, strings) in try Self.catalogs() {
            let point = try #require(strings["storage.consent.pointAccess"], "\(language): sin storage.consent.pointAccess")
            let row = try #require(strings["l20d.settings.exportRecords"], "\(language): sin l20d.settings.exportRecords")
            #expect(point.contains(row), "\(language): «\(point)» no nombra la fila «\(row)»")
        }
    }

    // MARK: - Punto 3

    /// La palabra «grupos» de cada idioma, en minúscula: las cifras del resultado dicen de qué son.
    private static let groupsWord: [String: String] = [
        "de": "gruppen", "en": "groups", "en-GB": "groups", "es": "grupos", "es-419": "grupos", "es-AR": "grupos",
        "es-ES": "grupos", "fr": "groupes", "it": "gruppi", "ja": "グループ", "nl": "groepen", "pl": "grup",
        "pt": "grupos", "pt-BR": "grupos", "pt-PT": "grupos", "zh-Hans": "群组",
    ]

    @Test("las cifras de «Salir de mis grupos» dicen de qué son, en los 16 idiomas")
    func batchLeaveStatsSayWhatTheyCount() throws {
        let keys = ["settings.batchLeaveStatLeft", "settings.batchLeaveStatTransferred", "settings.batchLeaveStatSkipped"]
        for (language, strings) in try Self.catalogs() {
            let word = try #require(Self.groupsWord[language], "\(language): falta en la tabla del test")
            for key in keys {
                let value = try #require(strings[key], "\(language): sin \(key)")
                #expect(value.lowercased().contains(word), "\(language) · \(key): «\(value)» no dice que cuenta grupos")
            }
        }
    }

    @Test("«puedes retomarlo» manda al botón y a la pantalla donde se usó, no a «Vaciar datos»")
    func batchLeaveResumeNamesWhereItWasUsed() throws {
        for (language, strings) in try Self.catalogs() {
            let body = try #require(strings["settings.batchLeaveStoppedBody"], "\(language): sin batchLeaveStoppedBody")
            let button = try #require(strings["l20d.groups.leaveAll.button"], "\(language): sin leaveAll.button")
            let screen = try #require(strings["groups.globalSettings.title"], "\(language): sin globalSettings.title")
            let reset = try #require(strings["settings.wipeData"], "\(language): sin settings.wipeData")
            #expect(body.contains(button), "\(language): «\(body)» no nombra «\(button)»")
            #expect(body.contains(screen), "\(language): «\(body)» no nombra «\(screen)»")
            #expect(!body.contains(reset), "\(language): «\(body)» sigue mandando a «\(reset)»")
        }
    }

    // MARK: - Punto 4

    /// Un idioma de la app cuyo formato de número no es el de la región del host: «de» agrupa con punto («5.006») y el
    /// host del simulador y del CI formatea con coma («5,006»). Si el host ya está en alemán, japonés (coma, otro idioma).
    private static var appLanguageUnlikeRegion: String {
        Locale.current.language.languageCode?.identifier == "de" ? "ja" : "de"
    }

    @Test("las cifras de «Dónde viven tus datos» usan el formato del idioma de la app, no el de la región")
    func storageCountsUseTheAppLanguage() {
        LanguageManager.overrideLanguage = Self.appLanguageUnlikeRegion
        let expected = 5006.formatted(.number.locale(AppLocale.current))
        let regional = 5006.formatted(.number.locale(Locale.current))
        // Control: si el idioma de la app formateara igual que la región, el caso no distinguiría nada.
        #expect(expected != regional, "«\(expected)» == «\(regional)»: el caso no discrimina en este host")

        let texts: [(String, String)] = [
            ("Sync.needsSignIn", L10n.Storage.Sync.needsSignIn(5006)),
            ("Sync.waitingForConnection", L10n.Storage.Sync.waitingForConnection(5006)),
            ("Sync.stopped", L10n.Storage.Sync.stopped(5006)),
            ("Steps.uploadedCount", L10n.Storage.Steps.uploadedCount(650, of: 5006)),
            ("Steps.pendingCount", L10n.Storage.Steps.pendingCount(5006)),
            ("Steps.wipedCount", L10n.Storage.Steps.wipedCount(5006)),
            ("Revert.Prior.groupRecords", L10n.Storage.Revert.Prior.groupRecords(5006)),
            ("Revert.Prior.wiping", L10n.Storage.Revert.Prior.wiping(5006)),
            ("Progress.reversePending", L10n.Storage.Progress.reversePending(5006)),
            ("Migrate.previewResult", L10n.Storage.Migrate.previewResult(5006, 1, 1, 1)),
            ("Welcome.Restore.foundTransactions", L10n.Welcome.Restore.foundTransactions(5006)),
            ("Welcome.Restore.foundAccounts", L10n.Welcome.Restore.foundAccounts(5006)),
            ("Welcome.Restore.foundBudgets", L10n.Welcome.Restore.foundBudgets(5006)),
            ("Welcome.PrivateICloud.foundAtLeast", L10n.Welcome.PrivateICloud.foundAtLeast(5006)),
            ("Welcome.PrivateICloud.foundCategories", L10n.Welcome.PrivateICloud.foundCategories(5006)),
            ("Welcome.Restore.foundGroups", L10n.Welcome.Restore.foundGroups(5006)),
            ("UXL20N.willMove", L10n.UXL20N.willMove(records: 5006, accounts: 1, budgets: 1)),
        ]
        for (name, text) in texts {
            #expect(text.contains(expected), "\(name): «\(text)» no lleva «\(expected)»")
        }
    }

    @Test("el plural de los avisos con cifra sigue funcionando con el formato del idioma de la app")
    func storageCountsKeepThePlural() {
        LanguageManager.overrideLanguage = "es-419"
        #expect(L10n.Storage.Sync.needsSignIn(1) == "Inicia sesión para subir 1 cambio")
        #expect(L10n.Storage.Sync.needsSignIn(1537) == "Inicia sesión para subir 1,537 cambios")
        LanguageManager.overrideLanguage = "es-ES"
        #expect(L10n.Storage.Sync.needsSignIn(1537).contains("1537"))
    }

    // MARK: - Punto 5

    /// Un `Text(` cuya cadena de modificadores pinta en `warningForeground`. Solo mira los modificadores pegados al `Text`
    /// (líneas que empiezan por `.`): el naranja de un icono o de la etiqueta de un botón no cuenta.
    @Test("en «Dónde viven tus datos» ningún texto se pinta en naranja: solo los iconos")
    func noWarningForegroundText() throws {
        let url = Self.repoRoot.appendingPathComponent("Yala/App/Views/Settings/StorageSettingsView.swift")
        let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var offenders: [String] = []
        for (index, line) in lines.enumerated() where line.hasPrefix("Text(") {
            var next = index + 1
            while next < lines.count, lines[next].hasPrefix(".") {
                if lines[next].hasPrefix(".foregroundStyle(DS.Semantic.warningForeground)") { offenders.append(line) }
                next += 1
            }
        }
        #expect(offenders.isEmpty, "textos en naranja: \(offenders)")
        // Control: el scan ve los textos de la pantalla (si la ruta cambiara, saldría vacío y verde).
        #expect(lines.filter { $0.hasPrefix("Text(") }.count > 20)
    }
}
