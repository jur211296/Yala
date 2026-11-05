//
//  CompleteAccountAdoptPending.swift
//  Yala
//
//  Ticket `complete-account-invite-adopt-can-pull-groups-before-the-guard`. Quien entra por un enlace de invitación con una
//  cuenta COMPLETA no arranca el canal de Grupos al firmar (`GroupsSignInChannelStartLogic`): su alta pasa por el guard
//  cross-cuenta del Welcome, que cuenta `SplitGroup`, y los grupos que el canal bajara contarían como «datos de otra
//  cuenta». Pero el arranque en frío y la vuelta a primer plano también llaman a `GroupsSyncClient.startIfEligible`, que
//  solo miraba el flag y la sesión: un relanzamiento o un paso por otra app entre la firma y el adopt bajaba los grupos, y
//  el Welcome volvía a decir «Este dispositivo tiene datos de otra cuenta» por los propios grupos de la persona.
//
//  Este candado DURABLE lo cierra: la firma lo arma con el `sub` que entra, `startIfEligible` no arranca el canal mientras
//  siga en pie para esa sesión, y el adopt lo retira al empezar (`onAdoptStarted`). Caduca solo a la hora: quien abandona el
//  recorrido a medias no se queda sin Grupos para siempre, y al volver por el Welcome lo vuelve a armar.
//

import Foundation

@MainActor
enum CompleteAccountAdoptPending {
    /// Cuánto aguanta el candado sin que el adopt empiece. Cubre la firma, la hoja y un relanzamiento; no un abandono.
    static let ttl: TimeInterval = 60 * 60

    static let subKey = "groupsSync.completeAccountAdoptPendingSub"
    static let sinceKey = "groupsSync.completeAccountAdoptPendingSince"

    /// Almacén. Los tests lo sustituyen por uno aislado.
    static var defaults: UserDefaults = .standard

    /// La firma con destino `.adoptAsCompleteAndOpenGroups` lo arma con la cuenta que entra.
    static func arm(sub: String?, now: Date = .now) {
        guard let sub, !sub.isEmpty else { return }
        defaults.set(sub, forKey: subKey)
        defaults.set(now.timeIntervalSince1970, forKey: sinceKey)
    }

    /// El adopt empezó (o el recorrido terminó): el canal ya puede bajar los grupos de esa cuenta.
    static func clear() {
        defaults.removeObject(forKey: subKey)
        defaults.removeObject(forKey: sinceKey)
    }

    /// ¿Frena el canal de Grupos para la sesión `sub`?
    static func blocksChannel(sub: String?, now: Date = .now) -> Bool {
        let since = defaults.object(forKey: sinceKey) as? Double
        return decide(armedSub: defaults.string(forKey: subKey), armedSince: since.map(Date.init(timeIntervalSince1970:)),
                      sessionSub: sub, now: now)
    }

    /// Pura. Frena solo con la MISMA cuenta y dentro del plazo. Un reloj que retrocede (`now < since`) no frena: el candado
    /// es una cortesía para el guard, y uno que no caduca nunca dejaría a la persona sin Grupos.
    nonisolated static func decide(armedSub: String?, armedSince: Date?, sessionSub: String?, now: Date) -> Bool {
        guard let armedSub, let armedSince, let sessionSub, armedSub == sessionSub else { return false }
        let elapsed = now.timeIntervalSince(armedSince)
        return elapsed >= 0 && elapsed < ttl
    }
}
