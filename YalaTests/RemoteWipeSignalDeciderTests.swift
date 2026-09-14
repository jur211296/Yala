//
//  RemoteWipeSignalDeciderTests.swift
//  YalaTests
//
//  Pure-logic tests para RemoteWipeSignalDecider. Sin SwiftData ni UI.
//  Cubre los 4 cases de la matriz de decisión + idempotencia + el eje de sesión.
//

import Foundation
import Testing

@testable import Yala

struct RemoteWipeSignalDeciderTests {

    // MARK: - Fresh-install guard (bug #6 fix)

    @Test func decide_freshInstall_doesNotProcess() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: false,
            isWipingData: false,
            hasRemoteWipeTimestamp: true,
            sessionObeysWipeSignal: true
        )
        #expect(decision.shouldProcess == false)
    }

    @Test func decide_freshInstall_marksSignalsAsProcessedForIdempotency() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: false,
            isWipingData: false,
            hasRemoteWipeTimestamp: true,
            sessionObeysWipeSignal: true
        )
        #expect(decision.shouldMarkSignalsAsProcessed == true)
    }

    @Test func decide_freshInstallNoRemoteSignal_doesNotMark() {
        // KV-Store limpio (Apple ID nunca tuvo Yala) — no hay nada que marcar.
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: false,
            isWipingData: false,
            hasRemoteWipeTimestamp: false,
            sessionObeysWipeSignal: true
        )
        #expect(decision.shouldProcess == false)
        #expect(decision.shouldMarkSignalsAsProcessed == false)
    }

    // MARK: - Returning user (no regresión cross-device wipe)

    @Test func decide_returningUser_processes() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: true,
            isWipingData: false,
            hasRemoteWipeTimestamp: true,
            sessionObeysWipeSignal: true
        )
        #expect(decision.shouldProcess == true)
        #expect(decision.shouldMarkSignalsAsProcessed == false)
    }

    // MARK: - Self-wipe guard (no auto-react al propio signal)

    @Test func decide_isWipingData_doesNotProcess() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: true,
            isWipingData: true,
            hasRemoteWipeTimestamp: true,
            sessionObeysWipeSignal: true
        )
        #expect(decision.shouldProcess == false)
    }

    @Test func decide_isWipingData_doesNotMark() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: true,
            isWipingData: true,
            hasRemoteWipeTimestamp: true,
            sessionObeysWipeSignal: true
        )
        #expect(decision.shouldMarkSignalsAsProcessed == false)
    }

    // MARK: - El eje de SESIÓN (ticket `remote-wipe-signal-honored-by-any-session`)

    /// El bug que cierra este ticket, en su forma exacta: un returning user con estado local —o sea, todo
    /// lo que los dos guards anteriores dejaban pasar— borraba sus filas aunque su sesión fuese la de la
    /// nube o la de solo grupos.
    ///
    /// **La matriz de abajo lo caza igual, y este caso no añade poder de mutación**: está aquí porque es
    /// la frase del ticket escrita como código, y en un log de fallos su nombre dice qué se rompió
    /// mientras que el de la matriz solo dice que una celda no cuadra.
    @Test func decide_sessionDoesNotObey_doesNotProcess() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: true,
            isWipingData: false,
            hasRemoteWipeTimestamp: true,
            sessionObeysWipeSignal: false
        )
        #expect(decision.shouldProcess == false)
    }

    /// Y no marca nada: la señal ya la consumió quien la detectó
    /// (`PreferenceSyncService.checkForRemoteWipeSignal` escribe `WipeKey.localWipe` antes de preguntar).
    /// Marcar aquí silenciaría además el timestamp de ONBOARDING, que este caso no toca.
    @Test func decide_sessionDoesNotObey_doesNotMark() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: true,
            isWipingData: false,
            hasRemoteWipeTimestamp: true,
            sessionObeysWipeSignal: false
        )
        #expect(decision.shouldMarkSignalsAsProcessed == false)
    }

    /// **El caso que fija el ORDEN de los guards.** Un fresh-install cuyo KV viene contaminado por una
    /// instalación anterior tiene que MARCAR la señal aunque su sesión no la obedezca — si no, el signal
    /// se re-postea en cada arranque hasta que el onboarding termine, que es cuando el bug #6 hacía daño.
    /// Mover el eje de sesión por delante del guard de fresh-install mata esa marca.
    ///
    /// Como el anterior, la matriz lo cubre; se queda por su nombre.
    @Test func decide_freshInstallInANonObeyingSession_stillMarksForIdempotency() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: false,
            isWipingData: false,
            hasRemoteWipeTimestamp: true,
            sessionObeysWipeSignal: false
        )
        #expect(decision.shouldProcess == false)
        #expect(decision.shouldMarkSignalsAsProcessed == true)
    }

    /// **El oráculo completo.** Cuatro `Bool` de entrada y dos de salida: las 16 combinaciones son la
    /// tabla de verdad entera, así que esto no «prueba con ejemplos», la fija.
    ///
    /// La especificación va escrita como dos expresiones PLANAS y la implementación es una cascada de
    /// `if`. Eso no protege «la forma de cascada» —colapsar la implementación a estas mismas dos
    /// expresiones es equivalente y sale verde, y debe salirlo—: lo que demuestra es que **el orden
    /// elegido para los guards produce exactamente esta tabla**, que es lo único observable desde fuera.
    /// Cualquier reordenación de los tres guards cambia la tabla y muere aquí.
    ///
    /// **Lo que NO alcanza, dicho entero:** esto solo lee el struct devuelto, así que un efecto lateral
    /// dentro del cuerpo es invisible; y todo lo que esté FUERA del cuerpo —un valor por defecto en la
    /// firma, un `#if DEBUG` alrededor de un guard, un término que lea estado ambiente— pasa los 16
    /// casos porque los 16 los pasan explícitos. Eso lo cubre `RemoteWipeSignalWiringTests`.
    @Test func decide_matrizCompleta_contraLaEspecificacion() {
        let bools = [true, false]
        for onboarding in bools {
            for wiping in bools {
                for timestamp in bools {
                    for obeys in bools {
                        let d = RemoteWipeSignalDecider.decide(
                            hasCompletedOnboarding: onboarding,
                            isWipingData: wiping,
                            hasRemoteWipeTimestamp: timestamp,
                            sessionObeysWipeSignal: obeys
                        )
                        let debeProcesar = !wiping && onboarding && obeys
                        let debeMarcar = !wiping && !onboarding && timestamp
                        #expect(d.shouldProcess == debeProcesar,
                                "procesar: onboarding=\(onboarding) wiping=\(wiping) ts=\(timestamp) obeys=\(obeys)")
                        #expect(d.shouldMarkSignalsAsProcessed == debeMarcar,
                                "marcar: onboarding=\(onboarding) wiping=\(wiping) ts=\(timestamp) obeys=\(obeys)")
                    }
                }
            }
        }
    }
}

