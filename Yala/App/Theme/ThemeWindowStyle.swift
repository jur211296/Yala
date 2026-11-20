//
//  ThemeWindowStyle.swift
//  Yala
//
//  El claro u oscuro del tema elegido, puesto en la VENTANA y no solo en la raíz de SwiftUI.
//
//  Por qué (Jürgen, 19-nov-2026, build 2.3 (5)): al cambiar de Claro a Oscuro dentro de Ajustes › Temas, la hoja de
//  Ajustes se quedaba con el texto del modo anterior —gris oscuro sobre negro— hasta cerrarla y volver a abrirla.
//  `preferredColorScheme` en la raíz no alcanza a una hoja YA presentada: conserva el modo con que se abrió. Su fondo y
//  sus tarjetas sí cambiaban (colores fijos del tema que llegan por el entorno), pero el texto de Claro y Oscuro es
//  `Color.primary` / `.secondary`, que se resuelve con el modo de la hoja. Medido en el simulador (iOS 27.2).
//
//  `overrideUserInterfaceStyle` en la `UIWindow` sí llega a todo lo presentado en ella: UIKit propaga el cambio a cada
//  controlador de la cadena, abiertos incluidos. Por eso vale para todas las hojas, no solo Ajustes. Cada ventana de
//  Yala (iPad con varias) lleva su sonda y se ajusta a sí misma. Con «Sistema» se suelta (`.unspecified`) y manda iOS.
//

import SwiftUI
import UIKit

// MARK: - Lógica

enum ThemeWindowStyleLogic {
    /// El estilo de la ventana para la elección de tema: el claro u oscuro del tema, o el del sistema con «Sistema».
    static func style(for choice: AppTheme, resolved: YalaTheme) -> UIUserInterfaceStyle {
        guard choice != .system else { return .unspecified }
        return resolved.baseColorScheme == .dark ? .dark : .light
    }
}

// MARK: - Modificador

extension View {
    /// Pone el claro u oscuro del tema en la ventana que contiene esta vista, para que las hojas abiertas se repinten al
    /// cambiar de tema (ver la cabecera del fichero). Va en la raíz de cada ventana (`YalaApp.rootView`).
    func appliesThemeStyleToWindow(_ style: UIUserInterfaceStyle) -> some View {
        background(ThemeWindowStyleProbe(style: style).frame(width: 0, height: 0).accessibilityHidden(true))
    }
}

private struct ThemeWindowStyleProbe: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIView(context: Context) -> ThemeWindowStyleProbeView {
        let view = ThemeWindowStyleProbeView()
        view.style = style
        return view
    }

    func updateUIView(_ view: ThemeWindowStyleProbeView, context: Context) {
        view.style = style
    }
}

/// Vista vacía que aplica su estilo a la ventana en cuanto está en una, y cada vez que cambia. Al CAMBIAR, además, a cada
/// controlador presentado en esa ventana: SwiftUI fija el modo en la hoja al presentarla (medido: con solo la ventana, el
/// texto de Ajustes › Temas seguía a 36/255 sobre negro), así que la ventana sola no le llega.
final class ThemeWindowStyleProbeView: UIView {
    var style: UIUserInterfaceStyle = .unspecified {
        didSet {
            applyToWindow()
            if oldValue != style { applyToPresentedControllers() }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyToWindow()
    }

    private func applyToWindow() {
        guard let window, window.overrideUserInterfaceStyle != style else { return }
        window.overrideUserInterfaceStyle = style
    }

    /// Solo en un cambio de tema, no al montarse: una presentación que pide su propio modo (el Welcome, oscuro) se
    /// respeta mientras nadie cambie el tema, y el tema solo se cambia desde Ajustes.
    private func applyToPresentedControllers() {
        var presented = window?.rootViewController?.presentedViewController
        while let controller = presented {
            controller.overrideUserInterfaceStyle = style
            presented = controller.presentedViewController
        }
    }
}
