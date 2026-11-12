//
//  SplashDurationLogic.swift
//  Yala
//
//  Cuánto tiempo mínimo se queda el logo animado del arranque (UX 2.2 · L1-1, decisión de Jürgen del
//  2026-10-13, opción B).
//
//  Hasta 2.2 el mínimo era de 2,5 s en CADA arranque en frío, aunque la app ya estuviera lista: quien abre
//  Yala para apuntar un gasto rápido lo pagaba cada vez. Ahora los 2,5 s son el momento de marca de la
//  primera impresión —mientras el onboarding no está hecho— y después el logo dura lo que la app tarde de
//  verdad en estar lista: el splash sigue esperando a `isInitialCheckDone` en los dos casos, así que con
//  mínimo cero no hay pantalla en blanco.
//
//  «Primer arranque» se lee de `hasCompletedOnboarding` y no de una clave nueva: no hay nada que borrar al
//  vaciar datos ni que migrar, y quien vuelve a empezar de cero (borrado, reinstalación) vuelve a ver la
//  presentación entera, que es lo que le toca.
//

import Foundation

enum SplashDurationLogic {

    /// El mínimo de la primera impresión. El mismo valor que tenía el splash para todos hasta 2.2.
    static let firstImpressionSeconds: Double = 2.5

    /// El tiempo mínimo del splash en segundos. Cero significa «solo lo que tarde la app en estar lista».
    static func minimumSeconds(hasCompletedOnboarding: Bool) -> Double {
        hasCompletedOnboarding ? 0 : firstImpressionSeconds
    }
}
