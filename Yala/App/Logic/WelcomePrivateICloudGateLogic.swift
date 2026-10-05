//
//  WelcomePrivateICloudGateLogic.swift
//  Yala
//
//  Paso 4 del rediseño de sesiones · **la puerta de «Primera vez → Tu cuenta en tu iCloud privado».**
//
//  ADR 2026-09-09 «Sesiones — dos ejes» §9, textual: *«"Primera vez → privado" valida iCloud ANTES de
//  todo, también en instalación fresca: si hay datos, alert con doble confirmación; borrar → se borra,
//  pide reinicio, y al reabrir el onboarding es de cero; cancelar → vuelve a la elección. **Nunca** se
//  muestra la pantalla de reinicio sin esa validación.»*
//
//  Lo que había hasta hoy, medido en device el 2026-09-09 y re-medido en árbol el 2026-09-10: la rama
//  privada sale del Welcome por `leaveWelcome(.privateOnboarding)`, que con el mount neutro **persiste el
//  destino y NO llama a `onSelectPrivateAccount`** — el único callback que consultaba «¿hay datos?» y
//  levantaba el alert. Así que la pantalla de reinicio salía ciega, y al reabrir
//  `presentNextOnboardingScreen` abría el onboarding completo mientras el espejo, recién adjuntado,
//  bajaba por debajo el histórico entero del Apple ID.
//
//  **Este enum es la mitad testeable del arreglo.** La otra mitad —hablar con CloudKit— vive en
//  `ICloudPersonalCorpusProbe` y solo se puede probar en device, porque CloudKit no existe en simulador.
//  El corte entre las dos mitades es deliberado y está donde el ticket lo pide: aquí se decide QUÉ
//  pantalla toca y qué destino tiene cada botón; allí se mide.
//

import Foundation

/// ¿Qué le enseña la puerta a quien acaba de elegir «privado»?
nonisolated enum WelcomePrivateICloudGateLogic {

    /// Los CINCO desenlaces. Ninguno es un camino muerto: los cuatro que no siguen adelante tienen salida
    /// visible, que es la mitad de lo que el ADR pide del Welcome entero.
    enum Decision: Equatable {
        /// iCloud está vacío (o no hace falta preguntar) **y el teléfono tampoco tiene datos**. Sigue al
        /// onboarding **por el portal de siempre**, con su relanzamiento si el mount es neutro. Es la fila
        /// «A · Primera vez → privado, iCloud vacío» de la matriz: onboarding directo, sin aviso.
        case proceed
        /// Hay corpus en el iCloud de este Apple ID. Aviso con CIFRAS y **tres salidas** (borrar con
        /// segunda confirmación, restaurar, cancelar) — decisión de Jürgen del 2026-09-09.
        case foundData(ICloudPersonalCorpus)
        /// **Hay datos EN ESTE TELÉFONO**, y en iCloud no (o no se pudo mirar). Aviso con doble
        /// confirmación y sin «traer mis datos»: no hay nada que traer.
        ///
        /// Existe porque el aviso de datos previos se PERDÍA justo aquí. Una sesión solo-grupos monta el
        /// store personal neutro en todos sus arranques (`shouldMountNeutralDurable`, tercer término), así
        /// que «Primera vez → privado» sale por el relanzamiento —`WelcomeMirrorRelaunchLogic
        /// .shouldRelaunch` da `true`— y ese camino **nunca llama a `onSelectPrivateAccount`**, que era el
        /// único que consultaba «¿hay datos?» y levantaba el alert. Resultado medido: onboarding de cero
        /// montado encima de los grupos y las categorías de la etapa anterior, sin decir una palabra, y el
        /// corpus viejo subiendo al iCloud del Apple ID en el arranque siguiente.
        ///
        /// **El corpus REMOTO gana cuando los dos tienen datos**, y no es arbitrario: aquel aviso ofrece
        /// «traer mis datos», que es la salida que no destruye nada, y su borrado se lleva por delante lo
        /// local de todas formas (`ContentView.performICloudCorpusWipe`). Avisar primero del local
        /// escondería la única salida reversible.
        ///
        /// `iCloudUnverified` viaja dentro porque decide lo que pasa DESPUÉS de borrar: si no se pudo
        /// preguntarle a iCloud —sin cuenta, o sin red—, quien siga adelante tiene que quedar bajo el
        /// mismo testigo que el estado K (`markPrivateChoseWithoutICloud`), o el aviso del espejo tardío
        /// se pierde y el histórico del Apple ID le cae encima el día que iCloud vuelva.
        case foundDeviceData(iCloudUnverified: Bool)
        /// Estado **K**: no hay iCloud en el dispositivo. No se puede validar ⇒ **se informa y se sigue en
        /// local**, jamás se bloquea. El ADR es explícito: no poder preguntar no es motivo para parar.
        case noICloud
        /// Se pudo intentar y falló (red, CloudKit). Se ofrece **reintentar**, como `WelcomeRestoreView`
        /// con su `.error`.
        ///
        /// **No cae en `proceed`, y la diferencia importa.** Seguir a ciegas con la red caída deja el
        /// espejo adjunto y el corpus viejo baja en cuanto vuelva la conexión: es el bug de este ticket
        /// por la puerta de atrás. Y tampoco cae en `noICloud`, porque allí el remedio no existe y aquí
        /// sí.
        case unreachable(String)
    }

    /// La tabla completa. Un solo sitio donde se escribe, y por eso no puede divergir de la vista.
    ///
    /// **`skipValidation` es el término de la hermeticidad, y va PRIMERO.** Bajo XCUITest no se toca red
    /// en ningún punto del Welcome (mismo criterio que `WelcomeFlowContainer.task` y que
    /// `WelcomeRestoreView.resolveEmptyState`), así que la puerta devuelve `proceed` y el recorrido
    /// determinista queda **byte-idéntico al de antes de este ticket** — incluido el de
    /// `WelcomeFreshStartAlertUITests`, que entra por aquí. Su posición delante de todo es lo que
    /// garantiza esa identidad: cualquier otro orden haría que el simulador (sin cuenta iCloud) cayera en
    /// `noICloud` y viera una pantalla nueva.
    ///
    /// **`deviceHasData` va SIN valor por defecto**, y eso es lo que impide que el hueco vuelva: la puerta
    /// la usan dos sitios con respuestas OPUESTAS —el Welcome pregunta por el corpus del teléfono, la
    /// activación de Yala completo jamás (esos datos son de la misma persona y se conservan)—, así que el
    /// compilador obliga a cada uno a pronunciarse en vez de heredar un default que solo le sirve a uno.
    ///
    /// **Y va DESPUÉS del corpus remoto, no antes.** Cuando los dos tienen datos gana el aviso de iCloud:
    /// es el único que ofrece «traer mis datos», la salida que no destruye nada, y su borrado ya se lleva
    /// las filas locales por delante.
    static func decide(skipValidation: Bool,
                       outcome: ICloudProbeOutcome,
                       deviceHasData: Bool) -> Decision {
        guard !skipValidation else { return .proceed }
        switch outcome {
        case .noAccount:
            // El estado K **deja de ser terminal cuando el teléfono sí tiene datos**: no poder preguntarle
            // a iCloud nunca bloquea, pero tampoco borra sin avisar lo que está aquí y se puede contar.
            return deviceHasData ? .foundDeviceData(iCloudUnverified: true) : .noICloud
        case .failed(let reason):
            return deviceHasData ? .foundDeviceData(iCloudUnverified: true) : .unreachable(reason)
        case .measured(let corpus):
            if corpus.hasAnyData { return .foundData(corpus) }
            return deviceHasData ? .foundDeviceData(iCloudUnverified: false) : .proceed
        }
    }

    /// ¿Esta decisión permite salir del Welcome hacia el onboarding sin que el usuario diga nada más?
    ///
    /// Existe como predicado y no como `== .proceed` escrito a mano en la vista porque **`noICloud` sí
    /// sale, pero solo después de que la persona lea el aviso y toque «continuar»**: son dos hechos
    /// distintos —«puede seguir» y «sigue solo»— y colapsarlos es como se pierde el aviso del estado K.
    static func advancesWithoutAsking(_ decision: Decision) -> Bool {
        decision == .proceed
    }

    // MARK: - El espejo que se adjunta TARDE

    /// La otra mitad del ticket, y la que Jürgen encontró abriendo el hueco: quien eligió privado sin
    /// iCloud sigue en local, **y el día que activa iCloud el espejo se adjunta y le baja el histórico
    /// viejo encima de lo que acaba de crear**. La validación no desapareció, solo se aplazó — así que se
    /// ejecuta cuando por fin se puede.
    enum LateMirrorDecision: Equatable {
        /// No hay nada que hacer en este arranque **y el testigo se queda puesto**. Cubre los cuatro
        /// motivos por los que todavía no se puede concluir: no hay testigo, no hay iCloud, la sonda no
        /// encontró cuenta (carrera con el token del sistema) o la sonda falló. Los dos últimos son
        /// «no pudimos preguntar», y retirar el testigo ahí sería justo perder el aviso por un fallo de
        /// red.
        case idle
        /// Hay corpus previo en iCloud. Se avisa, con las mismas cifras que la puerta.
        case ask(ICloudPersonalCorpus)
        /// Se pudo preguntar y no hay nada. **Se retira el testigo**: ya no queda nada que vigilar, y un
        /// testigo que sobrevive a su motivo vuelve a disparar en cada arranque.
        case standDown
    }

    /// **`outcome` es opcional a propósito.** Los dos primeros términos se resuelven sin tocar la red, y
    /// el llamador solo paga la sonda cuando de verdad hay algo que preguntar — este código corre en el
    /// arranque de todo usuario que alguna vez eligió privado sin iCloud.
    static func decideLateMirror(watching: Bool,
                                 iCloudAvailable: Bool,
                                 outcome: ICloudProbeOutcome?) -> LateMirrorDecision {
        guard watching, iCloudAvailable, let outcome else { return .idle }
        switch outcome {
        case .noAccount, .failed:
            return .idle
        case .measured(let corpus):
            return corpus.hasAnyData ? .ask(corpus) : .standDown
        }
    }

    // MARK: - El borrado del aviso tardío que falla, y el que quedó a medias

    // MARK: - El borrado de la puerta que se cancela

    /// **¿El borrado de iCloud de la puerta aplica su desenlace aunque su `.task` se haya cancelado?** (ticket
    /// `private-gate-remote-wipe-can-strand-its-arm`).
    ///
    /// Un `guard !Task.isCancelled` a secas tras el borrado se comía un borrado CONSUMADO: el scope del Welcome
    /// (`.handover`) llama a `wipeAllUserData`, que borra `hasCompletedOnboarding`, y ese cambio puede cancelar la
    /// `.task(id: phase)` con todo ya borrado. El arm se quedaba puesto y las preferencias residuales sin limpiar.
    /// Es el gemelo de `wipeDevice`, que ya no tiene ese guard.
    ///
    /// Quitarlo a secas tampoco vale: este borrado habla con CloudKit y puede cancelarse de verdad antes de tocar nada.
    /// **Lo que separa los dos casos es si llegó a escribir**, no si se canceló:
    ///
    ///  · **Sin cancelación**, manda el veredicto, como siempre.
    ///  · **Éxito** (`failed == false`): termina lo durable —preferencias residuales y desarme—. Todo camino que
    ///    devuelve `nil` cruzó la zona. Navegar (`onProceed`) ya no: cancelada, la puerta no está en pantalla.
    ///  · **Fallo con la zona ya ida** (`zoneGone`): pone la fase de fallo. Solo escribe `@State`, sin efectos
    ///    durables: el arm se queda, como en un fallo sin cancelar.
    ///  · **Fallo sin tocar nada**: vuelve y desarma. Cancelada, la puerta ya no está; el arm existe para sobrevivir a
    ///    un KILL, no a un abandono, y puesto lo reanudaría a ciegas `runLateICloudMirrorCheck`.
    ///
    /// `zoneGone` es la marca durable que escribe quien cruza la zona (`markICloudCorpusWipeZoneDone`), no algo
    /// deducido del motivo del fallo. Si viene de un intento anterior que ya se llevó la zona, también es verdad hoy.
    static func gateWipeSettles(failed: Bool, cancelled: Bool, zoneGone: Bool) -> Bool {
        guard cancelled else { return true }
        return !failed || zoneGone
    }

    /// Qué dejó un borrado del aviso tardío que FALLÓ (ticket
    /// `late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed`). **Son tres hechos y no uno**, y el
    /// arm significa cosas opuestas en cada uno: en los dos primeros no protege nada; en el tercero es lo único que
    /// terminaría el borrado, y terminarlo a ciegas es justo lo que la persona no pidió.
    enum LateWipeFailure: Equatable {
        /// Parado en los cambios de grupos. Nada se tocó, y su pantalla ya sabe salir (desarma al irse).
        case groupsPending
        /// Falló antes de la zona de iCloud. **Nada se tocó**: se desarma, el testigo se queda y el aviso vuelve a
        /// preguntar. El copy de `.failed` («Tus datos siguen en iCloud, intactos») es verdad solo aquí.
        case untouched
        /// La zona de iCloud ya no está y lo del teléfono sí. Ni se reanuda a ciegas ni se da por intacto: se le dice a
        /// la persona que quedó a medias y elige terminar o quedarse con lo que tiene.
        case leftHalfway
    }

    /// **`leftHalfway` entra también sin `zoneDone`**, y es a propósito: si el borrado ya había quedado a medias antes
    /// —la persona pulsó «Terminar de borrar» y este intento falló antes de llegar a la zona— la zona sigue sin estar, y
    /// decir «nada se tocó» sería mentira. Los grupos pendientes mandan porque su pantalla es la que explica qué falta.
    static func classifyLateWipeFailure(groupsPending: Bool,
                                        zoneDone: Bool,
                                        wasLeftHalfway: Bool) -> LateWipeFailure {
        if groupsPending { return .groupsPending }
        return (zoneDone || wasLeftHalfway) ? .leftHalfway : .untouched
    }

    /// Lo que el arranque hace con un borrado del aviso tardío pendiente, antes de sondear nada.
    enum LateWipeLaunch: Equatable {
        /// Hay un arm: un kill cortó el borrado sin que nadie viera un fallo. Se reanuda, como siempre.
        case resume
        /// El borrado quedó a medias delante de la persona: se le pregunta, no se reanuda.
        case askLeftHalfway
        /// **Hay una migración a la nube en vuelo** (ticket `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud`):
        /// ni se reanuda ni se pregunta. Borrar el corpus en mitad de la ida se llevaría lo que la migración está
        /// subiendo, y preguntar «terminar de borrar» con la nube a medio activar mezcla dos decisiones. El borrado sigue
        /// pendiente: lo decide el arranque en la nube si la migración termina, o este mismo arranque cuando vuelva al reposo.
        case holdForMigration
        /// Este dispositivo ya vive en la nube: ni el arm ni «a medias» describen su store, y los dos se retiran sin borrar
        /// ni preguntar. **Pero se cuenta**: la persona pidió ese borrado y tiene que saber que no se hizo.
        case retireInCloud
        /// Lo mismo, cuando la persona ya eligió «Activar la nube sin borrar» en Ajustes: se retira sin contarlo otra vez.
        case retireWaivedInCloud
        /// Un borrado ya retirado en la nube que la persona aún no ha visto contado (un kill antes de que la hoja montara).
        case tellCancelledInCloud
        /// Nada pendiente: sigue la comprobación normal del espejo tardío.
        case none
    }

    /// **El arm gana a «a medias»**: los dos a la vez solo pasan si la persona pulsó «Terminar de borrar» y un kill cortó
    /// ese intento — lo último que pidió fue terminar.
    ///
    /// **Y «a medias» solo se pregunta en `.icloud`** (ticket `private-gate-leave-after-a-halfway-wipe-forgets-the-zone`).
    /// La marca dice «el iCloud privado ya está vacío y lo del teléfono no», y su «Terminar de borrar» es `.handover`. En
    /// una cuenta de la nube lo del teléfono es de esa cuenta: terminar el borrado se llevaría sus datos. Desde que la
    /// puerta del Welcome también deja la marca, «Soy nuevo → nube» la lleva hasta aquí. El modo nube cuenta como
    /// sesión privada, así que el guard de arriba no la para.
    ///
    /// **Y en la nube tampoco se reanuda el arm** (ticket `private-gate-back-from-found-keeps-a-resumed-arm`). El arm es
    /// un borrado del iCloud PRIVADO con alcance `.handover`: reanudarlo en una cuenta de la nube se lleva lo del teléfono
    /// —que ya es de esa cuenta— y sus grupos, sin una sola pregunta. En la nube ningún camino arma ese borrado (el aviso
    /// tardío no sale sin espejo), así que un arm aquí siempre es una petición privada que sobrevivió al cambio de modo. La
    /// nube se mira PRIMERO por eso: el arm ya no gana en todos los modos.
    ///
    /// **Y en iCloud, una migración en vuelo congela el borrado pendiente; en la nube, se cuenta salvo renuncia** (ticket
    /// `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud`). La renuncia y el aviso no cambian nada en
    /// iCloud: allí caducan (`waiverLapses`, `cancelledNoticeLapses`).
    static func lateWipeLaunch(armed: Bool, leftHalfway: Bool, cancelledInCloudNoticePending: Bool,
                               waivedForCloud: Bool, migrationAtRest: Bool,
                               storageMode: StorageMode) -> LateWipeLaunch {
        switch storageMode {
        case .cloud:
            if armed || leftHalfway { return waivedForCloud ? .retireWaivedInCloud : .retireInCloud }
            return cancelledInCloudNoticePending ? .tellCancelledInCloud : .none
        case .icloud:
            if (armed || leftHalfway) && !migrationAtRest { return .holdForMigration }
            if armed { return .resume }
            if leftHalfway { return .askLeftHalfway }
            return .none
        }
    }

    /// **La renuncia de «Activar la nube sin borrar» caduca cuando el intento termina sin nube**: en iCloud y con la
    /// migración en reposo, esa activación ya no va a ocurrir, y la próxima vez se vuelve a preguntar. Con la migración en
    /// vuelo se conserva: es lo que la nube leerá si llega.
    static func waiverLapses(waivedForCloud: Bool, migrationAtRest: Bool, storageMode: StorageMode) -> Bool {
        waivedForCloud && storageMode == .icloud && migrationAtRest
    }

    /// **El aviso del borrado cancelado solo se enseña en la nube.** Si el dispositivo volvió a iCloud antes de verlo,
    /// «ya no se hará» deja de describir su store —ahí el aviso tardío puede volver a preguntar, o un borrado nuevo puede
    /// haber terminado—, y la marca se retira sin contarlo.
    static func cancelledNoticeLapses(noticePending: Bool, storageMode: StorageMode) -> Bool {
        noticePending && storageMode == .icloud
    }

    // MARK: - El borrado de la puerta que queda a medias

    /// **Qué hace cada montaje de la puerta con un borrado que quedó a medias**: la zona de iCloud ya no está y lo del
    /// teléfono sí (ticket `private-gate-leave-after-a-halfway-wipe-forgets-the-zone`). Hasta ese ticket, salir de la
    /// puerta retiraba el arm y con él la marca de la zona, y nada recordaba que iCloud había quedado vacío.
    ///
    /// Sin default, por lo mismo que `unverifiedExit`: los montajes contestan cosas distintas y el compilador tiene que
    /// obligarles a decirlo. **El remedio lo decide el alcance del borrado de cada uno**, no la pantalla:
    enum HalfwayWipe: Equatable {
        /// **El Welcome** (`.handover`). Salir deja la marca «a medias», y la pregunta el aviso tardío en el arranque:
        /// su «Terminar de borrar» es este mismo borrado.
        case leaveForLateNotice
        /// **«Activar Yala completo → Restaurar → Empezar desde cero»** (`.importedRows`). Salir deja la marca, pero su
        /// remedio no puede ser el aviso tardío: termina con `.handover`, que purgaría los grupos de quien activa para
        /// conservarlos. Lo termina esta misma puerta: al volver a entrar con iCloud vacío, borra lo que falta con su
        /// alcance en vez de seguir al onboarding encima de las filas importadas.
        case finishOnReentry
        /// **La puerta privada de la activación** (`.zoneOnly`). No borra filas, así que con la zona ida su borrado ya
        /// terminó: lo del teléfono es de quien activa y no queda nada a medias que recordar.
        case nothingLeftBehind

        /// **¿El borrado de este montaje llega a las filas del teléfono?** Es lo que decide las dos puntas de la marca:
        /// solo un borrado que las toca puede quedar a medias —y salir lo deja escrito—, y solo uno que las toca lo
        /// resuelve al terminar bien.
        var reachesDeviceRows: Bool {
            switch self {
            case .leaveForLateNotice, .finishOnReentry: return true
            case .nothingLeftBehind: return false
            }
        }
    }

    /// Qué hace `measure()` cuando la sonda dice que no hay nada que borrar (`Decision.proceed`).
    enum EmptyMeasure: Equatable {
        /// Seguir. Con `retiresHalfway`, la puerta acaba de medir que no queda mitad y la marca se va.
        case proceed(retiresHalfway: Bool)
        /// Terminar el borrado que quedó a medias, con el alcance de esta puerta.
        case finishHalfwayWipe
    }

    /// **La marca solo se retira donde la puerta midió las dos mitades.** `.proceed` dice «iCloud vacío» siempre, pero
    /// «el teléfono vacío» solo si el montaje le pasó su corpus (`measuredDevice`). Sin medirlo, retirar la marca sería
    /// dar por terminado un borrado del que no consta nada.
    ///
    /// `.finishOnReentry` no la retira: la termina. Con la marca puesta y la zona vacía, `.proceed` es justo el camino
    /// que deja las filas importadas en el teléfono, y la persona acaba de volver a pedir «Empezar desde cero».
    ///
    /// **Y termina también con `zoneDone` sin marca** (review adversarial, dos lentes). Un kill —o la hoja desmontada— justo
    /// tras borrar la zona deja el arm y la marca de la zona, pero no «a medias»: esa la escribe `disarm()` al salir, y
    /// nadie salió. En solo-grupos ningún arranque devuelve a la puerta, así que la próxima vez que se llega es esta.
    /// **Qué hace la salida «sin poder preguntarle a iCloud» con un borrado que quedó a medias** (ticket
    /// `late-notice-of-a-welcome-private-session-purges-groups-joined-later`, review adversarial). Es la hermana de
    /// `afterEmptyMeasure` para `.noICloud` y `.unreachable`: con el corpus del teléfono medido, la puerta solo llega ahí con
    /// el teléfono vacío —con datos habría salido por «Encontramos datos en este teléfono»—, o recién vaciado por
    /// «Empezar de cero» del teléfono. No queda mitad: la zona ya no está y el teléfono tampoco tiene nada.
    ///
    /// Dejar la marca era el bug: la persona hacía su onboarding privado, se unía a grupos, y el arranque le ofrecía
    /// «Terminar de borrar» con el `.handover` del Welcome, que purgaba esos grupos y sellaba el dominio. Solo en el
    /// Welcome (`.leaveForLateNotice`): los otros montajes no salen por aquí o no dejan nada a medias.
    static func unverifiedExitRetiresHalfway(_ halfway: HalfwayWipe, measuredDevice: Bool) -> Bool {
        halfway == .leaveForLateNotice && measuredDevice
    }

    static func afterEmptyMeasure(_ halfway: HalfwayWipe, leftHalfway: Bool, zoneDone: Bool,
                                  measuredDevice: Bool) -> EmptyMeasure {
        switch halfway {
        case .leaveForLateNotice: return .proceed(retiresHalfway: measuredDevice)
        case .finishOnReentry: return (leftHalfway || zoneDone) ? .finishHalfwayWipe : .proceed(retiresHalfway: false)
        case .nothingLeftBehind: return .proceed(retiresHalfway: false)
        }
    }

    /// **¿La pantalla de fallo dice que la zona ya no está?** La marca de ESTE borrado, o la de uno anterior que quedó a
    /// medias: un reintento que falla antes de llegar a la zona no la devuelve, e iCloud sigue vacío. Es el mismo
    /// criterio que `classifyLateWipeFailure` en el aviso tardío.
    ///
    /// Solo decide el COPY. Si el desenlace de una cancelación se aplica lo decide `zoneDone` a secas
    /// (`gateWipeSettles`): lo que importa ahí es si este intento llegó a escribir.
    static func failureFoundZoneGone(zoneDone: Bool, leftHalfway: Bool) -> Bool {
        zoneDone || leftHalfway
    }
}

/// Qué enseña la hoja del aviso tardío. **Un solo `.sheet(item:)` para los dos**, y no dos presentaciones: el borrado a
/// medias es el mismo flujo en otro momento, comparte fases (borrar, fallar) y su anchor ya es blocker de la matriz de
/// readiness con `lateICloudNotice != nil`.
nonisolated enum LateICloudNotice: Equatable, Sendable, Identifiable {
    /// El espejo trajo un corpus previo: el aviso de siempre, con sus cifras.
    case corpus(ICloudPersonalCorpus)
    /// Un borrado anterior quedó a medias: la zona de iCloud ya no está y lo del teléfono sí.
    case wipeLeftHalfway
    /// Un borrado de iCloud que la persona pidió se canceló al activar la nube. Solo informa: en la nube no hay nada que
    /// ofrecer terminar.
    case wipeCancelledInCloud

    var id: String {
        switch self {
        case .corpus(let corpus): return "corpus:\(corpus.id)"
        case .wipeLeftHalfway: return "wipeLeftHalfway"
        case .wipeCancelledInCloud: return "wipeCancelledInCloud"
        }
    }
}
