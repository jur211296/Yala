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

        // «Debes» y «Te deben» de Grupos: los de la lista (`Color.groupOweAmount` / `groupOwedAmount`).
        let owe = try Self.adaptiveHex("groupOweText", in: widget)
        #expect(owe.light == Color.groupOweAmountLightHex.uppercased())
        #expect(owe.dark == Color.groupOweAmountDarkHex.uppercased())
        let owed = try Self.adaptiveHex("groupOwedText", in: widget)
        #expect(owed.light == Color.groupOwedAmountLightHex.uppercased())
        #expect(owed.dark == Color.groupOwedAmountDarkHex.uppercased())
    }

    /// Contraste WCAG entre dos hex («RRGGBB»).
    private static func contrast(_ a: String, _ b: String) throws -> Double {
        func luminance(_ hex: String) throws -> Double {
            let value = try #require(Int(hex, radix: 16), "«\(hex)» no es un hex.")
            let channels = [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF].map { Double($0) / 255 }
            let linear = channels.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
        }
        let (la, lb) = (try luminance(a), try luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// El fondo con profundidad (2026-11-03) ya no es el `card` de la app: es un degradado de colores fijos. Cada texto
    /// de color tiene que seguir dando 4,5:1 en los DOS extremos del degradado, en claro y en oscuro: si alguien
    /// aclara el oscuro o agrisa el claro para que «se note más», el rosa y el índigo bajan de AA sin que nada lo diga.
    @Test func elFondoConProfundidadMantieneElContrasteDeLosTextos() throws {
        let widget = try Self.source("YalaWidgets/Theme/WidgetColors.swift")
        let top = try Self.adaptiveHex("cardTop", in: widget)
        let bottom = try Self.adaptiveHex("cardBottom", in: widget)
        // Que sea un degradado de verdad en oscuro (lo que pidió Jürgen), y que el oscuro no vuelva al gris elevado.
        #expect(top.dark != bottom.dark)
        #expect(try Self.contrast(top.dark, "000000") < Self.contrast("3A3A3C", "000000"))
        for name in ["incomeText", "alertText", "accentText", "groupOweText", "groupOwedText"] {
            let text = try Self.adaptiveHex(name, in: widget)
            for (label, fondo, color) in [("claro arriba", top.light, text.light), ("claro abajo", bottom.light, text.light),
                                          ("oscuro arriba", top.dark, text.dark), ("oscuro abajo", bottom.dark, text.dark)] {
                let ratio = try Self.contrast(color, fondo)
                #expect(ratio >= 4.5, "\(name) da \(ratio):1 sobre el fondo \(label) (#\(fondo)).")
            }
        }
    }

    /// Todos los widgets de la pantalla de inicio pintan su fondo con `WidgetCardBackground`; los de la pantalla
    /// bloqueada, transparente. Un widget nuevo copiado de una rama vieja traería el gris plano de vuelta.
    @Test func todosLosWidgetsUsanElFondoConProfundidad() throws {
        let widgets = Self.root.appending(path: "YalaWidgets/Widgets")
        let files = try FileManager.default.contentsOfDirectory(at: widgets, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        var withBackground = 0
        for url in files {
            let code = try String(contentsOf: url, encoding: .utf8)
            for match in code.matches(of: /\.containerBackground\(([^\n]*)/) {
                let call = String(match.1)
                withBackground += 1
                let ok = call.hasPrefix("for: .widget) {") || call == ".clear, for: .widget)"
                #expect(ok, "\(url.lastPathComponent) pinta el fondo sin `WidgetCardBackground`: «\(call)».")
                if call.hasPrefix("for: .widget) {") {
                    let tail = call + code[match.range.upperBound...].prefix(120)
                    #expect(tail.contains("WidgetCardBackground("), "\(url.lastPathComponent): el cierre no pinta `WidgetCardBackground`.")
                }
            }
        }
        // 12 widgets de datos + Entrada rápida + los 4 de la pantalla bloqueada.
        #expect(withBackground == 17, "Esperaba 17 fondos y hay \(withBackground): ¿un widget nuevo o uno sin fondo?")
        #expect(!(try Self.source("YalaWidgets/Theme/WidgetColors.swift")).contains("secondarySystemGroupedBackground"))
    }

    /// Los widgets rediseñados no usan el `WDS` viejo ni números de espaciado sueltos: solo `WidgetDS`.
    @Test(arguments: [
        "YalaWidgets/Widgets/BalanceWidget.swift", "YalaWidgets/Widgets/ExpenseWidget.swift",
        "YalaWidgets/Widgets/BudgetsWidget.swift", "YalaWidgets/Widgets/ScheduledPaymentsWidget.swift",
        "YalaWidgets/Widgets/ScheduledPaymentsPortraitView.swift", "YalaWidgets/Widgets/LatestRecordsWidget.swift",
        "YalaWidgets/Widgets/QuickEntryWidgets.swift", "YalaWidgets/Widgets/AccessoryWidgets.swift",
        "YalaWidgets/Views/WidgetCardComponents.swift",
        // Tanda 2 (S35f1): Entradas y salidas y Resumen del mes.
        "YalaWidgets/Widgets/CashFlowWidget.swift", "YalaWidgets/Widgets/CashFlowPortraitView.swift",
        "YalaWidgets/Widgets/MonthSummaryWidget.swift", "YalaWidgets/Widgets/MonthSummaryPortraitView.swift",
        // Tanda 3 (S35f2): Categorías y Subcategorías (ranking y tarta), sus piezas y las dos invitaciones.
        "YalaWidgets/Widgets/TopCategoriesWidget.swift", "YalaWidgets/Widgets/TopSubcategoriesWidget.swift",
        "YalaWidgets/Widgets/CategoriesPieWidget.swift", "YalaWidgets/Widgets/SubcategoriesPieWidget.swift",
        "YalaWidgets/Views/WidgetCategoryBreakdown.swift",
        "YalaWidgets/Views/WidgetNoDataInviteView.swift", "YalaWidgets/Views/GroupsOnlyInviteView.swift",
        // S35f3: Grupos.
        "YalaWidgets/Widgets/GroupsWidget.swift",
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

    /// La tanda 3 (S35f2) retiró el `WDS` viejo: ni su fichero ni una sola llamada en el target de los widgets. Un widget
    /// nuevo que copie de uno viejo (de otra rama, de un stash) lo vuelve a traer sin que nadie lo vea.
    @Test func elWDSViejoNoVuelve() throws {
        let widgets = Self.root.appending(path: "YalaWidgets")
        #expect(!FileManager.default.fileExists(atPath: widgets.appending(path: "Theme/WidgetDesignTokens.swift").path))
        let files = try #require(FileManager.default.enumerator(at: widgets, includingPropertiesForKeys: nil))
        var offenders: [String] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            let code = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            if code.contains("WDS.") { offenders.append(url.lastPathComponent) }  // «WidgetDS.» no casa: es «tDS.»
        }
        #expect(offenders.isEmpty, "Vuelven al WDS viejo: \(offenders.sorted())")
    }

    /// La tarta de Categorías y Subcategorías (S35f2) pinta en el aro las MISMAS filas que en la leyenda —agrupadas por
    /// `pieLegend` con el total del centro— y «Otros» con su gris. Con los trozos sueltos en el aro, o sin el gris
    /// (`WidgetColors.fill` de un hex vacío da índigo), aro y leyenda dejan de decir lo mismo: lo cazó el banco.
    @Test func laTartaPintaEnElAroLasFilasDeSuLeyenda() throws {
        let code = try Self.source("YalaWidgets/Views/WidgetCategoryBreakdown.swift")
        let body = try #require(code.range(of: "struct WidgetPieBreakdown: View {"))
        let end = code.range(of: "\nstruct ", range: body.upperBound..<code.endIndex)?.lowerBound ?? code.endIndex
        let pie = String(code[body.upperBound..<end])
        #expect(pie.contains("maxRows: Self.maxLegendRows, total: total,"), "La leyenda no agrupa contra el total del centro.")
        #expect(pie.contains("WidgetDonut(slices: rows.map {"), "El aro no pinta las filas de la leyenda.")
        #expect(pie.contains("ForEach(rows) { row in"), "La leyenda no pinta las filas agrupadas.")
        #expect(pie.contains("fixedColor: WidgetColors.othersFill"), "«Otros» pierde su gris.")
        #expect(code.contains("var color: Color { fixedColor ?? WidgetColors.fill(hex: colorHex) }"))
    }
}
