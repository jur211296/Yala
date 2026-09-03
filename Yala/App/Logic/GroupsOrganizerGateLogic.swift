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
//  **El segundo término es la enmienda del punto de control (spec M1-revival §6.1).** La rama reusa
//  `GroupsSignInView`, que NO consulta el guard cross-cuenta (regla dura de su docblock). Sobre un
//  device CON DATOS de otro humano —la ventana M1: Welcome visible tras un `.privateReset` con el corpus
//  del dueño vivo— la rama firmaría a la invitada solo-grupos SOBRE el store personal del dueño: su
//  bridge metería los gastos de ella en el Panel de él, y el trío del paso 7
//  (`onboardingMode = .groupInvite`) viajaría al iKV del Apple ID del dueño por never-downgrade,
//  contaminando sus otros devices. Aquí solo se BLOQUEA; ofrecer la sesión secundaria es de la ola M.
//
//  **El orden de los tres términos es load-bearing y no estético:** el canal va primero porque es el que
//  el `force` acaba de re-medir, y porque su copy («ahora mismo no puedo abrirte grupos») describe un
//  estado transitorio, mientras que los otros dos describen estados del dispositivo. Invertirlos le
//  diría a la invitada de la ventana M1 que el problema es la conexión.
//
//  **El TERCER término (C3, 2026-08-12) es la sesión secundaria, y va DELANTE de los datos ajenos.** No
//  es una variante del segundo: en secundaria el detector de corpus mide el store de la INVITADA
//  (`YalaModel-Secondary`), que en una sesión recién montada está VACÍO ⇒ `hasExistingData` da `false` y
//  la puerta abría. Y detrás de la puerta el alta escribe SEIS preferencias por
//  `PreferenceSyncService`, que en `.localOnly` sigue escribiendo el espejo local — o sea el
//  `UserDefaults.standard` del DUEÑO —, incluida `groupsBetaUnlocked`, que **el wipe de salida no
//  repone**: `removeGroupsDomainPreferenceKeys` tiene un único call-site, dentro del «empiezo de cero»
//  del Welcome, así que cerrar la sesión de la invitada le deja al dueño el dominio Grupos adoptado.
//  Se bloquea con copy PROPIO (`welcome.groups.secondary*`) y no reusando el de datos ajenos: el hecho
//  es distinto —«estás de visita», no «hay datos de otro humano»— y la salida también, porque aquí sí
//  la hay (cerrar la sesión de invitado y volver desde su propio dispositivo).
//
//  **El CUARTO término (D2, 2026-09-02) no es una razón más para bloquear: es la que impide bloquear
//  mal.** El detector de corpus cuenta filas y no puede saber QUIÉN las está escribiendo, así que a la
//  dueña que acaba de cambiar de móvil y está restaurando de SU iCloud la clasificaba como «datos de
//  otro humano» — y el copy le ofrecía crear el grupo «desde la app que ya usas», que es ÉSTA,
//  montándose delante de ella. Una salida imposible de seguir, que es la definición de camino muerto.
//  La señal (`ICloudRestoreSessionSignal.isRestoringNow`) corrige el TÉRMINO de los datos, no el
//  veredicto: por eso va DENTRO de la condición de `hasExistingData` y no como una cuarta rama, y por
//  eso el canal y la sesión secundaria siguen bloqueando igual mientras se restaura. Es la misma
//  enmienda, con la misma señal y sobre el mismo detector, que `CrossAccountEntryGuardLogic` ya
//  aplicaba desde el 2026-08-13: eran dos consumidores del mismo hecho y sólo uno lo clasificaba bien.
//  Decisión del owner; el contra que se aceptó es que cada puerta que hereda la señal es una
//  superficie más donde un fallo de la señal sale caro.
//

import Foundation

/// ¿Puede esta rama seguir adelante, y si no, por qué?
nonisolated enum GroupsOrganizerGateLogic {

    enum Decision: Equatable {
        /// Canal encendido y device sin corpus ajeno → seguir al sign-in.
        case proceed
        /// El canal de Grupos sigue apagado DESPUÉS del refresh forzado. Copy honesto, vuelta al step y
        /// **cero escrituras** — ni `onboardingMode`, ni `groupsBetaUnlocked`, ni `hasCompletedOnboarding`.
        case blockedChannelOff
        /// C3 · sesión secundaria M1 viva: estás de visita en el móvil de otra persona. Copy propio y
        /// **cero escrituras** — las seis del alta caerían en el `UserDefaults` del DUEÑO.
        case blockedSecondarySession
        /// Hay datos de otro humano en este dispositivo. Se bloquea con el copy que ya existe para ese
        /// hecho (`welcome.cloud.blocked*`), también sin escribir nada.
        case blockedForeignData
    }

    /// - Parameters:
    ///   - channelEnabled: `CloudSyncFlags.groupsBackendEnabled` **leído después** del
    ///     `refreshIfDue(force: true)`. Leerlo antes es el no-op que el bug describe.
    ///   - isSecondarySession: `SecondarySessionStore.isActive()`. C3 · va ANTES de `hasExistingData`
    ///     porque el detector mide el store de la INVITADA, que puede estar vacío: sin este término la
    ///     puerta abre justo en el caso que más caro sale.
    ///   - hasExistingData: el detector del guard cross-cuenta (`ContentView.checkHasExistingData`),
    ///     que cuenta también grupos y filas bridgeadas — un dueño anterior que venía de «Solo Grupos»
    ///     no tiene cuentas ni categorías propias y daría `false` con el detector estrecho.
    ///   - restoreInProgress: ESTA sesión pidió restaurar de iCloud y ese import no ha terminado
    ///     (`ICloudRestoreSessionSignal.isRestoringNow`). **SIN valor por defecto a propósito**, igual
    ///     que en `CrossAccountEntryGuardLogic.decide`: un default sería `false` y cualquier call-site
    ///     nuevo heredaría el bug en silencio. Sin él, añadir una puerta obliga a decidir, y lo
    ///     comprueba el compilador y no un escáner.
    static func decide(channelEnabled: Bool,
                       isSecondarySession: Bool,
                       hasExistingData: Bool,
                       restoreInProgress: Bool) -> Decision {
        guard channelEnabled else { return .blockedChannelOff }
        guard !isSecondarySession else { return .blockedSecondarySession }
        // Las filas que la propia dueña está bajando de SU iCloud ahora mismo no son «datos de otro
        // humano»: son el resultado, a medias, de lo que ella acaba de pedir. El detector cuenta filas y
        // no puede saber quién las está escribiendo, así que sin este término la puerta la acusa a ella
        // — y la salida que le ofrece el copy («crea el grupo desde la app que ya usas») es literalmente
        // esta app, montándose delante de ella. Imposible de seguir.
        //
        // Corrige el TÉRMINO de los datos, no el veredicto: es la misma forma que ya tiene el guard
        // gemelo (`CrossAccountEntryGuardLogic`, que consume el mismo detector), y por eso va DENTRO de
        // esta condición y no como una cuarta rama. Todo lo demás de la puerta sigue mandando: con el
        // canal apagado o en sesión secundaria se bloquea igual, esté restaurando o no.
        guard !(hasExistingData && !restoreInProgress) else { return .blockedForeignData }
        return .proceed
    }
}
