//
//  CancelledEntryReleasesSessionTests.swift
//  YalaTests
//
//  Card xhbn, barrido final de 2.3 (iPhone 14, 16-nov): tras «Cancelar la activación» › «Sí, cancelar» desde la vitrina,
//  la sesión de la cuenta cancelada seguía viva. Medido con trazas: la marca del adopt no la reconocía (`owned=nil`: la
//  sesión venía de un intento anterior), al cerrarse la pantalla se soltaba el candado de Grupos y, al pasar a primer plano,
//  el canal bajaba sus grupos: el puente dejaba «Grupos PEN», dos categorías y el gasto del grupo en el teléfono. Ahora la
//  cancelación que aterriza desde la vitrina suelta la sesión ANTES de cerrar la pantalla.
//

import Foundation
import Testing

@testable import Yala

@Suite("Barrido final 2.3 · cancelar la entrada no deja la sesión de esa cuenta viva")
struct CancelledEntryReleasesSessionTests {

    @Test("Desde la vitrina se suelta la sesión; desde la puerta de Grupos se conserva; sin sesión, nada")
    func releasesSession_table() {
        #expect(WelcomeAdoptCancel.releasesSessionAfterCancel(isUnifiedAccess: true, hasSession: true))
        #expect(!WelcomeAdoptCancel.releasesSessionAfterCancel(isUnifiedAccess: false, hasSession: true),
                "La sesión de la puerta de Grupos es la de los grupos de la persona")
        #expect(!WelcomeAdoptCancel.releasesSessionAfterCancel(isUnifiedAccess: true, hasSession: false))
    }

    @Test("La sesión se suelta antes de volver: volver cierra la pantalla y suelta el candado de Grupos")
    func wiring_signOutBeforeOnBack() throws {
        let view = try BarridoFinal23Source.code("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        #expect(view.contains(
            "if cancelLanded(controller) { if WelcomeAdoptCancel.releasesSessionAfterCancel( "
            + "isUnifiedAccess: isUnifiedAccess, hasSession: CloudAuthService.shared.hasSession) { "
            + "await CloudAuthService.shared.signOut() } onBack() return }"))
        // Y el candado se suelta al cerrar la pantalla: por eso el orden importa.
        #expect(view.contains(".onDisappear { flowTask?.cancel() AccountEntryGroupsHold.releaseIfNoAdoptPending() }"))
    }
}
