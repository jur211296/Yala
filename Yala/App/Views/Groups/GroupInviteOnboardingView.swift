//
//  GroupInviteOnboardingView.swift
//  Yala
//
//  2-step onboarding for users arriving via group invitation link.
//  Step 1: Welcome + name input. Step 2: Navigate to group.
//  Silent setup: categories, account, currency, onboardingMode.
//
//  GC-08.4 will implement the full UI. This is the structural placeholder.
//

import SwiftData
import SwiftUI

struct GroupInviteOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    @State private var userName: String = ""
    @State private var currentStep: Int = 1
    @State private var isProcessing: Bool = false

    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background
                    .ignoresSafeArea()

                VStack(spacing: DS.Spacing.xxl) {
                    switch currentStep {
                    case 1: welcomeStep
                    case 2: completionStep
                    case 3: pendingApprovalStep
                    default: completionStep
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
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

                Image(systemName: "person.2.fill")
                    .font(.system(size: 32)) // A11Y-DT: decorative icon inside circle
                    .foregroundStyle(.white)
            }
            .glassEffect(.regular, in: Circle())

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Invite.welcome)
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
            .disabled(isProcessing)
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
                TelemetryService.track(.groupInviteOnboardingCompleted)
                NudgeService.shared.recordGroupJoinIfNeeded()
                onComplete()
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    AppRouter.shared.enqueue(.navigate(.groups))
                }
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Join handler (A3)

    private func handleJoinTap() {
        guard !isProcessing else { return }
        performSilentSetup()
        isProcessing = true
        Task {
            let nextStep = await detectFinalStep()
            await MainActor.run {
                withAnimation { currentStep = nextStep }
                isProcessing = false
            }
        }
    }

    /// tras setup, detecta si el SplitMember quedó en `.pendingApproval` (step 3)
    /// o `.active` (step 2). Defensive: cualquier error → step 2 para no bloquear al user.
    private func detectFinalStep() async -> Int {
        guard let group = SplitSyncManager.shared.mostRecentGroup() else { return 2 }
        do {
            let member = try await GroupService.shared.ensureCurrentUserMemberExists(
                in: group, reactivateInactive: true
            )
            return member.isPendingApproval ? 3 : 2
        } catch {
            return 2
        }
    }

    // MARK: - Step 2: Completion

    private var completionStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56)) // A11Y-DT: decorative hero icon, fixed size
                .foregroundStyle(DS.Semantic.successForeground)

            Text(L10n.Groups.Invite.ready)
                .font(DS.Typography.title2)
                .multilineTextAlignment(.center)

            Spacer()

            YalaPrimaryButton(L10n.Groups.Invite.goToGroup) {
                TelemetryService.track(.groupInviteOnboardingCompleted)
                NudgeService.shared.recordGroupJoinIfNeeded()
                onComplete()
                // Navigate to groups after dismiss (UX delay for animation, not sync)
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    AppRouter.shared.enqueue(.navigate(.groups))
                }
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

        // 2. Save user name
        sync.set(string: effectiveName, forKey: AppPreferences.Keys.userName)

        // 3. Detect currency (from group if available, else region)
        let currency = detectCurrencyFromGroup() ?? CurrencyDefaults.detectCurrencyFromRegion()
        sync.set(string: currency.rawValue, forKey: "defaultCurrencyCode")
        sync.set(string: DetailPeriod.thisMonth.rawValue, forKey: "defaultPeriod")
        sessionState.selectedPeriod = .thisMonth

        // 4. Seed categories (idempotent — safe even if iCloud data arrives)
        seedCategoriesIfNeeded(in: modelContext)
        seedSystemGroupCategoriesIfNeeded(in: modelContext)

        // 5. Create default notifications (uses existing service — idempotent)
        NotificationService.shared.seedDefaultNotificationsIfNeeded(context: modelContext)

        // 6. Save
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("GroupInviteOnboardingView: Error saving setup: \(error)")
            #endif
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

        // 8. Track telemetry
        TelemetryService.track(.onboardingCompleted, parameters: [
            "mode": "groupInvite",
        ])
    }

    private func detectCurrencyFromGroup() -> CurrencyCode? {
        guard let group = SplitSyncManager.shared.mostRecentGroup(),
              let code = CurrencyCode(rawValue: group.currencyCode) else { return nil }
        return code
    }

    private var groupColor: Color {
        theme.accent
    }
}
