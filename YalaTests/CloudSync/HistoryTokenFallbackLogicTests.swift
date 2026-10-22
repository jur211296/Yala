//
//  HistoryTokenFallbackLogicTests.swift
//  YalaTests / CloudSync
//
//  DIFERIDOS #33: tabla exhaustiva de `HistoryTokenFallbackLogic.decide` (3 estados de token ×
//  ancla nil/presente) + cutoff exacto (`ancla − slack`). Pure-logic, sin contexto SwiftData.
//

import Foundation
import Testing

@testable import Yala

@Suite("HistoryTokenFallbackLogic · tabla de decisión (DIFERIDOS #33)")
struct HistoryTokenFallbackLogicTests {

    private let anchor = Date(timeIntervalSince1970: 1_700_000_000)
    private let slack: TimeInterval = 60

    @Test func absent_ignoresAnchor_isBootstrapFullRescan() {
        // Token ausente = bootstrap legítimo, CON o SIN ancla (un cursor jamás avanzado no tiene
        // nada drenado que re-emitir — el ancla presente no cambia la rama).
        #expect(HistoryTokenFallbackLogic.decide(
            tokenState: .absent, lastDrainedTxAt: nil, slack: slack) == .fullRescanBootstrap)
        #expect(HistoryTokenFallbackLogic.decide(
            tokenState: .absent, lastDrainedTxAt: anchor, slack: slack) == .fullRescanBootstrap)
    }

    @Test func valid_ignoresAnchor_isTokenFetch() {
        #expect(HistoryTokenFallbackLogic.decide(
            tokenState: .valid, lastDrainedTxAt: nil, slack: slack) == .tokenFetch)
        #expect(HistoryTokenFallbackLogic.decide(
            tokenState: .valid, lastDrainedTxAt: anchor, slack: slack) == .tokenFetch)
    }

    @Test func broken_withoutAnchor_isFullRescanNoAnchor() {
        // Semántica (a) del cierre: cursor pre-schema → full-rescan CONSERVADO.
        #expect(HistoryTokenFallbackLogic.decide(
            tokenState: .broken, lastDrainedTxAt: nil, slack: slack) == .fullRescanNoAnchor)
    }

    @Test func broken_withAnchor_isBoundedRescan_cutoffIsAnchorMinusSlack() {
        let branch = HistoryTokenFallbackLogic.decide(
            tokenState: .broken, lastDrainedTxAt: anchor, slack: slack)
        #expect(branch == .boundedRescan(cutoff: anchor.addingTimeInterval(-60)))
    }

    @Test func broken_withAnchor_zeroSlack_cutoffIsAnchor() {
        // El slack solo ENSANCHA el fetch; con slack 0 el cutoff es el ancla exacta.
        let branch = HistoryTokenFallbackLogic.decide(
            tokenState: .broken, lastDrainedTxAt: anchor, slack: 0)
        #expect(branch == .boundedRescan(cutoff: anchor))
    }
}
