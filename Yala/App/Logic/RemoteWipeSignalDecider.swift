//
//  RemoteWipeSignalDecider.swift
//  Yala
//
//  Pure decision logic para `ContentView.handleRemoteWipeSignal`. Extraído del
//  ContentView para tests pure-logic (sin SwiftData, UI ni actor isolation).
//
//  Bug #6 (A4 v3.2): el iCloud KV-Store del Apple ID retiene timestamps de
//  instalaciones previas que sobreviven al uninstall. En cold launch fresh, el
//  signal `.remoteWipeDetected` con `onboardingAlreadyDone=true` autopromovía
//  `hasCompletedOnboarding=true` saltándose el Welcome Hero/Chooser. El guard
//  `hasCompletedOnboarding` aquí evita ese path para devices sin estado local.
//

import Foundation

struct RemoteWipeSignalDecision: Equatable {
    /// Si true, ContentView ejecuta `performLocalWipeForRemoteSync`.
    let shouldProcess: Bool
    /// Si true, ContentView marca los timestamps remotos como procesados localmente
    /// (idempotencia — evita re-procesar el mismo signal en próximos launches).
    let shouldMarkSignalsAsProcessed: Bool
}

enum RemoteWipeSignalDecider {

    /// Decide cómo reaccionar a un `.remoteWipeDetected` recibido en ContentView.
    ///
    /// Reglas:
    /// 1. Si el device está mid-wipe local (`isWipingData=true`), ignorar el signal
    ///    sin marcar — es nuestro propio wipe en curso, no debemos reaccionar.
    /// 2. Si el device es fresh-install (`hasCompletedOnboarding=false`), ignorar
    ///    el signal y marcarlo como procesado para idempotencia. El KV-Store
    ///    sobrevive al uninstall y los timestamps del Apple ID no aplican a un
    ///    device sin estado local — el user pasará por el Hero/Chooser normal.
    /// 3. Caso normal (returning user con estado local): procesar el signal
    ///    para mantener este device en sync con los demás.
    static func decide(
        hasCompletedOnboarding: Bool,
        isWipingData: Bool,
        hasRemoteWipeTimestamp: Bool
    ) -> RemoteWipeSignalDecision {
        if isWipingData {
            return RemoteWipeSignalDecision(
                shouldProcess: false,
                shouldMarkSignalsAsProcessed: false
            )
        }
        if !hasCompletedOnboarding {
            return RemoteWipeSignalDecision(
                shouldProcess: false,
                shouldMarkSignalsAsProcessed: hasRemoteWipeTimestamp
            )
        }
        return RemoteWipeSignalDecision(
            shouldProcess: true,
            shouldMarkSignalsAsProcessed: false
        )
    }
}
