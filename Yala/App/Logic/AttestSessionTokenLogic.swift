//
//  AttestSessionTokenLogic.swift
//  Yala
//
//  Dos decisiones del token de sesión de App Attest que `AppAttestClient` no tenía, y que podían dejar «Activar la nube»
//  parada sin salida (ticket `cloud-activation-stalls-without-uploading-until-relaunch`, QA guiado del 2026-10-19):
//
//  1. **Cuánto se espera a un refresh en vuelo.** `currentSessionToken()` colapsa las llamadas en UNA tarea (single-flight)
//     y todos los llamadores esperan a esa tarea. Ninguna de sus esperas tiene techo propio: `DCAppAttestService`
//     (`attestKey`, `generateAssertion`) y `Transaction.currentEntitlements` no lo traen. Si la tarea no vuelve, todo el
//     que pida token espera para siempre, también la subida de la migración, que se queda con la barra al 55 % y
//     «Retomar» apagado hasta cerrar Yala. MEDIDO en producción: el iPhone que se quedó así no emitió ni un 401 de attest
//     ni una observación de la subida, así que el push nunca llegó a salir; INFERIDO: la espera colgada es esta.
//     ⇒ con el techo, quien espera recibe un error de red y la tarea colgada se abandona: el siguiente llamador empieza
//     otra. El precio: si la colgada vuelve a la vez que la nueva, pueden cruzarse dos assertions con la misma key, y el
//     gateway rechaza la de contador menor (un error más, con su backoff). Es mejor que esperar para siempre.
//
//  2. **Cuándo se olvida el token guardado.** El gateway rechaza con 401 `yala_attest_required` un token que ya no
//     verifica (el secreto rotó, o el reloj del teléfono va atrasado y el token caducó en el del servidor). El teléfono lo
//     seguía mandando hasta que caducaba en SU reloj (ticket `attest-session-token-rejected-by-the-gateway-stays-cached`).
//     ⇒ el cliente que recibe ese 401 lo dice, y se olvida el guardado **solo si es el mismo que viajó**: uno distinto ya
//     es más nuevo y tirarlo gastaría una assertion sin motivo.
//
//  Pura: el tiempo transcurrido entra como parámetro.
//

import Foundation

nonisolated enum AttestSessionTokenLogic {

    /// Lo más que se espera a UN refresh en vuelo. Un refresh sano tarda segundos; el peor legítimo es un registro con sus
    /// peticiones al gateway cerca del timeout de `URLSession` (60 s) más la atestación de Apple. 90 s deja pasar un
    /// registro lento y corta lo que no va a volver.
    static let refreshStallCeiling: Duration = .seconds(90)

    /// Cuánto le queda por esperar a un refresh que lleva `elapsed` en vuelo. `.zero` = ya venció: se abandona.
    static func remainingRefreshWait(elapsed: Duration) -> Duration {
        guard elapsed > .zero else { return refreshStallCeiling }
        let remaining = refreshStallCeiling - elapsed
        return remaining > .zero ? remaining : .zero
    }

    /// ¿Se olvida el token guardado tras un 401 `yala_attest_required`? Solo si es el que el gateway acaba de rechazar.
    static func discardsCachedToken(cached: String?, rejected: String?) -> Bool {
        guard let cached, let rejected, !rejected.isEmpty else { return false }
        return cached == rejected
    }
}
