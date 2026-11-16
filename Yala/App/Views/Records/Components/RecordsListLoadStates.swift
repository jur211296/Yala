//
//  RecordsListLoadStates.swift
//  Yala
//
//  Los dos estados de la lista de Registros que no son «Sin registros» (decisión 78 de la revisión 2.3, 9-nov): cargando
//  y error de carga. Antes, mientras cargaba no había nada en pantalla y un fallo al leer los movimientos se veía como la
//  lista vacía. Los monta `RecordsTabView` (Registros y Estadísticas › Registros).
//

import SwiftUI

/// Cargando: no se ve nada hasta pasado `RecordsListStateLogic.loadingIndicatorDelay`. La primera pasada suele tardar
/// menos, y un indicador que asoma y se va en un fotograma era el destello que quitó la card C7.
struct RecordsLoadingIndicator: View {
    @State private var isVisible = false

    var body: some View {
        ZStack {
            if isVisible {
                ProgressView {
                    Text(L10n.RecordsVoiceOver23.loading)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.xxl)
                .accessibilityIdentifier("records_loading")
                .transition(.loadingPlaceholder)
            }
        }
        .task {
            do { try await Task.sleep(for: RecordsListStateLogic.loadingIndicatorDelay) } catch { return }
            isVisible = true
        }
    }
}

/// Error de carga: dice que algo falló y ofrece volver a leer, sin parecerse a «Sin registros».
struct RecordsLoadErrorState: View {
    let onRetry: () -> Void

    var body: some View {
        YalaEmptyState(
            icon: "exclamationmark.triangle",
            title: L10n.RecordsVoiceOver23.loadErrorTitle,
            message: L10n.RecordsVoiceOver23.loadErrorMessage,
            actionTitle: L10n.Action.retry,
            action: onRetry,
            // Sin id en el contenedor: pisaría el del botón (regla de `testing.md`).
            actionAccessibilityIdentifier: "records_load_error_retry"
        )
    }
}
