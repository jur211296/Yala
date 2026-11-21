//
//  FlujoElegirPagosIconoTests.swift
//  YalaTests
//
//  Flujo de caja, «Elige los pagos» y «Pagos de esta línea» (pedido de Jürgen del 2026-11-21): un pago sin logo enseña el
//  icono de su subcategoría, como la lista de Pagos planificados, nunca un hueco. Fija qué icono se elige: logo → logo;
//  sin logo → subcategoría; subcategoría sin icono propio → el de su categoría; sin subcategoría → el de siempre de Pagos.
//  Y que las dos vistas pintan con esa pieza.
//

import Foundation
import Testing

@testable import Yala

@Suite("Flujo de caja · icono de un pago en «Elige los pagos»", .serialized)
@MainActor
struct FlujoElegirPagosIconoTests {

    private func pago(_ nombre: String, subcategoria: Subcategory? = nil, tipo: String = "recurring") -> ScheduledPayment {
        ScheduledPayment(name: nombre, amount: 20, currencyCode: "PEN", subcategory: subcategoria,
                         nextDueDate: Date(timeIntervalSince1970: 1_790_000_000), paymentCategory: tipo)
    }

    @Test("Con logo de comercio, el logo")
    func conLogo_elLogo() throws {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        let netflix = pago("Netflix", subcategoria: Subcategory(name: "Streaming", colorHex: "#E50914",
                                                                iconName: "tv.fill", category: nil))
        guard case .logo(let logo) = FlujoPagoIcono.elegir(para: netflix) else {
            Issue.record("Netflix tiene logo y no salió")
            return
        }
        #expect(logo == PagoLogoComercio.logo(for: netflix))
    }

    @Test("Sin logo, el icono y el color de su subcategoría")
    func sinLogo_laSubcategoria() {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        let categoria = Category(name: "Hogar", colorHex: "#111111", isIncome: false, iconName: "house.fill")
        let sub = Subcategory(name: "Gimnasio", colorHex: "#22AA55", iconName: "dumbbell.fill", category: categoria)
        let elegido = FlujoPagoIcono.elegir(para: pago("Cuota del gym de la esquina", subcategoria: sub))
        #expect(elegido == .simbolo(nombre: "dumbbell.fill", colorHex: "#22AA55"))
    }

    @Test("Subcategoría sin icono ni color propios: los de su categoría")
    func subcategoriaSinIcono_laCategoria() {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        let categoria = Category(name: "Hogar", colorHex: "#111111", isIncome: false, iconName: "house.fill")
        let sub = Subcategory(name: "Varios", colorHex: nil, iconName: nil, category: categoria)
        let elegido = FlujoPagoIcono.elegir(para: pago("Cuota del condominio", subcategoria: sub))
        #expect(elegido == .simbolo(nombre: "house.fill", colorHex: "#111111"))
    }

    @Test("Sin subcategoría: el icono de siempre de Pagos planificados, según el tipo de pago")
    func sinSubcategoria_elDeSiempre() {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        let recurrente = FlujoPagoIcono.elegir(para: pago("Cuota del condominio"))
        let suscripcion = FlujoPagoIcono.elegir(para: pago("Cuota del condominio", tipo: PaymentCategory.subscription.rawValue))
        #expect(recurrente == .simbolo(nombre: "arrow.trianglehead.2.clockwise.rotate.90", colorHex: AppConstants.defaultColorHex))
        #expect(suscripcion == .simbolo(nombre: "creditcard.and.123", colorHex: AppConstants.defaultColorHex))
    }

    @Test("Decide lo mismo que la lista de Pagos planificados")
    func mismoCriterioQueLaLista() {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        let categoria = Category(name: "Hogar", colorHex: "#111111", isIncome: false, iconName: "house.fill")
        let casos = [
            pago("Cuota del condominio"),
            pago("Cuota del condominio", subcategoria: Subcategory(name: "Varios", category: categoria)),
            pago("Cuota del gym", subcategoria: Subcategory(name: "Gym", colorHex: "#22AA55", iconName: "dumbbell.fill",
                                                            category: categoria)),
        ]
        for caso in casos {
            let lista = ScheduledPaymentsViewModel.paymentDisplayProperties(for: caso)
            #expect(FlujoPagoIcono.elegir(para: caso) == .simbolo(nombre: lista.icon, colorHex: lista.color), "\(caso.name)")
        }
    }
}

@Suite("Flujo de caja · icono de un pago: cableado de las dos vistas (source-scan)")
struct FlujoElegirPagosIconoCableadoTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Sin comentarios, para que documentar el invariante no lo cumpla.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let range = line.range(of: "//") else { return line }
                return line[..<range.lowerBound]
            }
            .joined(separator: "\n")
    }

    private static let carpeta = "Yala/App/Views/Reports/CashFlow/PagosDeLinea/"

    @Test("«Elige los pagos» y «Pagos de esta línea» pintan con la pieza común, sin casar el logo por su cuenta")
    func lasDosVistasUsanLaPieza() throws {
        for fichero in ["FlujoElegirPagosSheet.swift", "FlujoPagosDeLineaCard.swift"] {
            let code = Self.codeOnly(try Self.source(Self.carpeta + fichero))
            #expect(code.contains("FlujoPagoIconoView(pago:"), "\(fichero) no pinta con FlujoPagoIconoView")
            #expect(!code.contains("PagoLogoComercio.logo("), "\(fichero) vuelve a decidir el logo por su cuenta")
        }
    }

    @Test("La lista de Pagos planificados y el Flujo leen el mismo criterio")
    func laListaDelegaEnElCriterioComun() throws {
        let vm = Self.codeOnly(try Self.source("Yala/App/ViewModels/ScheduledPaymentsViewModel.swift"))
        #expect(vm.contains("Self.paymentDisplayProperties(for: payment)"))
        let pieza = Self.codeOnly(try Self.source(Self.carpeta + "FlujoPagoIcono.swift"))
        #expect(pieza.contains("ScheduledPaymentsViewModel.paymentDisplayProperties(for:"))
    }
}
