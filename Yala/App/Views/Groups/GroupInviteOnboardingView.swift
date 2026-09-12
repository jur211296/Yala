//
//  GroupInviteOnboardingView.swift
//  Yala
//
//  Onboarding para usuarios que llegan por enlace de invitación a un grupo.
//  El step visible se deriva de la fase REAL del join intent
//  (`GroupJoinIntentTracker.phase` → `GroupInviteOnboardingLogic.step`) —
//  nunca un fallback optimista: el "¡Todo listo!" solo aparece con member
//  confirmado (bug 2026-07-11: el fallback defensivo mostraba éxito sin
//  member ni solicitud, y el owner nunca se enteraba).
//

import SwiftData
import SwiftUI

struct GroupInviteOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    @State private var userName: String = ""
    @State private var hasTappedJoin: Bool = false
    @State private var hitSoftTimeout: Bool = false
    @State private var timeoutTask: Task<Void, Never>?
    /// El campo de nombre se siembra UNA vez (ver `seedNameFromProfileIfNeeded`).
    @State private var didSeedName: Bool = false

    private var tracker: GroupJoinIntentTracker { .shared }

    /// ¿Esta persona ya tiene cuenta en este device? Decide **qué escribe el CTA**, no qué se muestra: la
    /// hoja es la misma para todos desde 2026-09-05 (ver el encabezado de `GroupsGateLogic`).
    ///
    /// Hasta el 2026-09-12 esto iba al CAJÓN de la sesión y no a `.standard` (decisión del owner,
    /// 2026-09-03); hoy hay un solo dominio. Aquello existía porque con `.standard` la
    /// pregunta la respondería la DUEÑA del teléfono, y a la visita se le haría el alta o no según el
    /// onboarding de otra persona.
    private var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
    }

    /// Nombre del perfil de ESTA sesión. Mismo dominio y misma clave que
    /// `GroupBackendInviteEntryHandler.profileNameProvider`, que es quien lo usa de fallback en el join:
    /// leerlos de dominios distintos daría un prellenado que no es el que acabaría enviándose.
    private var profileName: String {
        UserDefaults.standard.string(forKey: AppPreferences.Keys.userName) ?? ""
    }

    /// #22: marca del invite (nombre/icono/color del grupo) para personalizar el banner. Si nil o sin
    /// nada que pintar → fallback al copy/visual genérico.
    ///
    /// El tipo es `InviteLinkService.BrandedMetadata` —lo que de verdad viaja en el enlace— y no el
    /// antiguo `InviteMetadata`, que exigía un `CKShare.Metadata` del canal que la Fase 3 borró y por eso
    /// llegaba SIEMPRE `nil`: el copy `welcomeWithGroup` y estos dos computed llevaban meses siendo código
    /// vivo sin camino alcanzable.
    let inviteMetadata: InviteLinkService.BrandedMetadata?

    /// Zona (== `group_id`) de la invitación que esta hoja está presentando, tal como la trae el intent
    /// del router. **Sin ella la vista no puede decir de qué grupo habla**, y eso tenía dos consecuencias:
    /// el CTA reconciliaba TODAS las invitaciones vivas como si la persona las hubiera confirmado todas
    /// (`reconcile(trigger: .acceptShare)` sin zona), y no había forma de retirar UNA invitación al decir
    /// «más tarde». `nil` solo en previews y en el seam de XCUITest, donde no hay intent detrás.
    let pendingJoinZone: String?

    var onComplete: (GroupInviteOnboardingOutcome) -> Void

    init(
        inviteMetadata: InviteLinkService.BrandedMetadata? = nil,
        pendingJoinZone: String? = nil,
        onComplete: @escaping (GroupInviteOnboardingOutcome) -> Void
    ) {
        self.inviteMetadata = inviteMetadata
        self.pendingJoinZone = pendingJoinZone
        self.onComplete = onComplete
    }

    private var step: GroupInviteOnboardingLogic.Step {
        GroupInviteOnboardingLogic.step(
            hasTappedJoin: hasTappedJoin,
            phase: tracker.phase,
            hitSoftTimeout: hitSoftTimeout
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: DS.Spacing.xxl) {
                    switch step {
                    case .welcome: welcomeStep
                    case .joining: joiningStep
                    case .takingLong: takingLongStep
                    case .pendingApproval: pendingApprovalStep
                    case .active: completionStep
                    case .failed(let reason): failedStep(reason)
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
        }
        .onAppear { seedNameFromProfileIfNeeded() }
        .onChange(of: tracker.phase) { _, newPhase in
            // Fase terminal → el soft-timeout deja de tener sentido.
            switch newPhase {
            case .pendingApproval, .active, .failed:
                timeoutTask?.cancel()
                timeoutTask = nil
            default:
                break
            }
        }
        .onDisappear {
            timeoutTask?.cancel()
            timeoutTask = nil
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(groupColor)
                    .frame(width: 72, height: 72) // A11Y-DT: decorative hero icon, fixed size

                Image(systemName: groupIcon)
                    .font(.system(size: 32)) // A11Y-DT: decorative icon inside circle
                    .foregroundStyle(.white)
            }
            .glassEffect(.regular, in: Circle())

            VStack(spacing: DS.Spacing.sm) {
                Text(welcomeTitle)
                    .font(DS.Typography.title2)
                    .multilineTextAlignment(.center)

                Text(L10n.Groups.Invite.subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField(L10n.Groups.Invite.namePlaceholder, text: $userName)
                .font(DS.Typography.body)
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(.thCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .stroke(.thCardBorder, lineWidth: 1)
                )
                .padding(.horizontal, DS.Spacing.lg)

            Spacer()

            YalaPrimaryButton(L10n.Groups.Invite.joinButton) {
                handleJoinTap()
            }
            .accessibilityIdentifier("invite_join_button")
            .padding(.bottom, canDecline ? DS.Spacing.md : DS.Spacing.xxl)

            // **La salida, y por qué SOLO para quien ya tiene la app montada.** Al invitado FRESCO esta
            // hoja no le tapa nada: es su primera pantalla y detrás no hay app a la que volver, así que
            // dejarle salir le dejaría en una app sin dar de alta — un brick, no una salida. A quien ya
            // usa Yala sí le tapa lo suyo, y el cover se vuelve a montar en cada arranque mientras el
            // intent viva, así que sin esto un enlace tapeado por error le secuestra la app hasta que se
            // rinda y entre al grupo.
            //
            // Copy REUSADO (`action.later`, ya en los 16 idiomas): «ahora no», que es exactamente el
            // hecho. Cero cadenas nuevas.
            if canDecline {
                Button(L10n.Action.later) {
                    handleDeclineTap()
                }
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("invite_decline_button")
                .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .dismissKeyboardOnTap()
    }

    // MARK: - Step 3: Pending Approval

    private var pendingApprovalStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56)) // A11Y-DT: decorative hero icon, fixed size
                .foregroundStyle(DS.Semantic.warningForeground)

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Invite.waitingApprovalTitle)
                    .font(DS.Typography.title2)
                    .multilineTextAlignment(.center)

                Text(L10n.Groups.Invite.waitingApprovalBody)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
            }

            Spacer()

            YalaPrimaryButton(L10n.Action.continueAction) {
                complete(.pendingApproval)
            }
            .accessibilityIdentifier("invite_pending_continue")
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    /// ¿Se le puede ofrecer salir sin unirse? Solo a quien tiene app detrás — ver el comentario del botón.
    private var canDecline: Bool { hasCompletedOnboarding }

    /// «Más tarde»: retira ESTA invitación y cierra. Sin la zona no se retira nada y solo se cierra la
    /// vista, que es lo correcto en ese caso —no hay invitación que nombrar— y no ocurre en producción.
    private func handleDeclineTap() {
        if let pendingJoinZone {
            PendingJoinStore.clear(zoneName: pendingJoinZone)
        }
        complete(.declined)
    }

    // MARK: - Prellenado del nombre

    /// Siembra el campo con el nombre del perfil, UNA vez y solo si sigue vacío.
    ///
    /// Sin esto, desde que la hoja se presenta también a quien ya tiene cuenta (2026-09-05), a esa persona
    /// se le pedía su nombre **en blanco** —el `@State` arranca vacío— y si lo dejaba así se unía como
    /// «Usuario»: el fallback de `resolveJoinDisplayName` la habría salvado, pero el campo vacío ya le
    /// había dicho que Yala no sabe quién es. Es el mismo nombre que se enviaría por defecto, escrito donde
    /// puede cambiarlo.
    ///
    /// El `didSeed` no es defensivo: `onAppear` vuelve a correr al reaparecer la vista, y sin él una
    /// re-siembra pisaría lo que la persona acabara de teclear. Y solo siembra sobre vacío, para no pisar
    /// tampoco lo tecleado dentro de la misma aparición. Para un invitado FRESCO el perfil está vacío ⇒ el
    /// campo queda como estaba y su recorrido no cambia.
    private func seedNameFromProfileIfNeeded() {
        guard !didSeedName else { return }
        didSeedName = true
        guard userName.isEmpty else { return }
        userName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Join handler (A3)

    private func handleJoinTap() {
        guard !hasTappedJoin else { return }
        // **La bifurcación entera del arreglo está en esta línea, y no en lo que se ve.** La hoja es la
        // misma para todos; lo que su CTA ESCRIBE no puede serlo: el alta completa, corrida sobre una
        // cuenta que ya existe, le pisa preferencias vivas — y las tres peores (`userName`,
        // `defaultCurrencyCode`, `defaultPeriod`) van por `PreferenceSyncService`, o sea al iKV del Apple
        // ID, así que el daño le llega también a sus OTROS dispositivos. Tabla medida en
        // `performJoinOnlySetup`.
        //
        // **`hasCompletedOnboarding` es una key POR DEVICE** (`PreferenceSyncService`: «NOT synced»), así
        // que lo que este predicado pregunta de verdad es «¿este teléfono hizo el alta?» y no «¿esta
        // persona tiene cuenta?». Un segundo dispositivo, o una reinstalación de alguien con la cuenta
        // consolidada, responden `false` y toman el alta completa. **Es el comportamiento que ya había**
        // —esa misma condición era la puerta de la hoja antes de este cambio, así que quien la veía era
        // exactamente quien la tomaba— y por eso no se toca aquí: el hueco es real, es anterior, y
        // cerrarlo pide una señal de CUENTA que este camino no tiene.
        if hasCompletedOnboarding {
            performJoinOnlySetup()
        } else {
            performSilentSetup()
        }
        withAnimation { hasTappedJoin = true }
        // Camino rápido: si la zona ya materializó, el member nace ahora mismo y
        // la fase salta a pending/active sin esperar el próximo fetch.
        Task { @MainActor in
            // La zona ACOTA el `.userAction`: `reconcile` barre todas las entries vigentes, y sin este dato
            // tapear «Unirme» aquí confirmaba también las invitaciones que la persona no ha visto (y les
            // sellaba la hoja para siempre). Ver `GroupJoinReconciler.mapTrigger`.
            await GroupJoinReconciler.reconcile(trigger: .acceptShare, userConfirmedZone: pendingJoinZone)
        }
        startSoftTimeout()
    }

    private func startSoftTimeout() {
        timeoutTask?.cancel()
        hitSoftTimeout = false
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(softTimeoutSeconds))
            guard !Task.isCancelled else { return }
            withAnimation { hitSoftTimeout = true }
        }
    }

    private var softTimeoutSeconds: TimeInterval {
        #if DEBUG
        if let override = UITestHooks.shared.joinSoftTimeoutOverride { return override }
        #endif
        return GroupInviteOnboardingLogic.softTimeout
    }

    /// Cierre único del onboarding: policy de limpieza + navegación.
    private func complete(_ outcome: GroupInviteOnboardingOutcome) {
        switch outcome {
        case .joined, .pendingApproval:
            NudgeService.shared.recordGroupJoinIfNeeded()
        case .closedWhileSyncing, .abandonedAfterFailure, .declined:
            break
        }
        // El tracker se consume al confirmar unión o al abandonar sin recovery;
        // en pending/closedWhileSyncing sigue vivo alimentando el banner del tab.
        switch outcome {
        case .joined, .abandonedAfterFailure(recoverable: false):
            tracker.clear()
        case .declined:
            // Solo si el tracker seguía esta invitación. Es global (trackea UNA zona), así que un `clear()`
            // a secas le apagaría el banner a un join de OTRO grupo que sí está en vuelo.
            if let pendingJoinZone, tracker.zoneName == pendingJoinZone { tracker.clear() }
        default:
            break
        }
        onComplete(outcome)
        // **Quien dice «más tarde» no va a Grupos.** No se ha unido a nada: mandarle al tab sería
        // llevarle justo a donde no quiso entrar, y en un dominio que puede no haber abierto nunca. Vuelve
        // a lo que estaba haciendo, que es lo que pidió.
        guard outcome != .declined else { return }
        // Navigate to groups after dismiss (UX delay for animation, not sync)
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            RouterEntryGate.shared.submit(.navigate(.groups))
        }
    }

    // MARK: - Step: Joining (spinner honesto)

    private var joiningStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .accessibilityIdentifier("invite_joining_spinner")

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Invite.joiningTitle)
                    .font(DS.Typography.title2)
                    .multilineTextAlignment(.center)

                Text(L10n.Groups.Invite.joiningBody)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
            }

            Spacer()
        }
    }

    // MARK: - Step: Taking long (salida digna, NO error)

    private var takingLongStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            ProgressView()
                .controlSize(.large)

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Invite.slowTitle)
                    .font(DS.Typography.title2)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("invite_slow_title")

                Text(L10n.Groups.Invite.slowBody)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
            }

            Spacer()

            YalaPrimaryButton(L10n.Groups.Invite.slowContinueButton) {
                complete(.closedWhileSyncing)
            }
            .accessibilityIdentifier("invite_slow_continue")
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Step: Failed (retry visible)

    private func failedStep(_ reason: JoinFailureReason) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56)) // A11Y-DT: decorative hero icon, fixed size
                .foregroundStyle(DS.Semantic.warningForeground)

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Invite.errorTitle)
                    .font(DS.Typography.title2)
                    .multilineTextAlignment(.center)

                Text(reason == .expired
                    ? String(localized: "groups.invite.linkInvalidDetail")
                    : L10n.Groups.Invite.errorBody)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
            }

            Spacer()

            if reason != .expired {
                YalaPrimaryButton(L10n.Action.retry) {
                    startSoftTimeout()
                    Task { @MainActor in
                        await tracker.retry()
                    }
                }
                .accessibilityIdentifier("invite_retry_button")
            }

            Button(L10n.Groups.Invite.errorExitButton) {
                let recoverable: Bool = {
                    if case .acceptFailed(let r) = reason { return r }
                    return reason == .memberSaveFailed
                }()
                complete(.abandonedAfterFailure(recoverable: recoverable && reason != .expired))
            }
            .font(DS.Typography.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("invite_error_exit")
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Step: Completion (SOLO con member confirmado activo)

    private var completionStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56)) // A11Y-DT: decorative hero icon, fixed size
                .foregroundStyle(DS.Semantic.successForeground)

            Text(L10n.Groups.Invite.ready)
                .font(DS.Typography.title2)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("invite_ready_title")

            Spacer()

            YalaPrimaryButton(L10n.Groups.Invite.goToGroup) {
                complete(.joined)
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Setup del CTA · la persona que YA tiene cuenta

    /// Lo que el CTA escribe cuando quien se une ya está dado de alta: **el nombre con el que entrará a
    /// ESTE grupo, y nada más.**
    ///
    /// Escrito como la LISTA de lo que `performSilentSetup` hace y esto no, porque la manera de romper esto
    /// es añadir ahí abajo un paso y no mirar aquí:
    ///
    /// | `performSilentSetup` escribe | Aquí | Alcance del daño, MEDIDO |
    /// |---|---|---|
    /// | `userName` del perfil | **NO** | **CROSS-DEVICE.** `sync.set(string:)` empuja al iKV del Apple ID (o al outbox), así que unirte a un grupo te renombraría el perfil en TODOS tus dispositivos |
    /// | `defaultCurrencyCode` / `defaultPeriod` | **NO** | **CROSS-DEVICE**, por el mismo camino, y recalculados desde el grupo o la región: te cambia la moneda de la app por la del grupo al que acabas de entrar |
    /// | `updateCurrentUserDisplayName` | **NO** | DEVICE-WIDE dentro de Grupos: recorre TODOS tus members (`resolveAllCurrentUserMembers`), así que el nombre tecleado aquí te renombraría en tus otros grupos |
    /// | `onboardingMode = .groupInvite` | **NO** | **Local a este device, y recuperable** (`FullModeActivationView`). La primera versión de esta tabla decía que escalaba al iKV con merge never-downgrade, y conviene saber que es FALSO por este camino: el `didSet` de `SessionState.onboardingMode` embuda en `OnboardingMode.setCurrent`, que escribe `UserDefaults.standard` a secas. Los dos que SÍ empujan esa key al iKV son `GroupsOrganizerOnboarding` y `FullModeActivationView`. Sigue fuera de aquí porque te deja la app recortada a Grupos sin haberlo pedido — pero el titular era otro, y repetirlo hacía creer que las cuentas existentes ya estaban protegidas de esa escalada |
    /// | seeds de categorías/notificaciones + `save()` | **NO** | ya los tiene; correrlos es trabajo sobre un store vivo a cambio de nada |
    /// | `signalOnboardingCompleted` | **NO** | no hay alta nueva que anunciar a los otros dispositivos |
    /// | KPI `localRegistrationCompleted` | **NO** | contaría un registro por alguien que ya estaba registrado |
    /// | `hasShownGroupsOnboarding` | **NO** | **la que cambió al medirla.** Marcarla APAGA el educativo de Grupos —tres pantallas— a quien nunca lo ha visto, per-device y para siempre: `hasSeenAnyGroupsEducational` es `hasShownOnboarding` OR (`onboardingMode == .groupInvite` AND alta hecha), y para un usuario `.full` de toda la vida el segundo término es falso ⇒ esta línea era la única que decidía. Esta hoja es UNA pantalla de bienvenida: hace de educativo para quien llega sin app, no para quien ya usa Yala y entra en Grupos por primera vez |
    /// | nombre en el join intent | **SÍ** | es lo único que hace falta: `resolveJoinDisplayName` lo prefiere sobre el del perfil, así que el member de este grupo nace con él, y si ya existía lo corrige `correctDisplayNameIfNeeded` (R1) |
    private func performJoinOnlySetup() {
        let finalName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Sin fallback a `defaultName` aquí, al revés que en el alta: dejarlo vacío hace que
        // `resolveJoinDisplayName` caiga al nombre del PERFIL, que para esta persona es un nombre real y
        // mejor que «Usuario». Escribir el default lo taparía.
        guard !finalName.isEmpty else { return }

        // Residual DECLARADO: `updateDisplayName` propaga a TODAS las entries vigentes ("el nombre es
        // global, no por grupo" — su propio docblock). Con dos invitaciones vivas a la vez, el nombre
        // tecleado aquí viajaría también en la otra. Se deja: acotarlo a una zona obliga a que la vista
        // sepa a qué grupo pertenece, que hoy no sabe, y el caso —dos invites sin resolver— no se ha visto.
        PendingJoinStore.updateDisplayName(finalName)
    }

    // MARK: - Setup del CTA · el invitado FRESCO (alta completa)

    /// El alta de primer arranque. **Solo para quien NO tiene cuenta** — ver `performJoinOnlySetup` para
    /// qué de todo esto es dañino sobre una cuenta que ya existe, y por qué.
    private func performSilentSetup() {
        // 0. **El neutro durable de la sesión solo-grupos** (paso 5 del rediseño). Hermano de la línea
        // equivalente en `GroupsOrganizerOnboarding.writePreferences`: sin ella el arranque SIGUIENTE
        // adjunta el espejo al store personal y se trae el contenedor privado del Apple ID del teléfono.
        //
        // **Va aquí y NO en `performJoinOnlySetup`**, que es la otra rama de `handleJoinTap()`. Aquélla
        // corre cuando el device ya tiene onboarding hecho —o sea el caso «privada + grupos asociados» del
        // ADR §2, donde hay sesión privada viva— y ahí el espejo es exactamente lo que el usuario quiere.
        // Armarla en las dos ramas apagaría iCloud a quien acepta una invitación desde su Yala de siempre.
        //
        // El guard de secundaria es propio: este método no tiene el de la cabecera que sí lleva su gemelo
        // del organizador, y en una sesión secundaria el `UserDefaults` es el del DUEÑO — escribirle una
        // decisión de mount le apagaría el espejo a él.
        StorageModePersistence.armGroupsOnlyNeutralMountIfPrimary()

        let sync = PreferenceSyncService.shared
        let finalName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = finalName.isEmpty ? L10n.Profile.defaultName : finalName

        // 1. Set onboarding mode
        sessionState.onboardingMode = .groupInvite

        // 1.5. C2 · **ESTA vista ES el educativo del invitado**, contextual al link y con la metadata del
        // grupo, así que al terminarla se marca el hecho real: «ya se le contó qué es un grupo». Antes,
        // esa supresión la hacía `GroupsOnboardingLogic.shouldShow` cortando por `onboardingMode ==
        // .groupInvite` — un proxy que además tapaba el educativo a quien entraba por la card «Solo
        // grupos», que era justo quien menos contexto tenía. Sin esta línea, el invitado vería el educativo
        // general del tab justo después del suyo.
        UserDefaults.standard.set(true, forKey: AppPreferences.Keys.hasShownGroupsOnboarding)

        // 2. Save user name
        sync.set(string: effectiveName, forKey: AppPreferences.Keys.userName)

        // 2.5. El nombre viaja también en el join intent persistente: si el
        // member aún no nació (zona sin materializar), GroupJoinReconciler lo
        // aplica al crearlo — cubre el catch vacío del paso 7.5 y el kill-app.
        PendingJoinStore.updateDisplayName(effectiveName)

        // 3. Detect currency (from group if available, else region)
        let groupCurrency = detectCurrencyFromGroup()
        let currency = groupCurrency ?? CurrencyDefaults.detectCurrencyFromRegion()
        sync.set(string: currency.rawValue, forKey: "defaultCurrencyCode")
        sync.set(string: DetailPeriod.thisMonth.rawValue, forKey: "defaultPeriod")
        sessionState.selectedPeriod = .thisMonth

        // 4-6. Seeds + save del store personal. Si el invite se acepta DURANTE el import del restore,
        // este `save()` dispararía el `_assertionFailure`. Gatear por quiescencia: las prefs de arriba
        // (UserDefaults, seguras) ya quedaron; los seeds son idempotentes y corren en el próximo
        // bootstrap quiescente (y el import trae las categorías/notificaciones reales igual).
        if iCloudSyncService.shared.isImportQuiescent {
            // 4. Seed categories (idempotent — safe even if iCloud data arrives)
            seedCategoriesIfNeeded(in: modelContext)
            seedSystemGroupCategoriesIfNeeded(in: modelContext)

            // 5. Create default notifications (uses existing service — idempotent)
            NotificationService.shared.seedDefaultNotificationsIfNeeded(context: modelContext)

            // 6. Save
            do {
                SaveBreadcrumb.willSave("GroupInviteOnboarding.performSilentSetup")
                try modelContext.save()
                SaveBreadcrumb.didSave("GroupInviteOnboarding.performSilentSetup")
            } catch {
                #if DEBUG
                print("GroupInviteOnboardingView: Error saving setup: \(error)")
                #endif
            }
        } else {
            SaveBreadcrumb.deferred("GroupInviteOnboarding.performSilentSetup", "import not quiescent")
        }

        // 7. Signal other devices
        PreferenceSyncService.shared.signalOnboardingCompleted()

        // 7.5. Propagate the real displayName to the SplitMember already created
        // during share acceptance (avoids "Usuario" appearing to other members until
        // some unrelated update triggers sync).
        Task {
            do {
                try await GroupService.shared.updateCurrentUserDisplayName(effectiveName)
            } catch {
                #if DEBUG
                print("GroupInviteOnboardingView: Failed to propagate displayName: \(error)")
                #endif
            }
        }

        // 8. KPI registros/día (alta local vía invitación de grupo)
        MetricsService.localRegistrationCompleted(mode: "groupInvite")

    }

    private func detectCurrencyFromGroup() -> CurrencyCode? {
        guard let group = GroupService.shared.mostRecentGroup(),
              let code = CurrencyCode(rawValue: group.currencyCode) else { return nil }
        return code
    }

    private var groupColor: Color {
        if let hex = inviteMetadata?.color, !hex.isEmpty {
            return Color(hex: hex)
        }
        return theme.accent
    }

    private var groupIcon: String {
        if let icon = inviteMetadata?.icon, !icon.isEmpty {
            return icon
        }
        return "person.2.fill"
    }

    private var welcomeTitle: String {
        if let name = inviteMetadata?.name, !name.isEmpty {
            return L10n.Groups.Invite.welcomeWithGroup(name)
        }
        return L10n.Groups.Invite.welcome
    }
}
