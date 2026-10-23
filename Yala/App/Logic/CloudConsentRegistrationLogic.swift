//
//  CloudConsentRegistrationLogic.swift
//  Yala
//
//  Chip M0 (ola M, §6.3 de [[MODO-NUBE-SPEC-M1-REVIVAL]]): DÓNDE cae la escritura del registro GDPR del
//  consent de Nube en la RE-ENTRADA del Welcome, una vez el guard cross-cuenta dice por dónde va.
//
//  El bug que cierra esta tabla: `CloudConsentView` escribía al aceptar, y ahí la ruta todavía no existe
//  —el sign-in ni siquiera ha ocurrido—, así que `PreferenceSyncService` resolvía el destino con el modo
//  PERSISTIDO del device, que durante el Welcome es el `.icloud` del DUEÑO. Un intento cross-cuenta que
//  terminaba BLOQUEADO ya había dejado el epoch de la otra persona en el iKV del dueño, y el paso 5-bis
//  del cutover (`MigrationWorkExecutor.adoptBackendAccount`) lo habría subido un día como consent SUYO.
//
//  Lo que esta tabla NO hace, y es deliberado: no borra ni degrada ningún epoch (consent es append-only,
//  regla §prefs de `.claude/rules/swiftdata-cloudkit.md`). Solo mueve la escritura al punto del flujo en
//  que la ruta ya se conoce.
//
//  El alta born-cloud queda FUERA a propósito: su ruta ya se conoce al aceptar (no pasa por el guard) y
//  su claim VERIFICA el registro (paso 5 de `BornCloudSignUpService`), así que allí sigue escribiendo la
//  pantalla. Por eso el `pending` es un parámetro y no una constante: en born-cloud llega ya consumido.
//

import Foundation

nonisolated enum CloudConsentRegistrationLogic {

    /// Los puntos del flujo de re-entrada donde la escritura puede caer, y el porqué de cada uno.
    enum Placement: Equatable {
        /// Adopt del propio dueño: ANTES de arrancar la máquina de migración. El paso 5-bis de
        /// `adoptBackendAccount` re-emite el epoch PERSISTIDO y, si no lo encuentra, cae al fallback
        /// `now()` — que es la hora de FIN del adopt, no la de la aceptación.
        case beforeAdopt
        /// Bloqueado: NUNCA. La sesión se descarta sin tocar nada del device y el registro GDPR real de
        /// esa cuenta vive en SU backend, escrito el día que la creó.
        case never
    }

    /// La tabla. Total sobre las salidas del guard: añadir una nueva obliga a decidir su destino
    /// aquí, no en la pantalla.
    static func placement(for decision: CrossAccountEntryGuardLogic.Decision) -> Placement {
        switch decision {
        case .proceed: .beforeAdopt
        case .blockedForeignData: .never
        }
    }

    /// Escribe (vía `persist`) SOLO si se cumplen las tres condiciones, y consume el pendiente.
    ///
    /// El `point != .never` no es defensa decorativa: sin él, un call-site colocado en la rama bloqueada
    /// con `at: .never` casaría con la tabla y escribiría — exactamente el bug que este chip cierra.
    ///
    /// `pending` es `inout` para que el consumo sea del LLAMADOR (el `@State` de la pantalla): la
    /// escritura ocurre UNA vez aunque el flujo pase dos veces por el mismo punto (retry tras `.error`),
    /// y el epoch conserva su T0 en vez de saltar a la hora del reintento.
    ///
    /// - Returns: `true` si esta llamada escribió. Para el test — el criterio del chip es contar.
    @discardableResult
    static func persistIfDue(
        at point: Placement,
        routedBy decision: CrossAccountEntryGuardLogic.Decision,
        pending: inout Bool,
        persist: () -> Void
    ) -> Bool {
        guard pending, point != .never, placement(for: decision) == point else { return false }
        pending = false
        persist()
        return true
    }

    // MARK: - Pasar de entrar a crear la cuenta en la misma pasada (UX 2.2 · lote decidido 15)

    /// Qué pasa con el consentimiento cuando, en la MISMA pantalla, la persona pasa de «Entrar con…» a «Crear cuenta
    /// con…» (desde «Este iPhone ya usó otra cuenta» o desde «No encontramos una cuenta»).
    enum SignUpSwitch: Equatable {
        /// No lo aceptó en esta pasada: se le pide, como siempre antes de firmar.
        case askConsent
        /// Ya lo aceptó hace un momento, antes de «Entrar con…»: el texto es el mismo (solo cambia el botón), así que
        /// pedirlo otra vez era el mismo permiso dos veces en un minuto (QA de 2.1, 19-oct). Se registra para el alta.
        case alreadyAccepted
    }

    static func signUpSwitch(consentAcceptedThisPass: Bool) -> SignUpSwitch {
        consentAcceptedThisPass ? .alreadyAccepted : .askConsent
    }

    /// El registro GDPR del ALTA cuando no se vuelve a preguntar. El alta escribe al aceptar porque su ruta ya se conoce;
    /// aquí la aceptación fue la de la re-entrada, que dejó su escritura PENDIENTE hasta que el guard cross-cuenta
    /// decidiera. Ese guard ya no va a decidir nada —no hay adopt—, y la ruta ahora es el alta: se escribe en este
    /// momento, una sola vez, y se consume el pendiente para que ningún otro punto lo escriba después.
    ///
    /// Sin pendiente no se escribe: o ya se escribió (no hay segunda aceptación que registrar) o no hubo aceptación, y
    /// entonces `signUpSwitch` habría pedido el consentimiento.
    ///
    /// - Returns: `true` si esta llamada escribió.
    @discardableResult
    static func persistForSignUpSwitch(pending: inout Bool, persist: () -> Void) -> Bool {
        guard pending else { return false }
        pending = false
        persist()
        return true
    }
}
