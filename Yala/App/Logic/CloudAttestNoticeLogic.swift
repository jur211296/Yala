//
//  CloudAttestNoticeLogic.swift
//  Yala
//
//  Cuándo la app enseña, fijo, que este teléfono no consigue App Attest y sus datos PERSONALES no suben a la nube
//  (ticket `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`, hermano del de Grupos).
//
//  POR QUÉ EXISTE. El veredicto terminal del canal personal solo emitía el canario
//  `cloudSyncBlockedByAttestUnavailable` y paraba el runtime, sin nada visible: quien apuntaba gastos desde este
//  teléfono no se enteraba nunca de que no llegaban a su cuenta, y solo lo descubría al intentar cerrar sesión
//  (`cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`). Es el mismo silencio que
//  `GroupsAttestTabNoticeLogic` cerró para Grupos, en el otro canal.
//
//  POR QUÉ SON CUATRO CONDICIONES Y NO SOLO EL VEREDICTO. La racha describe al TELÉFONO, no al canal: sobrevive al
//  cierre de sesión a propósito y la escriben LOS DOS motores —los tres clientes de Grupos y la puerta del personal
//  (`GroupsAttestStreakStore`)—. Hay tres poblaciones a las que el veredicto es cierto y la frase sería MENTIRA:
//
//   - **Con los datos personales en su iCloud privado** (`storageMode == .icloud`). Es la población MAYORITARIA hoy,
//     y la racha que tiene puede ser entera de Grupos: su teléfono no manda un solo movimiento personal a nuestro
//     servidor, así que anunciarle que «tus datos no suben» señala a un canal que no usa. Éste es el término que
//     hace de espejo del consent de Grupos.
//   - **Con el canal EN VUELO, no estable.** `storageMode` dice dónde viven los datos, no si el motor puede correr:
//     durante la reversa a iCloud, el cutover, un relanzamiento pendiente o un fallo, el par sigue en `.cloud` y
//     `CloudSyncRuntime.canRunDomain()` devuelve `false` por la FASE. El caso que lo hizo obligatorio lo cazó una
//     lente adversarial: quien está volviendo a iCloud **precisamente porque sus datos dejaron de subir** vería, en
//     Ajustes, la barra «Volviendo a iCloud» y a la vez, en el Panel, «usa otro teléfono» — el consejo contrario a
//     lo que está haciendo. Y no basta con `storageMode`: `.cloudActive` tampoco lo implica —`case .done` del
//     deriver no mira el modo—, así que los dos términos se ganan su sitio.
//   - **Sin sesión en la nube.** Nada está sincronizando y no hay cuenta a la que llegar; el sitio donde esto se
//     lee ya le ofrece crear una.
//
//  ESTE TÉRMINO ES EL QUE IGUALA LAS DOS SUPERFICIES. La sección de Ajustes ya lo tenía, pero IMPLÍCITO: solo se
//  pinta dentro de `case .cloudActive` del `switch` de `StorageSettingsView`. El Panel no tenía nada equivalente,
//  así que las dos caras del mismo aviso no tenían la misma puerta. Ahora la puerta es una y está escrita.
//
//  EL TÉRMINO DEL CANAL ES EL MODO PERSISTIDO DE ESTE TELÉFONO, y por el mismo motivo por el que el aviso de Grupos
//  lee `groupsBackendCompiledCapability` en vez del getter compuesto: describe un hecho sobre datos que YA existen,
//  no una puerta que abrir, así que no puede colgar de un término fail-closed ante un snapshot de remote-config
//  ausente. `CloudSyncFlags.storageMode` no lo es —sale de `StorageModePersistence.read()`, una key de este
//  dispositivo— y ADEMÁS es el testigo directo del corpus: si tus datos viven en la nube, viven en la nube aunque
//  el kill remoto esté bajado. Por eso aquí NO entra `CloudRemoteFlags.cloudModeEnabled`.
//
//  QUÉ NO ENTRA, Y SE MIDIÓ. `CloudSyncFlags.syncRuntimeEnabled` (la palanca compilada del motor) se descartó
//  porque no excluye a nadie: con el motor apagado los datos tampoco suben, así que el aviso seguiría siendo cierto
//  y el término solo añadiría un `&&` constante. `AccountKind` tampoco: dice qué lleva la CUENTA, y la pregunta del
//  aviso es sobre este TELÉFONO. Y `CloudSyncRuntime.canRunDomain()`, que es la respuesta canónica a «¿puede correr
//  el motor?», **no se puede llamar desde un body**: deja breadcrumbs y dispara el canario
//  `cloudStorageModePairViolation`. Por eso el término es el estado derivado que ya publica el controller.
//
//  QUÉ NO DECIDE. Cuándo se vuelve a mirar. El veredicto depende del reloj —una racha de ayer se vuelve terminal
//  sin que nadie escriba nada— y `isTerminal()` lee `UserDefaults`, que no repinta ninguna vista: por eso el store
//  avisa (`GroupsAttestStreakStore.didChangeNotification`) y cada superficie lo escucha. Las otras dos entradas sí
//  se leen VIVAS en el body.
//

import Foundation

nonisolated enum CloudAttestNoticeLogic {

    /// ¿Se enseña el aviso fijo «este teléfono no puede sincronizar tus datos»?
    ///
    /// Las cuatro condiciones a la vez, y ninguna sobra: el veredicto dice que el teléfono no atesta, y las otras
    /// tres dicen que esta persona TIENE datos personales subiendo por ese canal desde este teléfono. Sin parámetros
    /// por defecto a propósito —quien lo llame se pronuncia sobre los cuatro— por el mismo motivo que
    /// `CloudSignOutFlowLogic.path`.
    ///
    /// - Parameters:
    ///   - verdictIsTerminal: `GroupsAttestStreakStore.isTerminal()`.
    ///   - personalDataLivesInCloud: `CloudSyncFlags.storageMode == .cloud`. **No un flag remoto**: ver la cabecera.
    ///   - channelIsStable: `CloudMigrationController.shared?.uiState == .cloudActive` — el canal no está en mitad
    ///     de una migración, una reversa ni esperando un relanzamiento. Ver la cabecera.
    ///   - hasLiveSession: `CloudAuthService.shared.hasSession`.
    static func showsNotice(verdictIsTerminal: Bool,
                            personalDataLivesInCloud: Bool,
                            channelIsStable: Bool,
                            hasLiveSession: Bool) -> Bool {
        verdictIsTerminal && personalDataLivesInCloud && channelIsStable && hasLiveSession
    }
}
