//
//  CurrencyNameCapitalizationWiringTests.swift
//  YalaTests
//
//  La moneda se escribe igual en toda Yala (QA físico 2.2, iPhone 14, 9-nov).
//
//  El onboarding pintaba `CurrencyCode.localizedName` tal cual («sol peruano», el texto de los catálogos) y Ajustes ›
//  Cuentas, como otras ~20 pantallas, `currencyInfo(for:).name.capitalized` («Sol Peruano»). Se unificó a lo que ya
//  veía casi toda la app. Este scan fija que ningún `Text` pinte el nombre de una moneda sin `.capitalized`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Nombre de moneda: misma escritura en toda Yala (source-scan)")
struct CurrencyNameCapitalizationWiringTests {

    private static let appRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Yala/App")

    @Test("Todo Text con el nombre de una moneda lleva .capitalized")
    func everyCurrencyNameTextIsCapitalized() throws {
        let walker = try #require(FileManager.default.enumerator(at: Self.appRoot, includingPropertiesForKeys: nil))
        // `currency.localizedName`, `accountCurrency.localizedName`, `info.name` / `currencyInfo(for: x).name`…
        let pattern = #/Text\([^)\n]*(?:[Cc]urrency\.localizedName|info\.name|currencyInfo\(for: [^)]*\)\.name)/#
        var offenders: [String] = []
        var seen = 0
        for case let file as URL in walker where file.pathExtension == "swift" {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//"), code.contains(pattern) else { continue }
                seen += 1
                if !code.contains(".capitalized") {
                    offenders.append("\(file.lastPathComponent):\(index + 1)  \(code)")
                }
            }
        }
        // Control del escenario: el scan tiene que ver las pantallas que ya lo hacían bien, o no prueba nada.
        #expect(seen >= 10,"El scan solo vio \(seen) líneas: el patrón dejó de casar con el código.")
        #expect(offenders.isEmpty, "Nombre de moneda sin capitalizar:\n\(offenders.joined(separator: "\n"))")
    }
}
