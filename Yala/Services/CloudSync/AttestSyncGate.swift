//
//  AttestSyncGate.swift
//  Yala
//
//  Pure-logic gate (Modo Nube §f.5, E2E-S10) for App Attest failures on the SYNC path.
//
//  In cloud mode the App Attest token is OBLIGATORY on `/sync/push|pull` (C1 froze "attestation REAL,
//  no JWT-only branch") — so a device that can't attest can NEVER back up (a silent trap for a
//  born-cloud user whose only backend IS the cloud). This gate splits attest failures into:
//   - TRANSIENT → retry with backoff, no alarm, no state change (offline-first already queues deltas).
//   - TERMINAL  → explicit "this device can't sync safely" state + export as the safety net.
//
//  Plus the onboarding upfront gate: born-cloud only offered when attest is terminally SUPPORTED
//  (owner: block-upfront, mirroring Groups' `iCloudSyncService.isAccountAvailable`). Conectada desde el 2026-09-16:
//  la llama `WelcomeAccountChoiceLogic.visibleNewOptions` con `AppAttestClient.canObtainSessionToken`.
//
//  NO runtime wiring — the consumer (`CloudSyncRuntime.performCycle`) classifies each failure and, on `.terminal`,
//  fires the `cloudSyncBlockedByAttestUnavailable(platform)` canary and stops. **There is NO banner** (measured
//  2026-09-15: `SyncStatusBanner` is iCloud's); this line used to promise one, and a ticket inherited the claim. The
//  groups channel has its own terminal verdict, `GroupsAttestVerdictLogic`. Pure & `nonisolated`.
//
//  Since 2026-09-15 the same consumer also feeds the PHONE's attest streak with the failures that speak about attest
//  (`countsTowardAttestStreak`): that streak, not `.terminal`, is what lets a cloud sign-out offer to export and lose the
//  personal changes that can't be uploaded.
//

import DeviceCheck
import Foundation

enum AttestSyncGate {

    /// Default retry budget for a repeated `.unavailable` before it's deemed terminal (§f.5 "tras N").
    static let defaultMaxRetries = 3

    enum Classification: Equatable {
        /// Temporary (network / gateway / 5xx / re-register). Retry with backoff; no alarm.
        case transient
        /// Deterministic: the device can't attest. Explicit blocked state + export; NOT retried silently.
        case terminal
    }

    /// Classifies an `AppAttestError` seen on the sync path (§f.5).
    ///
    /// - `.network` → transient (offline-first queues the delta; the retry covers it).
    /// - `.server` → transient (includes gateway 5xx and typed upstream errors; §f.5 lists `.server`).
    /// - `.unknownKey` → transient: this triggers a re-register in `AppAttestClient`, not a
    ///   "device can't attest" verdict.
    /// - `.unavailable` → the terminal SIGNAL, but only once it PERSISTS: a one-off retries, a
    ///   repeated one (`retryCount >= maxRetries`) is a device that genuinely can't attest. In
    ///   release, `isSupported == false` surfaces as `.unavailable` on EVERY attempt → it converges
    ///   to terminal after `maxRetries`. Desde el 2026-09-16 ese teléfono ya no llega aquí por el chooser del alta:
    ///   `shouldOfferCloudOnly(isAttestSupported:)` no le ofrece la nube. **Sigue llegando** por las puertas que esa función
    ///   no cubre —las nombra su docblock, abajo— y quien eligió la nube antes de esa fecha.
    static func classify(
        error: AppAttestError,
        retryCount: Int,
        maxRetries: Int = defaultMaxRetries
    ) -> Classification {
        switch error {
        case .network, .server, .unknownKey:
            return .transient
        case .unavailable:
            return retryCount >= maxRetries ? .terminal : .transient
        }
    }

    /// El `error.type` con el que el gateway rechaza una atestación o una aserción (`gateway/src/attest/routes.ts`).
    static let attestRejectedType = "yala_attest_invalid"

    /// **¿Este fallo dice algo del ATTEST de este teléfono, y no de la red ni del servidor?** Lo que devuelve `true` cuenta
    /// en la racha del teléfono (`GroupsAttestStreakStore`) desde la puerta del motor personal
    /// (`CloudSyncRuntime.resolveAttest`, ticket `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`).
    ///
    /// El motor personal nunca manda una subida sin attest, así que no ve el 401 `yala_attest_required` con el que cuenta
    /// Grupos: ve el error con el que `AppAttestClient` no consiguió el token. Cuentan los que hablan del attest:
    ///  - `.unavailable`: este teléfono no tiene App Attest.
    ///  - `.unknownKey`: el gateway no reconoce la key de este teléfono.
    ///  - `.server("yala_attest_invalid")`: el gateway rechazó la atestación o la aserción.
    ///  - un error de DeviceCheck (`DCErrorDomain`): Apple no generó la key, la atestación o la aserción.
    ///
    /// **No cuentan** `.network`, los demás `.server` —un 5xx, `yala_bad_request`, un límite de peticiones, un `decode`— ni
    /// ningún otro error: sin red o con el gateway caído el veredicto no se acerca. **Dos que sí cuentan sin ser culpa del
    /// teléfono, medidos en la review del 2026-09-15**: un `DCError.serverUnavailable` (el servidor de Apple no atesta) y el
    /// `yala_attest_invalid` con que el gateway responde también cuando falla su escritura en D1
    /// (`attest-gateway-reports-a-storage-failure-as-an-invalid-attestation`). Esta función no decide qué fallo es PERMANENTE:
    /// lo decide el tiempo (24 h y 3 veces, `GroupsAttestVerdictLogic`), y un corte de unas horas no llega.
    static func countsTowardAttestStreak(_ error: any Error) -> Bool {
        if let attest = error as? AppAttestError {
            switch attest {
            case .unavailable, .unknownKey: return true
            case .server(let type): return type == attestRejectedType
            case .network: return false
            }
        }
        return (error as NSError).domain == DCErrorDomain
    }

    /// **La puerta del alta en la nube** (owner: bloquear por adelantado, 2026-07-06): «Tu cuenta en la nube» solo se
    /// ofrece a un teléfono que puede conseguir token. Un fallo pasajero no bloquea aquí, que para eso está el reintento:
    /// la entrada es la capacidad determinista, `AppAttestClient.canObtainSessionToken`.
    ///
    /// **Su llamador es `WelcomeAccountChoiceLogic.visibleNewOptions`** desde el 2026-09-16; hasta entonces no tuvo
    /// ninguno, y dos docblocks decían que sí (ticket `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`).
    /// Por ahí decide las cards de las tres puertas que comparten `WelcomeNewOptionsGate`: «Es mi primera vez», «Crear
    /// otra cuenta» y «Activar Yala completo». Sin la nube queda una sola card: «Es mi primera vez» y la activación hacen
    /// bypass a la rama privada, y «Crear otra cuenta» enseña el chooser con la privada sola.
    ///
    /// Y desde el mismo día cubre también las dos salidas al alta de la pantalla de entrar («Crear mi cuenta» tras «No
    /// encontramos una cuenta» y «Crear cuenta con…» del mismatch): las pinta solo `WelcomeNewOptionsGate.offersCloudSignUp`,
    /// que se deriva de esas cards (ticket `cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`).
    ///
    /// **No cubre** entrar con una cuenta que ya existe («Ya tengo una cuenta» y el faro) ni «Migrar a la nube» de Ajustes.
    /// Cuántos iPhone reales tienen `isSupported == false` no está medido.
    nonisolated static func shouldOfferCloudOnly(isAttestSupported: Bool) -> Bool {
        isAttestSupported
    }
}
