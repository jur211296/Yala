//
//  PanelViewModelTests.swift
//  YalaTests
//
//  Unit tests for PanelViewModel pure logic (account sorting, sort order consistency).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct PanelViewModelTests {

    // MARK: - Helpers

    private func makeAccount(name: String, isArchived: Bool = false) -> Account {
        let account = Account(
            name: name,
            currencyCode: "PEN",
            colorHex: "#000000",
            iconName: "creditcard",
            type: "bank"
        )
        account.isArchived = isArchived
        return account
    }

    // MARK: - orderedActiveAccounts

    @MainActor @Test func orderedActiveAccounts_excludesArchived() {
        let vm = PanelViewModel()
        let active = makeAccount(name: "Checking")
        let archived = makeAccount(name: "Old", isArchived: true)

        let result = vm.orderedActiveAccounts(
            from: [active, archived],
            sortOrderNames: ["Checking", "Old"]
        )
        #expect(result.count == 1)
        #expect(result[0].name == "Checking")
    }

    @MainActor @Test func orderedActiveAccounts_respectsSortOrder() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")
        let c = makeAccount(name: "Charlie")

        let result = vm.orderedActiveAccounts(
            from: [a, b, c],
            sortOrderNames: ["Charlie", "Alpha", "Beta"]
        )
        #expect(result[0].name == "Charlie")
        #expect(result[1].name == "Alpha")
        #expect(result[2].name == "Beta")
    }

    @MainActor @Test func orderedActiveAccounts_unknownFallsToEnd() {
        let vm = PanelViewModel()
        let known = makeAccount(name: "Checking")
        let unknown = makeAccount(name: "NewAccount")

        let result = vm.orderedActiveAccounts(
            from: [unknown, known],
            sortOrderNames: ["Checking"]
        )
        #expect(result[0].name == "Checking")
        #expect(result[1].name == "NewAccount")
    }

    @MainActor @Test func orderedActiveAccounts_bothUnknown_sortByName() {
        let vm = PanelViewModel()
        let z = makeAccount(name: "Zeta")
        let a = makeAccount(name: "Alpha")

        let result = vm.orderedActiveAccounts(
            from: [z, a],
            sortOrderNames: []
        )
        #expect(result[0].name == "Alpha")
        #expect(result[1].name == "Zeta")
    }

    // MARK: - ensureAccountsSortOrderConsistency

    @MainActor @Test func sortOrderConsistency_removesDeleted() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Checking")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a],
            currentOrder: ["Checking", "Savings"]
        )
        #expect(result == ["Checking"])
    }

    @MainActor @Test func sortOrderConsistency_addsNew() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Checking")
        let b = makeAccount(name: "NewAccount")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b],
            currentOrder: ["Checking"]
        )
        #expect(result == ["Checking", "NewAccount"])
    }

    @MainActor @Test func sortOrderConsistency_preservesExisting() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")
        let c = makeAccount(name: "Charlie")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b, c],
            currentOrder: ["Charlie", "Alpha", "Beta"]
        )
        #expect(result == ["Charlie", "Alpha", "Beta"])
    }

    @MainActor @Test func sortOrderConsistency_emptyAccounts() {
        let vm = PanelViewModel()

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [],
            currentOrder: ["Checking", "Savings"]
        )
        #expect(result == [])
    }

    @MainActor @Test func sortOrderConsistency_emptyCurrentOrder() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b],
            currentOrder: []
        )
        // Both are new → appended in array order
        #expect(result.contains("Alpha"))
        #expect(result.contains("Beta"))
    }

    @MainActor @Test func sortOrderConsistency_roundTrip() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")
        let c = makeAccount(name: "Charlie")

        // First, get consistency output
        let consistent = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b, c],
            currentOrder: ["Beta", "Charlie", "Alpha"]
        )

        // Use that output as sortOrderNames for orderedActiveAccounts
        let ordered = vm.orderedActiveAccounts(from: [a, b, c], sortOrderNames: consistent)

        #expect(ordered[0].name == "Beta")
        #expect(ordered[1].name == "Charlie")
        #expect(ordered[2].name == "Alpha")
    }

    // MARK: - hiddenSections compute-skip (P20-02)

    /// Default state: every toggleable section reports visible, which drives
    /// the guards in `performCalculation` / `calculateTrendData`.
    @MainActor @Test func visibilityGuard_defaultsToVisible() {
        let vm = PanelViewModel()
        for kind in PanelSectionKind.toggleableSections {
            #expect(vm.isSectionVisible(kind), "\(kind) should default to visible")
        }
    }

    /// Toggling a section into `hiddenSections` flips the guard so its compute
    /// block is skipped in the calculation pipeline.
    @MainActor @Test func visibilityGuard_respectsHiddenSet() {
        let vm = PanelViewModel()
        vm.hiddenSections = [.distribucion, .planificacion]

        #expect(!vm.isSectionVisible(.distribucion))
        #expect(!vm.isSectionVisible(.planificacion))
        #expect(vm.isSectionVisible(.tendencias))
        #expect(vm.isSectionVisible(.tools))
    }

    /// `latestRecords` is the Panel's primary CTA — the guard must treat it as
    /// visible even if it slips into `hiddenSections`.
    @MainActor @Test func visibilityGuard_latestRecordsAlwaysVisible() {
        let vm = PanelViewModel()
        vm.hiddenSections = [.latestRecords, .distribucion, .tendencias, .planificacion]
        #expect(vm.isSectionVisible(.latestRecords))
    }

    /// `toggleableSections` must exclude non-toggleable sections — guarantees
    /// the config sheet never lets users hide `latestRecords`.
    @Test func toggleableSections_excludesNonToggleable() {
        let toggleable = PanelSectionKind.toggleableSections
        #expect(!toggleable.contains(.latestRecords))
        for section in toggleable {
            #expect(section.canBeHidden)
        }
    }

    /// Every `PanelSectionKind` case must have a non-empty localized title and
    /// icon so the sections-config sheet never shows a blank row.
    @Test func everySectionHasTitleAndIcon() {
        for kind in PanelSectionKind.allCases {
            #expect(!kind.localizedTitle.isEmpty, "\(kind) missing title")
            #expect(!kind.iconName.isEmpty, "\(kind) missing icon")
        }
    }

    // MARK: - Hero IA (P20-05)
    //
    // Acotados a invariantes sin network: Free/no-consent reset del estado y
    // guard de heroData. El flow Pro+consent+API no se testea aquí — eso vive
    // en `HeroMessageCacheTests` (capa pura) y QA manual con `Yala Dev`.

    /// Sin `heroWidget.data`, `retriggerHeroAI` no toca el estado IA —
    /// precondición del VM antes de armar el contexto.
    @MainActor @Test func retriggerHeroAI_withoutHeroData_isNoOp() {
        let vm = PanelViewModel()
        vm.heroAISubtitle = "texto preseteado"

        vm.retriggerHeroAI()

        #expect(vm.heroAISubtitle == "texto preseteado")
    }

    /// Si el user no tiene consent IA, el VM debe dejar `heroAISubtitle`
    /// en nil (el view cae al fallback rule-based).
    @MainActor @Test func retriggerHeroAI_noConsent_resetsHeroAIState() {
        let vm = PanelViewModel()
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: "retriggerHeroAI.noConsent.\(UUID().uuidString)")!)
        prefs.aiInsightsConsentAccepted = false
        vm.setAppPreferences(prefs)

        vm.heroWidget = PanelHeroData(data: HeroMonthData(
            state: .neutral, income: 4500, expense: 1500,
            daysRemaining: 20, daysElapsed: 10
        ))
        vm.heroAISubtitle = "mensaje viejo"

        vm.retriggerHeroAI()

        #expect(vm.heroAISubtitle == nil)
    }
}
