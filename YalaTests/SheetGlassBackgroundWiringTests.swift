//
//  SheetGlassBackgroundWiringTests.swift
//  YalaTests
//
//  Hojas a media altura en glass, como «Configurar panel» (Jürgen, 2026-10-30, card g1uw): los selectores de Cuenta y
//  Categoría de Nuevo gasto de Grupos y el de cuenta de Yala IA salían con un gris sólido. Lo pintaba un material grueso
//  puesto como fondo de presentación (`SelectorSheetSizing`) y, en otras hojas, un fondo opaco en la raíz.
//
//  Source-scan: ninguna vista pinta fondo de presentación salvo el aviso de Bandeja (`.clear`, su propio telón), y las
//  hojas arregladas no vuelven a un fondo opaco a media altura.
//

import Foundation
import Testing

@Suite("Hojas a media altura en glass — cableado (source-scan)")
struct SheetGlassBackgroundWiringTests {

    private static let repoRoot: URL = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent()

    /// Las líneas de código, sin comentarios, para que documentar el patrón no cuente como usarlo.
    private static func codeLines(_ path: String) throws -> [String] {
        try String(contentsOf: repoRoot.appending(path: path), encoding: .utf8).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
    }

    /// Un `presentationBackground` tapa el Liquid Glass de la hoja. Solo se admite el `.clear` del aviso de Bandeja y el
    /// helper `glassSheet()` (sin usos).
    @Test func noView_paintsAPresentationBackground() throws {
        let app = Self.repoRoot.appending(path: "Yala/App")
        let files = try #require(FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        #expect(files.count > 100, "El recorrido no encontró las vistas: el scan no estaría mirando nada.")
        let allowed: Set<String> = [
            "Yala/App/ContentView.swift|.presentationBackground(.clear)",
            "Yala/App/DesignSystem/GlassSheetModifier.swift|.presentationBackground(.ultraThinMaterial)",
        ]
        var offenders: [String] = []
        for url in files {
            let relative = String(url.path.dropFirst(Self.repoRoot.path.count + 1))
            for line in try Self.codeLines(relative) where line.contains(".presentationBackground") {
                if !allowed.contains("\(relative)|\(line)") { offenders.append("\(relative): \(line)") }
            }
        }
        #expect(offenders.isEmpty, "Hoja con fondo de presentación (sale gris, no glass): \(offenders)")
    }

    /// `glassSheet()` pone un material encima del glass: nadie lo usa, y así sigue.
    @Test func noView_usesGlassSheet() throws {
        let app = Self.repoRoot.appending(path: "Yala/App")
        let files = try #require(FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        #expect(files.count > 100, "El recorrido no encontró las vistas.")
        let offenders = try files.filter { url in
            try Self.codeLines(String(url.path.dropFirst(Self.repoRoot.path.count + 1)))
                .contains { $0.contains(".glassSheet(") }
        }
        #expect(offenders.isEmpty, "Una hoja usa glassSheet(), que tapa el glass del sistema: \(offenders.map(\.lastPathComponent))")
    }

    /// Los selectores de registro no vuelven al material de L2-22.
    @Test func recordSelectors_leaveTheSystemGlass() throws {
        let code = try Self.codeLines("Yala/App/Views/Transactions/SelectorSheetSizing.swift")
        #expect(code.count > 30, "No se leyó SelectorSheetSizing.")
        #expect(!code.contains { $0.contains("Material") }, "SelectorSheetSizing vuelve a pintar un material.")
        #expect(code.contains { $0.contains(".yalaSheetDetents(detents, selection: $selectedDetent)") })
    }

    /// Las hojas que se presentan a media altura y pintaban la raíz opaca.
    @Test func partialSheets_doNotPaintAnOpaqueRoot() throws {
        let cases: [(path: String, expected: String, forbidden: String)] = [
            ("Yala/App/Views/Groups/MemberPickerView.swift", ".yalaScreenBackground(selectedDetent == .large ? .subtle : .transparent)", ".yalaScreenBackground(.subtle)"),
            ("Yala/App/Views/Groups/GroupPickerSheet.swift", ".yalaScreenBackground(background)", ".yalaScreenBackground(.subtle)"),
            ("Yala/App/Views/Filters/PeriodSelectorComponents.swift", ".yalaScreenBackground(.partialSheet)", ".background(.thCard)"),
        ]
        for c in cases {
            let code = try Self.codeLines(c.path)
            #expect(code.contains(c.expected), "\(c.path): falta \(c.expected)")
            #expect(!code.contains(c.forbidden), "\(c.path): vuelve \(c.forbidden)")
        }
        let inbox = try Self.codeLines("Yala/App/Views/Inbox/InboxView.swift")
        let composer = try Self.codeLines("Yala/App/Views/Groups/GroupExpenseComposerView.swift")
        #expect(inbox.contains("opensAtMediumHeight: true"), "El selector de grupo de la Bandeja deja de abrir a media altura en glass.")
        #expect(composer.contains("opensAtMediumHeight: true"), "El selector de grupo de Nuevo gasto deja de abrir a media altura en glass.")
        let picker = try Self.codeLines("Yala/App/Views/Groups/GroupPickerSheet.swift")
        #expect(picker.contains("return selectedDetent == .large || usesLargeSheets ? .subtle : .transparent"),
                "El selector de grupo no sigue el fondo de «Configurar panel» por detent.")
        let favorite = try Self.codeLines("Yala/App/Views/Transactions/SaveAsFavoriteSheet.swift")
        #expect(favorite.contains(".yalaScreenBackground(tagSheetDetent == .large || usesLargeSheets ? .subtle : .transparent)"),
                "Las etiquetas de Guardar favorito no siguen el fondo de «Configurar panel».")
        let export = try Self.codeLines("Yala/App/Views/ExportWizard/ExportRecordsView.swift")
        // La hoja de período es el último tipo del fichero: de su declaración al final.
        let exportPicker = try #require(export.firstIndex { $0.contains("struct ExportCustomPeriodPickerSheet") },
                                        "No se encontró la hoja de período de Exportar.")
        let exportBody = Array(export[exportPicker...])
        #expect(exportBody.contains(".yalaScreenBackground(.partialSheet)"), "El período de Exportar pierde su fondo de hoja parcial.")
        #expect(!exportBody.contains(".background(.thCard)"), "El período de Exportar vuelve a pintar la hoja entera.")
    }
}
