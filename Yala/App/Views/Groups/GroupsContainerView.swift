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
    /// Drives el alert "¿Salir del grupo?" cuando un current user `.rejected`
    /// toca su card. Single-modal global vs N alerts montados por card.
    @State private var rejectedGroupPendingLeave: SplitGroup?
    /// G6-3 (C3): estado observable del uploader de migración (banner de progreso).
    @State private var migrationProgress = GroupMigrationProgress.shared
    @State private var leaveErrorMessage: String?
    /// Payload del composer "Nuevo gasto": captura los grupos elegibles AL MOMENTO del tap.
    /// Evita que un `loadData()` remoto entre el tap y la presentación deje el sheet en blanco.
    @State private var expenseComposerPayload: ExpenseComposerPayload?

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
                    YalaEmptyState.noGroups {
                        requestCreateGroup()
                    }
                    .accessibilityIdentifier("groups_empty_state")
                } else if viewModel.activeGroups.isEmpty {
                    // Only archived groups exist
                    VStack(spacing: DS.Spacing.xl) {
                        YalaEmptyState.noGroups {
                            requestCreateGroup()
                        }
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

                            // G6-3 (C3): progreso simple mientras el uploader migra los grupos del owner al
                            // backend (DARK: solo puede ser true con `groupsBackendEnabled` ON). No bloquea.
                            if migrationProgress.isMigrating {
                                HStack(spacing: DS.Spacing.sm) {
                                    ProgressView()
                                    Text(L10n.Groups.Migrated.migratingBanner)
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(DS.Spacing.md)
                                .solidCard(radius: DS.Radius.md)
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
                // Traer cambios remotos de grupos al entrar al tab (el engine no auto-fetchea sin
                // push; debounced + gateado por quiescencia dentro de syncNow), luego recarga.
                Task { await viewModel.refreshFromCloud(force: false) }
            }
            .groupsOnboardingSheet(
                isPresented: $showGroupsOnboarding,
                onPersistFlag: {
                    seedSystemGroupCategoriesIfNeeded(in: modelContext)
                    appPreferences.hasShownGroupsOnboarding = true
                }
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
        }
    }

    // MARK: - Helpers

    private func groupCardRow(group: SplitGroup) -> some View {
        GroupCardView(
            group: group,
            memberCount: viewModel.memberCount(for: group),
            pendingCount: viewModel.pendingMemberCount(for: group),
            debts: viewModel.currentUserDebts(for: group),
            displayMode: GroupCardDisplayLogic.displayMode(
                memberStatus: viewModel.currentMemberStatus(for: group),
                isMigratedFrozen: group.isMigratedFrozen
            ),
            action: { viewModel.openDetail(for: group) },
            onRejectedTap: { rejectedGroupPendingLeave = group },
            onMigratedTap: { handleMigratedRejoin(group) }
        )
        .accessibilityIdentifier("group_card")
    }

    /// G6-3 (C4, CTA re-join): un grupo congelado se toca → dispara el flujo de re-entrada por el seam de G6-2.
    /// `GroupBackendInviteEntryHandler.handle` persiste el intent (capturando el `legacyMemberKey` del member
    /// local del grupo migrado → rebind server-side) y dispara la cadena consent/sign-in/join (source
    /// `.userAction` — nunca re-presenta onboarding). Token nil (no debería: viaja con `movedToBackendAt`) →
    /// alert genérico.
    private func handleMigratedRejoin(_ group: SplitGroup) {
        guard let token = group.backendReInviteToken, !token.isEmpty else {
            DS.Haptic.warning()
            leaveErrorMessage = L10n.Groups.Errors.actionFailed
            return
        }
        Task { @MainActor in
            await GroupBackendInviteEntryHandler.handle(
                groupID: group.cloudKitZoneID, token: token, source: .userAction)
        }
    }

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
        if UITestHooks.isActive { return }
        #endif
        let shouldShow = GroupsOnboardingLogic.shouldShow(
            hasShownOnboarding: appPreferences.hasShownGroupsOnboarding,
            onboardingMode: sessionState.onboardingMode,
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

    // MARK: - Create-group routing (G5-A / C3)

    /// Gate consent/sign-in ANTES de abrir el form. El form es sheet de ESTE anchor (GroupsContainerView),
    /// distinto del ContentView que posee `GroupsBackendInviteModifier` — emitir el intent con el form
    /// abierto lo dejaría RETENIDO por peek-first ("el save no haría nada"). Con el flag OFF SIEMPRE abre el
    /// form (byte-idéntico). Residual documentado: sin auto-continuación — tras la chain (consent/sign-in) el
    /// usuario re-tapea "crear grupo".
    private func requestCreateGroup() {
        switch GroupCreateRoutingLogic.route(
            flagOn: CloudSyncFlags.groupsBackendEnabled,
            hasSession: CloudAuthService.shared.hasSession,
            consentAccepted: GroupsConsentState.isAccepted
        ) {
        case .cloudKit, .backend:
            // El anchor de ESTA vista abre el form; la rama backend la resuelve `GroupFormView.saveAsync`.
            viewModel.showCreateGroup = true
        case .needsConsent:
            // Ceder el anchor: ContentView (libre) presenta el consent de inmediato. Sentinel "" ⇒
            // `continueFlow` no-op (no hay PendingJoin para la creación — verificado en el handler).
            RouterEntryGate.shared.submit(.presentGroupsConsent(pendingJoin: ""))
        case .needsSignIn:
            RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: ""))
        }
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
                requestCreateGroup()
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
                        requestCreateGroup()
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
