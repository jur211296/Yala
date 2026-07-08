//
//  AttestSyncGate.swift
//  Yala
//
//  Pure-logic gate (Modo Nube §f.5, E2E-S10) for App Attest failures on the SYNC path.
//
//  In cloud mode the App Attest token is OBLIGATORY on `/sync/push|pull` (C1 froze "attestation REAL,
//  no JWT-only branch") — so a device that can't attest can NEVER back up (a silent trap for a
//  born-cloud user whose only backend IS the cloud). This gate splits attest failures into:
//   - TRANSIENT → retry with backoff, no alarm, no state change (offline-first already queues deltas).
//   - TERMINAL  → explicit "this device can't sync safely" state + export as the safety net.
//
//  Plus the onboarding upfront gate: born-cloud only offered when attest is terminally SUPPORTED
//  (owner: block-upfront, mirroring Groups' `iCloudSyncService.isAccountAvailable`).
//
//  NO runtime wiring — the consumer (I7c) classifies each failure and, on `.terminal`, fires the
//  `cloudSyncBlockedByAttestUnavailable(platform)` canary + shows the banner. Pure & `nonisolated`.
//

import Foundation

enum AttestSyncGate {

    /// Default retry budget for a repeated `.unavailable` before it's deemed terminal (§f.5 "tras N").
    static let defaultMaxRetries = 3

    enum Classification: Equatable {
        /// Temporary (network / gateway / 5xx / re-register). Retry with backoff; no alarm.
        case transient
        /// Deterministic: the device can't attest. Explicit blocked state + export; NOT retried silently.
        case terminal
    }

    /// Classifies an `AppAttestError` seen on the sync path (§f.5).
    ///
    /// - `.network` → transient (offline-first queues the delta; the retry covers it).
    /// - `.server` → transient (includes gateway 5xx and typed upstream errors; §f.5 lists `.server`).
    /// - `.unknownKey` → transient: this triggers a re-register in `AppAttestClient`, not a
    ///   "device can't attest" verdict.
    /// - `.unavailable` → the terminal SIGNAL, but only once it PERSISTS: a one-off retries, a
    ///   repeated one (`retryCount >= maxRetries`) is a device that genuinely can't attest. In
    ///   release, `isSupported == false` surfaces as `.unavailable` on EVERY attempt → it converges
    ///   to terminal after `maxRetries`. The deterministic `isSupported == false` up-front case is
    ///   caught earlier by `shouldOfferCloudOnly(isAttestSupported:)`, before the user commits.
    static func classify(
        error: AppAttestError,
        retryCount: Int,
        maxRetries: Int = defaultMaxRetries
    ) -> Classification {
        switch error {
        case .network, .server, .unknownKey:
            return .transient
        case .unavailable:
            return retryCount >= maxRetries ? .terminal : .transient
        }
    }

    /// Onboarding born-cloud gate (owner: block-upfront, 2026-07-06): only offer cloud-only when
    /// attest is TERMINALLY supported on this device. Terminal-unsupported → don't offer cloud-only
    /// (offer iCloud / local + export). A transient failure does NOT block here (the retry covers it),
    /// so this keys strictly on the deterministic `isSupported` capability. On real iOS 26 hardware
    /// `isSupported == false` is vanishingly rare → the false-block rate is negligible.
    static func shouldOfferCloudOnly(isAttestSupported: Bool) -> Bool {
        isAttestSupported
    }
}
