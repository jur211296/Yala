//
//  AnimacionesVisibles.swift
//  Yala
//
//  Lote 2 del plan de eficiencia (análisis de calentamiento en el iPhone 14, 26-nov-2026): una animación sin fin solo
//  corre mientras su página se ve y la app está activa. Medido ese día: el pulso de la gráfica de tendencia seguía
//  latiendo con el Panel montado detrás de otra pestaña, y obligaba a SwiftUI a repintar cada fotograma (35-38 % de un
//  núcleo con la app quieta; 0,3 % sin él). Las seis páginas de la raíz siguen montadas al cambiar de pestaña, así que
//  «está en pantalla» no lo dice el `onAppear`: lo dice `\.isRootPageShown`, junto con la fase de la escena.
//

import SwiftUI

/// La regla, pura: una animación sin fin corre solo si la vista la quiere, está montada, su página se ve y la escena
/// está activa.
enum AnimacionVisibleLogic {
    static func anima(quiere: Bool, montada: Bool, paginaVisible: Bool, fase: ScenePhase) -> Bool {
        quiere && montada && paginaVisible && fase == .active
    }
}

/// Lo que mira el modificador; un solo `onChange` para las tres entradas (el CI tipa mal varios seguidos).
private struct AnimacionVisibleClave: Equatable {
    let quiere: Bool
    let paginaVisible: Bool
    let fase: ScenePhase
}

/// Enciende y apaga `activa` según `AnimacionVisibleLogic`. La vista anima con
/// `.animation(activa ? <animación sin fin> : nil, value: activa)`: al apagarse, la animación nula deja la pieza en
/// reposo y corta la repetición. Apagar nunca se anima (con una animación sin fin, volver a `false` arrancaría otra).
private struct AnimacionVisibleModifier: ViewModifier {
    let quiere: Bool
    @Binding var activa: Bool
    @Environment(\.isRootPageShown) private var paginaVisible
    @Environment(\.scenePhase) private var fase
    @State private var montada = false

    func body(content: Content) -> some View {
        content
            .onAppear { montada = true; ajustar() }
            .onDisappear { montada = false; ajustar() }
            .onChange(of: AnimacionVisibleClave(quiere: quiere, paginaVisible: paginaVisible, fase: fase)) { ajustar() }
    }

    private func ajustar() {
        let debe = AnimacionVisibleLogic.anima(quiere: quiere, montada: montada, paginaVisible: paginaVisible, fase: fase)
        guard debe != activa else { return }
        if debe {
            activa = true
        } else {
            var quieta = Transaction()
            quieta.disablesAnimations = true
            withTransaction(quieta) { activa = false }
        }
    }
}

extension View {
    /// Toda animación `repeatForever` cuelga de aquí (lo fija `RepeatForeverConVisibilidadTests`): `activa` solo es
    /// `true` con la vista montada, su página a la vista (`\.isRootPageShown`) y la app activa. `quiere` suma la
    /// condición propia de la vista («Reducir movimiento», el menú abierto, la fase que anima).
    func animaSoloVisible(_ activa: Binding<Bool>, si quiere: Bool = true) -> some View {
        modifier(AnimacionVisibleModifier(quiere: quiere, activa: activa))
    }
}
