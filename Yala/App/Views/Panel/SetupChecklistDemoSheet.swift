//
//  SetupChecklistDemoSheet.swift
//  Yala
//
//  Wrapper que despacha al View correcto en `mode: .demo` para cada step del
//  Setup Checklist. Steps 2-6 renderizan la View real existente (que ya trae su
//  propia navegación) + overlay `DemoBanner`. Step 1 (`exploreSettings`) es la
//  excepción: tiene chrome propio (carrusel standalone sin NavigationStack del
//  View real). Step 7 (`discoverFeatures`) NO está en el switch — va directo al
//  paywall sin demo (decisión de spec: paywall es metarecursivo demoizar).
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
            NewTransactionView(
                mode: .demo,
                onStartReal: { handleStartReal(for: .firstExpense) }
            )
        case .firstBudget:
            BudgetEditorView(
                budget: nil,
                mode: .demo,
                onStartReal: { handleStartReal(for: .firstBudget) }
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
            // F5 — carrusel standalone (chrome propio)
            placeholderDemo(title: "Explore Settings Carousel")
        case .discoverFeatures:
            // Step 7 sin demo. Defensive fallback.
            #if DEBUG
            let _ = assertionFailure("Step 7 (discoverFeatures) no debería abrir demo sheet")
            #endif
            EmptyView()
        }
    }

    /// Dispatcher invocado desde el callback `onStartReal` del demo. Cierra el sheet
    /// y enruta al flow real del step (con micro-delay de 350ms para evitar race
    /// entre dismiss y present del sheet/alert siguiente — patrón canónico).
    @MainActor
    private func handleStartReal(for step: SetupStepID) {
        // Race guard: snapshot del intent ANTES del dismiss. Si el user dismissa
        // manualmente entre el tap y el sleep, el sheet real / consent alert NO aparece.
        sheets.pendingConsentForStep = step
        sheets.setupDemoStep = nil

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            // Guard: intent cancelado
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
                sheets.setupTrialExampleImages = SetupChecklistDemoSheet.loadExampleImages()
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

    /// Loader de example images bundled (replica de PanelView.loadExampleImages).
    static func loadExampleImages() -> [UIImage]? {
        let supportedLangs: Set<String> = ["de", "en", "es", "fr", "it", "pt"]
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        let suffix = supportedLangs.contains(lang) ? lang : "en"
        let images = [
            "ExampleImages/example-receipt-\(suffix)",
            "ExampleImages/example-bank-alert-\(suffix)",
            "ExampleImages/example-transaction-list-\(suffix)"
        ]
        let loaded = images.compactMap { UIImage(named: $0) }
        return loaded.isEmpty ? nil : loaded
    }

    @ViewBuilder
    private func placeholderDemo(title: String) -> some View {
        VStack {
            Text(title)
                .font(.title2)
                .padding()
            Spacer()
            Text("F2-F5 implementarán esta demo.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .overlay(alignment: .top) {
            DemoBanner(onStartReal: { dismiss() })
        }
    }
}
