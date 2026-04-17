//
//  HeroKPIPreferencesTests.swift
//  YalaTests
//
//  Coverage for the Hero KPI preferences mutators on `PanelViewModel` (P20-04b).
//  Mirrors the style of `PanelSectionPreferencesTests` — isolated `UserDefaults`
//  suite per test, `panelPrefsMigratedV2` pre-seeded so the AppPreferences
//  migration path never touches `UserDefaults.standard`.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct HeroKPIPreferencesTests {

    // MARK: - Helpers

    private static func makeSuite() -> UserDefaults {
        let suiteName = "HeroKPIPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        return defaults
    }

    private static func makeVM(with prefs: AppPreferences) -> PanelViewModel {
        let vm = PanelViewModel()
        vm.setAppPreferences(prefs)
        return vm
    }

    // MARK: - 1. Defaults path — `customized == false`

    @Test func orderedHeroKPIs_notCustomized_returnsDefaultOrder() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        // `panelHeroKPIsCustomized` stays `false` — stored arrays are ignored.
        let vm = Self.makeVM(with: prefs)
        #expect(vm.orderedHeroKPIs() == HeroKPI.defaultOrder)
    }

    @Test func isHeroKPIHidden_notCustomized_consultsDefaultHidden() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let vm = Self.makeVM(with: prefs)

        // Defaults: income/spent/daysLeft visible; rest hidden.
        #expect(vm.isHeroKPIHidden(.income) == false)
        #expect(vm.isHeroKPIHidden(.spent) == false)
        #expect(vm.isHeroKPIHidden(.daysLeft) == false)
        #expect(vm.isHeroKPIHidden(.available) == true)
        #expect(vm.isHeroKPIHidden(.dailyAverage) == true)
        #expect(vm.isHeroKPIHidden(.projection) == true)
    }

    // MARK: - 2. Self-heal — customised but stored order misses a KPI

    @Test func orderedHeroKPIs_customized_healsCorruption_byAppendingMissingAtTail() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        prefs.panelHeroKPIsCustomized = true
        // Store only 2 KPIs out of 6 — rest must appear at the tail.
        prefs.panelHeroKPIsOrder = [HeroKPI.projection.rawValue, HeroKPI.income.rawValue]

        let vm = Self.makeVM(with: prefs)
        let result = vm.orderedHeroKPIs()

        // Stored entries first, in stored order.
        #expect(result[0] == .projection)
        #expect(result[1] == .income)
        // Then the missing defaults, in `defaultOrder` traversal order.
        #expect(Set(result) == Set(HeroKPI.allCases))
        #expect(result.count == HeroKPI.allCases.count)
    }

    // MARK: - 3. Customised empty hidden array is respected

    @Test func isHeroKPIHidden_customized_respectsEmptyArrayDeliberately() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        prefs.panelHeroKPIsCustomized = true
        prefs.panelHeroKPIsHidden = [] // user deliberately activated all 6

        let vm = Self.makeVM(with: prefs)
        // Without the customised flag the VM would have forced `defaultHidden`
        // on the last three KPIs — with the flag on, empty means "none hidden".
        for kpi in HeroKPI.allCases {
            #expect(vm.isHeroKPIHidden(kpi) == false, "\(kpi) should be visible")
        }
    }

    // MARK: - 4. Cap of 3 visible

    @Test func activeHeroKPIs_capsAtThree_preservingOrder() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        prefs.panelHeroKPIsCustomized = true
        prefs.panelHeroKPIsHidden = [] // all 6 active
        prefs.panelHeroKPIsOrder = [
            HeroKPI.projection.rawValue,
            HeroKPI.available.rawValue,
            HeroKPI.income.rawValue,
            HeroKPI.spent.rawValue,
            HeroKPI.daysLeft.rawValue,
            HeroKPI.dailyAverage.rawValue
        ]

        let vm = Self.makeVM(with: prefs)
        let active = vm.activeHeroKPIs()
        #expect(active == [.projection, .available, .income])

        // `.max` escape hatch used by the sheet to count active for the
        // last-active-toggle guard.
        #expect(vm.activeHeroKPIs(max: .max).count == 6)
    }

    // MARK: - 5. Flag flips on first change

    @Test func setHeroKPIHidden_flipsCustomizedFlag_onFirstChange() async {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.panelHeroKPIsCustomized == false)

        let vm = Self.makeVM(with: prefs)
        vm.setHeroKPIHidden(.available, hidden: false) // activate one extra
        vm.flushPendingHeroKPIWrites()

        #expect(prefs.panelHeroKPIsCustomized == true)
        // Hidden list now contains only the OTHER two defaults.
        #expect(prefs.panelHeroKPIsHidden.sorted() == [
            HeroKPI.dailyAverage.rawValue,
            HeroKPI.projection.rawValue
        ].sorted())
    }

    // MARK: - 6. Reset clears everything

    @Test func resetHeroKPIPreferences_clearsDrafts_arrays_andCustomizedFlag() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        prefs.panelHeroKPIsCustomized = true
        prefs.panelHeroKPIsOrder = [HeroKPI.projection.rawValue]
        prefs.panelHeroKPIsHidden = [HeroKPI.income.rawValue]

        let vm = Self.makeVM(with: prefs)
        vm.resetHeroKPIPreferences()

        #expect(prefs.panelHeroKPIsCustomized == false)
        #expect(prefs.panelHeroKPIsOrder == [])
        #expect(prefs.panelHeroKPIsHidden == [])
        // After reset, orderedHeroKPIs/isHeroKPIHidden must return defaults again.
        #expect(vm.orderedHeroKPIs() == HeroKPI.defaultOrder)
        #expect(vm.isHeroKPIHidden(.available) == true)
    }

    // MARK: - 7. Reorder no-op early-returns

    @Test func moveHeroKPI_noOp_doesNotTouchCustomizedFlag() async {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let vm = Self.makeVM(with: prefs)
        // Move with a source+destination that yields the same order → early return.
        vm.moveHeroKPI(from: IndexSet(integer: 0), to: 0)
        vm.flushPendingHeroKPIWrites()

        #expect(prefs.panelHeroKPIsCustomized == false)
        #expect(prefs.panelHeroKPIsOrder == [])
    }

    // MARK: - 8. Reorder among actives preserves hidden absolute positions

    @Test func moveActiveHeroKPI_swaps_onlyReordersActives_notHidden() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let vm = Self.makeVM(with: prefs)

        // Default state: [income, spent, daysLeft, available, dailyAverage, projection]
        // Actives = [income, spent, daysLeft] (first 3). Hidden = last 3.
        // Move "daysLeft" (active index 2) to active index 0.
        vm.moveActiveHeroKPI(from: IndexSet(integer: 2), to: 0)
        vm.flushPendingHeroKPIWrites()

        // Active slots are indices 0, 1, 2 in the full order; hidden occupy
        // 3, 4, 5. After the reorder actives become [daysLeft, income, spent]
        // and hidden stay exactly where they were.
        let newOrder = prefs.panelHeroKPIsOrder
        #expect(newOrder == [
            HeroKPI.daysLeft.rawValue,
            HeroKPI.income.rawValue,
            HeroKPI.spent.rawValue,
            HeroKPI.available.rawValue,
            HeroKPI.dailyAverage.rawValue,
            HeroKPI.projection.rawValue
        ])
    }
}
