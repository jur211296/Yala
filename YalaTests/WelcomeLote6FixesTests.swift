//
//  WelcomeLote6FixesTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 6 (primera vez con datos previos o en la nube): los cinco bugs claros que se arreglaron.
//  Cada caso tiene su mutante: deshacer el arreglo lo pone en rojo.
//

import Foundation
import Testing
import UIKit

@testable import Yala

@Suite("Auditoría UX 2.2 · lote 6 · bugs de Restaurar, aviso tardío y Yala completo")
struct WelcomeLote6FixesTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Sin comentarios: el porqué de cada arreglo vive en un comentario que nombra lo que se quitó.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func bundle(_ locale: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "falta \(locale).lproj")
        return try #require(Bundle(path: path))
    }

    private static func plural(_ key: String, _ count: Int, locale: String) throws -> String {
        let format = try bundle(locale).localizedString(forKey: key, value: "__MISSING__", table: nil)
        #expect(format != "__MISSING__", "\(key) no está en \(locale)")
        return String.localizedStringWithFormat(format, count)
    }

    // MARK: - B1 · «1 cuentas»

    @Test("MUTACIÓN: con una sola cuenta, Restaurar dice «1 cuenta» y no «1 cuentas»")
    func restoreCountsUseThePluralRule() throws {
        let cases: [(key: String, one: String, many: String)] = [
            ("welcome.restore.foundAccounts", "1 cuenta", "3 cuentas"),
            ("welcome.restore.foundTransactions", "1 registro", "3 registros"),
            ("welcome.restore.foundBudgets", "1 presupuesto", "3 presupuestos"),
            ("welcome.restore.foundGroups", "1 grupo compartido", "3 grupos compartidos"),
            ("welcome.privateICloud.foundCategories", "1 categoría", "3 categorías"),
        ]
        for c in cases {
            #expect(try Self.plural(c.key, 1, locale: "es-419") == c.one)
            #expect(try Self.plural(c.key, 3, locale: "es-419") == c.many)
        }
        #expect(try Self.plural("welcome.restore.foundAccounts", 1, locale: "en") == "1 account")
        #expect(try Self.plural("welcome.restore.foundAccounts", 0, locale: "pt-BR") == "0 contas")
    }

    @Test("MUTACIÓN: las cinco cifras se formatean con la regla de plural, no con `String(format:)` a secas")
    func l10nFormatsTheCountsWithThePluralRule() throws {
        let code = Self.codeOnly(try Self.source("Yala/Utils/L10n.swift"))
        for key in ["welcome.restore.foundAccounts", "welcome.restore.foundTransactions", "welcome.restore.foundBudgets",
                    "welcome.restore.foundGroups", "welcome.privateICloud.foundCategories"] {
            #expect(code.contains("String.localizedStringWithFormat(ls(\"\(key)\""), "\(key) no pasa por la regla de plural")
            #expect(!code.contains("String(format: ls(\"\(key)\""), "\(key) sigue con String(format:)")
        }
    }

    // MARK: - B2 · iconos que no existen

    /// `cloud.slash` no existe: «La nube de Yala está en pausa» salía con un hueco donde iba el icono. La red barre todas las
    /// pantallas del lote, no solo la que falló.
    @Test("MUTACIÓN: todos los iconos de las pantallas del lote existen en SF Symbols")
    func everySymbolInTheBatchScreensExists() throws {
        let files = [
            "Yala/App/Views/Onboarding/WelcomeRestoreView.swift",
            "Yala/App/Views/Onboarding/RestoreProgressView.swift",
            "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift",
            "Yala/App/Views/Onboarding/WelcomeExistingChooserView.swift",
            "Yala/App/Views/Onboarding/WelcomeNewChooserView.swift",
            "Yala/App/Views/Onboarding/WelcomeMirrorRelaunchView.swift",
            "Yala/App/Views/Shared/LateICloudMirrorNoticeView.swift",
            "Yala/App/Views/Groups/FullModeActivationView.swift",
            "Yala/App/Views/Groups/FullModeActivationFinaleView.swift",
            "Yala/App/Views/Settings/CloudConsentView.swift",
        ]
        let pattern = #/(?:systemName: |icon: |\.system\(|systemImage: )"([a-z0-9.]+)"/#
        var checked = 0
        for file in files {
            let code = Self.codeOnly(try Self.source(file))
            for match in code.matches(of: pattern) {
                let name = String(match.1)
                checked += 1
                #expect(UIImage(systemName: name) != nil, "\(file): el icono «\(name)» no existe")
            }
        }
        #expect(checked > 20, "el barrido no encontró los iconos (\(checked))")
    }

    // MARK: - B3 · «Reintentar búsqueda» en un borrado

    @Test("MUTACIÓN: si falla el borrado del aviso tardío, el botón dice que reintenta el borrado")
    func lateNoticeWipeFailureRetriesTheWipe() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Shared/LateICloudMirrorNoticeView.swift"))
        let start = try #require(code.range(of: "case .failed:"))
        let end = try #require(code.range(of: "case .leftHalfway:", range: start.upperBound..<code.endIndex))
        let failed = code[start.upperBound..<end.lowerBound]
        #expect(failed.contains("primary: L10n.Welcome.PrivateICloud.wipeRetry"))
        #expect(!failed.contains("L10n.Welcome.Restore.retry"))
    }

    // MARK: - B4 · contraste de la salida secundaria

    /// `.secondary` dentro de un `Button` deriva del tinte: «Empezar desde cero» y el «Cancelar» del final de la activación
    /// salían en índigo sobre el fondo oscuro, a 1,9:1.
    @Test("MUTACIÓN: las salidas secundarias de Restaurar y de la activación no heredan el tinte")
    func secondaryExitsDoNotInheritTheTint() throws {
        for file in ["Yala/App/Views/Onboarding/WelcomeRestoreView.swift",
                     "Yala/App/Views/Groups/FullModeActivationFinaleView.swift"] {
            let lines = Self.codeOnly(try Self.source(file))
                .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            for (i, line) in lines.enumerated() where line == ".font(DS.Typography.label)" && i + 1 < lines.count {
                #expect(lines[i + 1] != ".foregroundStyle(.secondary)", "\(file): un botón con `.secondary` (línea \(i + 2))")
            }
            #expect(lines.contains(".foregroundStyle(Color(uiColor: .secondaryLabel))"), "\(file)")
        }
    }

    // MARK: - B5 · «Esto creará una cuenta nueva…»

    /// Confirmar abre la puerta que revisa iCloud y vuelve a preguntar: ni crea una cuenta ni borra nada todavía (ticket
    /// `start-fresh-dialog-promises-what-the-gate-undoes`).
    @Test("MUTACIÓN: «¿Empezar desde cero?» ya no promete una cuenta nueva en ningún idioma")
    func startFreshDialogTellsWhatHappensNext() throws {
        let old = ["creará una cuenta nueva", "va a crear una cuenta nueva", "create a new account", "neues Konto",
                   "nouveau compte", "nuovo account", "新しいアカウント", "nieuwe account", "nowego konta", "conta nova", "新账户"]
        for locale in ["es-419", "es", "es-ES", "es-AR", "en", "en-GB", "de", "fr", "it", "ja", "nl", "pl", "pt-BR", "pt",
                       "pt-PT", "zh-Hans"] {
            let body = try Self.bundle(locale).localizedString(forKey: "welcome.restore.startFreshConfirm.body",
                                                               value: "__MISSING__", table: nil)
            #expect(body != "__MISSING__", "\(locale)")
            for phrase in old { #expect(!body.contains(phrase), "\(locale): «\(body)»") }
        }
        let es = try Self.bundle("es-419").localizedString(forKey: "welcome.restore.startFreshConfirm.body",
                                                           value: "", table: nil)
        #expect(es.hasPrefix("Todavía no se borra nada."))
    }
}
