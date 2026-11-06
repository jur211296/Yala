//
//  StatisticsView.swift
//  Yala
//
//  Statistics tab view with PanelView-style navigation.
//

import SwiftUI

struct StatisticsView: View {
    @Environment(SessionState.self) private var sessionState
    @Environment(SceneNavigation.self) private var navigation

    /// Vive aquí, fuera de la pila, para que la hoja de «Nuevo registro» cuelgue del CONTENEDOR. Colgada del contenido
    /// raíz (`DetailContainerView`), SwiftUI la desmontaba y la volvía a montar sin cerrarse cuando un enlace cambiaba
    /// de pestaña con la app volviendo a primer plano, y el importe escrito se perdía (ticket
    /// `external-entry-panel-link-loses-the-typed-amount-intermittently`; molde de `swiftui-ds.md`).
    @State private var recordsViewModel = DetailContainerView.makeRecordsViewModel()

    var body: some View {
        NavigationStack {
            DetailContainerView(initialTab: navigation.selectedDetailTab, recordsViewModel: recordsViewModel)
                .navigationTitle(L10n.Statistics.title)
                .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $recordsViewModel.showNewTransaction) {
            NewTransactionView()
                .presentationDetents([.large])
                // «Editar» del aviso tras guardar abre el registro con la hoja de editar de Estadísticas (UX 2.2 · L2-5).
                .environment(\.savedRecordEditorOpener, recordsViewModel.savedRecordEditorOpener)
                .onDisappear {
                    UITestHooks.shared.traceLifecycle("formulario fuera abierto=\(recordsViewModel.showNewTransaction)")
                }
        }
    }
}
