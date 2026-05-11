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

    var body: some View {
        switch step {
        case .scheduledPayment:
            ScheduledPaymentEditorView(
                payment: nil,
                mode: .demo,
                onStartReal: { handleStartReal(for: .scheduledPayment) }
            )
        case .firstExpense:
            // F3
            placeholderDemo(title: "First Expense Demo")
        case .firstBudget:
            // F3
            placeholderDemo(title: "First Budget Demo")
        case .tryVoiceInput:
            // F4
            placeholderDemo(title: "Voice Input Demo")
        case .tryImageInput:
            // F4
            placeholderDemo(title: "Image Input Demo")
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
        sheets.setupDemoStep = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            switch step {
            case .scheduledPayment:
                AppRouter.shared.enqueue(.navigate(.scheduledPayments))
                AppRouter.shared.enqueue(.autoOpenScheduledEditor)
            case .firstExpense:
                sheets.showNewTransaction = true
            case .firstBudget:
                AppRouter.shared.enqueue(.navigate(.budgets))
                AppRouter.shared.enqueue(.autoOpenBudgetEditor)
            case .tryVoiceInput, .tryImageInput:
                // F4 — consent flow con race guard
                break
            case .exploreSettings:
                sheets.isPresentingSettings = true
                SetupChecklistManager.shared.markCompleted(.exploreSettings)
            case .discoverFeatures:
                break
            }
        }
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
