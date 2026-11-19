//
//  FlujoCrearPlanTextosTests.swift
//  YalaTests
//
//  S5 del replanteo: los textos de crear el plan en los 16 idiomas, y el cableado que se retira o se añade (la cabecera
//  «¿Con cuánto empiezas?» con su «Cambiar», el filtro de subcategorías y el límite fijo al crear y al agregar).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · crear plan · textos en los 16 idiomas")
struct FlujoCrearPlanTextosTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    nonisolated static func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func table(_ locale: String) throws -> [String: String] {
        let url = repoRoot().appending(path: "Yala/Resources/\(locale).lproj/FlujoCrearPlan.strings")
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
        #expect(Set(L10n.FlujoCrearPlan.claves) == Set(try Self.table("es").keys))
        for clave in L10n.FlujoCrearPlan.claves {
            #expect(L10n.FlujoCrearPlan.string(clave) != clave, "Clave sin texto: \(clave)")
        }
    }

    @Test(arguments: locales)
    func laApp_resuelveLaTabla(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let texto = L10n.FlujoCrearPlan.string("flujoCrearPlan.hero.label", resolution: resolution)
        #expect(texto == (try Self.table(locale)["flujoCrearPlan.hero.label"]))
    }

    @Test func elPie_diceCuantasCuentas() {
        #expect(L10n.FlujoCrearPlan.pie(cuentas: 0) == L10n.FlujoCrearPlan.string("flujoCrearPlan.hero.caption.none"))
        #expect(L10n.FlujoCrearPlan.pie(cuentas: 1) == L10n.FlujoCrearPlan.string("flujoCrearPlan.hero.caption.one"))
        #expect(L10n.FlujoCrearPlan.pie(cuentas: 3).contains("3"))
    }
}

/// Lo que S5 retira no vuelve, y lo que añade queda cableado.
@Suite("Flujo de caja · crear plan · cableado")
struct FlujoCrearPlanCableadoTests {

    private func source(_ path: String) throws -> String {
        let root = FlujoCrearPlanTextosTests.repoRoot()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        return text.split(separator: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }.joined(separator: "\n")
    }

    private let setupPath = "Yala/App/Views/Reports/CashFlow/CashFlowSetupView.swift"
    private let addLinePath = "Yala/App/Views/Reports/CashFlow/CashFlowAddLineSheet.swift"

    @Test func elArmado_yaNoPreguntaConCuantoEmpiezas() throws {
        let setup = try source(setupPath)
        #expect(!setup.contains("cashflow_setup_change_starting"), "volvió «Cambiar» del saldo inicial")
        #expect(!setup.contains("UXL18.startTitle"), "volvió «¿Con cuánto empiezas?»")
        #expect(!setup.contains("typedStartingBalance"))
        #expect(setup.contains("startingBalance: todayBalance.amount"), "el plan parte del saldo de las cuentas")
        // La hoja sigue para «¿Cuánto recibes al mes?», y solo para eso.
        #expect(setup.components(separatedBy: "CashFlowStartingBalanceSheet(").count == 2)
        #expect(setup.contains("title: L10n.UXL18.incomeQuestionTitle"))
    }

    @Test func elArmado_filtraASubcategorias_alAparecer() throws {
        let setup = try source(setupPath)
        let generate = try #require(setup.range(of: "viewModel.generateSuggestions("))
        let filter = try #require(
            setup.range(of: "viewModel.suggestedLines = FlujoCrearPlanLogica.porSubcategoria(viewModel.suggestedLines)"))
        #expect(generate.lowerBound < filter.lowerBound, "el filtro va después de generar las sugerencias")
    }

    /// Límites móviles (decisión de Jürgen del 19-nov-2026, corrige el P4): crear el plan ya no convierte el promedio en
    /// monto fijo; cada línea guarda su método y la nota lo dice.
    @Test func alCrear_cadaLineaGuardaSuMetodo() throws {
        let setup = try source(setupPath)
        #expect(!setup.contains("FlujoCrearPlanLogica.conLimiteFijo("), "volvió el límite fijo del P4")
        #expect(setup.contains("Text(L10n.FlujoDetalleLinea.limitesMoviles)"))
        #expect(setup.contains("viewModel.createPlan("))
    }

    @Test func elArmado_agrupaPorCategoria() throws {
        let setup = try source(setupPath)
        #expect(setup.contains("FlujoCrearPlanLogica.agrupar("))
        #expect(setup.contains("collapsedGroups.contains(group.id)"))
        #expect(!setup.contains("linesCard("), "las líneas sueltas sin su categoría no vuelven")
    }

    /// Límites móviles (19-nov-2026): la línea nace con el método elegido, que se recalcula cada mes.
    @Test func agregarLinea_naceConSuMetodo_yPideLaSubcategoria() throws {
        let add = try source(addLinePath)
        #expect(add.contains("estimationMethod: selectedMethod,"))
        #expect(!add.contains("estimationMethod: .manual,\n            manualAmount: computePreview(),"),
                "volvió el límite fijo sembrado del P4")
        #expect(add.contains("FlujoCrearPlanLogica.semilla("))
        #expect(add.contains("!FlujoCrearPlanLogica.categoriaSinSubcategorias(cat) && selectedSubcategory == nil"))
    }
}
