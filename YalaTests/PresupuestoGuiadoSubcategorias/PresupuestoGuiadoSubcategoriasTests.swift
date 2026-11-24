//
//  PresupuestoGuiadoSubcategoriasTests.swift
//  YalaTests
//
//  «Nuevo presupuesto» por pasos, paso «¿Cuáles?» (pedido de Jürgen del 23-nov): al tocar una categoría salen debajo sus
//  subcategorías, todas marcadas, para quitar las que no se quieran contar. Aquí: las reglas de la selección, lo gastado
//  el período pasado con lo marcado (la frase «El mes pasado gastaste…» del paso del tope) y lo que pasa al formulario.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Selección de categorías y subcategorías

@Suite("Presupuesto guiado · categorías y subcategorías")
struct PresupuestoGuiadoSeleccionTests {
    typealias Logica = AsistentePresupuestoLogica
    typealias Ofrecida = Logica.CategoriaOfrecida<String, String>
    typealias Seleccion = Logica.Seleccion<String, String>

    private let compras = Ofrecida(id: "compras", subcategorias: ["ropa", "electronica", "hogar"])
    private let comida = Ofrecida(id: "comida", subcategorias: ["super", "restaurantes"])
    private var ofrecidas: [Ofrecida] { [compras, comida] }

    @Test func tocarUnaCategoria_laEligeConTodasSusSubcategoriasMarcadas() {
        let sel = Logica.alternarCategoria(compras, en: Seleccion())
        #expect(sel.categorias == ["compras"])
        #expect(sel.subcategorias == ["ropa", "electronica", "hogar"])
    }

    @Test func volverATocarla_laQuitaConSusSubcategorias_sinTocarLasDeOtra() {
        var sel = Logica.alternarCategoria(compras, en: Seleccion())
        sel = Logica.alternarCategoria(comida, en: sel)
        sel = Logica.alternarCategoria(compras, en: sel)
        #expect(sel.categorias == ["comida"])
        #expect(sel.subcategorias == ["super", "restaurantes"])
    }

    @Test func quitarLaCategoriaEntera_conAlgunaYaDesmarcada_limpiaTodasLasSuyas() {
        var sel = Logica.alternarCategoria(compras, en: Seleccion())
        sel = Logica.alternarSubcategoria("hogar", de: compras, en: sel)
        sel = Logica.alternarCategoria(compras, en: sel)
        #expect(sel == Seleccion())
    }

    @Test func desmarcarUnaSubcategoria_laQuita_yLaCategoriaSigueElegida() {
        var sel = Logica.alternarCategoria(compras, en: Seleccion())
        sel = Logica.alternarSubcategoria("electronica", de: compras, en: sel)
        #expect(sel.categorias == ["compras"])
        #expect(sel.subcategorias == ["ropa", "hogar"])
    }

    @Test func desmarcarTodasLasSubcategorias_desmarcaLaCategoria() {
        var sel = Logica.alternarCategoria(compras, en: Seleccion())
        sel = Logica.alternarCategoria(comida, en: sel)
        for sub in compras.subcategorias { sel = Logica.alternarSubcategoria(sub, de: compras, en: sel) }
        #expect(sel.categorias == ["comida"])
        #expect(sel.subcategorias == ["super", "restaurantes"])
        #expect(Logica.puedeSeguir(en: .categorias, .init(alcance: .categories, categoriasElegidas: sel.categorias.count)))
    }

    @Test func desmarcarLaUnicaElegidaEntera_apagaSiguiente() {
        var sel = Logica.alternarCategoria(comida, en: Seleccion())
        sel = Logica.alternarSubcategoria("super", de: comida, en: sel)
        sel = Logica.alternarSubcategoria("restaurantes", de: comida, en: sel)
        #expect(sel.categorias.isEmpty)
        #expect(!Logica.puedeSeguir(en: .categorias, .init(alcance: .categories, categoriasElegidas: sel.categorias.count)))
    }

    @Test func volverAMarcarUnaSubcategoria_laRepone() {
        var sel = Logica.alternarCategoria(compras, en: Seleccion())
        sel = Logica.alternarSubcategoria("ropa", de: compras, en: sel)
        sel = Logica.alternarSubcategoria("ropa", de: compras, en: sel)
        #expect(sel.subcategorias == ["ropa", "electronica", "hogar"])
        #expect(sel.categorias == ["compras"])
    }

    @Test func unaSubcategoriaDeOtraCategoria_noCambiaNada() {
        let sel = Logica.alternarCategoria(compras, en: Seleccion())
        #expect(Logica.alternarSubcategoria("super", de: compras, en: sel) == sel)
    }

    @Test func elOrdenDeCategorias_esElDeLosToques() {
        var sel = Logica.alternarCategoria(comida, en: Seleccion())
        sel = Logica.alternarCategoria(compras, en: sel)
        #expect(sel.categorias == ["comida", "compras"])
    }

    @Test func lasDelPresupuesto_sonSoloLasMarcadas_enOrdenYSinRepetir() {
        var sel = Logica.alternarCategoria(comida, en: Seleccion())
        sel = Logica.alternarCategoria(compras, en: sel)
        sel = Logica.alternarSubcategoria("electronica", de: compras, en: sel)
        #expect(Logica.subcategoriasDelPresupuesto(sel, ofrecidas: ofrecidas) == ["super", "restaurantes", "ropa", "hogar"])
    }

    @Test func lasDelPresupuesto_ignoranUnaMarcadaDeCategoriaNoElegida() {
        let sel = Seleccion(categorias: ["comida"], subcategorias: ["super", "ropa"])
        #expect(Logica.subcategoriasDelPresupuesto(sel, ofrecidas: ofrecidas) == ["super"])
    }

    @Test func alFormulario_pasaExactamenteLasMarcadas() throws {
        var sel = Logica.alternarCategoria(compras, en: Seleccion())
        sel = Logica.alternarSubcategoria("hogar", de: compras, en: sel)
        let ids = ["ropa": UUID(), "electronica": UUID(), "hogar": UUID()]
        let marcadas = Logica.subcategoriasDelPresupuesto(sel, ofrecidas: ofrecidas).compactMap { ids[$0] }
        let prefill = Logica.alFormulario(
            .init(alcance: .categories, categoriasElegidas: 1, tope: 500, nombre: "Compras"),
            subcategorias: marcadas, aviso: .none)
        let ropa = try #require(ids["ropa"])
        let electronica = try #require(ids["electronica"])
        #expect(Set(prefill.subcategoryIDs) == [ropa, electronica])
    }
}

// MARK: - Lo gastado el período pasado con lo marcado

@MainActor
@Suite("Presupuesto guiado · lo gastado con las subcategorías marcadas")
struct PresupuestoGuiadoGastadoTests {
    typealias Logica = AsistentePresupuestoLogica

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return c
    }()

    private func fecha(_ mes: Int, _ dia: Int, hora: Int = 10) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: mes, day: dia, hour: hora)))
    }

    /// «Hoy» fijo: 24 de noviembre de 2026, mediodía en Lima.
    private func hoy() throws -> Date { try fecha(11, 24, hora: 12) }

    private struct Fixture {
        let ropa: Subcategory
        let electronica: Subcategory
        let movimientos: [TransactionItem]
    }

    /// Compras (ropa 100 + electrónica 900 en octubre, ropa 40 en noviembre) y Comida (súper 5.000 en octubre, que una
    /// suma sin filtro contaría).
    private func fixture() throws -> Fixture {
        let compras = Yala.Category(name: "Compras", colorHex: "#111111", isIncome: false)
        let comida = Yala.Category(name: "Comida", colorHex: "#222222", isIncome: false)
        let ropa = Subcategory(name: "Ropa", category: compras)
        let electronica = Subcategory(name: "Electrónica", category: compras)
        let superm = Subcategory(name: "Supermercado", category: comida)
        func gasto(_ monto: Double, _ dia: Date, _ cat: Yala.Category, _ sub: Subcategory) -> TransactionItem {
            TransactionItem(date: dia, amount: -monto, currencyCode: "PEN", category: cat, subcategory: sub,
                            amountInPreferredCurrency: -monto)
        }
        return Fixture(ropa: ropa, electronica: electronica, movimientos: [
            gasto(100, try fecha(10, 5), compras, ropa),
            gasto(900, try fecha(10, 20), compras, electronica),
            gasto(5_000, try fecha(10, 12), comida, superm),
            gasto(40, try fecha(11, 3), compras, ropa),
        ])
    }

    private func gastadoMesPasado(_ subs: [UUID], _ movimientos: [TransactionItem]) throws -> Double {
        let dia = try #require(Logica.fechaDelPeriodoAnterior(.monthly, ahora: try hoy(), calendar: calendar))
        return TutorialPlanningMath.budgetSpent(
            subcategoryIDs: subs, period: .monthly, currencyCode: "PEN", transactions: movimientos, now: dia,
            calendar: calendar)
    }

    @Test func mesPasado_conLaCategoriaEntera_cuentaSoloSusSubcategorias() throws {
        let f = try fixture()
        let gastado = try gastadoMesPasado([f.ropa.shortcutID, f.electronica.shortcutID], f.movimientos)
        #expect(gastado == 1_000, "Solo Compras de octubre: ni Comida ni lo de noviembre")
    }

    @Test func mesPasado_conUnaSubcategoriaDesmarcada_laDejaFuera() throws {
        let f = try fixture()
        #expect(try gastadoMesPasado([f.ropa.shortcutID], f.movimientos) == 100)
    }

    @Test func control_sinFiltro_sumaTodo() throws {
        // Lo que se vería si el paso del tope ignorara la selección: la cifra inflada.
        #expect(try gastadoMesPasado([], try fixture().movimientos) == 6_000)
    }

    @Test func laCifraDeLaTarjeta_esDeEsteMes_noLaDelMesPasado() throws {
        // La tarjeta de «¿Cuáles?» dice lo gastado ESTE mes; el paso del tope, el mes pasado: dos cifras distintas.
        let f = try fixture()
        let esteMes = TutorialPlanningMath.budgetSpent(
            subcategoryIDs: [f.ropa.shortcutID, f.electronica.shortcutID], period: .monthly, currencyCode: "PEN",
            transactions: f.movimientos, now: try hoy(), calendar: calendar)
        #expect(esteMes == 40)
    }
}

// MARK: - Cableado de la vista

@Suite("Presupuesto guiado · cableado (source-scan)")
struct PresupuestoGuiadoCableadoTests {

    private static func code(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")
    }

    private let vista = "Yala/App/Views/Shared/AsistenteCreacion/Presupuesto/AsistentePresupuestoView.swift"

    @Test func loGastadoYLoCreado_usanSoloLasSubcategoriasMarcadas() throws {
        let src = try Self.code(vista)
        #expect(src.contains("return Logica.subcategoriasDelPresupuesto(estado.seleccion, ofrecidas: ofrecidas)"))
        #expect(src.contains("gastado(subcategorias: subcategoriasElegidas, periodo: estado.periodo, ahora: fecha)"))
        #expect(src.contains("let quiero = Set(subcategoriasElegidas)"))
        #expect(src.contains("estado.usarFormulario(subcategorias: subcategoriasElegidas)"))
    }

    @Test func losToques_pasanPorLasReglas() throws {
        let src = try Self.code(vista)
        #expect(src.contains("estado.seleccion = Logica.alternarCategoria(ofrecida(categoria), en: estado.seleccion)"))
        #expect(src.contains(
            "estado.seleccion = Logica.alternarSubcategoria(subcategoria, de: ofrecida(categoria), en: estado.seleccion)"))
        #expect(src.contains("AsistenteSubcategoriaCirculo("))
    }
}
