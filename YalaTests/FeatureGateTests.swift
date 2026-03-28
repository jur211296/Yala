//
//  FeatureGateTests.swift
//  YalaTests
//
//  Unit tests for ProFeature enum (pure, no SwiftData).
//

import Foundation
import Testing

@testable import Yala

struct FeatureGateTests {

    @Test func freeLimit_accounts() {
        #expect(ProFeature.accounts.freeLimit == 2)
    }

    @Test func freeLimit_budgets() {
        #expect(ProFeature.budgets.freeLimit == 3)
    }

    @Test func freeLimit_voiceInput_nil() {
        #expect(ProFeature.voiceInput.freeLimit == nil)
    }

    @Test func isProOnly_voiceInput_true() {
        #expect(ProFeature.voiceInput.isProOnly == true)
    }

    @Test func isProOnly_accounts_false() {
        #expect(ProFeature.accounts.isProOnly == false)
    }

    @Test func isProOnly_premiumIcons_true() {
        #expect(ProFeature.premiumIcons.isProOnly == true)
    }

    @Test func isProOnly_exportExtendedPeriods_true() {
        #expect(ProFeature.exportExtendedPeriods.isProOnly == true)
    }

    // MARK: - Setup Trial Bypass

    @MainActor @Test func setupTrial_enablesBypassesProGate() {
        let gate = FeatureGateService.shared
        // Ensure trial features are clean
        gate.disableSetupTrial(for: .voiceInput)
        gate.disableSetupTrial(for: .imageInput)

        // Without trial, Pro-only features are blocked for Free users
        #expect(gate.setupTrialFeatures.isEmpty)

        // Enable trial for voice
        gate.enableSetupTrial(for: .voiceInput)
        #expect(gate.setupTrialFeatures.contains(.voiceInput))

        // Cleanup
        gate.disableSetupTrial(for: .voiceInput)
        #expect(gate.setupTrialFeatures.isEmpty)
    }

    @MainActor @Test func setupTrial_independentPerFeature() {
        let gate = FeatureGateService.shared
        gate.disableSetupTrial(for: .voiceInput)
        gate.disableSetupTrial(for: .imageInput)

        gate.enableSetupTrial(for: .voiceInput)
        #expect(gate.setupTrialFeatures.contains(.voiceInput))
        #expect(!gate.setupTrialFeatures.contains(.imageInput))

        gate.enableSetupTrial(for: .imageInput)
        #expect(gate.setupTrialFeatures.contains(.imageInput))

        gate.disableSetupTrial(for: .voiceInput)
        #expect(!gate.setupTrialFeatures.contains(.voiceInput))
        #expect(gate.setupTrialFeatures.contains(.imageInput))

        gate.disableSetupTrial(for: .imageInput)
    }

    // MARK: - DetailPeriod.isProExportPeriod

    @Test func isProExportPeriod_freePeriods_false() {
        let freePeriods: [DetailPeriod] = [.thisWeek, .last7Days, .last30Days, .thisMonth, .lastMonth]
        for period in freePeriods {
            #expect(period.isProExportPeriod == false, "\(period) should be free")
        }
    }

    @Test func isProExportPeriod_proPeriods_true() {
        let proPeriods: [DetailPeriod] = [.thisYear, .lastYear, .allTime, .custom]
        for period in proPeriods {
            #expect(period.isProExportPeriod == true, "\(period) should be pro")
        }
    }
}
