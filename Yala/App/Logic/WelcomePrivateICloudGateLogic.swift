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
}
