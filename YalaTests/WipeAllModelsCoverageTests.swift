//
//  WipeAllModelsCoverageTests.swift
//  YalaTests
//
//  Pinnea que `wipeAllModels` (TestHelpers.swift) borra TODOS los modelos del schema.
//
//  Por qué existe: `makeTestContext()` reusa el `ModelContainer` por `#fileID` —eso es
//  deliberado, evita el `EXC_BREAKPOINT` por acumulación de containers in-memory— así que el
//  aislamiento entre tests del mismo fichero descansa ENTERO en que `wipeAllModels` vacíe de
//  verdad. Hasta el 2026-09-02 vaciaba 22 de los 31 modelos del schema, y los nueve que
//  faltaban eran los de sync y migración. El síntoma fue un rojo que sólo salía en CI
//  (`HandoverGroupsDomainTests.wipeLocalGroupsDomain_killsTheOutbox_butKEEPSTheCursor` contaba
//  dos `GroupSyncCursor` donde esperaba uno), porque `.serialized` garantiza que los tests no
//  se solapen pero NO en qué orden corren.
//
//  Es un source-scan a propósito: el fallo que persigue es que alguien añada un `@Model` al
//  schema y no lo añada aquí. Eso no lo caza ningún test de comportamiento — lo caza, meses
//  después, un rojo intermitente en otra suite.
//

import Foundation
import Testing

@testable import Yala

@Suite("Aislamiento · wipeAllModels cubre el schema entero (source-scan)")
struct WipeAllModelsCoverageTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// `Category` y `Tag` colisionan con tipos de Foundation/SwiftUI, así que `TestHelpers.swift`
    /// los renombra (`typealias YalaCategory = Yala.Category`, `:15-16`). El escáner deshace ese
    /// alias antes de comparar; si no, daría dos falsos positivos permanentes.
    private static let alias: [String: String] = [
        "YalaCategory": "Category",
        "YalaTag": "Tag"
    ]

    /// Modelos declarados en `SwiftDataConfiguration.schema`.
    private static func modelosDelSchema() throws -> Set<String> {
        let src = try code("Yala/Utils/SwiftDataConfiguration.swift")
        guard let inicio = src.range(of: "static var schema") else {
            Issue.record("no se encontró `static var schema` — ¿se renombró?")
            return []
        }
        // Del `static var schema` hasta el cierre de su array literal.
        let resto = src[inicio.upperBound...]
        guard let fin = resto.range(of: "])") else {
            Issue.record("no se encontró el cierre del array de `schema`")
            return []
        }
        let cuerpo = resto[..<fin.lowerBound]
        return Set(
            cuerpo
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
                .components(separatedBy: ".self")
                .dropLast()
                .compactMap { fragmento in
                    fragmento
                        .components(separatedBy: CharacterSet.alphanumerics.inverted)
                        .last
                        .flatMap { $0.isEmpty ? nil : $0 }
                }
        )
    }

    /// Modelos que `wipeAllModels` borra de verdad.
    private static func modelosBorrados() throws -> Set<String> {
        let src = try code("YalaTests/TestHelpers.swift")
        var encontrados: Set<String> = []
        var resto = Substring(src)
        while let r = resto.range(of: "wipe(") {
            let cola = resto[r.upperBound...]
            if let punto = cola.range(of: ".self") {
                let nombre = String(cola[..<punto.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                // `func wipe<T: PersistentModel>(_ type: T.Type)` también casa con "wipe(": se
                // descarta porque su argumento no es un identificador de modelo.
                if !nombre.isEmpty, nombre.allSatisfy({ $0.isLetter || $0.isNumber }) {
                    encontrados.insert(alias[nombre] ?? nombre)
                }
            }
            resto = resto[r.upperBound...]
        }
        return encontrados
    }

    @Test("todo modelo del schema se borra entre tests")
    func wipeCoversEveryModelInTheSchema() throws {
        let schema = try Self.modelosDelSchema()
        let borrados = try Self.modelosBorrados()

        // Control positivo: si el escáner no encuentra nada, la comparación de abajo pasaría
        // en verde sin haber comprobado nada. Es el modo de fallo clásico de un source-scan.
        #expect(schema.count >= 25, "el escáner del schema encontró \(schema.count) modelos; esperaba el schema entero. ¿Cambió la forma de `SwiftDataConfiguration.schema`?")
        #expect(borrados.count >= 25, "el escáner de `wipeAllModels` encontró \(borrados.count) llamadas; esperaba una por modelo.")

        let sinBorrar = schema.subtracting(borrados).sorted()
        #expect(sinBorrar.isEmpty, """
            estos modelos del schema NO se borran entre tests: \(sinBorrar).

            `makeTestContext()` reusa el container por `#fileID`, así que una fila de estos
            sobrevive de un test al siguiente del mismo fichero y contamina sus conteos. Añádelos
            a `wipeAllModels` en `YalaTests/TestHelpers.swift`.
            """)
    }

    @Test("el escáner no inventa modelos que el schema no tiene")
    func wipeDoesNotTargetGhosts() throws {
        let schema = try Self.modelosDelSchema()
        let borrados = try Self.modelosBorrados()
        let fantasmas = borrados.subtracting(schema).sorted()
        #expect(fantasmas.isEmpty, """
            `wipeAllModels` borra tipos que no están en el schema: \(fantasmas). O sobran, o el
            escáner del schema dejó de leerlo bien — y en ese segundo caso el test de arriba
            estaría pasando en verde sin comprobar nada.
            """)
    }
}
