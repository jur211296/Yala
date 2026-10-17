//
//  PositiveToastLayout.swift
//  Yala
//
//  Dónde y cuánto tiempo sale el aviso positivo de `ContentView` (UX 2.2 · L6-12).
//
//  Lo usan dos hechos que llegan de otro dispositivo —el onboarding terminado allí y una restauración remota—, y los
//  dos aparecen sobre el Panel recién montado. A 32 pt del borde el aviso quedaba encima de la barra de botones del
//  Panel; baja lo que mide una barra de navegación (44 pt) más el aire de siempre.
//

import CoreGraphics

enum PositiveToastLayout {
    static let topInset: CGFloat = DS.Spacing.xxl + 44
    /// Lo de siempre: un aviso de una línea.
    static let defaultSeconds: Double = 3
    /// «Terminaste la configuración en tu otro dispositivo…» son dos frases y llegan sin que la persona las espere.
    static let remoteOnboardingSeconds: Double = 6
}
