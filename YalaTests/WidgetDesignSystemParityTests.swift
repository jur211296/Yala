//
//  WidgetDesignSystemParityTests.swift
//  YalaTests
//
//  Los widgets no compilan el sistema de diseño de la app: `YalaWidgets/Theme/WidgetDS.swift` lo copia (mismos nombres,
//  mismos valores) y `WidgetColors` copia los colores de texto y de relleno de la app. `YalaTests` no compila el target
//  de los widgets, así que la única red es leer las dos fuentes y compararlas: si un token cambia en la app y no en el
//  widget, esto se pone rojo. Rediseño de los widgets 2.2 (`docs/widgets/AUDITORIA-WIDGETS-2-2.md`, G8).
//

import Foundation
import SwiftUI
import Testing

@testable import Yala

struct WidgetDesignSystemParityTests {

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    /// El cuerpo de `enum <name> {` dentro de `source`, contando llaves.
    private static func enumBody(_ name: String, in source: String) throws -> String {
        let start = try #require(source.range(of: "enum \(name) {"), "No encuentro «enum \(name)».")
        var depth = 0
        var index = start.upperBound
        depth = 1
        while index < source.endIndex, depth > 0 {
            let char = source[index]
            if char == "{" { depth += 1 }
            if char == "}" { depth -= 1 }
            index = source.index(after: index)
        }
        return String(source[start.upperBound..<index])
    }

    /// `static let nombre[: Tipo] = valor` → [nombre: valor normalizado], sin comentarios.
    private static func constants(in body: String) -> [String: String] {
        var result: [String: String] = [:]
        let regex = /static let (\w+)(?:\s*:\s*[\w.]+)?\s*=\s*(.+)/
        for line in body.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//"), let match = trimmed.firstMatch(of: regex) else { continue }
            var value = String(match.2)
            if let comment = value.range(of: " //") { value = String(value[..<comment.lowerBound]) }
            result[String(match.1)] = value.trimmingCharacters(in: .whitespaces)
        }
        return result
    }

    @Test(arguments: ["Spacing", "Radius", "Opacity", "Icon", "Sizing", "Typography"])
    func cadaTokenDelWidgetEsElDeLaApp(group: String) throws {
        let widget = Self.constants(in: try Self.enumBody(group, in: try Self.source("YalaWidgets/Theme/WidgetDS.swift")))
        let app = Self.constants(in: try Self.enumBody(group, in: try Self.source("Yala/App/Theme/DesignTokens.swift")))
        #expect(!widget.isEmpty, "WidgetDS.\(group) vacío: el test no mira nada.")
        for (name, value) in widget {
            let appValue = try #require(app[name], "WidgetDS.\(group).\(name) no existe en DS.\(group): el widget inventa un token.")
            #expect(value == appValue, "WidgetDS.\(group).\(name) = \(value), pero DS.\(group).\(name) = \(appValue).")
        }
    }

    // MARK: - Colores

    /// El hex de `static let <name> = Color(hex: "XXXXXX")` en `source`.
    private static func hex(_ name: String, in source: String) throws -> String {
        let regex = try Regex("static let \(name) = Color\\(hex: \"([0-9A-Fa-f]{6})\"\\)")
        let match = try #require(source.firstMatch(of: regex), "No encuentro el hex de «\(name)».")
        return String(try #require(match.output[1].substring)).uppercased()
    }

    /// Los dos hex de un color adaptativo (`traits.userInterfaceStyle == .dark ? <oscuro> : <claro>`) de `name`.
    private static func adaptiveHex(_ name: String, in source: String) throws -> (dark: String, light: String) {
        let start = try #require(source.range(of: "static let \(name) = Color(uiColor: UIColor { traits in"))
        let tail = String(source[start.upperBound...].prefix(260))
        let regex = /\.dark \? UIColor\(Color\(hex: "([0-9A-Fa-f]{6})"\)\) : UIColor\(Color\(hex: "([0-9A-Fa-f]{6})"\)\)/
        let match = try #require(tail.firstMatch(of: regex), "«\(name)» no es un adaptativo de dos hex.")
        return (String(match.1).uppercased(), String(match.2).uppercased())
    }

    @Test func losColoresDeTextoYRellenoSonLosDeLaApp() throws {
        let widget = try Self.source("YalaWidgets/Theme/WidgetColors.swift")
        let app = try Self.source("Yala/App/Views/Shared/UIHelpers.swift")

        // Ingreso como texto: `Color.incomeAmount` (#0F7A80 en claro, el turquesa de marca en oscuro).
        let income = try Self.adaptiveHex("incomeText", in: widget)
        #expect(income.light == Color.incomeAmountLightHex.uppercased())
        #expect(income.dark == Color.incomeAmountDarkHex.uppercased())

        // «Te pasaste» como texto: `Color.overBudgetText` (rosa profundo en claro, el de marca en oscuro).
        let alert = try Self.adaptiveHex("alertText", in: widget)
        #expect(alert.light == (try Self.hex("emphasisPinkFill", in: app)))
        #expect(alert.dark == (try Self.hex("hotPink", in: widget)))

        // Índigo como texto: el de marca en claro y `indigoTextOnDark` en oscuro.
        let accent = try Self.adaptiveHex("accentText", in: widget)
        #expect(accent.light == (try Self.hex("primary", in: widget)))
        #expect(accent.dark == (try Self.hex("indigoTextOnDark", in: app)))

        // Rellenos con blanco encima.
        #expect((try Self.hex("indigoFill", in: widget)) == (try Self.hex("selectedIndigoFill", in: app)))
        #expect((try Self.hex("pinkFill", in: widget)) == (try Self.hex("emphasisPinkFill", in: app)))
        #expect((try Self.hex("tealFill", in: widget)) == Color.incomeAmountLightHex.uppercased())
    }

    /// El fondo de la tarjeta del widget es el `card` del tema por defecto: blanco y #1C1C1E, que es el gris agrupado
    /// secundario del sistema. Si el tema cambia su tarjeta, el widget se queda atrás.
    @Test func elFondoDeLaTarjetaEsElDelTemaPorDefecto() throws {
        let widget = try Self.source("YalaWidgets/Theme/WidgetColors.swift")
        #expect(widget.contains("static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)"))
        let theme = try Self.source("Yala/App/Theme/YalaTheme.swift")
        #expect(theme.contains("card: .white,"))
        #expect(theme.contains("card: Color(red: 0.11, green: 0.11, blue: 0.12),  // #1C1C1E"))
    }

    /// Los widgets rediseñados no usan el `WDS` viejo ni números de espaciado sueltos: solo `WidgetDS`.
    @Test(arguments: [
        "YalaWidgets/Widgets/BalanceWidget.swift", "YalaWidgets/Widgets/ExpenseWidget.swift",
        "YalaWidgets/Widgets/BudgetsWidget.swift", "YalaWidgets/Widgets/ScheduledPaymentsWidget.swift",
        "YalaWidgets/Widgets/ScheduledPaymentsPortraitView.swift", "YalaWidgets/Widgets/LatestRecordsWidget.swift",
        "YalaWidgets/Widgets/QuickEntryWidgets.swift", "YalaWidgets/Widgets/AccessoryWidgets.swift",
        "YalaWidgets/Views/WidgetCardComponents.swift",
    ])
    func losRedisenadosSoloUsanWidgetDS(path: String) throws {
        let code = try Self.source(path).split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(!code.contains("WDS."), "\(path) vuelve al WDS viejo.")
        #expect(code.firstMatch(of: /(?:padding|spacing|cornerRadius|lineWidth)\s*[:(]\s*[0-9]/) == nil,
                "\(path) tiene un espaciado, radio o grosor suelto.")
        #expect(!code.contains("Color(.secondarySystemGroupedBackground)"), "\(path) pinta el fondo sin el token.")
        #expect(!code.contains(".gradient"), "\(path) vuelve a los degradados.")
    }
}
