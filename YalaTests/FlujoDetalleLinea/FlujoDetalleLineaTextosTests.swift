//
//  FlujoDetalleLineaTextosTests.swift
//  YalaTests
//
//  S3 del replanteo: los textos del detalle de línea en los 16 idiomas, y el cableado de la hoja (lo que se retiró y lo
//  que la sostiene: el límite arriba con «Cambiar», todos los registros, los seis meses, «Ver en Registros»).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · detalle de línea · textos y cableado")
struct FlujoDetalleLineaTextosTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    nonisolated static func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func table(_ locale: String) throws -> [String: String] {
        let url = repoRoot().appending(path: "Yala/Resources/\(locale).lproj/FlujoDetalleLinea.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot().appending(path: path), encoding: .utf8)
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
        #expect(try Self.table("en-GB") == Self.table("en"))
    }

    @Test func lasClavesDelCodigo_sonLasDeLaTabla() throws {
        #expect(Set(L10n.FlujoDetalleLinea.claves) == Set(try Self.table("es").keys))
        for clave in L10n.FlujoDetalleLinea.claves {
            #expect(L10n.FlujoDetalleLinea.string(clave) != clave, "Clave sin texto: \(clave)")
        }
    }

    /// Los textos nuevos viven en su tabla, nunca en `Localizable.strings`.
    @Test func ningunaClaveEnLocalizable() throws {
        let localizable = try Self.source("Yala/Resources/es.lproj/Localizable.strings")
        #expect(!localizable.contains("flujoDetalleLinea."))
    }

    // MARK: - Cableado de la hoja

    @Test func laHojaEnseñaTodosLosRegistros_yYaNoLosCincoUltimos() throws {
        let hoja = try Self.source("Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift")
        #expect(hoja.contains("FlujoDetalleLineaRegistrosView("))
        #expect(!hoja.contains("prefix(5)"))
        #expect(!hoja.contains("cellDetailRecentTransactions"))
        // Los registros salen del reparto del motor, no de filtrar por categoría a mano.
        #expect(hoja.contains("FlujoDetalleLineaLogica.registros("))
        #expect(!hoja.contains("tx.category?.persistentModelID == cat.persistentModelID"))
    }

    @Test func elLimiteVaArribaConCambiar_queAbreLaHojaDeS4() throws {
        let hoja = try Self.source("Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift")
        #expect(hoja.contains("FlujoCambiarLimiteSheet("))
        #expect(hoja.contains("\"cashflow_adjust_amount\""))
        #expect(!hoja.contains("L10n.CashFlowPlan.adjustAmount"))
        // La tarjeta del límite va antes que la gráfica y que los registros.
        let limite = try #require(hoja.range(of: "limitCard(m: m, lr: lr)"))
        let grafica = try #require(hoja.range(of: "FlujoDetalleLineaSeisMesesView("))
        let lista = try #require(hoja.range(of: "FlujoDetalleLineaRegistrosView("))
        #expect(limite.lowerBound < grafica.lowerBound)
        #expect(grafica.lowerBound < lista.lowerBound)
    }

    /// La gráfica diaria sumaba magnitudes sin convertir (una devolución sumaba): se retiró con la tira de ±2 meses.
    @Test func seRetiranLaGraficaDiaria_yLaTiraDeMeses() throws {
        let path = Self.repoRoot().appending(path: "Yala/App/Views/Reports/CashFlow/CashFlowCellMiniChart.swift").path
        #expect(!FileManager.default.fileExists(atPath: path))
        let hoja = try Self.source("Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift")
        #expect(!hoja.contains("monthTimeline"))
        #expect(!hoja.contains("cashflow_detail_timeline_"))
    }

    /// Los datos se calculan al cambiar de mes o de plan (`.task(id:)`), no en cada pasada del `body`.
    @Test func losDatosNoSeCalculanEnElBody() throws {
        let hoja = try Self.source("Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift")
        #expect(hoja.contains(".task(id: dataKey) { loadData() }"))
        #expect(hoja.components(separatedBy: "FlujoDetalleLineaLogica.seisMeses(").count == 2)
    }

    /// «Ver en Registros» escribe el filtro de la subcategoría y el período, y cambia a la pestaña de Registros.
    @Test func verEnRegistros_filtraYAbreRegistros() throws {
        let hoja = try Self.source("Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift")
        #expect(hoja.contains("session.selectedSubcategoryIDs = [sub.persistentModelID]"))
        #expect(hoja.contains("session.choosePeriod("))
        #expect(hoja.contains("navigation.selectMainTab(.records)"))
    }
}
