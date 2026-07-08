//
//  AccountClaimDecision.swift
//  Yala
//
//  Pure-logic decision (Modo Nube §f.1) that routes the client IMMEDIATELY after a successful
//  `signInWithIdToken` + `POST /account/claim`, and BEFORE any onboarding `save()`. It turns the
//  3-state claim contract (`created` / `existing_stable` / `claiming_in_progress`) + the UI branch
//  into the next action, closing the catastrophic C4 gap of [[MODO-NUBE-GAPS]]: never re-seed over a
//  populated account, never let a follower seed/adopt mid-migration, and warn (not silently seed) on
//  the variant-B provider mismatch.
//
//  NO runtime wiring — the consumer (I7c) feeds it the claim state + branch + beacon flags and acts
//  on the returned `AuthAction`. Pure & `nonisolated`: no context, no I/O, no side effects (the
//  `cloudSignInProviderMismatch` canary is fired by the consumer when the result is `.showProviderMismatch`).
//

import Foundation

enum AccountClaimDecision {

    /// The 3-state result of `POST /account/claim` (§f.1 contract). `created` includes the idempotent
    /// reclaim by the SAME in-progress leader device (the RPC collapses it to `created`).
    enum ClaimState: Equatable {
        /// The row did NOT exist and this call created it → this device is the seeder/leader.
        case created
        /// The row exists in a STABLE state (migration done / account operating) → returning-user.
        case existingStable
        /// The row exists with a migration IN PROGRESS by ANOTHER device (leader ≠ this device).
        case claimingInProgress
    }

    /// Which UI branch invoked the sign-in that produced this claim (§k.2/§k.3/§k.4 · §g.1).
    enum UIBranch: Equatable {
        /// Onboarding, cloud-native, empty backend (§k.3) — seeding is the intended happy path.
        case bornCloud
        /// Existing iCloud user migrating (§g.1) — `created` means "lead the migration", not "seed".
        case migration
        /// "I already have an account → cloud" (§k.4) — expects an existing account to adopt.
        case returningUser
    }

    /// What the client must do next.
    enum AuthAction: Equatable {
        /// Fresh backend, this device is the seeder → seed categories/account (§k.3). born-cloud.
        case seedBornCloud
        /// Fresh backend, migration branch → this device LEADS the migration (→ `claimingMigration`,
        /// §g.1). Distinct from `seedBornCloud`: a migrating device must NOT seed onto its own already
        /// populated local store — it uploads the existing snapshot. (5th action required by §g.1;
        /// see the module report — the born-cloud set alone could not express the migration leader.)
        case proceedMigration
        /// Account already exists & stable → pull summary and dispatch via `RestoreRouter` (§k.4).
        /// NEVER seed (this is the variant-A closure: no seed-over-populated-account).
        case routeReturningUser
        /// Follower: another device is mid-migration → wait for the leader to reach `done` (§g.6).
        case waitForLeader
        /// Variant B (§f.1): the signed-in provider differs from the one the beacon recorded for this
        /// Apple ID, and this `sub` has no row → do NOT silently seed a 2nd divergent account; warn and
        /// offer re-choosing the provider. Consumer fires the `cloudSignInProviderMismatch` canary here.
        case showProviderMismatch
    }

    /// Routes the client after a claim (§f.1).
    ///
    /// - `claimingInProgress` → `waitForLeader`, regardless of branch (a follower never seeds/adopts
    ///   until the leader finishes; §g.1's "otro device ya es líder → espera/seguidor").
    /// - `existingStable` → `routeReturningUser`, NEVER seed (variant-A closure; §k.4).
    /// - `created` → this device owns a fresh row. Variant B fires FIRST: only in the `returningUser`
    ///   branch, only when the beacon says this Apple ID already activated cloud AND the provider does
    ///   not match — a `created` there means a 2nd account under a different provider `sub`. Otherwise
    ///   `migration` → `proceedMigration`; `bornCloud`/`returningUser` → `seedBornCloud`.
    static func decide(
        state: ClaimState,
        branch: UIBranch,
        beaconSaysCloudActivated: Bool,
        providerMatchesBeacon: Bool
    ) -> AuthAction {
        switch state {
        case .claimingInProgress:
            return .waitForLeader
        case .existingStable:
            return .routeReturningUser
        case .created:
            if branch == .returningUser, beaconSaysCloudActivated, !providerMatchesBeacon {
                return .showProviderMismatch
            }
            switch branch {
            case .migration:
                return .proceedMigration
            case .bornCloud, .returningUser:
                return .seedBornCloud
            }
        }
    }
}
