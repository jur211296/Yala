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
//  Y mientras una guía de lugar señala una pestaña de la barra, la barra va desplegada (observación del iPhone 14,
//  25-nov-2026: «Tus presupuestos viven en Más» apuntaba a una barra encogida, sin «Más» a la vista).
//

import SwiftUI

struct TabBarArrivesExpandedModifier: ViewModifier {
    let selection: AppTab

    /// La barra fija un momento tras cambiar de pestaña.
    @State private var arriving = false
    @State private var restoreTask: Task<Void, Never>?

    /// Lo que dura la barra fija antes de volver a `.onScrollDown`: lo justo para que la pestaña nueva pinte su
    /// primer fotograma con la barra desplegada.
    static let holdExpanded: Duration = .milliseconds(400)

    func body(content: Content) -> some View {
        // La guía se lee aquí y no en `ContentView`: así solo este modificador se repinta cuando cambia.
        let keepsExpanded = TabBarExpansionLogic.keepsExpanded(
            arriving: arriving, guidePointsAtTab: PlaceGuideCenter.shared.holdsTabBarExpanded)
        content
            .tabBarMinimizeBehavior(keepsExpanded ? .never : .onScrollDown)
            .onChange(of: selection) { _, _ in expand() }
            .onDisappear { restoreTask?.cancel() }
    }

    private func expand() {
        restoreTask?.cancel()
        arriving = true
        restoreTask = Task { @MainActor in
            do {
                try await Task.sleep(for: Self.holdExpanded)
            } catch {
                return  // Otra selección la sustituye: esa vuelve a programar la vuelta.
            }
            arriving = false
        }
    }
}

/// Cuándo la barra de pestañas no se encoge.
nonisolated enum TabBarExpansionLogic {
    /// Al llegar a una pestaña (un momento) y mientras una guía de lugar señala una pestaña de la barra («Tus
    /// presupuestos viven en Más», «Tus grupos, a un toque»): encogida, la pestaña señalada no se veía.
    static func keepsExpanded(arriving: Bool, guidePointsAtTab: Bool) -> Bool {
        arriving || guidePointsAtTab
    }
}

extension View {
    /// Despliega la barra de pestañas cada vez que cambia la pestaña elegida (L8-2) y mientras una guía de lugar
    /// señala una de sus pestañas.
    func tabBarArrivesExpanded(selection: AppTab) -> some View {
        modifier(TabBarArrivesExpandedModifier(selection: selection))
    }
}
