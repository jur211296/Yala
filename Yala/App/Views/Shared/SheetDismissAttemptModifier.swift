//
//  SheetDismissAttemptModifier.swift
//  Yala
//
//  Una hoja con cambios sin guardar no se cierra con el gesto: pregunta (auditoría UX 2.2, lote 7, L7-5).
//

import SwiftUI
import UIKit

extension View {
    /// Mientras `isActive`, el gesto de cerrar la hoja (arrastrar hacia abajo o tocar fuera, a media altura)
    /// no la cierra y llama a `onAttempt`, para que la vista pregunte «¿Descartar cambios?».
    ///
    /// SwiftUI solo sabe **bloquear** el gesto (`interactiveDismissDisabled`); el aviso de que alguien lo
    /// intentó llega por `UIAdaptivePresentationControllerDelegate.presentationControllerDidAttemptToDismiss`,
    /// que SwiftUI no expone. Sin el aviso, la hoja rebotaría sin decir por qué.
    func onSheetDismissAttempt(isActive: Bool, perform onAttempt: @escaping () -> Void) -> some View {
        modifier(SheetDismissAttemptModifier(isActive: isActive, onAttempt: onAttempt))
    }
}

private struct SheetDismissAttemptModifier: ViewModifier {
    let isActive: Bool
    let onAttempt: () -> Void

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(isActive)
            .background(
                DismissAttemptObserver(isActive: isActive, onAttempt: onAttempt)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            )
    }
}

private struct DismissAttemptObserver: UIViewControllerRepresentable {
    let isActive: Bool
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> ObserverController {
        ObserverController()
    }

    func updateUIViewController(_ controller: ObserverController, context: Context) {
        controller.isActive = isActive
        controller.onAttempt = onAttempt
        controller.install()
    }

    final class ObserverController: UIViewController {
        var isActive = false
        var onAttempt: () -> Void = {}
        private let proxy = DismissAttemptProxy()

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            install()
        }

        /// Se cuelga del controlador de la presentación de la hoja que contiene esta vista. SwiftUI ya es su
        /// delegado: el proxy le reenvía todo lo demás (detents, si se puede cerrar), y solo añade el aviso.
        func install() {
            proxy.onAttempt = { [weak self] in
                guard let self, self.isActive else { return }
                self.onAttempt()
            }
            guard let presentation = sheetPresentationController() else { return }
            if presentation.delegate === proxy { return }
            proxy.original = presentation.delegate
            presentation.delegate = proxy
        }

        /// El controlador presentado como hoja es la raíz de esta jerarquía: se sube por los padres hasta ella.
        private func sheetPresentationController() -> UIPresentationController? {
            var root: UIViewController = self
            while let parent = root.parent { root = parent }
            guard root.presentingViewController != nil else { return nil }
            return root.presentationController
        }
    }
}

/// Reenvía al delegado de SwiftUI todo lo que no sea el aviso de «intentó cerrar».
private final class DismissAttemptProxy: NSObject, UIAdaptivePresentationControllerDelegate {
    weak var original: UIAdaptivePresentationControllerDelegate?
    var onAttempt: () -> Void = {}

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        original?.presentationControllerDidAttemptToDismiss?(presentationController)
        onAttempt()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return original?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original, original.responds(to: aSelector) { return original }
        return super.forwardingTarget(for: aSelector)
    }
}
