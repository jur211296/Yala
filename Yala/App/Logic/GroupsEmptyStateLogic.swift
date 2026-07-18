//
//  GroupsEmptyStateLogic.swift
//  Yala
//
//  Pure-logic del empty state del tab Grupos (hallazgo device-QA H-2026-07-18-7). Decide si mostrar el
//  empty state ESTÁNDAR ("aún no tienes grupos", CTA crear) o el de RE-ENTRADA ("tus grupos están en tu
//  cuenta", CTA iniciar sesión) cuando el usuario cerró sesión solo-grupos y ya no ve sus grupos. Sin
//  SwiftData/CloudKit/UI — tabla completa en GroupsEmptyStateLogicTests.
//
//  Flag OFF ⇒ SIEMPRE `.standard` (el shipping DARK queda byte-idéntico: la lógica no cambia el render).
//
//  Fuera de v1 (documentado): el caso "sin sesión + grupos CloudKit todavía visibles en la lista" NO aplica
//  aquí — el empty state solo se pinta con la lista VACÍA, así que un usuario con grupos CloudKit visibles
//  nunca lo ve. Decisión v1: no distinguir origen del grupo en la lista vacía.
//

import Foundation

nonisolated enum GroupsEmptyStateLogic {

    enum Kind: Equatable {
        /// Empty state vigente ("aún no tienes grupos", CTA crear). Flag OFF SIEMPRE cae aquí.
        case standard
        /// Flag ON sin sesión backend → "tus grupos están en tu cuenta", CTA iniciar sesión.
        case signInToView
    }

    /// Flag OFF → `.standard` (byte-idéntico). Flag ON + sin sesión → `.signInToView`; con sesión → `.standard`.
    static func decide(flagOn: Bool, hasSession: Bool) -> Kind {
        guard flagOn, !hasSession else { return .standard }
        return .signInToView
    }
}
