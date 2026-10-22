//
//  ForceUpdateGate.swift
//  Yala
//
//  Superficie REACTIVA del forzado de actualización (min-version). Lee el umbral del snapshot de
//  remote-config (`GET /config`, `minSupportedBuild`) + el build local y publica `isUpdateRequired`
//  para que ContentView presente la pantalla bloqueante. La decisión pura vive en
//  `ForceUpdateDecisionLogic`; este tipo es el wiring @Observable.
//
//  DARK: el snapshot solo trae `minSupportedBuild` si el fetch de `/config` corre (prod: no, hasta
//  D9). Sin snapshot → `isUpdateRequired` = false (fail-open). Se recomputa en boot y foreground.
//

import Foundation

@MainActor @Observable
final class ForceUpdateGate {

    static let shared = ForceUpdateGate()

    private(set) var isUpdateRequired = false

    #if DEBUG
    /// Fijado por el seam de UITest: `recompute()` no-opa para que el forzado forzado no lo pise
    /// el snapshot vacío del boot/foreground.
    private var debugForced = false
    #endif

    init() {}

    /// Recomputa desde el snapshot de remote-config persistido + el build local. Fire-and-forget:
    /// el snapshot lo actualiza `RemoteConfigClient` async, así que la latencia real es ≤ próximo
    /// boot/foreground (aceptable para un forzado; y DARK en prod).
    func recompute() {
        #if DEBUG
        if debugForced { return }
        #endif
        let minSupportedBuild = CloudRemoteConfigStore.readSnapshot()?.minSupportedBuild
        recompute(minSupportedBuild: minSupportedBuild, currentBuild: Self.currentBuild)
    }

    /// Seam para tests: inyecta el umbral y el build sin tocar `.standard`/`Bundle`.
    func recompute(minSupportedBuild: Int?, currentBuild: Int?) {
        isUpdateRequired = ForceUpdateDecisionLogic.isUpdateRequired(
            currentBuild: currentBuild, minSupportedBuild: minSupportedBuild
        )
    }

    #if DEBUG
    /// UI tests: fuerza el estado bloqueante sin red ni snapshot (persistente ante `recompute()`).
    func _forceRequiredForUITest() {
        debugForced = true
        isUpdateRequired = true
    }
    #endif

    /// Número de build instalado (`CFBundleVersion`). Nil si faltara o no fuera entero → fail-open.
    static var currentBuild: Int? {
        guard let raw = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else { return nil }
        return Int(raw)
    }
}
