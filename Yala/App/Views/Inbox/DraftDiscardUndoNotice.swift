//
//  DraftDiscardUndoNotice.swift
//  Yala
//
//  Aviso «Lo moviste a Archivados · Deshacer» tras descartar un borrador desde su editor (UX 2.2 · L4-5,
//  variante 2, elegida por Jürgen el 2026-10-14).
//

import SwiftUI
import UIKit

/// Enseña unos segundos el aviso de «descartado», con un botón para deshacerlo.
///
/// **Por qué una ventana de UIKit y no una capa de SwiftUI.** El editor del borrador se abre desde cuatro sitios —la
/// Bandeja, la voz, la foto y un pago planificado— y al descartar se cierra; desde la voz se cierra también la hoja de
/// voz y la persona vuelve al Panel. Una capa colgada de cualquiera de esas pantallas o se desmonta con el editor o
/// queda debajo de la hoja que siga abierta. Una `UIWindow` de la misma escena queda por encima de todo lo que esa
/// ventana presente (el mismo recurso que `LeaderSignOutBusyOverlay`).
///
/// **La ventana solo ocupa la franja del aviso**, no la pantalla: fuera de ella los toques llegan a la app como
/// siempre. No se hace `key`: no le quita el teclado a nadie.
@MainActor
enum DraftDiscardUndoNotice {
    /// Lo que dura el aviso en pantalla. Cinco segundos: lo que da tiempo a leerlo y a tocar «Deshacer».
    static let visibleDuration: Duration = .seconds(5)

    /// Hueco libre bajo el aviso: por encima de la barra de pestañas flotante y de los botones de pie de una hoja.
    private static let bottomClearance: CGFloat = 72

    private static var window: UIWindow?
    private static var hideTask: Task<Void, Never>?

    /// Enseña el aviso en la ventana que está delante. `onUndo` corre al tocar «Deshacer» y el aviso se va.
    static func show(onUndo: @escaping @MainActor () -> Void) {
        hide()
        guard let scene = targetScene() else { return }

        let message = L10n.Inbox.movedToArchived
        let host = UIHostingController(
            rootView: DraftDiscardUndoToast(message: message) {
                onUndo()
                hide()
            }
        )
        host.view.backgroundColor = .clear

        let bounds = scene.effectiveGeometry.coordinateSpace.bounds
        let safeArea = scene.windows.first { $0.isKeyWindow }?.safeAreaInsets ?? .zero
        let size = host.sizeThatFits(in: CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(
            x: 0,
            y: bounds.height - safeArea.bottom - bottomClearance - size.height,
            width: bounds.width,
            height: size.height
        )
        // Por encima de la ventana de la app (y de sus hojas), por debajo de una alerta del sistema.
        window.windowLevel = .normal + 1
        window.rootViewController = host
        window.isHidden = false
        self.window = window

        UIAccessibility.post(notification: .announcement, argument: message)

        hideTask = Task {
            do {
                try await Task.sleep(for: visibleDuration)
            } catch {
                return
            }
            hide()
        }
    }

    static func hide() {
        hideTask?.cancel()
        hideTask = nil
        window?.isHidden = true
        window = nil
    }

    /// La escena de la ventana que está delante; si el registro aún no la conoce, la escena activa.
    private static func targetScene() -> UIWindowScene? {
        if let id = SceneRegistry.shared.routingTargetID, let scene = SceneRegistry.shared.windowScene(for: id) {
            return scene
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}

/// El aviso: el mensaje y «Deshacer», en una cápsula de cristal.
struct DraftDiscardUndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "archivebox")
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(message)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DS.Spacing.sm)
            Button(L10n.Inbox.undoDiscard, action: onUndo)
                .font(DS.Typography.label.weight(.semibold))
                .foregroundStyle(DS.Semantic.undoForeground)
                .frame(minHeight: 44)
                .accessibilityIdentifier("draft_discard_undo")
        }
        .padding(.leading, DS.Spacing.lg)
        .padding(.trailing, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("draft_discard_notice")
    }
}

#if DEBUG
#Preview("Aviso de descartado") {
    VStack {
        Spacer()
        DraftDiscardUndoToast(message: "Lo moviste a Archivados") {}
    }
}
#endif
