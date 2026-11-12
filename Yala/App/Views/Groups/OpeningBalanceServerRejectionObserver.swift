//
//  OpeningBalanceServerRejectionObserver.swift
//  Yala
//
//  Card 6n1o (2026-10-31) · el detalle del grupo recoge el rechazo del servidor a un saldo inicial
//  (`OpeningBalanceServerRejectionNotices`) y lo enseña con su aviso de errores.
//
//  Cuándo mira, y cuándo NO (review adversarial del 2026-10-31):
//  - al aparecer, cuando llega un motivo nuevo (`revision`) y al cerrarse una hoja sin otra detrás (el `onDismiss` de
//    `GroupDetailView`, rama final);
//  - nunca al bajar `activeSheet` a `nil` ni al cerrarse otro aviso: los dos pasan con la presentación de antes aún
//    desmontándose, y un `.alert` pedido ahí no sale y deja `showActionError` en `true` (`swiftui-ds.md`, presentaciones).
//  Con algo delante el motivo no se consume: espera al siguiente disparo.
//  Va en su propio modificador para no alargar la cadena del `body` de `GroupDetailView` (el compilador del CI tipa peor).
//

import SwiftUI

struct OpeningBalanceServerRejectionObserver: ViewModifier {
    let viewModel: GroupDetailViewModel
    @Environment(SceneNavigation.self) private var navigation

    func body(content: Content) -> some View {
        content
            .onAppear {
                Self.present(viewModel, windowID: navigation.id)
                #if DEBUG
                Self.injectUITestRejectionOnce(groupID: viewModel.group.cloudKitZoneID)
                #endif
            }
            .onChange(of: OpeningBalanceServerRejectionNotices.shared.revision) {
                Self.present(viewModel, windowID: navigation.id)
            }
    }

    /// El único camino al aviso: pregunta a UIKit si la ventana tiene algo delante.
    static func present(_ viewModel: GroupDetailViewModel, windowID: UUID) {
        viewModel.presentOpeningBalanceServerRejectionIfAny(
            windowIsPresenting: ModalPresentationProbe.isAnythingPresented(
                in: SceneRegistry.shared.windowScene(for: windowID)))
    }

    #if DEBUG
    /// Seam `-uitest-opening-balance-server-rejection`: una vez por arranque, en el primer grupo que se abre, y un
    /// momento DESPUÉS de abrirlo, como llega en producción (la subida contesta con el grupo ya en pantalla). Así el
    /// XCUITest recorre el disparo por `revision`, no el del `onAppear`.
    private static var injectedUITestRejection = false
    private static func injectUITestRejectionOnce(groupID: String) {
        guard !injectedUITestRejection,
              let reason = OpeningBalanceServerRejectionLogic.reason(forSlug: UITestHooks.openingBalanceServerRejectionSlug)
        else { return }
        injectedUITestRejection = true
        Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1.5))
            } catch {
                print("OpeningBalanceServerRejectionObserver: seam cancelado: \(error)")
                return
            }
            OpeningBalanceServerRejectionNotices.shared.record(groupID: groupID, reason: reason)
        }
    }
    #endif
}
