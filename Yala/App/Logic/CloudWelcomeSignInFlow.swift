//
//  CloudWelcomeSignInFlow.swift
//  Yala
//
//  Pure-logic de la pantalla "Sign in with Apple" del Welcome (re-entrada a una
//  cuenta del Modo Nube existente). Rutea el resultado de GET /account/exists
//  (read-only — el claim con `created` CREA cuenta server-side, por eso JAMÁS se
//  claimea sin `exists == true` previo) y mapea el uiState del controller a la
//  fase de pantalla durante el adopt.
//

import Foundation

/// Fase de pantalla del sign-in de nube en el Welcome.
nonisolated enum CloudWelcomeSignInPhase: Equatable {
    /// Pantalla inicial con el botón SIWA.
    case intro
    /// `exists` en vuelo tras SIWA exitoso.
    case checking
    /// A5 (alta born-cloud): el claim está en vuelo — la cuenta se está CREANDO, no verificando.
    /// Caso propio y no un `.checking` con otro copy: son dos hechos distintos, y el alta cae a
    /// `.checking` de verdad cuando el claim la reencamina al returning-user.
    case creating
    /// Cross-cuenta con datos locales (F0-C degradado) — mensaje + volver.
    case blockedForeignData
    /// Adopt en curso (progreso de la máquina de migración).
    case adopting(fraction: Double)
    /// Claim devolvió `claiming_in_progress` — otro device lidera.
    case waitingLeader
    /// Adopt completo — TERMINAL: "Cierra y reabre Yala" (NUNCA auto-kill).
    case relaunch
    /// M1: confirmación explícita ANTES de escribir nada de la sesión secundaria
    /// ("entrarás con tu cuenta; los datos del dueño no se tocan").
    case secondaryConfirm
    /// M1: descriptor + claim armados — TERMINAL: "Cierra y reabre Yala" (el boot
    /// monta el store secundario). Sin auto-kill, igual que `.relaunch`.
    case relaunchSecondary
    /// El Apple ID firmado no tiene cuenta Yala en la nube.
    case notFound
    /// R9 (sesión 2 Google): sin cuenta para ESTE sub, pero el faro del device dice que la
    /// cuenta nube se creó con OTRO método → "vuelve atrás y entra con ese método". La sesión
    /// ya se soltó (signOut) y NO hubo claim — nada comprometido, back permitido.
    case providerMismatch(knownProvider: String?)
    /// Fallo de red/sesión del `exists` o de la máquina.
    case error(retryable: Bool)
}

nonisolated enum CloudWelcomeSignInFlow {

    /// Ruteo del resultado de GET /account/exists. `accountFound` NO arranca nada:
    /// el caller debe pasar por `CrossAccountEntryGuardLogic` antes de adoptar.
    enum ExistsRoute: Equatable {
        case accountFound
        case accountMissing
        case failed(retryable: Bool)
    }

    static func route(_ outcome: ExistsOutcome) -> ExistsRoute {
        switch outcome {
        case .exists(true): .accountFound
        case .exists(false): .accountMissing
        case .sessionExpired: .failed(retryable: true)
        case .transient: .failed(retryable: true)
        }
    }

    /// Mapea el `uiState` del CloudMigrationController a la fase de pantalla
    /// mientras el adopt corre. Estados que "no deberían ocurrir aquí" degradan
    /// a `.error` (defensivo, nunca trap).
    static func phase(for uiState: CloudMigrationUIState) -> CloudWelcomeSignInPhase {
        switch uiState {
        case .idle:
            // Pre-arranque de la máquina (fases consent/authenticating no-durables).
            return .adopting(fraction: 0)
        case .migrating(let step):
            return .adopting(fraction: step.fraction)
        case .needsRelaunch(.toCloud):
            return .relaunch
        case .cloudActive:
            // El relaunch ya se resolvió en otro proceso — terminal equivalente.
            return .relaunch
        case .waitingForLeader:
            return .waitingLeader
        case .failed:
            return .error(retryable: true)
        case .reverting, .needsRelaunch(.toICloud):
            // Imposibles en un adopt desde Welcome; jamás presentar UI de reversa.
            return .error(retryable: false)
        }
    }
}

// MARK: - A5 · el encadenado del alta born-cloud

/// Pure-logic del ALTA nube (born-cloud, A5 de D-A7): traduce el resultado del claim
/// (`BornCloudSignUpService.signUp()`) al siguiente paso del encadenado.
///
/// Vive aquí y no en el servicio porque es una decisión de PANTALLA: el servicio sabe qué pasó
/// server-side y esta tabla sabe qué hace la UI con ello. El paso que carga el peso es
/// `.continueAsReturningUser` — la variante A de §f.1: sobre una cuenta ya poblada **JAMÁS se
/// siembra**, se encamina al returning-user que ya existe.
nonisolated enum BornCloudSignUpFlow {

    /// Qué hace el llamador con el resultado del claim.
    enum Step: Equatable {
        /// `created` + rama born-cloud: escribir el par `.cloud` + `mirrorOffArmed` (A3) y presentar
        /// la terminal de relanzamiento. **Es el ÚNICO paso que toca el almacenamiento.**
        case activateStorageAndRelaunch
        /// La cuenta ya existía (2º device o reintento tras un `created` previo): continuar por el
        /// flujo de re-entrada CON LA SESIÓN VIVA (`exists` → guard cross-cuenta → adopt). No siembra.
        case continueAsReturningUser
        /// Terminal directa: otro device lidera, el método no casa, o un error del claim.
        case show(CloudWelcomeSignInPhase)
        /// 401: el JWT no sirve. Soltar la sesión ANTES de mostrar el error — si no, el re-tap
        /// reusaría la sesión muerta (`runSignInFlow` salta el sign-in cuando `hasSession`) y el
        /// usuario quedaría en un bucle de reintentos que no pueden funcionar.
        case releaseSessionAndShowError
    }

    static func step(for outcome: BornCloudSignUpOutcome) -> Step {
        switch outcome {
        case .seeded:
            return .activateStorageAndRelaunch
        case .routeReturningUser:
            return .continueAsReturningUser
        case .waitForLeader:
            return .show(.waitingLeader)
        case .providerMismatch(let knownProvider):
            // Hoy INALCANZABLE desde `.bornCloud` (la variante B es `returningUser`-only,
            // `AccountClaimDecision.swift:83` — medido en A2). Se mapea igual porque la tabla que
            // decide vive allí: el día que alguien la amplíe, esto ya muestra el copy R9 correcto.
            return .show(.providerMismatch(knownProvider: knownProvider))
        case .sessionExpired:
            return .releaseSessionAndShowError
        case .accountUnavailable:
            // 403 = cuenta suspendida. Reintentar no la despierta: error SIN botón de retry.
            return .show(.error(retryable: false))
        case .transient:
            // El claim es idempotente por contrato (§f.1: el re-claim del MISMO device colapsa a
            // `created`), así que reintentar es seguro.
            return .show(.error(retryable: true))
        }
    }
}

// MARK: - Auto-resume del adopt aparcado (H-2026-07-17-5)

/// Detector PURO de "drive aparcado" para el poll de la pantalla de adopt del Welcome
/// (H-2026-07-17-5: `startAdoptWithExistingSession()` retorna cuando el drive corta retomable
/// —transient de red— y el poll solo OBSERVABA; sin botón Retomar aquí y con `rekickIfParked`
/// disparando solo al volver a foreground, la pantalla quedaba clavada en "Conectando…").
/// Molde `MigrationForegroundRekick`: tabla pura + tests. El drive del runner es SÍNCRONO dentro
/// de las entradas públicas (`runGuarded`) ⇒ `isWorking == false` con fase `.adopting` significa
/// que NADIE conduce — sostenido N ticks es una aparcada real, no una ventana entre awaits.
/// La acotación a transicionales de adopt es estructural en el caller (el poll retorna en
/// `.relaunch`/`.error`/`.waitingLeader`) y en el destino (`resumeIfNeeded` → `MigrationBootDecision`,
/// que devuelve `.none` en terminales de fallo — contrato del boot: jamás auto-re-kick de rollbacks).
nonisolated enum WelcomeAdoptAutoResume {

    struct State: Equatable {
        /// Ticks consecutivos del poll con la pantalla en `.adopting` y el controller ocioso.
        var idleTicks = 0
        /// Auto-resumes disparados desde el último AVANCE real de la máquina.
        var attempts = 0
        /// Autos agotados sin avance → la vista muestra el botón Retomar manual.
        var showManualRetry = false
    }

    /// Poll de 1 s ⇒ ~4 s aparcada antes del primer auto-resume.
    static let idleTicksBeforeResume = 4
    /// Tras 3 autos sin avance deja de martillear la red (queda el botón manual + el
    /// rekick de foreground); un avance real repone intentos frescos.
    static let maxAutoAttempts = 3

    /// Un tick del poll. `isAdopting` = fase de pantalla `.adopting` (transicional);
    /// `isWorking` = el controller conduce AHORA (resume del boot/rekick en vuelo — jamás
    /// disparar encima); `machineAdvanced` = la fase journaleada cambió desde el tick anterior.
    static func tick(
        isAdopting: Bool,
        isWorking: Bool,
        machineAdvanced: Bool,
        state: State
    ) -> (state: State, fireAutoResume: Bool) {
        var next = state
        if machineAdvanced {
            // Avance real: un park posterior merece intentos frescos y el botón sobra.
            next.attempts = 0
            next.showManualRetry = false
        }
        guard isAdopting, !isWorking else {
            // Drive en curso o fase no transicional: la racha ociosa se corta, los
            // intentos se CONSERVAN (un resume en vuelo todavía no es avance).
            next.idleTicks = 0
            return (next, false)
        }
        next.idleTicks += 1
        guard next.idleTicks >= idleTicksBeforeResume else { return (next, false) }
        next.idleTicks = 0
        if next.attempts < maxAutoAttempts {
            next.attempts += 1
            return (next, true)
        }
        next.showManualRetry = true
        return (next, false)
    }
}
