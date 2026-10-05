//
//  SceneRoot.swift
//  Yala
//
//  La raíz de cada ventana: su navegación, su alta en el registro y a qué destino aterriza (fase 4 del carril
//  adaptativo).
//

import SwiftData
import SwiftUI
import UIKit

/// A dónde aterriza una ventana abierta con «Abrir en una ventana nueva». Es el valor de
/// `WindowGroup(for: WindowRoute.self)`: el sistema lo guarda con la ventana y lo devuelve al restaurarla, y si ya hay
/// una ventana con el mismo valor la trae al frente en vez de abrir otra.
enum WindowRoute: Codable, Hashable {
    /// Un grupo: la ventana abre Grupos con ese grupo, por las mismas puertas que un enlace (`pendingGroupID`).
    case group(id: String)
    /// Un registro: la ventana abre Registros con su detalle.
    case record(id: PersistentIdentifier)
}

/// La raíz de una ventana de Yala. Crea su `SceneNavigation`, la inyecta en el entorno, la da de alta en
/// `SceneRegistry` y la asocia a su escena de UIKit.
///
/// **Vive FUERA del remonte del swap de contenedor** (`YalaApp`): el registro y el orden de las ventanas sobreviven al
/// cambio de persona, y la líder sigue siendo la misma. La navegación sí se reinicia en el swap: lo pendiente
/// apuntaba a filas del store anterior.
struct SceneRoot<Content: View>: View {
    let route: WindowRoute?
    /// Generación del contenedor: cuando cambia, la navegación de la ventana vuelve a empezar.
    let containerGeneration: Int
    @ViewBuilder let content: () -> Content

    @State private var navigation = SceneNavigation()
    /// El destino se pone una vez: un `onAppear` repetido no debe reabrir lo que el usuario ya cerró.
    @State private var hasLanded = false

    var body: some View {
        content()
            .environment(navigation)
            .background {
                WindowSceneProbe(
                    onResolve: { scene in SceneRegistry.shared.attach(scene, to: navigation.id) },
                    onTouch: { SceneRegistry.shared.noteFocused(navigation.id) })
                .accessibilityHidden(true)
            }
            // **Sin `onDisappear` que dé de baja, a propósito.** La baja la da la desconexión de la escena
            // (`SceneRegistry`, con `pruneDisconnected` de red): un `onDisappear` espurio de la raíz quitaría la
            // ventana del registro y, si era la líder, desmontaría su `ContentView` con la app en marcha.
            .onAppear {
                SceneRegistry.shared.register(navigation)
                guard !hasLanded else { return }
                hasLanded = true
                land()
            }
            // Sin volver a aterrizar: el destino de la ventana (un grupo, un registro) era del store anterior, y
            // reponerlo dejaría un `pendingGroupID` que no existe callando el educativo de Grupos.
            .onChange(of: containerGeneration) { _, _ in
                navigation.resetForNewStore()
            }
    }

    /// Pone en la navegación el destino de la ventana. Lo consumen las pantallas al montarse.
    private func land() {
        guard let route else { return }
        switch route {
        case .group(let id):
            navigation.pendingGroupID = id
            navigation.selectMainTab(.groups)
        case .record(let id):
            navigation.pendingRecordID = id
            navigation.selectMainTab(.records)
        }
    }
}

extension SceneNavigation {
    /// Vuelve a la navegación de una ventana recién abierta. Lo usa el swap de contenedor: lo pendiente apuntaba al
    /// store anterior.
    func resetForNewStore() {
        selectedMainTab = .panel
        temporaryTab = nil
        selectedDetailTab = .insights
        selectedPlanningTab = .budgets
        selectedReportTab = .comparativa
        pendingGroupID = nil
        pendingRecordID = nil
        pendingNewGroupExpense = false
        pendingNewGroupForm = false
        pendingKeyboardPanelRequest = nil
        pendingSharedImageURL = nil
        pendingChatDraftPrefill = nil
        showNewTransactionFromChat = false
        isInboxSheetVisible = false
        isMainTabModalVisible = false
        shellModalBlocker = "splash"
    }
}

/// Resuelve la `UIWindowScene` de la ventana en la que está montado (SwiftUI no la expone; la necesita
/// `SceneRegistry` para saber cuándo se cierra la ventana y a cuál apunta una notificación) y avisa de cada toque en
/// ella.
///
/// **El toque, y no solo la ventana `key`.** Lo que un toque encola en el router se sella a la ventana que está
/// delante; si eso dependiera solo de `UIWindow.didBecomeKey`, un toque en la otra mitad de una pantalla dividida
/// podría sellarse a la ventana anterior (review adversarial, 2026-10-02: con escenas, «key» es por escena y su
/// notificación no está garantizada al cambiar de una a otra). El observador no reconoce nada: falla en el acto y no
/// retrasa ni cancela ningún toque.
private struct WindowSceneProbe: UIViewRepresentable {
    let onResolve: (UIWindowScene) -> Void
    let onTouch: () -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onResolve = onResolve
        view.onTouch = onTouch
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.onResolve = onResolve
        view.onTouch = onTouch
    }

    final class ProbeView: UIView {
        var onResolve: ((UIWindowScene) -> Void)?
        var onTouch: (() -> Void)?
        private weak var observedWindow: UIWindow?
        private lazy var touchObserver = WindowTouchObserver { [weak self] in self?.onTouch?() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, let scene = window.windowScene else { return }
            if observedWindow !== window {
                observedWindow?.removeGestureRecognizer(touchObserver)
                window.addGestureRecognizer(touchObserver)
                observedWindow = window
            }
            onResolve?(scene)
        }
    }
}

/// Avisa de que un toque empezó en la ventana y falla en el acto: no compite con ningún gesto ni retrasa toques.
private final class WindowTouchObserver: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private let onTouch: () -> Void

    init(onTouch: @escaping () -> Void) {
        self.onTouch = onTouch
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouch()
        state = .failed
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

/// Un enlace (`yala://`, invitación, callback de Google) que el sistema entrega a ESTA ventana. Antes de tratarlo, la
/// ventana se marca como la que está delante: todo lo que el enlace encole en el router queda sellado a ella, que es
/// donde el usuario lo espera.
struct WindowURLEntry: ViewModifier {
    let handle: (URL) -> Void
    @Environment(SceneNavigation.self) private var navigation

    func body(content: Content) -> some View {
        content.onOpenURL { url in
            SceneRegistry.shared.noteFocused(navigation.id)
            handle(url)
        }
    }
}
