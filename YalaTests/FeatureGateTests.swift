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
