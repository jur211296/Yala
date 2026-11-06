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
//  El alta born-cloud ENTRÓ el 2026-11-06 (ticket `borncloud-consent-epoch-written-before-the-guard-decides`).
//  Se la dejó fuera porque «su ruta ya se conoce al aceptar», y no era verdad: el claim puede contestar
//  `existing_stable`, y entonces el alta sigue por el guard cross-cuenta, que puede acabar en
//  `.blockedForeignData` o en la puerta de Grupos. Hoy el alta también deja el epoch PENDIENTE y lo escribe
//  cuando el claim confirma una cuenta nueva (`bornCloudWritesConsent`); si el claim la reencamina, escribe el
//  guard, como en cualquier re-entrada.
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

    // MARK: - El alta

    /// ¿El alta escribe el consentimiento pendiente tras este claim? Solo con una cuenta NUEVA y de quien está delante
    /// (`.seedBornCloud`). `routeReturningUser` sigue al guard cross-cuenta, que decide por la tabla de arriba; un
    /// seguidor (`waitForLeader`) no ha entrado a nada, y lo que la variante B enseñe tampoco. El pendiente se queda
    /// sin consumir: un reintento o la re-entrada lo escriben con el T0 de la aceptación.
    static func bornCloudWritesConsent(after action: AccountClaimDecision.AuthAction) -> Bool {
        action == .seedBornCloud
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

    /// El registro GDPR del ALTA, en el punto que `bornCloudWritesConsent` elige. Vale igual para la aceptación del
    /// alta y para la de la re-entrada que pasó al alta sin volver a preguntar (`signUpSwitch == .alreadyAccepted`): las
    /// dos dejaron el epoch PENDIENTE. Se escribe una sola vez y se consume el pendiente, para que ningún otro punto lo
    /// escriba después.
    ///
    /// Sin pendiente no se escribe: o ya se escribió (no hay segunda aceptación que registrar) o no hubo aceptación.
    ///
    /// - Returns: `true` si esta llamada escribió.
    @discardableResult
    static func persistForNewAccount(pending: inout Bool, persist: () -> Void) -> Bool {
        guard pending else { return false }
        pending = false
        persist()
        return true
    }
}
