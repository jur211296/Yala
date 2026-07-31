//
//  AttestRefreshBackoffLogic.swift
//  Yala
//
//  Cuánto esperar antes de volver a intentar el refresh del token de App Attest cuando el anterior
//  falló: la CACHÉ NEGATIVA que le faltaba al single-flight de `AppAttestClient`.
//
//  POR QUÉ EXISTE, medido en PRODUCCIÓN el 2026-07-31 (`wrangler tail --env production`, iPhone real):
//  con la atestación rota el device emitió ~17 `POST /v1/attest/challenge` en 3 segundos.
//  `currentSessionToken()` sí colapsaba las llamadas CONCURRENTES (`refreshTask`), pero en su `catch`
//  hacía `refreshTask = nil` SIN recordar que acababa de fallar ⇒ cada llamador que llegaba DESPUÉS
//  arrancaba un refresh nuevo contra un servicio que ya se sabía caído. Y llamadores hay varios e
//  INDEPENDIENTES —el proxy de IA, los tipos de cambio, el runtime de sync personal y los clients de
//  Grupos y de push—, cada uno con su propio reintento: en el tail se veían `/groups/pull` (×2),
//  `create_group` y `/push/register` pidiendo token mientras salía la ráfaga de challenges. El
//  single-flight resuelve la simultaneidad; nada resolvía la SUCESIÓN.
//
//  Y reintentar rápido no cura ninguna de las dos familias reales de fallo: la key muerta tras una
//  reinstalación (permanente hasta el re-registro — quien lo decide es `AttestKeyRecoveryLogic`) y la
//  red o el servicio de Apple caídos (de segundos a horas). El único efecto de las 17 era la tormenta.
//
//  Pura y con el reloj INYECTADO (`now:`) — regla del repo: nunca `Date()` dentro de la lógica.
//

import Foundation

nonisolated enum AttestRefreshBackoffLogic {

    /// El último fallo del refresh: cuándo fue y cuántos van SEGUIDOS (la racha se corta con un éxito).
    struct FailureState: Equatable {
        let at: Date
        let consecutiveCount: Int
    }

    enum Decision: Equatable {
        /// Fuera de la ventana (o sin fallo previo): intentar de verdad.
        case attempt
        /// Dentro de la ventana: no tocar la red. `retryAfter` es lo que queda para reabrirla.
        case suppress(retryAfter: TimeInterval)
    }

    /// Escalera de espera por racha: 1er fallo → 2 s, 2º → 5 s, 3º → 15 s, 4º → 30 s, 5º y siguientes → 60 s.
    ///
    /// Los dos extremos están elegidos, no son redondeos. **2 s** porque la tormenta medida es una RÁFAGA
    /// (17 peticiones en 3 s): con 2 s el mismo episodio se queda en 2 intentos, y a la vez un usuario que
    /// vuelve a tocar «crear grupo» unos segundos después SÍ obtiene un intento real en vez de un error
    /// instantáneo que parecería un bug. **60 s de tope** porque el fallo puede ser permanente (key muerta
    /// que el gateway no acepta, device sin App Attest) y ahí el ritmo sostenido tiene que ser bajo, pero
    /// sin que quien acaba de arreglar su wifi espere minutos: 1 intento/minuto ya es ~340× menos que lo
    /// medido.
    static let delays: [TimeInterval] = [2, 5, 15, 30, 60]

    /// Espera correspondiente al fallo n-ésimo consecutivo (`n` a partir de 1). Satura en el último escalón.
    static func delay(consecutiveFailures n: Int) -> TimeInterval {
        guard n > 0 else { return 0 }
        return delays[min(n, delays.count) - 1]
    }

    /// Estado tras anotar un fallo nuevo. `previous == nil` (primer fallo, o el anterior ya se limpió
    /// con un éxito) → racha 1.
    static func record(previous: FailureState?, now: Date) -> FailureState {
        FailureState(at: now, consecutiveCount: (previous?.consecutiveCount ?? 0) + 1)
    }

    /// ¿Toca intentar el refresh, o estamos dentro de la ventana del último fallo?
    ///
    /// Un `lastFailure` en el FUTURO significa que el reloj del device se movió hacia atrás: se intenta
    /// (mismo criterio que `RemoteFlagDecisionLogic.shouldRefresh`). Sin eso, un reloj mal puesto podría
    /// dejar el attest atascado durante el tamaño del error, que es justo el fallo silencioso y permanente
    /// que este subsistema ya sufrió una vez.
    static func decide(lastFailure: FailureState?, now: Date) -> Decision {
        guard let lastFailure else { return .attempt }
        if lastFailure.at > now { return .attempt }

        let wait = delay(consecutiveFailures: lastFailure.consecutiveCount)
        let elapsed = now.timeIntervalSince(lastFailure.at)
        guard elapsed < wait else { return .attempt }
        return .suppress(retryAfter: wait - elapsed)
    }
}
