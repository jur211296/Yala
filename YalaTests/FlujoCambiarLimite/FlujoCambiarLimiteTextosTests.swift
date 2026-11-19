//
//  FlujoCambiarLimiteTextosTests.swift
//  YalaTests
//
//  S4 del replanteo: los textos del alcance de «Monto fijo» en los 16 idiomas, y el cableado que se retira (la hoja de
//  configuración de línea, que nadie abría, el campo con la alerta de alcance del detalle de línea y, desde el
//  19-nov-2026, la hoja «Cambiar límite», que se quedó sin entrada).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · cambiar límite · textos en los 16 idiomas")
struct FlujoCambiarLimiteTextosTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    nonisolated static func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func table(_ locale: String) throws -> [String: String] {
        let url = repoRoot().appending(path: "Yala/Resources/\(locale).lproj/FlujoCambiarLimite.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    private static func placeholders(_ text: String) -> [String] {
        text.matches(of: /%(\d+\$)?[@d]/).map { String($0.output.0) }.sorted()
    }

    @Test(arguments: locales)
    func cadaIdioma_tieneCadaClave_conTexto_yLosMismosHuecos(_ locale: String) throws {
        let referencia = try Self.table("es")
        let textos = try Self.table(locale)
        #expect(Set(textos.keys) == Set(referencia.keys), "\(locale): claves distintas de es.")
        for (clave, valor) in textos {
            #expect(!valor.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(clave) vacía.")
            #expect(Self.placeholders(valor) == Self.placeholders(referencia[clave] ?? ""),
                    "\(locale): \(clave) no tiene los mismos huecos que en español.")
        }
    }

    @Test func alias_copianSuReferencia() throws {
        #expect(try Self.table("es-419") == Self.table("es"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
    }

    @Test func lasClavesDelCodigo_sonLasDeLaTabla() throws {
        #expect(Set(L10n.FlujoCambiarLimite.claves) == Set(try Self.table("es").keys))
        for clave in L10n.FlujoCambiarLimite.claves {
            #expect(L10n.FlujoCambiarLimite.string(clave) != clave, "Clave sin texto: \(clave)")
        }
    }

    @Test(arguments: locales)
    func laApp_resuelveLaTabla(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let texto = L10n.FlujoCambiarLimite.string("flujoCambiarLimite.save", resolution: resolution)
        #expect(texto == (try Self.table(locale)["flujoCambiarLimite.save"]))
    }
}

/// Lo que S4 retira no vuelve: la hoja de configuración de línea y el «Ajustar monto» en línea con su alerta.
@Suite("Flujo de caja · cambiar límite · cableado")
struct FlujoCambiarLimiteCableadoTests {

    private func source(_ path: String) throws -> String {
        let root = FlujoCambiarLimiteTextosTests.repoRoot()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        return text.split(separator: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }.joined(separator: "\n")
    }

    @Test func laHojaDeConfiguracion_seRetiro() throws {
        let root = FlujoCambiarLimiteTextosTests.repoRoot()
        let path = root.appending(path: "Yala/App/Views/Reports/CashFlow/CashFlowLineConfigSheet.swift").path
        #expect(!FileManager.default.fileExists(atPath: path))
        #expect(try !source("Yala/App/Views/Reports/CashFlow/CashFlowTableView.swift").contains("CashFlowLineConfigSheet"))
        #expect(try !source("Yala/App/ViewModels/CashFlowPlanViewModel.swift").contains("showLineConfig"))
    }

    @Test func ajustarMonto_abreLaHojaNueva_sinCampoNiAlerta() throws {
        let detalle = try source("Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift")
        // Desde el 19-nov-2026 el único «Cambiar» abre «Cálculo del monto», que lleva el alcance de esta hoja al
        // escribir un monto fijo (`FlujoCalculoMontoSheet` → `cambiarLimite`).
        #expect(detalle.contains("FlujoCalculoMontoSheet("))
        #expect(detalle.contains("\"cashflow_adjust_amount\""))
        #expect(!detalle.contains("cashflow_adjust_amount_field"))
        #expect(!detalle.contains("showOverrideScopeAlert"))
        #expect(!detalle.contains("setAmountFromMonthOnward"))
    }

    /// La hoja «Cambiar límite» se retiró el 19-nov-2026 (todo pasa por «Cálculo del monto»), y nadie la vuelve a
    /// nombrar. Lo que queda de ella es la escritura, que mira antes si la línea sigue viva (card 1w89).
    @Test func laHojaCambiarLimite_seRetiro_yLaEscrituraMiraLaLinea() throws {
        let root = FlujoCambiarLimiteTextosTests.repoRoot()
        let path = root.appending(path: "Yala/App/Views/Reports/CashFlow/CambiarLimite/FlujoCambiarLimiteSheet.swift").path
        #expect(!FileManager.default.fileExists(atPath: path))
        #expect(try !source("Yala/App/Views/Reports/CashFlow/CalculoMonto/FlujoCalculoMontoSheet.swift")
            .contains("FlujoCambiarLimiteSheet"))
        #expect(try !source("Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift").contains("FlujoCambiarLimiteSheet"))
        let vm = try source("Yala/App/Views/Reports/CashFlow/CambiarLimite/CashFlowPlanViewModel+CambiarLimite.swift")
        #expect(vm.contains("guard !line.isDeleted, let ctx = line.modelContext,"))
    }
}
