//
//  SubscriptionBrandBadge.swift
//  Yala
//
//  El distintivo de un comercio conocido en los pagos planificados: su logo real, en un círculo del mismo tamaño que el
//  icono de la fila (card `scheduled-payments-real-brand-logos`, 2.3); sin imagen, sus iniciales sobre su color (card
//  9nn7). El logo viene empaquetado (`MerchantCatalog`): no se descarga nada.
//
//  Uso de marca (Jürgen, 2026-11-17): el logo no se deforma ni se recolorea. Se escala entero y se recorta al círculo
//  como el resto de iconos de la fila; los de fondo transparente ya llegan sobre blanco con su margen.
//

import SwiftUI

struct SubscriptionBrandBadge: View {
    let logo: PaymentLogo
    var diameter: CGFloat = DS.Icon.badgeLarge
    /// Junto al nombre del pago (lista, línea de tiempo) el distintivo es decorativo: VoiceOver ya lee el nombre.
    var isDecorative: Bool = false

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Group {
            if let photo = logo.photo {
                // Logo propio: la foto ya viene cuadrada (`PagoLogoPropioFoto`), se recorta al círculo con su borde.
                Image(uiImage: photo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 0.5))
            } else if let assetName = logo.assetName {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
                    // Un borde fino: un logo sobre blanco no se pierde contra la tarjeta clara.
                    .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 0.5))
            } else {
                monogram
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement()
        .accessibilityLabel(logo.name)
        .accessibilityIdentifier("scheduled_brand_badge_\(logo.id)")
        .accessibilityHidden(isDecorative)
    }

    private var monogram: some View {
        let fill = Color(hex: logo.colorHex)
        return ZStack {
            Circle().fill(fill)
            Text(verbatim: logo.monogram)
                // A11Y-DT: el monograma es parte del distintivo y escala con el círculo, no con el texto.
                .font(.system(size: diameter * (logo.monogram.count > 1 ? 0.36 : 0.46), weight: .heavy, design: .rounded))
                .foregroundStyle(theme.onFill(fill))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(diameter * 0.12)
        }
    }
}

/// La marca de un pago en una celda del calendario: el logo (o su inicial) en 12 pt y un aro del color del estado.
struct PaymentLogoCalendarMark: View {
    let logo: PaymentLogo
    let stateColor: Color

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        ZStack {
            if let photo = logo.photo {
                Image(uiImage: photo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 12, height: 12)
                    .clipShape(Circle())
            } else if let assetName = logo.assetName {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 12, height: 12)
                    .clipShape(Circle())
            } else {
                let fill = Color(hex: logo.colorHex)
                Circle().fill(fill).frame(width: 12, height: 12)
                Text(verbatim: String(logo.monogram.prefix(1)))
                    .font(.system(size: 7, weight: .heavy, design: .rounded)) // A11Y-DT: micro-marca del calendario
                    .foregroundStyle(theme.onFill(fill))
            }
            Circle().stroke(stateColor, lineWidth: 1.5).frame(width: 15, height: 15)
        }
        .frame(width: 15, height: 15)
        .accessibilityHidden(true)
    }
}

/// La marca de un pago SIN logo en una celda del calendario: el icono de su subcategoría en 12 pt, sobre el color de su
/// categoría, con el mismo aro del estado que la del logo (encargo del 24-nov-2026; antes era un punto).
struct PaymentIconCalendarMark: View {
    let icon: String
    let colorHex: String
    let stateColor: Color

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: colorHex)).frame(width: 12, height: 12)
            Image(systemName: icon)
                .font(.system(size: 6.5, weight: .bold)) // A11Y-DT: micro-marca del calendario
                .foregroundStyle(.white)
            Circle().stroke(stateColor, lineWidth: 1.5).frame(width: 15, height: 15)
        }
        .frame(width: 15, height: 15)
        .accessibilityHidden(true)
    }
}
