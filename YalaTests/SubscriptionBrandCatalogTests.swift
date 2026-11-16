//
//  SubscriptionBrandCatalogTests.swift
//  YalaTests
//
//  Logos de suscripción en pagos planificados (card 2.3 `tablero-logos-de-suscripcion-en-pagos-planificad-9nn7`).
//

import Foundation
import Testing

@testable import Yala

@Suite("Logos de suscripción")
struct SubscriptionBrandCatalogTests {

    @Test("Casa por nombre, sin mayúsculas, tildes ni signos")
    func casaPorNombre() {
        #expect(SubscriptionBrandCatalog.match(name: "Netflix")?.id == "netflix")
        #expect(SubscriptionBrandCatalog.match(name: "  netflix ")?.id == "netflix")
        #expect(SubscriptionBrandCatalog.match(name: "Disney Plus")?.id == "disneyplus")
        #expect(SubscriptionBrandCatalog.match(name: "Disney+")?.id == "disneyplus")
        #expect(SubscriptionBrandCatalog.match(name: "iCloud+")?.id == "icloud")
        #expect(SubscriptionBrandCatalog.match(name: "HBO Max")?.id == "max")
    }

    @Test("Casa si empieza por el servicio y sigue otra palabra")
    func casaConApellido() {
        #expect(SubscriptionBrandCatalog.match(name: "Netflix familiar")?.id == "netflix")
        #expect(SubscriptionBrandCatalog.match(name: "Spotify Duo")?.id == "spotify")
    }

    @Test("No casa por un trozo de palabra ni por algo que solo lo contiene")
    func noCasaPorTrozos() {
        #expect(SubscriptionBrandCatalog.match(name: "Netflixy") == nil)
        #expect(SubscriptionBrandCatalog.match(name: "Cuenta de Netflix") == nil)
        #expect(SubscriptionBrandCatalog.match(name: "Alquiler") == nil)
        #expect(SubscriptionBrandCatalog.match(name: "") == nil)
    }

    @Test("Gana el nombre más largo: «Apple TV+» no es «Apple One»")
    func ganaElMasLargo() {
        #expect(SubscriptionBrandCatalog.match(name: "Apple TV+")?.id == "appletv")
        #expect(SubscriptionBrandCatalog.match(name: "YouTube Music")?.id == "youtube")
    }

    @Test("Lo guardado manda: automático, quitado o elegido")
    func resolver() {
        #expect(SubscriptionBrandCatalog.resolve(storedID: nil, name: "Netflix")?.id == "netflix")
        #expect(SubscriptionBrandCatalog.resolve(storedID: SubscriptionBrandCatalog.noneID, name: "Netflix") == nil)
        #expect(SubscriptionBrandCatalog.resolve(storedID: "spotify", name: "Netflix")?.id == "spotify")
        #expect(SubscriptionBrandCatalog.resolve(storedID: "spotify", name: "Música")?.id == "spotify")
        // Un id que ya no existe en el catálogo cae al automático en vez de dejar el pago sin nada.
        #expect(SubscriptionBrandCatalog.resolve(storedID: "desaparecido", name: "Netflix")?.id == "netflix")
    }

    @Test("Catálogo sano: ids únicos, monogramas cortos y colores válidos")
    func catalogoSano() {
        let ids = SubscriptionBrandCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(!ids.contains(SubscriptionBrandCatalog.noneID))
        for brand in SubscriptionBrandCatalog.all {
            #expect((1...3).contains(brand.monogram.count), "\(brand.id)")
            #expect(brand.colorHex.range(of: #"^#[0-9A-F]{6}$"#, options: .regularExpression) != nil, "\(brand.id)")
        }
    }

    @Test("El pago resuelve su logo con lo que tiene guardado")
    func pagoResuelve() {
        let pago = ScheduledPayment(name: "Netflix", amount: 45, currencyCode: "PEN", nextDueDate: .now)
        #expect(pago.subscriptionBrand?.id == "netflix")
        pago.brandLogoID = SubscriptionBrandCatalog.noneID
        #expect(pago.subscriptionBrand == nil)
    }
}
