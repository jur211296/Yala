//
//  SignOutBlockedCopy.swift
//  Yala
//
//  Qué se le dice a la persona cuando un cierre de sesión se bloquea, por motivo.
//
//  **Una sola fuente para las dos pantallas que lo enseñan**: el aviso de Ajustes (`ProfileView`) y la hoja
//  del cambio de Apple ID (`AppleIDCloseNoticeView`). Vivía como `switch` privado de `ProfileView` hasta el
//  2026-09-15, cuando la hoja se convirtió en su segunda lectora: dos copias del mismo `switch` divergen en
//  cuanto un motivo nuevo aprende a decirse en una y no en la otra.
//
//  **Exhaustivo a propósito: sin `default`.** Solo así el compilador obliga a que un motivo nuevo se
//  pronuncie aquí.
//

import Foundation

enum SignOutBlockedCopy {

    /// El título del aviso. `.transient` tiene el suyo porque promete lo que es verdad de él —«un momento
    /// más», tras los reintentos internos del cierre—; el resto comparte «No pudimos cerrar tu sesión», que
    /// es exacto para todos: el cierre no se completó.
    static func title(for reason: CloudSignOutFlowLogic.BlockReason) -> String {
        switch reason {
        case .transient:
            return L10n.Settings.signOutPendingTitle
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
    ///    tras agotar sus reintentos. Ajustes lo enseña por su propio alert, con este mismo texto.
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
        case .permanent, .exportUnconfirmed, .bridgeUnreadable, .detachBusy, .none:
            return L10n.Settings.signOutBlockedMessage
        }
    }
}
