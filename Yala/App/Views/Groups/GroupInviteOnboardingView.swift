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

    private var tracker: GroupJoinIntentTracker { .shared }

    /// #22: metadata branded del invite (nombre/icono/color del grupo) para
    /// personalizar el banner. Si nil → fallback al copy/visual genérico.
    let inviteMetadata: InviteMetadata?
    var onComplete: (GroupInviteOnboardingOutcome) -> Void

    init(
        inviteMetadata: InviteMetadata? = nil,
        onComplete: @escaping (GroupInviteOnboardingOutcome) -> Void
    ) {
        self.inviteMetadata = inviteMetadata
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
            .padding(.bottom, DS.Spacing.xxl)
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

    // MARK: - Join handler (A3)

    private func handleJoinTap() {
        guard !hasTappedJoin else { return }
        performSilentSetup()
        withAnimation { hasTappedJoin = true }
        // Camino rápido: si la zona ya materializó, el member nace ahora mismo y
        // la fase salta a pending/active sin esperar el próximo fetch.
        Task { @MainActor in
            await GroupJoinReconciler.reconcile(trigger: .acceptShare)
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
        case .closedWhileSyncing, .abandonedAfterFailure:
            break
        }
        // El tracker se consume al confirmar unión o al abandonar sin recovery;
        // en pending/closedWhileSyncing sigue vivo alimentando el banner del tab.
        switch outcome {
        case .joined, .abandonedAfterFailure(recoverable: false):
            tracker.clear()
        default:
            break
        }
        onComplete(outcome)
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

    // MARK: - Silent Setup

    private func performSilentSetup() {
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
        if let hex = inviteMetadata?.groupColor, !hex.isEmpty {
            return Color(hex: hex)
        }
        return theme.accent
    }

    private var groupIcon: String {
        if let icon = inviteMetadata?.groupIcon, !icon.isEmpty {
            return icon
        }
        return "person.2.fill"
    }

    private var welcomeTitle: String {
        if let name = inviteMetadata?.groupName, !name.isEmpty {
            return L10n.Groups.Invite.welcomeWithGroup(name)
        }
        return L10n.Groups.Invite.welcome
    }
}
