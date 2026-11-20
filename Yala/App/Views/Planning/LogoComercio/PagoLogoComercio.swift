//
//  PagoLogoComercio.swift
//  Yala
//
//  El logo del comercio en Pagos planificados, con UN criterio para sus tres vistas: lista, línea de tiempo y calendario
//  (decisión de Jürgen del 2026-11-18: el logo va solo en Pagos planificados, no en Registros ni en el Panel). Si el pago
//  casa con el banco (`MerchantCatalog`) o tiene un logo elegido, se pinta el logo; si no, lo que cada vista pintaba antes.
//  Un logo propio (la foto del pago, `PagoLogoPropio.swift`) gana a todo lo demás.
//
//  El casado recorre ~2.000 formas por nombre, en dos pasadas. Antes cada vista lo repetía en cada pintado (el calendario,
//  dos veces por pago y celda), así que aquí se recuerda por (logo guardado, nombre): el banco es estático y, si la persona
//  renombra el pago o elige otro logo, la clave ya es otra.
//

import SwiftUI

@MainActor
enum PagoLogoComercio {

    struct Clave: Hashable {
        let logoGuardado: String?
        let nombre: String
    }

    /// Techo de seguridad: cada pago aporta una clave y un renombrado otra. Pasado el techo se empieza de cero.
    static let techo = 512

    private static var recordados: [Clave: PaymentLogo?] = [:]

    /// Cuántas veces se ha casado de verdad contra el banco. Solo para los tests.
    private(set) static var casadosReales = 0

    /// El logo que se pinta para este pago, o `nil` si no hay (cada vista pinta entonces lo de siempre).
    static func logo(for payment: ScheduledPayment) -> PaymentLogo? {
        // El logo propio gana: es lo que la persona eligió para este pago (encargo del 2026-11-20).
        if let datos = payment.customLogoData,
           let foto = PagoLogoPropioImagenes.imagen(pago: payment.id, datos: datos) {
            return PaymentLogo(photo: foto, paymentName: payment.name)
        }
        return logo(logoGuardado: payment.brandLogoID, nombre: payment.name)
    }

    static func logo(logoGuardado: String?, nombre: String) -> PaymentLogo? {
        let clave = Clave(logoGuardado: logoGuardado, nombre: nombre)
        if let recordado = recordados[clave] { return recordado }
        if recordados.count >= techo { recordados.removeAll(keepingCapacity: true) }
        casadosReales += 1
        let logo = PaymentLogoResolver.resolve(storedID: logoGuardado, name: nombre)
        recordados[clave] = .some(logo)
        return logo
    }

    #if DEBUG
    static func _testReset() {
        recordados.removeAll()
        casadosReales = 0
    }
    #endif
}

/// El distintivo de un pago en la lista y en la línea de tiempo: su logo en un círculo del tamaño pedido o, sin logo, lo
/// que la vista pintaba antes (`sinLogo`). Decorativo: VoiceOver ya lee el nombre del pago al lado.
struct PagoLogoDistintivo<SinLogo: View>: View {
    let logo: PaymentLogo?
    var diameter: CGFloat = DS.Icon.badgeLarge
    @ViewBuilder let sinLogo: () -> SinLogo

    var body: some View {
        if let logo {
            SubscriptionBrandBadge(logo: logo, diameter: diameter, isDecorative: true)
        } else {
            sinLogo()
        }
    }
}

extension PagoLogoDistintivo where SinLogo == EmptyView {
    /// Sin logo no se pinta nada (la línea de tiempo: su icono es el círculo del día).
    init(logo: PaymentLogo?, diameter: CGFloat = DS.Icon.badgeLarge) {
        self.init(logo: logo, diameter: diameter, sinLogo: { EmptyView() })
    }
}
