//
//  SessionExpiryPolicy.swift
//  Yala
//
//  Pure-logic policy (Modo Nube §f.3/§f.5, S11) for the COMPOUND case: the Supabase refresh token
//  expired during a long offline window AND the outbox still has unsynced deltas. Re-login can
//  fail/stall, blocking the drain — with no proactive communication. The data is SAFE locally
//  (offline-first); the gap is UX/visibility, not loss.
//
//  Rule: `pending > 0` AND the session cannot renew → an EXPLICIT, actionable state ("you have N
//  unsynced changes — sign in to upload them", CTA to sign-in), NOT a silent failure or a retry loop.
//  `pending == 0` → OK even if the session can't renew (nothing is waiting to go up).
//
//  NO runtime wiring — the consumer (I7c/I8 drain) evaluates this and, on `.blockedNeedsSignIn`,
//  surfaces the banner + fires the `cloudSyncBlockedByExpiredSession(pending)` breadcrumb. Pure &
//  `nonisolated`.
//

import Foundation

enum SessionExpiryPolicy {

    enum Decision: Equatable {
        /// Nothing to do: either the session can renew, or there's nothing pending to upload.
        case ok
        /// Actionable blocked state: `pending` changes are stuck because the session can't renew.
        case blockedNeedsSignIn(pending: Int)
    }

    /// Decides whether an expired/unrenewable session must surface a blocked state.
    ///
    /// - `pending > 0 && !canRenewSession` → `.blockedNeedsSignIn(pending:)` (explicit CTA, no loop).
    /// - otherwise (`pending == 0`, or the session can renew) → `.ok`.
    static func decide(pending: Int, canRenewSession: Bool) -> Decision {
        if pending > 0, !canRenewSession {
            return .blockedNeedsSignIn(pending: pending)
        }
        return .ok
    }
}
