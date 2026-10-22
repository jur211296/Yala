//
//  GroupsOrganizerGateLogic.swift
//  Yala
//
//  G3 de Grupos-first · **la puerta que se comprueba ANTES de escribir nada.**
//
//  La rama organizador del Welcome («Crear mi primer grupo») no puede empezar pidiendo datos: si el
//  canal de Grupos está apagado no hay grupo que crear, y hasta C4 el intento tenía DOS finales, los dos
//  malos y el primero PERMANENTE — con cuenta iCloud del OS nacía un grupo LOCAL con
//  `isBackendGroup = false` en silencio (y no hay ninguna llamada cliente a `migrate_group` en el
//  árbol, así que moría huérfano aunque el flag se encendiera un minuto después: un grupo de una sola
//  persona, para siempre); sin ella, el seed de identidad lanzaba y el form pintaba un `CKError` crudo.
//  **C4 cerró esa fábrica** (`GroupCreateRoutingLogic.route` devuelve `.channelOff` y `.cloudKit` ya no
//  existe), así que esta puerta ya no es lo único que separa al organizador del grupo zombi. Sigue
//  siendo necesaria por lo otro que hace: bloquear ANTES de pedir nombre e identidad, y sin escribir.
//
//  Y el flag está **OFF garantizado** en el primer render de un fresh install de producción:
//  `absentDefault = false` en release (`CloudRemoteConfig.swift`) y los dos `refreshIfDue` que existen
//  —boot y el `.task` del Welcome— son fire-and-forget SIN `force`, con min-interval de 6 h. Por eso el
//  paso 1 de la rama es un `refreshIfDue(force: true)`: la intención del usuario **ES** evidencia de que
//  el canal debería estar encendido, que es la misma regla que ya usa
//  `GroupInviteChannelRoutingLogic` con un link backend.
//
//  **El orden de los términos es load-bearing y no estético:** el canal va primero porque es el que
//  el `force` acaba de re-medir, y porque su copy («ahora mismo no puedo abrirte grupos») describe un
//  estado transitorio, mientras que los otros dos describen estados del dispositivo. Invertirlos le
//  diría que el problema es la conexión.
//
//  **El término de los DATOS dejó de BLOQUEAR el 2026-09-11 (mitad 2 del paso 5 del rediseño).** Hasta ese día
//  `hasExistingData && !restoreInProgress` devolvía `.blockedForeignData`, una pantalla con un único
//  botón «Volver» y un copy que ofrecía «crea el grupo desde la app que ya usas» — que es ÉSTA. Jürgen
//  lo midió en su móvil el 2026-09-09 sobre su PROPIO corpus: la puerta bloqueaba al dueño de los datos
//  y no había salida. Lo que manda es la **fila B de la matriz del ADR**
//  (`docs/sessions/2026-09-09-matriz-escenarios-sesiones.md`: «Vengo por un grupo → **sin bloqueo**: vuelta
//  al neutro (borra local, iCloud intacto, relanza) y sigue»), y se cita ella y no el §2 a propósito: el §2
//  declara VÁLIDA la celda «privada + grupos asociados», cuyo camino de asociación no borra nada, así que
//  apoyar «hay corpus ⇒ borrar» en el §2 invitaría a extenderlo a una puerta donde sería destructivo.
//  ⇒ la respuesta aquí no es bloquear sino **volver al neutro**: esperar el export, borrar lo local por
//  ARCHIVOS, dejar iCloud intacto y relanzar. Con eso, `restoreInProgress` salió de la firma: corregía el
//  veredicto de un bloqueo que ya no existe, y ahora las dos ramas —restaurando o no— acaban en el mismo
//  sitio. **Y el latch NO se apaga**: dos lentes midieron que apagarlo antes de saber si el cierre va a
//  poder correr deja al guard cross-cuenta clasificando el corpus propio de la dueña como ajeno si el
//  cierre se aborta. Vive en memoria y muere con el relanzamiento, que es lo que este camino hace.
//
//  **Y el término se ENSANCHÓ al eje ancho del mount, que es lo que arregla el otro medio bug.** No basta
//  con mirar si hay filas: `PersonalStoreDecision.attachesCloudKitMirror` es `true` también para
//  `.localNoMirror` —`.automatic` adjunta el espejo aunque no haya cuenta de iCloud, medido en la
//  auditoría R1(c)— así que un store VACÍO con el espejo puesto dejaba pasar al recién llegado y sus
//  gastos de grupo acababan exportados al iCloud del dueño del teléfono. `false` para `.neutralNoMirror`,
//  que es el mount de toda instalación fresca: la población limpia no paga nada por este término.
//

import Foundation

/// ¿Puede esta rama seguir adelante, y si no, por qué?
nonisolated enum GroupsOrganizerGateLogic {

    enum Decision: Equatable {
        /// Canal encendido y el store de este arranque no tiene ni corpus ni espejo → seguir al sign-in.
        case proceed
        /// El canal de Grupos sigue apagado DESPUÉS del refresh forzado. Copy honesto, vuelta al step y
        /// **cero escrituras** — ni la marca del eje 1, ni `groupsBetaUnlocked`, ni `hasCompletedOnboarding`.
        case blockedChannelOff
        /// El store personal de ESTE arranque tiene corpus, o espeja a iCloud, o las dos cosas ⇒ antes de
        /// entrar a Grupos hay que devolver el dispositivo al neutro. **No es un bloqueo**: la rama sigue,
        /// con una pantalla en medio. Tampoco escribe nada por sí sola — quien borra es el cierre de sesión
        /// privado (`CloudSessionSignOut`), y quien lo dispara es la vista tras informar a la persona.
        case returnsToNeutral
    }

    /// - Parameters:
    ///   - channelEnabled: `CloudSyncFlags.groupsBackendEnabled` **leído después** del
    ///     `refreshIfDue(force: true)`. Leerlo antes es el no-op que el bug describe.
    ///   - hasExistingData: el detector del guard cross-cuenta (`ContentView.checkHasExistingData`),
    ///     que cuenta también grupos y filas bridgeadas — un dueño anterior que venía de «Solo Grupos»
    ///     no tiene cuentas ni categorías propias y daría `false` con el detector estrecho.
    ///   - mountAttachesMirror: `SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror`,
    ///     el EJE ANCHO. **Sin valor por defecto a propósito**, por la misma razón por la que
    ///     `restoreInProgress` no lo tenía: un default sería `false` y cualquier call-site nuevo heredaría
    ///     en silencio el medio bug que este término existe para cerrar (entrar a Grupos con el espejo
    ///     puesto y exportar los gastos del recién llegado al iCloud del dueño del teléfono).
    static func decide(channelEnabled: Bool,
                       hasExistingData: Bool,
                       mountAttachesMirror: Bool) -> Decision {
        guard channelEnabled else { return .blockedChannelOff }
        // Los dos términos van en OR y cada uno cierra una mitad distinta del mismo daño:
        //  · `hasExistingData` — hay corpus de alguien debajo, y el alta de Grupos escribiría encima.
        //  · `mountAttachesMirror` — aunque el store esté VACÍO: con el espejo adjunto, lo que el recién
        //    llegado escriba se exporta al iCloud del Apple ID de este teléfono. Es el medio bug que el
        //    detector de filas no puede ver, porque no hay filas todavía.
        // Ninguno de los dos es «datos de otro humano»: el detector cuenta filas y no sabe de quién son.
        // Por eso la respuesta dejó de ser un bloqueo — quien está delante puede perfectamente ser el
        // dueño, y en el modelo del ADR §2 un Welcome visible significa que no hay sesión privada viva.
        guard !(hasExistingData || mountAttachesMirror) else { return .returnsToNeutral }
        return .proceed
    }
}
