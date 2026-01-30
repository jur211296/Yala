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

    // User preferences (will be saved on completion)
    @State private var userName: String = ""
    @State private var selectedCurrency: CurrencyCode = CurrencyDefaults.detectCurrencyFromRegion()
    @State private var selectedSecondaryCurrencies: Set<CurrencyCode> = []
    @State private var selectedPeriod: DetailPeriod = .thisMonth
    @State private var loadSeedCategories: Bool = true

    #if DEV_BUILD
    // Dev data seed preference (only visible in DEV builds)
    @State private var loadDevData: Bool = false
    #endif

    // Current step in the onboarding flow
    @State private var currentStep: Int = 0

    // Animation state for category grid
    @State private var showCategoryIcons: Bool = false

    // Notification preferences
    @State private var selectedNotifications: Set<NotificationType> = []
    @State private var hasRequestedPermission: Bool = false

    // Callback when onboarding completes
    var onComplete: () -> Void

    // Available periods for selection (excluding custom)
    private let availablePeriods: [DetailPeriod] = [
        .thisWeek, .last7Days, .last30Days, .thisMonth, .lastMonth,
        .thisYear, .lastYear, .allTime
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressIndicator
                .padding(.top, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)

            // Content based on current step
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                currencyStep.tag(1)
                secondaryCurrenciesStep.tag(2)
                periodStep.tag(3)
                categoriesStep.tag(4)
                #if DEV_BUILD
                devDataStep.tag(5)
                notificationsStep.tag(6)
                #else
                notificationsStep.tag(5)
                #endif
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .dsAnimation(.easeInOut(duration: 0.3), value: currentStep, reduceMotion: reduceMotion)

            Spacer()

            // Navigation buttons
            navigationButtons
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)
        }
        .background(Color.yalaBackground)
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        #if DEV_BUILD
        let totalSteps = 7
        #else
        let totalSteps = 6
        #endif

        return HStack(spacing: DS.Spacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.electricIndigo : Color.yalaSecondaryText.opacity(0.2))
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
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.welcomeSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.Onboarding.nameLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField(L10n.Onboarding.namePlaceholder, text: $userName)
                    .font(.body)
                    .padding(DS.Spacing.md)
                    .background(Color.yalaCard)
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

    private var currencyStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.electricIndigo)

                Text(L10n.Onboarding.currencyTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.currencySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.top, DS.Spacing.xl)

            ScrollView {
                LazyVStack(spacing: DS.Spacing.sm) {
                    ForEach(CurrencyCode.allCases) { currency in
                        currencyRow(currency, isSelected: selectedCurrency == currency) {
                            selectedCurrency = currency
                            // Remove from secondary if selected as primary
                            selectedSecondaryCurrencies.remove(currency)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
        }
    }

    // MARK: - Step 3: Secondary Currencies

    private var secondaryCurrenciesStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.electricIndigo)

                Text(L10n.Onboarding.secondaryTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.secondarySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.top, DS.Spacing.xl)

            ScrollView {
                LazyVStack(spacing: DS.Spacing.sm) {
                    ForEach(CurrencyCode.allCases.filter { $0 != selectedCurrency }) { currency in
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
                .padding(.horizontal, DS.Spacing.xl)
            }

            // Selection hint
            Text(L10n.Onboarding.secondaryHint(selectedSecondaryCurrencies.count, 2))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, DS.Spacing.md)
        }
    }

    // MARK: - Step 4: Default Period

    private var periodStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.electricIndigo)

                Text(L10n.Onboarding.periodTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.periodSubtitle)
                    .font(.subheadline)
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

    // MARK: - Step 5: Seed Categories

    private var categoriesStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.electricIndigo)

                Text(L10n.Onboarding.categoriesTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.categoriesSubtitle)
                    .font(.subheadline)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L10n.Onboarding.categoriesInfo)
                    .font(.caption)
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
                            .font(.title3)
                            .foregroundStyle(loadSeedCategories ? Color.electricIndigo : .secondary)

                        Text(L10n.Onboarding.categoriesYes)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(L10n.Onboarding.categoriesRecommended)
                            .font(.caption)
                            .foregroundStyle(Color.electricIndigo)
                    }
                    .padding(DS.Spacing.md)
                    .background(loadSeedCategories ? Color.electricIndigo.opacity(0.1) : Color.yalaCard)
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
                            .font(.title3)
                            .foregroundStyle(loadSeedCategories ? .secondary : Color.electricIndigo)

                        Text(L10n.Onboarding.categoriesNo)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(DS.Spacing.md)
                    .background(loadSeedCategories ? Color.yalaCard : Color.electricIndigo.opacity(0.1))
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

    #if DEV_BUILD
    // MARK: - Step 5 (DEV_BUILD): Dev Data Seed

    private var devDataStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.electricIndigo)

                Text("Datos de prueba")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Solo para desarrollo: carga datos de ejemplo (cuentas, transacciones, presupuestos) para probar la app rápidamente")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.top, DS.Spacing.md)

            Spacer()

            // Selection buttons
            VStack(spacing: DS.Spacing.sm) {
                Button {
                    loadDevData = true
                } label: {
                    HStack {
                        Image(systemName: loadDevData ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(loadDevData ? Color.electricIndigo : .secondary)

                        Text("Sí, cargar datos de prueba")
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(DS.Spacing.md)
                    .background(loadDevData ? Color.electricIndigo.opacity(0.1) : Color.yalaCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(loadDevData ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    loadDevData = false
                } label: {
                    HStack {
                        Image(systemName: loadDevData ? "circle" : "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(loadDevData ? .secondary : Color.electricIndigo)

                        Text("No, empezar sin datos")
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(DS.Spacing.md)
                    .background(loadDevData ? Color.yalaCard : Color.electricIndigo.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(loadDevData ? DS.Colors.borderSubtle : Color.electricIndigo.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.md)

            Spacer()
        }
    }
    #endif

    // MARK: - Step 6 (or 7 in DEBUG): Notifications

    private var notificationsStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.electricIndigo)

                Text(L10n.Onboarding.notificationsTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.notificationsSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.top, DS.Spacing.md)

            ScrollView {
                VStack(spacing: DS.Spacing.sm) {
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
                    notificationToggleRow(.announcements)
                }
                .padding(.horizontal, DS.Spacing.xl)
            }

            // Skip button
            Button {
                selectedNotifications.removeAll()
            } label: {
                Text(L10n.Onboarding.notificationsSkip)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, DS.Spacing.sm)
        }
    }

    private func notificationGroupHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
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
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: type.defaultColor))
                }

                // Name and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(notificationName(for: type))
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(notificationHint(for: type))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Toggle indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.electricIndigo : .secondary)
            }
            .padding(DS.Spacing.md)
            .background(isSelected ? Color.electricIndigo.opacity(0.1) : Color.yalaCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private func notificationHint(for type: NotificationType) -> String {
        switch type {
        case .endOfDay: return "8:00 PM"
        case .lunchTime: return "1:30 PM"
        case .dailyReport: return "9:00 PM"
        case .weeklyReport: return L10n.Notifications.dayMonday + " 9:00 AM"
        case .monthlyReport: return L10n.Notifications.dayFirstOfMonth
        case .scheduledPayments: return L10n.Notifications.scheduledPaymentsHint
        case .announcements: return L10n.Notifications.announcementsHint
        case .custom: return ""
        }
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
                            .font(.system(size: 22))
                            .foregroundStyle(Color(hex: category.colorHex))
                    }

                    Text(category.name)
                        .font(.caption2)
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
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.rawValue)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(currencyName(currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if showCheckmark {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.electricIndigo : .secondary)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.electricIndigo)
                }
            }
            .padding(DS.Spacing.md)
            .background(isSelected ? Color.electricIndigo.opacity(0.1) : Color.yalaCard)
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
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.electricIndigo)
                }
            }
            .padding(DS.Spacing.md)
            .background(isSelected ? Color.electricIndigo.opacity(0.1) : Color.yalaCard)
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
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(Color.yalaCard)
                        .clipShape(Capsule())
                }
            }

            // Next/Finish button
            Button {
                // Dismiss keyboard (especially important on step 1)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                #if DEV_BUILD
                let lastStep = 6
                #else
                let lastStep = 5
                #endif

                if currentStep < lastStep {
                    dsWithAnimation(reduceMotion) {
                        currentStep += 1
                    }
                    // Trigger category icons animation when entering step 4
                    if currentStep == 4 {
                        triggerCategoryAnimation()
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                #if DEV_BUILD
                let isLastStep = currentStep >= 6
                #else
                let isLastStep = currentStep >= 5
                #endif

                Text(isLastStep ? L10n.Onboarding.finish : L10n.Action.next)
                    .font(.body.weight(.semibold))
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
        switch currency {
        case .pen: return "🇵🇪"
        case .usd: return "🇺🇸"
        case .eur: return "🇪🇺"
        case .mxn: return "🇲🇽"
        case .cop: return "🇨🇴"
        case .brl: return "🇧🇷"
        case .gbp: return "🇬🇧"
        }
    }

    private func currencyName(_ currency: CurrencyCode) -> String {
        switch currency {
        case .pen: return L10n.Currency.pen
        case .usd: return L10n.Currency.usd
        case .eur: return L10n.Currency.eur
        case .mxn: return L10n.Currency.mxn
        case .cop: return L10n.Currency.cop
        case .brl: return L10n.Currency.brl
        case .gbp: return L10n.Currency.gbp
        }
    }

    private func completeOnboarding() {
        // Save user preferences
        let defaults = UserDefaults.standard

        // User name
        let finalName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(finalName.isEmpty ? "Usuario" : finalName, forKey: "userName")

        // Preferred currency
        defaults.set(selectedCurrency.rawValue, forKey: "defaultCurrencyCode")

        // Secondary currencies (store as comma-separated string)
        let secondaryArray = selectedSecondaryCurrencies.map { $0.rawValue }
        defaults.set(secondaryArray.joined(separator: ","), forKey: "secondaryCurrencies")

        // Default period
        defaults.set(selectedPeriod.rawValue, forKey: "defaultPeriod")

        // Mark onboarding as complete
        defaults.set(true, forKey: "hasCompletedOnboarding")

        defaults.synchronize()

        // Apply period to SessionState immediately (since it was created before onboarding)
        sessionState.selectedPeriod = selectedPeriod

        // Seed categories if user chose to
        if loadSeedCategories {
            seedCategoriesIfNeeded(in: modelContext)
        }

        #if DEV_BUILD
        // Seed dev data if user chose to (DEV_BUILD only)
        if loadDevData {
            seedDevDataIfEnabled(in: modelContext, preferredCurrency: selectedCurrency)
        }
        #endif

        // Create notifications based on user selection
        createSelectedNotifications()

        // Load historical exchange rates for secondary currencies (in background)
        loadHistoricalRatesForSecondaryCurrencies()

        // Notify completion
        onComplete()
    }

    private func loadHistoricalRatesForSecondaryCurrencies() {
        // Skip if no secondary currencies selected
        guard !selectedSecondaryCurrencies.isEmpty else { return }

        // Load exchange rates in background (after onboarding dismisses)
        Task {
            // Calculate 1 year date range
            let calendar = Calendar.current
            let today = Date()
            guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: today) else {
                return
            }

            let dateInterval = DateInterval(start: oneYearAgo, end: today)

            // Load historical rates for each secondary currency
            await ExchangeRateService.shared.ensureRates(for: dateInterval, context: modelContext)

            // Signal widget to refresh when user opens Panel
            SessionState.shared.needsExchangeRateWidgetRefresh = true

            #if DEBUG
                print(
                    "OnboardingView: Loaded historical rates for secondary currencies: \(selectedSecondaryCurrencies.map { $0.rawValue })"
                )
            #endif
        }
    }

    private func createSelectedNotifications() {
        // Create all default notifications
        let allDefaults = NotificationItem.createDefaults()

        for notification in allDefaults {
            // Set active state based on user selection
            let isSelected = selectedNotifications.contains(notification.notificationType)
            notification.isActive = isSelected

            modelContext.insert(notification)

            // Schedule if active
            if isSelected {
                Task {
                    await NotificationService.shared.scheduleNotification(for: notification)
                }
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("OnboardingView: Error saving notifications: \(error)")
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
        CategoryInfo(name: "Alimentación", colorHex: "#22C55E", iconName: "cart.fill"),
        CategoryInfo(name: "Compras", colorHex: "#F59E0B", iconName: "bag.fill"),
        CategoryInfo(name: "Transporte", colorHex: "#0EA5E9", iconName: "car.fill"),
        CategoryInfo(name: "Finanzas", colorHex: "#6366F1", iconName: "banknote.fill"),
        CategoryInfo(name: "Hogar", colorHex: "#475569", iconName: "house.fill"),
        CategoryInfo(name: "Entretenimiento", colorHex: "#FF0080", iconName: "sparkles"),
        CategoryInfo(name: "Personal", colorHex: "#A855F7", iconName: "person.fill"),
        CategoryInfo(name: "Mascotas", colorHex: "#84CC16", iconName: "pawprint.fill"),
        CategoryInfo(name: "Vehículo", colorHex: "#64748B", iconName: "car.side.fill"),
        CategoryInfo(name: "Ingresos", colorHex: "#14B8A6", iconName: "arrow.down.circle.fill"),
        CategoryInfo(name: "Otros", colorHex: "#64748B", iconName: "ellipsis.circle.fill"),
    ]
}

#Preview {
    OnboardingView {
        print("Onboarding completed!")
    }
}
