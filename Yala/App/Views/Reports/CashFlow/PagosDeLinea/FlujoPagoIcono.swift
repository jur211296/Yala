//
//  FlujoPagoIcono.swift
//  Yala
//
//  El icono de un pago en el Flujo de caja («Elige los pagos» y «Pagos de esta línea»), pedido de Jürgen del 2026-11-21:
//  con logo de comercio, el logo; sin él, el icono de su subcategoría (o de su categoría) sobre su color, como la lista
//  de Pagos planificados. Nunca un hueco. Decide con las dos piezas comunes (`PagoLogoComercio` y
//  `ScheduledPaymentsViewModel.paymentDisplayProperties`), sin criterio propio.
//

import SwiftUI

enum FlujoPagoIcono: Equatable {
    case logo(PaymentLogo)
    case simbolo(nombre: String, colorHex: String)

    @MainActor
    static func elegir(para pago: ScheduledPayment) -> FlujoPagoIcono {
        if let logo = PagoLogoComercio.logo(for: pago) { return .logo(logo) }
        let propiedades = ScheduledPaymentsViewModel.paymentDisplayProperties(for: pago)
        return .simbolo(nombre: propiedades.icon, colorHex: propiedades.color)
    }
}

/// El distintivo del pago a `DS.Icon.badgeSmall`: el logo, o el círculo del color con el icono en blanco.
struct FlujoPagoIconoView: View {
    let pago: ScheduledPayment

    var body: some View {
        switch FlujoPagoIcono.elegir(para: pago) {
        case .logo(let logo):
            SubscriptionBrandBadge(logo: logo, diameter: DS.Icon.badgeSmall, isDecorative: true)
        case .simbolo(let nombre, let colorHex):
            ZStack {
                Circle().fill(Color(hex: colorHex))
                Image(systemName: nombre)
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
            .accessibilityHidden(true)
        }
    }
}
