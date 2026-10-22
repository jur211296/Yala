//
//  EntryReadinessLogic.swift
//  Yala
//
//  Pure-logic: ¿puede tratarse YA una entrada a la app (un enlace `yala://`, una acción del Centro de Control), o
//  tiene que esperar a que el arranque termine?
//
//  Algunas entradas DECIDEN algo al tratarse: la puerta Pro (`FeatureGateService.canAccess`), el consentimiento de IA
//  o el eje de la sesión. Antes de que `AppBootstrapper.bootstrap` llegue a `isInitialized`, esas lecturas no valen:
//  `StoreKitManager.isProUser` arranca en `false` y solo se carga en el paso 3. Una foto compartida con la app cerrada
//  llega por `onOpenURL` antes de eso: la puerta Pro la daría por no-Pro, **borraría la foto** y encolaría la hoja de
//  Yala Pro (inferido del código). Lo medido el 2026-10-10 es su gemelo del consentimiento: en XCUITest, el enlace
//  pre-arranque leyó el consentimiento antes de que existiera y pidió aceptarlo. Esas entradas se apartan y se
//  vuelven a tratar al terminar el arranque.
//
//  Las demás (`.navigate` a una pestaña) no deciden nada y siguen yendo por el aplazamiento del router
//  (`RouterEntryGate` → `DeferredIntentBuffer`), que ya las conserva entre arranques.
//
//  Ver `docs/entry-points.md` y el ticket `share-image-reading-does-not-always-start`.
//

import Foundation

enum EntryReadinessLogic {

    /// Hosts de `yala://` cuyo tratamiento lee estado que el arranque todavía no ha cargado.
    /// - `shared-image`, `image-entry`, `voice-entry`: puerta Pro y consentimiento de IA.
    /// - `new-transaction`: no decide nada, pero va con sus hermanos de widget y Siri para que el orden de llegada se
    ///   conserve (un «nuevo registro» no adelanta a una foto que llegó antes).
    /// - `activate-full`: lee `sessionState.isGroupsFocusedShell`, que el arranque refresca.
    static let hostsThatWaitForBootstrap: Set<String> = [
        "shared-image", "image-entry", "voice-entry", "new-transaction", "activate-full",
    ]

    /// `true` → apartar la URL y tratarla al terminar el arranque. `false` → tratarla ahora.
    static func waitsForBootstrap(host: String?, isInitialized: Bool) -> Bool {
        guard !isInitialized, let host else { return false }
        return hostsThatWaitForBootstrap.contains(host)
    }

    /// Una acción del Centro de Control se lee de una clave del App Group y se BORRA al tratarla. Antes del arranque
    /// no se toca: la clave se queda y la lee el arranque al terminar (o el siguiente `.active`).
    static func controlActionMayRun(isInitialized: Bool) -> Bool {
        isInitialized
    }
}
