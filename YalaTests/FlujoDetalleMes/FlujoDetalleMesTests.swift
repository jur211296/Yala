//
//  FlujoDetalleMesTests.swift
//  YalaTests
//
//  S2 del replanteo del flujo de caja (18-nov-2026): el detalle del mes cuenta una sola historia —«Empezaste con · Entró ·
//  Salió · Terminas con»— y la tabla agrupa por categoría con la subcategoría como fila base.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@MainActor
@Suite("Flujo de caja · detalle del mes · la historia")
struct FlujoDetalleMesHistoriaTests {

    private func mes(
        past: Bool = false, current: Bool = false,
        income: Double, expense: Double, realIncome: Double = 0, realExpense: Double = 0,
        opening: Double?, closing: Double?
    ) -> CashFlowMonth {
        CashFlowMonth(
            monthKey: "2026-11", date: Date(timeIntervalSince1970: 1_793_000_000), isPast: past, isCurrent: current,
            incomeLines: [], expenseLines: [], otherExpenses: nil, otherIncome: nil,
            totalIncome: income, totalExpense: expense, netFlow: income - expense,
            accumulatedBalance: closing, openingBalance: opening,
            realIncome: realIncome, realExpense: realExpense
        )
    }

    @Test func unMesCerrado_esTodoReal_yCuadra() {
        let h = FlujoDetalleMesLogica.historia(mes(past: true, income: 3_000, expense: 2_100, realIncome: 3_000,
                                                   realExpense: 2_100, opening: 10_000, closing: 10_900))
        #expect(h.tiempo == .pasado)
        #expect(h.entro == .init(real: 3_000, estimado: 0))
        #expect(h.salio == .init(real: 2_100, estimado: 0))
        #expect(h.empezaste == 10_000)
        #expect(h.terminas == 10_900)
        #expect(h.ajuste == nil)
        #expect(!h.esEstimada)
        #expect(FlujoDetalleMesLogica.textoCapsula(h) == YalaFormatter.amountCompactTable(value: 10_900))
    }

    /// El mes en curso: lo real hasta hoy y lo que falta, estimado. La cifra grande es «Al 30» (la del motor).
    @Test func elMesEnCurso_separaLoRealDeLoQueFalta() {
        let h = FlujoDetalleMesLogica.historia(mes(current: true, income: 3_000, expense: 2_500, realIncome: 2_000,
                                                   realExpense: 1_200, opening: 10_000, closing: 10_500))
        #expect(h.tiempo == .enCurso)
        #expect(h.entro == .init(real: 2_000, estimado: 1_000))
        #expect(h.salio == .init(real: 1_200, estimado: 1_300))
        #expect(h.entro.tieneEstimado && h.salio.tieneEstimado)
        #expect(h.ajuste == nil)
        #expect(h.esEstimada)
        #expect(FlujoDetalleMesLogica.textoCapsula(h).hasPrefix("≈ "))
    }

    /// Lo que entró y salió no explica todo el saldo (un ajuste de saldo, un movimiento sin cuenta): la historia lo dice
    /// en una fila propia para que la suma dé «Terminas con».
    @Test func siLaSumaNoCuadra_hayUnaFilaDeAjustes() {
        let h = FlujoDetalleMesLogica.historia(mes(past: true, income: 3_000, expense: 2_100, realIncome: 3_000,
                                                   realExpense: 2_100, opening: 10_000, closing: 11_150))
        #expect(h.ajuste == 250)
        let suma = (h.empezaste ?? 0) + h.entro.total - h.salio.total + (h.ajuste ?? 0)
        #expect(abs(suma - (h.terminas ?? 0)) < 0.001)
    }

    @Test func unResiduoDeComaFlotante_noEsUnAjuste() {
        let h = FlujoDetalleMesLogica.historia(mes(past: true, income: 0.1 + 0.2, expense: 0, realIncome: 0.3,
                                                   opening: 0, closing: 0.3))
        #expect(h.ajuste == nil)
    }

    @Test func unMesQueViene_esTodoEstimado() {
        let h = FlujoDetalleMesLogica.historia(mes(income: 3_000, expense: 2_600, opening: 10_500, closing: 10_900))
        #expect(h.tiempo == .futuro)
        #expect(h.entro == .init(real: 0, estimado: 3_000))
        #expect(h.salio == .init(real: 0, estimado: 2_600))
        #expect(h.esEstimada)
        #expect(h.ajuste == nil)
    }

    /// Sin cuentas que sumen no hay «Empezaste» honesto: la cifra es lo que queda, como antes.
    @Test func sinCuentas_laCifraEsElNeto() {
        let h = FlujoDetalleMesLogica.historia(mes(current: true, income: 3_000, expense: 3_400, realIncome: 1_000,
                                                   realExpense: 900, opening: nil, closing: nil))
        #expect(h.empezaste == nil && h.terminas == nil && h.ajuste == nil)
        #expect(h.cifra == -400)
        #expect(FlujoDetalleMesLogica.textoCapsula(h) == CashFlowMonthSummaryLogic.capsuleNetText(-400))
    }
}

@MainActor
@Suite("Flujo de caja · detalle del mes · tabla por categoría", .serialized)
struct FlujoDetalleMesTablaTests {

    private func linea(_ id: UUID, _ name: String) -> CashFlowLineResult {
        CashFlowLineResult(
            lineID: id, name: name, isIncome: false, plannedAmount: 100, realAmount: 40, difference: nil,
            differencePercent: nil, progress: nil, isOverride: false, estimationMethod: .manual,
            subcategoryBreakdown: nil
        )
    }

    @Test func cadaCategoriaAgrupaSusLineas_yLasSinCategoriaVanAparte() throws {
        let context = try makeTestContext()
        let comida = Category(name: "Comida", colorHex: "#FF0000", isIncome: false)
        let casa = Category(name: "Casa", colorHex: "#00FF00", isIncome: false)
        context.insert(comida)
        context.insert(casa)
        try context.save()
        let (a, b, c, libre) = (UUID(), UUID(), UUID(), UUID())
        let lineas = [linea(a, "Mercado"), linea(libre, "Varios"), linea(b, "Restaurantes"), linea(c, "Luz")]
        let grupos = [
            CashFlowCategoryGroup(categoryID: comida.persistentModelID, categoryName: "Comida", isIncome: false,
                                  lineIDs: [a, b], plannedAmount: 200, realAmount: 130, expectedAmount: 230,
                                  unassignedAmount: 30),
            CashFlowCategoryGroup(categoryID: casa.persistentModelID, categoryName: "Casa", isIncome: false,
                                  lineIDs: [c], plannedAmount: 100, realAmount: 40, expectedAmount: 100,
                                  unassignedAmount: 0)
        ]
        let tabla = FlujoDetalleMesLogica.tabla(lineas: lineas, grupos: grupos)
        #expect(tabla.grupos.map(\.nombre) == ["Comida", "Casa"])
        #expect(tabla.grupos[0].lineas.map(\.lineID) == [a, b])
        #expect(tabla.grupos[0].sinSubcategoria == 30)
        #expect(tabla.grupos[0].total == 230)
        #expect(tabla.grupos[1].sinSubcategoria == nil)
        #expect(tabla.sueltas.map(\.lineID) == [libre])
    }

    @Test func unGrupoSinLineasVisibles_noSePinta() throws {
        let context = try makeTestContext()
        let cat = Category(name: "Ocio", colorHex: "#0000FF", isIncome: false)
        context.insert(cat)
        try context.save()
        let grupos = [CashFlowCategoryGroup(categoryID: cat.persistentModelID, categoryName: "Ocio", isIncome: false,
                                            lineIDs: [UUID()], plannedAmount: 0, realAmount: 0, expectedAmount: 0,
                                            unassignedAmount: 0)]
        #expect(FlujoDetalleMesLogica.tabla(lineas: [], grupos: grupos).grupos.isEmpty)
    }
}

@MainActor
@Suite("Flujo de caja · detalle del mes · textos en los 16 idiomas")
struct FlujoDetalleMesTextosTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    nonisolated static func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func table(_ locale: String) throws -> [String: String] {
        let url = repoRoot().appending(path: "Yala/Resources/\(locale).lproj/FlujoDetalleMes.strings")
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

    @Test func cadaClaveDelCodigo_existe() throws {
        typealias T = L10n.FlujoDetalleMes
        var textos = [T.faltaEntrar, T.faltaSalir, T.ajustes, T.estimado, T.lineas(3)]
        for tiempo in [FlujoDetalleMesLogica.Tiempo.pasado, .enCurso, .futuro] {
            textos += [T.empezaste(tiempo), T.entro(tiempo), T.salio(tiempo), T.terminas(tiempo)]
        }
        for texto in textos {
            #expect(!texto.hasPrefix("flujoDetalleMes."), "Clave sin texto: \(texto)")
        }
        #expect(try Self.table("es").count == textos.count)
    }

    @Test(arguments: locales)
    func laApp_resuelveLaTabla(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let texto = L10n.FlujoDetalleMes.string("flujoDetalleMes.adjustment", resolution: resolution)
        #expect(texto == (try Self.table(locale)["flujoDetalleMes.adjustment"]))
    }
}

/// Lo que S2 retira no vuelve: las tres cifras de «cómo acabo el mes» y el «Empezaste con · Cambiar» del saldo manual.
@Suite("Flujo de caja · detalle del mes · cableado")
struct FlujoDetalleMesCableadoTests {

    private func source(_ path: String) throws -> String {
        let root = FlujoDetalleMesTextosTests.repoRoot()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        // Sin comentarios: documentar lo que se quitó no lo vuelve a poner.
        return text.split(separator: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
                && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("///")
        }.joined(separator: "\n")
    }

    @Test func elDetalleDelMes_noTraeLasCifrasRetiradas() throws {
        let detalle = try source("Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift")
        for retirado in ["UXL18.startedWith", "UXL18.projectedEnd", "cashflow_change_starting_balance",
                         "cashflow_month_net_line", "monthEndBreakdown"] {
            #expect(!detalle.contains(retirado), "Volvió \(retirado) al detalle del mes.")
        }
        #expect(detalle.contains("FlujoDetalleMesLogica.historia("))
        #expect(detalle.contains("FlujoDetalleMesHistoriaView("))
        #expect(detalle.contains("FlujoDetalleMesLogica.tabla("))
    }

    @Test func laCapsula_diceLaCifraDeLaHistoria() throws {
        let capsula = try source("Yala/App/Views/Reports/CashFlow/CashFlowMonthCapsule.swift")
        #expect(capsula.contains("FlujoDetalleMesLogica.textoCapsula("))
    }

    /// La barra de «Comparativa / Flujo de caja» difumina lo que pasa por debajo: con `safeAreaInset` el texto de las
    /// filas se leía detrás de las cápsulas.
    @Test func laBarraDeReportes_esUnaBarra() throws {
        let reportes = try source("Yala/App/Views/Reports/FinancialReportView.swift")
        #expect(reportes.contains(".safeAreaBar(edge: .top"))
        #expect(!reportes.contains(".safeAreaInset(edge: .top"))
    }
}
