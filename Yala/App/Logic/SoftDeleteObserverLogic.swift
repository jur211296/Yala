//
//  SoftDeleteObserverLogic.swift
//  Yala
//
//  Pure-logic helpers for FU-02 cleanup observers en `SplitSyncManager`.
//  Sin dependencia de SwiftData ni CloudKit — testeable sin context (regla R8).
//

import Foundation

enum SoftDeleteObserverLogic {

    /// Decide si dispararle `freezeForSoftDelete + cascade + delete + leaveShare` al device
    /// del current user cuando llega un update remoto del `SplitMember`.
    ///
    /// Solo se dispara cuando el current user PASA de `.active` a `.removed` (admin lo removió
    /// remotamente). NO se dispara para `.left` (el current user mismo hizo `leaveGroup`
    /// local — el cleanup corre ahí mismo, no via observer).
    ///
    /// - Parameters:
    ///   - wasActiveAndCurrentUser: Snapshot previo al `CKRecordTranslator.update` —
    ///     `existing.isActive && existing.isCurrentUser`.
    ///   - newStatus: Status post-update.
    /// - Returns: `true` si debe dispararse el cleanup.
    static func shouldTriggerRemovedSelfCleanup(
        wasActiveAndCurrentUser: Bool,
        newStatus: SplitMemberStatus
    ) -> Bool {
        wasActiveAndCurrentUser && newStatus == .removed
    }
}
