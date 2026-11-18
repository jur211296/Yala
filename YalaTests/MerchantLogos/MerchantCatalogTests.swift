//
//  MerchantCatalogTests.swift
//  YalaTests
//
//  Pagos planificados: logos reales y banco amplio de comercios (card `scheduled-payments-real-brand-logos`, 2.3).
//

import Foundation
import Testing
import UIKit

@testable import Yala

@Suite("Banco de comercios: catálogo y logos")
struct MerchantCatalogTests {

    @Test("El banco se lee del bundle y tiene cientos de comercios, con ids únicos")
    func bancoSeLee() {
        let all = MerchantCatalog.all
        #expect(all.count >= 500, "Solo \(all.count) comercios")
        let ids = all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(!ids.contains(SubscriptionBrandCatalog.noneID))
        for merchant in all {
            #expect(!merchant.name.isEmpty, "\(merchant.id)")
            #expect(merchant.domain.contains("."), "\(merchant.id)")
        }
    }

    @Test("Prioriza Perú: bancos, telcos, servicios básicos y gimnasios de casa están")
    func peruEsta() {
        for id in ["bcp", "interbank", "bbva", "yape", "plin", "claro", "movistar", "entel", "bitel", "luzdelsur",
                   "sedapal", "calidda", "smartfit", "rimac", "pacifico", "plazavea", "tottus", "inkafarma", "sunat"] {
            #expect(MerchantCatalog.merchant(id: id) != nil, "Falta \(id)")
        }
    }

    @Test("Cada servicio de suscripción de antes sigue con su id, su nombre y sus alias")
    func suscripcionesDeAntesSiguen() throws {
        for brand in SubscriptionBrandCatalog.all {
            let merchant = try #require(MerchantCatalog.merchant(id: brand.id), "Falta \(brand.id)")
            #expect(merchant.name == brand.name, "\(brand.id)")
            #expect(Set(brand.aliases).isSubset(of: Set(merchant.aliases)), "\(brand.id)")
        }
    }

    @Test("Cada logo declarado está empaquetado, y la mayoría de comercios tiene el suyo")
    func logosEmpaquetados() {
        let withLogo = MerchantCatalog.all.filter { $0.logo != nil }
        for merchant in withLogo {
            #expect(UIImage(named: merchant.logo ?? "", in: .main, with: nil) != nil, "\(merchant.id): \(merchant.logo ?? "")")
        }
        #expect(Double(withLogo.count) >= Double(MerchantCatalog.all.count) * 0.75,
                "Solo \(withLogo.count) de \(MerchantCatalog.all.count) con logo")
    }

    @Test("Los pagos de la captura de Jürgen encuentran su comercio, y los cuatro tienen logo")
    func capturaDeJurgen() {
        let cases = ["SmartFit J1": "smartfit", "Claro": "claro", "Spotify": "spotify", "Cloudflare": "cloudflare"]
        for (name, id) in cases {
            let merchant = MerchantCatalog.match(name: name)
            #expect(merchant?.id == id, "\(name) → \(merchant?.id ?? "nil")")
            #expect(merchant?.logo != nil, "\(name) sin logo")
        }
    }

    @Test("Casado tolerante: sufijos, trámites delante, tildes y razón social")
    func casadoTolerante() {
        let cases: [(String, String)] = [
            ("smartfit j1", "smartfit"),
            ("Smart Fit P2", "smartfit"),
            ("Interbank Crédito", "interbank"),
            ("Tarjeta de crédito BCP", "bcp"),
            ("Recibo Luz del Sur", "luzdelsur"),
            ("Pago Claro", "claro"),
            ("Claro Hogar", "claro"),
            ("Movistar Total", "movistar"),
            ("Entel PE", "entel"),
            ("Rímac Seguros S.A.C.", "rimac"),
            ("Cálidda", "calidda"),
            ("Mensualidad UPC", "upc"),
            ("Netflix familiar", "netflix"),
            ("APPLE.COM/BILL", "apple"),
        ]
        for (name, id) in cases {
            #expect(MerchantCatalog.match(name: name)?.id == id, "\(name) → \(MerchantCatalog.match(name: name)?.id ?? "nil")")
        }
    }

    @Test("Gana la forma más larga: «Uber Eats» no es «Uber One», «Apple TV+» no es «Apple»")
    func ganaLaMasLarga() {
        #expect(MerchantCatalog.match(name: "Uber Eats")?.id == "ubereats")
        #expect(MerchantCatalog.match(name: "Uber")?.id == "uberone")
        #expect(MerchantCatalog.match(name: "Apple TV+")?.id == "appletv")
        #expect(MerchantCatalog.match(name: "Apple")?.id == "apple")
        #expect(MerchantCatalog.match(name: "Línea 1 Metro de Lima")?.id == "lineauno")
        #expect(MerchantCatalog.match(name: "Metro")?.id == "metro")
    }

    @Test("No casa por una palabra en medio ni por un nombre genérico")
    func noCasaDeMas() {
        for name in ["Viaje a Paris", "Alquiler", "Luz", "Agua", "Pago", "Cuota del carro", "Transferencia a mamá", "", "  "] {
            #expect(MerchantCatalog.match(name: name) == nil, "\(name) → \(MerchantCatalog.match(name: name)?.id ?? "")")
        }
    }

    @Test("Cada comercio se encuentra por su propio nombre")
    func cadaNombreSeEncuentra() {
        for merchant in MerchantCatalog.all {
            #expect(MerchantCatalog.match(name: merchant.name)?.id == merchant.id,
                    "\(merchant.name) → \(MerchantCatalog.match(name: merchant.name)?.id ?? "nil")")
        }
    }

    @Test("La limpieza quita trámites delante, códigos y razón social detrás, y nada más")
    func limpieza() {
        #expect(MerchantNameCleaner.clean("tarjeta de credito bcp") == "bcp")
        #expect(MerchantNameCleaner.clean("smartfit j1") == "smartfit")
        #expect(MerchantNameCleaner.clean("rimac s a c") == "rimac")
        #expect(MerchantNameCleaner.clean("interbank credito") == "interbank")
        #expect(MerchantNameCleaner.clean("viaje a paris") == "viaje a paris")
        #expect(MerchantNameCleaner.clean("pago") == "")
    }

    @Test("Lo guardado manda: automático, quitado, elegido o desaparecido")
    func resolver() {
        #expect(PaymentLogoResolver.resolve(storedID: nil, name: "Claro")?.id == "claro")
        #expect(PaymentLogoResolver.resolve(storedID: SubscriptionBrandCatalog.noneID, name: "Claro") == nil)
        #expect(PaymentLogoResolver.resolve(storedID: "yape", name: "Mamá")?.id == "yape")
        #expect(PaymentLogoResolver.resolve(storedID: "spotify", name: "Música")?.id == "spotify")
        #expect(PaymentLogoResolver.resolve(storedID: "desaparecido", name: "Claro")?.id == "claro")
        #expect(PaymentLogoResolver.resolve(storedID: nil, name: "Alquiler") == nil)
    }

    @Test("Sin imagen, la inicial: la de la suscripción si la había, si no la de las dos primeras palabras")
    func inicial() throws {
        #expect(PaymentLogo.monogram(for: "Luz del Sur") == "LS")
        #expect(PaymentLogo.monogram(for: "Claro") == "C")
        #expect(PaymentLogo.monogram(for: "Banco de la Nación") == "BN")
        let netflix = try #require(PaymentLogoResolver.logo(id: "netflix"))
        #expect(netflix.monogram == "N")
        #expect(netflix.colorHex == "#E50914")
        // El color de respaldo es fijo por comercio.
        #expect(PaymentLogo.fallbackColor(for: "claro") == PaymentLogo.fallbackColor(for: "claro"))
    }

    @Test("El pago resuelve su logo con lo que tiene guardado")
    func pagoResuelve() {
        let pago = ScheduledPayment(name: "Claro", amount: 89.9, currencyCode: "PEN", nextDueDate: .now)
        #expect(pago.paymentLogo?.id == "claro")
        pago.brandLogoID = SubscriptionBrandCatalog.noneID
        #expect(pago.paymentLogo == nil)
        pago.brandLogoID = "bcp"
        #expect(pago.paymentLogo?.id == "bcp")
        // La semántica de suscripción no cambia: Claro no es una suscripción del catálogo de siempre.
        pago.brandLogoID = nil
        #expect(pago.subscriptionBrand == nil)
    }
}
