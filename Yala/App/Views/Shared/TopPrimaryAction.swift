//
//  TopPrimaryAction.swift
//  Yala
//
//  El patrón del Panel, para todas las páginas principales (card kzhe, Jürgen 2026-10-24): la acción principal
//  («Nuevo …») es un botón ARRIBA, bajo la cabecera, y el botón flotante solo sale cuando el scroll se lleva ese
//  botón. Arriba el flotante sobra —la acción está a la vista y tapaba cifras—; abajo hace falta, para no subir del
//  todo a crear algo.
//
//  El Panel decide por el desplazamiento (umbrales 180/150 en `PanelView`) porque su fila de acciones está siempre
//  a la misma altura. Aquí cada página tiene la cabecera de un alto distinto (con o sin hero, con avisos), así que
//  decide el propio botón: `revealsFloatingActionWhenScrolledAway` mira si sigue a la vista dentro de su scroll.
//

import SwiftUI

/// La píldora de la acción principal: la misma que «Nuevo registro» en la fila del Panel (`PanelQuickActionsRow`),
/// relleno del acento con el texto encima. Con `isPrimary: false`, la de tarjeta de las acciones secundarias.
struct TopPrimaryActionPill: View {
    let title: String
    let systemImage: String
    var isPrimary: Bool = true
    let accessibilityIdentifier: String
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme

    /// 44 pt, el mínimo táctil de las HIG; con texto grande crece (`minHeight`).
    private static let pillHeight: CGFloat = 44

    var body: some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: systemImage)
                    .font(DS.Typography.label)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DS.Typography.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isPrimary ? AnyShapeStyle(theme.onAccent) : AnyShapeStyle(Color.primary))
            .padding(.horizontal, DS.Spacing.lg)
            .frame(minHeight: Self.pillHeight)
            .background {
                if isPrimary {
                    Capsule().fill(theme.accent)
                } else {
                    Capsule().fill(theme.card)
                }
            }
            // Dentro del label y tras el padding (regla de filas clicables de `swiftui-ds.md`).
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .shadow(
            color: DS.Shadow.small.color,
            radius: DS.Shadow.small.radius,
            x: DS.Shadow.small.x,
            y: DS.Shadow.small.y
        )
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

/// Qué hace el flotante según la visibilidad del botón de arriba. Puro, para fijarlo en un test.
enum TopPrimaryActionRevealLogic {
    /// Fracción del botón que tiene que seguir a la vista para que cuente como visible. Con medio botón fuera ya
    /// no se lee como «la acción está aquí», y el flotante entra.
    static let visibilityThreshold: Double = 0.5

    /// El flotante sale cuando el botón de arriba ya no se ve, y solo entonces: con los dos a la vez la acción
    /// principal saldría dos veces en la misma pantalla.
    static func showsFloating(topActionVisible: Bool) -> Bool {
        !topActionVisible
    }

    /// Lo que pasa al flotante cuando cambia la visibilidad del botón de arriba; `nil` es no tocarlo. Dos avisos del
    /// sistema no hablan del scroll y se ignoran (cards 2m2r y hsqm, medido en vídeo el 2026-11-02, iOS 27.2):
    ///
    /// 1. **Con la página oculta.** Las páginas de pestaña siguen montadas; al ocultarse, el botón cuenta como «no
    ///    visible» por la pestaña. Ese aviso encendía el flotante y al volver se veía 2-3 fotogramas antes de que llegara
    ///    el de «visible» (Grupos, Presupuestos, Pagos y Estadísticas). Ignorado, el flotante se queda como estaba al
    ///    salir: apagado arriba, encendido con la lista bajada.
    /// 2. **El primer «no visible», antes de haber visto nunca el botón.** Al montarse la página, el primer aviso llega
    ///    antes de que el scroll tenga su sitio y dice «no visible» con el botón en pantalla. Encendía el flotante con
    ///    animación, y esa transacción animaba también el reajuste del scroll: la primera entrada a Grupos o Planificación
    ///    pintaba el contenido 44 pt más abajo y lo subía en ~0,2 s, con el «+» asomando. Desde que el botón se ve una
    ///    vez, un «no visible» es el scroll de verdad. Ese primero no se tira: espera `firstHiddenConfirmation`
    ///    (`awaitsConfirmation`), porque con el iPhone girado y texto grande el botón puede nacer fuera de pantalla.
    static func floatingAfterVisibilityChange(
        topActionVisible: Bool, isPageShown: Bool, hasSeenTopAction: Bool
    ) -> Bool? {
        guard isPageShown else { return nil }
        guard topActionVisible || hasSeenTopAction else { return nil }
        return showsFloating(topActionVisible: topActionVisible)
    }

    /// El «no visible» que `floatingAfterVisibilityChange` deja en suspenso: el primero de una página a la vista, antes de
    /// haber visto el botón. Si en `firstHiddenConfirmation` nadie lo desmiente —el falso del montaje llega seguido de su
    /// «visible» en uno o dos fotogramas—, el botón nació fuera de pantalla y el flotante sale.
    static func awaitsConfirmation(topActionVisible: Bool, isPageShown: Bool, hasSeenTopAction: Bool) -> Bool {
        isPageShown && !topActionVisible && !hasSeenTopAction
    }

    /// Lo que espera un primer «no visible» antes de creérselo. El falso del montaje se desmiente en ~0,2 s (medido en
    /// vídeo el 2026-11-02); el doble deja margen sin que el «+» de un botón nacido fuera tarde en salir.
    static let firstHiddenConfirmation: Duration = .milliseconds(400)
}

extension EnvironmentValues {
    /// `false` en las páginas de pestaña que no son la elegida (las pone `MainTabView`). Fuera de la raíz, `true`.
    @Entry var isRootPageShown = true
}

extension View {
    /// Se cuelga del botón de arriba. Escribe en `showsFloating` si el flotante tiene que salir: `true` cuando el
    /// scroll se lleva el botón, `false` cuando vuelve. Fuera de un scroll no se llama nunca y el flotante no sale,
    /// que es lo correcto: el botón está siempre a la vista.
    func revealsFloatingActionWhenScrolledAway(_ showsFloating: Binding<Bool>) -> some View {
        modifier(TopPrimaryActionRevealModifier(showsFloating: showsFloating))
    }
}

private struct TopPrimaryActionRevealModifier: ViewModifier {
    @Binding var showsFloating: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isRootPageShown) private var isRootPageShown
    /// El botón de arriba ya se vio en pantalla desde que se montó la página (punto 2 de
    /// `TopPrimaryActionRevealLogic.floatingAfterVisibilityChange`).
    @State private var hasSeenTopAction = false
    /// El primer «no visible» en suspenso (`TopPrimaryActionRevealLogic.awaitsConfirmation`).
    @State private var firstHiddenConfirmation: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onScrollVisibilityChange(threshold: TopPrimaryActionRevealLogic.visibilityThreshold) { visible in
                apply(visible: visible)
            }
            // Sin reinicio en `onAppear` a propósito: las páginas de pestaña siguen montadas y conservan el scroll, así
            // que al volver con el botón fuera de vista el flotante tiene que seguir ahí.
            .onDisappear { firstHiddenConfirmation?.cancel() }
    }

    private func apply(visible: Bool) {
        let shows = TopPrimaryActionRevealLogic.floatingAfterVisibilityChange(
            topActionVisible: visible, isPageShown: isRootPageShown, hasSeenTopAction: hasSeenTopAction)
        let awaits = TopPrimaryActionRevealLogic.awaitsConfirmation(
            topActionVisible: visible, isPageShown: isRootPageShown, hasSeenTopAction: hasSeenTopAction)
        if visible && isRootPageShown { hasSeenTopAction = true }
        firstHiddenConfirmation?.cancel()
        firstHiddenConfirmation = awaits ? confirmFirstHidden() : nil
        guard let shows, shows != showsFloating else { return }
        dsWithAnimation(reduceMotion) { showsFloating = shows }
    }

    /// Nadie desmintió el primer «no visible»: el botón nació fuera de pantalla y el flotante sale.
    private func confirmFirstHidden() -> Task<Void, Never> {
        let showsFloating = $showsFloating
        let reduceMotion = reduceMotion
        return Task { @MainActor in
            do {
                try await Task.sleep(for: TopPrimaryActionRevealLogic.firstHiddenConfirmation)
            } catch {
                return  // Llegó otro aviso (o la página se fue): ese decide.
            }
            guard !showsFloating.wrappedValue else { return }
            dsWithAnimation(reduceMotion) { showsFloating.wrappedValue = true }
        }
    }
}
