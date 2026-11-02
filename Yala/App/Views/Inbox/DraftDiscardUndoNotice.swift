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
/// **La ventana ocupa la escena entera, pero solo recoge los toques que caen en la cápsula** (`NoticePassthroughWindow`):
/// el resto llega a la app como siempre, también el «+» que asoma por encima del aviso. Hasta el 2026-10-31 la ventana
/// era una franja del alto que medía `sizeThatFits`, y la cápsula se pintaba ~36 pt por DEBAJO de ella: la franja
/// invisible tapaba el «+» entero y la mitad de abajo de «Deshacer» no recibía el toque. No se hace `key`: no le quita
/// el teclado a nadie.
@MainActor
enum DraftDiscardUndoNotice {
    /// Lo que dura el aviso en pantalla. Cinco segundos: lo que da tiempo a leerlo y a tocar «Deshacer».
    /// Un XCUITest puede alargarlo (`UITestHooks.undoNoticeSeconds`).
    static let visibleDuration: Duration = UITestHooks.undoNoticeSeconds.map { .milliseconds(Int($0 * 1000)) } ?? .seconds(5)

    /// Hueco libre bajo el aviso, sobre el borde inferior del área segura: justo encima de la barra de pestañas
    /// flotante, donde salen siempre estos avisos, en todas las pantallas. Es la altura a la que se veía hasta el 28-oct
    /// (medida en el iPhone 17 Pro: el aviso acaba 3 pt por encima de los botones de la barra).
    ///
    /// Del 28 al 31-oct subía además por encima de la pila de botones flotantes (Yala IA y «+») para no tapar el «+», y
    /// donde no hay botones quedaba a media pantalla. Jürgen lo devolvió abajo el 2026-10-31 (card d3qq): que pise la parte
    /// baja del «+» unos segundos no importa. Si se vuelve a subir, `UndoNoticePlacementUITests` se pone rojo.
    static let bottomClearance: CGFloat = 44

    private static var window: NoticePassthroughWindow?
    private static var hideTask: Task<Void, Never>?
    /// El «Deshacer» del aviso de un borrado en pantalla: ⌘Z lo pulsa mientras dura (UX 2.2 · L15-13).
    private static var activeUndo: (@MainActor () -> Void)?

    /// ⌘Z: pulsa el «Deshacer» del aviso en pantalla. `false` si no hay ninguno.
    @discardableResult
    static func performActiveUndo() -> Bool {
        guard let activeUndo else { return false }
        activeUndo()
        return true
    }

    /// El `noticeIdentifier` del aviso que está en pantalla, o `nil`. Quien vigila su propio aviso
    /// (`SavedRecordNotice`) lo mira para no retirar el de otro, y quien lo pidió lo retira sin llevarse
    /// el de otro (`hide(noticeIdentifier:)`).
    private(set) static var currentNoticeIdentifier: String?

    /// Enseña el aviso en la ventana que está delante. `onUndo` corre al tocar «Deshacer» y el aviso se va.
    static func show(onUndo: @escaping @MainActor () -> Void) {
        show(message: L10n.Inbox.movedToArchived, undoesDeletion: true, onUndo: onUndo)
    }

    /// El mismo aviso con otro texto e icono: Registros lo usa tras cambiar la subcategoría desde el menú de una fila
    /// (auditoría UX 2.2, L8-9), que también cierra su hoja al elegir.
    ///
    /// El formulario de registro lo usa tras guardar (UX 2.2 · L2-5): con «Editar» delante de «Deshacer»
    /// (`secondaryTitle`/`onSecondary`), y sin ningún botón para «Cambios guardados» (`onUndo` a `nil`).
    static func show(
        message: String,
        systemImage: String = "archivebox",
        undoTitle: String? = nil,
        noticeIdentifier: String = "draft_discard_notice",
        undoIdentifier: String = "draft_discard_undo",
        undoesDeletion: Bool = false,
        secondaryTitle: String? = nil,
        secondaryIdentifier: String = "draft_discard_secondary",
        onSecondary: (@MainActor () -> Void)? = nil,
        onUndo: (@MainActor () -> Void)?
    ) {
        // Uno nuevo sustituye al de antes en el acto: fundirlos dejaría dos textos uno encima de otro.
        hide(animated: false)
        guard let scene = targetScene() else { return }

        let window = NoticePassthroughWindow(windowScene: scene)
        let host = UIHostingController(
            rootView: DraftDiscardUndoNoticeLayer(hitArea: window.hitArea, toast: DraftDiscardUndoToast(
                message: message,
                systemImage: systemImage,
                undoTitle: undoTitle ?? L10n.Inbox.undoDiscard,
                noticeIdentifier: noticeIdentifier,
                undoIdentifier: undoIdentifier,
                secondaryTitle: onSecondary == nil ? nil : secondaryTitle,
                secondaryIdentifier: secondaryIdentifier,
                onSecondary: onSecondary.map { action in { action(); hide() } },
                onUndo: onUndo.map { action in { action(); hide() } }
            ))
        )
        host.view.backgroundColor = .clear
        // ⌘Z deshace el último BORRADO mientras dura su aviso (UX 2.2 · L15-13). Los avisos que no deshacen un borrado
        // (saltar una fecha, cambiar la subcategoría, «Ver» tras guardar) siguen con su botón y nada más.
        if undoesDeletion, let onUndo {
            activeUndo = {
                onUndo()
                hide()
            }
            UndoNoticeState.shared.isActive = true
        }

        // Por encima de la ventana de la app (y de sus hojas), por debajo de una alerta del sistema.
        window.windowLevel = .normal + 1
        // El tema claro u oscuro de Yala, no el del sistema: la app lo elige con `preferredColorScheme` solo en su ventana,
        // y esta, a pantalla completa y encima, es la que decide el color de la barra de estado mientras dura el aviso.
        if let appStyle = scene.keyWindow?.traitCollection.userInterfaceStyle {
            window.overrideUserInterfaceStyle = appStyle
        }
        window.rootViewController = host
        window.isHidden = false
        self.window = window
        currentNoticeIdentifier = noticeIdentifier

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
        hide(animated: true)
    }

    private static func hide(animated: Bool) {
        hideTask?.cancel()
        hideTask = nil
        if let window {
            if animated {
                retire(window)
            } else {
                window.isHidden = true
            }
        }
        window = nil
        activeUndo = nil
        UndoNoticeState.shared.isActive = false
        currentNoticeIdentifier = nil
    }

    /// La salida del aviso (card C3): se funde, y desde el primer instante ni se lee ni recoge toques, así que para la
    /// app y para un XCUITest ya no está. Con Reducir movimiento, se va en seco. La ventana se esconde al terminar; la
    /// retiene el propio cierre de la animación.
    private static func retire(_ leaving: NoticePassthroughWindow) {
        leaving.hitArea.frame = .zero
        leaving.accessibilityElementsHidden = true
        guard !UIAccessibility.isReduceMotionEnabled, let view = leaving.rootViewController?.view else {
            leaving.isHidden = true
            return
        }
        view.accessibilityElementsHidden = true
        UIView.animate(
            withDuration: DS.Animation.normal,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
            view.alpha = 0
        } completion: { _ in
            leaving.isHidden = true
        }
    }

    /// Retira el aviso solo si el que se ve es ese: el chat lo hace al cerrarse (UX 2.2 · L14-7), y en el iPad, con el
    /// chat en columna, el aviso de delante puede ser otro (el de Registros, el de un pago) que no le toca quitar.
    static func hide(noticeIdentifier: String) {
        guard currentNoticeIdentifier == noticeIdentifier else { return }
        hide()
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

/// La ventana del aviso: ocupa la escena (y la sigue al girar o redimensionar), pero solo se queda los toques que caen
/// dentro de la cápsula. Fuera de ella devuelve `nil` y el toque sigue a la ventana de la app.
@MainActor
final class NoticePassthroughWindow: UIWindow {
    /// Dónde quedó la cápsula; la vista la apunta al medirse. Va en una caja aparte y no en la ventana para que la vista
    /// no retenga a la ventana que la retiene a ella.
    let hitArea = NoticeHitArea()

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard hitArea.frame.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// Marco de la cápsula del aviso en coordenadas de su ventana.
@MainActor
final class NoticeHitArea {
    var frame: CGRect = .zero
}

/// Coloca el aviso abajo, sobre el área segura, y le cuenta a su ventana dónde quedó para recoger solo esos toques.
struct DraftDiscardUndoNoticeLayer: View {
    let hitArea: NoticeHitArea
    let toast: DraftDiscardUndoToast

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// La entrada (card C3): el aviso se funde en su sitio. Va en su propia ventana, fuera de la `TabView`, así que aquí
    /// `withAnimation` sí anima. Sin desplazamiento a propósito: moverlo cambiaría su marco mientras entra, y
    /// `UndoNoticePlacementUITests` mide ese marco en cuanto aparece. Con Reducir movimiento sale ya pintado.
    @State private var hasEntered = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            toast
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                    hitArea.frame = frame
                }
                .opacity(hasEntered || reduceMotion ? 1 : 0)
                .padding(.bottom, DraftDiscardUndoNotice.bottomClearance)
        }
        // El teclado no lo sube: hasta ahora el aviso no se movía con él.
        .ignoresSafeArea(.keyboard)
        .onAppear {
            dsWithAnimation(reduceMotion, DS.Animation.appear) { hasEntered = true }
        }
    }
}

/// ¿Hay en pantalla el aviso de un borrado con «Deshacer»? Observable para que el atajo ⌘Z se encienda solo mientras dura
/// (`RootCommandActions.canUndoDeletion`).
@MainActor
@Observable
final class UndoNoticeState {
    static let shared = UndoNoticeState()
    var isActive = false
}

/// El aviso: el mensaje y «Deshacer», en una cápsula de cristal.
struct DraftDiscardUndoToast: View {
    let message: String
    var systemImage: String = "archivebox"
    var undoTitle: String = L10n.Inbox.undoDiscard
    var noticeIdentifier: String = "draft_discard_notice"
    var undoIdentifier: String = "draft_discard_undo"
    /// Un segundo botón delante de «Deshacer» («Editar» tras guardar un registro).
    var secondaryTitle: String? = nil
    var secondaryIdentifier: String = "draft_discard_secondary"
    var onSecondary: (() -> Void)? = nil
    /// `nil`: el aviso no lleva «Deshacer» (solo informa).
    let onUndo: (() -> Void)?

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: systemImage)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(message)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DS.Spacing.sm)
            if let secondaryTitle, let onSecondary {
                Button(secondaryTitle, action: onSecondary)
                    .font(DS.Typography.label.weight(.semibold))
                    .foregroundStyle(DS.Semantic.undoForeground)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier(secondaryIdentifier)
            }
            if let onUndo {
                Button(undoTitle, action: onUndo)
                    .font(DS.Typography.label.weight(.semibold))
                    .foregroundStyle(DS.Semantic.undoForeground)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier(undoIdentifier)
            }
        }
        .padding(.leading, DS.Spacing.lg)
        .padding(.trailing, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(noticeIdentifier)
    }
}

#if DEBUG
#Preview("Aviso de descartado") {
    VStack {
        Spacer()
        DraftDiscardUndoToast(message: "Lo moviste a Archivados", onUndo: {})
    }
}
#endif
