//
//  OnboardingView.swift
//  Yala
//
//  Simple onboarding flow for first-time users or after data wipe.
//  Collects: user name, preferred currency, secondary currencies, default period, seed categories.
//

import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48
    @ScaledMetric(relativeTo: .largeTitle) private var completionIconSize: CGFloat = 56

    // User preferences (will be saved on completion)
    @State private var userName: String = ""
    @State private var selectedCurrency: CurrencyCode = CurrencyDefaults.detectCurrencyFromRegion()
    @State private var selectedSecondaryCurrencies: Set<CurrencyCode> = []
    @State private var selectedPeriod: DetailPeriod = .thisMonth
    @State private var loadSeedCategories: Bool = true

    // Current step in the onboarding flow
    @State private var currentStep: Int = 0

    // Animation state for category grid
    @State private var showCategoryIcons: Bool = false

    // Expenses-only mode preference
    @State private var expensesOnlyMode: Bool = false

    // Notification preferences
    @State private var selectedNotifications: Set<NotificationType> = []
    @State private var hasRequestedPermission: Bool = false
    @State private var budgetAlertsEnabled: Bool = false
    @State private var showTutorialsSheet: Bool = false

    // Callback when onboarding completes
    var onComplete: () -> Void

    // Available periods for selection (excluding custom)
    private let availablePeriods: [DetailPeriod] = [
        .thisWeek, .last7Days, .last30Days, .thisMonth, .lastMonth,
        .thisYear, .lastYear, .allTime
    ]

    private let totalSteps = 8

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            // Progress indicator (hidden on final privacy step)
            progressIndicator
                .padding(.top, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)
                .opacity(currentStep < totalSteps - 1 ? 1 : 0)

            // Content based on current step
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                currencyStep.tag(1)
                secondaryCurrenciesStep.tag(2)
                periodStep.tag(3)
                expensesOnlyStep.tag(4)
                categoriesStep.tag(5)
                notificationsStep.tag(6)
                privacyStep.tag(7)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(true)
            .dsAnimation(.easeInOut(duration: 0.3), value: currentStep, reduceMotion: reduceMotion)

            Spacer()

            // Navigation buttons
            navigationButtons
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)
        }
        .background(.thBackground)
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.electricIndigo : theme.secondaryText.opacity(0.2))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .dsAnimation(.spring(response: 0.3), value: currentStep, reduceMotion: reduceMotion)
            }
        }
    }

    // MARK: - Step 1: Welcome & Name

    private var welcomeStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            // App icon with proper sizing (uses preview icon from Resources)
            Image(uiImage: UIImage(named: "IconOriginal@3x") ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 26))

            VStack(spacing: DS.Spacing.md) {
                Text(L10n.Onboarding.welcomeTitle)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.welcomeSubtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.Onboarding.nameLabel)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)

                TextField(L10n.Onboarding.namePlaceholder, text: $userName)
                    .font(DS.Typography.body)
                    .padding(DS.Spacing.md)
                    .background(.thCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xl)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 2: Preferred Currency

    private var recommendedCurrency: CurrencyCode {
        CurrencyDefaults.detectCurrencyFromRegion()
    }

    private var filteredContinentGroups: [(continent: Continent, currencies: [CurrencyCode])] {
        CurrencyCode.groupedByContinent.compactMap { group in
            let filtered = group.currencies.filter { $0 != recommendedCurrency }
            guard !filtered.isEmpty else { return nil }
            return (continent: group.continent, currencies: filtered)
        }
    }

    private var currencyStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Header
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: heroIconSize))
                    .foregroundStyle(Color.electricIndigo)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(L10n.Onboarding.currencyTitle)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.currencySubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.top, DS.Spacing.xl)

            ScrollView {
                LazyVStack(spacing: DS.Spacing.lg) {
                    // Recommended currency section
                    recommendedCurrencySection

                    // Currencies by continent (excluding recommended)
                    ForEach(filteredContinentGroups, id: \.continent) { group in
                        continentCurrencySection(group)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
        }
    }

    private var recommendedCurrencySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Onboarding.recommended)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, DS.Spacing.xs)

            currencyRow(recommendedCurrency, isSelected: selectedCurrency == recommendedCurrency) {
                selectedCurrency = recommendedCurrency
                selectedSecondaryCurrencies.remove(recommendedCurrency)
            }
            .background(Color.electricIndigo.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }

    private func continentCurrencySection(_ group: (continent: Continent, currencies: [CurrencyCode])) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(group.continent.localizedName)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(group.currencies) { currency in
                    currencyRow(currency, isSelected: selectedCurrency == currency) {
                        selectedCurrency = currency
                        selectedSecondaryCurrencies.remove(currency)
                    }
                }
            }
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }

    // MARK: - Step 3: Secondary Currencies

    /// Currencies to show in the recommended section
    private let recommendedCurrencyPool: [CurrencyCode] = [.usd, .eur, .gbp]

    /// Recommended currencies (excluding the preferred one, but including already selected)
    private var recommendedSecondaryCurrencies: [CurrencyCode] {
        recommendedCurrencyPool.filter { currency in
            currency != selectedCurrency
        }
    }

    /// Other currencies (excluding recommended and selected)
    private var otherSecondaryCurrencies: [CurrencyCode] {
        CurrencyCode.allCases.filter { currency in
            currency != selectedCurrency && !recommendedCurrencyPool.contains(currency)
        }
    }

    private var secondaryCurrenciesStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: heroIconSize))
                    .foregroundStyle(Color.electricIndigo)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(L10n.Onboarding.secondaryTitle)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.secondarySubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.top, DS.Spacing.xl)

            ScrollView {
                LazyVStack(spacing: DS.Spacing.lg) {
                    // Recommended section (if any available)
                    if !recommendedSecondaryCurrencies.isEmpty {
                        recommendedSecondaryCurrenciesSection
                    }

                    // Other currencies section
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(L10n.Common.others)
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.leading, DS.Spacing.xs)

                        VStack(spacing: DS.Spacing.none) {
                            ForEach(otherSecondaryCurrencies) { currency in
                                let isSelected = selectedSecondaryCurrencies.contains(currency)
                                currencyRow(currency, isSelected: isSelected, showCheckmark: true) {
                                    if isSelected {
                                        selectedSecondaryCurrencies.remove(currency)
                                    } else if selectedSecondaryCurrencies.count < 2 {
                                        selectedSecondaryCurrencies.insert(currency)
                                    }
                                }
                            }
                        }
                        .background(.thCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
            }

            // Selection hint
            Text(L10n.Onboarding.secondaryHint(selectedSecondaryCurrencies.count, 2))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, DS.Spacing.md)
        }
    }

    /// Recommended currencies section with highlighted background
    private var recommendedSecondaryCurrenciesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Settings.recommendedCurrencies)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(recommendedSecondaryCurrencies) { currency in
                    let isSelected = selectedSecondaryCurrencies.contains(currency)
                    currencyRow(currency, isSelected: isSelected, showCheckmark: true) {
                        if isSelected {
                            selectedSecondaryCurrencies.remove(currency)
                        } else if selectedSecondaryCurrencies.count < 2 {
                            selectedSecondaryCurrencies.insert(currency)
                        }
                    }
                }
            }
            .background(Color.electricIndigo.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(Color.electricIndigo.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Step 4: Default Period

    private var periodStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: heroIconSize))
                    .foregroundStyle(Color.electricIndigo)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(L10n.Onboarding.periodTitle)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.periodSubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.top, DS.Spacing.xl)

            VStack(spacing: DS.Spacing.sm) {
                ForEach(availablePeriods) { period in
                    periodRow(period, isSelected: selectedPeriod == period) {
                        selectedPeriod = period
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Step 5: Expenses Only Mode

    private var expensesOnlyStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: heroIconSize))
                    .foregroundStyle(Color.electricIndigo)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(L10n.Onboarding.expensesOnlyTitle)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.expensesOnlySubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.top, DS.Spacing.xl)

            VStack(spacing: DS.Spacing.sm) {
                // Option 1: Track everything (default)
                Button {
                    expensesOnlyMode = false
                } label: {
                    HStack {
                        Image(systemName: expensesOnlyMode ? "circle" : "checkmark.circle.fill")
                            .font(DS.Typography.title)
                            .foregroundStyle(expensesOnlyMode ? .secondary : Color.electricIndigo)

                        Text(L10n.Onboarding.expensesOnlyOptionAll)
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        if !expensesOnlyMode {
                            Text(L10n.Onboarding.categoriesRecommended)
                                .font(DS.Typography.caption)
                                .foregroundStyle(Color.electricIndigo)
                        }
                    }
                    .padding(DS.Spacing.md)
                    .background(!expensesOnlyMode ? Color.electricIndigo.opacity(0.1) : theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(!expensesOnlyMode ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Option 2: Only expenses
                Button {
                    expensesOnlyMode = true
                } label: {
                    HStack {
                        Image(systemName: expensesOnlyMode ? "checkmark.circle.fill" : "circle")
                            .font(DS.Typography.title)
                            .foregroundStyle(expensesOnlyMode ? Color.electricIndigo : .secondary)

                        Text(L10n.Onboarding.expensesOnlyOptionExpenses)
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(DS.Spacing.md)
                    .background(expensesOnlyMode ? Color.electricIndigo.opacity(0.1) : theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(expensesOnlyMode ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Step 6: Seed Categories

    private var categoriesStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: heroIconSize))
                    .foregroundStyle(Color.electricIndigo)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(L10n.Onboarding.categoriesTitle)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.categoriesSubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.top, DS.Spacing.md)

            // Visual grid of category icons
            categoryIconsGrid
                .padding(.horizontal, DS.Spacing.lg)

            // Info text about subcategories
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "info.circle")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                Text(L10n.Onboarding.categoriesInfo)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()

            // Selection buttons
            VStack(spacing: DS.Spacing.sm) {
                Button {
                    loadSeedCategories = true
                } label: {
                    HStack {
                        Image(systemName: loadSeedCategories ? "checkmark.circle.fill" : "circle")
                            .font(DS.Typography.title)
                            .foregroundStyle(loadSeedCategories ? Color.electricIndigo : .secondary)

                        Text(L10n.Onboarding.categoriesYes)
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(L10n.Onboarding.categoriesRecommended)
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.electricIndigo)
                    }
                    .padding(DS.Spacing.md)
                    .background(loadSeedCategories ? Color.electricIndigo.opacity(0.1) : theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(loadSeedCategories ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    loadSeedCategories = false
                } label: {
                    HStack {
                        Image(systemName: loadSeedCategories ? "circle" : "checkmark.circle.fill")
                            .font(DS.Typography.title)
                            .foregroundStyle(loadSeedCategories ? .secondary : Color.electricIndigo)

                        Text(L10n.Onboarding.categoriesNo)
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(DS.Spacing.md)
                    .background(loadSeedCategories ? theme.card : Color.electricIndigo.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(loadSeedCategories ? DS.Colors.borderSubtle : Color.electricIndigo.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    // MARK: - Step 7: Notifications

    private var notificationsStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: heroIconSize))
                    .foregroundStyle(Color.electricIndigo)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(L10n.Onboarding.notificationsTitle)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.notificationsSubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.top, DS.Spacing.md)

            ScrollView {
                VStack(spacing: DS.Spacing.sm) {
                    // Enable all / Disable all button
                    Button {
                        Task { await toggleAllNotifications() }
                    } label: {
                        HStack {
                            Text(allNotificationsSelected
                                 ? L10n.Onboarding.notificationsDeselectAll
                                 : L10n.Onboarding.notificationsSelectAll)
                                .font(DS.Typography.headline)
                                .foregroundStyle(Color.electricIndigo)
                            Spacer()
                            Image(systemName: allNotificationsSelected ? "checkmark.circle.fill" : "circle")
                                .font(DS.Typography.title)
                                .foregroundStyle(allNotificationsSelected ? Color.electricIndigo : .secondary)
                        }
                        .padding(DS.Spacing.md)
                        .background(.thCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    // Reminders section
                    notificationGroupHeader(L10n.Notifications.sectionReminders)
                    notificationToggleRow(.endOfDay)
                    notificationToggleRow(.lunchTime)

                    // Reports section
                    notificationGroupHeader(L10n.Notifications.sectionReports)
                    notificationToggleRow(.dailyReport)
                    notificationToggleRow(.weeklyReport)
                    notificationToggleRow(.monthlyReport)

                    // System section
                    notificationGroupHeader(L10n.Notifications.sectionSystem)
                    notificationToggleRow(.scheduledPayments)
                    budgetAlertsToggleRow
                    notificationToggleRow(.announcements)
                }
                .padding(.horizontal, DS.Spacing.xl)
            }

        }
    }

    private func notificationGroupHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xs)
    }

    private func notificationToggleRow(_ type: NotificationType) -> some View {
        let isSelected = selectedNotifications.contains(type)

        return Button {
            Task {
                await toggleNotification(type)
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: type.defaultColor).opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: type.defaultIcon)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color(hex: type.defaultColor))
                }

                // Name and description
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(notificationName(for: type))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Text(notificationHint(for: type))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Toggle indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title)
                    .foregroundStyle(isSelected ? Color.electricIndigo : .secondary)
            }
            .padding(DS.Spacing.md)
            .background(isSelected ? Color.electricIndigo.opacity(0.1) : theme.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var allNotificationsSelected: Bool {
        let allTypes: Set<NotificationType> = [
            .endOfDay, .lunchTime, .dailyReport, .weeklyReport,
            .monthlyReport, .scheduledPayments, .announcements
        ]
        return selectedNotifications == allTypes && budgetAlertsEnabled
    }

    private func toggleAllNotifications() async {
        if allNotificationsSelected {
            selectedNotifications.removeAll()
            budgetAlertsEnabled = false
        } else {
            if !hasRequestedPermission {
                let granted = await NotificationService.shared.requestPermission()
                hasRequestedPermission = true
                if !granted { return }
            }
            selectedNotifications = [
                .endOfDay, .lunchTime, .dailyReport, .weeklyReport,
                .monthlyReport, .scheduledPayments, .announcements
            ]
            budgetAlertsEnabled = true
        }
    }

    private func toggleNotification(_ type: NotificationType) async {
        // Request permission on first activation
        if !hasRequestedPermission && !selectedNotifications.contains(type) {
            let granted = await NotificationService.shared.requestPermission()
            hasRequestedPermission = true

            if !granted {
                return // Don't activate if permission denied
            }
        }

        // Toggle selection
        if selectedNotifications.contains(type) {
            selectedNotifications.remove(type)
        } else {
            selectedNotifications.insert(type)
        }
    }

    private var budgetAlertsToggleRow: some View {
        Button {
            Task {
                // Request permission on first activation
                if !hasRequestedPermission && !budgetAlertsEnabled {
                    let granted = await NotificationService.shared.requestPermission()
                    hasRequestedPermission = true

                    if !granted {
                        return
                    }
                }
                budgetAlertsEnabled.toggle()
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.hotPink.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: "chart.bar.fill")
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.hotPink)
                }

                // Name and description
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Notifications.budgetAlertsTitle)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Text(L10n.Notifications.budgetAlertsHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Toggle indicator
                Image(systemName: budgetAlertsEnabled ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title)
                    .foregroundStyle(budgetAlertsEnabled ? Color.electricIndigo : .secondary)
            }
            .padding(DS.Spacing.md)
            .background(budgetAlertsEnabled ? Color.electricIndigo.opacity(0.1) : theme.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(budgetAlertsEnabled ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func notificationName(for type: NotificationType) -> String {
        switch type {
        case .endOfDay: return L10n.Notifications.endOfDayName
        case .lunchTime: return L10n.Notifications.lunchTimeName
        case .dailyReport: return L10n.Notifications.dailyReportName
        case .weeklyReport: return L10n.Notifications.weeklyReportName
        case .monthlyReport: return L10n.Notifications.monthlyReportName
        case .scheduledPayments: return L10n.Notifications.scheduledPaymentsName
        case .announcements: return L10n.Notifications.announcementsName
        case .custom: return ""
        }
    }

    private static let hintTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private func formattedTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else { return "" }
        return Self.hintTimeFormatter.string(from: date)
    }

    private func notificationHint(for type: NotificationType) -> String {
        switch type {
        case .endOfDay: return formattedTime(hour: 20, minute: 0)
        case .lunchTime: return formattedTime(hour: 13, minute: 30)
        case .dailyReport: return formattedTime(hour: 21, minute: 0)
        case .weeklyReport: return L10n.Notifications.dayMonday + " " + formattedTime(hour: 9, minute: 0)
        case .monthlyReport: return L10n.Notifications.dayFirstOfMonth
        case .scheduledPayments: return L10n.Notifications.scheduledPaymentsHint
        case .announcements: return L10n.Notifications.announcementsHint
        case .custom: return ""
        }
    }

    // MARK: - Step 8: Privacy & Finish

    private var privacyStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            // Checkmark icon with gradient circle background
            ZStack {
                Circle()
                    .fill(Color.electricIndigo.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: completionIconSize))
                    .foregroundStyle(Color.electricIndigo)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }

            VStack(spacing: DS.Spacing.md) {
                Text(L10n.Onboarding.privacyTitle)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.privacySubtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }

            // Privacy points with colored icon circles
            VStack(spacing: DS.Spacing.sm) {
                privacyPoint(icon: "iphone", color: .electricIndigo, text: L10n.Onboarding.privacyLocal)
                privacyPoint(icon: "eye.slash.fill", color: .hotPink, text: L10n.Onboarding.privacyNoTracking)
                privacyPoint(icon: "person.badge.key.fill", color: .electricIndigo, text: L10n.Onboarding.privacyIcloud)
                privacyPoint(icon: "lock.shield.fill", color: .hotPink, text: L10n.Onboarding.privacyNoSharing)
            }
            .padding(.horizontal, DS.Spacing.xl)

            // Tutorials card button
            Button {
                showTutorialsSheet = true
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.electricIndigo.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: "lightbulb.fill")
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(Color.electricIndigo)
                    }

                    Text(L10n.Onboarding.privacyTutorialsHint)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(Color.electricIndigo)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.electricIndigo.opacity(0.6))
                }
                .padding(DS.Spacing.md)
                .background(Color.electricIndigo.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(Color.electricIndigo.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()
            Spacer()
        }
        .sheet(isPresented: $showTutorialsSheet) {
            NavigationStack {
                TutorialsListView()
            }
        }
    }

    private func privacyPoint(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(color)
            }

            Text(text)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Category Icons Grid

    /// Preview grid showing seed category icons with staggered animation
    private var categoryIconsGrid: some View {
        let seedCategories = SeedCategoryPreview.categories
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]

        return LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            ForEach(Array(seedCategories.enumerated()), id: \.offset) { index, category in
                VStack(spacing: DS.Spacing.xs) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: category.colorHex).opacity(0.2))
                            .frame(width: 52, height: 52)

                        Image(systemName: category.iconName)
                            .font(DS.Typography.title)
                            .foregroundStyle(Color(hex: category.colorHex))
                    }

                    Text(category.name)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .opacity(showCategoryIcons ? 1 : 0)
                .scaleEffect(showCategoryIcons ? 1 : 0.5)
                .dsAnimation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05),
                    value: showCategoryIcons,
                    reduceMotion: reduceMotion
                )
            }
        }
    }

    private func triggerCategoryAnimation() {
        showCategoryIcons = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [reduceMotion] in
            dsWithAnimation(reduceMotion) {
                showCategoryIcons = true
            }
        }
    }

    // MARK: - Reusable Components

    private func currencyRow(
        _ currency: CurrencyCode,
        isSelected: Bool,
        showCheckmark: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Text(currencyFlag(currency))
                    .font(DS.Typography.title)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(currency.rawValue)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.primary)
                    Text(currencyName(currency))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if showCheckmark {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(DS.Typography.title)
                        .foregroundStyle(isSelected ? Color.electricIndigo : .secondary)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.electricIndigo)
                }
            }
            .padding(DS.Spacing.md)
            .background(isSelected ? Color.electricIndigo.opacity(0.1) : theme.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func periodRow(
        _ period: DetailPeriod,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(period.displayName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.electricIndigo)
                }
            }
            .padding(DS.Spacing.md)
            .background(isSelected ? Color.electricIndigo.opacity(0.1) : theme.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: DS.Spacing.md) {
            // Back button (hidden on first step)
            if currentStep > 0 {
                Button {
                    dsWithAnimation(reduceMotion) {
                        currentStep -= 1
                    }
                } label: {
                    Text(L10n.Action.back)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(.thCard)
                        .clipShape(Capsule())
                }
            }

            // Next/Finish button
            Button {
                // Dismiss keyboard (especially important on step 1)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                if currentStep < totalSteps - 1 {
                    dsWithAnimation(reduceMotion) {
                        currentStep += 1
                    }
                    // Trigger category icons animation when entering categories step
                    if currentStep == 5 {
                        triggerCategoryAnimation()
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                let isLastStep = currentStep >= totalSteps - 1

                Text(isLastStep ? L10n.Onboarding.finish : L10n.Action.next)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(Color.electricIndigo)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Helpers

    private func currencyFlag(_ currency: CurrencyCode) -> String {
        currency.flag
    }

    private func currencyName(_ currency: CurrencyCode) -> String {
        currency.localizedName
    }

    private func completeOnboarding() {
        // Save user preferences via PreferenceSyncService (dual-writes to UserDefaults + iCloud KV)
        let sync = PreferenceSyncService.shared

        // User name
        let finalName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        sync.set(string: finalName.isEmpty ? L10n.Profile.defaultName : finalName, forKey: "userName")

        // Preferred currency
        sync.set(string: selectedCurrency.rawValue, forKey: "defaultCurrencyCode")

        // Secondary currencies (store as comma-separated string)
        let secondaryArray = selectedSecondaryCurrencies.map { $0.rawValue }
        sync.set(string: secondaryArray.joined(separator: ","), forKey: "secondaryCurrencies")

        // Default period
        sync.set(string: selectedPeriod.rawValue, forKey: "defaultPeriod")

        // Expenses-only mode (didSet propagates to app group)
        sync.set(bool: expensesOnlyMode, forKey: "expensesOnlyMode")
        sessionState.isExpensesOnlyMode = expensesOnlyMode

        // Budget alerts preference
        sync.set(bool: budgetAlertsEnabled, forKey: "budgetAlertsEnabled")

        // Apply period to SessionState immediately (since it was created before onboarding)
        sessionState.selectedPeriod = selectedPeriod

        // Create default account
        createDefaultAccount()

        // Seed categories if user chose to
        if loadSeedCategories {
            seedCategoriesIfNeeded(in: modelContext)
        }

        // Create notifications based on user selection
        createSelectedNotifications()

        // Mark onboarding as complete AFTER data creation (prevents inconsistent state on crash)
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Load historical exchange rates for secondary currencies (in background)
        loadHistoricalRatesForSecondaryCurrencies()

        // Notify completion
        onComplete()
    }

    private func createDefaultAccount() {
        // Check if any accounts already exist (e.g. from iCloud sync)
        let descriptor = FetchDescriptor<Account>()
        let existingCount: Int
        do {
            existingCount = try modelContext.fetchCount(descriptor)
        } catch {
            #if DEBUG
            print("OnboardingView: Error fetching account count: \(error)")
            #endif
            existingCount = 0
        }
        guard existingCount == 0 else { return }

        let account = Account(
            name: L10n.Onboarding.defaultAccountName,
            currencyCode: selectedCurrency.rawValue,
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "checking"
        )
        modelContext.insert(account)

        do {
            try modelContext.save()
            #if DEBUG
            print("OnboardingView: Created default account '\(account.name)' (\(account.currencyCode))")
            #endif
        } catch {
            #if DEBUG
            print("OnboardingView: Error creating default account: \(error)")
            #endif
        }
    }

    private func loadHistoricalRatesForSecondaryCurrencies() {
        // Load exchange rates in background (after onboarding dismisses)
        Task {
            // 1. First, force update TODAY's rate with ALL 7 currencies
            // This ensures the Settings "Tipo de cambio" section shows all currencies
            await ExchangeRateService.shared.forceUpdateToday(context: modelContext)

            // 2. Then load historical rates if secondary currencies were selected
            if !selectedSecondaryCurrencies.isEmpty {
                let calendar = Calendar.current
                let today = Date()
                guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: today) else {
                    return
                }

                let dateInterval = DateInterval(start: oneYearAgo, end: today)

                // FORCE refresh historical rates to ensure ALL currencies are included
                // This handles cases where rates were fetched before all currencies were selected
                await ExchangeRateService.shared.forceRefreshRates(for: dateInterval, context: modelContext)

                #if DEBUG
                print(
                    "OnboardingView: Force refreshed historical rates for secondary currencies: \(selectedSecondaryCurrencies.map { $0.rawValue })"
                )
                #endif
            }

            // Signal widget to refresh when user opens Panel
            SessionState.shared.needsExchangeRateWidgetRefresh = true
        }
    }

    private func createSelectedNotifications() {
        // R9: Guard against duplicate creation if called twice or iCloud delivers mid-save
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "notificationsSeeded") { return }
        defaults.set(true, forKey: "notificationsSeeded")

        // Fetch existing notifications to check by type (avoids duplicates on reinstall with iCloud)
        let descriptor = FetchDescriptor<NotificationItem>()
        let existing: [NotificationItem]
        do {
            existing = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("OnboardingView: Error fetching existing notifications: \(error)")
            #endif
            existing = []
        }
        let existingTypes = Set(existing.map { $0.typeRaw })

        // Create all default notifications
        let allDefaults = NotificationItem.createDefaults()
        var inserted = 0

        for notification in allDefaults {
            // Skip if this type already exists
            guard !existingTypes.contains(notification.typeRaw) else { continue }

            // Set active state based on user selection
            let isSelected = selectedNotifications.contains(notification.notificationType)
            notification.isActive = isSelected

            modelContext.insert(notification)
            inserted += 1

            // Schedule if active (and not a dynamic type)
            if isSelected && !notification.notificationType.requiresDynamicContent {
                Task {
                    await NotificationService.shared.scheduleNotification(for: notification)
                }
            }
        }

        guard inserted > 0 else {
            #if DEBUG
            print("OnboardingView: All notification types already exist, skipping creation")
            #endif
            return
        }

        do {
            try modelContext.save()
            #if DEBUG
            print("OnboardingView: Created \(inserted) notification types")
            #endif
        } catch {
            #if DEBUG
            print("OnboardingView: Error saving notifications: \(error)")
            #endif
        }
    }
}

// MARK: - Seed Category Preview

/// Provides a static preview of seed categories for the onboarding UI
/// This avoids importing the full CategorySeed definitions
enum SeedCategoryPreview {
    struct CategoryInfo {
        let name: String
        let colorHex: String
        let iconName: String
    }

    static let categories: [CategoryInfo] = [
        CategoryInfo(name: L10n.Category.food, colorHex: "#22C55E", iconName: "cart.fill"),
        CategoryInfo(name: L10n.Category.shopping, colorHex: "#F59E0B", iconName: "bag.fill"),
        CategoryInfo(name: L10n.Category.transport, colorHex: "#0EA5E9", iconName: "car.fill"),
        CategoryInfo(name: L10n.Category.finance, colorHex: "#6366F1", iconName: "banknote.fill"),
        CategoryInfo(name: L10n.Category.housing, colorHex: "#475569", iconName: "house.fill"),
        CategoryInfo(name: L10n.Category.entertainment, colorHex: "#FF0080", iconName: "sparkles"),
        CategoryInfo(name: L10n.Category.personal, colorHex: "#A855F7", iconName: "person.fill"),
        CategoryInfo(name: L10n.Category.pets, colorHex: "#84CC16", iconName: "pawprint.fill"),
        CategoryInfo(name: L10n.Category.vehicle, colorHex: "#64748B", iconName: "car.side.fill"),
        CategoryInfo(name: L10n.Category.incomeCategory, colorHex: "#14B8A6", iconName: "arrow.down.circle.fill"),
        CategoryInfo(name: L10n.Category.other, colorHex: "#64748B", iconName: "ellipsis.circle.fill"),
    ]
}

#Preview {
    OnboardingView {
        print("Onboarding completed!")
    }
}
