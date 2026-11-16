//
//  VoiceOverSelectoresConNombreTests.swift
//  YalaTests
//
//  Card «VoiceOver: cinco selectores sin nombre fuera de Planificación» (2.3). Un selector con título vacío
//  (`Picker("", …)`, `DatePicker("", …)`, `ColorPicker("", …)`, `Toggle("", …)`) es lo que VoiceOver lee sin
//  nombre. Mismo defecto que el lote 04 arregló en Pagos planificados (`PlanningVoiceOverWiringTests`).
//

import Foundation
import Testing

@Suite("VoiceOver · los selectores tienen nombre")
struct VoiceOverSelectoresConNombreTests {

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// Código sin comentarios y con los espacios colapsados: documentar el patrón no lo pone en rojo.
    private static func code(_ path: String) throws -> String {
        try codeOnly(String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
    }

    private static func codeOnly(_ text: String) -> String {
        var raw = text.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
        return raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    /// El barrido: ningún fichero de `Yala/App` declara un selector con título vacío.
    @Test func ningunSelectorDeLaAppTieneTituloVacio() throws {
        let appDir = Self.root.appendingPathComponent("Yala/App")
        let enumerator = try #require(FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil))
        let pattern = try NSRegularExpression(pattern: #"\b(Picker|DatePicker|ColorPicker|Toggle)\(\s*""\s*,"#)
        var offenders: [String] = []
        var scanned = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            scanned += 1
            let source = Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
            let range = NSRange(source.startIndex..., in: source)
            if pattern.firstMatch(in: source, range: range) != nil {
                offenders.append(url.path.replacingOccurrences(of: Self.root.path + "/", with: ""))
            }
        }
        // Control: el barrido leyó la app de verdad (sin esto, una ruta mala daría verde sin mirar nada).
        #expect(scanned > 200, "Solo se leyeron \(scanned) ficheros de Yala/App")
        #expect(offenders.isEmpty, "Selectores sin nombre en: \(offenders)")
    }

    /// Control negativo del patrón: casa con las formas que prohíbe y no con un título real.
    @Test func elPatronDelBarridoDistingueVacioDeNombrado() throws {
        let pattern = try NSRegularExpression(pattern: #"\b(Picker|DatePicker|ColorPicker|Toggle)\(\s*""\s*,"#)
        func matches(_ text: String) -> Bool {
            pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
        #expect(matches(#"Picker("", selection: $x)"#))
        #expect(matches(#"DatePicker( "" , selection: $d)"#))
        #expect(matches(#"ColorPicker("", selection: $c)"#))
        #expect(matches(#"Toggle("", isOn: $b)"#))
        #expect(!matches(#"Picker(L10n.UXL19.splitType, selection: $x)"#))
        #expect(!matches(#"Toggle("Simular Pro", isOn: $b)"#))
    }

    /// Cada uno de los cinco lleva el nombre del rótulo que tiene al lado, también para VoiceOver.
    @Test(arguments: [
        ("Yala/App/Views/Records/RecordsFiltersView.swift",
         "Picker(L10n.VoiceOverSelectores.filterMode, selection: $isEditingHidden)",
         ".accessibilityLabel(L10n.VoiceOverSelectores.filterMode)"),
        ("Yala/App/Views/Groups/GroupFormView.swift",
         "Picker(L10n.UXL19.splitType, selection: $defaultSplitType)",
         ".accessibilityLabel(L10n.UXL19.splitType)"),
        ("Yala/App/Views/Groups/SettlementFormView.swift",
         "Picker(L10n.GroupsNecesarias06.settlementCurrencyA11y, selection: $useSuggestedAmount)",
         ".accessibilityLabel(L10n.GroupsNecesarias06.settlementCurrencyA11y)"),
        ("Yala/App/Views/Reports/CashFlow/CashFlowStartingBalanceSheet.swift",
         "DatePicker(L10n.CashFlowPlan.startingBalanceDateLabel, selection: $balanceDate",
         ".accessibilityLabel(L10n.CashFlowPlan.startingBalanceDateLabel)"),
        ("Yala/App/Views/Shared/IconColorPickerSheet.swift",
         "ColorPicker(L10n.VoiceOverSelectores.customColor, selection: $customColor",
         ".accessibilityLabel(L10n.VoiceOverSelectores.customColor)"),
    ])
    func losCincoSelectoresTienenNombre(path: String, declaration: String, label: String) throws {
        let source = try Self.code(path)
        let start = try #require(source.range(of: declaration), "\(path): falta «\(declaration)»")
        // La etiqueta va pegada a ESE selector, no en otra vista del fichero.
        let tail = String(source[start.upperBound...].prefix(700))
        #expect(tail.contains(label), "\(path): el selector no lleva \(label)")
    }

    /// Los dos textos nuevos existen en los 16 idiomas y no se quedaron en español fuera de él.
    @Test func losTextosNuevosEstanTraducidos() throws {
        let resources = Self.root.appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let file = resources.appendingPathComponent("\(locale)/Localizable.strings")
            let strings = try #require(NSDictionary(contentsOf: file) as? [String: String], "\(locale) no se lee")
            for key in ["a11y.selectores.filterMode", "a11y.selectores.customColor"] {
                let value = try #require(strings[key], "\(locale): falta \(key)")
                if !locale.hasPrefix("es") {
                    #expect(value != "Modo del filtro" && value != "Color personalizado", "\(locale): \(key) sin traducir")
                }
            }
        }
    }
}
