//
//  FullModeActivationView.swift
//  Yala
//
//  «Activar Yala completo» desde una sesión solo-grupos. **Paso 8 del rediseño de sesiones: antes del
//  onboarding se pregunta dónde van a vivir los datos personales** — el iCloud privado o la cuenta en la
//  nube que ya usa para grupos (ADR 2026-09-09 §8). Hasta este paso la vista reusaba `OnboardingView` sin más
//  y lo personal aterrizaba en el store que estuviera montado, sin que nadie preguntara.
//
//  La vista es una máquina de pantallas. Lo que decide cada transición, el ORDEN del cierre y lo que deshace
//  «cancelar» vive en `FullModeActivationFlowLogic`, que tiene test; aquí solo se ejecuta. Todo ocurre DENTRO
//  de esta sheet —chooser, puerta de iCloud, consentimiento, onboarding y restaurar—, y no es comodidad: cada
//  presentación nueva colgando del anchor de `ContentView` entraría en la matriz de readiness (regla 3 de
//  Presentaciones).
//
//  Lo que se reusa sin copiarlo: el chooser y su gate (`WelcomeNewChooserView`, `WelcomeNewOptionsGate`), la
//  puerta de iCloud del paso 4 (`WelcomePrivateICloudGateView`), el terminal y el destino durable del
//  relanzamiento (`WelcomeMirrorRelaunchView`, `WelcomePendingDestinationStore`), el restore de «Ya tengo
//  cuenta» (`WelcomeRestoreView`) y el alta born-cloud (`BornCloudSignUpService`), que con la fila ligera de
//  grupos PROMOCIONA la cuenta en vez de crear otra.
//

import SwiftData
import SwiftUI
import os

struct FullModeActivationView: View {
    /// El borrado de la zona de iCloud de la puerta privada, SIN tocar lo local. Vive en `ContentView`, que es
    /// quien tiene la sonda y el `modelContext`.
    var performICloudZoneWipe: @MainActor () async -> String?
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    /// D1: al activar Yala completo desde «Solo mis grupos» hay que resetear el foco de la shell
    /// (si no, `usageFocus == .groupsOnly` residual mantendría la app reducida pese al onboarding).
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var screen: FullModeActivationFlowLogic.Screen
    /// Lo que TAPA el onboarding al terminar [P]: la pregunta del historial, la promoción y sus desenlaces.
    @State private var finale: FullModeActivationFinale?
    @State private var prefilledSummary: ICloudAccountSummary?
    /// El `commit` que entregó `OnboardingView` al terminar [P]. Solo vale mientras el onboarding siga
    /// montado —lee su `@State`—, y por eso el cierre lo TAPA con `finale` en vez de sustituirlo, y cancelar
    /// está bloqueado mientras el plan corre.
    @State private var pendingCommit: (() -> Void)?
    @State private var pendingSource: FullModeActivationFlowLogic.OnboardingSource?
    @State private var historyChoice: FullModeActivationFlowLogic.HistoryChoice?
    /// Un plan a la vez: el doble toque en «Empezar a usar Yala» o en «Reintentar» no puede lanzar dos claims.
    @State private var isRunningPlan = false

    init(
        performICloudZoneWipe: @escaping @MainActor () async -> String?,
        onComplete: @escaping () -> Void
    ) {
        self.performICloudZoneWipe = performICloudZoneWipe
        self.onComplete = onComplete
        let resume = FullModeActivationResumeStore.peek()
        let isGroupsOnly = SessionState.shared.isGroupInviteMode
        _screen = State(initialValue: FullModeActivationFlowLogic.initialScreen(
            isSecondarySession: SecondarySessionStore.isActive(),
            isGroupsOnlySession: isGroupsOnly,
            resume: resume,
            isLegacyMirroredInstall: FullModeActivationFlowLogic.isLegacyMirroredInstall(
                isGroupsOnlySession: isGroupsOnly,
                mountAttachesMirror: SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror,
                groupsOnlyNeutralArmed: StorageModePersistence.isGroupsOnlyNeutralMountArmed(),
                hasResume: resume != nil,
                isUITesting: SwiftDataConfiguration.isUITesting),
            visibleOptions: WelcomeNewOptionsGate.live))
    }

    var body: some View {
        ZStack {
            screenView
                // **Tapado es tapado también para VoiceOver y para el dedo** (review adversarial, 2026-09-11). Una
                // vista cubierta en un `ZStack` sigue entera en el árbol de accesibilidad: sin esto, un usuario de
                // VoiceOver llegaba por barrido a la X del onboarding durante «Activando tu cuenta…», cerraba la
                // sheet, y el plan seguía en su `Task` con el onboarding ya desmontado.
                .accessibilityHidden(finale != nil)
                .allowsHitTesting(finale == nil)
                .transition(.opacity)

            if let finale {
                FullModeActivationFinaleView(
                    finale: finale,
                    onShowHistory: { answerHistory(.showInPersonal) },
                    onKeepHistoryInGroups: { answerHistory(.keepInGroups) },
                    onRetry: { runPendingPlan() },
                    onLeave: { cancelActivation() })
                .transition(.opacity)
            }
        }
        // Deslizar para cerrar, solo en el chooser: ahí todavía no ha pasado nada. En el resto hay trabajo en
        // vuelo (la sonda, el borrado, el claim) o un estado que deshacer (el neutro tras relanzar), y eso lo
        // hacen las salidas explícitas, que son las que saben deshacerlo.
        .interactiveDismissDisabled(screen != .chooser || finale != nil)
        .onAppear {
            if prefilledSummary == nil { prefilledSummary = buildPrefilledSummary() }
        }
    }

    // MARK: - Pantallas

    @ViewBuilder
    private var screenView: some View {
        switch screen {
        case .chooser:
            WelcomeNewChooserView(
                options: WelcomeNewOptionsGate.live,
                onSelect: { option in go(to: FullModeActivationFlowLogic.screen(for: option)) },
                onBack: { cancelActivation() },
                context: .fullActivation)
        case .privateGate:
            WelcomePrivateICloudGateView(
                onProceed: { proceed(to: .fullActivationPrivate, otherwise: .onboarding(.freshPrivate)) },
                onRestore: { proceed(to: .fullActivationRestore, otherwise: .restore) },
                onBack: { backFromBranch() },
                // Re-envuelto y no reenviado: pasar la property directa convierte un valor de función
                // no-Sendable y avisa (`may introduce data races`). Mismo remedio que `WelcomeFlowContainer`.
                performWipe: { await performICloudZoneWipe() },
                clearsResidualPreferencesOnWipe: false)
        case .relaunch:
            WelcomeMirrorRelaunchView()
        case .consent:
            CloudConsentView(
                path: .bornCloud,
                onAccept: { go(to: .onboarding(.freshCloud)) },
                onCancel: { backFromBranch() })
        case .onboarding(let source):
            onboarding(source)
        case .restore:
            WelcomeRestoreView(
                onContinueWithSummary: { summary in finishRestoreSearch(summary) },
                // Mismo desenlace que en el Welcome: empezar de cero es el onboarding personal, sin restaurar.
                // Lo que ese botón NO hace con lo ya importado es un defecto heredado del Welcome, con su
                // ticket (`restore-start-fresh-keeps-the-imported-corpus`).
                onStartFresh: { go(to: .onboarding(.freshPrivate)) },
                onOpenSettings: { openSettings() },
                onBack: { backFromRestore() })
        case .reinstallNotice:
            FullModeActivationFinaleView(
                finale: .reinstallRequired,
                onShowHistory: {},
                onKeepHistoryInGroups: {},
                onRetry: {},
                onLeave: { cancelActivation() })
        case .legacyOnboarding:
            OnboardingView(
                prefilledData: prefilledSummary,
                backgroundStyle: .themedPanel,
                mode: .fullActivation,
                onCancel: { onComplete() },
                onComplete: { completeFullActivation() })
            .onAppear { cleanupResidualGeneralAccount() }
        }
    }

    /// El onboarding de la activación. **No se monta hasta que hay prefill** (review adversarial): el `init` de
    /// `OnboardingView` fija su primer paso con el prefill que recibe, y el de Grupos se construye en el
    /// `.onAppear` de la raíz. Tras un relanzamiento esta es la PRIMERA pantalla, así que sin esperar al
    /// prefill arrancaba en «Nombre» —que el plan de pasos salta— y perdía la divisa del grupo.
    @ViewBuilder
    private func onboarding(_ source: FullModeActivationFlowLogic.OnboardingSource) -> some View {
        if let prefill = prefill(for: source) {
            OnboardingView(
                prefilledData: prefill,
                backgroundStyle: .themedPanel,
                mode: .fullActivation,
                onCancel: { cancelActivation() },
                beforeCommit: { commit in onboardingFinished(source: source, commit: commit) },
                onComplete: {
                    // Vacío a propósito: el cierre lo conduce el plan (`run`), y `commit()` acaba llamando aquí a
                    // mitad de él. Cerrar la sheet en este punto se saltaría los pasos que van detrás.
                })
            .onAppear {
                // Solo en los onboardings NUEVOS: tras restaurar, una cuenta `.general` vacía puede ser del usuario.
                if case .restored = source { return }
                cleanupResidualGeneralAccount()
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// El prefill del onboarding. **Tras restaurar gana lo restaurado** (decisión de Jürgen): el nombre y la
    /// divisa que venían de Grupos se descartan y el onboarding arranca con el resumen de iCloud.
    private func prefill(for source: FullModeActivationFlowLogic.OnboardingSource) -> ICloudAccountSummary? {
        switch source {
        case .freshPrivate, .freshCloud: return prefilledSummary
        case .restored(let summary): return summary
        }
    }

    // MARK: - Transiciones

    private func go(to next: FullModeActivationFlowLogic.Screen) {
        let animation: Animation? = reduceMotion ? nil : .smooth(duration: 0.4)
        withAnimation(animation) { screen = next }
    }

    /// «Volver» desde la puerta privada o desde el consentimiento: al chooser si lo hubo; si no (bypass con una
    /// sola card), volver es cancelar.
    private func backFromBranch() {
        if let origin = FullModeActivationFlowLogic.originScreen(visibleOptions: WelcomeNewOptionsGate.live) {
            go(to: origin)
        } else {
            cancelActivation()
        }
    }

    /// «Volver» en Restaurar: a la puerta si no hubo relanzamiento; tras relanzar, cancelar — que para
    /// Restaurar NO deshace nada (`FullModeActivationFlowLogic.CancelEffect.keepPending`).
    private func backFromRestore() {
        let hasResume = FullModeActivationResumeStore.peek() != nil
        if let previous = FullModeActivationFlowLogic.screenBeforeRestore(hasResume: hasResume) {
            go(to: previous)
        } else {
            cancelActivation()
        }
    }

    /// Salir de la puerta privada hacia lo que viene después, relanzando si el espejo no está puesto.
    ///
    /// **El orden de las tres escrituras de abajo es el de la kill-safety**, y conviene ser exacto sobre lo que
    /// cubre: el destino durable va PRIMERO, así que un kill tras él arranca todavía en neutro —la marca sigue
    /// puesta— y el arranque encuentra el destino y retoma la activación en el paso elegido, pero sin espejo:
    /// el onboarding privado se completa sobre el store neutro y el espejo se adjunta en el arranque siguiente;
    /// Restaurar no encuentra nada que importar hasta entonces. Al revés, un kill tras levantar la marca y antes
    /// del destino dejaría el espejo puesto sobre una sesión solo-grupos sin nada que lo retome. Entre dos
    /// escrituras síncronas seguidas no hay más atomicidad posible: `UserDefaults` no tiene transacciones.
    private func proceed(
        to destination: WelcomeMirrorRelaunchLogic.Destination,
        otherwise next: FullModeActivationFlowLogic.Screen
    ) {
        guard WelcomeMirrorRelaunchLogic.shouldRelaunch(
            destination: destination,
            mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision) else {
            // No hay mount neutro que romper (XCUITest; una instalación con el espejo ya puesto no llega aquí,
            // la para `reinstallNotice`): se sigue en este mismo proceso.
            go(to: next)
            return
        }
        WelcomePendingDestinationStore.set(destination)
        // El anti-bucle del neutro R4, el mismo que pone `onNeedsMirrorRelaunch` en el Welcome: con la marca
        // `neutralMountArmed` puesta (la deja un cierre de sesión) y el chooser sin marcar, el arranque
        // siguiente volvería a montar neutro y el terminal «reabre Yala» no terminaría nunca.
        appPreferences.hasShownWelcomeChooser = true
        // Y se levanta el neutro solo-grupos: **esta es la rama privada**, que es la que el ticket pedía que se
        // lo llevara (antes lo levantaba la activación entera, sin preguntar nada).
        StorageModePersistence.clearGroupsOnlyNeutralMountIfPrimary()
        go(to: .relaunch)
    }

    private func finishRestoreSearch(_ summary: ICloudAccountSummary) {
        if summary.isFullyPrefilled {
            run(FullModeActivationFlowLogic.restoredWithoutOnboardingPlan)
        } else {
            go(to: .onboarding(.restored(summary)))
        }
    }

    /// Cancelar la activación. Lo que deshace lo decide `FullModeActivationFlowLogic.cancelEffect`.
    ///
    /// **Con un plan en vuelo no se cancela**: el claim puede haber contestado ya `created`, y cerrar aquí
    /// dejaría la cuenta completa en el servidor sin nada personal detrás —lo que la decisión de Jürgen
    /// prohíbe—, con el `commit` leyendo el `@State` de un onboarding desmontado.
    private func cancelActivation() {
        guard !isRunningPlan else { return }
        switch FullModeActivationFlowLogic.cancelEffect(
            resume: FullModeActivationResumeStore.peek(),
            isGroupsOnlySession: sessionState.isGroupInviteMode) {
        case .nothing, .keepPending:
            break
        case .revertToGroupsOnly:
            // El escritor de la marca retira también la reanudación: volver a solo-grupos es eso entero.
            StorageModePersistence.armGroupsOnlyNeutralMountIfPrimary()
            FullModeActivationResumeStore.clearIfPrimary()
        case .dropStaleMark:
            FullModeActivationResumeStore.clearIfPrimary()
        }
        onComplete()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - El cierre

    /// [P] terminó. Nada se ha escrito todavía: `commit` es lo que lo escribirá, y aquí se decide qué va antes.
    private func onboardingFinished(
        source: FullModeActivationFlowLogic.OnboardingSource,
        commit: @escaping () -> Void
    ) {
        guard finale == nil, !isRunningPlan else { return }
        pendingCommit = commit
        pendingSource = source
        if FullModeActivationFlowLogic.shouldAskHistory(
            source: source, bridgedGroupExpenseCount: bridgedGroupExpenseCount()) {
            finale = .history
        } else {
            runPendingPlan()
        }
    }

    private func answerHistory(_ choice: FullModeActivationFlowLogic.HistoryChoice) {
        historyChoice = choice
        runPendingPlan()
    }

    private func runPendingPlan() {
        guard let pendingSource else { return }
        run(FullModeActivationFlowLogic.commitPlan(for: pendingSource))
    }

    private func run(_ plan: [FullModeActivationFlowLogic.CommitStep]) {
        guard !isRunningPlan else { return }
        isRunningPlan = true
        if FullModeActivationFlowLogic.needsDurableConvergence(plan) {
            GroupsBridgeRestoreConvergenceStore.markPending()
        }
        // Un `Task` no estructurado y no `.task(id:)`, a propósito: cancelar un plan a medias —con el claim ya
        // contestado `created`— dejaría la cuenta completa en el servidor sin nada personal detrás, que es
        // exactamente el estado que la decisión de Jürgen prohíbe. Mientras corre, no hay salida que lo corte.
        Task { @MainActor in
            await execute(plan)
            isRunningPlan = false
        }
    }

    /// Ejecuta el plan en su orden. La promoción es el único paso que puede parar el plan, y para ANTES de la
    /// primera escritura local: lo que haya pasado hasta ahí no ha escrito nada.
    private func execute(_ plan: [FullModeActivationFlowLogic.CommitStep]) async {
        var promotion: BornCloudSignUpService?
        for step in plan {
            switch step {
            case .promote:
                finale = .promoting
                let service = BornCloudSignUpService(session: LiveCloudSessionProvider())
                let outcome = FullModeActivationFlowLogic.promotionStep(for: await service.signUp())
                FullModeActivationBreadcrumb.promotion(String(describing: outcome))
                switch outcome {
                case .commit:
                    promotion = service
                case .blocked(let block):
                    finale = .blocked(block)
                    return
                case .retry:
                    finale = .failed
                    return
                }
            case .activateCloudStorage:
                // Inalcanzable sin `promotion`: el plan pone `.promote` delante. Si alguien reordena el plan, lo
                // seguro es NO escribir el par `.cloud` para una cuenta que no se ha promocionado.
                guard let promotion else { return }
                let terminal = promotion.activateBornCloudStorage(
                    mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision,
                    context: modelContext)
                // `.relaunch` solo sale con el espejo ya adjunto, y ese mount no llega a la nube: lo para
                // `reinstallNotice` antes del chooser. Queda el rastro por si alguien quita esa puerta.
                FullModeActivationBreadcrumb.cloudStorage(terminal: String(describing: terminal))
            case .persistOnboarding:
                pendingCommit?()
            case .applyHistoryChoice:
                applyHistoryChoice()
            case .completeActivation:
                completeFullActivation()
            case .convergeGroupsBridge:
                let context = modelContext
                Task { @MainActor in await GroupsBridgeRestoreConvergence.runAfterActivation(context: context) }
            }
        }
        if promotion != nil {
            // El tipo cacheado de la sesión era `groups_only`; el backend ya dice `complete`.
            Task { _ = await AccountKindService.shared.refresh() }
        }
    }

    /// La respuesta a «¿traemos tus gastos de grupo?». **No escribe ni una transacción**: las filas ya existen
    /// (las creó el bridge de solo-grupos) y lo que se decide es si se ven en lo personal. Sin pregunta —no
    /// había nada puenteado— no se toca nada.
    private func applyHistoryChoice() {
        guard let historyChoice else { return }
        let visibility = FullModeActivationFlowLogic.groupVisibility(for: historyChoice)
        appPreferences.includeGroupTransactionsInFeed = visibility.feed
        appPreferences.includeGroupsInPanelTotal = visibility.panelTotal
        appPreferences.includeGroupTransactionsInStats = visibility.stats
        // Los presupuestos no tienen toggle global: cada uno decide si cuenta los gastos compartidos. Los que
        // existen ahora son los que acaba de crear [P].
        do {
            let budgets = try modelContext.fetch(FetchDescriptor<Budget>())
            for budget in budgets where budget.includeSharedExpenses != visibility.budgets {
                budget.includeSharedExpenses = visibility.budgets
            }
            if modelContext.hasChanges { try modelContext.save() }
        } catch {
            #if DEBUG
            print("FullModeActivationView: Error applying the history choice to budgets: \(error)")
            #endif
        }
    }

    /// Cuántos gastos de grupo tienen ya filas en lo personal. Un fallo de lectura cuenta como cero: sin la
    /// pregunta, las filas se quedan como están, que es lo que ya pasaba antes de este paso.
    private func bridgedGroupExpenseCount() -> Int {
        do {
            let rows = try modelContext.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID != nil }))
            return Set(rows.compactMap(\.splitExpenseID)).count
        } catch {
            #if DEBUG
            print("FullModeActivationView: bridged count failed: \(error)")
            #endif
            return 0
        }
    }

    // MARK: - Prefill y limpieza

    /// `fetchCount` para Category es <10ms — invocado una vez en `.onAppear`.
    private func buildPrefilledSummary() -> ICloudAccountSummary {
        let categoriesCount: Int
        do {
            categoriesCount = try modelContext.fetchCount(
                FetchDescriptor<Category>(predicate: #Predicate { !$0.isSystem })
            )
        } catch {
            #if DEBUG
            print("FullModeActivationView: category fetchCount failed: \(error)")
            #endif
            categoriesCount = 0
        }
        return FullModeActivationLogic.buildSummary(
            userName: UserDefaults.standard.string(forKey: AppPreferences.Keys.userName),
            groupCurrency: GroupService.shared.mostRecentGroup()?.currencyCode,
            defaultCurrency: UserDefaults.standard.string(forKey: AppPreferences.Keys.defaultCurrencyCode),
            userCategoriesCount: categoriesCount
        )
    }

    /// Paranoid safeguard para QA con state acumulado de tests previos.
    /// En producción no hay legacy: groups no estaban en producción según decisión [2026-05-05].
    ///
    /// **Solo sin espejo adjunto** (review adversarial, 2026-09-11): con el espejo puesto, el store puede traer
    /// cuentas de iCloud cuyas transacciones todavía no han bajado —la relación llega vacía en la ventana
    /// lazy—, y este borrado se las llevaría y el espejo exportaría el borrado. XCUITest sigue igual: su store
    /// no espeja, aunque el testigo del mount diga lo contrario porque allí no se captura.
    private func cleanupResidualGeneralAccount() {
        guard SwiftDataConfiguration.isUITesting
            || !SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror else { return }
        let generalType = AccountType.general.rawValue
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate {
                $0.type == generalType && !$0.isSystemAccount
            }
        )
        do {
            let accounts = try modelContext.fetch(descriptor)
            for account in accounts where FullModeActivationLogic.shouldDeleteResidualGeneralAccount(
                type: account.type,
                isSystemAccount: account.isSystemAccount,
                hasTransactions: !(account.transactions?.isEmpty ?? true)
            ) {
                modelContext.delete(account)
            }
            try modelContext.save()
        } catch {
            // El cleanup es defensivo: un fallo no debe bloquear la activación full.
            #if DEBUG
            print("FullModeActivationView: cleanup de cuenta General residual falló: \(error)")
            #endif
        }
    }

    // MARK: - El paso final, común a todos los recorridos

    /// `OnboardingView.completeOnboarding` ya hizo seeds + account + notifs +
    /// `hasCompletedOnboarding=true` (o el restore trajo los suyos). Aquí cambiamos al modo `.completed` y
    /// expandimos el TabBar.
    private func completeFullActivation() {
        // **El orden de las marcas frente al modo es el de la kill-safety.** Las dos que cambian el arranque
        // siguiente —el borrado de iCloud armado y el neutro solo-grupos— salen ANTES de escribir `.completed`:
        // con cualquiera de las dos viva y el modo ya completo, ese arranque borraría a ciegas o montaría sin
        // espejo a quien acaba de elegir. La reanudación sale DESPUÉS (abajo).
        //
        // Un borrado de iCloud a medias (review adversarial, 2026-09-11). Si la app murió
        // durante el borrado de la puerta, su arm sobrevive; mientras la sesión es solo-grupos no se reanuda
        // (`runLateICloudMirrorCheck` sale antes), pero en cuanto la activación termina el arranque siguiente lo
        // reanudaría A CIEGAS —con el borrado local incluido— sobre el corpus que la persona acaba de crear o de
        // restaurar, y la mandaría al Welcome. A estas alturas la persona ya eligió dónde viven sus datos, que es
        // lo que deja sin efecto una petición de borrado anterior.
        StorageModePersistence.clearICloudCorpusWipeArmIfPrimary()
        // **Se levanta el neutro durable de solo-grupos** (paso 5 del rediseño). Activar Yala completo ES
        // «ya elegí dónde viven mis datos personales», y desde el paso 8 esto solo se alcanza DESPUÉS de haberlo
        // elegido: la rama privada ya lo levantó antes de relanzar, y en la de nube hace falta igual —con
        // `.cloud` + `mirrorOffArmed` el mount ya es sin espejo, pero si un día vuelve a iCloud («Volver a
        // iCloud»), una marca superviviente le montaría neutro y el espejo de la reversa no se adjuntaría nunca.
        //
        // **Gateado por sesión secundaria, igual que los dos sitios que la ARMAN.** En secundaria el
        // `UserDefaults` es el del DUEÑO: si él es solo-grupos y la invitada activa Yala completo (que en
        // secundaria ocurre en memoria, ver el guard de abajo), desarmar aquí le devolvería el espejo al
        // dueño en su próximo arranque — o sea le causaría el bug de este ticket desde la sesión de otra
        // persona. La simetría es la regla: quien no arma, no desarma.
        StorageModePersistence.clearGroupsOnlyNeutralMountIfPrimary()

        let sync = PreferenceSyncService.shared
        // M1 · frontera de cuenta. Este `set` escribe la key del modo por `PreferenceSyncService`
        // —que en `.localOnly` (sesión secundaria) sigue escribiendo el ESPEJO LOCAL, que desde el
        // 2026-09-12 es `UserDefaults.standard` para todos— así que el guard de
        // `OnboardingMode.setCurrent` no lo cubre: va aquí, en el escritor. `.completed` es rank 2 y el
        // merge es never-downgrade ⇒
        // escribirlo desde la sesión de la invitada deja al dueño una shell escalada que su
        // `.groupInvite` del iKV ya no puede recuperar, y el wipe de salida no repone la key.
        // La activación SÍ ocurre en memoria: la invitada ve su shell completa durante su sesión.
        //
        // Paso 8 · y es la activación quien escribe `.completed` también tras RESTAURAR: `RestoreRouter.decide`
        // lee el modo local, que es `.groupInvite`, y devolvería al usuario a solo-grupos.
        if !SecondarySessionStore.isActive() {
            sync.set(string: OnboardingMode.completed.rawValue, forKey: OnboardingMode.userDefaultsKey)
        }
        sessionState.onboardingMode = .completed
        // La reanudación, fuera — DESPUÉS del modo, a propósito: un kill entre las dos escrituras deja
        // `.completed` con la marca puesta, y el arranque la retira sola (`resolveAtBoot`, fuera de solo-grupos).
        // Al revés dejaría a quien ya guardó su onboarding en solo-grupos y sin nada que retome la activación.
        FullModeActivationResumeStore.clearIfPrimary()

        // D1: des-reducir la shell. DEBE ir ANTES de `selectMainTab(.panel)` — `effectiveShellMode`
        // es `.groupsFocused` mientras `usageFocus == .groupsOnly` (independiente de onboardingMode),
        // así que el guard GC-08 rechazaría `.panel` si el reset viniera después. No-op para
        // group-invite (usageFocus ya `.full`, guard del didSet).
        appPreferences.usageFocus = .full

        UserDefaults.standard.set(
            TabBarConfiguration.default.toJSON(),
            forKey: TabBarConfiguration.storageKey
        )
        sessionState.selectMainTab(.panel)

        onComplete()
    }
}

/// Rastro de la activación en producción. Mismo `subsystem`/`category` que `CloudSyncBreadcrumb`, y FUERA de
/// `#if DEBUG` a propósito: es la única forma de distinguir en un log de device por qué una activación a la
/// nube no terminó. Sin PII — ni el `sub`, ni el JWT, ni cifras.
enum FullModeActivationBreadcrumb {
    private static let logger = Logger(subsystem: "com.yala", category: "CloudSync")

    static func promotion(_ step: String) {
        logger.notice("FullModeActivation promotion=\(step, privacy: .public)")
    }

    static func cloudStorage(terminal: String) {
        logger.notice("FullModeActivation cloudStorage terminal=\(terminal, privacy: .public)")
    }
}
