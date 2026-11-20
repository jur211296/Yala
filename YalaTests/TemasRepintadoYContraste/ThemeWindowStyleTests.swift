//
//  ThemeWindowStyleTests.swift
//  YalaTests
//
//  Al cambiar de tema, la ventana y lo que tiene presentado toman el claro u oscuro nuevo (Jürgen, 19-nov-2026: Ajustes
//  se quedaba con el texto del modo anterior hasta cerrarlo). La pintura la mide `TemasRepintadoUITests`; aquí, lo que
//  la decide: el estilo de cada tema, que la sonda lo ponga en la ventana Y en lo presentado, y que esté colgada.
//

import SwiftUI
import Testing
import UIKit
@testable import Yala

@Suite("Temas: la ventana y sus hojas toman el claro u oscuro del tema", .serialized)
@MainActor
struct ThemeWindowStyleTests {

    // MARK: - Lógica

    /// Cada elección con la paleta que le da `ThemeManager.resolved` (sin instanciarlo: escribe en `UserDefaults.standard`).
    private static let choices: [(AppTheme, YalaTheme, UIUserInterfaceStyle)] = [
        (.light, .light, .light), (.dark, .dark, .dark), (.indigo, .indigo, .dark), (.rosa, .rosa, .dark),
        (.teal, .teal, .dark), (.minimalist, .minimalist, .dark), (.translucent, .translucent, .dark),
        (.translucent, .translucentRosa, .dark), (.translucent, .translucentTeal, .dark), (.liquidGlass, .liquidGlass, .dark),
    ]

    @Test("Cada tema da su claro u oscuro a la ventana; «Sistema» la suelta")
    func style_perTheme() {
        for (choice, theme, expected) in Self.choices {
            #expect(ThemeWindowStyleLogic.style(for: choice, resolved: theme) == expected, "\(choice)")
        }
        #expect(ThemeWindowStyleLogic.style(for: .system, resolved: .light) == .unspecified)
        #expect(ThemeWindowStyleLogic.style(for: .system, resolved: .dark) == .unspecified)
        #expect(Set(Self.choices.map(\.0)).union([.system]) == Set(AppTheme.allCases), "Un tema nuevo entra en la tabla")
    }

    // MARK: - La sonda

    /// Una ventana de verdad, en la escena del host: sin escena y visible, la vista no llega a estar en la ventana.
    private static func makeWindow() throws -> UIWindow {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "El host de tests no tiene escena"
        )
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.isHidden = false
        return window
    }

    @Test("La sonda pone el estilo en su ventana al entrar y al cambiar")
    func probe_setsTheWindowStyle() throws {
        let window = try Self.makeWindow()
        defer { window.isHidden = true }
        let probe = ThemeWindowStyleProbeView()
        probe.style = .dark
        window.rootViewController?.view.addSubview(probe)
        #expect(window.overrideUserInterfaceStyle == .dark)
        probe.style = .light
        #expect(window.overrideUserInterfaceStyle == .light)
        probe.style = .unspecified
        #expect(window.overrideUserInterfaceStyle == .unspecified)
    }

    @Test("Al cambiar de tema, lo presentado en la ventana también cambia (la hoja de Ajustes abierta)")
    func probe_updatesPresentedControllers() async throws {
        let window = try Self.makeWindow()
        defer { window.isHidden = true }
        let root = try #require(window.rootViewController)

        let sheet = UIViewController()
        // Así la deja SwiftUI al presentarla: con el modo de quien la abrió.
        sheet.overrideUserInterfaceStyle = .light
        await withCheckedContinuation { continuation in
            root.present(sheet, animated: false) { continuation.resume() }
        }
        defer { sheet.dismiss(animated: false) }

        let probe = ThemeWindowStyleProbeView()
        probe.style = .light
        root.view.addSubview(probe)
        #expect(sheet.overrideUserInterfaceStyle == .light)

        probe.style = .dark
        #expect(window.overrideUserInterfaceStyle == .dark)
        #expect(sheet.overrideUserInterfaceStyle == .dark, "La hoja abierta se quedó con el modo de antes")
        #expect(sheet.traitCollection.userInterfaceStyle == .dark)

        probe.style = .unspecified
        #expect(sheet.overrideUserInterfaceStyle == .unspecified, "Con «Sistema» la hoja vuelve a seguir a iOS")
    }

    // MARK: - Cableado

    @Test("La raíz de cada ventana cuelga la sonda con el estilo del tema elegido")
    func wiring_rootViewAppliesTheStyle() throws {
        let source = try Self.source("Yala/App/YalaApp.swift")
        let flat = source.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        #expect(flat.contains(".appliesThemeStyleToWindow("))
        #expect(source.contains("ThemeWindowStyleLogic.style(for: themeManager.userChoice, resolved: themeManager.resolved)"))
    }

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        var url = URL(fileURLWithPath: "\(file)")
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
