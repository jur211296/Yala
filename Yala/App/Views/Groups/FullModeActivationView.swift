//
//  FullModeActivationView.swift
//  Yala
//
//  2-step activation for groupInvite users switching to full Yala mode.
//  Step 1: Main account setup (currency + name).
//  Step 2: Notification permission.
//  Post-activation: expand tabs, offer import of group history as drafts.
//

import SwiftData
import SwiftUI
import UserNotifications

struct FullModeActivationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    @State private var currentStep: Int = 1
    @State private var accountName: String = ""
    @State private var selectedCurrency: CurrencyCode = CurrencyDefaults.detectCurrencyFromRegion()
    @State private var showImportPrompt: Bool = false
    @State private var groupExpenseCount: Int = 0

    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background
                    .ignoresSafeArea()

                VStack(spacing: DS.Spacing.xxl) {
                    if currentStep == 1 {
                        accountStep
                    } else {
                        notificationStep
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
            .navigationTitle(L10n.Groups.Activate.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Action.cancel) { onComplete() }
                }
            }
        }
        .alert(L10n.Groups.Activate.importPrompt(groupExpenseCount), isPresented: $showImportPrompt) {
            Button(L10n.Groups.Activate.importYes) {
                importGroupHistory()
                onComplete()
            }
            Button(L10n.Groups.Activate.importNo, role: .cancel) {
                onComplete()
            }
        }
        .onAppear {
            TelemetryService.track(.fullModeActivationStarted)
            // Pre-select currency from group if available
            if let group = SplitSyncManager.shared.mostRecentGroup(),
               let code = CurrencyCode(rawValue: group.currencyCode) {
                selectedCurrency = code
            }
        }
    }

    // MARK: - Step 1: Account

    private var accountStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "banknote.fill")
                .font(.system(size: 48)) // A11Y-DT: decorative hero icon, fixed size
                .foregroundStyle(theme.accent)

            Text(L10n.Groups.Activate.accountStep)
                .font(DS.Typography.title2)
                .multilineTextAlignment(.center)

            VStack(spacing: DS.Spacing.md) {
                TextField(L10n.Groups.Activate.accountName, text: $accountName)
                    .font(DS.Typography.body)
                    .textFieldStyle(.roundedBorder)

                // Currency display (simplified — uses detected or group currency)
                HStack {
                    Text(selectedCurrency.flag)
                    Text(selectedCurrency.rawValue)
                        .font(DS.Typography.body)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(.thCard)
                )
            }

            Spacer()

            YalaPrimaryButton(L10n.Action.next) {
                withAnimation { currentStep = 2 }
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Step 2: Notifications

    private var notificationStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "bell.fill")
                .font(.system(size: 48)) // A11Y-DT: decorative hero icon, fixed size
                .foregroundStyle(theme.accent)

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Activate.notificationStep)
                    .font(DS.Typography.title2)
                    .multilineTextAlignment(.center)

                Text(L10n.Groups.Activate.notificationMessage)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: DS.Spacing.md) {
                YalaPrimaryButton(L10n.Groups.Activate.enableNotifications) {
                    requestNotificationPermission()
                    completeActivation()
                }

                Button(L10n.Groups.Activate.skipNotifications) {
                    completeActivation()
                }
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Activation Logic

    private func completeActivation() {
        let sync = PreferenceSyncService.shared

        // 1. Create account if none exists (or update existing "General")
        createAccountIfNeeded()

        // 2. Save preferences
        sync.set(string: selectedCurrency.rawValue, forKey: "defaultCurrencyCode")
        sync.set(string: DetailPeriod.thisMonth.rawValue, forKey: "defaultPeriod")
        sessionState.selectedPeriod = .thisMonth

        // 3. Switch to completed mode
        sessionState.onboardingMode = .completed
        sync.set(string: OnboardingMode.completed.rawValue, forKey: "onboardingMode")

        // 4. Save context
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("FullModeActivationView: Error saving: \(error)")
            #endif
        }

        // 5. Expand tabs to default layout
        let defaultJSON = TabBarConfiguration.default.toJSON()
        UserDefaults.standard.set(defaultJSON, forKey: TabBarConfiguration.storageKey)
        sessionState.selectedMainTab = .panel

        // 6. Track telemetry
        TelemetryService.track(.onboardingCompleted, parameters: [
            "mode": "fullActivation",
        ])
        TelemetryService.track(.fullModeActivationCompleted, parameters: [
            "fromSegment": UserSegmentService.shared.currentSegment.rawValue
        ])

        // 7. Check for group expenses to import
        let count = countGroupExpenses()
        if count > 0 {
            groupExpenseCount = count
            showImportPrompt = true
        } else {
            onComplete()
        }
    }

    private func createAccountIfNeeded() {
        let descriptor = FetchDescriptor<Account>()
        let existing: [Account]
        do {
            existing = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("FullModeActivationView: Error fetching accounts: \(error)")
            #endif
            return
        }

        // If a "General" account exists, update its currency
        if let generalAccount = existing.first(where: { $0.type == AccountType.general.rawValue }) {
            generalAccount.currencyCode = selectedCurrency.rawValue
            if !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                generalAccount.name = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if existing.isEmpty {
            let name = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
            let account = Account(
                name: name.isEmpty ? L10n.Account.AccountType.general : name,
                currencyCode: selectedCurrency.rawValue,
                colorHex: AppConstants.defaultColorHex,
                iconName: "banknote.fill",
                type: AccountType.general.rawValue
            )
            modelContext.insert(account)
        }
    }

    private func countGroupExpenses() -> Int {
        let descriptor = FetchDescriptor<SplitExpense>()
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            #if DEBUG
            print("FullModeActivationView: Error counting expenses: \(error)")
            #endif
            return 0
        }
    }

    private func importGroupHistory() {
        let descriptor = FetchDescriptor<SplitGroup>()
        let groups: [SplitGroup]
        do {
            groups = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("FullModeActivationView: Error fetching groups: \(error)")
            #endif
            return
        }
        guard !groups.isEmpty else { return }
        do {
            try GroupTransactionBridge.shared.importGroupHistoryAsDrafts(for: groups)
            TelemetryService.track(.groupHistoryImported, parameters: ["count": String(groupExpenseCount)])
        } catch {
            #if DEBUG
            print("FullModeActivationView: Import error: \(error)")
            #endif
        }
    }

    private func requestNotificationPermission() {
        Task {
            do {
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                #if DEBUG
                print("FullModeActivationView: Notification permission error: \(error)")
                #endif
            }
        }
    }
}
