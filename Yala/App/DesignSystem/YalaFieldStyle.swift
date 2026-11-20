//
//  YalaFieldStyle.swift
//  Yala
//
//  El estilo común de un campo que la persona completa (encargo de Primeros pasos del 2026-11-20, «el texto escrito casi
//  no se ve»). Medido ese día: la build 2.3 (5) se subió a las 17:31 del 19-nov, antes del arreglo de temas de las 22:31
//  (`ThemeWindowStyle`), y en ella una hoja con el tema Claro y el iPhone en oscuro pintaba `Color.primary` en blanco
//  sobre la tarjeta blanca del tema. En la base de hoy los tres cruces (tema oscuro y sistema claro, Claro con claro, Claro
//  con oscuro) ya se leen. Esta pieza ata el texto escrito AL TEMA y no al modo del sistema, para que un campo no dependa
//  de que el modo llegue bien a la presentación: el texto en `theme.primaryText` resuelto con el modo del tema, el cursor
//  en el acento como texto y el aviso de ejemplo en gris secundario (el terciario daba ~2:1 sobre la tarjeta).
//
//  Lo fija `YalaTests/PrimerosPasosPulido/CamposLegiblesTests` (AA 4,5:1 en los diez temas) y su barrido de cableado.
//

import SwiftUI

extension View {
    /// El texto escrito de un campo: el del tema, con el modo del tema, legible sobre `theme.card` (AA en los diez
    /// temas). Va en el `TextField`, no en su contenedor: el contenedor puede llevar textos con su propio color.
    func yalaFieldText() -> some View {
        modifier(YalaFieldTextModifier())
    }
}

extension Text {
    /// El aviso de ejemplo de un campo vacío («0.00», «Nombre de la cuenta»): gris secundario, que se lee sin parecer
    /// escrito.
    func yalaFieldPrompt() -> Text {
        foregroundStyle(.secondary)
    }
}

private struct YalaFieldTextModifier: ViewModifier {
    @Environment(\.yalaTheme) private var theme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(theme.primaryText)
            .tint(theme.accentText)
            // El modo del tema, no el de la presentación: `primaryText` del tema Claro es `Color.primary`, que con el
            // iPhone en oscuro y la hoja sin el modo del tema salía blanco sobre blanco.
            .environment(\.colorScheme, theme.baseColorScheme)
    }
}

/// La fila de un campo con un texto delante («Día» 15, «S/» 620): los dos en la misma línea base y la misma letra, con
/// aire entre ellos (encargo del 2026-11-20: «que no se peguen»). El prefijo va en gris; el número, en el estilo del campo.
enum YalaFieldPrefix {
    /// El aire entre el texto y el número.
    static let spacing = DS.Spacing.sm
    /// La letra de los dos.
    static let font = DS.Typography.title3.weight(.semibold)
}
