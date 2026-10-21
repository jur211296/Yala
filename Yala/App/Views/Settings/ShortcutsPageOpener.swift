//
//  ShortcutsPageOpener.swift
//  Yala
//
//  Abre la página de Yala en Atajos —la que lista sus acciones— desde un botón con el estilo de Yala.
//
//  Por qué así (auditoría UX 2.2, lote 15, L15-4): la decisión es un botón RELLENO de la app, «Abrir mis atajos de
//  Yala». El enlace oficial de Apple (`ShortcutsLink`) lleva a esa página, pero solo con sus estilos. Medido el
//  2026-10-21 en iOS 27.0:
//  - no hay URL que lo haga: `shortcuts://` con `app-shortcuts`, `apps` o `bundleIdentifier`, en cinco formas, abre
//    siempre «Todos los atajos»;
//  - `ShortcutsUIButton` (el `UIButton` público que hay detrás) no tiene acciones ni destinos: responde a sus propios
//    reconocedores de gestos, así que `sendActions(for:)` no hace nada.
//  Lo que queda es poner ese botón encima del nuestro, del mismo tamaño y casi transparente: el dedo lo toca a él y se
//  ve el de Yala.
//

import AppIntents
import SwiftUI
import UIKit

struct ShortcutsPageButtonOverlay: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear
        let button = ShortcutsUIButton(style: .automatic)
        button.isAccessibilityElement = false
        button.accessibilityElementsHidden = true
        // Por debajo de 0,01 UIKit deja de entregarle toques.
        button.alpha = 0.02
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
