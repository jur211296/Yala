//
//  FullModeActivationFlowLogic.swift
//  Yala
//
//  Paso 8 del rediseño de sesiones · **«Activar Yala completo» pregunta dónde viven tus datos personales.**
//
//  ADR 2026-09-09 «Sesiones — dos ejes» §8: «Yala completo» no es «nube completa». Quien usa Yala solo
//  para grupos y activa Yala completo ELIGE con el mismo chooser de «Primera vez»: su iCloud privado o su
//  cuenta en la nube (la misma que ya usa para grupos). Hasta este paso la activación abría el onboarding
//  directamente, y lo personal aterrizaba en el store que estuviera montado sin que nadie preguntara.
//
//  **Este fichero es la mitad testeable**: qué pantalla toca, en qué orden se escribe cada cosa, qué hace
//  cada desenlace de la promoción y qué deshace «cancelar». `FullModeActivationView` solo ejecuta.
//

import Foundation

enum FullModeActivationFlowLogic {

    typealias Option = WelcomeAccountChoiceLogic.NewOption

    // MARK: - Pantallas

    /// Las pantallas de la activación.
    enum Screen: Equatable {
        /// Privado / nube. Es la primera pantalla de toda activación desde solo-grupos (criterio 1 del ticket).
        case chooser
        /// La puerta del paso 4: le pregunta a CloudKit qué hay ANTES de adjuntar el espejo.
        case privateGate
        /// El store montado es el neutro y lo privado necesita el espejo: hay que reabrir la app.
        case relaunch
        /// Consentimiento de la nube. No se recorta nunca (decisión de Jürgen en el paso 3).
        case consent
        /// El onboarding personal [P].
        case onboarding(OnboardingSource)
        /// «Ya tengo cuenta → iCloud»: los mismos screens, dentro de la activación.
        case restore
        /// Una instalación solo-grupos anterior al paso 5, con el espejo YA adjunto: hay que reinstalar.
        case reinstallNotice
        /// El recorrido de antes, sin chooser: para quien NO es solo-grupos y por tanto ya tiene decidido
        /// dónde viven sus datos personales.
        case legacyOnboarding
        /// **La misma puerta, pero después de Restaurar: «Empezar desde cero» descartando lo que ya bajó.**
        ///
        /// Es un case propio y no un flag al lado de `.privateGate` porque las dos entradas necesitan
        /// borrados **opuestos**, y un flag se hereda en silencio (el defecto que la review le cazó al
        /// propósito de la puerta de Grupos cuando vivía en un `@State` paralelo al step):
        ///
        ///  · en `.privateGate` el store todavía **no espeja** —se llega antes del relanzamiento—, así que
        ///    lo local es de la persona que activa y borrarlo sería el daño contrario: solo se borra la zona;
        ///  · aquí hubo relanzamiento, el store **espeja**, y lo local ES el corpus que la persona acaba de
        ///    decidir no traerse. Borrar solo la zona lo deja entero y el espejo lo re-exporta a la zona
        ///    recién creada — un borrado que no borra, que es el bug de este case.
        ///
        /// Su «volver» tampoco es el mismo: vuelve a `.restore`, de donde vino. `backFromRestore` tras un
        /// relanzamiento es CANCELAR (`screenBeforeRestore(hasResume: true) == nil`), así que reusar aquel
        /// camino echaría de la activación a quien solo se arrepintió de un botón.
        ///
        /// Va al FINAL del enum a propósito: un case nuevo en medio cambia el número de los `alert`
        /// diagnósticos que se derivan de su orden.
        case restoreDiscardGate
    }

    /// De dónde sale el prefill del onboarding, y con él qué hace su commit.
    enum OnboardingSource: Equatable {
        /// Lo personal en el iCloud privado. Prefill de Grupos (nombre y divisa).
        case freshPrivate
        /// Lo personal en la nube. Prefill de Grupos; el commit PROMOCIONA la cuenta antes de escribir nada.
        case freshCloud
        /// Tras restaurar de iCloud sin datos completos. El prefill es el RESUMEN RESTAURADO y no el de
        /// Grupos: al restaurar, gana lo restaurado (decisión de Jürgen, 2026-09-09).
        case restored(ICloudAccountSummary)
    }

    /// La pantalla con la que abre la sheet.
    ///
    /// **El eje de sesión va ANTES que la reanudación** (review adversarial, 2026-09-11). La primera versión
    /// hacía ganar a la marca «por definición» —quien reabre a mitad sigue en solo-grupos—, y eso solo es
    /// cierto en ESTE dispositivo: si otro del mismo Apple ID termina su activación, `.completed` llega aquí
    /// por el iCloud-KV (merge never-downgrade) y la marca abría un onboarding a alguien ya completo — cuya
    /// cancelación, encima, le armaba el mount neutro y le apagaba el espejo para siempre.
    ///
    /// - Parameters:
    ///   - isGroupsOnlySession: no hay sesión privada en este dispositivo (`PrivateSessionMark`), el estado
    ///     F de la matriz.
    ///   - resume: la marca de reanudación tras un relanzamiento (`FullModeActivationResumeStore`).
    ///   - isLegacyMirroredInstall: `isLegacyMirroredInstall(...)`, abajo.
    ///   - visibleOptions: el gate del chooser, el MISMO del Welcome (`WelcomeNewOptionsGate.live`).
    static func initialScreen(
        isGroupsOnlySession: Bool,
        resume: FullModeActivationResumeStore.Step?,
        isLegacyMirroredInstall: Bool,
        visibleOptions: [Option]
    ) -> Screen {
        guard isGroupsOnlySession else { return .legacyOnboarding }
        switch resume {
        case .privateOnboarding: return .onboarding(.freshPrivate)
        case .restore: return .restore
        case nil: break
        }
        guard !isLegacyMirroredInstall else { return .reinstallNotice }
        if let single = WelcomeAccountChoiceLogic.bypass(visibleOptions) { return screen(for: single) }
        return .chooser
    }

    /// **Una sesión solo-grupos que YA espeja iCloud**: la dio de alta un build anterior al paso 5, que no
    /// armaba el neutro duradero, así que desde su segundo arranque el espejo está puesto y puede haber bajado
    /// el corpus viejo del Apple ID (decisión de Jürgen del paso 5: sin migración, «se cura al reinstalar»).
    ///
    /// Sobre ese store ninguna rama es segura: el borrado de la puerta es solo de la zona (lo local nunca vino
    /// de iCloud… salvo aquí) y deja lo importado para que el espejo lo vuelva a subir; y la nube lo subiría a
    /// la cuenta como semilla, que es una migración y no un alta. Por eso se reinstala antes.
    ///
    /// Los términos que lo DESCARTAN: la marca del neutro puesta (cualquier alta del paso 5 en adelante, y la
    /// cancelación de una activación relanzada, que la re-arma), una reanudación en curso (el espejo lo
    /// adjuntó la propia activación) y XCUITest (su store es `cloudKitDatabase: .none` y el mount no se
    /// captura, así que el testigo dice «espejo» sin haberlo).
    static func isLegacyMirroredInstall(
        isGroupsOnlySession: Bool,
        mountAttachesMirror: Bool,
        groupsOnlyNeutralArmed: Bool,
        hasResume: Bool,
        isUITesting: Bool
    ) -> Bool {
        isGroupsOnlySession && mountAttachesMirror && !groupsOnlyNeutralArmed && !hasResume && !isUITesting
    }

    /// Qué abre cada card del chooser.
    static func screen(for option: Option) -> Screen {
        switch option {
        case .privateAccount: return .privateGate
        case .cloudAccount: return .consent
        }
    }

    /// Adónde lleva el «volver» de la puerta privada o del consentimiento. `nil` = no hubo chooser (una sola
    /// card visible, bypass), así que volver es cancelar la activación. Es el mismo término que decide el
    /// bypass: enseñarle al retroceder una pantalla que no vio sería peor que cerrar.
    static func originScreen(visibleOptions: [Option]) -> Screen? {
        WelcomeAccountChoiceLogic.bypass(visibleOptions) == nil ? .chooser : nil
    }

    // MARK: - Cancelar

    /// Lo que deshace «cancelar» (la X del onboarding, «volver» en Restaurar).
    enum CancelEffect: Equatable {
        /// La activación no llegó a relanzar: no hay nada que deshacer.
        case nothing
        /// Relanzó para el onboarding PRIVADO: volver a solo-grupos es volver a su mount neutro. Sin re-armar
        /// la marca, el arranque siguiente seguiría espejando una sesión solo-grupos (el bug del paso 5).
        case revertToGroupsOnly
        /// Relanzó para RESTAURAR: el espejo ya está bajando el corpus. Volver a solo-grupos dejaría ese corpus
        /// debajo de una sesión que no es privada, y el bridge de solo-grupos borra las transacciones reales
        /// que re-puentea. **No se vuelve atrás**: se cierra la sheet y la activación queda a medias —el bridge
        /// cerrado— hasta terminarla, o hasta cerrar sesión, que es la salida del modelo para dejar una privada.
        case keepPending
        /// La marca es de una activación que ya no aplica (este dispositivo dejó de ser solo-grupos): se retira
        /// y NO se toca el mount.
        case dropStaleMark
    }

    static func cancelEffect(resume: FullModeActivationResumeStore.Step?, isGroupsOnlySession: Bool) -> CancelEffect {
        guard let resume else { return .nothing }
        guard isGroupsOnlySession else { return .dropStaleMark }
        switch resume {
        case .privateOnboarding: return .revertToGroupsOnly
        case .restore: return .keepPending
        }
    }

    /// «Volver» en la pantalla de Restaurar. Tras relanzar, es cancelar (y `cancelEffect` dice que no deshace
    /// nada); sin relanzamiento, la puerta que llevó hasta aquí sigue siendo el paso anterior.
    static func screenBeforeRestore(hasResume: Bool) -> Screen? {
        hasResume ? nil : .privateGate
    }

    // MARK: - El commit, y su orden

    /// Los pasos con los que se cierra la activación. **El orden ES la decisión** y no un detalle:
    enum CommitStep: Equatable {
        /// La cuenta en la nube pasa de solo-grupos a completa (`POST /account/claim`).
        case promote
        /// `.cloud` + `mirrorOffArmed` + marca born-cloud, y arranque del motor de sync personal.
        case activateCloudStorage
        /// Lo que [P] tenía en memoria llega al store: cuenta, categorías, notificaciones y preferencias.
        case persistOnboarding
        /// La respuesta a «¿traemos tus gastos de grupo?».
        case applyHistoryChoice
        /// Modo `.completed`, barra de pestañas, y fuera las marcas de la activación.
        case completeActivation
        /// Converger los gastos de grupo con el corpus restaurado (`GroupsBridgeRestoreConvergence`).
        case convergeGroupsBridge
    }

    /// El plan de cierre de cada recorrido.
    ///
    /// - **Nube**: la promoción va PRIMERO entre las escrituras y DESPUÉS de que [P] termine (decisión de
    ///   Jürgen: «la promoción a `complete` es el último paso; si el usuario abandona a mitad, sigue siendo
    ///   solo-grupos»). Y el almacenamiento nube se activa ANTES de persistir [P], por dos motivos medidos:
    ///   `PreferenceSyncService` decide el destino de cada preferencia por el `behavior` del INSTANTE en que
    ///   se escribe —con `.icloud` iría al iCloud-KV y nunca llegaría a la cuenta—, y es el mismo orden que el
    ///   alta born-cloud (`activateBornCloudStorage` se invoca «antes de sembrar nada»).
    /// - **Privado**: sin servidor que tocar; lo personal ya se sincroniza por el espejo de iCloud.
    /// - **Restaurado**: la activación (modo `.completed`) va ANTES de converger, y no es un matiz: con la
    ///   sesión todavía en solo-grupos el bridge BORRA toda transacción real del gasto que re-puentea
    ///   (`GroupTransactionBridge.createGroupsOnlyCaseAVirtualPair`), o sea las que el usuario había
    ///   clasificado en su vida anterior y acaban de volver de iCloud.
    static func commitPlan(for source: OnboardingSource) -> [CommitStep] {
        switch source {
        case .freshPrivate:
            return [.persistOnboarding, .applyHistoryChoice, .completeActivation]
        case .freshCloud:
            return [.promote, .activateCloudStorage, .persistOnboarding, .applyHistoryChoice, .completeActivation]
        case .restored:
            return [.persistOnboarding, .completeActivation, .convergeGroupsBridge]
        }
    }

    /// Restaurar con los datos completos no pasa por el onboarding: el resumen restaurado ya trae todo.
    static let restoredWithoutOnboardingPlan: [CommitStep] = [.completeActivation, .convergeGroupsBridge]

    /// ¿Hay que dejar DURABLE la intención de converger antes de empezar? Se marca al principio del plan y no
    /// en su paso: un kill entre el modo `.completed` y la convergencia dejaría cada gasto dos veces para
    /// siempre, y lo que se difiere siendo una INTENCIÓN tiene que sobrevivir al proceso (regla del repo).
    static func needsDurableConvergence(_ plan: [CommitStep]) -> Bool {
        plan.contains(.convergeGroupsBridge)
    }

    // MARK: - La promoción

    /// Qué hace la activación con cada desenlace del claim.
    enum PromotionStep: Equatable {
        /// La fila ligera de grupos se promocionó (`created`): seguir con el commit.
        case commit
        /// No se puede promocionar y reintentar no lo cambia. **Nada se ha escrito**, ni aquí ni en el servidor.
        case blocked(PromotionBlock)
        /// Red caída, 5xx o respuesta ilegible. Reintentar no escribe nada que no hiciera ya el primero, y
        /// termina: si el servidor llegó a promocionar y la respuesta se perdió, el reintento de ESTE teléfono
        /// sobre la cuenta todavía vacía vuelve a contestar `created` (`qa/cloud/g16_01_…`, 2026-09-24; antes
        /// contestaba `existing_stable` y bloqueaba — ticket `claim-promotion-lost-response-blocks-the-retry`).
        /// Salvo que otro teléfono haya entrado entretanto por el adopt: entonces bloquea
        /// (`qa/cloud/g16_02_…`).
        case retry
    }

    enum PromotionBlock: Equatable {
        /// `existing_stable`: la cuenta ya tiene lo personal reclamado —desde otro dispositivo, o es una cuenta
        /// que volvió a iCloud—. Sembrar aquí un segundo corpus sería una fusión, que el ADR descartó.
        /// Desde g16_01 NO sale para el reintento de este mismo teléfono sobre una cuenta en la que nadie ha
        /// escrito nada personal: eso es el mismo alta repetido y el servidor contesta `created`. SÍ sale si el
        /// que promocionó fue otro teléfono (aunque aún no haya escrito: su alta está en curso), si ya se
        /// subió algo personal, preferencias incluidas, o si otro teléfono ya entró en la cuenta por el adopt
        /// aunque no haya subido nada (`qa/cloud/g16_02_…`, ticket
        /// `claim-replay-can-seed-beside-a-phone-that-adopted-silently`).
        case accountAlreadyHasPersonalData
        /// `claiming_in_progress`: otro dispositivo lidera una migración de esta cuenta.
        case anotherDeviceIsMoving
        /// 401, o sin token con la sesión borrada: la sesión de la cuenta ya no está viva. Sin token y con la sesión
        /// guardada no llega aquí: es `.retry` (2026-09-16, `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`).
        case sessionExpired
        /// 403, o un desenlace que la rama born-cloud no puede producir.
        case accountUnavailable
    }

    /// La tabla. `BornCloudSignUpService.signUp()` es el alta de siempre: con la fila ligera de grupos,
    /// `claim_account` la PROMOCIONA y contesta `created` (`qa/cloud/g15_01_account_kind.sql`, rama
    /// «PROMOCIÓN de fila ligera»), así que `.seeded` es exactamente «la cuenta acaba de pasar a completa».
    static func promotionStep(for outcome: BornCloudSignUpOutcome) -> PromotionStep {
        switch outcome {
        case .seeded:
            return .commit
        case .routeReturningUser:
            return .blocked(.accountAlreadyHasPersonalData)
        case .waitForLeader:
            return .blocked(.anotherDeviceIsMoving)
        case .sessionExpired:
            return .blocked(.sessionExpired)
        case .accountUnavailable:
            return .blocked(.accountUnavailable)
        case .providerMismatch:
            // Inalcanzable desde la rama born-cloud (`BornCloudSignUpService.signUp`, su docblock). Si la
            // tabla de `AccountClaimDecision` cambiara, lo seguro es NO sembrar.
            return .blocked(.accountUnavailable)
        case .transient:
            return .retry
        }
    }

    // MARK: - El historial de grupos

    /// ¿Se pregunta «¿traemos tus gastos de grupo?»?
    ///
    /// **Las filas ya existen**, y eso es lo que el ticket no sabía: el bridge de solo-grupos crea cada gasto
    /// en la cuenta de sistema «Grupos» del store personal, y sin tocar nada salen en Panel, Registros,
    /// Estadísticas y Presupuestos en cuanto la app es completa. Sin ninguna, no hay nada que decidir.
    ///
    /// Tras restaurar NO se pregunta: la decisión de Jürgen ata la pregunta al onboarding, y restaurar es la
    /// vida anterior del usuario volviendo como estaba.
    static func shouldAskHistory(source: OnboardingSource, bridgedGroupExpenseCount: Int) -> Bool {
        guard bridgedGroupExpenseCount > 0 else { return false }
        switch source {
        case .freshPrivate, .freshCloud: return true
        case .restored: return false
        }
    }

    enum HistoryChoice: Equatable {
        /// «Sí, mostrarlos».
        case showInPersonal
        /// «No, dejarlos en Grupos».
        case keepInGroups
    }

    /// Las cuatro superficies personales por las que se ven los gastos de grupo.
    struct GroupVisibility: Equatable {
        /// `includeGroupTransactionsInFeed` — Registros.
        let feed: Bool
        /// `includeGroupsInPanelTotal` — el total del Panel.
        let panelTotal: Bool
        /// `includeGroupTransactionsInStats` — Estadísticas.
        let stats: Bool
        /// `Budget.includeSharedExpenses` de los presupuestos que ya existen — el que acaba de crear [P].
        /// No es un toggle global: es un campo POR presupuesto, y sin él un «No» dejaba que los gastos de grupo
        /// consumieran el presupuesto que la persona creó en el mismo onboarding (review adversarial).
        let budgets: Bool
    }

    /// **Ninguno de los dos caminos escribe una sola transacción**, y es a propósito: «Sí» deja las filas que
    /// ya están —cero escrituras, cero duplicados por construcción— y «No» las saca de lo personal con los
    /// ajustes que ya existen, sin borrar nada y reversible. Lo que «No» NO puede hacer sin estado sincronizado
    /// es limitarse al pasado: también oculta los que vengan después, reales incluidos, y el copy lo dice.
    /// Está en el ticket `groups-history-cutoff-needs-synced-state`.
    static func groupVisibility(for choice: HistoryChoice) -> GroupVisibility {
        switch choice {
        case .showInPersonal: return GroupVisibility(feed: true, panelTotal: true, stats: true, budgets: true)
        case .keepInGroups: return GroupVisibility(feed: false, panelTotal: false, stats: false, budgets: false)
        }
    }
}

// MARK: - La reanudación tras relanzar

/// Dónde se recuerda que una activación privada está a medias porque la app tuvo que reabrirse.
///
/// **Por qué no basta con el destino del Welcome** (`WelcomePendingDestinationStore`, que es quien marca el
/// terminal «reabre Yala»): de ese almacén cuelga también la salida del proceso al pasar a segundo plano
/// (`RelaunchNetLogic.shouldExitOnBackground`), así que tiene que retirarse en cuanto el arranque siguiente lo
/// lee. Si la activación viviera de él, pasar a segundo plano durante el onboarding reanudado mataría la app.
/// Al consumirlo, el arranque lo convierte en esta marca, que no mata nada y sobrevive a un kill.
nonisolated enum FullModeActivationResumeStore {

    enum Step: String, CaseIterable, Equatable {
        /// Relanzó para adjuntar el espejo y sigue en el onboarding personal privado.
        case privateOnboarding
        /// Relanzó para adjuntar el espejo y sigue en «Restaurar mis datos».
        case restore
    }

    static let key = "fullModeActivation.resumeStep"

    static func set(_ step: Step, defaults: UserDefaults = .standard) {
        defaults.set(step.rawValue, forKey: key)
    }

    static func peek(_ defaults: UserDefaults = .standard) -> Step? {
        defaults.string(forKey: key).flatMap(Step.init(rawValue:))
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    /// Qué destino del relanzamiento corresponde a cada paso, y al revés. Exhaustivo a propósito: un destino
    /// nuevo del Welcome tiene que declarar que NO es de la activación.
    static func step(for destination: WelcomeMirrorRelaunchLogic.Destination) -> Step? {
        switch destination {
        case .fullActivationPrivate: return .privateOnboarding
        case .fullActivationRestore: return .restore
        // `groupsInvite` cae con `groupsOrganizer`: los dos los escribe la puerta de Grupos del Welcome
        // para retomarse A SÍ MISMA tras la vuelta al neutro, y ninguno es un paso de la activación.
        case .privateOnboarding, .restoreICloud, .inviteRecovery, .cloudAccount, .cloudSignIn,
             .groupsOrganizer, .groupsInvite:
            return nil
        }
    }

    static func destination(for step: Step) -> WelcomeMirrorRelaunchLogic.Destination {
        switch step {
        case .privateOnboarding: return .fullActivationPrivate
        case .restore: return .fullActivationRestore
        }
    }

    /// ¿Hay una activación privada a medias —con el relanzamiento pedido o ya hecho—? Mientras la haya, el
    /// bridge no crea nada (`GroupTransactionBridge.isDomainOpenForBridge`): la sesión sigue siendo
    /// solo-grupos y el espejo ya puede estar bajando un corpus con transacciones reales, que esa sesión
    /// borra al re-puentear.
    static func isPrivateActivationInFlight(
        pending: WelcomeMirrorRelaunchLogic.Destination?,
        current: Step?
    ) -> Bool {
        pending.flatMap(step(for:)) != nil || current != nil
    }

    /// El arranque de un returning user frente a lo que dejó pendiente la activación.
    struct BootResolution: Equatable {
        /// Retirar el destino del relanzamiento (y con él la salida al pasar a segundo plano).
        let consumesPendingDestination: Bool
        /// La reanudación que hay que escribir ANTES de consumir el destino (kill-safety).
        let writesResume: Step?
        /// Retirar una marca que ya no aplica.
        let clearsResume: Bool
        /// Reabrir la sheet de la activación.
        let presentsActivation: Bool

        static let nothing = BootResolution(
            consumesPendingDestination: false, writesResume: nil, clearsResume: false, presentsActivation: false)
    }

    /// Solo se consume un destino que SEA de la activación: los del Welcome los consume
    /// `presentNextOnboardingScreen`, que es la población contraria (onboarding sin completar).
    ///
    /// **Y solo se retoma una activación si el dispositivo sigue en solo-grupos.** Si dejó de estarlo —otro
    /// dispositivo del mismo Apple ID la terminó y `.completed` llegó por el iCloud-KV, o se vaciaron los
    /// datos—, lo pendiente se RETIRA: el destino se consume igual (si no, `exit(0)` en cada paso a segundo
    /// plano) y la marca se borra, sin reabrir nada.
    static func resolveAtBoot(
        pending: WelcomeMirrorRelaunchLogic.Destination?,
        current: Step?,
        isGroupsOnlySession: Bool
    ) -> BootResolution {
        let pendingStep = pending.flatMap(step(for:))
        guard isGroupsOnlySession else {
            return BootResolution(consumesPendingDestination: pendingStep != nil, writesResume: nil,
                                  clearsResume: current != nil, presentsActivation: false)
        }
        if let pendingStep {
            return BootResolution(consumesPendingDestination: true, writesResume: pendingStep,
                                  clearsResume: false, presentsActivation: true)
        }
        return BootResolution(consumesPendingDestination: false, writesResume: nil,
                              clearsResume: false, presentsActivation: current != nil)
    }
}
