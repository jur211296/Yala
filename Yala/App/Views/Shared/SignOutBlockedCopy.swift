//
//  SignOutBlockedCopy.swift
//  Yala
//
//  Qué se le dice a la persona cuando un cierre de sesión se bloquea, por motivo.
//
//  **Una sola fuente para las pantallas que lo enseñan**: el aviso de Ajustes (`ProfileView`) y la hoja del
//  cambio de Apple ID (`AppleIDCloseNoticeView`), con título y mensaje, y la puerta de Grupos del Welcome
//  (`WelcomeGroupsGateView`), que desde el 2026-09-15 lee el mensaje de `.transient`. Vivía como `switch` privado
//  de `ProfileView` hasta ese día, cuando la hoja se convirtió en su segunda lectora: dos copias del mismo
//  `switch` divergen en cuanto un motivo nuevo aprende a decirse en una y no en la otra.
//
//  **Exhaustivo a propósito: sin `default`.** Solo así el compilador obliga a que un motivo nuevo se
//  pronuncie aquí.
//

import Foundation

enum SignOutBlockedCopy {

    /// El título del aviso. `.transient` tiene el suyo porque promete lo que es verdad de él —«un momento
    /// más», tras los reintentos internos del cierre—, y los dos motivos del teléfono sin App Attest también, porque lo que
    /// importa no es que el cierre fallara sino que este teléfono no puede sincronizar: `.attestUnavailable` habla de tus
    /// grupos y `.personalAttestUnavailable` de tus datos. El resto comparte «No pudimos cerrar tu sesión», que es exacto
    /// para todos: el cierre no se completó.
    static func title(for reason: CloudSignOutFlowLogic.BlockReason) -> String {
        switch reason {
        case .transient:
            return L10n.Settings.signOutPendingTitle
        case .attestUnavailable:
            return L10n.Groups.Errors.attestUnavailableTitle
        case .personalAttestUnavailable:
            return L10n.Settings.signOutAttestTitle
        case .permanent, .exportUnconfirmed, .sessionExpired, .bridgeUnreadable, .detachBusy,
             .channelPaused, .uploadRetryLater, .syncStoppedNeedsUpdate, .syncStoppedMidMigration,
             .syncStoppedNeedsRelaunch, .personalUploadRetryLater, .cloudSessionExpired, .sessionNotClosed:
            return L10n.Settings.signOutBlockedTitle
        }
    }

    /// El mensaje, por motivo. Lo que cambia es qué pasó y qué puede hacer la persona:
    ///  · **sesión caducada** (paso 9): se arregla volviendo a entrar, no mirando la red.
    ///  · **canal de Grupos en pausa** (2026-09-13): no hay nada que arreglar —alguien bajó el kill-switch
    ///    por un incidente—, así que dice que vuelva en un rato y que no pierde nada. Con el genérico se le
    ///    decía que revisara una conexión que funciona.
    ///  · **la subida de grupos falló por algo pasajero** (2026-09-14): tampoco hay nada que revisar, y aquí
    ///    no se ha reintentado nada; dice que no llegó, que no se pierde y que lo intente en un rato.
    ///  · **lo pasajero del cierre que reintenta** (`.transient`): «espera unos segundos», que es lo cierto
    ///    cuando lo que falta es un guardado que se asienta. Sin red no lo es, y desde el 2026-09-15 aquí llega
    ///    también quien está sin conexión con el token caducado: `signout-pending-copy-says-wait-seconds-when-offline`.
    ///    Ajustes lo enseña por su propio alert, con este mismo texto, y la puerta de Grupos del Welcome también.
    ///  · **este teléfono lleva más de un día sin App Attest** (2026-09-15): esperar ya no lo arregla. Este es el texto
    ///    SIN salida; el aviso que ofrece salir perdiendo los cambios usa `attestLossMessage(pending:)`.
    ///  · **lo mismo con tus cambios en la nube** (2026-09-15): el texto SIN salida. El aviso que ofrece exportar y
    ///    perderlos usa `personalAttestLossMessage(pending:)`, y solo lo pinta Ajustes.
    ///  · **la sincronización con la nube parada a propósito** (2026-09-25): la conexión no tiene nada que ver, así que
    ///    no se habla de ella. Con el registro de la migración ilegible, cerrar y abrir Yala o actualizarla; con el paso
    ///    entre la nube e iCloud a medias, «Dónde viven tus datos» y «Reintentar»; con el paso terminado y el espejo aún
    ///    montado, reabrir la app.
    ///  · **la subida de tus cambios a la nube no llegó** (2026-09-25): el texto de la de grupos, dicho de tus datos. Hasta
    ///    ese día el cierre en la nube le decía «revisa tu conexión» a quien tenía el servidor fallando.
    ///  · **la sesión en la nube caducó** (2026-09-25): el texto de la sesión caducada, pero diciendo DÓNDE se vuelve a
    ///    entrar —«Dónde viven tus datos», aquí en Perfil, y su «Iniciar sesión»—. Con solo cambios de grupos no había
    ///    ninguna puerta a la vista (ticket `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`).
    ///  · el resto: el genérico de siempre, que no afirma ninguna causa concreta.
    ///
    /// `nil` cae al genérico: Ajustes escribe el motivo antes de encender su aviso, así que con el aviso
    /// presentado no ocurre.
    static func message(for reason: CloudSignOutFlowLogic.BlockReason?) -> String {
        switch reason {
        case .sessionExpired: return L10n.Groups.Errors.sessionExpired
        case .channelPaused: return L10n.Groups.Errors.channelPaused
        case .uploadRetryLater: return L10n.Groups.Errors.uploadRetryLater
        case .transient: return L10n.Settings.signOutPendingMessage
        case .attestUnavailable: return L10n.Groups.Errors.attestUnavailable
        case .personalAttestUnavailable: return L10n.Settings.signOutAttestBlocked
        case .syncStoppedNeedsUpdate: return L10n.Settings.signOutSyncStoppedNeedsUpdate
        case .syncStoppedMidMigration: return L10n.Settings.signOutSyncStoppedMidMigration
        case .syncStoppedNeedsRelaunch: return L10n.Settings.signOutSyncStoppedNeedsRelaunch
        case .personalUploadRetryLater: return L10n.Settings.signOutUploadRetryLater
        case .cloudSessionExpired: return L10n.Settings.signOutCloudSessionExpired
        case .permanent, .exportUnconfirmed, .bridgeUnreadable, .detachBusy, .sessionNotClosed, .none:
            return L10n.Settings.signOutBlockedMessage
        }
    }

    /// El mensaje del aviso que OFRECE salir perdiendo los cambios de grupos (`CloudSessionSignOut.offersGroupsLossExit`),
    /// en Ajustes y en la hoja del cambio de Apple ID. Cuenta lo que se pierde con su cifra, o sin ella si no hay número
    /// honesto (`CloudSignOutFlowLogic.shownLossCount`).
    static func attestLossMessage(pending: Int) -> String {
        guard let count = CloudSignOutFlowLogic.shownLossCount(pending) else {
            return L10n.Groups.Errors.attestUnavailableSignOutLossUnknown
        }
        return L10n.Groups.Errors.attestUnavailableSignOutLoss(count)
    }

    /// Lo mismo para la puerta de Grupos del Welcome, que no habla de «cerrar sesión» sino de «continuar», como ya adapta
    /// el aviso de la espera de iCloud (`L10n.Welcome.Groups.neutralStalledBody`).
    static func welcomeAttestLossMessage(pending: Int) -> String {
        guard let count = CloudSignOutFlowLogic.shownLossCount(pending) else {
            return L10n.Welcome.Groups.neutralAttestLossBodyUnknown
        }
        return L10n.Welcome.Groups.neutralAttestLossBody(count)
    }

    /// **«Empezar de cero» no borró porque quedan cambios de grupos sin subir** (ticket
    /// `fresh-start-wipe-kills-unsent-group-writes-silently`). Primero lo que importa —no se borró nada, y cuántos cambios
    /// se habría llevado—, y detrás el motivo de la subida con el MISMO texto que el cierre de sesión: el hecho es el mismo
    /// y lo que puede hacer la persona también. Lo pintan las tres pantallas del gesto: la puerta privada del Welcome, el
    /// aviso del espejo tardío y el alert del shell.
    ///
    /// **Con los motivos que esperar no arregla, el texto de detrás es otro** (ticket
    /// `fresh-start-has-no-way-out-when-group-writes-can-never-upload`): dice por qué no van a subir y ofrece perderlos, que
    /// es lo que el botón de al lado hace. Con `.sessionExpired` ya no pide «vuelve a iniciar sesión»: en un iPhone heredado
    /// la cuenta que los apuntó no es de quien empieza de cero.
    static func freshStartGroupsPendingMessage(_ block: CloudSessionSignOut.FreshStartGroupsBlock) -> String {
        let lead = CloudSignOutFlowLogic.shownLossCount(block.pendingCount)
            .map { L10n.Groups.FreshStartPending.lead($0) } ?? L10n.Groups.FreshStartPending.leadUnknown
        return lead + " " + freshStartReasonText(block)
    }

    /// Lo que va detrás de la cifra. Los tres motivos que ofrecen perderlos tienen el suyo; el resto, el del cierre de
    /// sesión. Exhaustivo y sin `default`, como todo este fichero; y un test recorre `BlockReason.allCases` comprobando que
    /// todo motivo que ofrece la salida (`CloudSignOutFlowLogic.freshStartOffersGroupsLossExit`) tiene aquí su texto.
    private static func freshStartReasonText(_ block: CloudSessionSignOut.FreshStartGroupsBlock) -> String {
        guard block.offersLossExit else { return message(for: block.reason) }
        switch block.reason {
        case .sessionExpired: return L10n.Groups.FreshStartPending.lossSessionExpired
        case .permanent: return L10n.Groups.FreshStartPending.lossPermanent
        case .attestUnavailable: return L10n.Groups.FreshStartPending.lossAttest
        case .transient, .exportUnconfirmed, .bridgeUnreadable, .detachBusy, .channelPaused, .uploadRetryLater,
             .personalAttestUnavailable, .syncStoppedNeedsUpdate, .syncStoppedMidMigration, .syncStoppedNeedsRelaunch,
             .personalUploadRetryLater, .cloudSessionExpired, .sessionNotClosed:
            return message(for: block.reason)
        }
    }

    /// **El «¿seguro?» de «Empezar de cero y perderlos»**: cuántos cambios se pierden y que no hay vuelta. La cifra es la
    /// del aviso —lo que la persona acepta—, o ninguna si no hay número honesto.
    static func freshStartGroupsLossConfirmMessage(_ block: CloudSessionSignOut.FreshStartGroupsBlock) -> String {
        guard let count = CloudSignOutFlowLogic.shownLossCount(block.pendingCount) else {
            return L10n.Groups.FreshStartPending.lossConfirmBodyUnknown
        }
        return L10n.Groups.FreshStartPending.lossConfirmBody(count)
    }

    /// El mensaje del aviso que OFRECE exportar los movimientos y cerrar sesión perdiendo los cambios personales
    /// (`CloudSessionSignOut.offersPersonalLossExit`). Solo lo pinta Ajustes, que es la única pantalla que cierra una sesión
    /// en la nube. Cuenta lo que se pierde con su cifra, o sin ella si no hay número honesto.
    static func personalAttestLossMessage(pending: Int) -> String {
        guard let count = CloudSignOutFlowLogic.shownLossCount(pending) else {
            return L10n.Settings.signOutAttestMessageUnknown
        }
        return L10n.Settings.signOutAttestMessage(count)
    }

    /// El texto del aviso de error de la exportación que ofrece ese aviso. El del servicio no sirve: está escrito en español
    /// y, sin movimientos, habla de «filtros seleccionados» que aquí no existen (review adversarial, 2026-09-15).
    static func personalExportFailureMessage(for error: any Error) -> String {
        if let exportError = error as? TransactionsExportError, case .noTransactionsToExport = exportError {
            return L10n.Settings.signOutAttestExportEmpty
        }
        return L10n.Settings.signOutAttestExportFailed
    }
}
