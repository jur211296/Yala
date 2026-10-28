//
//  SignOutDeferredRoutingLogic.swift
//  Yala
//
//  Card 7e60 (Jürgen, 2026-10-28): cerró sesión aceptando perder los cambios y la app «se cerró». El cierre que no pide
//  reabrir (card ypit) cambia el almacén en caliente y monta un `ContentView` nuevo mientras la fase sigue en
//  `.awaitingRelaunch`; el arranque de ese `ContentView` callaba el Welcome por el `guard` de `presentNextOnboardingScreen`
//  y nadie lo retomaba al volver la fase a `.idle`. Aquí vive CUÁNDO se retoma, en puro.
//

import Foundation

enum SignOutDeferredRoutingLogic {

    /// ¿Se retoma ahora el encaminamiento que se calló esperando el relanzamiento? Solo con algo aplazado y la fase de
    /// vuelta en reposo: en `.awaitingRelaunch` manda el cover terminal, y en `.working` o `.blocked` el cierre sigue vivo.
    static func resumes(deferred: Bool, phase: CloudSessionSignOut.Phase) -> Bool {
        deferred && phase == .idle
    }
}
