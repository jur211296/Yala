//
//  UserDataResetView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Vaciar datos del usuario (FIN-25)

struct UserDataResetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingConfirmationAlert = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    /// Callback opcional para notificar que el borrado completo de datos
    /// se ha realizado y permitir cerrar también la hoja de Ajustes.
    let onUserDataWiped: (() -> Void)?

    init(onUserDataWiped: (() -> Void)? = nil) {
        self.onUserDataWiped = onUserDataWiped
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    SectionBox(title: L10n.Settings.resetData) {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.Settings.resetAllData)
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                Text(
                                    L10n.Settings.resetDataDescription
                                )
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                            SubsectionDivider()

                            Button(role: .destructive) {
                                isShowingConfirmationAlert = true
                            } label: {
                                HStack {
                                    if isProcessing {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                    }

                                    Text(L10n.Settings.deleteAllData)
                                        .font(.body)

                                    Spacer()
                                }
                                .padding(16)
                            }
                            .disabled(isProcessing)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(L10n.Settings.resetData)
        .navigationBarTitleDisplayMode(.inline)

        // Alerta principal de confirmación
        .alert(
            L10n.Settings.deleteDataConfirmation,
            isPresented: $isShowingConfirmationAlert
        ) {
            Button(L10n.Settings.cancel, role: .cancel) {
                // El usuario se arrepiente, no hacemos nada.
            }

            Button(L10n.Settings.deleteAllDataAction, role: .destructive) {
                Task {
                    await handleWipeAllData()
                }
            }
        } message: {
            Text(
                L10n.Settings.deleteDataWarning
            )
        }

        // Alerta secundaria para errores
        .alert(
            L10n.Settings.deleteDataError,
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button(L10n.Common.accept, role: .cancel) {}
        } message: {
            Text(errorMessage ?? L10n.Settings.deleteDataUnknownError)
        }
    }

    // MARK: - Lógica de borrado

    @MainActor
    private func handleWipeAllData() async {
        isProcessing = true

        // 1. Activate wipe overlay BEFORE starting deletion
        //    This prevents @Query observers from crashing by showing a blocking overlay
        SessionState.shared.isWipingData = true

        // 2. Dismiss all sheets first to reduce active observers
        onUserDataWiped?()
        dismiss()

        // 3. Wait for SwiftUI to fully unmount the TabView and deactivate @Query observers
        //    This is critical - without this delay, @Query observers may still be active during deletion
        try? await Task.sleep(for: .milliseconds(500))

        // 4. Perform the actual wipe
        do {
            try DataWipeService.wipeAllUserData(
                in: modelContext,
                reseedInitialData: true
            )

            // 5. Small delay to let SwiftData settle before removing overlay
            try? await Task.sleep(for: .milliseconds(200))

            isProcessing = false
            SessionState.shared.isWipingData = false

            // 6. Load exchange rates directly after wipe (more reliable than flag mechanism)
            //    We call the service directly using the same context
            try? await Task.sleep(for: .milliseconds(100))
            await ExchangeRateService.shared.updateTodayIfNeeded(context: modelContext)
            await ExchangeRateService.shared.preloadHistoricalIfNeeded(context: modelContext)
            await TransactionUpdateService.updateProvisionalTransactions(context: modelContext)

            // 7. Trigger widget refresh so Panel recalculates with new data
            SessionState.shared.needsExchangeRateWidgetRefresh = true
        } catch {
            isProcessing = false
            SessionState.shared.isWipingData = false
            errorMessage = error.localizedDescription
        }
    }
}
