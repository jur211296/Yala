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

    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background
                    .ignoresSafeArea()

                VStack(spacing: DS.Spacing.xxl) {
                    if currentStep == 1 {
                        welcomeStep
                    } else {
                        completionStep
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

            Image(systemName: "person.2.fill")
                .font(.system(size: 56)) // A11Y-DT: decorative hero icon, fixed size
                .foregroundStyle(theme.accent)

            VStack(spacing: DS.Spacing.sm) {
                if let groupName = sessionState.pendingInviteGroupName {
                    Text(L10n.Groups.Invite.welcomeWithGroup(groupName))
                        .font(DS.Typography.title2)
                        .multilineTextAlignment(.center)
                } else {
                    Text(L10n.Groups.Invite.welcome)
                        .font(DS.Typography.title2)
                        .multilineTextAlignment(.center)
                }

                Text(L10n.Groups.Invite.subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField(L10n.Groups.Invite.namePlaceholder, text: $userName)
                .font(DS.Typography.body)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, DS.Spacing.lg)

            Spacer()

            YalaPrimaryButton(L10n.Groups.Invite.joinButton) {
                performSilentSetup()
                withAnimation { currentStep = 2 }
            }
            .padding(.bottom, DS.Spacing.xxl)
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
                // Navigate to groups after dismiss
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    SessionState.shared.deepLinkDestination = .groups
                }
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Silent Setup

    private func performSilentSetup() {
        let sync = PreferenceSyncService.shared
        let finalName = userName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Set onboarding mode
        sessionState.onboardingMode = .groupInvite

        // 2. Save user name
        sync.set(string: finalName.isEmpty ? L10n.Profile.defaultName : finalName, forKey: "userName")

        // 3. Detect currency (from group if available, else region)
        let currency = detectCurrencyFromGroup() ?? CurrencyDefaults.detectCurrencyFromRegion()
        sync.set(string: currency.rawValue, forKey: "defaultCurrencyCode")
        sync.set(string: DetailPeriod.thisMonth.rawValue, forKey: "defaultPeriod")
        sessionState.selectedPeriod = .thisMonth

        // 4. Seed categories (idempotent — safe even if iCloud data arrives)
        seedCategoriesIfNeeded(in: modelContext)

        // 5. Create "General" account if none exists
        createGeneralAccountIfNeeded(currency: currency)

        // 6. Create default notifications (uses existing service — idempotent)
        NotificationService.shared.seedDefaultNotificationsIfNeeded(context: modelContext)

        // 7. Save
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("GroupInviteOnboardingView: Error saving setup: \(error)")
            #endif
        }

        // 8. Signal other devices
        PreferenceSyncService.shared.signalOnboardingCompleted()

        // 9. Track telemetry
        TelemetryService.track(.onboardingCompleted, parameters: [
            "mode": "groupInvite",
        ])
    }

    private func detectCurrencyFromGroup() -> CurrencyCode? {
        guard let group = SplitSyncManager.shared.mostRecentGroup(),
              let code = CurrencyCode(rawValue: group.currencyCode) else { return nil }
        return code
    }

    private func createGeneralAccountIfNeeded(currency: CurrencyCode) {
        let descriptor = FetchDescriptor<Account>()
        let existingCount: Int
        do {
            existingCount = try modelContext.fetchCount(descriptor)
        } catch {
            #if DEBUG
            print("GroupInviteOnboardingView: Error fetching accounts: \(error)")
            #endif
            return
        }
        guard existingCount == 0 else { return }

        let account = Account(
            name: L10n.Account.AccountType.general,
            currencyCode: currency.rawValue,
            colorHex: AppConstants.defaultColorHex,
            iconName: "banknote.fill",
            type: AccountType.general.rawValue
        )
        modelContext.insert(account)
    }

}
