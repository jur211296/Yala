//
//  StorageMigrationSignInLogicTests.swift
//  YalaTests
//
//  Pinnea el guard R9 de la entrada de migración/adopt (bug C-7 de la auditoría de escenarios,
//  2026-07-27): con sesión de nube viva NO se vuelve a preguntar el método, porque re-firmar
//  permite aterrizar en OTRA cuenta y dejar los datos personales y los grupos en cuentas
//  distintas — justo lo contrario de lo que promete `groups.signin.accountNote`.
//
//  Sin estos tests, el fix se revierte solo: la regresión natural es «devolver el chooser
//  siempre» al tocar la pantalla, y en el simulador no se nota (el chooser se ve idéntico).
//

import Foundation
import Testing

@testable import Yala

@Suite("StorageMigrationSignInLogic · una cuenta, una identidad (C-7)")
struct StorageMigrationSignInLogicTests {

    typealias L = StorageMigrationSignInLogic

    // MARK: - Regla 1: sin sesión ⇒ elección libre (byte-idéntico al comportamiento previo)

    @Test func noSession_asksProvider() {
        #expect(L.decide(hasSession: false, storedProvider: nil) == .askProvider)
    }

    /// Un provider persistido de una sesión YA CERRADA no debe resucitar la cuenta: `signOut()`
    /// borra `keyProvider`, pero si por lo que sea sobreviviera, sin sesión se pregunta igual.
    @Test func noSession_ignoresStaleStoredProvider() {
        #expect(L.decide(hasSession: false, storedProvider: "google") == .askProvider)
        #expect(L.decide(hasSession: false, storedProvider: "apple") == .askProvider)
    }

    // MARK: - Regla 2: sesión viva ⇒ se reusa, jamás se re-pregunta

    @Test func liveSessionApple_reusesWithoutAsking() {
        #expect(L.decide(hasSession: true, storedProvider: "apple") == .reuseLiveSession(provider: .apple))
    }

    /// El caso real del bug: los grupos viven en una cuenta Google y la migración ofrecía Apple
    /// como si fuera una elección — firmar ahí desalojaba la sesión de Grupos en silencio.
    @Test func liveSessionGoogle_reusesWithoutAsking() {
        #expect(L.decide(hasSession: true, storedProvider: "google") == .reuseLiveSession(provider: .google))
    }

    // MARK: - Regla 3: el método es cosmético; la SESIÓN es la autoridad

    /// `keyProvider` perdida (residual documentado del claim, población ~0): se reusa igual y el
    /// copy cae a la línea genérica. Devolver `.askProvider` aquí reabriría el bug entero por un
    /// dato de presentación que falta.
    @Test func liveSessionWithoutStoredProvider_stillReuses_withGenericCopy() {
        #expect(L.decide(hasSession: true, storedProvider: nil) == .reuseLiveSession(provider: nil))
    }

    /// Valor del wire que no es ninguno de los dos métodos conocidos → nunca se interpola crudo
    /// en la UI: viaja como `nil` y el call-site usa el copy genérico.
    @Test func liveSessionWithUnknownProvider_reusesWithGenericCopy() {
        #expect(L.decide(hasSession: true, storedProvider: "facebook") == .reuseLiveSession(provider: nil))
        #expect(L.decide(hasSession: true, storedProvider: "") == .reuseLiveSession(provider: nil))
    }

    // MARK: - Invariante cruzado

    /// Ninguna combinación con sesión viva puede terminar en `.askProvider`. Es el invariante que
    /// protege el fix frente a una regla nueva añadida por delante sin pensar en R9.
    @Test func liveSession_neverAsksProvider() {
        for stored in [nil, "apple", "google", "otro", ""] as [String?] {
            #expect(L.decide(hasSession: true, storedProvider: stored) != .askProvider,
                    "storedProvider=\(stored ?? "nil") con sesión viva debería reusar")
        }
    }

    // MARK: - Adopt en un segundo device (el faro nombra la cuenta esperada)

    /// El iPad recibió por el mirror el marcador del iPhone que migró a la cuenta A, pero dentro hay
    /// una sesión de la cuenta B. Adoptar ahí subiría el corpus bajo la identidad equivocada y
    /// `writeBeacon` reescribiría el faro del device: dos cuentas mezcladas y sin rastro de cuál era.
    @Test func adoptConSesionDeOtraCuenta_bloquea() {
        #expect(L.decide(hasSession: true, storedProvider: "google", isAdopt: true,
                         beaconAccountHash: "hashA", sessionAccountHash: "hashB")
                == .blockedOtherAccount(knownProvider: .google))
    }

    /// La MISMA cuenta que migró re-entra sin fricción: es el camino normal del adopt.
    @Test func adoptConLaMismaCuenta_reusa() {
        #expect(L.decide(hasSession: true, storedProvider: "apple", isAdopt: true,
                         beaconAccountHash: "hashA", sessionAccountHash: "hashA")
                == .reuseLiveSession(provider: .apple))
    }

    /// Sin faro (device que nunca migró, o iCloud KV aún sin bajar) no hay cuenta esperada contra la
    /// que comparar: no se bloquea por una ausencia — sería negarle el adopt a quien sí puede.
    @Test func adoptSinFaro_reusa() {
        #expect(L.decide(hasSession: true, storedProvider: "apple", isAdopt: true,
                         beaconAccountHash: nil, sessionAccountHash: "hashB")
                == .reuseLiveSession(provider: .apple))
    }

    /// La comprobación es SOLO del adopt: en una migración normal el corpus es local y de quien está
    /// dentro. Un faro viejo de otra cuenta no puede bloquear a quien migra sus propios datos.
    @Test func migracionNormal_ignoraElFaro() {
        #expect(L.decide(hasSession: true, storedProvider: "apple", isAdopt: false,
                         beaconAccountHash: "hashA", sessionAccountHash: "hashB")
                == .reuseLiveSession(provider: .apple))
    }

    // MARK: - Belt de la máquina (`execution`)

    /// EL invariante del belt: una sesión usable gana SIEMPRE, incluso si el plan que llega dice
    /// «firma con Google». Un plan obsoleto jamás debe disparar una auth que cambie de cuenta.
    @Test func execution_sesionUsableGanaSobreCualquierPlan() {
        #expect(L.execution(for: .reuseLiveSession, sessionIsUsable: true) == .useLiveSession)
        #expect(L.execution(for: .authenticateWith(.google), sessionIsUsable: true) == .useLiveSession)
        #expect(L.execution(for: .authenticateWith(.apple), sessionIsUsable: true) == .useLiveSession)
    }

    /// Sin sesión usable, el plan manda: autenticar con lo elegido.
    @Test func execution_sinSesion_autenticaConElProviderElegido() {
        #expect(L.execution(for: .authenticateWith(.google), sessionIsUsable: false)
                == .authenticate(.google))
    }

    /// «Reusar» sin sesión usable no puede avanzar la máquina: el claim se quedaría sin JWT y el
    /// journal en una fase transicional. Fallar honesto y dejar que el productor vuelva a decidir.
    @Test func execution_reusoSinSesionUsable_falla() {
        #expect(L.execution(for: .reuseLiveSession, sessionIsUsable: false) == .failNoUsableSession)
    }
}
