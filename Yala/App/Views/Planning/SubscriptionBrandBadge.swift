//
//  SubscriptionBrandBadge.swift
//  Yala
//
//  El distintivo de un servicio conocido (card 2.3 `tablero-logos-de-suscripcion-en-pagos-planificad-9nn7`): sus
//  iniciales sobre su color de marca, en un círculo del mismo tamaño que el icono de la fila. No es la imagen del logo
//  del tercero (ver `SubscriptionBrandCatalog`).
//

import SwiftUI

struct SubscriptionBrandBadge: View {
    let brand: SubscriptionBrand
    var diameter: CGFloat = DS.Icon.badgeLarge
    /// Junto al nombre del pago (lista, línea de tiempo) el distintivo es decorativo: VoiceOver ya lee el nombre.
    var isDecorative: Bool = false

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        let fill = Color(hex: brand.colorHex)
        ZStack {
            Circle().fill(fill)
            Text(verbatim: brand.monogram)
                // A11Y-DT: el monograma es parte del distintivo y escala con el círculo, no con el texto.
                .font(.system(size: diameter * (brand.monogram.count > 1 ? 0.36 : 0.46), weight: .heavy, design: .rounded))
                .foregroundStyle(theme.onFill(fill))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(diameter * 0.12)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement()
        .accessibilityLabel(brand.name)
        .accessibilityIdentifier("scheduled_brand_badge_\(brand.id)")
        .accessibilityHidden(isDecorative)
    }
}
