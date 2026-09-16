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
    ///
    /// R0 (el auto-exit del terminal del Welcome) la dejó FUERA a propósito, y conviene saber por qué
    /// antes de "completarlo": esta fase es `@State` privado de `WelcomeCloudSignInView`, así que
    /// `YalaApp.handleScenePhase` —que decide con el scenePhase AGREGADO del proceso y por eso solo lee
    /// estado durable— no tiene nada que consultar. Sus dos productores están además fuera del alcance
    /// de aquel chip: el adopt (máquina de migración) y el alta born-cloud sobre un device CON archivo
    /// de store. Darle auto-exit exige antes un testigo durable, no un observable de pantalla.
    case relaunch
    /// **R2: alta born-cloud completa SIN relanzar.** El proceso montó el store personal NEUTRO
    /// (`.none` explícito), que es la MISMA `ModelConfiguration` que pide el par `.cloud` + `mirrorOffArmed`
    /// recién escrito ⇒ no hay nada que remontar y el motor ya arrancó en esta sesión. Terminal como
    /// `.relaunch`, pero su salida es continuar al onboarding normal, no matar la app.
    ///
    /// Caso propio y no un `.relaunch` con otro copy: son dos desenlaces distintos del MISMO alta y quien
    /// los distingue es el testigo de mount, no la pantalla. Colapsarlos obligaría a la vista a re-derivar
    /// la decisión.
    case bornCloudReady
    /// **R3 (2026-09-06): la RE-ENTRADA terminó sin relanzar.** Mismo hecho visible que
    /// `.bornCloudReady` —el almacenamiento nube quedó activo en este proceso, con el motor arrancado en
    /// sesión, y no hay nada que reabrir— y por eso comparte su pantalla y su copy.
    ///
    /// **Es una fase propia por su SALIDA, y la diferencia no es de camino sino de precondición.** El
    /// alta llega aquí con `hasCompletedOnboarding` en `false`: su usuario no tiene datos y el onboarding
    /// de 8 pasos es su siguiente paso legítimo. La re-entrada llega con ese flag ya en `true`, porque
    /// `onAdoptStarted` lo marca ANTES de conducir la máquina para «cerrar el hazard kill-mid-adopt → el
    /// seed del onboarding jamás corre sobre una cuenta existente» (`ContentView`, su propio comentario).
    /// Mandarla al onboarding desharía esa defensa: `createOnboardingAccount` inserta una cuenta sin
    /// comprobar existencia y `seedCategoriesIfNeeded` siembra si el pull aún no aterrizó — y con el motor
    /// ya corriendo, ambas cosas SUBEN al backend y se abanican a los demás devices del usuario.
    ///
    /// Su salida es la del relanzamiento de antes: cerrar el cover y caer a la app. Colapsar las dos
    /// fases en una obliga al callback único a adivinar cuál de las dos precondiciones tiene delante, que
    /// es exactamente lo que no puede hacer.
    case reentryReady
    /// El Apple ID firmado no tiene cuenta Yala en la nube.
    case notFound
    /// R9 (sesión 2 Google): sin cuenta para ESTE sub, pero el faro del device dice que la
    /// cuenta nube se creó con OTRO método. **Desde el paso 6 ya no es una pared** (ADR 2026-09-09 §10):
    /// lleva las DOS salidas del veredicto —entrar con el método del faro, o crear una cuenta con el que la
    /// persona acaba de usar—, y la pantalla pinta la de crear solo tras la puerta del alta
    /// (`WelcomeNewOptionsGate.offersCloudSignUp`). La sesión ya se soltó (signOut) y NO hubo claim — nada
    /// comprometido, back permitido.
    case providerMismatch(ProviderMismatchLogic.Exits)
    /// Fallo de red/sesión del `exists` o de la máquina.
    case error(retryable: Bool)
    /// La cuenta existe pero el backend no la deja entrar (403 en el claim). Caso propio y no un
    /// `.error(retryable: false)`: ése comparte copy con el fallo de red —icono de wifi incluido— y
    /// **el problema no es la conexión**. Sin botón de reintentar: esperar no despierta una cuenta
    /// suspendida (ticket `reentry-counts-as-fresh-install` §3).
    case accountBlocked
}

nonisolated enum CloudWelcomeSignInFlow {

    /// Ruteo del resultado de GET /account/exists. `accountFound` NO arranca nada:
    /// el caller debe pasar por `CrossAccountEntryGuardLogic` antes de adoptar.
    ///
    /// El `kind` viaja con `accountFound` porque es la misma respuesta: preguntar «¿existe?» y «¿de
    /// qué tipo es?» en dos viajes abriría una ventana en la que las dos respuestas pueden discrepar.
    /// **Es `AccountKind?` y no `AccountKind`**: un gateway anterior a g15_01 contesta sin el campo, y
    /// eso no es un fallo de ruteo — quien decide qué asumir entonces es `AccountKindLogic.resolve`.
    ///
    /// Quién USA ese `kind` para elegir pantalla es el ticket `cloud-sign-in-discovers-account-kind`
    /// (bloque [I] del ADR §7): aquí solo se transporta.
    enum ExistsRoute: Equatable {
        case accountFound(kind: AccountKind?)
        case accountMissing
        case failed(retryable: Bool)
    }

    static func route(_ outcome: ExistsOutcome) -> ExistsRoute {
        switch outcome {
        case let .exists(true, kind): .accountFound(kind: kind)
        case .exists(false, _): .accountMissing
        case .sessionExpired: .failed(retryable: true)
        case .transient: .failed(retryable: true)
        }
    }

    /// Mapea el `uiState` del CloudMigrationController a la fase de pantalla
    /// mientras el adopt corre. Estados que "no deberían ocurrir aquí" degradan
    /// a `.error` (defensivo, nunca trap).
    ///
    /// `claimBlocker` GANA sobre el progreso, y por eso se mira primero: un claim aparcado por 403
    /// deja el journal en `claimingMigration` —una fase transicional perfectamente normal— así que el
    /// `uiState` sigue diciendo `.migrating` y la pantalla se quedaba en «Conectando con tu cuenta…»
    /// indefinidamente, con el auto-resume gastando sus tres intentos y ofreciendo luego un botón de
    /// reintentar sobre algo que reintentar no arregla.
    ///
    /// **No gana sobre los terminales de éxito**: si el adopt llegó a `needsRelaunch`/`cloudActive`,
    /// un bloqueo viejo de un intento anterior no debe tapar un final que ya ocurrió.
    static func phase(
        for uiState: CloudMigrationUIState,
        claimBlocker: ClaimBlocker? = nil
    ) -> CloudWelcomeSignInPhase {
        if let claimBlocker {
            switch uiState {
            case .needsRelaunch, .cloudActive:
                break                          // ya terminó: el bloqueo es de un intento superado
            case .idle, .migrating, .reverting, .waitingForLeader, .failed:
                switch claimBlocker {
                case .accountUnavailable:
                    return .accountBlocked
                case .sessionExpired:
                    // La sesión se puede rehacer entrando otra vez — reintentar aquí SÍ tiene sentido.
                    return .error(retryable: true)
                }
            }
        }
        switch uiState {
        case .idle:
            // Pre-arranque de la máquina (fases consent/authenticating no-durables).
            return .adopting(fraction: 0)
        case .migrating(let step):
            return .adopting(fraction: step.fraction)
        case .needsRelaunch(.toCloud):
            return .relaunch
        case .cloudActive:
            // **Terminal de LISTA, no de relanzamiento** (decisión owner 2026-09-06).
            //
            // Hasta el 2026-09-07 esto devolvía `.relaunch` justificado con «el relaunch ya se
            // resolvió en otro proceso — terminal equivalente», y esa frase describía mal el caso que
            // más importa: en un móvil recién instalado NINGÚN proceso resolvió nada. El store nació
            // NEUTRO, así que `derive` nunca pasa por `.needsRelaunch(.toCloud)` —ese término exige
            // `mirrorStillAttached`— y cae aquí con el mirror inexistente y nada que remontar. Pedirle
            // a ese usuario que cerrara y reabriera Yala era cobrarle un relanzamiento que no hacía
            // falta.
            //
            // Llegar aquí significa, por los DOS productores, que la app ya funciona sin reabrirse:
            //  · mount neutro (re-entrada en móvil limpio) — el motor lo arranca en sesión
            //    `startAdoptWithExistingSession`, igual que el alta;
            //  · el relanzamiento SÍ ocurrió en otro proceso — y entonces el motor arrancó en su boot
            //    (`resumeIfNeeded` → `startRuntimeIfStable`).
            // El caso que todavía DEBE relanzar tiene su propio `case` arriba y no pasa por aquí.
            //
            // Fase PROPIA y no `.bornCloudReady`: comparten pantalla y copy, pero no salida. Quien
            // llega aquí ya tiene `hasCompletedOnboarding` marcado por `onAdoptStarted`, así que su
            // siguiente paso es la app, no el onboarding de 8 pasos —que sobre una cuenta existente
            // insertaría una cuenta duplicada y podría sembrar categorías encima del pull—. El
            // razonamiento completo, en el docblock de `.reentryReady`.
            return .reentryReady
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
        /// `created` + rama born-cloud: escribir el par `.cloud` + `mirrorOffArmed` (A3) y presentar la
        /// terminal que corresponda. **Es el ÚNICO paso que toca el almacenamiento.**
        ///
        /// R2: la terminal ya no es siempre el relanzamiento — la decide `activateBornCloudStorage`
        /// preguntándole al testigo de mount. El nombre del caso se conserva porque lo que este paso
        /// significa (activar el almacenamiento nube) no ha cambiado.
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
        case .providerMismatch(let exits):
            // Hoy INALCANZABLE desde `.bornCloud` (la variante B es `returningUser`-only,
            // `AccountClaimDecision.swift:83` — medido en A2). Se mapea igual porque la tabla que
            // decide vive allí: el día que alguien la amplíe, esto ya muestra la pantalla R9 con sus
            // dos salidas.
            return .show(.providerMismatch(exits))
        case .sessionExpired:
            return .releaseSessionAndShowError
        case .accountUnavailable:
            // 403 = cuenta suspendida. Reintentar no la despierta, y el copy genérico de `.error`
            // culpa a la conexión: pantalla propia (la MISMA que ve el adopt desde §3 del ticket
            // `reentry-counts-as-fresh-install` — las dos puertas cuentan por fin lo mismo).
            return .show(.accountBlocked)
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
/// `.relaunch`/`.reentryReady`/`.error`/`.waitingLeader`/`.accountBlocked` — la lista creció el
/// 2026-09-07, cuando el adopt sobre mount neutro dejó de terminar en `.relaunch`) y en el destino
/// (`resumeIfNeeded` → `MigrationBootDecision`,
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
