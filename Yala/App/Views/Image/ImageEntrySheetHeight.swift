//
//  ImageEntrySheetHeight.swift
//  Yala
//
//  A qué altura va la hoja de la foto (decisión 80 de la revisión 2.3). Abre a media altura, como los selectores de
//  Nuevo registro (`SelectorSheetSizing.mediumFirst`), y el usuario la estira si quiere. Con varios registros leídos, a
//  media altura solo se veía uno (captura 43 de la revisión): ahí la hoja deja de ofrecer media altura y pasa a grande,
//  con la lista entera a la vista y desplazable dentro.
//
//  Cómo se agranda: ni cambiar por código la selección de los detents (medido el 2026-10-04, `swiftui-ds.md`) ni quitar la
//  media altura del juego (medido el 2026-11-12, iOS 27.2: la hoja se quedó a media altura con solo `.large` ofrecido)
//  la mueven. Lo que la mueve es pedírselo a la hoja de UIKit (`UISheetPresentationController.animateChanges`), a la
//  que se llega como en `SheetDismissAttemptModifier`. SwiftUI queda de acuerdo: ofrece solo `.large` y su selección
//  también es `.large`.
//

import SwiftUI
import UIKit

enum ImageEntrySheetHeightLogic {
    /// Los detents de la hoja: con varios registros que revisar, solo grande; en lo demás, media altura primero.
    static func detents(showsSeveralToReview: Bool, dynamicTypeSize: DynamicTypeSize) -> Set<PresentationDetent> {
        showsSeveralToReview ? [.large] : SelectorSheetSizing.mediumFirst.detents(dynamicTypeSize: dynamicTypeSize)
    }

    /// El fondo, con la misma regla que los selectores: el glass del sistema a media altura y `.subtle` cuando se ve
    /// grande (porque se estiró, porque la ventana lo fuerza o porque no hay media altura que ofrecer).
    static func background(
        detents: Set<PresentationDetent>,
        selectedDetent: PresentationDetent,
        usesLargeSheets: Bool
    ) -> YalaBackgroundVariant {
        guard detents.contains(.medium) else { return .subtle }
        return usesLargeSheets || selectedDetent == .large ? .subtle : .transparent
    }
}

extension View {
    /// Cuando `grow` pasa a `true`, la hoja que contiene esta vista sube a grande, animada.
    func growsSheetToLarge(when grow: Bool) -> some View {
        background(
            SheetGrowToLarge(grow: grow)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }
}

private struct SheetGrowToLarge: UIViewControllerRepresentable {
    let grow: Bool

    func makeUIViewController(context: Context) -> GrowController {
        GrowController()
    }

    func updateUIViewController(_ controller: GrowController, context: Context) {
        controller.update(grow: grow)
    }

    final class GrowController: UIViewController {
        private var grew = false

        func update(grow: Bool) {
            guard grow else {
                grew = false
                return
            }
            guard !grew else { return }
            // Una vuelta después: deja que SwiftUI pase antes a UIKit los detents nuevos.
            DispatchQueue.main.async { [weak self] in self?.growNow() }
        }

        private func growNow() {
            guard !grew, let sheet = sheetPresentationController() else { return }
            grew = true
            guard sheet.selectedDetentIdentifier != .large else { return }
            sheet.animateChanges { sheet.selectedDetentIdentifier = .large }
        }

        /// El controlador presentado como hoja es la raíz de esta jerarquía: se sube por los padres hasta ella.
        private func sheetPresentationController() -> UISheetPresentationController? {
            var root: UIViewController = self
            while let parent = root.parent { root = parent }
            guard root.presentingViewController != nil else { return nil }
            return root.sheetPresentationController
        }
    }
}
