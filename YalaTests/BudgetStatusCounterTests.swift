//
//  BudgetStatusCounterTests.swift
//  YalaTests
//
//  Pure-logic tests para BudgetStatusCounter.{classify, counters}.
//  Sin SwiftData, sin UI.
//

import Foundation
import Testing

@testable import Yala

struct BudgetStatusCounterTests {

    // MARK: - classify

    @Test func classify_belowThreshold_returnsOnTrack() {
        #expect(BudgetStatusCounter.classify(spent: 79, limit: 100) == .onTrack)
    }

    @Test func classify_atLowerLimit_returnsAtLimit() {
        #expect(BudgetStatusCounter.classify(spent: 80, limit: 100) == .atLimit)
    }

    @Test func classify_nearUpperLimit_returnsAtLimit() {
        #expect(BudgetStatusCounter.classify(spent: 99, limit: 100) == .atLimit)
    }

    @Test func classify_atOrAboveLimit_returnsOverLimit() {
        #expect(BudgetStatusCounter.classify(spent: 100, limit: 100) == .overLimit)
        #expect(BudgetStatusCounter.classify(spent: 150, limit: 100) == .overLimit)
    }

    @Test func classify_zeroLimit_returnsOnTrackDefensive() {
        #expect(BudgetStatusCounter.classify(spent: 0,   limit: 0) == .onTrack)
        #expect(BudgetStatusCounter.classify(spent: 100, limit: 0) == .onTrack)
    }

    @Test func classify_negativeLimit_returnsOnTrackDefensive() {
        #expect(BudgetStatusCounter.classify(spent: 50, limit: -10) == .onTrack)
    }

    // MARK: - counters

    @Test func counters_emptyInput_returnsZero() {
        let result = BudgetStatusCounter.counters(for: [])
        #expect(result == BudgetCounters.zero)
    }

    @Test func counters_mixedItems_aggregatesCorrectly() {
        let items: [(spent: Double, limit: Double)] = [
            (50,  100),    // onTrack
            (80,  100),    // atLimit
            (90,  100),    // atLimit
            (100, 100),    // overLimit
            (200, 100),    // overLimit
            (0,   100),    // onTrack
        ]
        let result = BudgetStatusCounter.counters(for: items)
        #expect(result == BudgetCounters(onTrack: 2, atLimit: 2, overLimit: 2))
    }

    // MARK: - Umbral único de la barra (card bj9n, 2026-11-04)

    /// La barra se pinta de aviso justo donde empieza «en el límite»: al 80 %, no al 75 % de antes.
    @Test func barWarning_startsWhereAtLimitStarts() {
        #expect(BudgetStatusCounter.atLimitPercent == 80)
        #expect(!BudgetStatusCounter.isAtOrPastLimit(percent: 75))
        #expect(!BudgetStatusCounter.isAtOrPastLimit(percent: 79.99))
        #expect(BudgetStatusCounter.isAtOrPastLimit(percent: 80))
        #expect(BudgetStatusCounter.isAtOrPastLimit(percent: 99))
        #expect(BudgetStatusCounter.isAtOrPastLimit(percent: 100))
        #expect(BudgetStatusCounter.isAtOrPastLimit(percent: 150))
    }

    /// Color y estado salen del mismo umbral: para cualquier porcentaje, la barra avisa si y solo si el estado no es
    /// «al día». Con dos números distintos este caso cae en el tramo que los separa.
    @Test func barWarning_matchesTheStatusForEveryPercent() {
        for tenths in 0...1_500 {
            let percent = Double(tenths) / 10
            let status = BudgetStatusCounter.classify(spent: percent, limit: 100)
            #expect(BudgetStatusCounter.isAtOrPastLimit(percent: percent) == (status != .onTrack),
                    "Barra y estado no coinciden al \(percent) %")
        }
    }
}

/// La barra no lleva su propio número: lee el umbral de `BudgetStatusCounter` (source-scan, card bj9n).
struct BudgetProgressBarThresholdWiringTests {
    private static func codeLines(_ relativePath: String, file: StaticString = #filePath) throws -> [String] {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
    }

    @Test func progressBar_readsTheSharedThreshold() throws {
        let code = try Self.codeLines("Yala/App/Views/Planning/Components/BudgetProgressBar.swift")
        #expect(code.contains("if BudgetStatusCounter.isAtOrPastLimit(percent: percentage) { return DS.Semantic.warningForeground }"),
                "La barra dejó de pintar el aviso con el umbral de «en el límite».")
        #expect(!code.contains { $0.contains("percentage >= 75") || $0.contains("percentage >= 80") },
                "La barra volvió a llevar su propio umbral.")
    }
}
