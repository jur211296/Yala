//
//  WelcomeVisualAdjustmentsTests.swift
//  YalaTests
//
//  Ajustes de la bienvenida 2.3 del 13-nov (ticket `welcome-2-3-visual-adjustments`). Lo que se puede fijar sin
//  pantalla: que la fuente del lema llega empaquetada, que el lema y las minidescripciones caben en el iPhone más chico
//  en los 16 idiomas, que los tres accesos caben en su botón y que el logo es vectorial.
//

import Foundation
import Testing
import UIKit
@testable import Yala

@Suite("Bienvenida 2.3 · ajustes visuales del 13-nov")
struct WelcomeVisualAdjustmentsTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // WelcomeVisual2026Nov/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    static let languages = ["es", "es-419", "es-ES", "es-AR", "en", "en-GB", "de", "fr", "it", "nl", "pl",
                            "pt", "pt-BR", "pt-PT", "ja", "zh-Hans"]

    /// El iPhone más chico que soporta Yala mide 375 pt; la pantalla deja 16 pt a cada lado.
    static let narrowestScreen: CGFloat = 375
    static let pageWidth: CGFloat = narrowestScreen - 2 * DS.Spacing.lg
    /// La vitrina resta su relleno (14 pt por lado).
    static let stageTextWidth: CGFloat = pageWidth - 2 * (DS.Spacing.md + DS.Spacing.xxs)

    private func text(_ key: String, _ language: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"), "Falta \(language).lproj")
        let bundle = try #require(Bundle(path: path))
        let value = NSLocalizedString(key, bundle: bundle, value: "__MISSING__", comment: "")
        #expect(value != "__MISSING__", "Falta \(key) en \(language)")
        return value
    }

    private func width(_ string: String, _ font: UIFont, tracking: CGFloat = 0) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: font, .kern: tracking]).width
    }

    // MARK: - Lema

    @Test("La fuente del lema llega empaquetada y registrada")
    func titleFontIsBundled() {
        #expect(UIFont(name: WelcomeShowcaseView.titleFontName, size: 28) != nil,
                "Bricolage Grotesque no se registró: revisa Resources/Fonts y UIAppFonts en Info.plist.")
    }

    @Test("«Tus finanzas personales,» cabe en una línea a tamaño completo en el iPhone de 375 pt")
    func spanishTitleFitsWithoutShrinking() throws {
        let font = try #require(UIFont(name: WelcomeShowcaseView.titleFontName, size: WelcomeShowcaseView.titleFontSize))
        let tracking = -WelcomeShowcaseView.titleFontSize * 0.025
        for language in ["es", "es-419", "es-ES", "es-AR"] {
            for key in ["bienvenida23.showcase.financesTitle", "bienvenida23.showcase.financesTitleAccent",
                        "bienvenida23.showcase.groupsTitle", "bienvenida23.showcase.groupsTitleAccent"] {
                let line = try text(key, language)
                #expect(width(line, font, tracking: tracking) <= Self.pageWidth, "«\(line)» (\(language)) parte en dos")
            }
        }
    }

    @Test("En todos los idiomas cada mitad del lema entra en su línea con el encogido que permite la vista (60 %)")
    func everyTitleLineFitsWithItsScale() throws {
        let font = try #require(UIFont(name: WelcomeShowcaseView.titleFontName, size: WelcomeShowcaseView.titleFontSize))
        for language in Self.languages {
            for key in ["bienvenida23.showcase.financesTitle", "bienvenida23.showcase.financesTitleAccent",
                        "bienvenida23.showcase.groupsTitle", "bienvenida23.showcase.groupsTitleAccent"] {
                let line = try text(key, language)
                #expect(width(line, font) * 0.6 <= Self.pageWidth, "«\(line)» (\(language)) no cabe ni encogido")
            }
        }
    }

    // MARK: - Minidescripciones

    static let captionKeys = ["receipt", "voice", "organize", "split", "budget", "whoOwes", "settle"]
        .map { "bienvenida23.showcase.\($0).caption" }

    @Test("En español cada minidescripción ocupa una línea sin encoger", arguments: ["es", "es-419", "es-ES", "es-AR"])
    func spanishCaptionsFitAtFullSize(language: String) throws {
        let font = UIFont.preferredFont(forTextStyle: .subheadline,
                                        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        for key in Self.captionKeys {
            let caption = try text(key, language)
            #expect(width(caption, font) <= Self.stageTextWidth, "«\(caption)» (\(language)) ocupa dos líneas")
        }
    }

    @Test("En los 16 idiomas cada minidescripción cabe en una línea encogiendo como mucho al 85 %")
    func everyCaptionFitsOneLine() throws {
        let font = UIFont.preferredFont(forTextStyle: .subheadline,
                                        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        for language in Self.languages {
            for key in Self.captionKeys {
                let caption = try text(key, language)
                #expect(width(caption, font) * 0.85 <= Self.stageTextWidth,
                        "«\(caption)» (\(language)) no cabe en una línea")
            }
        }
    }

    // MARK: - Accesos

    @Test("El tercer acceso dice «iCloud privado»", arguments: ["es", "es-419", "es-ES", "es-AR"])
    func thirdAccessSaysPrivateICloud(language: String) throws {
        #expect(try text("bienvenida23.access.iCloud", language) == "Entrar con iCloud privado")
    }

    @Test("Los tres accesos caben en su botón en todos los idiomas, con el encogido que permite (80 %)")
    func accessTitlesFitTheButton() throws {
        let font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        // Botón a todo el ancho, menos su relleno, el hueco del ícono y su separación.
        let room = Self.pageWidth - 2 * DS.Spacing.lg - WelcomeAccessButton.iconSlot - DS.Spacing.sm
        for language in Self.languages {
            for key in ["bienvenida23.access.google", "bienvenida23.access.apple", "bienvenida23.access.iCloud"] {
                let title = try text(key, language)
                #expect(width(title, font) * 0.8 <= room, "«\(title)» (\(language)) no cabe en el botón")
            }
        }
    }

    @Test("La línea de iCloud privado cabe en una línea en todos los idiomas, con el encogido que permite (80 %)")
    func iCloudSubtitleFits() throws {
        let font = UIFont.preferredFont(forTextStyle: .caption1,
                                        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        // Arranca donde el texto de arriba: el botón menos su relleno, el hueco del ícono y su separación.
        let room = Self.pageWidth - 2 * DS.Spacing.lg - WelcomeAccessButton.iconSlot - DS.Spacing.sm
        for language in Self.languages {
            let line = try text("bienvenida23.access.iCloudLine", language)
            #expect(width(line, font) * 0.8 <= room, "«\(line)» (\(language)) no cabe")
        }
    }

    @Test("«Dividir gastos con amigos» sale en «Mis finanzas» con cualquier función de la vitrina")
    func groupsDoorDoesNotDependOnTheRotatingFunction() {
        #expect(WelcomeShowcaseLogic.offersGroupsDoor(on: .finances, providersAvailable: true))
        #expect(!WelcomeShowcaseLogic.offersGroupsDoor(on: .groups, providersAvailable: true))
        #expect(!WelcomeShowcaseLogic.offersGroupsDoor(on: .finances, providersAvailable: false))
    }

    // MARK: - Logo

    @Test("El logo es vectorial: un SVG con «Preserve Vector Data» y sin PNG")
    func logoIsVector() throws {
        let folder = Self.repoRoot.appendingPathComponent("Yala/Resources/Assets.xcassets/YalaLogo.imageset")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(files.contains("YalaLogo.svg"))
        #expect(!files.contains { $0.hasSuffix(".png") }, "Volvió un PNG: el logo se pixela al agrandarse.")
        let json = try String(contentsOf: folder.appendingPathComponent("Contents.json"), encoding: .utf8)
        #expect(json.contains("\"preserves-vector-representation\" : true"))
    }

    @Test("El logo se carga con su tamaño natural de siempre (120 × 40), el que usa la pantalla de arranque")
    func logoKeepsItsNaturalSize() throws {
        let image = try #require(UIImage(named: "YalaLogo"))
        #expect(image.size == CGSize(width: 120, height: 40))
    }
}
