//
//  CloudSessionRevision.swift
//  Yala
//
//  Card n533 · el aviso de cambio de sesión (`CloudAuthService.sessionDidChangeNotification`, card nve0) hecho
//  OBSERVABLE, para que una vista que pinte con `CloudAuthService.shared.hasSession` se repinte sin escucharlo ella.
//
//  **Por qué un contador y no un `onReceive` por vista.** nve0 arregló la pestaña de Grupos con un `@State` que el aviso
//  sube y el `body` lee. El mismo patrón asomaba en cinco sitios más, y en dos de ellos la lectura no está en el `body`
//  de una vista con estado propio: «Tu cuenta de Yala» es una pantalla empujada, y el aviso del attest del Panel se
//  decide en `CloudAttestNotice.isShowing`, que comparten dos pantallas. Con un `@State` por vista habría que tocar cada
//  contenedor y acordarse de todos. Aquí basta con llamar a `track()` junto a la lectura de la sesión: SwiftUI registra
//  la dependencia en el `body` que lo evalúa, sea cual sea, y lo repinta cuando sube.
//
//  **Solo para repintar**, como el aviso del que sale: no dice qué sesión hay (la vista la vuelve a leer) y no es sitio
//  para sellar nada. **No cubre la sesión que el SDK borra solo** tras un refresco terminal, por lo mismo que el aviso
//  (ticket `cloud-session-removed-by-the-sdk-does-not-announce-itself`).
//

import Foundation
import Observation

@Observable
@MainActor
final class CloudSessionRevision {

    static let shared = CloudSessionRevision()

    /// Sube una vez por aviso. El valor no significa nada: leerlo es lo que ata el `body` al cambio.
    private(set) var value = 0

    private init() {}

    /// Lo llama `CloudAuthService` en el mismo sitio donde emite `sessionDidChangeNotification`, y solo ahí.
    func bump() { value &+= 1 }

    /// Ata el `body` que lo evalúe a los cambios de sesión. Se llama justo antes de leer `hasSession`.
    func track() { _ = value }
}
