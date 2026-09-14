//
//  AppleIDChangeCloseLogic.swift
//  Yala
//
//  El predicado PURO de «el Apple ID del teléfono cambió y la sesión privada era del anterior».
//
//  POR QUÉ EXISTE, y por qué NO es «alinear el aviso que ya había». El ticket
//  (`apple-id-change-should-close-the-private-session`) daba por supuesto que
//  `AppBootstrapper.checkForICloudMismatch` ya reaccionaba al cambio de cuenta y solo había que
//  convertir su aviso en un cierre. Medido el 2026-09-14 en este árbol, no es así: el predicado que
//  gobierna ese aviso (`SwiftDataConfiguration.shouldOfferICloudRestart`) pregunta «¿monté sin espejo
//  y AHORA hay iCloud?», que es otra cosa, y **la app no guardaba ningún testigo del Apple ID con el
//  que montó** — no había con qué comparar. El aviso viejo se queda donde está: contesta otra
//  pregunta y sigue siendo correcta.
//
//  LA REGLA DEL ADR (2026-09-09 «Sesiones — dos ejes», §1). La sesión privada «vive en el dispositivo
//  y sincroniza por el iCloud privado del Apple ID del teléfono. No tiene login ni logout: salir es
//  borrar lo local y dejar el contenedor en iCloud». Si el Apple ID cambia, la sesión privada de este
//  teléfono es de una cuenta que ya no está: sus datos siguen en el iCloud del Apple ID anterior, y
//  lo local es una copia que le pertenece a otra persona. El desenlace del modelo es el cierre de
//  sesión, con su borrado por ARCHIVOS, no un aviso.
//
//  LOS CUATRO TÉRMINOS, y hacia dónde falla cada uno. Todos empujan en la misma dirección: ante la
//  duda NO se cierra. El error caro de este predicado es el `true` — borra datos de alguien.
//
//  DE DÓNDE SALE LA IDENTIDAD, y por qué NO del token de iCloud. `PrivateSessionAppleIDWitness` la
//  toma de `CKContainer.userRecordID()` del contenedor PERSONAL. El camino barato —comparar
//  `FileManager.ubiquityIdentityToken`— está descartado por la rule de área
//  (`.claude/rules/swiftdata-cloudkit.md`): ese token mide iCloud **Drive**, no CloudKit, así que con
//  Drive apagado y la sesión de iCloud viva vale `nil` mientras CloudKit funciona perfectamente.
//  Usarlo aquí convertiría «apagar iCloud Drive» en «cambiaste de Apple ID» y BORRARÍA los datos de
//  quien no cambió nada. La notificación `NSUbiquityIdentityDidChange` sí se usa, pero como
//  DISPARADOR de la comprobación, jamás como veredicto.
//
//  EL RESIDUAL, dicho entero porque no se puede cerrar. Quien cambie de Apple ID **antes** de
//  actualizar a la versión que estrena esto llega sin testigo, y el primer arranque le siembra la
//  cuenta NUEVA: su cambio ya no se detecta nunca. No hay forma de arreglarlo —nadie guardó con qué
//  cuenta se montó— y la alternativa (tratar la ausencia como sospecha) borraría los datos del parque
//  entero, que es infinitamente peor. A esa población la sigue cubriendo el cambio SIGUIENTE.
//
//  ADR 2026-09-09 §1 · ticket `apple-id-change-should-close-the-private-session`.
//

import Foundation

nonisolated enum AppleIDChangeCloseLogic {

    /// Qué hacer con la identidad que CloudKit acaba de contestar.
    enum Verdict: Equatable {
        /// La sesión privada de este teléfono es de otro Apple ID: ofrecer el cierre (con confirmación).
        case offerClose
        /// Primera lectura en este dispositivo: guardar la identidad como testigo y no hacer nada más.
        /// **Nunca cierra**: una marca ausente no es prueba de un cambio, y el parque entero llega aquí
        /// sin testigo el día que este código se estrena.
        case seedWitness
        /// Ni cierre ni testigo nuevo: la identidad coincide, o esta celda no participa.
        case ignore
    }

    /// El veredicto.
    ///
    /// - Parameters:
    ///   - confirmedPrivateSession: **la lectura ESTRICTA del eje 1** (`PrivateSessionMark`, ausente ⇒
    ///     `false`), y no la ancha. Cumple el criterio que su docblock fija para admitir un consumidor
    ///     nuevo: «hacia `true` se destruye, hacia `false` solo se conserva de más». Con la lectura
    ///     ancha, un dispositivo cuya marca aún no se ha escrito se borraría a sí mismo. **Aporta DOS
    ///     lecturas y no una** —el pre-filtro y la re-lectura tras el `await`—, que es lo que sube el
    ///     conteo de `PrivateSessionMarkTests` de 3 a 5.
    ///   - groupsOnlySessionArmed: el término que el ticket pide conservar explícitamente. Una sesión
    ///     solo-grupos **no tiene sesión privada que cerrar**: su store personal está vacío a
    ///     propósito y su vida vive en la cuenta de Yala, que no es del Apple ID del teléfono. Sin
    ///     este término le llegaría un aviso que le propone borrar algo que no es suyo. Va ADEMÁS del
    ///     eje 1 y no en su lugar: son dos hechos distintos y el residual del backfill (un alta
    ///     solo-grupos anterior al 2026-09-10 no tiene la marca del mount) hace que uno de los dos
    ///     pueda mentir.
    ///   - storageMode: en `.cloud` lo personal vive en la cuenta de Yala y el Apple ID del teléfono
    ///     no gobierna nada de lo personal — cambiarlo no cierra ninguna sesión. Se lee el modo
    ///     PERSISTIDO y no el mount, porque la pregunta es «¿de quién son estos datos?», que la
    ///     reversa cambia en caliente sin remontar.
    ///   - witness: la identidad guardada la última vez. `nil` = nunca se guardó ⇒ `.seedWitness`.
    ///   - currentIdentity: lo que CloudKit contesta AHORA. `nil` = no se pudo preguntar (sin red, sin
    ///     cuenta, `notAuthenticated`) ⇒ **`.ignore`**: no saber no es saber que cambió. Falla CERRADO.
    static func decide(confirmedPrivateSession: Bool,
                       groupsOnlySessionArmed: Bool,
                       storageMode: StorageMode,
                       witness: String?,
                       currentIdentity: String?) -> Verdict {
        guard participates(confirmedPrivateSession: confirmedPrivateSession,
                           groupsOnlySessionArmed: groupsOnlySessionArmed,
                           storageMode: storageMode) else { return .ignore }
        // CloudKit no contestó: no se concluye nada.
        guard let currentIdentity, !currentIdentity.isEmpty else { return .ignore }
        // Primera vez en este dispositivo: se siembra, no se cierra.
        guard let witness, !witness.isEmpty else { return .seedWitness }
        return witness == currentIdentity ? .ignore : .offerClose
    }

    /// **Los tres términos LOCALES: ¿esta celda participa siquiera?**
    ///
    /// Es la mitad del predicado que se puede contestar sin salir a la red, y por eso existe aparte: el
    /// llamador la evalúa ANTES de gastar una ida a CloudKit, que en una sesión solo-grupos o en la nube
    /// sería un viaje por arranque para contestar siempre lo mismo.
    ///
    /// **Está extraída y no duplicada, y esa es toda la gracia.** Un pre-filtro que repite la condición
    /// del criterio con su propia copia es cómo se consigue que el mutante del criterio salga VERDE: la
    /// medición nunca llega a la lógica porque el filtro ya la cortó. Aquí hay una sola fuente —`decide`
    /// la llama— así que invertir un término rompe los dos caminos, y los tests pinnean cada nivel.
    static func participates(confirmedPrivateSession: Bool,
                             groupsOnlySessionArmed: Bool,
                             storageMode: StorageMode) -> Bool {
        // 1. Sin sesión privada confirmada no hay nada que cerrar, y el testigo no describiría a nadie.
        guard confirmedPrivateSession else { return false }
        // 2. Solo-grupos nunca ve esto (criterio explícito del ticket).
        guard !groupsOnlySessionArmed else { return false }
        // 3. En la nube lo personal no es del Apple ID.
        return storageMode == .icloud
    }
}
