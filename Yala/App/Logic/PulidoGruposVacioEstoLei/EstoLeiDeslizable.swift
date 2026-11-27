//
//  EstoLeiDeslizable.swift
//  Yala
//
//  El deslizar de una tarjeta o fila de «Esto leí» en grande (encargo del 27-nov-2026). La tarjeta se mueve a la
//  izquierda con el dedo y detrás asoma su botón («Descartar» o «Eliminar»); un deslizamiento largo lo ejecuta sin
//  tocarlo, como en una lista del sistema. VoiceOver lo tiene como acción de la tarjeta.
//
//  El gesto es un reconocedor de UIKit que solo arranca si el dedo va más en horizontal que en vertical: un `DragGesture`
//  dentro del `ScrollView` de la hoja le quitaría el desplazamiento (`swiftui-ds.md`, `HorizontalSwipeGesture`).
//

import SwiftUI
import UIKit

extension EnvironmentValues {
    /// La hoja de la foto se ve grande: las tarjetas de lo leído llevan el fondo de card del Panel y se deslizan. Lo pone
    /// `ImageSelectionView`; fuera de ella (la voz), `false` y todo queda como estaba.
    @Entry var estoLeiEnGrande = false
    /// Deslizar una tarjeta o fila de lo leído: lo ejecuta la hoja, que sabe confirmar, avisar y cerrarse.
    @Entry var estoLeiAlDeslizar: ((InboxDraft, EstoLeiDeslizarLogic.Accion) -> Void)?
}

extension View {
    /// Hace deslizable la tarjeta o fila. Sin acción, o con `isEnabled` en `false`, la vista queda exactamente igual.
    /// `cornerRadius` recorta el botón de detrás a la forma de la tarjeta (0 en una fila dentro de un bloque ya recortado).
    func estoLeiDeslizable(
        _ accion: EstoLeiDeslizarLogic.Accion?,
        isEnabled: Bool,
        cornerRadius: CGFloat,
        onAccion: @escaping (EstoLeiDeslizarLogic.Accion) -> Void
    ) -> some View {
        modifier(EstoLeiDeslizableModifier(
            accion: isEnabled ? accion : nil, cornerRadius: cornerRadius, onAccion: onAccion))
    }
}

struct EstoLeiDeslizableModifier: ViewModifier {
    let accion: EstoLeiDeslizarLogic.Accion?
    let cornerRadius: CGFloat
    let onAccion: (EstoLeiDeslizarLogic.Accion) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @State private var offset: CGFloat = 0
    @State private var isOpen = false
    @State private var width: CGFloat = 0

    typealias Logic = EstoLeiDeslizarLogic

    /// UNA sola estructura, con la acción o sin ella: si apagar el deslizar quitara los modificadores, la tarjeta cambiaría de
    /// identidad y perdería su estado. Medido el 27-nov-2026: tocar la descripción sube el teclado, la hoja se ve grande y
    /// la tarjeta se rehacía sin el campo en edición (`XNativaHojaFotoUITests`).
    func body(content: Content) -> some View {
        content
            // Abierta, un toque en la tarjeta la cierra en vez de llegar a sus chips. Va ANTES del desplazamiento, para
            // que viaje con la tarjeta: colgada después cubría también el botón que asoma y se comía su toque.
            .overlay {
                if isOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { settle(open: false) }
                        .accessibilityHidden(true)
                }
            }
            .offset(x: offset)
            .background(alignment: .trailing) {
                if offset < 0, let accion {
                    actionButton(accion)
                        .frame(width: max(Logic.anchoBoton, -offset))
                        .frame(maxHeight: .infinity)
                }
            }
            // Recorta el botón a la forma de la tarjeta solo con el deslizar encendido; apagado, nada se recorta (el
            // contorno y la sombra de la tarjeta a media altura quedan como estaban).
            .mask {
                if accion == nil {
                    Rectangle().padding(-DS.Spacing.xxl)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .gesture(EstoLeiPanGesture(
                isEnabled: accion != nil,
                onChanged: { translation in
                    guard accion != nil else { return }
                    offset = Logic.desplazamiento(traslacion: translation, abierto: isOpen, ancho: width)
                },
                onEnded: { translation in
                    guard let accion else { return settle(open: false) }
                    switch Logic.alSoltar(traslacion: translation, abierto: isOpen, ancho: width) {
                    case .cerrar: settle(open: false)
                    case .abrir: settle(open: true)
                    case .ejecutar: run(accion)
                    }
                }
            ))
            // La tarjeta es un contenedor (`children: .contain`) y VoiceOver no llega a una acción colgada de él: la
            // alternativa es un botón propio, sin tamaño visible, al final de la tarjeta.
            .overlay(alignment: .bottomTrailing) {
                if let accion {
                    Button { onAccion(accion) } label: { Color.clear }
                        .buttonStyle(.plain)
                        .frame(width: 1, height: 1)
                        .allowsHitTesting(false)
                        .accessibilityLabel(title(accion))
                        .accessibilityIdentifier(
                            accion == .descartar ? "esto_lei_a11y_discard" : "esto_lei_a11y_delete")
                }
            }
            // Si el deslizar se apaga con la tarjeta abierta (la hoja vuelve a media altura), vuelve a su sitio.
            .onChange(of: accion == nil) { _, off in if off { settle(open: false) } }
    }

    private func actionButton(_ accion: Logic.Accion) -> some View {
        Button { run(accion) } label: {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: accion == .descartar ? "archivebox" : "trash")
                    .font(DS.Typography.headline)
                Text(title(accion))
                    .font(DS.Typography.labelSmall)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(accion == .descartar ? DS.Semantic.warningForeground : DS.Semantic.errorForeground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accion == .descartar ? "esto_lei_swipe_discard" : "esto_lei_swipe_delete")
    }

    private func title(_ accion: Logic.Accion) -> String {
        accion == .descartar ? L10n.Inbox.reject : L10n.Action.delete
    }

    private func run(_ accion: Logic.Accion) {
        settle(open: false)
        onAccion(accion)
    }

    private func settle(open: Bool) {
        isOpen = open
        let target: CGFloat = open ? -Logic.anchoBoton : 0
        if reduceMotion {
            offset = target
        } else {
            withAnimation(DS.Animation.selection) { offset = target }
        }
    }
}

/// Un arrastre horizontal que no se queda con el vertical: solo arranca si el dedo va más de lado que de arriba abajo, y
/// convive solo con el pan del `ScrollView` (como `HorizontalSwipeGesture`), pero avisa mientras se mueve.
struct EstoLeiPanGesture: UIGestureRecognizerRepresentable {
    /// Apagado, el reconocedor no arranca: no le quita nada a los chips ni al scroll.
    var isEnabled = true
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.isEnabled = isEnabled
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let x = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed: onChanged(x)
        case .ended: onEnded(x)
        case .cancelled, .failed: onEnded(0)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer.view is UIScrollView
        }
    }
}
