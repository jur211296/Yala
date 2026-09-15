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
    /// más», tras los reintentos internos del cierre—, y `.attestUnavailable` también, porque lo que importa no es
    /// que el cierre fallara sino que este teléfono no puede sincronizar grupos. El resto comparte «No pudimos cerrar
    /// tu sesión», que es exacto para todos: el cierre no se completó.
    static func title(for reason: CloudSignOutFlowLogic.BlockReason) -> String {
        switch reason {
        case .transient:
            return L10n.Settings.signOutPendingTitle
        case .attestUnavailable:
            return L10n.Groups.Errors.attestUnavailableTitle
        case .permanent, .exportUnconfirmed, .sessionExpired, .bridgeUnreadable, .detachBusy,
             .channelPaused, .uploadRetryLater:
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
        case .permanent, .exportUnconfirmed, .bridgeUnreadable, .detachBusy, .none:
            return L10n.Settings.signOutBlockedMessage
        }
    }

    /// El mensaje del aviso que OFRECE salir perdiendo los cambios de grupos (`CloudSessionSignOut.offersGroupsLossExit`),
    /// en Ajustes y en la hoja del cambio de Apple ID. Cuenta lo que se pierde con su cifra, o sin ella si no hay número
    /// honesto (`CloudSignOutFlowLogic.shownGroupsLossCount`).
    static func attestLossMessage(pending: Int) -> String {
        guard let count = CloudSignOutFlowLogic.shownGroupsLossCount(pending) else {
            return L10n.Groups.Errors.attestUnavailableSignOutLossUnknown
        }
        return L10n.Groups.Errors.attestUnavailableSignOutLoss(count)
    }

    /// Lo mismo para la puerta de Grupos del Welcome, que no habla de «cerrar sesión» sino de «continuar», como ya adapta
    /// el aviso de la espera de iCloud (`L10n.Welcome.Groups.neutralStalledBody`).
    static func welcomeAttestLossMessage(pending: Int) -> String {
        guard let count = CloudSignOutFlowLogic.shownGroupsLossCount(pending) else {
            return L10n.Welcome.Groups.neutralAttestLossBodyUnknown
        }
        return L10n.Welcome.Groups.neutralAttestLossBody(count)
    }
}
