//
//  UserDataResetView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
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
                    SectionBox(title: "Vaciar tus datos") {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Vaciar todos tus datos")
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                Text(
                                    "Esta operación eliminará de forma permanente tus cuentas, transacciones, presupuestos, tipos de cambio, categorías y cualquier otro dato asociado a tu perfil de Finaria. Después del borrado, la app volverá a un estado similar al inicial."
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

                                    Text("Eliminar todos mis datos")
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
        .navigationTitle("Vaciar datos")
        .navigationBarTitleDisplayMode(.inline)

        // Alerta principal de confirmación
        .alert(
            "¿Eliminar todos tus datos?",
            isPresented: $isShowingConfirmationAlert
        ) {
            Button("Cancelar", role: .cancel) {
                // El usuario se arrepiente, no hacemos nada.
            }

            Button("Eliminar definitivamente", role: .destructive) {
                Task {
                    await handleWipeAllData()
                }
            }
        } message: {
            Text(
                "Esta acción es irreversible. Se eliminarán todas tus cuentas, transacciones, presupuestos, tipos de cambio y categorías. Después de esto, Finaria se reiniciará a un estado similar al inicial y no podrás recuperar tus datos."
            )
        }

        // Alerta secundaria para errores
        .alert(
            "Error al eliminar datos",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Ha ocurrido un error desconocido al eliminar los datos.")
        }
    }

    // MARK: - Lógica de borrado

    @MainActor
    private func handleWipeAllData() async {
        isProcessing = true

        do {
            try DataWipeService.wipeAllUserData(
                in: modelContext,
                reseedInitialData: true
            )

            isProcessing = false

            // Notificamos al presentador (Ajustes) para que cierre la hoja
            // y el usuario vuelva al Panel de inicio.
            onUserDataWiped?()

            // Cerramos también esta vista de confirmación si sigue visible.
            dismiss()
        } catch {
            isProcessing = false
            errorMessage = error.localizedDescription
        }
    }
}
