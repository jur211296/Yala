//
//  WidgetHelpCircleLabel.swift
//  Yala
//
//  Apariencia compartida del botón de ayuda (`?`) que aparece junto al título
//  de un widget del Panel. Reusado por `InfoHintButton` (popover) y
//  `WidgetInfoButton` (sheet pedagógica) — el contenedor de cada caller mete
//  el `Button` y su overlay correspondiente.
//

import SwiftUI

struct WidgetHelpCircleLabel: View {
    var body: some View {
        Image(systemName: "questionmark")
            .font(DS.Typography.captionSmall)
            .fontWeight(.semibold)
            .foregroundStyle(Color.primary)
            .frame(width: DS.Panel.widgetAccessorySize, height: DS.Panel.widgetAccessorySize)
            .glassEffect(.regular.interactive(), in: Circle())
    }
}

extension View {
    /// Alinea ópticamente el círculo con el texto del título del widget
    /// dentro de un HStack alineado a `.firstTextBaseline`. La baseline del
    /// texto está debajo del cap, así que mappear directo al `.center` deja
    /// el círculo colgado por debajo del centro óptico del texto. Sumamos
    /// ~6pt (≈ cap-height/2 de `subheadlineEmphasized`) para que el centro
    /// del círculo quede a la altura de la x-height del texto.
    func widgetHelpCircleAlignment() -> some View {
        alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 6 }
    }
}
