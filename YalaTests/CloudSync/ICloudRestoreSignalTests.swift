//
//  ICloudRestoreSignalTests.swift
//  YalaTests
//
//  La señal que le dice al guard cross-cuenta «estas filas las está bajando el propio dueño ahora».
//
//  Dos mitades y ninguna cubre a la otra: la TABLA (cuándo la señal está viva) y el CABLEADO (quién la
//  enciende y quién la lee). La segunda es un source-scan porque lo que decide aquí es QUIÉN llama y en
//  qué orden — molde `AttestWiringTests` / `OwnerKeyValueWiringTests`: la lógica pura puede ser perfecta
//  y sus tests verdes mientras nadie la invoca donde hace falta, o mientras alguien la invoca donde NO.
//

import Foundation
import Testing

@testable import Yala

@Suite("La restauración en curso · la tabla")
struct ICloudRestoreInProgressLogicTests {

    private static let t0 = Date(timeIntervalSince1970: 1_760_000_000)

    /// Atajo: la ventana recién abierta y con el import dando señales de vida, que es el caso normal.
    private static func isRestoring(
        startedAt: Date? = t0,
        firstImport: Bool = false,
        quiescent: Bool = false,
        activity: Bool = true,
        afterSeconds: TimeInterval = 5
    ) -> Bool {
        ICloudRestoreInProgressLogic.isRestoringNow(
            restoreStartedAt: startedAt,
            hasCompletedFirstImport: firstImport,
            isImportQuiescent: quiescent,
            hasObservedImportActivity: activity,
            now: t0.addingTimeInterval(afterSeconds))
    }

    @Test("sin haber pedido restaurar, la señal está SIEMPRE apagada")
    func withoutTheRequest_neverFires() {
        for first in [true, false] {
            for quiescent in [true, false] {
                for activity in [true, false] {
                    #expect(!Self.isRestoring(
                        startedAt: nil, firstImport: first,
                        quiescent: quiescent, activity: activity), """
                        Un import de CloudKit ocurre en cualquier arranque; sin el acto explícito del \
                        usuario, tomarlo por una restauración abre el guard cross-cuenta de par en par.
                        """)
                }
            }
        }
    }

    @Test("pedido el restore, la señal vive mientras el import no ASIENTA")
    func afterTheRequest_livesUntilTheImportSettles() {
        // Aún no ha llegado el primer importEvent completo: es el instante en el que la pantalla de
        // restaurar está contando filas en vivo, o sea el centro exacto del escenario.
        #expect(Self.isRestoring(firstImport: false, quiescent: false))

        // Y la quiescencia SOLA no cierra la ventana: es `true` ANTES del primer import, así que
        // preguntar solo por ella diría «ya terminó» cuando no ha empezado — la misma asimetría que
        // documenta `waitForImportQuiescence`.
        #expect(Self.isRestoring(firstImport: false, quiescent: true), """
            Con solo la quiescencia, la señal se apagaría justo antes de que empiece la descarga: el \
            usuario que vuelve atrás en los primeros segundos volvería a ver el bloqueo.
            """)

        // Importando todavía (llegó un evento, no hay quietud).
        #expect(Self.isRestoring(firstImport: true, quiescent: false))
    }

    @Test("con el import asentado la señal se apaga: esas filas ya son corpus como cualquier otro")
    func settledImport_closesTheWindow() {
        #expect(!Self.isRestoring(firstImport: true, quiescent: true), """
            La ventana tiene que CERRARSE. Si la señal se quedara viva toda la sesión, el guard \
            cross-cuenta quedaría desarmado hasta que el usuario matara la app.
            """)
    }

    // MARK: - Las dos salidas que hacen el sesgo REALMENTE fail-closed
    //
    // Reportadas por la sesión hermana el 2026-08-13 sobre `d3c14350`, y medidas: el primer término
    // era un latch que nunca se apaga y el segundo, `!(A && B)`, devuelve `true` cuando A se
    // desconoce. O sea que la ausencia de información se leía como «sí, está restaurando» — el sesgo
    // declarado («ante la duda, false») estaba INVERTIDO respecto al implementado.

    /// EL caso que abría el guard. `hasCompletedFirstImport` solo se enciende en la rama de import
    /// EXITOSO (`iCloudSyncService.swift:265-272`, dentro del `else if let endDate`), y hay un
    /// escenario en el que no llega NUNCA: el propio docblock de `waitForImportQuiescence` lo dice —
    /// «un store que NADA importa nunca dispara `.importEvent`».
    ///
    /// Camino completo: tocar «Restaurar desde iCloud» (la búsqueda arranca ⇒ latch ON) → no hay
    /// backup → volver atrás → firmar con OTRA cuenta sobre un device con el corpus del dueño. Con la
    /// señal pegada el guard devuelve `.proceed` y se adopta sobre datos ajenos: es exactamente el
    /// incidente que `CrossAccountEntryGuardLogic` existe para impedir.
    @Test("sin NINGUNA actividad de import, la señal se apaga sola pasada la gracia")
    func noImportActivityAtAll_closesTheWindow() {
        // Dentro de la gracia sigue viva: CloudKit puede tardar en emitir su primer evento y apagarla
        // aquí devolvería el bloqueo al dueño legítimo que sí está restaurando.
        #expect(Self.isRestoring(activity: false, afterSeconds: 30))

        #expect(!Self.isRestoring(activity: false, afterSeconds: 61), """
            No hay NI UN `.importEvent` y ha pasado la gracia: no hay ninguna restauración en curso \
            que justifique la ventana. Con la señal pegada, cualquiera puede firmar sobre el corpus \
            de otro humano — el guard cross-cuenta queda desarmado hasta que se mate la app.
            """)
    }

    /// El tope duro es la red que no depende de NADA: ni de que un callback corra, ni de que CloudKit
    /// emita, ni de que la pantalla se desmonte por donde esperamos. Si nada la apagó, se apaga sola.
    @Test("y aunque el import dé señales de vida, la ventana tiene tope")
    func hardCap_closesTheWindowNoMatterWhat() {
        #expect(Self.isRestoring(activity: true, afterSeconds: 599))
        #expect(!Self.isRestoring(activity: true, afterSeconds: 601), """
            Un import que lleva diez minutos sin asentar no es una restauración en curso: es un \
            estado atascado. Mantener la puerta abierta indefinidamente por él es el sesgo inverso al \
            declarado.
            """)
    }
    // MARK: - ¿Este final deja descarga detrás?
    // (`restore-timeout-closes-the-session-window-with-the-import-still-running`, 2026-09-21)

    /// **Las cuatro combinaciones, y las dos que importan son las de la diagonal.** El criterio no es
    /// el desenlace que elige el copy —`RestoreImportSettlement`— sino los dos términos crudos: aquél
    /// agrupa en `.inconclusive` al usuario sin nada que importar con el import que dio un error
    /// vigente, y esos errores suelen ser retriables, con CloudKit trayendo filas detrás.
    @Test("el final cierra la ventana si asentó o si no hubo un solo import, y no en otro caso")
    func closingTheWindowFollowsTheTwoRawTerms() {
        #expect(ICloudRestoreInProgressLogic.closesTheSessionWindow(
            settled: true, hasObservedImportActivity: true), """
            El import ASENTÓ y la ventana se queda abierta hasta caducar. Esas filas ya son corpus como \
            cualquier otro y el guard de frontera de cuenta no tiene por qué seguir entornado.
            """)
        #expect(ICloudRestoreInProgressLogic.closesTheSessionWindow(
            settled: true, hasObservedImportActivity: false),
            "asentar cierra pase lo que pase con el testigo")
        #expect(ICloudRestoreInProgressLogic.closesTheSessionWindow(
            settled: false, hasObservedImportActivity: false), """
            El tope se agotó SIN un solo `.importEvent`: no hay nada bajando ni lo hubo, y es la \
            población del usuario realmente nuevo. Dejarle la ventana abierta pierde la precisión que \
            este apagado aporta sobre la caducidad — hasta 60 s de gracia con el guard entornado.
            """)
        #expect(!ICloudRestoreInProgressLogic.closesTheSessionWindow(
            settled: false, hasObservedImportActivity: true), """
            **EL CASO DEL TICKET.** El tope se agotó habiendo visto un import: las filas siguen \
            entrando. Apagar aquí pone `restoreStartedAt` a `nil` con la descarga viva, y el dueño \
            legítimo que toque atrás y firme con su cuenta se encuentra un `.blockedForeignData` sobre \
            sus propios datos. Es el bug entero.
            """)
    }

    /// **El control por separado de cada término, que es lo que impide "arreglarlo" con una constante.**
    /// Con `true` fijo vuelve el ticket; con `false` fijo, la ventana del usuario nuevo vive hasta
    /// caducar. Y con `settled || hasObservedImportActivity` —el `!` perdido— se invierte justo en las
    /// dos filas que deciden.
    @Test("MUTACIÓN: los dos términos por separado, y ninguna constante los cumple")
    func neitherConstantSatisfiesBothTerms() {
        let filas: [(settled: Bool, activity: Bool, esperado: Bool)] = [
            (true,  true,  true),
            (true,  false, true),
            (false, false, true),
            (false, true,  false),
        ]
        for fila in filas {
            let cierra = ICloudRestoreInProgressLogic.closesTheSessionWindow(
                settled: fila.settled, hasObservedImportActivity: fila.activity)
            #expect(cierra == fila.esperado, Comment(rawValue: """
                settled=\(fila.settled) actividad=\(fila.activity) ⇒ cierra=\(cierra), \
                esperado \(fila.esperado)
                """))
        }
        // Y que el resultado NO sea constante, que es lo que ninguna fila sola comprueba.
        let valores = Set(filas.map {
            ICloudRestoreInProgressLogic.closesTheSessionWindow(
                settled: $0.settled, hasObservedImportActivity: $0.activity)
        })
        #expect(valores == [true, false],
                "el criterio se volvió una constante: deja de separar población ninguna")
    }

}

@Suite("La restauración en curso · el latch de sesión", .serialized)
struct ICloudRestoreSessionSignalTests {

    @Test("nace apagada y solo la enciende el arranque de la búsqueda")
    @MainActor
    func latchStartsOffAndOnlyTheSearchTurnsItOn() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil)
        _ = ICloudRestoreSessionSignal.noteRestoreStarted(hasObservedImportActivity: false)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt != nil)
    }

    /// **DENTRO de un restore vivo el reloj no se re-ancla**, y ésa es la condición que impide que el
    /// tope duro sea una ventana extensible: un flujo que sigue siendo dueño y vuelve a pasar por el
    /// encendido se queda con su instante original.
    ///
    /// **Ojo con lo que este test NO dice**, porque hasta el 2026-09-21 el docblock lo decía por él:
    /// no cubre los cinco botones de «volver a buscar» de `WelcomeRestoreView`. Medido — solo salen
    /// en estados terminales, todos aguas abajo de `noteRestoreFinished`, así que cuando el usuario
    /// los toca ya no hay dueño NI reloj y la entrada estrena ventana, igual antes del ticket que
    /// después. Lo que se mide aquí es el invariante de la API, no aquel camino.
    @Test("re-arrancar con el dueño vigente NO reinicia el reloj de la ventana")
    @MainActor
    func restartingTheSearchDoesNotExtendTheWindow() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        _ = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: true)
        // Con el import dando señales de vida, que es el caso que MÁS invita a re-anclar: si el
        // término del dueño no estuviera, el testigo de arriba bastaría para renovar la ventana.
        _ = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0.addingTimeInterval(300),
                                                         hasObservedImportActivity: true)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t0, """
            Con un dueño vigente, el reloj se re-ancló en la entrada nueva. El tope duro pasa a ser \
            extensible: quien vuelva a pasar por el encendido sin soltar la titularidad renueva sus \
            600 s, y el guard de frontera de cuenta se queda abierto tanto como alguien insista.
            """)
    }

    /// El apagado explícito: cuando el flujo termina **sin dejar descarga detrás** la ventana se
    /// cierra sin esperar a la caducidad. («Gane o pierda» valió hasta el 2026-09-21: quién llega a
    /// este verbo lo decide hoy `ICloudRestoreInProgressLogic.closesTheSessionWindow`.)
    @Test("terminar el flujo cierra la ventana")
    @MainActor
    func finishingTheFlowClosesTheWindow() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let flujo = ICloudRestoreSessionSignal.noteRestoreStarted(hasObservedImportActivity: false)
        ICloudRestoreSessionSignal.noteRestoreFinished(flujo)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil)
        #expect(ICloudRestoreSessionSignal.currentFlow == nil, """
            La ventana se cerró pero su dueño se quedó puesto. Terminar es el único acto que apaga \
            LAS DOS cosas: un dueño sin reloj rompe el invariante `currentFlow != nil ⇒ \
            restoreStartedAt != nil` y deja un token viejo gobernando una ventana que ya no existe.
            """)
        #expect(!ICloudRestoreSessionSignal.isRestoringNow)
    }

    // MARK: - El reloj y el dueño, separados
    //
    // `abandoned-restore-no-longer-clears-the-session-window-clock`. Hasta aquí el invariante era
    // `restoreStartedAt == nil ⇔ currentFlow == nil`, o sea que apagar la ventana y liberar su reloj
    // eran el MISMO acto — y con `force-fetch-and-wait-ignores-cancellation` el flujo abandonado dejó
    // de apagar (con razón: el import sigue bajando), así que dejó también de liberar.

    /// **EL CASO DEL TICKET.** Entro a Restaurar, me arrepiento a los 5 s, y vuelvo a entrar 400 s
    /// después. Con el reloj heredado mi ventana de 600 s se agota a los 200 s de mi descarga real, y
    /// si entonces salgo y firmo, `CrossAccountEntryGuardLogic` me dice que mis datos son de otra
    /// persona.
    @Test("volver a entrar tras abandonar ESTRENA la ventana")
    @MainActor
    func reenteringAfterAnAbandonedAttemptStartsAFreshWindow() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let abandonado = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)
        // t=5 s: toco atrás. La pantalla se va y suelta la titularidad.
        ICloudRestoreSessionSignal.noteRestoreAbandoned(abandonado)

        // t=400: vuelvo a entrar. El import de la primera entrada siguió bajando —CloudKit no para
        // porque yo salga de la pantalla—, así que hay actividad observada y la ventana se estrena.
        let t400 = t0.addingTimeInterval(400)
        _ = ICloudRestoreSessionSignal.noteRestoreStarted(now: t400, hasObservedImportActivity: true)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t400, """
            La entrada nueva heredó el reloj del intento que la persona abandonó. Su tope duro caduca \
            200 s después de empezar a bajar datos en vez de a los 600, y el guard de frontera de \
            cuenta se cierra sobre el dueño legítimo con su propio import a medias — el ticket entero.
            """)
    }

    /// **La otra cara de re-anclar, y la cazó una lente de la review.** Si una entrada nueva pudiera
    /// estrenar reloj SIEMPRE que no hay dueño, entrar y salir de Restaurar cada menos de 60 s
    /// renovaría la ventana indefinidamente: `isRestoringNow` mide todos sus plazos desde
    /// `restoreStartedAt`, la gracia incluida, así que el tope duro dejaría de ser un tope. En un
    /// teléfono con el corpus de otra persona eso mantiene abierta de par en par la puerta que
    /// `CrossAccountEntryGuardLogic` existe para cerrar.
    ///
    /// Lo que lo impide es el testigo del import: sin un solo `.importEvent` no hay descarga que
    /// justifique una ventana nueva.
    @Test("sin NINGUNA descarga detrás, volver a entrar NO re-ancla la ventana")
    @MainActor
    func reenteringWithoutImportActivityDoesNotReArmTheWindow() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        // Tres vueltas de entrar-y-salir, todas sin que CloudKit emita nada.
        var reloj = t0
        for vuelta in 0..<3 {
            let intento = ICloudRestoreSessionSignal.noteRestoreStarted(
                now: reloj, hasObservedImportActivity: false)
            ICloudRestoreSessionSignal.noteRestoreAbandoned(intento)
            reloj = t0.addingTimeInterval(Double(vuelta + 1) * 50)
        }
        _ = ICloudRestoreSessionSignal.noteRestoreStarted(now: reloj, hasObservedImportActivity: false)

        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t0, """
            El ciclo entrar-salir re-ancló la ventana sin una sola descarga detrás. El tope duro deja \
            de ser un tope: quien navegue más rápido que la gracia de 60 s mantiene abierto el guard \
            de frontera de cuenta todo lo que quiera, y en un teléfono con el corpus de otra persona \
            eso es exactamente la adopción que el guard impide.
            """)
    }

    /// **La otra mitad, y es la que no se puede romper para arreglar la primera**: soltar la
    /// titularidad NO apaga la ventana. Salir de Restaurar no para el import —CloudKit sigue trayendo
    /// filas—, así que apagar aquí reabre `force-fetch-and-wait-ignores-cancellation` de un plumazo.
    @Test("abandonar NO apaga la ventana: el import sigue bajando")
    @MainActor
    func abandoningLeavesTheWindowOpenForTheImport() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let abandonado = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)
        ICloudRestoreSessionSignal.noteRestoreAbandoned(abandonado)

        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t0, """
            Abandonar apagó la ventana. El import sigue bajando filas y el dueño legítimo que vuelva \
            atrás y firme se encuentra con que sus propios datos son «de otra persona»: el bug que \
            cerró `force-fetch-and-wait-ignores-cancellation`, reabierto por la puerta de al lado.
            """)
        #expect(ICloudRestoreSessionSignal.currentFlow == nil, """
            La titularidad no se soltó, así que la ventana sigue teniendo dueño y la entrada \
            siguiente heredará su reloj. El ticket queda sin arreglar.
            """)
    }

    /// El guard del token, en el verbo nuevo. Un intento abandonado que se entera tarde no puede
    /// desposeer al que entró después: si lo hiciera, el vivo perdería su propio `noteRestoreFinished`
    /// —pasaría a ser un no-op— y su ventana se quedaría abierta hasta caducar.
    @Test("solo el dueño vigente puede soltar la titularidad")
    @MainActor
    func onlyTheCurrentOwnerCanRelease() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let viejo = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)
        let vivo = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0.addingTimeInterval(10), hasObservedImportActivity: false)

        ICloudRestoreSessionSignal.noteRestoreAbandoned(viejo)
        #expect(ICloudRestoreSessionSignal.currentFlow == vivo, """
            Una pantalla vieja que se desmonta tarde le quitó la titularidad al intento vivo. Su \
            `noteRestoreFinished` pasa a ser un no-op y la ventana se queda abierta hasta caducar, \
            con el guard cross-cuenta entornado hasta diez minutos de más.
            """)

        ICloudRestoreSessionSignal.noteRestoreFinished(vivo)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil,
                "el dueño vigente tiene que poder cerrar su propia ventana")
    }

    /// Soltar DOS veces, que es el camino normal y no una rareza: el `onDisappear` de la pantalla corre
    /// también cuando el flujo terminó por sus propios méritos, o sea cuando `noteRestoreFinished` ya
    /// rotó el dueño a `nil` unas líneas antes. Ahí soltar tiene que ser un no-op **que no reviva
    /// nada**: si tocara el reloj, el apagado explícito de la línea anterior quedaría deshecho y la
    /// ventana viviría hasta caducar con el guard cross-cuenta abierto de más todo ese rato.
    @Test("soltar sin dueño es un no-op que no reabre la ventana")
    @MainActor
    func releasingWithoutAnOwnerIsANoOp() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let flujo = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)
        ICloudRestoreSessionSignal.noteRestoreFinished(flujo)

        // El desmontaje llega DESPUÉS del apagado, con el mismo token.
        ICloudRestoreSessionSignal.noteRestoreAbandoned(flujo)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil, """
            El desmontaje del camino normal reabrió una ventana que su propio flujo acababa de cerrar.
            """)
        #expect(ICloudRestoreSessionSignal.currentFlow == nil, "y el dueño sigue sin existir")

        // Y sobre una señal que nunca se encendió (la pantalla montada en `.wiped` / `.iCloudDisabled`
        // no tiene token, pero un camino futuro sí podría llegar aquí con uno viejo).
        ICloudRestoreSessionSignal.noteRestoreAbandoned(flujo)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil)
    }

    /// **El invariante nuevo, recorrido entero.** `currentFlow != nil ⇒ restoreStartedAt != nil` en
    /// cada transición, y el converso NO: la ventana huérfana —reloj puesto, dueño `nil`— es el estado
    /// legítimo que hace posible todo lo de arriba.
    @Test("el invariante: hay dueño ⇒ hay reloj, pero un reloj puede quedarse huérfano")
    @MainActor
    func theInvariantHoldsAcrossEveryTransition() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        /// Comprueba el invariante Y el estado concreto que ese paso tiene que dejar. **Las dos mitades
        /// hacen falta**: el invariante solo dice algo cuando hay dueño, así que un helper que solo lo
        /// mirara sería un `if` que no entra en tres de los cinco pasos —lo cazó una lente de la
        /// review— y el test pasaría sin comprobar nada justo en los pasos que el ticket añade.
        func assertPaso(_ paso: String, reloj: Date?, hayDueño: Bool,
                        sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(ICloudRestoreSessionSignal.restoreStartedAt == reloj,
                    Comment(rawValue: "\(paso): el reloj no es el esperado"),
                    sourceLocation: sourceLocation)
            #expect((ICloudRestoreSessionSignal.currentFlow != nil) == hayDueño,
                    Comment(rawValue: "\(paso): la titularidad no es la esperada"),
                    sourceLocation: sourceLocation)
            if ICloudRestoreSessionSignal.currentFlow != nil {
                #expect(ICloudRestoreSessionSignal.restoreStartedAt != nil, Comment(rawValue: """
                    \(paso): hay dueño y no hay reloj. Un token que gobierna una ventana inexistente \
                    puede «cerrar» lo que no está abierto y, peor, hace que la entrada siguiente crea \
                    que alguien vigila — y entonces no estrena reloj y no hay ninguno que heredar.
                    """), sourceLocation: sourceLocation)
            }
        }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let t400 = t0.addingTimeInterval(400)
        assertPaso("recién reseteada", reloj: nil, hayDueño: false)

        let primero = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)
        assertPaso("tras entrar", reloj: t0, hayDueño: true)

        ICloudRestoreSessionSignal.noteRestoreAbandoned(primero)
        assertPaso("tras abandonar", reloj: t0, hayDueño: false)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt != nil
                && ICloudRestoreSessionSignal.currentFlow == nil, """
            La ventana HUÉRFANA dejó de existir como estado. Sin ella hay que volver a elegir entre \
            cerrarle la ventana a un import vivo y hacer que la entrada siguiente herede un reloj que \
            no describe nada suyo — los dos lados del bug, otra vez.
            """)

        let segundo = ICloudRestoreSessionSignal.noteRestoreStarted(
            now: t400, hasObservedImportActivity: true)
        assertPaso("tras volver a entrar", reloj: t400, hayDueño: true)

        ICloudRestoreSessionSignal.noteRestoreFinished(segundo)
        assertPaso("tras terminar", reloj: nil, hayDueño: false)
    }

    /// **EL CASO DEL TICKET** `restore-back-and-reenter-closes-the-live-session-window`.
    ///
    /// Entrar a Restaurar, tocar atrás a los 5 s y volver a entrar a los 10. El primer intento queda
    /// clavado en el tope de `forceFetchAndWait` —que no observa cancelación— y despierta al minuto y
    /// medio, con el segundo todavía bajando datos. Hasta el 2026-09-21 ese despertar apagaba la
    /// ventana del vivo, y `ICloudRestoreInProgressLogic` la leía `false` en el acto: el guard de
    /// frontera de cuenta se cerraba sobre el dueño legítimo con su propio import a medias.
    @Test("un flujo ABANDONADO no apaga la ventana del que sigue vivo")
    @MainActor
    func anAbandonedFlowCannotCloseTheLiveWindow() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let abandonado = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)
        let vivo = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0.addingTimeInterval(10), hasObservedImportActivity: false)

        // t≈90: el abandonado despierta del tope y llega al apagado con su token viejo.
        ICloudRestoreSessionSignal.noteRestoreFinished(abandonado)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t0, """
            El flujo que la persona dejó atrás apagó la ventana del intento que sigue bajando datos. \
            A partir de aquí `CrossAccountEntryGuardLogic` ve filas locales sin claim que las reclame \
            y le bloquea a su dueño la entrada a su propia cuenta.
            """)

        // Y el vivo sí puede cerrarla cuando termine.
        ICloudRestoreSessionSignal.noteRestoreFinished(vivo)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil, """
            El dueño vigente ya no puede cerrar su propia ventana: se quedaría abierta hasta caducar, \
            con el guard cross-cuenta entornado hasta diez minutos de más.
            """)
    }

    /// **El REINTENTO de la misma pantalla**, que es el otro camino a dos intentos y el que la review
    /// encontró sin cubrir. Los cinco botones de «volver a buscar» de `WelcomeRestoreView` vuelven a
    /// pasar por el encendido, así que su segundo intento estrena token y tiene que poder cerrar su
    /// propia ventana — un token de un solo uso dejaría la pantalla sin forma de cerrarla.
    @Test("el segundo intento de la MISMA pantalla estrena token y cierra su ventana")
    @MainActor
    func aRetryGetsItsOwnTokenAndCanCloseItsWindow() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let primero = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)
        ICloudRestoreSessionSignal.noteRestoreFinished(primero)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil)

        // «Volver a buscar»: intento nuevo, token nuevo, ventana nueva.
        let segundo = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0.addingTimeInterval(120), hasObservedImportActivity: false)
        #expect(segundo != primero, """
            El reintento heredó el token del intento anterior. Con los dos compartiendo identidad, \
            una espera abandonada del primero vuelve a poder cerrar la ventana del segundo — el bug \
            del ticket, dentro de una sola pantalla.
            """)
        ICloudRestoreSessionSignal.noteRestoreFinished(segundo)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil, """
            La pantalla no puede cerrar la ventana de su propio reintento: se quedaría abierta hasta \
            caducar, con el guard cross-cuenta entornado hasta diez minutos de más.
            """)
    }

    /// La otra mitad de la simetría, y el orden CONTRARIO: el vivo termina primero y el abandonado
    /// despierta después, sobre una ventana que ya no es de nadie. Un contador de entradas —la otra
    /// opción que el ticket dejaba abierta— cierra aquí tarde; el token no reabre ni cierra de más.
    @Test("y cuando despierta sobre una ventana ya cerrada, no toca la del intento siguiente")
    @MainActor
    func awakingOverAClosedWindowIsANoOp() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let abandonado = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)
        let vivo = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0.addingTimeInterval(10), hasObservedImportActivity: false)
        ICloudRestoreSessionSignal.noteRestoreFinished(vivo)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil)

        // La persona entra por TERCERA vez y estrena ventana, anclada en su propio instante.
        let t200 = t0.addingTimeInterval(200)
        _ = ICloudRestoreSessionSignal.noteRestoreStarted(now: t200, hasObservedImportActivity: false)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t200, """
            Una ventana cerrada tiene que volver a abrirse en el instante de la entrada nueva: \
            heredar el reloj viejo la haría caducar antes de tiempo sobre un import que acaba de \
            empezar.
            """)

        ICloudRestoreSessionSignal.noteRestoreFinished(abandonado)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t200, """
            El flujo abandonado del primer intento cerró la ventana del TERCERO. El apagado sigue \
            siendo incondicional para todo el que llegue tarde.
            """)
    }

    // MARK: - El tope agotado con el import todavía bajando
    // (`restore-timeout-closes-the-session-window-with-the-import-still-running`, 2026-09-21)

    /// **El veredicto del guard de frontera de cuenta**, que es donde la persona sufre el bug: entra
    /// por la card de su cuenta con filas locales que su claim no reclama —el claim vive en
    /// `UserDefaults` y murió con la reinstalación, que es la mitad del escenario— y lo único que puede
    /// dejarla pasar es que la señal diga que está restaurando.
    ///
    /// **Va hasta `CrossAccountEntryGuardLogic` a propósito y no se queda en `restoreStartedAt`**: lo
    /// pidió una lente de la review, y tiene razón — el criterio del ticket habla del dueño bloqueado
    /// en su propia cuenta, no de un campo. El reloj se inyecta porque el getter de la señal mide desde
    /// `.now` y el escenario dura minutos.
    @MainActor
    private static func guardDecide(en momento: Date) -> CrossAccountEntryGuardLogic.Decision {
        CrossAccountEntryGuardLogic.decide(
            hasLocalData: true,
            sameAccountClaimExists: false,
            restoreInProgress: ICloudRestoreInProgressLogic.isRestoringNow(
                restoreStartedAt: ICloudRestoreSessionSignal.restoreStartedAt,
                hasCompletedFirstImport: false,
                isImportQuiescent: false,
                hasObservedImportActivity: true,
                now: momento))
    }

    /// **EL CASO DEL TICKET.** Histórico grande: la persona entra a Restaurar y a los 90 s la espera se
    /// rinde con el import de CloudKit todavía trayendo filas. Hasta el 2026-09-21 la pantalla llamaba
    /// al apagado «gane o pierda», así que `restoreStartedAt` se ponía a `nil` en ese mismo instante —
    /// y quien tocaba atrás y firmaba con su propia cuenta se encontraba con que sus datos eran «de
    /// otra persona», con las filas entrando por debajo.
    @Test("el tope agotado CON el import en marcha no cierra la ventana: las filas siguen entrando")
    @MainActor
    func timeoutWithALiveImportKeepsTheWindowOpen() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let intento = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)

        // t=90: la espera se rinde habiendo visto un import, así que la pantalla NO llama al apagado.
        // Es la puerta REAL de `RestoreProgressView`, con los dos términos crudos.
        if ICloudRestoreInProgressLogic.closesTheSessionWindow(
            settled: false, hasObservedImportActivity: true) {
            ICloudRestoreSessionSignal.noteRestoreFinished(intento)
        }

        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t0, """
            El tope agotado apagó la ventana con el import de CloudKit todavía bajando. A partir de \
            aquí `CrossAccountEntryGuardLogic` ve filas locales sin claim que las reclame y le bloquea \
            al dueño la entrada a su propia cuenta — mientras sus datos entran en ese mismo momento.
            """)
        #expect(Self.guardDecide(en: t0.addingTimeInterval(95)) == .proceed, """
            Y el efecto que de verdad importa, medido donde la persona lo sufre: a los 95 s el guard \
            tiene que dejar pasar al dueño legítimo. Es justo el instante en que la pantalla le dice \
            «seguimos trayendo tus datos» y él toca atrás para firmar con su cuenta — y el veredicto \
            que se llevaba era `.blockedForeignData` sobre sus propios datos.
            """)
    }

    /// **El caso que la review encontró sin cubrir, y era el bug del ticket sin arreglar.** Un restore
    /// grande con la red floja recibe errores de import RETRIABLES —`requestRateLimited`, `zoneBusy`,
    /// `networkUnavailable`— y CloudKit sigue trayendo filas detrás de cada uno. El primer intento de
    /// este ticket puso la puerta en `RestoreImportSettlement`, cuyo `.inconclusive` agrupa esa
    /// población con la del usuario que no tiene nada: le apagaba la ventana con la descarga viva.
    @Test("un error RETRIABLE con el import vivo tampoco cierra la ventana")
    @MainActor
    func aRetriableImportErrorDoesNotCloseTheWindowEither() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let intento = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)

        // El copy de esta población es el de siempre —y así tiene que seguir— porque un error vigente
        // no permite prometer que los datos vienen.
        let copy = RestoreImportSettlement.resolve(
            settled: false, hasObservedImportActivity: true,
            lastImportErrorAt: t0.addingTimeInterval(15), lastSuccessfulImportAt: nil)
        #expect(copy == .inconclusive, "el copy de esta población no cambia: sigue sin prometer datos")

        // Pero la VENTANA no sigue al copy: hubo import, así que puede seguir bajando.
        if ICloudRestoreInProgressLogic.closesTheSessionWindow(
            settled: false, hasObservedImportActivity: true) {
            ICloudRestoreSessionSignal.noteRestoreFinished(intento)
        }
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t0, """
            Un error retriable apagó la ventana. `iCloudSyncService.isRetriable` da `true` a \
            `requestRateLimited`, `zoneBusy`, `networkUnavailable` y hasta en su `default`, y el \
            testigo del import se enciende ANTES del `if let error`: o sea que a un restore grande con \
            la red floja —el caso normal— se le apaga la ventana con CloudKit todavía trayendo filas.
            """)
        #expect(Self.guardDecide(en: t0.addingTimeInterval(95)) == .proceed,
                "y el dueño legítimo sigue sin poder entrar en su propia cuenta")
    }

    /// **«Empezar desde cero» SÍ apaga, y es la otra mitad que la review encontró rota.** Desde que el
    /// tope agotado con el import vivo ya no apaga, la única salida que quedaba en ese camino era
    /// soltar la titularidad — que no toca el reloj —, así que la ventana se iba abierta hasta diez
    /// minutos con el guard de frontera de cuenta entornado. Y ahí la persona acaba de declarar lo
    /// contrario de la premisa que sostiene todo el diseño: lo que hay detrás del botón es la puerta
    /// que borra esas filas.
    @Test("descartar el import APAGA la ventana, no la suelta")
    @MainActor
    func discardingTheImportClosesTheWindow() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let intento = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)
        // t=90: el tope se agota con el import vivo y no se apaga nada.
        #expect(!ICloudRestoreInProgressLogic.closesTheSessionWindow(
            settled: false, hasObservedImportActivity: true))

        // t=95: «Empezar desde cero» → confirmar.
        ICloudRestoreSessionSignal.noteRestoreFinished(intento)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil, """
            Descartar dejó la ventana viva. Con el corpus de otra persona en el teléfono, eso son ocho \
            minutos de sobra para firmar encima de sus datos: el guard de frontera de cuenta contesta \
            `.proceed` mientras la señal siga encendida.
            """)
        #expect(Self.guardDecide(en: t0.addingTimeInterval(120)) == .blockedForeignData,
                "y el guard vuelve a hacer su trabajo en el acto, sin esperar a la caducidad")
    }

    /// **La otra mitad, y es la que impide arreglar la primera de más**: cuando el tope se agota sin
    /// haber visto un solo import —el usuario realmente nuevo, cuyo store vacío no dispara ningún
    /// `.importEvent`— el apagado explícito sigue corriendo. Lo que aporta sobre la caducidad es PRECISIÓN: sin él, la
    /// ventana de alguien que no tiene ningún import vive hasta la gracia de 60 s (o el tope duro de
    /// 600), con el guard de frontera de cuenta entornado todo ese rato.
    @Test("el tope agotado SIN nada que importar sigue cerrando la ventana en el acto")
    @MainActor
    func timeoutWithoutAnyImportStillClosesTheWindow() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let intento = ICloudRestoreSessionSignal.noteRestoreStarted(
            now: t0, hasObservedImportActivity: false)
        if ICloudRestoreInProgressLogic.closesTheSessionWindow(
            settled: false, hasObservedImportActivity: false) {
            ICloudRestoreSessionSignal.noteRestoreFinished(intento)
        }
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil, """
            La ventana se quedó abierta esperando a caducar. Sin un solo `.importEvent` no hay ninguna \
            descarga que la justifique —ni la hubo— y el guard de frontera de cuenta queda entornado \
            hasta 60 s de más, que es justo la precisión que este apagado aporta sobre la caducidad.
            """)
        #expect(ICloudRestoreSessionSignal.currentFlow == nil, "y el intento deja de ser dueño de nada")
        #expect(Self.guardDecide(en: t0.addingTimeInterval(1)) == .blockedForeignData,
                "y el guard vuelve a decidir como siempre en el acto")
    }

    /// **EL TERCER CRITERIO: el reintento desde «seguimos trayendo tus datos» no re-ancla el tope.**
    ///
    /// Es el riesgo que trae dejar la ventana viva: si además se soltara la titularidad, quedaría
    /// HUÉRFANA, y `noteRestoreStarted` re-ancla una huérfana en cuanto hay descarga detrás. Como
    /// `hasObservedImportActivity` es un latch monótono del proceso, ese término está encendido para
    /// siempre a partir del primer `.importEvent`: pulsar «volver a buscar» cada 90 s renovaría el tope
    /// duro de 600 s indefinidamente, y en un teléfono con el corpus de otra persona eso mantiene
    /// abierta de par en par la puerta que el guard existe para cerrar.
    ///
    /// Lo que lo impide es que el intento CONSERVE la titularidad mientras la persona siga dentro de
    /// Restaurar — o sea que el `noteRestoreAbandoned` viva en `WelcomeRestoreView` y no en la pantalla
    /// de progreso, que se desmonta en cada cambio de estado.
    @Test("el reintento desde `.importIncomplete` NO re-ancla el tope duro")
    @MainActor
    func retryingFromImportIncompleteDoesNotReArmTheHardCap() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        _ = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)

        // Seis vueltas de «el tope se agota con el import vivo → vuelvo a buscar», que son más de los
        // 600 s del tope duro. Ninguna apaga, ninguna suelta: la pantalla de progreso se desmonta al
        // cambiar de estado, pero la de Restaurar sigue en pantalla.
        var reloj = t0
        for _ in 0..<6 {
            reloj = reloj.addingTimeInterval(90)
            _ = ICloudRestoreSessionSignal.noteRestoreStarted(now: reloj, hasObservedImportActivity: true)
            #expect(ICloudRestoreSessionSignal.restoreStartedAt == t0, """
                El reintento re-ancló la ventana. El tope duro deja de ser un tope: basta pulsar \
                «volver a buscar» cada 90 s para mantener abierto el guard de frontera de cuenta todo \
                lo que se quiera, y en un teléfono con el corpus de otra persona eso es exactamente la \
                adopción que el guard impide.
                """)
        }

        #expect(Self.guardDecide(en: t0.addingTimeInterval(601)) == .blockedForeignData, """
            Y pasado el tope duro el guard vuelve a bloquear: es la red que no depende de que corra \
            ningún callback, y seis reintentos no la corren. (Salir de Restaurar y volver a entrar SÍ \
            estrena ventana —con descarga real detrás— y eso queda fuera de este criterio: es el \
            comportamiento que ratificó `abandoned-restore-no-longer-clears-the-session-window-clock`, \
            con su propio ticket abierto para acotarlo.)
            """)
    }

    /// **Y el ticket hermano sigue en pie**, que es lo que no se puede romper para conseguir lo de
    /// arriba: irse de Restaurar SÍ suelta la titularidad, así que quien vuelve a entrar con una
    /// descarga real detrás estrena ventana en vez de heredar un reloj que no describe nada suyo
    /// (`abandoned-restore-no-longer-clears-the-session-window-clock`).
    @Test("irse de Restaurar tras el tope sí suelta: la entrada siguiente estrena ventana")
    @MainActor
    func leavingRestoreAfterTheTimeoutStillReleasesOwnership() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        let intento = ICloudRestoreSessionSignal.noteRestoreStarted(now: t0, hasObservedImportActivity: false)

        // t=90: el tope se agota con el import vivo y no se apaga nada. t=95: la persona toca atrás y
        // se va de Restaurar — ahí sí se suelta.
        ICloudRestoreSessionSignal.noteRestoreAbandoned(intento)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t0,
                "soltar no puede apagar: el import sigue bajando")

        let t400 = t0.addingTimeInterval(400)
        _ = ICloudRestoreSessionSignal.noteRestoreStarted(now: t400, hasObservedImportActivity: true)
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t400, """
            La entrada nueva heredó el reloj del intento que la persona dejó atrás. Su tope duro caduca \
            200 s después de empezar a bajar datos en vez de a los 600, y el guard de frontera de \
            cuenta se cierra sobre el dueño legítimo con su propio import a medias.
            """)
    }

}

@Suite("La restauración en curso · el cableado (source-scan)")
struct ICloudRestoreSignalWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CloudSync
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Código SIN líneas de comentario: los docblocks de este subsistema nombran a propósito lo que
    /// prohíben, y contar la prosa haría que documentar el invariante lo «cumpliera».
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo entre llaves balanceadas desde un marcador, sin líneas de comentario. Acotar no es
    /// cosmético: un `contains` sobre el fichero entero lo cumple cualquier otra llave del archivo.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let restoreView = "Yala/App/Views/Onboarding/WelcomeRestoreView.swift"
    private static let signInView = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"
    private static let signal = "Yala/Services/CloudSync/ICloudRestoreSessionSignal.swift"
    private static let guardLogic = "Yala/App/Logic/CrossAccountEntryGuardLogic.swift"

    @Test("MUTACIÓN: el guard del sign-in LEE la señal, y la lee viva")
    func theGuardReadsTheSignal() throws {
        let view = try Self.code(Self.signInView)
        #expect(view.contains("restoreInProgress: ICloudRestoreSessionSignal.isRestoringNow"), """
            El único call-site de producción del guard dejó de consultar la señal. La lógica pura \
            seguiría siendo correcta y sus 8 tests verdes, y el dueño que restaura volvería a tener \
            bloqueada la entrada a su propia cuenta.
            """)
    }

    @Test("MUTACIÓN: `restoreInProgress` NO tiene valor por defecto")
    func theParameterHasNoDefault() throws {
        let logic = try Self.code(Self.guardLogic)
        #expect(logic.contains("restoreInProgress: Bool\n"), "el parámetro sigue existiendo")
        #expect(!logic.contains("restoreInProgress: Bool ="), """
            Un default sería `false` y cualquier puerta NUEVA al guard heredaría el bug en silencio — \
            la familia exacta del `attestProvider: { nil }` de `.claude/rules/gateway-attest.md`. Sin \
            default, quien añada un call-site tiene que DECIDIR, y lo comprueba el compilador.
            """)
    }

    /// **El conteo es lo que carga el peso de este suite.** La señal abre —acotadamente— un guard de
    /// frontera de cuenta: encenderla desde un segundo sitio (un `onAppear` de más, un camino de
    /// migración que «también importa datos») desarma el guard sin tocar ni una línea de la lógica pura
    /// y con toda la suite en verde.
    @Test("MUTACIÓN: la señal se enciende en UN solo sitio de producción, y es la pantalla de restaurar")
    func onlyOneProductionCallSiteTurnsItOn() throws {
        let root = Self.repoRoot.appendingPathComponent("Yala")
        var callSites: [String] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            // La propia definición no es un call-site.
            guard url.lastPathComponent != "ICloudRestoreSessionSignal.swift" else { continue }
            let body = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            if body.contains("noteRestoreStarted(") { callSites.append(url.lastPathComponent) }
        }
        #expect(callSites == ["WelcomeRestoreView.swift"], """
            Encendedores de la señal encontrados: \(callSites.sorted()). Tiene que haber EXACTAMENTE \
            uno y ser la pantalla de restaurar: cualquier otro sitio la enciende sin que el usuario \
            haya pedido una restauración, y con ella encendida el guard deja adoptar sobre el corpus \
            de otro humano.
            """)
    }

    /// **El testigo del import llega VIVO al encendido, y eso solo lo ve un escáner.**
    ///
    /// El parámetro tiene default para que los tests puedan recorrer las dos ramas —bajo el host de
    /// test nadie importa nada y el singleton vale `false` en toda corrida—, y ese default es
    /// justamente lo que ningún test de comportamiento puede comprobar: cableado a `false`, la ventana
    /// huérfana no se re-ancla NUNCA y vuelve el ticket entero; cableado a `true`, el ciclo
    /// entrar-salir renueva el tope duro a voluntad. Las dos mitades siguen verdes en la tabla,
    /// porque allí el valor se pasa a mano.
    @Test("MUTACIÓN: el encendido lee el testigo del import VIVO, no una constante")
    func theStartReadsTheLiveImportWitness() throws {
        let code = try Self.code(Self.signal)
        #expect(!code.contains("hasObservedImportActivity: Bool ="), """
            El testigo ganó un valor por defecto. Cualquier constante ahí rompe algo: `false` no \
            re-ancla nunca —y vuelve el bug de heredar el reloj de un intento abandonado— y `true` \
            re-ancla siempre, con lo que entrar y salir de Restaurar renueva la ventana del guard \
            cross-cuenta indefinidamente. Sin default, quien añada un call-site tiene que DECIDIR y lo \
            comprueba el compilador — misma familia que el `restoreInProgress: Bool` del guard.
            """)

        let view = try Self.code(Self.restoreView)
        #expect(view.contains(
            "hasObservedImportActivity: iCloudSyncService.shared.hasObservedImportActivity"), """
            La pantalla dejó de pasar el testigo VIVO del servicio. Cableado a una constante compila, \
            no deja warning y la tabla entera sigue verde: allí el valor se pasa a mano.
            """)

        // Y que el término siga siendo una CONJUNCIÓN con la titularidad. Los dos límites son
        // distintos y ninguno cubre al otro: sin el dueño, un flujo vivo re-ancla su propia ventana;
        // sin el testigo, la re-ancla cualquier navegación.
        #expect(code.contains("if restoreStartedAt == nil || (currentFlow == nil && hasObservedImportActivity) {"), """
            La condición del encendido cambió de forma. Cada término tapa un agujero distinto: \
            `restoreStartedAt == nil` es lo único que ENCIENDE la señal, `currentFlow == nil` impide \
            que un flujo vivo renueve su propio tope, y `hasObservedImportActivity` impide que lo \
            renueve una navegación sin ninguna descarga detrás.
            """)
    }

    /// **El verbo nuevo también se pinnea a un solo sitio, y por el mismo motivo que su hermano.**
    /// Soltar la titularidad no apaga nada —por eso es seguro— pero **libera el reloj para la entrada
    /// siguiente**: un segundo call-site (un `onDisappear` de más, un camino que «también sale de
    /// restaurar») deja al usuario re-anclar la ventana a voluntad, que es justo el tope duro que
    /// `noteRestoreStarted` protege al conservar el reloj con dueño vigente. Y no pondría roja ni una
    /// tabla: la lógica pura no se entera de quién movió el reloj.
    ///
    /// **Ese único sitio se MUDÓ el 2026-09-21** de la pantalla de progreso a la de restaurar
    /// (`restore-timeout-closes-the-session-window-with-the-import-still-running`), y la mudanza es la
    /// mitad del ticket: la de progreso se desmonta también cuando solo cambia el `state` —a
    /// `.importIncomplete`, a `.found`—, o sea con la persona TODAVÍA dentro de Restaurar. Soltar ahí
    /// deja la ventana huérfana y el reintento la re-ancla, porque `hasObservedImportActivity` es un
    /// latch monótono del proceso: el tope duro de 600 s pasaba a renovarse cada 90 s con solo pulsar
    /// «volver a buscar». El desmontaje de la pantalla de restaurar sí significa «me fui».
    @Test("MUTACIÓN: la titularidad se suelta en UN solo sitio, y es la pantalla de RESTAURAR")
    func onlyOneProductionCallSiteReleasesOwnership() throws {
        let root = Self.repoRoot.appendingPathComponent("Yala")
        var callSites: [String] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard url.lastPathComponent != "ICloudRestoreSessionSignal.swift" else { continue }
            let body = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            if body.contains("noteRestoreAbandoned(") { callSites.append(url.lastPathComponent) }
        }
        #expect(callSites == ["WelcomeRestoreView.swift"], """
            Sitios que sueltan la titularidad: \(callSites.sorted()). Tiene que haber EXACTAMENTE uno \
            y ser la pantalla de RESTAURAR, que es la única cuyo desmontaje significa «me fui de \
            Restaurar». Desde la pantalla de progreso —donde vivía hasta el 2026-09-21— también suelta \
            al cambiar de estado con la persona todavía dentro, y entonces el reintento re-ancla el \
            tope duro. Desde cualquier otro, el reloj de la ventana se vuelve re-anclable sin más.
            """)
    }

    /// **La otra mitad de la mudanza: soltar va donde el desmontaje SIGNIFICA irse.**
    ///
    /// El conteo de arriba dice que hay un solo sitio; esto dice que ese sitio es el `onDisappear` de
    /// la pantalla entera y que va con el token reservado. Un `noteRestoreAbandoned` colgado de otra
    /// cosa de ese mismo fichero —del `onBack` del toolbar, por ejemplo— pasaría el conteo y dejaría
    /// sin cubrir las demás salidas: continuar con el resumen, irse a la puerta de «empezar desde
    /// cero», o que el contenedor de arriba cambie de pantalla.
    @Test("MUTACIÓN: la pantalla de restaurar suelta la titularidad en su `onDisappear`, con SU token")
    func theRestoreScreenReleasesOnItsOwnDisappear() throws {
        let view = try Self.code(Self.restoreView)

        // **El `.onDisappear` es UNO y cuelga de la pantalla entera, no de una vista de dentro.** Lo
        // pidió una lente de la review y mata el mutante que reabre el ticket: mover este bloque al
        // `RestoreProgressView(flowToken:)` del `case .searching` deja los otros scans en verde —el
        // conteo por fichero no cambia— y devuelve exactamente el comportamiento de antes del fix,
        // porque esa vista se desmonta en cada cambio de `state`.
        #expect(view.components(separatedBy: ".onDisappear {").count - 1 == 1, """
            La pantalla de restaurar tiene más de un `.onDisappear` (o ninguno). El scan de abajo mira \
            el primero, así que un segundo lo deja ciego.
            """)
        let montaProgreso = try #require(view.range(of: "RestoreProgressView(flowToken: flowToken)"))
        let arranque = try #require(view.range(of: ".task { startSearch() }"))
        let salidaRango = try #require(view.range(of: ".onDisappear {"))
        #expect(montaProgreso.upperBound < arranque.lowerBound
                && arranque.upperBound < salidaRango.lowerBound, """
            El `.onDisappear` se movió DENTRO del `switch` de estados —al `RestoreProgressView`, o a \
            cualquier vista de un `case`—. Ahí vuelve a soltar la titularidad en cada cambio de \
            `state`, con la persona todavía en Restaurar y un «volver a buscar» delante: ventana \
            huérfana, y el reintento re-ancla el tope duro cada 90 s. Va al nivel del `NavigationStack`, \
            pegado al `.task { startSearch() }`.
            """)

        let salida = try Self.body(of: ".onDisappear {", in: view)
        #expect(salida.contains("ICloudRestoreSessionSignal.noteRestoreAbandoned(flowToken)"), """
            El desmontaje de la pantalla de restaurar dejó de soltar la titularidad. Quien entra, se \
            arrepiente y vuelve siete minutos después hereda un reloj que no describe nada suyo: su \
            tope duro caduca a media descarga y el guard de frontera de cuenta se cierra sobre el \
            dueño legítimo — `abandoned-restore-no-longer-clears-the-session-window-clock` entero.
            """)
        #expect(salida.contains("if let flowToken {"), """
            Se soltó sin comprobar que hay token. `.wiped` y `.iCloudDisabled` salen de `startSearch()` \
            antes de encender nada, así que ahí no hay titularidad ninguna que soltar.
            """)
        #expect(!salida.contains("noteRestoreFinished"), """
            El DESMONTAJE apaga la ventana en vez de soltarla. Salir de Restaurar no para el import —\
            CloudKit sigue trayendo filas— así que esto reabre entero \
            `force-fetch-and-wait-ignores-cancellation`.
            """)
    }

    /// **Descartar el import APAGA la ventana, y va en la CONFIRMACIÓN y no en el botón.**
    ///
    /// Lo cazó una lente de la review como regresión de este mismo ticket: desde que el tope agotado
    /// con el import vivo ya no apaga, esta salida se llevaba la ventana abierta hasta diez minutos —
    /// el `onDisappear` suelta, y soltar no toca el reloj—. Con el corpus de otra persona en el
    /// teléfono, eso son ocho minutos de sobra para firmar encima de sus datos.
    ///
    /// **En la confirmación** porque el botón solo abre el diálogo (`showStartFreshConfirm = true`) y
    /// el `cancel` tiene que poder volver sin haber apagado nada.
    @Test("MUTACIÓN: «Empezar desde cero» apaga la ventana al CONFIRMAR")
    func discardingTheImportClosesTheWindowFromTheConfirmation() throws {
        let view = try Self.code(Self.restoreView)
        let confirmar = try Self.body(of: "Button(L10n.Welcome.Restore.startFreshConfirmConfirm, role: .destructive) {",
                                      in: view)
        #expect(confirmar.contains("ICloudRestoreSessionSignal.noteRestoreFinished(flowToken)"), """
            Descartar el import dejó de apagar la ventana de sesión. La persona acaba de declarar que \
            NO quiere esas filas —detrás de este botón está la puerta que las borra—, así que la \
            premisa que sostiene todo el diseño de la señal, «las filas siguen entrando», deja de \
            valer. Sin esto, el desmontaje solo SUELTA y la ventana vive hasta el tope duro de 600 s \
            con el guard de frontera de cuenta entornado.
            """)
        #expect(confirmar.contains("onStartFresh()"), "y sigue llevando a la puerta de descarte")

        // El `cancel` no puede apagar nada: quien se arrepiente del diálogo sigue restaurando.
        let cancelar = try Self.body(of: "Button(L10n.Welcome.Restore.startFreshConfirmCancel, role: .cancel) {",
                                     in: view)
        #expect(!cancelar.contains("ICloudRestoreSessionSignal"), """
            Cancelar el diálogo toca la ventana de sesión. Quien se arrepiente sigue en Restaurar con \
            su import bajando, y apagarle la ventana ahí le devuelve el bloqueo sobre su propia cuenta.
            """)
    }

    /// El ORDEN, que ningún test de comportamiento caza: `startSearch` tiene dos `return` tempranos —sin
    /// cuenta de iCloud y tras un wipe— y en los dos NO hay import. Encender antes de ellos abriría la
    /// ventana sin corpus que la justifique.
    @Test("MUTACIÓN: la señal se enciende DESPUÉS de los dos estados que no importan nada")
    func theSignalFiresAfterTheEarlyReturns() throws {
        let view = try Self.code(Self.restoreView)
        let disabled = try #require(view.range(of: "state = .iCloudDisabled"))
        let wiped = try #require(view.range(of: "state = .wiped"))
        let note = try #require(
            view.range(of: "ICloudRestoreSessionSignal.noteRestoreStarted("),
            "la pantalla de restaurar dejó de encender la señal: el fix queda inerte")

        #expect(disabled.upperBound < note.lowerBound && wiped.upperBound < note.lowerBound, """
            La señal se enciende antes de los `return` de «iCloud no disponible» y «este device fue \
            borrado». En los dos no hay ningún import de CloudKit, así que la ventana quedaría abierta \
            sin nada que la justifique — y esa ventana es un guard de frontera de cuenta.
            """)
    }

    private static let progressView = "Yala/App/Views/Onboarding/RestoreProgressView.swift"

    /// El apagado explícito al terminar el flujo. **Ningún test de comportamiento lo caza**: la
    /// caducidad de la lógica pura cierra la ventana igual, solo que tarda. Lo que se pierde al
    /// quitarlo es la PRECISIÓN —hasta diez minutos con un guard de frontera de cuenta abierto de
    /// más— y eso solo lo ve un escáner.
    ///
    /// **Y desde el 2026-09-21 el apagado va DENTRO de una puerta**
    /// (`restore-timeout-closes-the-session-window-with-the-import-still-running`): ya no es «gane o
    /// pierda», porque perder con el import en marcha no es un final. La puerta es lo único que separa
    /// los dos, y el mutante que la borra —dejando la llamada incondicional— reabre el ticket entero
    /// sin poner roja ni una tabla: `RestoreImportSettlement` seguiría clasificando perfectamente y
    /// nadie le haría caso.
    @Test("MUTACIÓN: la pantalla de progreso apaga la señal al terminar, y SOLO si no queda descarga")
    func theProgressViewClosesTheWindowWhenTheFlowEnds() throws {
        let code = try Self.code(Self.progressView)
        #expect(code.contains("ICloudRestoreSessionSignal.noteRestoreFinished(flowToken)"), """
            La pantalla de restaurar dejó de cerrar la ventana al terminar, o la cierra con otro \
            token. La señal seguiría viva hasta caducar, con el guard cross-cuenta abierto de más \
            todo ese rato.
            """)

        // **El apagado está EXACTAMENTE una vez, y eso es lo que caza el mutante que la review
        // encontró**: dejar la puerta puesta y añadir DEBAJO la llamada incondicional. Un `contains`
        // de la condición y otro del cuerpo lo dan por bueno; el conteo no.
        #expect(code.components(separatedBy: "noteRestoreFinished(").count - 1 == 1, """
            La pantalla de progreso apaga la ventana en más de un sitio (o en ninguno). Con una \
            segunda llamada fuera de la puerta, agotar el tope con el import de CloudKit en marcha \
            vuelve a poner `restoreStartedAt = nil` con las filas entrando — y la puerta de arriba \
            sigue estando, así que todo lo demás sale verde.
            """)

        // La PUERTA, fijada por su cuerpo entero y no por el literal de la condición: un `if` cuyo
        // cuerpo fuera otra cosa —o que envolviera además el `phase =` y el resumen— cumpliría un
        // `contains` de la condición sola y dejaría el apagado fuera, o el desenlace sin pintar.
        // El marcador incluye la LLAVE de apertura: sin ella `body(of:)` empieza a contar desde el
        // paréntesis de la condición, la primera `{` que encuentra es justo la del `if`, y el cierre
        // del `if` lo devuelve a profundidad 1 — así que el «cuerpo» se traga la closure entera y las
        // dos aserciones de debajo dejan de significar nada.
        #expect(code.contains("if ICloudRestoreInProgressLogic.closesTheSessionWindow("),
                "la puerta del apagado desapareció o cambió de criterio")
        let puerta = try Self.body(of: "hasObservedImportActivity: sawImport) {", in: code)
        #expect(puerta.contains("ICloudRestoreSessionSignal.noteRestoreFinished(flowToken)"), """
            La puerta del apagado cambió de forma. Dentro va EXACTAMENTE el apagado: si desaparece, \
            agotar el tope de 90 s con el import de CloudKit en marcha vuelve a poner \
            `restoreStartedAt = nil` con las filas entrando.
            """)
        #expect(!puerta.contains("phase =") && !puerta.contains("onSettled("), """
            La puerta se tragó el desenlace visual o la entrega del resumen: el import en marcha \
            dejaría de pintarse y `.importIncomplete` no llegaría nunca.
            """)

        // **Y los dos términos que entran, que es donde vive la corrección de la review.** Cableados
        // al `settlement` —o a una constante— el escáner de arriba sigue verde y vuelve el ticket para
        // la población del error retriable, que es la mayoría de un restore grande con red floja.
        #expect(code.contains("settled: settled, hasObservedImportActivity: sawImport"), """
            La puerta dejó de recibir los dos términos CRUDOS de la espera. Con el desenlace del copy \
            ahí, su `.inconclusive` agrupa «no vi ningún import» con «el último dio error» —y esos \
            errores suelen ser retriables, con CloudKit trayendo filas detrás—, así que apagaría la \
            ventana con la descarga viva.
            """)
        #expect(code.contains("let sawImport = iCloudSyncService.shared.hasObservedImportActivity"), """
            El testigo del import dejó de leerse VIVO, una sola vez, pegado al `settled` que describe. \
            Cableado a una constante compila, no deja warning y las tablas siguen verdes.
            """)

        // Y el ORDEN, **invertido el 2026-09-21** (`force-fetch-and-wait-ignores-cancellation`): el
        // apagado va DETRÁS del `guard !Task.isCancelled`, no delante.
        //
        // Antes iba delante porque la espera no observaba cancelación: llegar ahí solo podía significar
        // «el flujo terminó por sus propios méritos», y el guard cubría el desmontaje en ese instante
        // exacto. Desde que salir de la pantalla CORTA la espera, llegar ahí puede significar «la
        // persona tocó atrás» — y apagar ahí es justo lo que `ICloudRestoreSessionSignal` prohíbe («no
        // se apaga al volver atrás: CloudKit sigue bajando filas»), porque le devuelve al dueño
        // legítimo el bloqueo cross-cuenta sobre su propia cuenta.
        let apagado = try #require(code.range(of: "ICloudRestoreSessionSignal.noteRestoreFinished(flowToken)"))
        let espera = try #require(code.range(of: "await iCloudSyncService.shared.waitForImportQuiescence"))
        let cancelado = try #require(
            code.range(of: "guard !Task.isCancelled", range: espera.upperBound..<code.endIndex))
        #expect(espera.upperBound < cancelado.lowerBound && cancelado.upperBound < apagado.lowerBound, """
            El apagado volvió a ponerse ANTES del `guard !Task.isCancelled`. Con la espera observando \
            cancelación, eso hace que tocar «atrás» cierre la ventana de sesión mientras el import \
            sigue bajando — el bug que `ICloudRestoreInProgressLogic` existe para cerrar, y que su \
            camino (2) da explícitamente por imposible.
            """)
    }

    /// **La cancelación llega a los DOS `Task` de la pantalla, y al refresher por su propia vía.**
    ///
    /// El refresher es un `Task {}` no estructurado: no hereda la cancelación de `runTask`. Atarlo solo
    /// al `cancel()` que va después de la espera sería hacer que su tramo lo cumpla el vecino — y el
    /// vecino es justo lo que este ticket acaba de arreglar. Sin handle propio, salir de la pantalla
    /// dejaba un `iCloudAccountSummary` sobre 5+ entidades cada 0,6 s en el MainActor, escribiendo el
    /// `@State` de una vista muerta.
    @Test("MUTACIÓN: salir de la pantalla apaga la espera Y el refresher")
    func leavingTheScreenStopsBothTasks() throws {
        let code = try Self.code(Self.progressView)

        // El `onDisappear` es multilínea desde que además suelta la titularidad de la ventana, así
        // que se ancla por sus tres efectos dentro del cuerpo y no por un literal de una línea.
        let salida = try Self.body(of: ".onDisappear {", in: code)
        for efecto in ["runTask?.cancel()", "refreshTask?.cancel()"] {
            #expect(salida.contains(efecto), Comment(rawValue: """
                El desmontaje dejó de apagar `\(efecto)`. Con solo `runTask`, el refresher sigue
                contando filas con la pantalla cerrada; con solo `refreshTask`, vuelve el ticket entero.
                """))
        }
        #expect(!salida.contains("ICloudRestoreSessionSignal."), """
            El desmontaje de la pantalla de PROGRESO volvió a tocar la ventana de sesión. Aquí se \
            desmonta también por un cambio de estado —a `.importIncomplete`, a `.found`—, o sea con la \
            persona todavía dentro de Restaurar y un «volver a buscar» delante: soltar deja la ventana \
            huérfana y el reintento la re-ancla (el tope duro renovándose cada 90 s), y apagar reabre \
            `force-fetch-and-wait-ignores-cancellation`. Quien suelta es `WelcomeRestoreView`.
            """)
        #expect(code.contains("@State private var refreshTask: Task<Void, Never>?"), """
            El refresher perdió su handle propio y volvió a ser una variable local dentro de `runTask`. \
            Desde fuera ya no se puede apagar: su única salida vuelve a ser que la espera devuelva.
            """)
        #expect(code.contains("refreshTask = Task { @MainActor in"), """
            El refresher dejó de guardarse en su handle (un `Task {}` suelto basta para romperlo).
            """)

        // Y que el apagado del refresher siga ocurriendo en el camino normal, DETRÁS del guard de
        // cancelación. Delante mataría el refresher de la generación NUEVA: `refreshTask` es un
        // `@State`, o sea una caja compartida, y un `runTask` cancelado que despierta tras un
        // re-montaje leería de ella el handle del intento vivo. Lo cazó una lente de la review.
        let espera = try #require(code.range(of: "await iCloudSyncService.shared.waitForImportQuiescence"))
        let cancelacion = try #require(
            code.range(of: "guard !Task.isCancelled", range: espera.upperBound..<code.endIndex))
        let apagaRefresher = try #require(
            code.range(of: "refreshTask?.cancel()", range: espera.upperBound..<code.endIndex), """
            Tras resolverse la espera nadie apaga el refresher. Seguiría refrescando durante el mínimo \
            de exhibición y más allá, hasta que la vista se desmonte.
            """)
        #expect(cancelacion.upperBound < apagaRefresher.lowerBound, """
            El apagado del refresher volvió a ponerse DELANTE del guard de cancelación. En el camino \
            cancelado ese `cancel()` es redundante —`onDisappear` es el único sitio que cancela \
            `runTask`, así que ya apagó los dos— y lo único que puede hacer es matarle el refresher a \
            la generación siguiente de la vista.
            """)

        // Y los handles previos se cancelan antes de reasignarlos: un `Task` pisado sin cancelar
        // queda vivo y sin dueño.
        let arranque = try #require(code.range(of: "private func startFlow() {"))
        let limpiaRefresher = try #require(
            code.range(of: "refreshTask?.cancel()", range: arranque.upperBound..<code.endIndex), """
            `startFlow()` dejó de cancelar el refresher anterior antes de reasignarlo.
            """)
        let limpiaRun = try #require(
            code.range(of: "runTask?.cancel()", range: limpiaRefresher.upperBound..<code.endIndex), """
            `startFlow()` dejó de cancelar la espera anterior antes de reasignarla.
            """)
        let asigna = try #require(
            code.range(of: "refreshTask = Task { @MainActor in", range: arranque.upperBound..<code.endIndex))
        #expect(limpiaRun.upperBound < asigna.lowerBound,
                "la limpieza tiene que ir ANTES de la asignación, o no limpia nada")
    }

    /// **El token del flujo, de punta a punta.** Es el mecanismo entero de
    /// `restore-back-and-reenter-closes-the-live-session-window` y ningún test de comportamiento del
    /// latch lo caza: allí los tokens se piden a mano, así que una pantalla que pase `nil` para
    /// siempre —o que se guarde el token y no lo pase— deja las dos suites de arriba en verde.
    @Test("MUTACIÓN: el token que enciende la ventana es el que viaja a la pantalla y el que la cierra")
    func theFlowTokenTravelsFromTheSwitchToTheShutdown() throws {
        let view = try Self.code(Self.restoreView)
        let progress = try Self.code(Self.progressView)

        #expect(view.contains("flowToken = ICloudRestoreSessionSignal.noteRestoreStarted("), """
            El encendido dejó de GUARDAR su token (un `_ =` basta para hacerlo). Sin token, la \
            puerta de abajo no monta la espera y la búsqueda de iCloud no arranca nunca.
            """)
        #expect(view.contains("if let flowToken {"), """
            **La puerta cayó.** Sin ella la espera de 90 s arranca en el PRIMER render —`state` nace \
            en `.searching`— o sea antes de que `startSearch()` haya mirado iCloud ni el wipe. Quien \
            enciende iCloud y toca «volver a buscar» tendría entonces DOS esperas vivas. Desde el \
            2026-09-21 la fantasma se cancela al cambiar de estado, así que lo que la puerta evita es \
            MONTARLA — más barato que montarla y cancelarla — y que el token llegue por re-disparo.
            """)

        // Y que el token del `@State` sea el que VIAJA. Es la pasarela del cableado: la reserva y el
        // registro pueden estar bien y la pantalla recibir otra cosa, y entonces el apagado de arriba
        // se queda sin dueño que reconocer.
        #expect(view.contains("RestoreProgressView(flowToken: flowToken)"), """
            El token dejó de VIAJAR a la pantalla de progreso. El apagado deja de identificar a este \
            flujo y el intento abandonado vuelve a poder cerrar la ventana del vivo.
            """)
    }

    /// El sesgo fail-closed no es una opinión del docblock: es que el latch viva en memoria. Persistido,
    /// un kill del proceso a mitad del restore dejaría la puerta entornada en el arranque siguiente.
    @Test("MUTACIÓN: el latch NO se persiste")
    func theLatchIsNeverPersisted() throws {
        let code = try Self.code(Self.signal)
        #expect(!code.contains("UserDefaults"), """
            El latch pasó a persistirse. Su modo de fallo tiene que ser APAGARSE: en memoria, un kill \
            del proceso cierra la ventana; en disco, la deja abierta en el arranque siguiente, cuando \
            ya no hay ningún import que la justifique.
            """)
        #expect(!code.contains("SharedContainerService") && !code.contains("suiteName"),
                "ni por el App Group, que es la otra vía de persistencia del repo")
    }
}
