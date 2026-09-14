//
//  RemoteWipeSignalDecider.swift
//  Yala
//
//  Pure decision logic para `ContentView.handleRemoteWipeSignal`. Extraído del
//  ContentView para tests pure-logic (sin SwiftData, UI ni actor isolation).
//
//  Bug #6 (A4 v3.2): el iCloud KV-Store del Apple ID retiene timestamps de
//  instalaciones previas que sobreviven al uninstall. En cold launch fresh, el
//  signal de vaciado con `onboardingAlreadyDone=true` autopromovía
//  `hasCompletedOnboarding=true` saltándose el Welcome Hero/Chooser. El guard
//  `hasCompletedOnboarding` aquí evita ese path para devices sin estado local.
//
//  **EL EJE DE SESIÓN (2026-09-14, ticket `remote-wipe-signal-honored-by-any-session`).** Hasta hoy
//  este decisor miraba SOLO el estado del dispositivo —¿está a medio vaciarse?, ¿tiene onboarding?— y
//  nunca QUIÉN está usándolo. El paso 9 del rediseño de sesiones cerró el lado EMISOR de la señal
//  (`DestructiveScopeLogic.wipeSignalsAppleIDDevices`); el receptor era el que quedaba. Lo decide
//  ahora `wipeSignalObeyedByThisSession`, que es el mismo predicado por el otro extremo del canal.
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

    /// Decide cómo reaccionar a una señal de vaciado llegada por el iCloud KV del Apple ID.
    ///
    /// **Dos call-sites, y los dos importan.** `PreferenceSyncService.checkForRemoteWipeSignal` lo
    /// consulta al DETECTAR la señal, y solo con `shouldProcess` submitea el intent `.remoteWipe`;
    /// `ContentView.handleRemoteWipeSignal` lo vuelve a consultar al DRENARLO, con valores vivos, y solo
    /// entonces borra. La segunda evaluación no es redundante: entre el submit y el drenaje pueden pasar
    /// un onboarding entero y un cambio de sesión.
    ///
    /// **Pero solo puede CERRAR la puerta, nunca abrirla, y eso no es simétrico.** El detector consume la
    /// señal antes de preguntar (escribe `WipeKey.localWipe` incondicionalmente), así que un `false` en la
    /// DETECCIÓN la quema para siempre: `remoteWipe > localWipe` no vuelve a cumplirse y no hay intent que
    /// drenar. O sea que un eje transitoriamente equivocado en el punto de detección no se retrasa, se
    /// pierde — lo recoge el ticket `remote-wipe-signal-is-burned-even-when-the-session-ignores-it`.
    /// (El `Notification.Name.remoteWipeDetected` que este fichero citaba hasta hoy **no existe como
    /// canal**: cero `post`, cero observadores. El canal real es el intent.)
    ///
    /// Reglas, **en este orden**:
    /// 1. Si el device está mid-wipe local (`isWipingData=true`), ignorar el signal
    ///    sin marcar — es nuestro propio wipe en curso, no debemos reaccionar.
    /// 2. Si el device es fresh-install (`hasCompletedOnboarding=false`), ignorar
    ///    el signal y marcarlo como procesado para idempotencia. El KV-Store
    ///    sobrevive al uninstall y los timestamps del Apple ID no aplican a un
    ///    device sin estado local — el user pasará por el Hero/Chooser normal.
    /// 3. Si la SESIÓN de este dispositivo no obedece la señal del Apple ID
    ///    (`sessionObeysWipeSignal=false` — nube completa o solo grupos), ignorarla.
    /// 4. Caso normal (sesión privada, returning user con estado local): procesar el
    ///    signal para mantener este device en sync con los demás.
    ///
    /// **El orden de 2 y 3 no es indiferente, y ponerlo al revés reintroduce el bug #6.** La regla 2 es
    /// la única que MARCA los timestamps, y lo hace justo en los devices sin estado local. Si el eje de
    /// sesión cortara antes, un fresh-install con el KV contaminado saldría sin marcar y el signal se
    /// re-postearía en cada arranque hasta que el onboarding terminase — que es cuando el bug #6 hacía
    /// daño. El eje de sesión va DESPUÉS, sobre un device que ya tiene estado local.
    ///
    /// **La regla 3 no marca nada, y eso es correcto, no un olvido.** El único camino que llega hasta
    /// aquí en producción es `PreferenceSyncService.checkForRemoteWipeSignal`, que escribe
    /// `WipeKey.localWipe = remoteWipe` **incondicionalmente** antes de consultar este decisor (su
    /// comentario «Mark as processed so we don't react again»). O sea que la señal queda marcada en el
    /// sitio donde se DETECTA, no en el que decide, y `remoteWipe > localWipe` ya no se cumple en el
    /// arranque siguiente. Devolver `true` aquí no añadiría idempotencia: marcaría además el timestamp
    /// de ONBOARDING —lo que hace `markRemoteSignalsAsProcessed`— y con eso silenciaría el «Caso B»
    /// (`.remoteOnboardingCompleted`), que es un efecto que este caso no pide.
    ///
    /// `sessionObeysWipeSignal` **no tiene valor por defecto a propósito**: un default dejaría a un
    /// call-site futuro obedeciendo la señal sin haberse pronunciado, que es exactamente la forma del
    /// bug que este parámetro cierra. El compilador obliga a decidir.
    static func decide(
        hasCompletedOnboarding: Bool,
        isWipingData: Bool,
        hasRemoteWipeTimestamp: Bool,
        sessionObeysWipeSignal: Bool
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
        if !sessionObeysWipeSignal {
            return RemoteWipeSignalDecision(
                shouldProcess: false,
                shouldMarkSignalsAsProcessed: false
            )
        }
        return RemoteWipeSignalDecision(
            shouldProcess: true,
            shouldMarkSignalsAsProcessed: false
        )
    }
}
