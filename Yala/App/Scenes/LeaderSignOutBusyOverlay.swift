//
//  LeaderSignOutBusyOverlay.swift
//  Yala
//
//  La ventana líder deja de operar mientras OTRA ventana cierra la sesión (fase 4 del carril adaptativo).
//

import SwiftUI
import UIKit

/// Tapa la ventana líder ENTERA —sus hojas incluidas— mientras otra ventana cierra la sesión.
///
/// **Por qué una ventana de UIKit encima y no desmontar como en la seguidora.** La líder monta `ContentView`, el shell
/// de proceso: desmontarlo cortaría sus flujos y al volver repetiría su arranque. Y una capa de SwiftUI no basta: las
/// hojas del shell (Ajustes de sincronización, la activación de Yala completo, el aviso del espejo tardío) se presentan
/// por encima de cualquier capa (review adversarial, 2026-10-02). Una `UIWindow` de nivel alto en la MISMA escena
/// queda por encima de todo lo que esa ventana presente.
///
/// Lo demás ya lo cubre la matriz del shell: con el cierre en `.working` el blocker `signOutWorking` retiene el router,
/// los atajos de teclado y el soltar recibos. Con una sola ventana solo se enciende si la que lanzó el cierre ya no
/// existe (el sistema desconectó su escena en segundo plano): mientras dure `.working`, nadie opera.
struct LeaderSignOutBusyOverlay: ViewModifier {
    @Environment(SceneNavigation.self) private var navigation

    private var isBusy: Bool { SceneRegistry.shared.isBusyBySignOut(navigation.id) }

    func body(content: Content) -> some View {
        content
            .onChange(of: isBusy, initial: true) { _, busy in
                SceneBusyWindows.set(busy, for: navigation.id)
            }
            .onDisappear {
                SceneBusyWindows.set(false, for: navigation.id)
            }
    }
}

/// Las ventanas de UIKit que tapan una escena, por ventana de Yala.
@MainActor
enum SceneBusyWindows {
    private static var windows: [UUID: (window: UIWindow, previousKey: UIWindow?)] = [:]

    static func set(_ busy: Bool, for id: UUID) {
        if busy {
            guard windows[id] == nil, let scene = SceneRegistry.shared.windowScene(for: id) else { return }
            let previousKey = scene.keyWindow
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            let host = UIHostingController(rootView: WindowBusyView())
            host.view.backgroundColor = .systemBackground
            window.rootViewController = host
            // Key y no solo visible: con un teclado físico, un campo de texto de debajo seguiría recibiendo lo que se
            // escribe (y Return guardaría).
            window.makeKeyAndVisible()
            windows[id] = (window, previousKey)
        } else {
            guard let entry = windows.removeValue(forKey: id) else { return }
            entry.window.isHidden = true
            entry.previousKey?.makeKey()
        }
    }
}
