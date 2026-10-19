//
//  UITestRouterNoticeStage.swift
//  Yala
//
//  Seam de XCUITest para pedir un aviso de la app con Yala ya delante. Sus productores reales no se pueden disparar a
//  voluntad en el simulador (la prueba que caduca, la cuenta de iCloud que cambia, la oferta tras el onboarding), y los
//  launch args existentes los encolan en el ARRANQUE, antes de que el test pueda abrir un formulario. El test abre
//  `<scheme>://uitest-notice?kind=<trial-offer|trial-expired|pro-ended|icloud-mismatch>` y este seam hace solo lo que haría el
//  productor: `RouterEntryGate.shared.submit(_:)`. Lo que se prueba —qué consumidor lo drena y cuándo— es el camino
//  real (ticket `invite-and-app-notices-present-over-other-tab-sheets`).
//  Fuera de `-uitest` no hace nada, y en release no existe.
//

#if DEBUG
import Foundation

enum UITestRouterNoticeStage {

    /// El aviso que pide `url`, o `nil` si no trae un `kind` conocido.
    static func notice(for url: URL) -> RouterIntent? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        switch items.first(where: { $0.name == "kind" })?.value {
        case "trial-offer": return .presentTrialOffer
        case "trial-expired": return .presentTrialExpired
        // La hoja de fin de Pro (UX 2.2 · L17-6): su productor exige un downgrade de verdad, que el simulador no da.
        case "pro-ended": return .presentDowngradeResolution
        case "icloud-mismatch": return .iCloudMismatch
        default: return nil
        }
    }

    /// Bajo `-uitest`, encola el aviso que pide `url` por la puerta de siempre.
    @MainActor
    static func submitIfRequested(by url: URL) {
        guard UITestHooks.isActive, let intent = notice(for: url) else { return }
        // La hoja de fin de Pro exige que Pro se haya acabado de verdad (`justDowngraded`): el seam crea esa
        // precondición, no la salta. `-uitest-reset` la borra en el arranque siguiente.
        if case .presentDowngradeResolution = intent { StoreKitManager.shared.wasProUser = true }
        print("UITestRouterNoticeStage: submit \(intent.id)")
        RouterEntryGate.shared.submit(intent)
    }
}
#endif
