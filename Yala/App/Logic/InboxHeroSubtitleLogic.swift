//
//  InboxHeroSubtitleLogic.swift
//  Yala
//
//  Pure-logic helper para el subtítulo motivacional del mini-hero de Inbox.
//  La localización vive en el callsite (InboxView.heroSubtitleText) — este
//  helper no depende de L10n para mantener tests sin Bundle lookup.
//

import Foundation

enum InboxHeroSubtitle: Equatable {
    case allDone
    case onePending
    case multiplePending(Int)
}

enum InboxHeroSubtitleLogic {
    /// Decide el subtítulo motivacional según el conteo global de drafts pendientes.
    /// Count <= 0 → allDone (incluye negativos defensivos).
    static func subtitle(pendingCount: Int) -> InboxHeroSubtitle {
        guard pendingCount > 0 else { return .allDone }
        return pendingCount == 1 ? .onePending : .multiplePending(pendingCount)
    }
}
