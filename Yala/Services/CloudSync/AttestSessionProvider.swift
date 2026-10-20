//
//  AttestSessionProvider.swift
//  Yala
//
//  El token de sesión de App Attest que los clients del gateway inyectan en su `attestProvider` para
//  poblar el header `X-Yala-Attest-Session`. Una sola definición para TODOS los canales (Grupos, push,
//  borrado de cuenta, revoke de SIWA).
//
//  POR QUÉ ESTE FICHERO EXISTE, y no es cosmética: esto vivía anidado en
//  `AccountDeletionService.Dependencies.liveAttest`. Quien cableaba un client de Grupos buscaba
//  «attest», no «borrado de cuenta», así que no lo encontraba: SEIS construcciones nacieron con el
//  default `{ nil }` de su init y el canal de Grupos entero salió a producción sin el header. El
//  2026-07-31, con `ENFORCE = "enforce"`, crear un grupo devolvía 401 `yala_attest_required`. La
//  lección durable está en `.claude/rules/gateway-attest.md`; esta es su mitad de código.
//
//  POR QUÉ CONVIVE CON `LiveCloudSessionProvider.attestToken()` (`Yala/Services/CloudSync/`), que llama
//  al MISMO `AppAttestClient.shared.currentSessionToken()`, y por qué NO se consolidan: **no son la
//  misma cosa, y unificarlos rompería a uno de los dos.** Lo que difiere no es de dónde sale el token
//  —se acuña en un solo sitio— sino el CONTRATO DE ERROR, y cada uno tiene el contrario:
//
//   · Aquí: «header o nada». Los clients del gateway añaden `X-Yala-Attest-Session` solo cuando el
//     provider devuelve non-nil, así que la firma NO PUEDE lanzar: es `() async -> String?`. Un
//     `throws` haría que un attest caído abortase flujos que el gateway sigue aceptando.
//   · Allí: el error VIAJA, y está escrito en el contrato del protocolo (`CloudSyncRuntime.swift:46`):
//     `attestToken()` propaga el `AppAttestError` para que el runtime lo clasifique transient/terminal
//     con `AttestSyncGate` — de ahí sale el canario `cloudSyncBlockedByAttestUnavailable` y la parada del runtime (no
//     hay banner: medido el 2026-09-15). Un `try?` allí borraría esa clasificación entera.
//
//  Que la diferencia es real y no cosmética se ve en el consumidor: `CloudSyncRuntime.swift:274` y
//  `CloudMigrationController.swift:212` degradan a mano (`{ try? await session.attestToken() }`)
//  justo donde necesitan ESTA forma, mientras `CloudSyncRuntime.swift:737` usa la que lanza.
//

import Foundation

enum AttestSessionProvider {

    /// Token de sesión de App Attest vigente, o `nil` si no se puede obtener (simulador sin el bypass de
    /// dev, red caída, key que el gateway no reconoce).
    ///
    /// **`nil` NO es inocuo donde la ruta exige attest**: los clients solo añaden el header cuando el
    /// provider devuelve algo non-nil, así que un `nil` degrada a «request sin attest» — que bajo
    /// `ENFORCE = "enforce"` el gateway rechaza con 401 `yala_attest_required`, y bajo `"observe"`
    /// (staging) deja pasar. Esa asimetría es exactamente lo que hizo invisible el fallo en QA.
    ///
    /// El `try?` es deliberado y NO es un silencio de los que prohíbe CLAUDE.md: `AppAttestClient` ya
    /// loguea el fallo, y convertirlo en un `throw` haría que un attest caído abortara flujos de usuario
    /// que el gateway puede seguir aceptando (rutas bajo `requireUser`) o degradar con su propio error
    /// tipado. En el canal de sync y en el de membresía de Grupos ese error es PASAJERO desde el 2026-09-15
    /// (`.transient` y `GroupsRPCError.transient(status: 401)`): el 401 `yala_attest_required` llega con la sesión
    /// buena, y leerlo como caducada le pedía a la persona volver a entrar por algo que no se arregla así.
    ///
    /// `nonisolated` para poder referenciarlo desde inicializadores de `static` nonisolados
    /// (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`): el closure `@MainActor` se FORMA aquí sin ejecutarse.
    nonisolated static let live: @MainActor () async -> String? = {
        try? await AppAttestClient.shared.currentSessionToken()
    }

    /// El gateway contestó 401 `yala_attest_required` a `request`: el token que viajó en su `X-Yala-Attest-Session` ya no le
    /// vale. Se olvida en `AppAttestClient` si es el guardado, para que el siguiente intento pida otro en vez de reenviarlo
    /// hasta que caduque en el reloj del teléfono (ticket `attest-session-token-rejected-by-the-gateway-stays-cached`).
    ///
    /// La llaman los OCHO sitios que leen ese 401 (push, pull, merkle, prefs ×2, Grupos sync ×2 y membresía), en la
    /// primera línea de su rama. El reintento no va aquí: lo pone la cadencia de cada llamador.
    static func reportRejected(sentIn request: URLRequest) {
        rejectionSink(sentToken(in: request))
    }

    /// El token de sesión que lleva `request`, sin el prefijo `Bearer `. `nil` si no lo lleva.
    nonisolated static func sentToken(in request: URLRequest) -> String? {
        guard let header = request.value(forHTTPHeaderField: "X-Yala-Attest-Session"), !header.isEmpty else { return nil }
        let prefix = "Bearer "
        return header.hasPrefix(prefix) ? String(header.dropFirst(prefix.count)) : header
    }

    /// A dónde va el token rechazado. Producción: `AppAttestClient.shared`. Los tests lo sustituyen para ver QUÉ token se
    /// rechazó sin tocar el cliente real; restáuralo en `defer` (estático: la suite que lo use va `.serialized`).
    static var rejectionSink: @MainActor (String?) -> Void = defaultRejectionSink
    static let defaultRejectionSink: @MainActor (String?) -> Void = { token in
        AppAttestClient.shared.discardSessionToken(ifEqualTo: token)
    }
}
