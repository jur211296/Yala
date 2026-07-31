//
//  AttestRefreshBackoffLogicTests.swift
//  YalaTests
//
//  La caché negativa del refresh de App Attest: cuándo se vuelve a intentar tras un fallo.
//
//  El caso que dio origen a esto está MEDIDO en producción el 2026-07-31 (`wrangler tail --env
//  production`, iPhone real): con la atestación rota el device emitió ~17 `POST /v1/attest/challenge`
//  en 3 segundos. El single-flight de `AppAttestClient` ya colapsaba lo simultáneo; lo que no existía
//  era memoria del fallo, así que cada llamador SUCESIVO arrancaba su propio refresh.
//
//  El test que de verdad protege algo es `laTormentaMedida_seColapsa`: reproduce el episodio real y
//  exige que esas 17 llamadas produzcan 2 intentos. Es la barrera contra «simplificar» el backoff a un
//  reintento inmediato, y contra el primer escalón puesto a 0 «para no molestar al usuario».
//

import Foundation
import Testing

@testable import Yala

@Suite("App Attest · caché negativa y backoff del refresh")
struct AttestRefreshBackoffLogicTests {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func state(_ at: Date, _ count: Int) -> AttestRefreshBackoffLogic.FailureState {
        .init(at: at, consecutiveCount: count)
    }

    // MARK: - Sin fallo previo no hay nada que suprimir

    @Test func sinFalloPrevio_intenta() {
        #expect(AttestRefreshBackoffLogic.decide(lastFailure: nil, now: t0) == .attempt)
    }

    @Test func trasUnExito_elEstadoSeLimpiaYVuelveAIntentar() {
        // `AppAttestClient` pone `lastFailure = nil` al obtener token; esto pinnea que ese nil basta
        // (no queda ninguna ventana residual dependiente de la racha anterior).
        #expect(
            AttestRefreshBackoffLogic.decide(lastFailure: nil, now: t0.addingTimeInterval(0.001))
                == .attempt)
    }

    // MARK: - Dentro de la ventana: se calla

    @Test func dentroDeLaVentana_suprimeYDiceCuantoQueda() {
        let d = AttestRefreshBackoffLogic.decide(
            lastFailure: state(t0, 1), now: t0.addingTimeInterval(0.5))
        #expect(d == .suppress(retryAfter: 1.5))
    }

    @Test func inmediatamenteDespuesDelFallo_suprimeLaVentanaEntera() {
        // El caso literal de la tormenta: seis llamadores llegando en el mismo instante.
        #expect(
            AttestRefreshBackoffLogic.decide(lastFailure: state(t0, 1), now: t0)
                == .suppress(retryAfter: 2))
    }

    // MARK: - Al expirar: se intenta

    @Test func justoAlExpirarLaVentana_intenta() {
        // Frontera inclusiva a propósito: `elapsed >= wait` intenta. Un `>` dejaría el instante exacto
        // en tierra de nadie y haría el test de la escalera dependiente del error de coma flotante.
        #expect(
            AttestRefreshBackoffLogic.decide(lastFailure: state(t0, 1), now: t0.addingTimeInterval(2))
                == .attempt)
    }

    @Test func muchoDespues_intenta() {
        #expect(
            AttestRefreshBackoffLogic.decide(
                lastFailure: state(t0, 5), now: t0.addingTimeInterval(3_600)) == .attempt)
    }

    // MARK: - La escalera y su tope

    @Test func laEscaleraEsLaDeclarada() {
        #expect(AttestRefreshBackoffLogic.delay(consecutiveFailures: 1) == 2)
        #expect(AttestRefreshBackoffLogic.delay(consecutiveFailures: 2) == 5)
        #expect(AttestRefreshBackoffLogic.delay(consecutiveFailures: 3) == 15)
        #expect(AttestRefreshBackoffLogic.delay(consecutiveFailures: 4) == 30)
        #expect(AttestRefreshBackoffLogic.delay(consecutiveFailures: 5) == 60)
    }

    @Test func elTopeSatura_noCreceSinLimite() {
        // Un fallo permanente (key que el gateway no acepta, device sin App Attest) no puede acabar
        // esperando horas: 60 s es el techo, y sigue siendo ~340× menos tráfico que lo medido.
        #expect(AttestRefreshBackoffLogic.delay(consecutiveFailures: 6) == 60)
        #expect(AttestRefreshBackoffLogic.delay(consecutiveFailures: 500) == 60)
        #expect(
            AttestRefreshBackoffLogic.decide(
                lastFailure: state(t0, 500), now: t0.addingTimeInterval(61)) == .attempt)
    }

    @Test func rachaNoPositiva_noEspera() {
        // Defensivo: `record` nunca produce 0, pero un 0 que llegara no debe convertirse en `delays[-1]`.
        #expect(AttestRefreshBackoffLogic.delay(consecutiveFailures: 0) == 0)
        #expect(AttestRefreshBackoffLogic.delay(consecutiveFailures: -3) == 0)
        #expect(AttestRefreshBackoffLogic.decide(lastFailure: state(t0, 0), now: t0) == .attempt)
    }

    // MARK: - La racha

    @Test func record_desdeCeroEmpiezaEnUno() {
        let s = AttestRefreshBackoffLogic.record(previous: nil, now: t0)
        #expect(s == state(t0, 1))
    }

    @Test func record_acumulaYMueveElInstante() {
        let t1 = t0.addingTimeInterval(3)
        let s = AttestRefreshBackoffLogic.record(previous: state(t0, 2), now: t1)
        #expect(s == state(t1, 3))
    }

    // MARK: - Reloj hacia atrás

    @Test func falloEnElFuturo_intenta() {
        // Reloj del device movido hacia atrás. Sin esta rama el attest quedaría atascado durante el
        // TAMAÑO del error — el mismo fallo silencioso y permanente que este subsistema ya sufrió.
        #expect(
            AttestRefreshBackoffLogic.decide(
                lastFailure: state(t0.addingTimeInterval(86_400), 3), now: t0) == .attempt)
    }

    // MARK: - El episodio medido

    @Test func laTormentaMedida_seColapsa() {
        // 17 llamadas repartidas por igual en 3 s — la firma exacta de `wrangler tail` del 2026-07-31,
        // con TODAS fallando. Antes del fix cada una era un `POST /v1/attest/challenge`.
        let total = 17
        let ventana: TimeInterval = 3
        var lastFailure: AttestRefreshBackoffLogic.FailureState?
        var intentos = 0

        for i in 0..<total {
            let now = t0.addingTimeInterval(ventana / Double(total) * Double(i))
            guard AttestRefreshBackoffLogic.decide(lastFailure: lastFailure, now: now) == .attempt else {
                continue
            }
            intentos += 1
            lastFailure = AttestRefreshBackoffLogic.record(previous: lastFailure, now: now)
        }

        #expect(
            intentos == 2,
            """
            \(total) llamadas en \(ventana)s produjeron \(intentos) intentos. La tormenta medida en \
            producción eran 17; el contrato de esta lógica es que se queden en 2 (el primero, que no \
            puede saber nada, y uno más al abrirse la ventana de 2 s).
            """)
    }

    @Test func trasLaTormenta_elRitmoSostenidoCae() {
        // La otra mitad: si el fallo PERSISTE, el ritmo tiene que seguir bajando. Un minuto entero de
        // llamadas cada 100 ms son 600 oportunidades; el contrato es que salgan un puñado.
        var lastFailure: AttestRefreshBackoffLogic.FailureState?
        var intentos = 0
        for i in 0..<600 {
            let now = t0.addingTimeInterval(0.1 * Double(i))
            guard AttestRefreshBackoffLogic.decide(lastFailure: lastFailure, now: now) == .attempt else {
                continue
            }
            intentos += 1
            lastFailure = AttestRefreshBackoffLogic.record(previous: lastFailure, now: now)
        }
        // 0s, 2s, 7s, 22s, 52s → el sexto caería en 112s, fuera del minuto.
        #expect(intentos == 5, "600 llamadas en 60 s produjeron \(intentos) intentos (se esperaban 5).")
    }
}
