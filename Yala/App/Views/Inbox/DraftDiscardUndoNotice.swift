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
    /// Un XCUITest puede alargarlo (`UITestHooks.undoNoticeSeconds`).
    static let visibleDuration: Duration = UITestHooks.undoNoticeSeconds.map { .milliseconds(Int($0 * 1000)) } ?? .seconds(5)

    /// Hueco libre bajo el aviso: por encima de la barra de pestañas flotante y de los botones de pie de una hoja.
    private static let tabBarClearance: CGFloat = 72

    /// Hueco libre bajo el aviso, por encima también de los botones flotantes de la página: Jürgen eligió el 2026-10-22
    /// que el aviso vaya más arriba que el «+», en todas las pantallas (ticket
    /// `saved-record-notice-covers-the-panel-plus-button`). Con 72 pt la franja caía sobre el «+» del Panel y su primer
    /// toque no llegaba. Cuenta la pila más alta, Yala IA encima del «+» (`FABStackView`); con poco alto los dos van en
    /// fila (UX 2.2 · L15-14) y basta uno. Medido en el iPhone 17 Pro: con 72 pt el aviso acaba casi en el borde de la
    /// barra, así que la pila entera (`fabStackClearance`, con su margen inferior y aire) va encima: 11 pt sobre Yala IA.
    static func bottomClearance(sceneHeight: CGFloat) -> CGFloat {
        let buttons = DS.Adaptive.isShortContainer(height: sceneHeight) ? 1 : 2
        return tabBarClearance + DS.Button.fabStackClearance(buttons: buttons)
    }

    private static var window: UIWindow?
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
        hide()
        guard let scene = targetScene() else { return }

        let host = UIHostingController(
            rootView: DraftDiscardUndoToast(
                message: message,
                systemImage: systemImage,
                undoTitle: undoTitle ?? L10n.Inbox.undoDiscard,
                noticeIdentifier: noticeIdentifier,
                undoIdentifier: undoIdentifier,
                secondaryTitle: onSecondary == nil ? nil : secondaryTitle,
                secondaryIdentifier: secondaryIdentifier,
                onSecondary: onSecondary.map { action in { action(); hide() } },
                onUndo: onUndo.map { action in { action(); hide() } }
            )
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

        let bounds = scene.effectiveGeometry.coordinateSpace.bounds
        let safeArea = scene.windows.first { $0.isKeyWindow }?.safeAreaInsets ?? .zero
        let size = host.sizeThatFits(in: CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(
            x: 0,
            y: bounds.height - safeArea.bottom - bottomClearance(sceneHeight: bounds.height) - size.height,
            width: bounds.width,
            height: size.height
        )
        // Por encima de la ventana de la app (y de sus hojas), por debajo de una alerta del sistema.
        window.windowLevel = .normal + 1
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
        hideTask?.cancel()
        hideTask = nil
        window?.isHidden = true
        window = nil
        activeUndo = nil
        UndoNoticeState.shared.isActive = false
        currentNoticeIdentifier = nil
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
