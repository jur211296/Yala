//
//  PanelMarcasEnReleaseTests.swift
//  YalaTests
//
//  El archivo de Yala 2.3 (12) no compilaba en Release: `PanelViewModel.marcasEnCurso` (lote 4 de eficiencia,
//  26-nov-2026) estaba declarada dentro de un `#if DEBUG` y se usa fuera, en `performCalculationInStages` y en la
//  tendencia. Las pruebas y el CI compilan en Debug, así que nada lo vio hasta archivar. Esta prueba lee el fuente:
//  la declaración tiene que quedar fuera de todo bloque `#if DEBUG`.
//

import Foundation
import Testing

@Suite("Release · las marcas del recálculo del Panel no dependen de DEBUG")
struct PanelMarcasEnReleaseTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // CIRojo23Build12/
        .deletingLastPathComponent()  // YalaTests/
        .deletingLastPathComponent()  // raíz del repo

    /// Profundidad de `#if DEBUG` en cada línea: cuenta los `#if DEBUG` abiertos y los cierra con su `#endif` (un
    /// `#if` de otra condición abre un nivel que no es DEBUG, para emparejar bien los `#endif`).
    private static func debugDepthByLine(_ source: String) -> [Bool] {
        var stack: [Bool] = []
        var result: [Bool] = []
        for raw in source.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if ") {
                stack.append(line == "#if DEBUG")
            } else if line.hasPrefix("#endif"), !stack.isEmpty {
                stack.removeLast()
            }
            result.append(stack.contains(true))
        }
        return result
    }

    @Test func marcasEnCurso_seDeclaraFueraDeDEBUG() throws {
        let url = Self.root.appendingPathComponent("Yala/App/ViewModels/PanelViewModel.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let lines = source.components(separatedBy: "\n")
        let inDebug = Self.debugDepthByLine(source)
        let declarations = lines.indices.filter { lines[$0].contains("var marcasEnCurso:") }
        #expect(declarations.count == 1, "Se esperaba una sola declaración de marcasEnCurso.")
        for index in declarations {
            #expect(!inDebug[index], "marcasEnCurso está dentro de #if DEBUG (línea \(index + 1)): Release no compila.")
        }
        // Control: el contador de cálculos SÍ vive en DEBUG; si el detector no lo viera, la prueba no mediría nada.
        let control = try #require(lines.firstIndex { $0.contains("var debugCalculationsStarted") })
        #expect(inDebug[control], "El detector de #if DEBUG no ve el bloque del contador.")
    }
}
