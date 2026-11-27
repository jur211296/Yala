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
//  La media altura de la hoja personal es `estoLeiPartial` (encargo del 2026-11-23): la `.medium` del sistema, salvo cuando
//  no le cabe un registro con su nota y «Guardar», como en el iPhone SE. La foto de Grupos sigue con `.medium`.
//

import SwiftUI
import UIKit

enum ImageEntrySheetHeightLogic {
    /// Los detents de la hoja: con varios registros que revisar, solo grande; en lo demás, media altura primero.
    /// `partial` es la media altura que se ofrece: `.medium` en la foto de Grupos, `estoLeiPartial` en la personal.
    static func detents(
        showsSeveralToReview: Bool,
        dynamicTypeSize: DynamicTypeSize,
        partial: PresentationDetent = .medium
    ) -> Set<PresentationDetent> {
        guard !showsSeveralToReview else { return [.large] }
        let base = SelectorSheetSizing.mediumFirst.detents(dynamicTypeSize: dynamicTypeSize)
        guard base.contains(.medium) else { return base }
        return [partial, .large]
    }

    /// El fondo, con la misma regla que los selectores: el glass del sistema a media altura y `.subtle` cuando se ve
    /// grande (porque se estiró, porque la ventana lo fuerza o porque no hay media altura que ofrecer).
    ///
    /// `sheetTop` es dónde está de verdad el borde de arriba de la hoja, en la ventana. Con varios leídos solo se ofrece
    /// grande, pero si la hoja no llega a subir se queda a media altura: Jürgen la vio así, con fondo sólido, el
    /// 25-nov-2026 en su iPhone. Se ve a media altura ⇒ glass, diga lo que diga el detent.
    static func background(
        detents: Set<PresentationDetent>,
        selectedDetent: PresentationDetent,
        usesLargeSheets: Bool,
        sheetTop: CGFloat? = nil
    ) -> YalaBackgroundVariant {
        if !usesLargeSheets, let sheetTop, sheetTop > largeSheetTopMax { return .transparent }
        guard detents.contains(where: { $0 != .large }) else { return .subtle }
        return usesLargeSheets || selectedDetent == .large ? .subtle : .transparent
    }

    /// Por debajo de esto, el borde de arriba de la hoja está pegado a la barra de estado: es la hoja grande. La media
    /// altura empieza mucho más abajo (en el iPhone 14, ~370 pt; la grande, ~55 pt).
    static let largeSheetTopMax: CGFloat = 120

    /// La hoja se ve grande: su borde de arriba, medido, está pegado a la barra de estado. Sin medida aún, no.
    static func isLarge(sheetTop: CGFloat?) -> Bool {
        guard let sheetTop else { return false }
        return sheetTop <= largeSheetTopMax
    }

    /// Lo leído se pinta «en grande» (fondo de card del Panel y deslizar): con la hoja vista grande, o cuando la ventana
    /// fuerza las hojas grandes.
    static func showsLargePresentation(sheetTop: CGFloat?, usesLargeSheets: Bool) -> Bool {
        usesLargeSheets || isLarge(sheetTop: sheetTop)
    }

    // MARK: - Media altura de «Esto leí» (encargo del 2026-11-23)

    /// La media altura de la hoja personal de foto: la `.medium` de siempre salvo cuando no le cabe lo leído de un
    /// registro (cabecera, aire, tarjeta, nota de la Bandeja y «Guardar»). En un iPhone SE la `.medium` cortaba la fila
    /// de chips y la nota ya antes del aire sobre la tarjeta (medido en el simulador, 2026-11-23).
    static let estoLeiPartial = PresentationDetent.custom(EstoLeiPartialDetent.self)

    /// Lo que mide «Esto leí» con un registro, del borde de arriba de la hoja al de abajo, con «Guardar» y su margen.
    /// Medido en el simulador con el texto de siempre: en el iPhone SE la nota de la Bandeja va en dos líneas y con 450 pt
    /// la segunda quedaba cortada. Los tamaños más grandes suman lo que crecen sus líneas.
    static func estoLeiContentHeight(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium, .large: return 470
        case .xLarge: return 495
        case .xxLarge: return 520
        default: return 550
        }
    }

    /// Lo que mide la `.medium` del sistema respecto al alto máximo de la hoja: en el iPhone 17 Pro el máximo es 778 pt y la
    /// `.medium` medía 436 (medido con una sonda y en la captura, 2026-11-23). Una `CustomPresentationDetent` no puede
    /// leerla, y quedarse corto haría la hoja más baja que antes en los iPhone grandes.
    static let systemMediumFraction: CGFloat = 0.56

    /// La `.medium` del sistema (`systemMedium`) o, si no alcanza, lo que mide el contenido; nunca más que la hoja entera.
    static func estoLeiPartialHeight(
        maxHeight: CGFloat,
        systemMedium: CGFloat,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        min(maxHeight, max(systemMedium, estoLeiContentHeight(dynamicTypeSize: dynamicTypeSize)))
    }
}

/// La media altura de «Esto leí» (`ImageEntrySheetHeightLogic.estoLeiPartial`).
struct EstoLeiPartialDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        ImageEntrySheetHeightLogic.estoLeiPartialHeight(
            maxHeight: context.maxDetentValue,
            systemMedium: context.maxDetentValue * ImageEntrySheetHeightLogic.systemMediumFraction,
            dynamicTypeSize: context.dynamicTypeSize
        )
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
