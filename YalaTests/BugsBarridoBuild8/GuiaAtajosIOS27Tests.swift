//
//  GuiaAtajosIOS27Tests.swift
//  YalaTests / BugsBarridoBuild8
//
//  Barrido de la build 8 (24-nov-2026): la guía de Atajos de «Avisos del banco» describía la app Atajos de iOS 26. En iOS
//  27 o posterior enseña los pasos de la app nueva; en iOS 26, los de siempre. Se fija la elección por versión, que los
//  textos de iOS 27 no nombran nada que ya no exista y que las claves nuevas están en los 16 idiomas.
//

import Foundation
import Testing

@testable import Yala

@Suite("Barrido build 8 · guía de Atajos por versión de iOS")
struct GuiaAtajosIOS27Tests {

    private static func os(_ major: Int, _ minor: Int = 0) -> OperatingSystemVersion {
        OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: 0)
    }

    @Test func iOS26_keepsTheOldGuide_andIOS27OrLater_theNewOne() {
        #expect(BankNoticeGuideVersion.forSystem(Self.os(26, 4)) == .ios26)
        #expect(BankNoticeGuideVersion.forSystem(Self.os(27, 0)) == .ios27)
        #expect(BankNoticeGuideVersion.forSystem(Self.os(27, 2)) == .ios27)
        #expect(BankNoticeGuideVersion.forSystem(Self.os(28)) == .ios27)
    }

    /// Cada paso que cambió sale con otro texto en cada guía.
    @Test func theTwoGuides_differInEveryChangedStep() {
        let old = BankNoticeGuideVersion.ios26
        let new = BankNoticeGuideVersion.ios27
        #expect(old.step2Detail != new.step2Detail)
        #expect(old.step3Detail("BCP") != new.step3Detail("BCP"))
        #expect(old.step4Detail != new.step4Detail)
        #expect(old.step5Detail("BCP") != new.step5Detail("BCP"))
        #expect(old.removeStep1("BCP") != new.removeStep1("BCP"))
        #expect(old.removeStep2 != new.removeStep2)
        // El argumento llega al texto: la app y el banco se nombran.
        #expect(new.step3Detail("la app de BCP").contains("la app de BCP"))
        #expect(new.step5Detail("Interbank").contains("Interbank"))
        #expect(new.removeStep1("Yape").contains("Yape"))
    }

    // MARK: - Textos

    private static let locales = [
        "es-419", "es", "es-ES", "es-AR", "en", "en-GB", "de", "fr", "it", "ja", "nl", "pl", "pt-BR", "pt", "pt-PT", "zh-Hans",
    ]

    private static let newKeys = [
        "atajoParte2.bank.guide27.step2.detail", "atajoParte2.bank.guide27.step3.detail",
        "atajoParte2.bank.guide27.step4.detail", "atajoParte2.bank.guide27.step5.detail",
        "atajoParte2.bank.remove27.step1", "atajoParte2.bank.remove27.step2",
    ]

    /// Las claves que llevan `%@`: la app (paso 3), el banco (paso 5) y su nombre (quitarlo).
    private static let keysWithArgument: Set<String> = [
        "atajoParte2.bank.guide27.step3.detail", "atajoParte2.bank.guide27.step5.detail", "atajoParte2.bank.remove27.step1",
    ]

    private static func strings(_ locale: String) throws -> [String: String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Yala/Resources/\(locale).lproj/CapturaAtajoParte2.strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String])
    }

    @Test(arguments: locales)
    func everyLocale_hasTheNewSteps_withTheirArgument(_ locale: String) throws {
        let table = try Self.strings(locale)
        for key in Self.newKeys {
            let value = try #require(table[key], "\(locale) no tiene \(key)")
            #expect(!value.isEmpty && value != key)
            let arguments = value.components(separatedBy: "%@").count - 1
            #expect(arguments == (Self.keysWithArgument.contains(key) ? 1 : 0), "\(locale): \(key) con \(arguments) %@")
        }
    }

    /// En iOS 27 no existen «Ejecutar inmediatamente», «Siguiente», «Nueva automatización en blanco» ni «Agregar acción»,
    /// y no se borra deslizando: la guía nueva no puede nombrarlos (el hallazgo del barrido, medido en el iPhone 14).
    @Test(arguments: ["es-419", "es", "es-ES", "es-AR"])
    func spanishGuide27_namesNothingThatIsGone(_ locale: String) throws {
        let table = try Self.strings(locale)
        let text = Self.newKeys.compactMap { table[$0] }.joined(separator: " ").lowercased()
        for gone in ["inmediatamente", "siguiente", "en blanco", "agregar acción", "añadir acción", "desliza"] {
            #expect(!text.contains(gone), "\(locale) nombra «\(gone)»")
        }
        // Y sí nombra lo que hay: el «+» de abajo, la pestaña «Automatización» y la pulsación larga.
        #expect(text.contains("nuevo atajo"))
        #expect(text.contains("automatización"))
        #expect(text.contains("mant"))
    }

    @Test(arguments: ["en", "en-GB"])
    func englishGuide27_namesNothingThatIsGone(_ locale: String) throws {
        let table = try Self.strings(locale)
        let text = Self.newKeys.compactMap { table[$0] }.joined(separator: " ").lowercased()
        for gone in ["run immediately", "next", "blank", "add action", "swipe"] {
            #expect(!text.contains(gone), "\(locale) nombra «\(gone)»")
        }
    }

    /// La vista elige el texto por la versión: ningún paso que cambió llama a la clave vieja directamente.
    @Test func theBankView_readsTheChangedStepsFromTheVersion() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let code = try String(
            contentsOf: root.appendingPathComponent("Yala/App/Views/Settings/AtajoBanco/BankNoticeBankView.swift"),
            encoding: .utf8)
        #expect(code.contains("BankNoticeGuideVersion.forSystem()"))
        for old in ["Bank.guideStep2Detail", "Bank.guideStep3Detail", "Bank.guideStep4Detail", "Bank.guideStep5Detail",
                    "Bank.removeStep1", "Bank.removeStep2"] {
            #expect(!code.contains(old), "BankNoticeBankView usa \(old) sin pasar por la versión")
        }
    }
}
