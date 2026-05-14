//
//  SetupChecklistDemoSheet.swift
//  Yala
//
//  Wrapper que despacha al View standalone correcto para cada Step del Setup
//  Checklist. Cada `SetupDemo*View` corre auto-play scripted con su propio
//  chrome (X cierra sin completar, "Lo tengo claro" marca completed). Step 7
//  (`discoverFeatures`) NO está en el switch — va directo al paywall sin demo.
//

import SwiftData
import SwiftUI

struct SetupChecklistDemoSheet: View {
    let step: SetupStepID
    @Binding var sheets: PanelSheetState
    let viewModel: PanelViewModel

    var body: some View {
        switch step {
        case .scheduledPayment:
            SetupDemoScheduledPaymentView(
                onClose: { sheets.setupDemoStep = nil },
                onComplete: {
                    SetupChecklistManager.shared.markCompleted(.scheduledPayment)
                    sheets.setupDemoStep = nil
                }
            )
        case .firstExpense:
            SetupDemoFirstExpenseView(
                onClose: { sheets.setupDemoStep = nil },
                onComplete: {
                    SetupChecklistManager.shared.markCompleted(.firstExpense)
                    sheets.setupDemoStep = nil
                }
            )
        case .firstBudget:
            SetupDemoFirstBudgetView(
                onClose: { sheets.setupDemoStep = nil },
                onComplete: {
                    SetupChecklistManager.shared.markCompleted(.firstBudget)
                    sheets.setupDemoStep = nil
                }
            )
        case .tryVoiceInput:
            SetupDemoVoiceInputView(
                onClose: { sheets.setupDemoStep = nil },
                onComplete: {
                    SetupChecklistManager.shared.markCompleted(.tryVoiceInput)
                    sheets.setupDemoStep = nil
                }
            )
        case .tryImageInput:
            SetupDemoImageInputView(
                onClose: { sheets.setupDemoStep = nil },
                onComplete: {
                    SetupChecklistManager.shared.markCompleted(.tryImageInput)
                    sheets.setupDemoStep = nil
                }
            )
        case .exploreSettings:
            // Step 1: CTA "Abrir Ajustes" = acción real (abrir ProfileView) + markCompleted.
            // Divergencia documentada vs Steps 2-6 que usan onComplete + "Lo tengo claro".
            ProfileSectionsCarouselDemo(onOpenSettings: {
                sheets.setupDemoStep = nil
                sheets.isPresentingSettings = true
                SetupChecklistManager.shared.markCompleted(.exploreSettings)
            })
        case .discoverFeatures:
            #if DEBUG
            let _ = assertionFailure("Step 7 (discoverFeatures) no debería abrir demo sheet")
            #endif
            EmptyView()
        }
    }
}
