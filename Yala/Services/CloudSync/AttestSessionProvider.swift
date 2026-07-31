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
//     con `AttestSyncGate` — de ahí salen el banner de «este device no puede sincronizar» y el canario
//     `cloudSyncBlockedByAttestUnavailable`. Un `try?` allí borraría esa clasificación entera.
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
    /// tipado (`GroupsRPCError.sessionExpired`).
    ///
    /// `nonisolated` para poder referenciarlo desde inicializadores de `static` nonisolados
    /// (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`): el closure `@MainActor` se FORMA aquí sin ejecutarse.
    nonisolated static let live: @MainActor () async -> String? = {
        try? await AppAttestClient.shared.currentSessionToken()
    }
}
