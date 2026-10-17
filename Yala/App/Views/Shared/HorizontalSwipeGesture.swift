//
//  HorizontalSwipeGesture.swift
//  Yala
//
//  Un deslizamiento horizontal que no se queda con el arrastre vertical.
//

import SwiftUI
import UIKit

/// Desliza a izquierda o derecha sobre contenido que vive dentro de un `ScrollView` vertical.
///
/// Un `DragGesture` de SwiftUI sobre ese contenido BLOQUEA el desplazamiento vertical, y también con
/// `.simultaneousGesture`: medido el 2026-10-16 en el plan de flujo de caja (iOS 27.0, simulador), la lista del
/// mes solo se movía arrastrando desde la tira de meses, y sin el gesto se movía bien. Este reconocedor de UIKit
/// solo EMPIEZA si el gesto arranca más horizontal que vertical; si no, falla y el arrastre es del `ScrollView`.
struct HorizontalSwipeGesture: UIGestureRecognizerRepresentable {
    /// Distancia horizontal mínima para contar como deslizamiento.
    var minimumDistance: CGFloat = 50
    /// `true` = hacia la izquierda (siguiente), `false` = hacia la derecha (anterior).
    let onSwipe: (_ towardsNext: Bool) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard recognizer.state == .ended else { return }
        let translation = recognizer.translation(in: recognizer.view)
        guard abs(translation.x) > minimumDistance,
              abs(translation.x) > abs(translation.y) * 1.5 else { return }
        onSwipe(translation.x < 0)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Solo un arranque horizontal. Un arrastre vertical hace fallar a este reconocedor y lo recibe el scroll.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        /// Convive SOLO con el pan del `ScrollView`. Con el resto no: simultáneo con todo, un deslizamiento sobre
        /// una fila cambiaba de mes y además abría la hoja de esa fila (medido en el simulador).
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer.view is UIScrollView
        }
    }
}
