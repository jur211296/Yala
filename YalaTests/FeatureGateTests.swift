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
        #expect(ProFeature.accounts.freeLimit == 4)
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

    // MARK: - Exportar es gratis (2026-10-12)

    /// Exportar todos los datos, de cualquier período y en CSV o Excel, es gratis: es portabilidad y la política de
    /// privacidad lo promete. Ninguna función Pro puede volver a cerrar la exportación.
    @Test func noProFeatureGatesExport() {
        let exportFeatures = ProFeature.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains("export") }
        #expect(exportFeatures.isEmpty, "La exportación volvió a tener puerta Pro: \(exportFeatures)")
    }

    /// El tour que se enseña al pasar a Pro no puede venderla como ventaja de Pro.
    @Test func proTourDoesNotSellExport() {
        let ids = ProTourSteps.profileSteps.map(\.id)
        #expect(!ids.contains { $0.localizedCaseInsensitiveContains("export") }, "El tour Pro aún anuncia exportar: \(ids)")
        #expect(ids == ["settingsAppIcon", "settingsTheme"])
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
}
