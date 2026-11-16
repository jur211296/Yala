//
//  NuevoRegistroCodigoMuertoTests.swift
//  YalaTests
//
//  Revisión 2.3 · Nuevo registro, decisión 82 del 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`):
//  `TransactionAmountInputView` —un importe con su propio selector de divisa— no lo usaba nadie desde que el formulario
//  pinta su importe, y se borró. Source-scan: no vuelve, ni su fichero ni el tipo en otro sitio.
//

import Foundation
import Testing

@Suite("Nuevo registro 2.3 — sin la vista de importe muerta (source-scan)")
struct NuevoRegistroCodigoMuertoTests {

    private static let repoRoot: URL = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent()

    @Test func theDeadAmountInputView_isGone() throws {
        let path = "Yala/App/Views/Transactions/Components/TransactionAmountInputView.swift"
        #expect(!FileManager.default.fileExists(atPath: Self.repoRoot.appending(path: path).path),
                "Volvió el fichero de la vista de importe sin uso: \(path)")

        let app = Self.repoRoot.appending(path: "Yala")
        let files = try #require(FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        #expect(files.count > 100, "El recorrido no encontró el código: el scan no estaría mirando nada.")
        let declaring = try files.filter { url in
            try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.hasPrefix("//") }
                .contains { $0.contains("struct TransactionAmountInputView") }
        }
        #expect(declaring.isEmpty, "Alguien volvió a declarar la vista de importe sin uso: \(declaring.map(\.lastPathComponent))")
    }
}
