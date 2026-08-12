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
//  **El orden de los dos términos es load-bearing y no estético:** el canal va primero porque es el que
//  el `force` acaba de re-medir, y porque su copy («ahora mismo no puedo abrirte grupos») describe un
//  estado transitorio, mientras que el de datos ajenos describe uno del dispositivo. Invertirlos le
//  diría a la invitada de la ventana M1 que el problema es la conexión.
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
        /// Hay datos de otro humano en este dispositivo. Se bloquea con el copy que ya existe para ese
        /// hecho (`welcome.cloud.blocked*`), también sin escribir nada.
        case blockedForeignData
    }

    /// - Parameters:
    ///   - channelEnabled: `CloudSyncFlags.groupsBackendEnabled` **leído después** del
    ///     `refreshIfDue(force: true)`. Leerlo antes es el no-op que el bug describe.
    ///   - hasExistingData: el detector del guard cross-cuenta (`ContentView.checkHasExistingData`),
    ///     que cuenta también grupos y filas bridgeadas — un dueño anterior que venía de «Solo Grupos»
    ///     no tiene cuentas ni categorías propias y daría `false` con el detector estrecho.
    static func decide(channelEnabled: Bool, hasExistingData: Bool) -> Decision {
        guard channelEnabled else { return .blockedChannelOff }
        guard !hasExistingData else { return .blockedForeignData }
        return .proceed
    }
}
