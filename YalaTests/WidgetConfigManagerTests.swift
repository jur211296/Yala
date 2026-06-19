//
//  WidgetConfigManagerTests.swift
//  YalaTests
//
//  Tests para WidgetConfigManager.makeLayoutRows (PP2-05) — verifica que widgets
//  con size == .small se emparejen en half-pair siempre, en iPhone (columns=1)
//  e iPad (columns=2). Los widgets .medium mantienen el comportamiento previo:
//  full-width en iPhone, half-pair en iPad.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct WidgetConfigManagerTests {

    // MARK: - Helpers

    private static func makeConfig(type: WidgetType, size: WidgetSize) -> WidgetConfig {
        WidgetConfig(id: UUID(), type: type, isVisible: true, size: size)
    }

    // MARK: - .small pairing on iPhone (columns=1)

    @Test func smallPlusSmall_iPhone_paired() {
        let a = Self.makeConfig(type: .topSpending, size: .small)
        let b = Self.makeConfig(type: .categoriesPie, size: .small)
        let rows = WidgetConfigManager.makeLayoutRows(for: [a, b], columns: 1)

        #expect(rows.count == 1)
        guard case .halfWidthPair(let left, let right) = rows[0].type else {
            Issue.record("Expected halfWidthPair, got \(rows[0].type)")
            return
        }
        #expect(left.id == a.id)
        #expect(right?.id == b.id)
    }

    @Test func smallAlone_iPhone_halfWithNil() {
        let a = Self.makeConfig(type: .topSpending, size: .small)
        let rows = WidgetConfigManager.makeLayoutRows(for: [a], columns: 1)

        #expect(rows.count == 1)
        guard case .halfWidthPair(let left, let right) = rows[0].type else {
            Issue.record("Expected halfWidthPair, got \(rows[0].type)")
            return
        }
        #expect(left.id == a.id)
        #expect(right == nil)
    }

    @Test func smallThenMedium_iPhone_flushesSmallAndMediumFullWidth() {
        let small = Self.makeConfig(type: .topSpending, size: .small)
        let medium = Self.makeConfig(type: .topSubcategories, size: .medium)
        let rows = WidgetConfigManager.makeLayoutRows(for: [small, medium], columns: 1)

        #expect(rows.count == 2)
        guard case .halfWidthPair(let left, let right) = rows[0].type else {
            Issue.record("Row 0 expected halfWidthPair, got \(rows[0].type)")
            return
        }
        #expect(left.id == small.id)
        #expect(right == nil)

        guard case .fullWidth(let config) = rows[1].type else {
            Issue.record("Row 1 expected fullWidth, got \(rows[1].type)")
            return
        }
        #expect(config.id == medium.id)
    }

    @Test func mediumThenSmall_iPhone_preservesOrder() {
        let medium = Self.makeConfig(type: .topSubcategories, size: .medium)
        let small = Self.makeConfig(type: .topSpending, size: .small)
        let rows = WidgetConfigManager.makeLayoutRows(for: [medium, small], columns: 1)

        #expect(rows.count == 2)
        guard case .fullWidth(let mediumConfig) = rows[0].type else {
            Issue.record("Row 0 expected fullWidth, got \(rows[0].type)")
            return
        }
        #expect(mediumConfig.id == medium.id)

        guard case .halfWidthPair(let left, let right) = rows[1].type else {
            Issue.record("Row 1 expected halfWidthPair, got \(rows[1].type)")
            return
        }
        #expect(left.id == small.id)
        #expect(right == nil)
    }

    // MARK: - iPad pairing (regression)

    @Test func twoMedium_iPad_paired() {
        let a = Self.makeConfig(type: .topSpending, size: .medium)
        let b = Self.makeConfig(type: .topSubcategories, size: .medium)
        let rows = WidgetConfigManager.makeLayoutRows(for: [a, b], columns: 2)

        #expect(rows.count == 1)
        guard case .halfWidthPair(let left, let right) = rows[0].type else {
            Issue.record("Expected halfWidthPair, got \(rows[0].type)")
            return
        }
        #expect(left.id == a.id)
        #expect(right?.id == b.id)
    }

    @Test func trendAlone_fullWidthEvenOnIPad() {
        let trend = Self.makeConfig(type: .trend, size: .medium)
        let rows = WidgetConfigManager.makeLayoutRows(for: [trend], columns: 2)

        #expect(rows.count == 1)
        guard case .fullWidth(let config) = rows[0].type else {
            Issue.record("Expected fullWidth for .trend, got \(rows[0].type)")
            return
        }
        #expect(config.id == trend.id)
    }

    @Test func smallBetweenFullWidthOnlyTypes_iPad_smallAloneInHalf() {
        // `.trend` is in fullWidthOnlyTypes — flushing a pending .small between two
        // trend widgets must produce halfWidthPair(small, nil) + fullWidth(trend) + ...
        let trend1 = Self.makeConfig(type: .trend, size: .medium)
        let small = Self.makeConfig(type: .topSpending, size: .small)
        let trend2 = Self.makeConfig(type: .trend, size: .medium)
        let rows = WidgetConfigManager.makeLayoutRows(
            for: [trend1, small, trend2],
            columns: 2
        )

        #expect(rows.count == 3)
        guard case .fullWidth(let first) = rows[0].type else {
            Issue.record("Row 0 expected fullWidth")
            return
        }
        #expect(first.id == trend1.id)

        guard case .halfWidthPair(let left, let right) = rows[1].type else {
            Issue.record("Row 1 expected halfWidthPair")
            return
        }
        #expect(left.id == small.id)
        #expect(right == nil)

        guard case .fullWidth(let third) = rows[2].type else {
            Issue.record("Row 2 expected fullWidth")
            return
        }
        #expect(third.id == trend2.id)
    }

    // MARK: - PP2-06b: Budgets + ScheduledPayments .small

    @Test func budgetsSmall_withTopCategoriesSmall_iPhone_paired() {
        let budgets = Self.makeConfig(type: .budgets, size: .small)
        let top = Self.makeConfig(type: .topSpending, size: .small)
        let rows = WidgetConfigManager.makeLayoutRows(for: [budgets, top], columns: 1)

        #expect(rows.count == 1)
        guard case .halfWidthPair(let left, let right) = rows[0].type else {
            Issue.record("Expected halfWidthPair, got \(rows[0].type)")
            return
        }
        #expect(left.id == budgets.id)
        #expect(right?.id == top.id)
    }

    @Test func scheduledPaymentsSmall_withBudgetsSmall_iPhone_paired() {
        let scheduled = Self.makeConfig(type: .scheduledPayments, size: .small)
        let budgets = Self.makeConfig(type: .budgets, size: .small)
        let rows = WidgetConfigManager.makeLayoutRows(for: [scheduled, budgets], columns: 1)

        #expect(rows.count == 1)
        guard case .halfWidthPair(let left, let right) = rows[0].type else {
            Issue.record("Expected halfWidthPair, got \(rows[0].type)")
            return
        }
        #expect(left.id == scheduled.id)
        #expect(right?.id == budgets.id)
    }

    @Test func budgetsSmall_pairs_iPad() {
        let a = Self.makeConfig(type: .budgets, size: .small)
        let b = Self.makeConfig(type: .scheduledPayments, size: .small)
        let rows = WidgetConfigManager.makeLayoutRows(for: [a, b], columns: 2)

        #expect(rows.count == 1)
        guard case .halfWidthPair(let left, let right) = rows[0].type else {
            Issue.record("Expected halfWidthPair, got \(rows[0].type)")
            return
        }
        #expect(left.id == a.id)
        #expect(right?.id == b.id)
    }

    @Test func scheduledPaymentsSmall_aloneWithMedium_iPhone_flushesToHalfAndMediumFull() {
        let small = Self.makeConfig(type: .scheduledPayments, size: .small)
        let medium = Self.makeConfig(type: .budgets, size: .medium)
        let rows = WidgetConfigManager.makeLayoutRows(for: [small, medium], columns: 1)

        #expect(rows.count == 2)
        guard case .halfWidthPair(let left, let right) = rows[0].type else {
            Issue.record("Row 0 expected halfWidthPair, got \(rows[0].type)")
            return
        }
        #expect(left.id == small.id)
        #expect(right == nil)

        guard case .fullWidth(let config) = rows[1].type else {
            Issue.record("Row 1 expected fullWidth, got \(rows[1].type)")
            return
        }
        #expect(config.id == medium.id)
    }
}
