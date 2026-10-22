//
//  GroupsConsentRetryBackoffLogic.swift
//  Yala
//
//  La escalera de reintentos del registro del consent de Grupos (C1). Pura: entra (intentos consumidos,
//  último intento, ahora) y sale «toca o no toca».
//
//  ## Por qué una escalera propia y no una primitiva compartida
//
//  MEDIDO al escribir el chip: **no existe ninguna primitiva reusable de backoff en este repo.** Hay tres
//  escaleras independientes y de forma distinta —`AttestRefreshBackoffLogic` (tabla fija),
//  `SyncCadencePolicy` (exponencial), `CloudSignOutFlowLogic` (presupuesto por tiempo)— y **ninguna racha
//  sobrevive a un kill del proceso** (la de attest es una propiedad almacenada). Generalizar una cuarta
//  primitiva desde aquí sería un refactor de tres subsistemas que este chip no pidió; lo que sí hace falta
//  es que ESTA racha sea durable, y por eso el contador vive en el payload del intent, como el tope por ID
//  del intent del bridge.
//
//  ## Por qué hay backoff pero NO hay tope de intentos
//
//  El intent del bridge lleva tope (3 por ID) porque un ID envenenado haría trabajo **y un `save()` de
//  SwiftData** en cada arranque, para siempre. Aquí no hay `save()`: es un request. Y caducar significaría
//  tirar la prueba de un consentimiento que el usuario dio de verdad — exactamente lo que el chip existe
//  para no volver a perder. ⇒ sin TTL y sin tope; lo que impide el bucle es esta escalera, que se estira
//  hasta 6 h y ahí se queda.
//
//  La escalera se recorre por INTENTOS CONSUMIDOS, no por tiempo transcurrido desde que se armó: un
//  arranque que no llegó a intentar (sin sesión, `sub` que no casa) no gasta ningún peldaño.
//

import Foundation

nonisolated enum GroupsConsentRetryBackoffLogic {

    /// Espera mínima antes del intento número N+1, indexada por intentos ya FALLIDOS. El primer reintento
    /// es inmediato a propósito: el caso dominante es «aceptó sin red y firmó/arrancó dos minutos después»,
    /// y hacerle esperar ahí solo alarga la ventana en que su consent no está registrado.
    static let delays: [TimeInterval] = [0, 60, 5 * 60, 30 * 60, 2 * 60 * 60, 6 * 60 * 60]

    /// El peldaño que aplica tras `attempts` fallos. Por encima de la tabla, el último (6 h) — la escalera
    /// se estira y NUNCA se rinde.
    static func delay(afterAttempts attempts: Int) -> TimeInterval {
        guard attempts > 0 else { return delays[0] }
        return delays[min(attempts, delays.count - 1)]
    }

    /// ¿Toca intentar ahora?
    ///
    /// - Parameters:
    ///   - attempts: intentos ya fallidos de este intent.
    ///   - lastAttemptAt: cuándo fue el último. `nil` = nunca se intentó ⇒ toca.
    ///   - now: inyectable (regla del repo: jamás `Date()` dentro de la lógica).
    static func shouldAttempt(attempts: Int, lastAttemptAt: Date?, now: Date = .now) -> Bool {
        guard let lastAttemptAt else { return true }
        // Un reloj que retrocede (cambio de zona, ajuste manual) dejaría `elapsed` negativo y congelaría el
        // reintento hasta que el reloj alcanzara al valor guardado. Intentar es la dirección segura.
        let elapsed = now.timeIntervalSince(lastAttemptAt)
        if elapsed < 0 { return true }
        return elapsed >= delay(afterAttempts: attempts)
    }
}
