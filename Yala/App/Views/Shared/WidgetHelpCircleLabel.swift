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
    /// Sube el círculo ~4pt para que su centro óptico coincida con la línea
    /// del texto del título del widget (`subheadlineEmphasized`). Sin esto,
    /// en HStacks con `alignment: .top` el círculo cuelga muy por debajo;
    /// con un offset al `.center` completo queda demasiado arriba — 4pt es
    /// el equilibrio para un círculo de 22pt sobre un cap-height ≈ 14pt.
    func widgetHelpCircleAlignment() -> some View {
        alignmentGuide(.top) { d in d[.top] + 4 }
            .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
    }
}
