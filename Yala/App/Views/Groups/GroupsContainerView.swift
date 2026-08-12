//
//  GroupsContainerView.swift
//  Yala
//
//  Vista principal del tab Grupos — lista de grupos compartidos.
//

import SwiftUI
import SwiftData
import UIKit

struct GroupsContainerView: View {

    // MARK: - Environment

    @Environment(SessionState.self) private var sessionState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - State

    @State private var viewModel = GroupsViewModel()
    @State private var isPresentingSettings = false
    @State private var isPresentingGroupsSettings = false
    @Environment(AppPreferences.self) private var appPreferences
    @State private var showNotificationPrompt = false
    @State private var showPermissionDeniedAlert = false
    @State private var showNudgeBanner = false
    @State private var showGroupsOnboarding = false
    // D2 (§3.3.3): banner one-shot de re-entrada tras "Cerrar sesión de grupos". Se arma con
    // `GroupsSignOutBannerMarker` (in-session, sobrevive el relaunch), se lee en la primera aparición del
    // tab (el `onAppear` no re-lee si ya está visible) y se quema en el `onAppear` del banner real.
    @State private var showGroupsSignOutReentryBanner = false
    /// Drives el alert "¿Salir del grupo?" cuando un current user `.rejected`
    /// toca su card. Single-modal global vs N alerts montados por card.
    @State private var rejectedGroupPendingLeave: SplitGroup?
    /// G6-3 (C3): estado observable del uploader de migración (banner de progreso).
    @State private var leaveErrorMessage: String?
    /// Payload del composer "Nuevo gasto": captura los grupos elegibles AL MOMENTO del tap.
    /// Evita que un `loadData()` remoto entre el tap y la presentación deje el sheet en blanco.
    @State private var expenseComposerPayload: ExpenseComposerPayload?
    /// C4: el canal de Grupos sigue apagado tras el `refreshIfDue(force: true)` de `requestCreateGroup`.
    /// Antes de C4 este camino abría el form igual y acuñaba un grupo local irrecuperable.
    @State private var showChannelOffAlert = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if !viewModel.hasLoadedOnce {
                    // Cold launch de "Solo Grupos": el tab puede montar antes de que el bootstrap
                    // configure el contexto de GroupService. Mostramos spinner en vez del empty
                    // state hasta la primera carga con éxito (el bootstrap dispara loadData al terminar).
                    ProgressView()
                        .accessibilityIdentifier("groups_loading_spinner")
                } else if viewModel.activeGroups.isEmpty && viewModel.archivedGroups.isEmpty {
                    emptyState(standardAccessibilityID: "groups_empty_state")
                } else if viewModel.activeGroups.isEmpty {
                    // Only archived groups exist
                    VStack(spacing: DS.Spacing.xl) {
                        emptyState(standardAccessibilityID: nil)
                        archivedGroupsSection
                            .padding(.horizontal, DS.Spacing.lg)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: DS.Spacing.lg) {
                            // Global summary
                            if let summary = viewModel.globalSummary {
                                GroupSummaryHeader(summary: summary)
                            }

                            // Nudge banner
                            if let nudge = NudgeService.shared.currentNudge, showNudgeBanner {
                                GroupNudgeBanner(
                                    nudge: nudge,
                                    message: NudgeService.shared.currentNudgeMessage ?? "",
                                    onAction: {
                                        NudgeService.shared.recordInteracted(nudge)
                                        withAnimation(.easeOut(duration: 0.25)) { showNudgeBanner = false }
                                        handleNudgeAction(nudge)
                                    },
                                    onDismiss: {
                                        NudgeService.shared.recordDismissed(nudge)
                                        withAnimation(.easeOut(duration: 0.25)) { showNudgeBanner = false }
                                    },
                                    onAutoDismiss: {
                                        NudgeService.shared.recordDismissed(nudge, autoDismissed: true)
                                        withAnimation(.easeOut(duration: 0.25)) { showNudgeBanner = false }
                                    }
                                )
                            }

                            // Group cards
                            ForEach(viewModel.filteredGroups, id: \.id) { group in
                                groupCardRow(group: group)
                            }

                            // Archived groups
                            if !viewModel.archivedGroups.isEmpty {
                                archivedGroupsSection
                            }
                        }
                        .padding(.top, DS.Spacing.sm)
                        .padding(.bottom, DS.Spacing.safeBottom)
                    }
                    .scrollViewGlassEdges()
                    .searchable(
                        text: $viewModel.searchText,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: L10n.Common.search
                    )
                    // Pull-to-refresh SOLO en el ScrollView de la lista (no en el
                    // ZStack/NavigationStack): así su RefreshAction no se hereda por
                    // environment al detalle ni a los sheets — iOS 26 la captaba en el
                    // ScrollView horizontal de los chips del form de gasto (pull espurio).
                    // Fuerza un fetch real de CloudKit (no solo relee local) — force salta el debounce.
                    .refreshable { await viewModel.refreshFromCloud(force: true) }
                }

                // FAB — new group
                if !viewModel.activeGroups.isEmpty || !viewModel.archivedGroups.isEmpty {
                    newGroupFAB
                }
            }
            .safeAreaInset(edge: .top) { joinIntentBanner }
            .safeAreaInset(edge: .top) { groupsSignOutReentryBanner }
            .yalaScreenBackground(.panel)
            .navigationTitle(L10n.Groups.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingGroupsSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .accessibilityLabel(L10n.Groups.GlobalSettings.title)
                    }
                    .accessibilityIdentifier("groups_global_settings_button")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ProfileToolbarItem {
                    isPresentingSettings = true
                }
            }
            .sheet(isPresented: $isPresentingSettings) {
                ProfileView()
            }
            .sheet(isPresented: $isPresentingGroupsSettings) {
                GroupsGlobalSettingsView()
            }
            .sheet(isPresented: $viewModel.showCreateGroup, onDismiss: {
                viewModel.loadData()
            }) {
                GroupFormView(group: nil)
            }
            .sheet(item: $expenseComposerPayload, onDismiss: {
                // El prompt de notificaciones se difirió para no colisionar con este
                // composer (dos modales simultáneos → el sheet no llega a presentarse).
                // Reevaluarlo ahora que el composer cerró.
                maybeShowGroupsNotificationPrompt()
            }) { payload in
                GroupExpenseComposerView(
                    groups: payload.groups,
                    initialGroup: payload.initialGroup,
                    activeMembers: { viewModel.activeMembers(for: $0) },
                    memberNameLookup: { viewModel.memberNameLookup(for: $0) },
                    memberCount: { viewModel.memberCount(for: $0) },
                    onSave: { viewModel.loadData() }
                )
                .presentationDetents(DS.Adaptive.sheetDetents([.large]))
            }
            .navigationDestination(item: $viewModel.selectedGroup) { group in
                GroupDetailView(group: group)
            }
            .onChange(of: viewModel.selectedGroup) { _, newValue in
                // Al volver del detalle (pop → nil) refrescamos la lista, igual que el
                // antiguo onDismiss del fullScreenCover.
                if newValue == nil { viewModel.loadData() }
            }
            .appliesPendingRemoteChanges(sessionState)
            .onAppear {
                viewModel.setContext(modelContext)
                evaluateNudge()
                evaluateGroupsOnboarding()
                // D2 (§3.3.3): lee el marker en la primera aparición del tab. NO re-lee si el banner ya
                // está visible — el `onAppear` re-dispara en cada re-selección y el marker ya se quemó, lo
                // que pisaría un banner aún visible. El banner real quema el marker en su propio `onAppear`;
                // solo surge sobre el empty state H-7 (signInToView).
                if !showGroupsSignOutReentryBanner {
                    showGroupsSignOutReentryBanner = GroupsSignOutBannerMarker.isPending()
                }
                // C2 · el SEGUNDO armador del latch «tuvo sesión alguna vez», y no es un cinturón: es lo
                // único que cubre al parque que YA tenía sesión antes de esta versión —para quien no habrá
                // ningún evento de sign-in futuro— y a quien firmó por el camino de nube completo, que no
                // pasa por el closure de `GroupsSignInView`. Sin él, todos ellos leerían «crea una cuenta»
                // al cerrar sesión. Idempotente y monotónico: solo arma.
                if CloudAuthService.shared.hasSession {
                    GroupsSessionHistoryMarker.markSessionSeen()
                }
                // Traer cambios remotos de grupos al entrar al tab (el engine no auto-fetchea sin
                // push; debounced + gateado por quiescencia dentro de syncNow), luego recarga.
                Task { await viewModel.refreshFromCloud(force: false) }
            }
            .groupsOnboardingSheet(
                isPresented: $showGroupsOnboarding,
                onPersistFlag: {
                    seedSystemGroupCategoriesIfNeeded(in: modelContext)
                    appPreferences.hasShownGroupsOnboarding = true
                },
                // A1 (D-A7): el CTA de sign-in del cierre reusa el MISMO camino que el del
                // empty state — un solo productor de `.presentGroupsSignIn`.
                onRequestSignIn: { requestGroupsSignIn() }
            )
            .onDisappear {
                showNudgeBanner = false
                viewModel.cancelRecalculation()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background, .inactive:
                    viewModel.setBackground(true)
                case .active:
                    guard UIApplication.shared.applicationState == .active else { return }
                    viewModel.setBackground(false)
                    viewModel.reloadAndRecalculate()
                @unknown default:
                    break
                }
            }
            .onChange(of: sessionState.dataVersion) {
                // Sync remoto: debounced para coalescer ráfagas de cambios de CloudKit.
                viewModel.reloadAndRecalculate()
            }
            .onChange(of: viewModel.activeGroups.count) { _, _ in
                maybeShowGroupsNotificationPrompt()
            }
            // Deep link: open a specific group detail once the group list is available.
            .onChange(of: sessionState.pendingGroupID, initial: true) { _, _ in
                openPendingGroupIfAvailable()
            }
            // FAB del Panel ("Grupo"): abre el composer "Nuevo gasto" al llegar al tab.
            .onChange(of: sessionState.pendingNewGroupExpense, initial: true) { _, _ in
                openExpenseComposerIfRequested()
            }
            // G3: último paso de la rama organizador del Welcome — el formulario de grupo, directo.
            .onChange(of: sessionState.pendingNewGroupForm, initial: true) { _, _ in
                openGroupFormIfRequested()
            }
            .onChange(of: viewModel.groups.count, initial: true) { _, _ in
                openPendingGroupIfAvailable()
                openExpenseComposerIfRequested()
            }
            .alert(L10n.Groups.Notifications.promptTitle, isPresented: $showNotificationPrompt) {
                Button(L10n.Groups.Notifications.promptEnable) {
                    appPreferences.hasSeenGroupsNotificationPrompt = true
                    activateGroupsNotification()
                }
                Button(L10n.Action.cancel, role: .cancel) {
                    appPreferences.hasSeenGroupsNotificationPrompt = true
                }
            } message: {
                Text(L10n.Groups.Notifications.promptMessage)
            }
            .alert(L10n.Notifications.permissionRequired, isPresented: $showPermissionDeniedAlert) {
                Button(L10n.Notifications.openSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Notifications.permissionMessage)
            }
            .alert(
                L10n.Groups.Card.leaveGroupAlertTitle,
                isPresented: Binding(
                    get: { rejectedGroupPendingLeave != nil },
                    set: { if !$0 { rejectedGroupPendingLeave = nil } }
                )
            ) {
                Button(L10n.Groups.Settings.leaveGroup, role: .destructive) {
                    if let group = rejectedGroupPendingLeave {
                        Task { @MainActor in
                            do {
                                try await GroupService.shared.leaveGroup(group)
                                viewModel.loadData()
                            } catch {
                                // H1 review G5-A: el leave backend es RPC server-first — un fallo
                                // (sesión/red) deja el grupo local intacto y DEBE verse (cero silencios).
                                #if DEBUG
                                print("GroupsContainerView: leaveGroup failed: \(error)")
                                #endif
                                DS.Haptic.warning()
                                leaveErrorMessage = error.localizedDescription
                            }
                            rejectedGroupPendingLeave = nil
                        }
                    }
                }
                Button(L10n.Action.cancel, role: .cancel) {
                    rejectedGroupPendingLeave = nil
                }
            } message: {
                Text(L10n.Groups.Card.leaveGroupAlertBody)
            }
            .alert(
                L10n.Common.error,
                isPresented: Binding(
                    get: { leaveErrorMessage != nil },
                    set: { if !$0 { leaveErrorMessage = nil } }
                )
            ) {
                Button(L10n.Common.ok) { leaveErrorMessage = nil }
            } message: {
                Text(leaveErrorMessage ?? "")
            }
            .alert(
                L10n.Welcome.Groups.channelOffTitle,
                isPresented: $showChannelOffAlert
            ) {
                Button(L10n.Common.ok) { showChannelOffAlert = false }
            } message: {
                Text(L10n.Welcome.Groups.channelOffBody)
            }
        }
    }

    // MARK: - Helpers

    /// C2 · ¿ya se le contó a esta persona qué es un grupo? La MISMA señal para el educativo del tab y para
    /// el empty state: si discreparan, el tab podría anunciar «ver cómo funciona» y no presentar nada.
    private var hasSeenGroupsEducational: Bool {
        GroupsOnboardingLogic.hasSeenAnyGroupsEducational(
            hasShownOnboarding: appPreferences.hasShownGroupsOnboarding,
            onboardingMode: sessionState.onboardingMode,
            hasCompletedSetup: UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
        )
    }

    /// Empty state del tab. Decide (pure-logic) QUÉ le falta al usuario y lo dice, con la MISMA precedencia
    /// que `GroupsGateLogic` usa para decidir qué le va a pedir el tap — lo anunciado y lo pedido no pueden
    /// divergir. Con `groupsBackendEnabled` OFF SIEMPRE `.standard` ⇒ byte-idéntico al camino actual.
    ///
    /// `standardAccessibilityID` preserva la identidad de accesibilidad exacta por rama (total =
    /// `groups_empty_state`, solo-archivados = ninguna); las cuatro variantes llevan la suya fija. **El id
    /// va en el CONTENEDOR y pisa el del botón interior** (regla medida en `testing.md`): un XCUITest que
    /// busque el id declarado en `YalaEmptyState` no lo encuentra en el árbol.
    @ViewBuilder
    private func emptyState(standardAccessibilityID: String?) -> some View {
        switch GroupsEmptyStateLogic.decide(
            flagOn: CloudSyncFlags.groupsBackendEnabled,
            hasSeenEducational: hasSeenGroupsEducational,
            hadSessionEver: GroupsSessionHistoryMarker.hadSessionEver(),
            hasSession: CloudAuthService.shared.hasSession,
            isConsented: GroupsConsentState.isAccepted
        ) {
        case .standard:
            let base = YalaEmptyState.noGroups { Task { await requestCreateGroup() } }
            if let standardAccessibilityID {
                base.accessibilityIdentifier(standardAccessibilityID)
            } else {
                base
            }
        case .needsEducational:
            YalaEmptyState.groupsNeedsEducational { showGroupsOnboarding = true }
                .accessibilityIdentifier("groups_empty_state_educational")
        case .signInToView:
            YalaEmptyState.groupsSignedOut { requestGroupsSignIn() }
                .accessibilityIdentifier("groups_empty_state_signin")
        case .createAccount:
            // Mismo intent que la re-entrada: `GroupsSignInView` es la pantalla que CREA la cuenta además
            // de recuperarla. Lo que cambia es el copy, que es justo lo que estaba mal.
            YalaEmptyState.groupsCreateAccount { requestGroupsSignIn() }
                .accessibilityIdentifier("groups_empty_state_create_account")
        case .needsConsent:
            YalaEmptyState.groupsNeedsConsent { requestGroupsConsent() }
                .accessibilityIdentifier("groups_empty_state_consent")
        }
    }

    private func groupCardRow(group: SplitGroup) -> some View {
        GroupCardView(
            group: group,
            memberCount: viewModel.memberCount(for: group),
            pendingCount: viewModel.pendingMemberCount(for: group),
            debts: viewModel.currentUserDebts(for: group),
            displayMode: GroupCardDisplayLogic.displayMode(
                memberStatus: viewModel.currentMemberStatus(for: group),
                migrationState: group.migrationState
            ),
            action: { viewModel.openDetail(for: group) },
            onRejectedTap: { rejectedGroupPendingLeave = group }
        )
        .accessibilityIdentifier("group_card")
    }

    // C-10: `handleMigratedRejoin(_:)` vivía aquí y se ELIMINÓ. Era la SEGUNDA entrada a la cadena de
    // re-entrada al backend (la buena es `GroupDetailView.handleMigratedRejoin`, que ahora gatea por
    // capacidad) y la ÚNICA de todo el flujo que no comprobaba el flag, a diferencia de sus vecinas de
    // este mismo archivo (`groupsEmptyState`, `requestCreateGroup`). Con el canal apagado disparaba
    // `GroupBackendInviteEntryHandler.handle`, que sin ningún guard escribía `groupsBetaUnlocked` de
    // forma PERMANENTE, persistía un join intent que caducaba a los 7 días disparando su canario de
    // expiración, emitía un canario falso de intent persistido, y acababa presentando un sign-in que
    // fallaba siempre en `CloudAuthError.notConfigured`. El tap de la card ahora abre el detalle.

    private func evaluateNudge() {
        NudgeService.shared.evaluate()
        if NudgeService.shared.currentNudge != nil {
            withAnimation(.easeOut(duration: 0.3)) {
                showNudgeBanner = true
            }
        }
    }

    private func evaluateGroupsOnboarding() {
        #if DEBUG
        // F1c: en uitest no montar el onboarding informativo del tab (interceptaría taps).
        //
        // **C2 · el seam que invierte este early-return, y por qué existe.** Sin él, el educativo —que C2
        // convierte en el PRIMER escalón de las cuatro puertas— nace sin ninguna red determinista: no hay
        // XCUITest posible porque esta línea lo desmonta, y `qa/coverage-index.json` ya anotaba el hueco.
        // `-uitest-groups-educativo` lo monta a propósito para las corridas que lo ejercitan; el resto de
        // la suite sigue con el early-return intacto (el arg no está en `launchForUITest` por defecto), así
        // que ningún test existente cambia de comportamiento.
        if UITestHooks.isActive && !UITestHooks.groupsEducativo { return }
        #endif
        let shouldShow = GroupsOnboardingLogic.shouldShow(
            hasSeenEducational: hasSeenGroupsEducational,
            hasPendingGroupDeeplink: sessionState.pendingGroupID != nil
        )
        if shouldShow {
            showGroupsOnboarding = true
        }
    }

    private func openPendingGroupIfAvailable() {
        guard let groupID = sessionState.pendingGroupID,
              let uuid = UUID(uuidString: groupID),
              let group = viewModel.activeGroups.first(where: { $0.id == uuid })
        else { return }

        sessionState.pendingGroupID = nil
        viewModel.openDetail(for: group)
    }

    /// Abre el composer "Nuevo gasto" pedido desde el FAB del Panel. Solo consume el
    /// flag cuando hay un grupo elegible: si los grupos aún no cargaron (o el usuario
    /// no tiene ninguno), el flag persiste y el `.onChange(of: groups.count)` reintenta
    /// al llegar el primero — abriendo el composer tras crear el primer grupo.
    private func openExpenseComposerIfRequested() {
        guard sessionState.pendingNewGroupExpense else { return }
        let eligibles = viewModel.eligibleGroupsForExpense()
        guard let first = eligibles.first else { return }

        sessionState.pendingNewGroupExpense = false
        expenseComposerPayload = ExpenseComposerPayload(groups: eligibles, initialGroup: first)
    }

    /// G3 · abre el formulario de grupo pedido por la rama organizador del Welcome. **Se consume al
    /// primer intento y no espera a nada** —al contrario que su hermano `openExpenseComposerIfRequested`,
    /// que necesita un grupo elegible—: aquí el usuario acaba de darse de alta y todavía no tiene ninguno,
    /// que es justo el motivo de abrir el form. Si el sheet no llegara a presentarse, la red es el empty
    /// state estándar con su CTA «crear grupo», que ya existe.
    private func openGroupFormIfRequested() {
        guard sessionState.pendingNewGroupForm else { return }
        sessionState.pendingNewGroupForm = false
        Task { await requestCreateGroup() }
    }

    /// Presenta el prompt de notificaciones de grupos, SALVO que un composer del FAB del
    /// Panel esté pendiente o presentándose: SwiftUI no presenta dos modales a la vez, y el
    /// alert ganaría dejando el sheet del composer sin mostrarse. En ese caso el prompt
    /// espera al `onDismiss` del composer. La guarda doble (`pendingNewGroupExpense` +
    /// `expenseComposerPayload`) cubre cualquier orden entre los `onChange`.
    private func maybeShowGroupsNotificationPrompt() {
        guard !appPreferences.hasSeenGroupsNotificationPrompt,
              !viewModel.activeGroups.isEmpty,
              !sessionState.pendingNewGroupExpense,
              expenseComposerPayload == nil
        else { return }
        showNotificationPrompt = true
    }

    private func handleNudgeAction(_ nudge: NudgeType) {
        switch nudge.actionType {
        case .activateFullMode:
            RouterEntryGate.shared.submit(.presentFullModeActivation)
        case .openPanel:
            sessionState.selectMainTab(.panel)
        case .openGroupDetail:
            if let group = viewModel.activeGroups.first {
                viewModel.openDetail(for: group)
            }
        case .dismiss:
            break
        }
    }

    private func activateGroupsNotification() {
        // typeRaw matches NotificationType.groups
        let descriptor = FetchDescriptor<NotificationItem>(
            predicate: #Predicate { $0.typeRaw == "groups" }
        )
        do {
            if let item = try modelContext.fetch(descriptor).first {
                item.isActive = true
                try modelContext.save()
            }
        } catch {
            #if DEBUG
            print("GroupsContainerView: Error activating groups notification: \(error)")
            #endif
        }

        Task { @MainActor in
            let status = await NotificationService.shared.checkPermissionStatus()
            switch status {
            case .notDetermined:
                _ = await NotificationService.shared.requestPermission()
            case .denied:
                showPermissionDeniedAlert = true
            default:
                break
            }
        }
    }

    // MARK: - Archived Groups

    private var archivedGroupsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.showArchived.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: viewModel.showArchived ? "chevron.down" : "chevron.right")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                    Text(viewModel.showArchived
                         ? L10n.Groups.Settings.hideArchived
                         : L10n.Groups.Settings.showArchivedCount(viewModel.archivedGroups.count))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if viewModel.showArchived {
                ForEach(viewModel.archivedGroups, id: \.id) { group in
                    groupCardRow(group: group)
                        .opacity(0.6)
                }
            }
        }
    }

    // MARK: - Join intent banner

    /// Continuidad visible del join intent a nivel tab: el onboarding puede
    /// cerrarse en "está tardando" y el reconciliador sigue trabajando detrás —
    /// esta strip informa el estado real (conectando / esperando aprobación /
    /// error con retry / expirado) alimentada por `GroupJoinIntentTracker`.
    @ViewBuilder
    private var joinIntentBanner: some View {
        let tracker = GroupJoinIntentTracker.shared
        switch tracker.phase {
        case .idle, .active:
            EmptyView()

        case .accepting, .waitingForZone, .creatingMember:
            joinBannerChip(accessibilityID: "invite_sync_banner") {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.Groups.Invite.syncBanner)
                    .font(DS.Typography.caption)
            }

        case .pendingApproval:
            joinBannerChip(accessibilityID: "invite_pending_banner") {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(DS.Semantic.warningForeground)
                Text(L10n.Groups.Invite.waitingApprovalBanner)
                    .font(DS.Typography.caption)
            }

        case .failed(let reason):
            switch reason {
            case .acceptFailed(recoverable: true), .memberSaveFailed:
                joinBannerChip(accessibilityID: "invite_failed_banner") {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(DS.Semantic.warningForeground)
                    Text(L10n.Groups.Invite.errorTitle)
                        .font(DS.Typography.caption)
                    Button(L10n.Action.retry) {
                        Task { @MainActor in await tracker.retry() }
                    }
                    .font(DS.Typography.caption.weight(.semibold))
                }
            case .acceptFailed(recoverable: false), .expired:
                joinBannerChip(accessibilityID: "invite_expired_banner") {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(DS.Semantic.warningForeground)
                    Text(L10n.Groups.Invite.expiredBanner)
                        .font(DS.Typography.caption)
                    Button {
                        tracker.clear()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .accessibilityLabel(L10n.Action.cancel)
                    }
                }
            }
        }
    }

    private func joinBannerChip(
        accessibilityID: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            content()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .glassEffect()
        .accessibilityIdentifier(accessibilityID)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.xs)
    }

    // MARK: - Re-entry banner (D2, §3.3.3)

    /// Banner one-shot sobre el empty state H-7 tras "Cerrar sesión de grupos". Solo se pinta cuando el
    /// empty state de re-entrada (signInToView) está activo — así NUNCA aparece sobre tarjetas de grupo.
    /// Se quema (limpia el marker) en su propio `onAppear` (regla de one-shots del repo — jamás en el
    /// productor ni en el drain); dismiss manual con la X. `@State showGroupsSignOutReentryBanner` da la
    /// visibilidad estable en la sesión (leído una vez en el `onAppear` del contenedor).
    @ViewBuilder
    private var groupsSignOutReentryBanner: some View {
        if showGroupsSignOutReentryBanner && isGroupsSignedOutEmptyState {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(theme.accent)
                Text(L10n.Groups.Empty.SignedOut.reentryBanner)
                    .font(DS.Typography.caption)
                Spacer(minLength: 0)
                Button {
                    showGroupsSignOutReentryBanner = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .accessibilityLabel(L10n.Action.cancel)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .glassEffect()
            .accessibilityIdentifier("groups_signout_reentry_banner")
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.xs)
            .onAppear { GroupsSignOutBannerMarker.clear() }
        }
    }

    /// True cuando el tab muestra el empty state de re-entrada H-7 (signInToView): lista cargada y vacía,
    /// flag ON y sin sesión backend. Gatea el banner D2 para que jamás aparezca sobre tarjetas de grupo.
    private var isGroupsSignedOutEmptyState: Bool {
        viewModel.hasLoadedOnce
            && viewModel.activeGroups.isEmpty && viewModel.archivedGroups.isEmpty
            && GroupsEmptyStateLogic.decide(
                flagOn: CloudSyncFlags.groupsBackendEnabled,
                hasSeenEducational: hasSeenGroupsEducational,
                hadSessionEver: GroupsSessionHistoryMarker.hadSessionEver(),
                hasSession: CloudAuthService.shared.hasSession,
                isConsented: GroupsConsentState.isAccepted) == .signInToView
    }

    // MARK: - Create-group routing (G5-A / C3 · C4)

    /// Gate canal/consent/sign-in ANTES de abrir el form, y **choke-point ÚNICO de las cuatro entradas**
    /// de creación del tab (empty state, FAB simple, FAB expandible y el `pendingNewGroupForm` que deja la
    /// rama organizador del Welcome). El form es sheet de ESTE anchor (GroupsContainerView), distinto del
    /// ContentView que posee `GroupsBackendInviteModifier` — emitir el intent con el form abierto lo dejaría
    /// RETENIDO por peek-first ("el save no haría nada"). Residual documentado: sin auto-continuación — tras
    /// la chain (consent/sign-in) el usuario re-tapea "crear grupo".
    ///
    /// **C4 · el `force: true` va ANTES de leer el flag, y no es cosmético:** sin él `refreshIfDue` es un
    /// no-op exactamente en el caso del bug (min-interval de 6 h, ya gastada por el refresh fire-and-forget
    /// del arranque) y las cuatro entradas medirían un snapshot rancio. La regla —«la intención del usuario
    /// ES evidencia de que el canal debería estar encendido»— es la misma que aplica
    /// `GroupInviteChannelRoutingLogic` al recibir un link backend, y la que ya protegía el Welcome
    /// (`WelcomeGroupsGateView.evaluate`). El `force` vive AQUÍ y no replicado en los cuatro call-sites a
    /// propósito: un solo punto de decisión es lo que hace que añadir una quinta entrada no reabra el
    /// agujero. Lo fija `GroupCreateRoutingWiringTests` por source-scan — la lógica pura puede estar
    /// perfecta y verde mientras nadie la llame donde hace falta.
    ///
    /// **Con `.channelOff` no se escribe NADA** (ni preferencias, ni `SplitGroup`): solo se dice la verdad.
    private func requestCreateGroup() async {
        // Hermeticidad: bajo `-uitest` no se toca red, igual que la puerta del Welcome. Los getters ya
        // devuelven su default (ON bajo `Yala Dev`), así que el XCUITest recorre la rama buena.
        if !SwiftDataConfiguration.isUITesting {
            await RemoteConfigClient.shared.refreshIfDue(force: true)
        }

        switch GroupCreateRoutingLogic.route(
            flagOn: CloudSyncFlags.groupsBackendEnabled,
            hasSession: CloudAuthService.shared.hasSession,
            consentAccepted: GroupsConsentState.isAccepted
        ) {
        case .backend:
            // El anchor de ESTA vista abre el form; la creación la resuelve `GroupFormView.saveAsync`.
            viewModel.showCreateGroup = true
        case .channelOff:
            // El copy que YA existe para este hecho, el de la puerta del Welcome (`welcome.groups.channelOff*`):
            // estado transitorio, sin culpar al usuario y diciendo que no se guardó nada. Es el mismo
            // precedente por el que esa puerta reusa `welcome.cloud.blocked*`.
            DS.Haptic.warning()
            showChannelOffAlert = true
        case .needsConsent:
            // Ceder el anchor: ContentView (libre) presenta el consent de inmediato. Sentinel "" ⇒
            // `continueFlow` no-op (no hay PendingJoin para la creación — verificado en el handler).
            RouterEntryGate.shared.submit(.presentGroupsConsent(pendingJoin: ""))
        case .needsSignIn:
            RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: ""))
        }
    }

    /// CTA del empty state de re-entrada (H-2026-07-18-7): cede el anchor a ContentView (dueño ÚNICO de
    /// `GroupsBackendInviteModifier`) para presentar el sign-in solo-grupos. Sentinel "" ⇒ sin PendingJoin.
    /// El arranque del canal post-sign-in ya está cableado (f1c79424: el closure de éxito de
    /// `GroupsSignInView` dentro de `GroupsBackendInviteModifier` llama `startIfEligible`), así que esta
    /// CTA solo presenta el sign-in y hereda ese arranque gratis.
    private func requestGroupsSignIn() {
        RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: ""))
    }

    /// C2 · CTA del empty state `.needsConsent`. Cede el anchor igual que sus hermanas y reusa el MISMO
    /// intent que `requestCreateGroup` emite en su rama `.needsConsent` — un segundo productor duplicaría
    /// el dueño de esa cadena. Sentinel "" ⇒ `continueFlow` no-op (no hay PendingJoin aquí).
    private func requestGroupsConsent() {
        RouterEntryGate.shared.submit(.presentGroupsConsent(pendingJoin: ""))
    }

    // MARK: - FAB

    private var newGroupFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                fabControl
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    /// Si no hay grupo donde el current user pueda crear un gasto, el FAB es el simple
    /// de "Nuevo grupo". Si hay ≥1 elegible, despliega menú (Nuevo grupo / Nuevo gasto).
    @ViewBuilder
    private var fabControl: some View {
        if viewModel.eligibleGroupsForExpense().isEmpty {
            CircularPlusFAB(
                tint: theme.accent,
                accessibilityLabel: L10n.Groups.newGroup,
                accessibilityIdentifier: "groups_fab_new"
            ) {
                Task { await requestCreateGroup() }
            }
            .dsFloatingShadow()
        } else {
            ExpandableFAB(
                mainTint: theme.accent,
                actions: [
                    ExpandableFABAction(
                        id: "newGroup",
                        icon: "person.2.fill",
                        text: L10n.Groups.newGroup,
                        color: .electricIndigo,
                        accessibilityIdentifier: "groups_fab_new_group"
                    ) {
                        Task { await requestCreateGroup() }
                    },
                    ExpandableFABAction(
                        id: "newExpense",
                        icon: "square.and.pencil",
                        text: L10n.Groups.Expense.newExpense,
                        color: .hotPink,
                        accessibilityIdentifier: "groups_fab_new_expense"
                    ) {
                        let eligibles = viewModel.eligibleGroupsForExpense()
                        if let first = eligibles.first {
                            expenseComposerPayload = ExpenseComposerPayload(groups: eligibles, initialGroup: first)
                        }
                    }
                ],
                mainAccessibilityLabel: L10n.Action.add,
                closeAccessibilityLabel: L10n.Accessibility.closeMenu,
                mainAccessibilityIdentifier: "groups_fab_new"
            )
        }
    }
}

/// Snapshot inmutable de los grupos elegibles + el inicial, capturado al tocar "Nuevo gasto".
/// Presentar el composer vía `.sheet(item:)` con este payload evita recomputar la lista en el
/// closure del sheet (donde un `loadData()` concurrente podría vaciarla → sheet en blanco).
private struct ExpenseComposerPayload: Identifiable {
    let id = UUID()
    let groups: [SplitGroup]
    let initialGroup: SplitGroup
}
