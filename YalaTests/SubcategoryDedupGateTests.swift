//
//  SubcategoryDedupGateTests.swift
//  YalaTests
//
//  Pure-logic tests for SubcategoryDedupGate.decide. Deterministic `now` injected.
//

import Foundation
import Testing

@testable import Yala

struct SubcategoryDedupGateTests {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func syncing_returnsSyncing() {
        let d = SubcategoryDedupGate.decide(
            now: now, lastImportDate: now, isSyncing: true, lastDedupRunAt: nil
        )
        #expect(d == .syncing)
    }

    @Test func recentImport_returnsWaitQuiescenceWithRemaining() {
        // import hace 3s, quietWindow 8s → faltan 5s.
        let d = SubcategoryDedupGate.decide(
            now: now, lastImportDate: now.addingTimeInterval(-3), isSyncing: false, lastDedupRunAt: nil
        )
        #expect(d == .waitQuiescence(retryAfter: 5))
    }

    @Test func afterQuietWindow_returnsRun() {
        let d = SubcategoryDedupGate.decide(
            now: now, lastImportDate: now.addingTimeInterval(-10), isSyncing: false, lastDedupRunAt: nil
        )
        #expect(d == .run)
    }

    @Test func recentDedup_returnsThrottled() {
        let d = SubcategoryDedupGate.decide(
            now: now, lastImportDate: now.addingTimeInterval(-100), isSyncing: false,
            lastDedupRunAt: now.addingTimeInterval(-30)
        )
        #expect(d == .throttled)
    }

    @Test func throttleTakesPrecedenceOverQuietWindow() {
        // Corrió hace 30s (throttle <60s) Y import hace 2s (quietWindow) → throttled gana.
        let d = SubcategoryDedupGate.decide(
            now: now, lastImportDate: now.addingTimeInterval(-2), isSyncing: false,
            lastDedupRunAt: now.addingTimeInterval(-30)
        )
        #expect(d == .throttled)
    }

    @Test func noICloudAccount_returnsRun() {
        let d = SubcategoryDedupGate.decide(
            now: now, lastImportDate: nil, isSyncing: false, lastDedupRunAt: nil
        )
        #expect(d == .run)
    }
}
