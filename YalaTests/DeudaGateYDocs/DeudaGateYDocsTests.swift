//
//  DeudaGateYDocsTests.swift
//  YalaTests / DeudaGateYDocs
//
//  Deuda de 2.3 (27-nov-2026), dos de sus cinco arreglos:
//  (1) `rfr.planning.fromRecord` («Desde un registro») y `rfr.picker.footer` (el pie viejo de «Elige un registro») ya
//      no los pintaba nadie: solo sus accesores. Se borraron con su clave en los 16 idiomas, y aquí no vuelven.
//  (2) `/gate` reinicia el simulador entre la suite unitaria y la de interfaz, que moría con «AX loaded» tras la
//      unitaria entera. Se fija que el paso 3 llama a `sim-reiniciar.sh` antes de cada XCUITest y que el script pide
//      el turno del simulador antes de apagarlo.
//

import Foundation
import Testing

@testable import Yala

@Suite("Deuda de 2.3 · textos sin uso y reinicio del simulador en el gate")
struct DeudaGateYDocsTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func read(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8)
    }

    private static let borradas = ["rfr.planning.fromRecord", "rfr.picker.footer"]

    // MARK: - 1. Textos sin uso

    @Test func lasDosClavesNoEstanEnNingunIdioma() throws {
        let resources = Self.root.appendingPathComponent("Yala/Resources")
        let lprojs = try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") }
            .filter { FileManager.default.fileExists(atPath: resources.appendingPathComponent("\($0)/Localizable.strings").path) }
        #expect(lprojs.count == 16, "se esperaban 16 idiomas con Localizable.strings: \(lprojs.sorted())")
        for lproj in lprojs {
            let strings = try read("Yala/Resources/\(lproj)/Localizable.strings")
            // Control positivo: el resto de los textos de «Hacer recurrente» sigue ahí.
            #expect(strings.contains("\"rfr.picker.title\""), "\(lproj) perdió rfr.picker.title")
            for key in Self.borradas {
                #expect(!strings.contains("\"\(key)\""), "\(lproj) sigue con \(key)")
            }
        }
    }

    @Test func ningunCodigoPideLasClavesBorradas() throws {
        let accesores = try read("Yala/Utils/L10n+RecurrenteDesdeRegistro.swift")
        #expect(accesores.contains("rfr.picker.title"))
        for key in Self.borradas {
            #expect(!accesores.contains(key))
        }
        #expect(!accesores.contains("static var fromRecord"))
        #expect(!accesores.contains("static var pickerFooter"))
    }

    @Test func elBundleYaNoResuelveLasClaves() {
        // Resuelta, una clave devuelve su texto; ausente, la propia clave (el centinela de `NSLocalizedString`).
        let sentinel = "__AUSENTE__"
        #expect(NSLocalizedString("rfr.picker.title", bundle: .main, value: sentinel, comment: "") != sentinel)
        for key in Self.borradas {
            #expect(NSLocalizedString(key, bundle: .main, value: sentinel, comment: "") == sentinel)
        }
    }

    // MARK: - 2. El gate reinicia el simulador antes de la interfaz

    @Test func elPaso3ReiniciaAntesDeCadaXCUITest() throws {
        let gate = try read(".claude/commands/gate.md")
        #expect(gate.contains("Bash(bash qa/scripts/sim-reiniciar.sh:*)"), "falta en allowed-tools")
        let paso2 = try #require(gate.range(of: "## 2 · Unit tests"))
        let paso3 = try #require(gate.range(of: "## 3 · XCUITest de lo tocado"))
        let paso4 = try #require(gate.range(of: "## 4 · Audit de calidad"))
        #expect(gate[paso2.upperBound..<paso3.lowerBound].contains("sim-reiniciar.sh") == false,
                "el reinicio va entre las fases, no dentro de la unitaria")
        let tramo = String(gate[paso3.upperBound..<paso4.lowerBound])
        let lineas = tramo.components(separatedBy: "\n")
        // Cada `xcodebuild … test` de interfaz del paso 3 lleva delante, en su bloque, el reinicio.
        let xcuitest = lineas.indices.filter { lineas[$0].contains("sim-lock.sh --") }
        #expect(xcuitest.count >= 2)
        for indice in xcuitest {
            let anterior = lineas[..<indice].lastIndex { $0.contains("sim-reiniciar.sh") }
            let inicioBloque = lineas[..<indice].lastIndex { $0.hasPrefix("```") }
            guard let anterior, let inicioBloque else {
                Issue.record("el XCUITest de la línea \(indice) del paso 3 no tiene reinicio ni bloque delante")
                continue
            }
            #expect(anterior > inicioBloque, "el XCUITest de la línea \(indice) del paso 3 no reinicia antes")
        }
    }

    @Test func elScriptPideElTurnoAntesDeApagar() throws {
        let script = try read("qa/scripts/sim-reiniciar.sh")
        let turno = try #require(script.range(of: "exec bash \"$DIR/sim-lock.sh\" --"))
        let apagar = try #require(script.range(of: "simctl shutdown"))
        let arrancar = try #require(script.range(of: "simctl bootstatus \"$udid\" -b"))
        #expect(turno.lowerBound < apagar.lowerBound)
        #expect(apagar.lowerBound < arrancar.lowerBound)
        #expect(script.contains("TECHO_SEGUNDOS"), "la espera del arranque necesita techo")
    }
}
