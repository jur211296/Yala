//
//  UITestDemoSubcategoryLogicTests.swift
//  YalaTests
//
//  Los perfiles `two` de las demos de voz y foto (`-uitest-voice-result two`, `-uitest-image-result two`) ponen el taxi en
//  su subcategoría de transporte, no en Restaurantes (hallazgo del cierre de las capturas de la App Store).
//

import Testing
@testable import Yala

@Suite("Demos de voz y foto · subcategoría del taxi")
struct UITestDemoSubcategoryLogicTests {
    private let seeded = ["Restaurantes", "Supermercados", "Taxis y apps", "Transporte público"]

    @Test("Con «Taxis y apps» sembrada, el taxi va ahí y no a la de la comida")
    func taxi_goesToRideshare() {
        let result = UITestDemoSubcategoryLogic.taxiSubcategory(
            among: seeded, rideshareName: "Taxis y apps", fallback: "Restaurantes")
        #expect(result == "Taxis y apps")
    }

    @Test("Sin la de taxis entre los gastos, se queda con la de siempre")
    func withoutRideshare_keepsTheFallback() {
        let result = UITestDemoSubcategoryLogic.taxiSubcategory(
            among: ["Restaurantes", "Supermercados"], rideshareName: "Taxis y apps", fallback: "Restaurantes")
        #expect(result == "Restaurantes")
    }

    @Test("El nombre por defecto es el de la subcategoría sembrada en el idioma de la app")
    func defaultName_isTheSeededOne() {
        let result = UITestDemoSubcategoryLogic.taxiSubcategory(
            among: [L10n.Subcategory.restaurants, L10n.Subcategory.rideshare], fallback: L10n.Subcategory.restaurants)
        #expect(result == L10n.Subcategory.rideshare)
    }
}
