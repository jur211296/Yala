//
//  RecordsQuickCategoryDetentLogicTests.swift
//  YalaTests
//
//  Hoja de «Categoría ▾» en Registros (Jürgen, 23-nov): a media altura, las subcategorías que salen al tocar una
//  categoría quedaban fuera de la vista. La hoja abre a media altura solo sin nada elegido, abre grande con algo ya
//  elegido y sube a grande al elegir una categoría. Más un scan del cableado: la hoja tiene que usar esta lógica y
//  subir por UIKit (`growsSheetToLarge`), porque cambiar la `selection` de SwiftUI no mueve una hoja presentada.
//

import Foundation
@testable import Yala
import SwiftUI
import Testing

struct RecordsQuickCategoryDetentLogicTests {
    private typealias Logic = RecordsQuickCategoryDetentLogic
    private typealias Entry = RecordsQuickCategorySelectionLogic.Entry<String, String>

    // Comida: delivery, restaurantes · Transporte: taxi, bus
    private let food = Entry(id: "comida", subcategories: ["delivery", "restaurantes"])
    private let transport = Entry(id: "transporte", subcategories: ["taxi", "bus"])
    private var entries: [Entry] { [food, transport] }

    // MARK: - Al abrir

    @Test func sinNadaElegido_abreAMediaAltura() {
        #expect(Logic.initialDetent(entries, expanded: []) == .medium)
    }

    @Test func conUnaCategoriaEntera_abreGrande() {
        #expect(Logic.initialDetent(entries, expanded: ["delivery", "restaurantes"]) == .large)
    }

    @Test func conUnaCategoriaAMedias_abreGrande() {
        #expect(Logic.initialDetent(entries, expanded: ["taxi"]) == .large)
    }

    /// Una subcategoría que ya no se ofrece no cuenta: no hay nada que enseñar debajo de la rejilla.
    @Test func soloSubcategoriasQueNoSeOfrecen_abreAMediaAltura() {
        #expect(Logic.initialDetent(entries, expanded: ["fantasma"]) == .medium)
    }

    // MARK: - Al tocar

    @Test func elegirLaPrimeraCategoria_subeAGrande() {
        let after = RecordsQuickCategorySelectionLogic.togglingCategory(food, in: [])
        #expect(Logic.growsToLarge(entries, before: [], after: after))
    }

    @Test func elegirOtraCategoriaConUnaYaElegida_subeAGrande() {
        let before: Set<String> = ["delivery", "restaurantes"]
        let after = RecordsQuickCategorySelectionLogic.togglingCategory(transport, in: before)
        #expect(Logic.growsToLarge(entries, before: before, after: after))
    }

    @Test func quitarUnaCategoria_noMueveLaHoja() {
        let before: Set<String> = ["delivery", "restaurantes"]
        let after = RecordsQuickCategorySelectionLogic.togglingCategory(food, in: before)
        #expect(after.isEmpty)
        #expect(!Logic.growsToLarge(entries, before: before, after: after))
    }

    @Test func quitarUnaSubcategoria_noMueveLaHoja() {
        let before: Set<String> = ["delivery", "restaurantes"]
        let after = RecordsQuickCategorySelectionLogic.togglingSubcategory("delivery", in: before)
        #expect(!Logic.growsToLarge(entries, before: before, after: after))
    }

    /// La hoja se desplaza hasta las subcategorías de la categoría recién elegida, no de la que ya estaba.
    @Test func laRecienElegida_esLaQueSeEnsena() {
        let before: Set<String> = ["delivery", "restaurantes"]
        let after = RecordsQuickCategorySelectionLogic.togglingCategory(transport, in: before)
        #expect(Logic.newlyChosen(entries, before: before, after: after) == "transporte")
        #expect(Logic.newlyChosen(entries, before: after, after: before) == nil)
    }

    @Test func vaciarConTodasLasCategorias_noMueveLaHoja() {
        #expect(!Logic.growsToLarge(entries, before: ["taxi", "delivery"], after: []))
    }
}

// MARK: - Cableado

struct RecordsQuickCategoryDetentWiringTests {
    private static func source() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Yala/App/Views/Records/QuickFilters/RecordsQuickCategorySheet.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func laHojaAbreConLaAlturaDeLaLogica() throws {
        let code = try Self.source()
        #expect(code.contains("RecordsQuickCategoryDetentLogic.initialDetent("))
    }

    @Test func laHojaSubePorUIKitAlElegirUnaCategoria() throws {
        let code = try Self.source()
        #expect(code.contains("RecordsQuickCategoryDetentLogic.growsToLarge("))
        #expect(code.contains(".growsSheetToLarge(when: growsToLarge)"))
    }

    @Test func laHojaBajaHastaLasSubcategoriasDeLoElegido() throws {
        let code = try Self.source()
        #expect(code.contains("RecordsQuickCategoryDetentLogic.newlyChosen("))
        #expect(code.contains(".id(item.category.persistentModelID)"))
        #expect(code.contains("scrollPosition.scrollTo(edge: .bottom)"))
    }
}
