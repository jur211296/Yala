//
//  WidgetSessionSeal.swift
//  Yala
//
//  El SELLO de identidad del snapshot que la app publica para los widgets. Vive en `Yala/` y compila
//  TAMBIÉN en `YalaWidgetsExtension` (molde `WidgetAmountSplitter`, exception set del `.pbxproj`) por una
//  razón que no es de comodidad: `WidgetDataService` vive SOLO en el target del widget, así que
//  `@testable import Yala` no lo alcanza y un test de `YalaTests` no puede invocar al lector real. Sin un
//  símbolo COMPARTIDO, el criterio de este fichero solo se podría probar contra una réplica — y una réplica
//  no demuestra nada del código que corre en el teléfono.
//
//  ## El problema, y por qué el sello no es donde la intuición lo pone
//
//  En una sesión SECUNDARIA (M1) el store montado es el de la INVITADA, y `WidgetDataCache.updateCache`
//  no tiene forma de saberlo: escribe lo que el `ModelContext` le da. Decisión del owner (2026-08-13):
//  durante la visita el widget muestra los datos de quien tiene la sesión abierta, que es lo coherente con
//  lo que la pantalla enseña. Lo que no puede pasar es que esos datos SOBREVIVAN a la visita.
//
//  **La key activa espeja el DESCRIPTOR, no el snapshot.** Es la única forma de que el lector falle
//  CERRADO: si la publicara `updateCache` junto al snapshot, las dos mitades se moverían juntas y un
//  snapshot de la invitada que sobreviviera traería su propio sello válido al lado — el sello no protegería
//  de nada. Colgada del descriptor, el instante en que `SecondarySessionStore.clear` retira la sesión
//  retira también el sello ⇒ un snapshot suyo que quede en disco deja de servirse **corra o no corra el
//  `clearCache()`**, que es exactamente la garantía que no se puede pedirle a una limpieza best-effort.
//
//  ## Lo que se midió el 2026-08-14, porque cambia lo que este fichero tiene que hacer
//
//  El ticket que lo pide («el widget se queda con los números de la visita») describía un síntoma que ya
//  estaba cubierto, y conviene que el yo-futuro no repita el diagnóstico:
//   · la SALIDA ya limpia in-session — `CloudSessionSignOut.clearLocalSurfacesForArmedWipe` hace
//     `WidgetDataCache.clearCache()` justo tras armar el wipe, y su docblock nombra literalmente el caso
//     «o no vuelve a abrir la app nunca». Y es la ÚNICA salida: la precedencia de `CloudSignOutFlowLogic`
//     manda toda sesión secundaria a `.secondaryCloudSignOut`, y el borrado de cuenta está BLOQUEADO en
//     secundaria (`AccountDeletionService`, `canDelete`);
//   · la ENTRADA la cubre `SecondarySessionBoundaryPurge.purge()`, que abre con el mismo `clearCache()`
//     — pero es un hook PRE-MOUNT, o sea que solo corre en el arranque siguiente. Ése era el hueco vivo:
//     entre `confirmSecondaryEntry` y ese arranque, el widget de la pantalla de inicio seguía con los
//     saldos DEL DUEÑO y el teléfono lo tenía la invitada. Se cierra con el `clearCache()` in-session de la
//     entrada, simétrico con el que la salida ya tenía;
//   · y la ventana post-clear (app viva en `.awaitingRelaunch` con los 48 call-sites de `updateCache`
//     abiertos) **NO es alcanzable por BGTask**: `RelaunchNetLogic.shouldExitOnBackground` mata el proceso
//     al ir a background en esa fase. La puerta de `updateCache` es endurecimiento, no la cura de un bug
//     medido — y se escribe igual, por el gemelo del párrafo siguiente.
//
//  ## Por qué la puerta va en la PUERTA
//
//  Son **48** call-sites de producción en 18 ficheros (el ticket decía ~13, contando solo el bootstrap y
//  los ViewModels; faltaban `TransactionService`, `DraftService`, `GroupTransactionBridge`, cinco Views y
//  los dos del `BackgroundTaskManager`). Gatear 48 sitios es una lista que envejece. El gemelo ya resolvió
//  esta pregunta para las notificaciones: `NotificationService.isPersonalWipeArmed` evalúa
//  `isSignOutWipeArmed() || SecondarySessionStore.isWipeArmed()` **en el instante del `add`**, y su docblock
//  explica el porqué — cierra la ventana «para CUALQUIER productor, presente o futuro, sin rastrear tareas».
//  El widget usa el MISMO predicado, y por eso cubre también el cierre `.cloud` del dueño.
//
//  ## Lo que NO hace falta cablear
//
//  `YalaShare` quedó MEDIDO fuera de esta frontera (`ShareViewController` es un solo fichero: escribe una
//  imagen en `PendingImages/` y no toca ni el snapshot ni `UserDefaults` del App Group). El punto 4 del
//  ticket, que lo dejaba sin medir, está cerrado.
//

import CryptoKit
import Foundation

nonisolated enum WidgetSessionSeal {

    /// Key del sello ACTIVO en el `UserDefaults` del App Group. Su presencia significa «hay una sesión
    /// secundaria viva y es ésta»; su ausencia, «la sesión es la del dueño». Espeja el descriptor
    /// (`SecondarySessionStore.userIDKey`), que vive en `.standard` y por tanto es invisible para el widget
    /// — publicar el sello es la ÚNICA vía por la que la extensión puede saber de quién es lo que lee.
    static let activeSealKey = "widget_session_seal"

    // MARK: - El sello

    /// El sello de una sesión. **`nil` = sesión del DUEÑO**, que es el estado del 100 % del parque y el que
    /// tiene que seguir funcionando sin escribir nada.
    ///
    /// Es un SHA-256 truncado a 16 hex (molde `CloudBeacon.hash`) y no el `sub` en claro: el App Group
    /// persiste en el disco del DUEÑO y sobrevive a la visita hasta la purga, así que no hay motivo para
    /// dejarle ahí el identificador de cuenta de la invitada cuando el lector solo compara igualdad.
    ///
    /// El `!isEmpty` no es defensivo por costumbre: un string de cero bytes leído de un almacén se
    /// distingue mal de la ausencia (la misma trampa que `KeychainService.getString`, que devuelve `""` y
    /// no `nil`), y aquí un `""` colaría como sello legítimo distinto de `nil` ⇒ el dueño dejaría de ver
    /// sus propios datos.
    static func seal(forUserID userID: String?) -> String? {
        guard let userID, !userID.isEmpty else { return nil }
        let digest = SHA256.hash(data: Data(userID.utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
    }

    // MARK: - La decisión del lector

    /// `true` si el snapshot pertenece a la sesión viva. Lo consume `WidgetDataService.loadSnapshot()`.
    ///
    /// Es igualdad simple, y esa simpleza es el punto: `nil == nil` deja pasar al dueño (incluido **todo
    /// snapshot ya escrito en los teléfonos**, que decodifica el campo ausente como `nil` — que es de quien
    /// era), y cualquier otra combinación no casa. Un sello de invitada con la sesión ya cerrada (key
    /// retirada) da `false` y el widget se declara sin datos, que es la dirección segura: enseñar de menos
    /// se arregla abriendo la app; enseñar de más no se arregla.
    static func isFresh(snapshotSeal: String?, activeSeal: String?) -> Bool {
        snapshotSeal == activeSeal
    }

    // MARK: - La key activa (App Group)

    /// El sello activo publicado. `nil` = sesión del dueño (key ausente o vacía).
    static func activeSeal(in defaults: UserDefaults?) -> String? {
        guard let raw = defaults?.string(forKey: activeSealKey), !raw.isEmpty else { return nil }
        return raw
    }

    /// Publica el sello activo, o lo RETIRA con `nil`. Idempotente — los tres call-sites lo re-ejecutan
    /// completo tras un kill a mitad.
    static func publish(_ seal: String?, in defaults: UserDefaults?) {
        guard let defaults else { return }
        if let seal, !seal.isEmpty {
            defaults.set(seal, forKey: activeSealKey)
        } else {
            defaults.removeObject(forKey: activeSealKey)
        }
    }
}
