//
//  SetupChecklistDemoSheet.swift
//  Yala
//
//  Wrapper que despacha al View correcto en `mode: .demo` para cada step del
//  Setup Checklist. Steps 2-6 renderizan la View real existente (que ya trae su
//  propia navegación) + overlay `DemoBanner`. Step 1 (`exploreSettings`) tiene
//  chrome propio (carrusel standalone). Step 7 (`discoverFeatures`) NO está en
//  el switch — va directo al paywall sin demo.
//

import SwiftData
import SwiftUI

struct SetupChecklistDemoSheet: View {
    let step: SetupStepID
    @Binding var sheets: PanelSheetState
    let viewModel: PanelViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        switch step {
        case .scheduledPayment:
            ScheduledPaymentEditorView(
                payment: nil,
                mode: .demo,
                onStartReal: { handleStartReal(for: .scheduledPayment) }
            )
        case .firstExpense:
            SetupDemoFirstExpenseView(
                onClose: {
                    sheets.setupDemoStep = nil
                },
                onComplete: {
                    SetupChecklistManager.shared.markCompleted(.firstExpense)
                    sheets.setupDemoStep = nil
                }
            )
        case .firstBudget:
            SetupDemoFirstBudgetView(
                onClose: {
                    sheets.setupDemoStep = nil
                },
                onComplete: {
                    SetupChecklistManager.shared.markCompleted(.firstBudget)
                    sheets.setupDemoStep = nil
                }
            )
        case .tryVoiceInput:
            VoiceRecordingView(
                mode: .demo,
                onStartReal: { handleStartReal(for: .tryVoiceInput) }
            )
        case .tryImageInput:
            ImageSelectionView(
                mode: .demo,
                onStartReal: { handleStartReal(for: .tryImageInput) }
            )
        case .exploreSettings:
            ProfileSectionsCarouselDemo(onOpenSettings: {
                handleStartReal(for: .exploreSettings)
            })
        case .discoverFeatures:
            #if DEBUG
            let _ = assertionFailure("Step 7 (discoverFeatures) no debería abrir demo sheet")
            #endif
            EmptyView()
        }
    }

    /// Cierra el demo sheet y enruta al flow real con micro-delay anti-race.
    /// El race guard `pendingConsentForStep` cubre el caso en que el user
    /// dismissa manualmente entre tap CTA y el sleep.
    @MainActor
    private func handleStartReal(for step: SetupStepID) {
        sheets.pendingConsentForStep = step
        sheets.setupDemoStep = nil

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard sheets.pendingConsentForStep == step else { return }
            sheets.pendingConsentForStep = nil

            switch step {
            case .scheduledPayment:
                AppRouter.shared.enqueue(.navigate(.scheduledPayments))
                AppRouter.shared.enqueue(.autoOpenScheduledEditor)
            case .firstExpense:
                sheets.showNewTransaction = true
            case .firstBudget:
                AppRouter.shared.enqueue(.navigate(.budgets))
                AppRouter.shared.enqueue(.autoOpenBudgetEditor)
            case .tryVoiceInput:
                FeatureGateService.shared.enableSetupTrial(for: .voiceInput)
                sheets.isVoiceSetupTrial = true
                if appPreferences.aiDataConsentAccepted {
                    sheets.showVoiceRecording = true
                } else {
                    sheets.pendingAIInput = .voice
                    sheets.showAIConsentAlert = true
                }
            case .tryImageInput:
                FeatureGateService.shared.enableSetupTrial(for: .imageInput)
                sheets.isImageSetupTrial = true
                sheets.setupTrialExampleImages = ExampleImagesLoader.load()
                if appPreferences.aiDataConsentAccepted {
                    sheets.showImageSelection = true
                } else {
                    sheets.pendingAIInput = .image
                    sheets.showAIConsentAlert = true
                }
            case .exploreSettings:
                sheets.isPresentingSettings = true
                SetupChecklistManager.shared.markCompleted(.exploreSettings)
            case .discoverFeatures:
                break
            }
        }
    }
}
