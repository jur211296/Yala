//
//  DividirBoletaSinGrupoCableadoTests.swift
//  YalaTests
//
//  Lo que «Dividir una boleta» promete y no se ve en un cálculo: no crea grupos ni guarda personas (ningún
//  `SplitMember`), solo guarda el borrador de mi parte, las dos entradas existen, la imagen no lee `@Environment`, y sus
//  textos viven en la tabla propia de los 16 idiomas. Lee el código FUENTE (`#filePath`).
//

import Foundation
import Testing

@Suite("Dividir una boleta · cableado")
struct DividirBoletaSinGrupoCableadoTests {

    private static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repo.appendingPathComponent(path), encoding: .utf8)
    }

    /// El código sin comentarios: documentar lo prohibido no puede poner rojo el test.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                guard let range = line.range(of: "//") else { return String(line) }
                return String(line[..<range.lowerBound])
            }
            .joined(separator: "\n")
    }

    private static func flowFiles() throws -> [(String, String)] {
        let folders = ["Yala/App/Views/DividirBoleta", "Yala/App/Logic/DividirBoleta"]
        var files: [(String, String)] = []
        for folder in folders {
            let url = repo.appendingPathComponent(folder)
            for name in try FileManager.default.contentsOfDirectory(atPath: url.path) where name.hasSuffix(".swift") {
                files.append(("\(folder)/\(name)", codeOnly(try source("\(folder)/\(name)"))))
            }
        }
        return files
    }

    @Test("Ningún fichero del flujo toca grupos ni miembros guardados")
    func noGroupsNorMembers() throws {
        let files = try Self.flowFiles()
        #expect(files.count >= 7)
        for (path, code) in files {
            for forbidden in ["SplitMember", "SplitGroup", "GroupService", "GroupExpenseService", "SplitExpense("] {
                #expect(!code.contains(forbidden), "\(path) usa \(forbidden)")
            }
        }
    }

    @Test("Lo único que el flujo guarda es el borrador de mi parte")
    func onlyMyShareDraftIsInserted() throws {
        let inserts = try Self.flowFiles().flatMap { path, code in
            code.components(separatedBy: "\n")
                .filter { $0.range(of: #"[Cc]ontext\.insert\("#, options: .regularExpression) != nil }
                .map { (path, $0) }
        }
        // Solo inserciones en un contexto de SwiftData: `assignees.insert(` de un `Set` no guarda nada.
        #expect(inserts.count == 1)
        #expect(inserts.first?.0.hasSuffix("DividirBoletaFlowView.swift") == true)
        #expect(inserts.first?.1.contains("modelContext.insert(draft)") == true)
    }

    @Test("La tarjeta que se rasteriza no lee @Environment")
    func shareCardHasNoEnvironment() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/DividirBoleta/DividirBoletaShareCard.swift"))
        #expect(!code.contains("@Environment"))
        #expect(!code.contains("AmountText"))
        #expect(code.contains("YalaLogo"))
        #expect(code.contains("YalaIconBranded"))
    }

    @Test("Las dos entradas: bajo las fichas de la foto personal y bajo la fila de Grupos")
    func entries() throws {
        let photo = Self.codeOnly(try Self.source("Yala/App/Views/Image/ImageSelectionView.swift"))
        #expect(photo.contains("DividirBoletaEntryButton("))
        #expect(photo.contains("DividirBoletaFlowView("))
        let groups = Self.codeOnly(try Self.source("Yala/App/Views/Groups/GroupsContainerView.swift"))
        #expect(groups.contains("DividirBoletaEntryButton("))
        #expect(groups.contains("allowsRegistering: !sessionState.isGroupsFocusedShell"))
    }

    @Test("Los textos viven en DividirBoleta.strings, con las mismas claves en los 16 idiomas")
    func stringsTableParity() throws {
        let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                       "pt-BR", "pt-PT", "pt", "zh-Hans"]
        func keys(_ locale: String) throws -> Set<String> {
            let url = Self.repo.appendingPathComponent("Yala/Resources/\(locale).lproj/DividirBoleta.strings")
            let dict = try #require(NSDictionary(contentsOf: url) as? [String: String])
            return Set(dict.keys)
        }
        let reference = try keys("es-419")
        #expect(reference.count >= 70)
        for locale in locales {
            #expect(try keys(locale) == reference, "\(locale)")
        }
        let localizable = try Self.source("Yala/Resources/es-419.lproj/Localizable.strings")
        #expect(!localizable.contains("dividirBoleta."))
    }
}
