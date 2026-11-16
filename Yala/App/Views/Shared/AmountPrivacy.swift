//
//  AmountPrivacy.swift
//  Yala
//
//  «Ocultar montos» del Panel (card «Ojo para ocultar montos en el Panel», 2026-11-06): un ojo junto a la cifra grande del
//  hero cambia `AppPreferences.panelAmountsHidden`, y el Panel lo baja a su contenido con
//  `.environment(\.amountsHidden, …)`. Fuera del Panel el valor es `false` y nada cambia.
//
//  Quién lo lee:
//  - `AmountText` pinta el símbolo de la moneda y `•••••` en vez de la cifra, y VoiceOver dice «Monto oculto».
//  - Las cifras del Panel que no pasan por `AmountText` (frases con el monto dentro, ejes y etiquetas de las gráficas)
//    pasan su texto ya formateado por `AmountPrivacy.text(_:hidden:)`.
//
//  La máscara tiene SIEMPRE el mismo largo: un número de más dígitos no puede delatarse por el ancho.
//  Las gráficas mantienen su forma (barras, líneas, tartas y porcentajes): dicen proporciones, no cuánto hay.
//  Las hojas que se abren desde el Panel no heredan el valor: abrir el detalle de algo es pedir verlo.
//  Dentro de una `.annotation` de Swift Charts el entorno no llega: ahí se pasa el valor leído en la vista.
//

import SwiftUI

enum AmountPrivacy {
    /// Lo que se pinta en el sitio de la cifra.
    static let mask = "•••••"

    /// El texto de un monto ya formateado, oculto: se queda con lo que va antes de la cifra (`S/`, `≈ PEN`) y cambia
    /// la cifra por la máscara. Un monto sin símbolo («2,3k» en un eje) queda solo en la máscara.
    ///
    /// Formato esperado, el de `AppPreferences.currency`: `[≈ ]<símbolo> [signo]<cifra>`. Lo que no tenga espacios es
    /// la cifra entera.
    static func masked(_ formatted: String) -> String {
        let parts = formatted
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count > 1 else { return mask }
        return parts.dropLast().joined(separator: " ") + " " + mask
    }

    /// `masked(_:)` si los montos están ocultos; si no, el texto tal cual.
    static func text(_ formatted: String, hidden: Bool) -> String {
        hidden ? masked(formatted) : formatted
    }

    /// Para una etiqueta de VoiceOver: «Monto oculto» en vez de la cifra. La máscara se leería viñeta a viñeta.
    @MainActor
    static func spoken(_ formatted: String, hidden: Bool) -> String {
        hidden ? L10n.Panel.amountHidden : formatted
    }
}

extension EnvironmentValues {
    /// `true` en el contenido del Panel con «Ocultar montos» puesto. Ver `AmountPrivacy`.
    @Entry var amountsHidden: Bool = false
}
