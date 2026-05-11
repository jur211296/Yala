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
            // F2 — primer boceto. Implementado en próxima fase.
            placeholderDemo(title: "Scheduled Payment Demo")
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
