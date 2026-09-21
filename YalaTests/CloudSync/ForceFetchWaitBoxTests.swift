//
//  ForceFetchWaitBoxTests.swift
//  YalaTests
//
//  La resolución única de `iCloudSyncService.forceFetchAndWait`, probada en la pieza y no en el SUT.
//
//  **Por qué existe este fichero, y es una lección de método.** Los casos de cancelación de
//  `iCloudSyncServiceTests` prueban que la espera devuelve pronto; lo que NO pueden probar es lo que la
//  espera SUELTA al resolver: un `NotificationCenter` no dice cuántos observers tiene, y el `Task` del
//  tope no es observable desde fuera de la caja. Medido el 2026-09-21: un mutante que quita el `guard`
//  de resolución única **sobrevive** a la suite entera, porque el doble `resume` lo tapa por casualidad
//  el `continuation = nil` de la línea siguiente. Un término que ningún test puede matar es un término
//  que sobra — o, como aquí, uno al que le falta su test.
//

import Foundation
import Testing

@testable import Yala

/// **`.timeLimit` no es adorno, y lo pidió la review.** Estos casos hacen `await withCheckedContinuation`
/// sin tope propio, así que los tres mutantes que dejan la caja resuelta con la continuation dentro
/// —`arm` sin la rama `pendingValue`, `resolve` sin guardar `pendingValue`, `arm` sin guardar la
/// continuation— no la resuelven NUNCA y el caso se suspende para siempre: un cuelgue no da veredicto y
/// se lleva la corrida entera. Es la misma regla que obliga al tope propio en `iCloudSyncServiceTests`,
/// aplicada aquí, que es donde vive el modo de fallo.
@Suite("La resolución única de la espera del primer import", .timeLimit(.minutes(1)))
struct ForceFetchWaitBoxTests {

    /// Un `Task` que no termina solo, para comprobar quién lo cancela.
    private func tareaViva() -> Task<Void, Never> {
        Task { try? await Task.sleep(for: .seconds(30)) }
    }

    /// El caso feliz: la primera vía que resuelve se lleva el valor, y suelta las dos cosas que la
    /// espera retenía. **El `timeoutTask.cancel()` es la mitad que nadie veía**: hasta este ticket, una
    /// espera resuelta por la notificación a los 2 s dejaba su sleep de 15 s (o 90) durmiendo detrás.
    @Test("resolver suelta el observer y CANCELA el `Task` del tope")
    func resolvingReleasesObserverAndTimeoutTask() async {
        let caja = ForceFetchWaitBox()
        let tope = tareaViva()
        let nombre = Notification.Name("yala.test.forceFetchWaitBox.\(UUID().uuidString)")
        nonisolated(unsafe) var avisos = 0
        let observer = NotificationCenter.default.addObserver(
            forName: nombre, object: nil, queue: nil) { _ in avisos += 1 }

        let valor: Bool = await withCheckedContinuation { continuation in
            caja.arm(continuation: continuation, observer: observer, timeoutTask: tope)
            caja.resolve(true)
        }

        #expect(valor == true)
        #expect(tope.isCancelled, """
            El `Task` del tope sobrevivió a la resolución. Es el trabajo fantasma que este ticket \
            cierra: un desenlace feliz a los 2 s dejaba durmiendo el sleep de 15 s del arranque o el de \
            90 s del restore, con todo lo que retiene.
            """)

        NotificationCenter.default.post(name: nombre, object: nil)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(avisos == 0, """
            El observer sigue registrado tras resolver la espera. Cada espera abandonada dejaría el \
            suyo vivo para siempre.
            """)
    }

    /// La carrera que obliga a que exista `pendingValue`: la cancelación llega ANTES de que haya
    /// continuation, porque `withTaskCancellationHandler` corre su `onCancel` antes de `operation`
    /// cuando el `Task` ya venía cancelado. Sin cobrarlo al armar, la espera NO RESUELVE NUNCA.
    @Test("resolver ANTES de armar se cobra al armar")
    func resolvingBeforeArmingIsHonouredOnArm() async {
        let caja = ForceFetchWaitBox()
        let tope = tareaViva()
        // El observer se vigila igual que en el caso de arriba: la rama `pendingValue` de `arm` tiene
        // su PROPIA llamada a `removeObserver`, y sin esta cuenta su único guardián era el source-scan.
        let nombre = Notification.Name("yala.test.forceFetchWaitBox.\(UUID().uuidString)")
        nonisolated(unsafe) var avisos = 0
        let observer = NotificationCenter.default.addObserver(
            forName: nombre, object: nil, queue: nil) { _ in avisos += 1 }

        caja.resolve(false)
        let valor: Bool = await withCheckedContinuation { continuation in
            caja.arm(continuation: continuation, observer: observer, timeoutTask: tope)
        }

        #expect(valor == false)
        #expect(tope.isCancelled, "armar sobre una caja ya resuelta también tiene que soltar el tope")

        NotificationCenter.default.post(name: nombre, object: nil)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(avisos == 0, """
            La rama que cobra el valor pendiente no retiró el observer. Es el camino de la cancelación \
            que llega antes que la continuation — el más frecuente de los tres, no un borde.
            """)
    }

    /// Y **una sola vez**: la segunda resolución no cambia el valor con el que se resolvió la primera.
    /// Es el invariante que da nombre a la clase, y el que el mutante del 2026-09-21 destapó sin red:
    /// las tres vías (notificación, tope, cancelación) compiten de verdad, y aquí llegan las dos que
    /// pueden hacerlo antes de que exista la continuation.
    @Test("la SEGUNDA resolución no pisa a la primera")
    func theSecondResolutionIsIgnored() async {
        let caja = ForceFetchWaitBox()
        let tope = tareaViva()
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("yala.test.\(UUID().uuidString)"), object: nil, queue: nil) { _ in }
        defer { NotificationCenter.default.removeObserver(observer) }

        caja.resolve(false)   // la cancelación llega primero
        caja.resolve(true)    // y la notificación después, todavía sin continuation
        let valor: Bool = await withCheckedContinuation { continuation in
            caja.arm(continuation: continuation, observer: observer, timeoutTask: tope)
        }

        #expect(valor == false, """
            La segunda resolución pisó a la primera. Quien gana es quien llega antes: sin el `guard` de \
            resolución única, la espera devuelve el valor de la vía equivocada — y con la continuation \
            ya instalada, ese mismo hueco es un doble `resume`, que es un CRASH y no un test rojo.
            """)
    }

    /// Resolver DESPUÉS de haber resuelto, ya con la continuation consumida, tiene que ser un no-op
    /// silencioso. Es lo que pasa en producción cada vez que el tope expira tras un desenlace feliz.
    ///
    /// **Es un caso-documento y conviene decirlo**: su aserción la cubre el primero, y el mutante del
    /// `guard` lo mata `theSecondResolutionIsIgnored`. Lo que aporta, con el `.timeLimit` de la suite,
    /// es que ese segundo `resolve` no cuelgue ni haga saltar el doble `resume`.
    @Test("resolver otra vez con la continuation ya consumida es inocuo")
    func resolvingAgainAfterTheContinuationIsGoneIsANoOp() async {
        let caja = ForceFetchWaitBox()
        let tope = tareaViva()
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("yala.test.\(UUID().uuidString)"), object: nil, queue: nil) { _ in }
        defer { NotificationCenter.default.removeObserver(observer) }

        let valor: Bool = await withCheckedContinuation { continuation in
            caja.arm(continuation: continuation, observer: observer, timeoutTask: tope)
            caja.resolve(true)
        }
        caja.resolve(false)   // el tope, que llega tarde

        #expect(valor == true)
    }
}
