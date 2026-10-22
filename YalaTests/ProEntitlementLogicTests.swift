//
//  ProEntitlementLogicTests.swift
//  YalaTests
//
//  Pinnea la resolución del derecho Pro cuando puede venir de DOS sitios (bug C-8, 2026-07-27):
//  la suscripción del Apple ID de este device y la suscripción vinculada a la cuenta de Yala.
//
//  Las tres cosas que estos tests impiden, en orden de daño:
//   1. Quitarle Pro a un pagador — por un fallo de red, por el flag apagado, o por leer mal la caché.
//   2. Regalar Pro con la caché de OTRA cuenta (la clase de fuga del handover de dispositivo).
//   3. Que el flag DARK no sea realmente DARK: con la resolución apagada el veredicto tiene que ser
//      EXACTAMENTE el de antes del fix, o el commit cambia monetización sin querer.
//

import Foundation
import Testing

@testable import Yala

@Suite("ProEntitlementLogic · el derecho Pro por cuenta (C-8)")
struct ProEntitlementLogicTests {

    typealias L = ProEntitlementLogic

    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let userA = "11111111-2222-3333-4444-555555555555"
    static let userB = "99999999-8888-7777-6666-555555555555"

    static func snapshot(
        userID: String = userA,
        expiresAt: Date? = now.addingTimeInterval(30 * 24 * 3600),
        refreshedAt: Date = now.addingTimeInterval(-3600)
    ) -> AccountEntitlementSnapshot {
        AccountEntitlementSnapshot(
            userID: userID, product: "com.yala.pro.yearly", expiresAt: expiresAt, refreshedAt: refreshedAt)
    }

    // MARK: - isPro · el local manda siempre

    /// Quien paga en ESTE device conserva Pro pase lo que pase: sin cuenta, con el flag apagado, o
    /// con una caché vencida de otra cuenta. Es la regla que hace el fix seguro para monetización.
    @Test func localActive_alwaysPro_regardlessOfEverythingElse() {
        for enabled in [true, false] {
            for session in [nil, Self.userA, Self.userB] as [String?] {
                #expect(L.isPro(localActive: true,
                                snapshot: Self.snapshot(userID: Self.userB, expiresAt: Self.now.addingTimeInterval(-1)),
                                sessionUserID: session,
                                resolutionEnabled: enabled,
                                now: Self.now),
                        "enabled=\(enabled) session=\(session ?? "nil") debería seguir siendo Pro")
            }
        }
    }

    // MARK: - isPro · DARK

    /// Con el flag apagado el veredicto es literalmente `localActive` — byte-idéntico a antes del fix.
    @Test func resolutionDisabled_isExactlyLocalActive() {
        #expect(L.isPro(localActive: false, snapshot: Self.snapshot(), sessionUserID: Self.userA,
                        resolutionEnabled: false, now: Self.now) == false)
        #expect(L.isPro(localActive: true, snapshot: nil, sessionUserID: nil,
                        resolutionEnabled: false, now: Self.now) == true)
    }

    // MARK: - isPro · el derecho de la cuenta

    /// EL caso de C-8: device con otro Apple ID (sin entitlement local) + cuenta de Yala con Pro.
    @Test func accountEntitlementVigente_grantsPro_onADeviceWithAnotherAppleID() {
        #expect(L.isPro(localActive: false, snapshot: Self.snapshot(), sessionUserID: Self.userA,
                        resolutionEnabled: true, now: Self.now))
    }

    @Test func accountEntitlementExpirado_noPro() {
        let expired = Self.snapshot(expiresAt: Self.now.addingTimeInterval(-1))
        #expect(L.isPro(localActive: false, snapshot: expired, sessionUserID: Self.userA,
                        resolutionEnabled: true, now: Self.now) == false)
    }

    /// Justo en el instante de expiración ya NO hay derecho (`>`, no `>=`): el borde se resuelve
    /// contra el usuario para no servir un derecho caducado ni un segundo.
    @Test func accountEntitlementEnElInstanteDeExpiracion_noPro() {
        #expect(L.isPro(localActive: false, snapshot: Self.snapshot(expiresAt: Self.now),
                        sessionUserID: Self.userA, resolutionEnabled: true, now: Self.now) == false)
    }

    @Test func snapshotSinExpiry_noPro() {
        #expect(L.isPro(localActive: false, snapshot: Self.snapshot(expiresAt: nil),
                        sessionUserID: Self.userA, resolutionEnabled: true, now: Self.now) == false)
    }

    // MARK: - isPro · fronteras de cuenta (la fuga que NO puede ocurrir)

    /// La caché de la cuenta A jamás da Pro a la cuenta B, aunque esté vigente. Es el mismo
    /// invariante que el sello del handover de dispositivo: sin dueño, una caché es una fuga.
    @Test func snapshotDeOtraCuenta_neverGrantsPro() {
        #expect(L.isPro(localActive: false, snapshot: Self.snapshot(userID: Self.userA),
                        sessionUserID: Self.userB, resolutionEnabled: true, now: Self.now) == false)
    }

    /// Sin sesión de nube no hay derecho de cuenta, por vigente que esté el snapshot (post sign-out
    /// antes de que la purga corra, o una caché superviviente a un kill).
    @Test func sinSesion_neverGrantsPro() {
        #expect(L.isPro(localActive: false, snapshot: Self.snapshot(), sessionUserID: nil,
                        resolutionEnabled: true, now: Self.now) == false)
    }

    @Test func sinSnapshot_noPro() {
        #expect(L.isPro(localActive: false, snapshot: nil, sessionUserID: Self.userA,
                        resolutionEnabled: true, now: Self.now) == false)
    }

    // MARK: - shouldRefresh

    @Test func refresh_sinSesion_nunca() {
        #expect(L.shouldRefresh(snapshot: nil, sessionUserID: nil, now: Self.now) == false)
        #expect(L.shouldRefresh(snapshot: Self.snapshot(), sessionUserID: nil, now: Self.now) == false)
    }

    @Test func refresh_sinCache_siempre() {
        #expect(L.shouldRefresh(snapshot: nil, sessionUserID: Self.userA, now: Self.now))
    }

    /// Cambió el dueño de la sesión: la caché de la otra cuenta no se reutiliza, se reemplaza ya.
    @Test func refresh_cacheDeOtraCuenta_inmediato() {
        #expect(L.shouldRefresh(snapshot: Self.snapshot(userID: Self.userB),
                                sessionUserID: Self.userA, now: Self.now))
    }

    @Test func refresh_cacheFresca_no() {
        let fresh = Self.snapshot(refreshedAt: Self.now.addingTimeInterval(-60))
        #expect(L.shouldRefresh(snapshot: fresh, sessionUserID: Self.userA, now: Self.now) == false)
    }

    @Test func refresh_cacheVieja_si() {
        let stale = Self.snapshot(refreshedAt: Self.now.addingTimeInterval(-6 * 3600))
        #expect(L.shouldRefresh(snapshot: stale, sessionUserID: Self.userA, now: Self.now))
    }

    /// Una caché VIEJA sigue dando Pro mientras el refresco no llegue (avión, backend caído): la
    /// validez la gobierna el expiry firmado por Apple, no la frescura de la lectura.
    @Test func cacheViejaPeroVigente_sigueDandoPro() {
        let stale = Self.snapshot(refreshedAt: Self.now.addingTimeInterval(-7 * 24 * 3600))
        #expect(L.shouldRefresh(snapshot: stale, sessionUserID: Self.userA, now: Self.now))
        #expect(L.isPro(localActive: false, snapshot: stale, sessionUserID: Self.userA,
                        resolutionEnabled: true, now: Self.now))
    }

    // MARK: - Gracia offline (tope de la caché)

    /// Un snapshot que lleva más de la gracia sin revalidar deja de conceder derecho AUNQUE Apple
    /// hubiera firmado una fecha lejana: sin este tope, un `expires_at` en 2099 (bug de unidades,
    /// backend comprometido) daría Pro perpetuo a un device que ya no puede revalidar nada.
    @Test func masAlláDeLaGraciaOffline_dejaDeDarPro() {
        let ancient = Self.snapshot(
            expiresAt: Self.now.addingTimeInterval(365 * 24 * 3600),
            refreshedAt: Self.now.addingTimeInterval(-31 * 24 * 3600))
        #expect(L.isPro(localActive: false, snapshot: ancient, sessionUserID: Self.userA,
                        resolutionEnabled: true, now: Self.now) == false)
        #expect(L.shouldRefresh(snapshot: ancient, sessionUserID: Self.userA, now: Self.now))
    }

    /// Dentro de la gracia, el mismo snapshot lejano SÍ vale: un mes sin red no puede costarte Pro.
    @Test func dentroDeLaGraciaOffline_sigueDandoPro() {
        let recent = Self.snapshot(
            expiresAt: Self.now.addingTimeInterval(365 * 24 * 3600),
            refreshedAt: Self.now.addingTimeInterval(-29 * 24 * 3600))
        #expect(L.isPro(localActive: false, snapshot: recent, sessionUserID: Self.userA,
                        resolutionEnabled: true, now: Self.now))
    }

    /// El expiry EFECTIVO es el menor de los dos: lo que firmó Apple y el tope de la gracia.
    @Test func effectiveExpiry_esElMenorDeLosDos() {
        let corto = Self.snapshot(expiresAt: Self.now.addingTimeInterval(3600),
                                  refreshedAt: Self.now)
        #expect(L.effectiveExpiry(corto) == Self.now.addingTimeInterval(3600))

        let largo = Self.snapshot(expiresAt: Self.now.addingTimeInterval(365 * 24 * 3600),
                                  refreshedAt: Self.now)
        #expect(L.effectiveExpiry(largo) == Self.now.addingTimeInterval(L.offlineGrace))

        #expect(L.effectiveExpiry(Self.snapshot(expiresAt: nil)) == nil)
    }

    // MARK: - Borde de renovación (el bug que más caro sale)

    /// Una mensual que renueva deja el snapshot caducado un instante después. Sin esta regla, el
    /// throttle de 6 h dejaría al pagador en Free —con red y con la renovación ya cobrada— y encima
    /// dispararía el flujo destructivo de downgrade.
    @Test func snapshotCaducado_refrescaYaAunqueSeaReciente() {
        let justRenewed = Self.snapshot(
            expiresAt: Self.now.addingTimeInterval(-60),          // caducó hace un minuto
            refreshedAt: Self.now.addingTimeInterval(-120))       // leído hace dos: fresquísimo
        #expect(L.shouldRefresh(snapshot: justRenewed, sessionUserID: Self.userA, now: Self.now),
                "un snapshot sin derecho vigente se refresca YA, sin esperar al intervalo")
    }

    /// Cuenta sin suscripción (snapshot sin expiry): se vuelve a preguntar, por si acaba de comprar
    /// en otro device.
    @Test func snapshotSinDerecho_refrescaSinEsperar() {
        #expect(L.shouldRefresh(snapshot: Self.snapshot(expiresAt: nil, refreshedAt: Self.now),
                                sessionUserID: Self.userA, now: Self.now))
    }
}
