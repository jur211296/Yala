//
//  TabBarArrivesExpandedModifier.swift
//  Yala
//
//  La barra de pestañas se encoge al desplazarse hacia abajo (`.onScrollDown`) y ese estado es de la barra, no de la
//  pestaña: si Más estaba desplazado cuando una de sus tarjetas lleva a Registros, Registros llegaba con la barra
//  encogida aunque su lista estuviera arriba del todo, y el botón redondo que queda caía sobre los iconos de las filas
//  (auditoría UX 2.2, L8-2, opción B). Al cambiar de pestaña la barra se despliega y, enseguida, vuelve a encogerse
//  solo al desplazarse, como en el resto de pestañas.
//

import SwiftUI

struct TabBarArrivesExpandedModifier: ViewModifier {
    let selection: AppTab

    @State private var behavior: TabBarMinimizeBehavior = .onScrollDown
    @State private var restoreTask: Task<Void, Never>?

    /// Lo que dura la barra fija antes de volver a `.onScrollDown`: lo justo para que la pestaña nueva pinte su
    /// primer fotograma con la barra desplegada.
    static let holdExpanded: Duration = .milliseconds(400)

    func body(content: Content) -> some View {
        content
            .tabBarMinimizeBehavior(behavior)
            .onChange(of: selection) { _, _ in expand() }
            .onDisappear { restoreTask?.cancel() }
    }

    private func expand() {
        restoreTask?.cancel()
        behavior = .never
        restoreTask = Task { @MainActor in
            do {
                try await Task.sleep(for: Self.holdExpanded)
            } catch {
                return  // Otra selección la sustituye: esa vuelve a programar la vuelta.
            }
            behavior = .onScrollDown
        }
    }
}

extension View {
    /// Despliega la barra de pestañas cada vez que cambia la pestaña elegida (L8-2).
    func tabBarArrivesExpanded(selection: AppTab) -> some View {
        modifier(TabBarArrivesExpandedModifier(selection: selection))
    }
}
