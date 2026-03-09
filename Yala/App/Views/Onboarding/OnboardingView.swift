//
//  OnboardingView.swift
//  Yala
//
//  Onboarding flow: 7 steps to get started.
//  0. Welcome + name, 1. Currency, 2. Usage mode, 3. Seed categories,
//  4. Account setup, 5. Quick budget (optional), 6. Privacy + finish.
//

import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .largeTitle) private var completionIconSize: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var appIconSize: CGFloat = 120
    @ScaledMetric(relativeTo: .body) private var categoryIconSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var notifIconSize: CGFloat = 52
    @ScaledMetric(relativeTo: .largeTitle) private var privacyIconSize: CGFloat = 100

    // User preferences (will be saved on completion)
    @State private var userName: String = ""
    @State private var selectedCurrency: CurrencyCode = CurrencyDefaults.detectCurrencyFromRegion()
    @State private var loadSeedCategories: Bool = true

    // Current step in the onboarding flow
    @State private var currentStep: Int = 0
    @State private var navigatingForward: Bool = true

    // Animation state for category grid
    @State private var showCategoryIcons: Bool = false

    // Usage mode preference (replaces simple expensesOnlyMode toggle)
    @State private var selectedUsageMode: UsageMode = .dayToDay

    /// Derived from selectedUsageMode for backward compatibility with existing logic
    private var expensesOnlyMode: Bool { selectedUsageMode == .expensesOnly }

    private enum UsageMode {
        case expensesOnly, dayToDay, fullControl
    }

    // Account setup state
    @State private var selectedAccountType: AccountType = .general
    @State private var accountName: String = ""
    @State private var accountCurrency: CurrencyCode = CurrencyDefaults.detectCurrencyFromRegion()
    @State private var initialBalanceText: String = ""
    @State private var balanceIsPositive: Bool = true
    @State private var showCurrencyPicker: Bool = false
    @State private var showBalanceGuide: Bool = false
    @FocusState private var accountNameFocused: Bool

    // Quick budget state
    @State private var wantsBudget: Bool = false
    @State private var selectedBudgetCategoryIndex: Int? = nil
    @State private var budgetAmountText: String = ""

    // Callback when onboarding completes
    var onComplete: () -> Void

    private let totalSteps = 7

    /// Account types available in onboarding (no credit card)
    private let onboardingAccountTypes: [AccountType] = [.general, .cash, .checking, .savings]

    /// Effective total steps (skips budget step if no seed categories)
    private var effectiveTotalSteps: Int {
        loadSeedCategories ? 7 : 6
    }

    /// Maps currentStep to visual progress index (accounts for skipped budget step)
    private var effectiveStepIndex: Int {
        if !loadSeedCategories && currentStep == 6 {
            return 5 // Privacy shows as last dot when budget is skipped
        }
        return currentStep
    }

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            // Progress indicator (hidden on final privacy step)
            progressIndicator
                .padding(.top, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)
                .opacity(currentStep < totalSteps - 1 ? 1 : 0)

            // Content based on current step
            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: currencyStep
                case 2: usageModeStep
                case 3: categoriesStep
                case 4: accountSetupStep
                case 5: quickBudgetStep
                case 6: privacyStep
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: navigatingForward ? .trailing : .leading),
                removal: .move(edge: navigatingForward ? .leading : .trailing)
            ))

            Spacer()

            // Navigation buttons
            navigationButtons
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)
        }
        .background(.thBackground)
        .onTapGesture {
            dismissKeyboard()
        }
        .task {
            // Pre-fill from synced preferences (populated by PreferenceSyncService.bootstrap())
            let defaults = UserDefaults.standard
            if let name = defaults.string(forKey: "userName"), !name.isEmpty, name != "Usuario" {
                userName = name
            }
            if let raw = defaults.string(forKey: "defaultCurrencyCode"),
               let currency = CurrencyCode(rawValue: raw) {
                selectedCurrency = currency
                accountCurrency = currency
            }
            if defaults.object(forKey: "expensesOnlyMode") != nil {
                if defaults.bool(forKey: "expensesOnlyMode") {
                    selectedUsageMode = .expensesOnly
                } else if defaults.string(forKey: "financialMindset") == "patrimonial" {
                    selectedUsageMode = .fullControl
                } else {
                    selectedUsageMode = .dayToDay
                }
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(0..<effectiveTotalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= effectiveStepIndex ? Color.electricIndigo : theme.secondaryText.opacity(0.2))
                    .frame(width: step == effectiveStepIndex ? 24 : 8, height: 8)
                    .dsAnimation(.spring(response: 0.3), value: effectiveStepIndex, reduceMotion: reduceMotion)
            }
        }
    }

    // MARK: - Step 0: Welcome & Name

    private var welcomeStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            // App icon with proper sizing (uses preview icon from Resources)
            Image(uiImage: UIImage(named: "IconOriginal@3x") ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(width: appIconSize, height: appIconSize)
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

    // MARK: - Step 1: Preferred Currency

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
                    recommendedCurrencySection(selected: selectedCurrency) {
                        selectedCurrency = recommendedCurrency
                    }

                    // Currencies by continent (excluding recommended)
                    ForEach(filteredContinentGroups, id: \.continent) { group in
                        continentCurrencySection(group)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
        }
    }

    private func recommendedCurrencySection(
        selected: CurrencyCode,
        onSelect: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Onboarding.recommended)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, DS.Spacing.xs)

            currencyRow(recommendedCurrency, isSelected: selected == recommendedCurrency, action: onSelect)
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
                    }
                }
            }
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }

    // MARK: - Step 2: Usage Mode

    private var usageModeStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "gearshape.fill")
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
                // Option 1: Expenses only
                usageModeCard(
                    mode: .expensesOnly,
                    title: L10n.Onboarding.usageModeExpensesOnly,
                    quote: L10n.Onboarding.usageModeExpensesOnlyQuote,
                    description: L10n.Onboarding.usageModeExpensesOnlyDesc
                )

                // Option 2: Day to day (default)
                usageModeCard(
                    mode: .dayToDay,
                    title: L10n.Onboarding.usageModeDayToDay,
                    quote: L10n.Onboarding.usageModeDayToDayQuote,
                    description: L10n.Onboarding.usageModeDayToDayDesc,
                    showRecommended: true
                )

                // Option 3: Full control
                usageModeCard(
                    mode: .fullControl,
                    title: L10n.Onboarding.usageModeFullControl,
                    quote: L10n.Onboarding.usageModeFullControlQuote,
                    description: L10n.Onboarding.usageModeFullControlDesc
                )
            }
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()
        }
    }

    private func usageModeCard(mode: UsageMode, title: String, quote: String, description: String, showRecommended: Bool = false) -> some View {
        let isSelected = selectedUsageMode == mode
        return Button {
            selectedUsageMode = mode
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(DS.Typography.title)
                        .foregroundStyle(isSelected ? Color.electricIndigo : .secondary)

                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    if showRecommended && isSelected {
                        Text(L10n.Onboarding.categoriesRecommended)
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.electricIndigo)
                    }
                }

                Text(quote)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.leading, DS.Spacing.xl + DS.Spacing.xs)

                Text(description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, DS.Spacing.xl + DS.Spacing.xs)
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

    // MARK: - Step 3: Seed Categories

    /// Seed categories filtered by usage mode (exclude income in expenses-only)
    private var filteredSeedCategories: [SeedCategoryPreview.CategoryInfo] {
        if expensesOnlyMode {
            return SeedCategoryPreview.categories.filter { $0.name != L10n.Category.incomeCategory }
        }
        return SeedCategoryPreview.categories
    }

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

    // MARK: - Step 4: Account Setup

    private var accountSetupStep: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                // Header
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: heroIconSize))
                        .foregroundStyle(Color.electricIndigo)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                    Text(L10n.Onboarding.accountTitle)
                        .font(DS.Typography.title)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(L10n.Onboarding.accountSubtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                }
                .padding(.top, DS.Spacing.md)

                // Account type pills
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(onboardingAccountTypes) { type in
                        Button {
                            selectedAccountType = type
                        } label: {
                            VStack(spacing: DS.Spacing.xs) {
                                Image(systemName: iconName(for: type))
                                    .font(DS.Typography.body)
                                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                                Text(type.localizedName)
                                    .font(DS.Typography.captionSmall)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .foregroundStyle(selectedAccountType == type ? Color.electricIndigo : .secondary)
                            .background(selectedAccountType == type ? Color.electricIndigo.opacity(0.1) : theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .stroke(selectedAccountType == type ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)

                // Form card (SectionBox style)
                SectionBox(title: L10n.Common.general) {
                    VStack(spacing: DS.Spacing.none) {
                        // Name row
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "textformat")
                                .foregroundStyle(.secondary)
                            TextField(L10n.Onboarding.accountNamePlaceholder, text: $accountName)
                                .focused($accountNameFocused)
                        }
                        .padding()

                        SubsectionDivider()

                        // Currency row (tappable to change)
                        Button {
                            accountNameFocused = false
                            showCurrencyPicker = true
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                Text(accountCurrency.flag)
                                    .font(DS.Typography.title)
                                Text(L10n.Onboarding.accountCurrencyLabel)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(accountCurrency.rawValue)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)

                // Balance section (only in full control mode)
                if !expensesOnlyMode {
                    SectionBox(title: L10n.Onboarding.accountBalanceLabel) {
                        VStack(spacing: DS.Spacing.none) {
                            // Sign selector (segmented)
                            HStack(spacing: DS.Spacing.md) {
                                Text(L10n.Account.sign)
                                    .font(DS.Typography.subheadline)
                                Spacer()
                                Picker(L10n.Account.sign, selection: $balanceIsPositive) {
                                    Text(L10n.Account.positive).tag(true)
                                    Text(L10n.Account.negative).tag(false)
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding()

                            SubsectionDivider()

                            // Amount input
                            HStack {
                                Spacer()
                                HStack(spacing: DS.Spacing.xs) {
                                    Text(accountCurrency.symbol)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.secondary)
                                    TextField("0", text: $initialBalanceText)
                                        .font(DS.Typography.largeTitle)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                            .padding()

                            SubsectionDivider()

                            // Contextual hint per account type
                            Text(selectedAccountType.balanceHint)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)

                    // Learn more link
                    Button {
                        showBalanceGuide = true
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "questionmark.circle")
                                .font(DS.Typography.subheadline)
                            Text(L10n.Onboarding.accountBalanceLearnMore)
                                .font(DS.Typography.subheadline)
                        }
                        .foregroundStyle(Color.electricIndigo)
                    }
                    .buttonStyle(.plain)
                }

                // Tip
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: "plus.circle")
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.electricIndigo)
                    Text(L10n.Onboarding.accountMoreTip)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.md)
                .background(Color.electricIndigo.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .padding(.horizontal, DS.Spacing.lg)
            }
            .padding(.vertical, DS.Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            accountCurrency = selectedCurrency
        }
        .sheet(isPresented: $showCurrencyPicker) {
            accountCurrencyPickerSheet
        }
        .sheet(isPresented: $showBalanceGuide) {
            BalanceCalculatorSheet(
                accountType: selectedAccountType,
                mindset: selectedUsageMode == .fullControl ? "patrimonial" : "cashFlow",
                currencySymbol: accountCurrency.symbol,
                onUseBalance: { amount in
                    if amount >= 0 {
                        balanceIsPositive = true
                        initialBalanceText = String(format: "%.2f", amount)
                    } else {
                        balanceIsPositive = false
                        initialBalanceText = String(format: "%.2f", abs(amount))
                    }
                },
                onDismiss: { showBalanceGuide = false }
            )
        }
    }

    // Balance guide sheet replaced by BalanceCalculatorSheet (shared component)

    /// Sheet for changing account currency
    private var accountCurrencyPickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.lg) {
                    recommendedCurrencySection(selected: accountCurrency) {
                        accountCurrency = recommendedCurrency
                        showCurrencyPicker = false
                    }

                    ForEach(filteredContinentGroups, id: \.continent) { group in
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(group.continent.localizedName)
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.leading, DS.Spacing.xs)

                            VStack(spacing: DS.Spacing.none) {
                                ForEach(group.currencies) { currency in
                                    currencyRow(currency, isSelected: accountCurrency == currency) {
                                        accountCurrency = currency
                                        showCurrencyPicker = false
                                    }
                                }
                            }
                            .background(.thCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.md)
            }
            .navigationTitle(L10n.Onboarding.currencyTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Action.cancel) {
                        showCurrencyPicker = false
                    }
                }
            }
            .background(.thBackground)
        }
    }


    // MARK: - Step 5: Quick Budget

    /// Budget-eligible categories (expense categories from seed, excluding income)
    private var budgetCategories: [SeedCategoryPreview.CategoryInfo] {
        SeedCategoryPreview.categories.filter { $0.name != L10n.Category.incomeCategory }
    }

    private var quickBudgetStep: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                // Header
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: heroIconSize))
                        .foregroundStyle(Color.electricIndigo)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                    Text(L10n.Onboarding.budgetTitle)
                        .font(DS.Typography.title)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(L10n.Onboarding.budgetSubtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                }
                .padding(.top, DS.Spacing.md)

                // Yes/No toggle cards
                VStack(spacing: DS.Spacing.sm) {
                    Button {
                        wantsBudget = true
                    } label: {
                        HStack {
                            Image(systemName: wantsBudget ? "checkmark.circle.fill" : "circle")
                                .font(DS.Typography.title)
                                .foregroundStyle(wantsBudget ? Color.electricIndigo : .secondary)

                            Text(L10n.Onboarding.budgetYes)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding(DS.Spacing.md)
                        .background(wantsBudget ? Color.electricIndigo.opacity(0.1) : theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(wantsBudget ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        wantsBudget = false
                    } label: {
                        HStack {
                            Image(systemName: wantsBudget ? "circle" : "checkmark.circle.fill")
                                .font(DS.Typography.title)
                                .foregroundStyle(wantsBudget ? .secondary : Color.electricIndigo)

                            Text(L10n.Onboarding.budgetNo)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding(DS.Spacing.md)
                        .background(wantsBudget ? theme.card : Color.electricIndigo.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(wantsBudget ? DS.Colors.borderSubtle : Color.electricIndigo.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DS.Spacing.xl)

                // Budget details (animated, only if wantsBudget)
                if wantsBudget {
                    VStack(spacing: DS.Spacing.lg) {
                        // Category selection — horizontal scrollable pills
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(L10n.Onboarding.budgetCategoryLabel)
                                .font(DS.Typography.label)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xl)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DS.Spacing.sm) {
                                    ForEach(Array(budgetCategories.enumerated()), id: \.offset) { index, category in
                                        Button {
                                            selectedBudgetCategoryIndex = index
                                        } label: {
                                            HStack(spacing: DS.Spacing.xs) {
                                                Image(systemName: category.iconName)
                                                    .font(DS.Typography.caption)
                                                    .foregroundStyle(Color(hex: category.colorHex))

                                                Text(category.name)
                                                    .font(DS.Typography.subheadline)
                                                    .foregroundStyle(selectedBudgetCategoryIndex == index ? .primary : .secondary)
                                                    .lineLimit(1)
                                            }
                                            .padding(.horizontal, DS.Spacing.md)
                                            .padding(.vertical, DS.Spacing.sm)
                                            .background(selectedBudgetCategoryIndex == index ? Color.electricIndigo.opacity(0.1) : theme.card)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(selectedBudgetCategoryIndex == index ? Color.electricIndigo.opacity(0.4) : DS.Colors.borderSubtle, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.xl)
                            }
                        }

                        // Amount field — modern centered style
                        SectionBox(title: L10n.Onboarding.budgetAmountLabel) {
                            HStack {
                                Spacer()
                                HStack(spacing: DS.Spacing.xs) {
                                    Text(accountCurrency.symbol)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.secondary)
                                    TextField("0", text: $budgetAmountText)
                                        .font(DS.Typography.largeTitle)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                            .padding()
                        }
                        .padding(.horizontal, DS.Spacing.lg)

                        // Live preview card — mirrors BudgetRowView
                        budgetPreviewCard
                            .padding(.horizontal, DS.Spacing.lg)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

            }
            .padding(.bottom, DS.Spacing.xl)
            .dsAnimation(.easeInOut(duration: 0.3), value: wantsBudget, reduceMotion: reduceMotion)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
    }

    /// Live preview card that mirrors BudgetRowView appearance
    private var budgetPreviewCard: some View {
        let cats = budgetCategories
        let selectedCategory = selectedBudgetCategoryIndex
            .flatMap { $0 < cats.count ? cats[$0] : nil }

        let budgetAmount = Double(budgetAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let hasCategory = selectedCategory != nil
        let hasAmount = budgetAmount > 0

        let iconName = selectedCategory?.iconName ?? "questionmark"
        let colorHex = selectedCategory?.colorHex ?? "#8E8E93"
        let categoryName = selectedCategory?.name ?? L10n.Onboarding.budgetCategoryLabel
        let formattedLimit = YalaFormatter.currency(value: budgetAmount, currencyCode: accountCurrency.rawValue)
        let formattedZero = YalaFormatter.currency(value: 0, currencyCode: accountCurrency.rawValue)

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Onboarding.budgetPreviewLabel)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.md) {
                    // Icon badge
                    ZStack {
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: categoryIconSize, height: categoryIconSize)

                        Image(systemName: iconName)
                            .font(DS.Typography.label)
                            .foregroundStyle(.white)
                    }

                    // Name + period
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(categoryName)
                            .font(DS.Typography.headline)
                            .foregroundStyle(hasCategory ? .primary : .secondary)
                            .lineLimit(1)

                        Text(NSLocalizedString("budgets.period.monthly", comment: ""))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Amount
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        Text(formattedZero)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)

                        Text(String(format: NSLocalizedString("budgets.amount.of", comment: ""), formattedLimit))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary.opacity(hasAmount ? 1 : 0.4))
                    }
                }

                // Progress bar (always empty)
                BudgetProgressBar(
                    percentage: 0,
                    color: colorHex,
                    isExceeded: false
                )
            }
            .yalaCard(padding: DS.Spacing.lg, radius: DS.Radius.md)
        }
        .dsAnimation(.easeInOut(duration: 0.25), value: selectedBudgetCategoryIndex, reduceMotion: reduceMotion)
    }

    // MARK: - Step 6: Privacy & Finish

    private var privacyStep: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Checkmark icon with gradient circle background
                    ZStack {
                        Circle()
                            .fill(Color.electricIndigo.opacity(0.12))
                            .frame(width: privacyIconSize, height: privacyIconSize)

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
                }
                .padding(.vertical, DS.Spacing.xl)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func privacyPoint(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: badgeSize, height: badgeSize)

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
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]

        return LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            ForEach(Array(filteredSeedCategories.enumerated()), id: \.offset) { index, category in
                VStack(spacing: DS.Spacing.xs) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: category.colorHex).opacity(0.2))
                            .frame(width: notifIconSize, height: notifIconSize)

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
                Text(currency.flag)
                    .font(DS.Typography.title)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(currency.rawValue)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.primary)
                    Text(currency.localizedName)
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

    // MARK: - Navigation Buttons

    /// Whether the Next button should be disabled for the current step
    private var isNextDisabled: Bool {
        switch currentStep {
        case 0:
            return userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 4:
            return accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 5:
            // If user wants a budget, require category + valid amount
            if wantsBudget {
                let cleanedAmount = budgetAmountText.replacingOccurrences(of: ",", with: ".")
                guard let index = selectedBudgetCategoryIndex,
                      index < budgetCategories.count,
                      let amount = Double(cleanedAmount),
                      amount > 0
                else { return true }
            }
            return false
        default:
            return false
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: DS.Spacing.md) {
            // Back button (hidden on first step)
            if currentStep > 0 {
                Button {
                    navigatingForward = false
                    dsWithAnimation(reduceMotion, .easeInOut(duration: 0.3)) {
                        // Skip budget step on back if no seed categories
                        if currentStep == 6 && !loadSeedCategories {
                            currentStep = 4
                        } else {
                            currentStep -= 1
                        }
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
                // Dismiss keyboard (especially important on step 0)
                dismissKeyboard()

                if currentStep < totalSteps - 1 {
                    navigatingForward = true
                    // Compute destination before animation to avoid reading stale state
                    let nextStep = (currentStep == 4 && !loadSeedCategories) ? 6 : currentStep + 1
                    dsWithAnimation(reduceMotion, .easeInOut(duration: 0.3)) {
                        currentStep = nextStep
                    }
                    // Trigger category icons animation when entering categories step
                    if nextStep == 3 {
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
                    .background(isNextDisabled ? Color.electricIndigo.opacity(0.4) : Color.electricIndigo)
                    .clipShape(Capsule())
            }
            .disabled(isNextDisabled)
        }
    }

    // MARK: - Helpers

    private func completeOnboarding() {
        // Save user preferences via PreferenceSyncService (dual-writes to UserDefaults + iCloud KV)
        let sync = PreferenceSyncService.shared

        // User name
        let finalName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        sync.set(string: finalName.isEmpty ? L10n.Profile.defaultName : finalName, forKey: "userName")

        // Preferred currency
        sync.set(string: selectedCurrency.rawValue, forKey: "defaultCurrencyCode")

        // Default period (hardcode .thisMonth — 80%+ of users don't need to change it)
        sync.set(string: DetailPeriod.thisMonth.rawValue, forKey: "defaultPeriod")
        sessionState.selectedPeriod = .thisMonth

        // Expenses-only mode (didSet propagates to app group)
        sync.set(bool: expensesOnlyMode, forKey: "expensesOnlyMode")
        sessionState.isExpensesOnlyMode = expensesOnlyMode

        // Financial mindset (educational UI only)
        let mindset = selectedUsageMode == .fullControl ? "patrimonial" : "cashFlow"
        sync.set(string: mindset, forKey: "financialMindset")
        sessionState.financialMindset = mindset

        // Seed categories if user chose to
        if loadSeedCategories {
            seedCategoriesIfNeeded(in: modelContext)
        }

        // Ensure balance adjustment subcategory exists when no seed categories + control total
        if !loadSeedCategories && !expensesOnlyMode {
            InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: modelContext)
        }

        // Create account from step 4
        createOnboardingAccount()

        // Create budget if selected in step 5
        if wantsBudget && loadSeedCategories {
            createOnboardingBudget()
        }

        // Create all notifications as inactive (no user selection step)
        createDefaultNotifications()

        // Single save for all data created above (account, budget, notifications, subcategory)
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("OnboardingView: Error saving onboarding data: \(error)")
            #endif
        }

        // Mark onboarding as complete AFTER data creation (prevents inconsistent state on crash)
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Signal other devices that onboarding is done (cross-device wipe coordination)
        PreferenceSyncService.shared.signalOnboardingCompleted()

        // Force update today's exchange rate in background
        Task {
            await ExchangeRateService.shared.forceUpdateToday(context: modelContext)
            SessionState.shared.needsExchangeRateWidgetRefresh = true
        }

        // Notify completion
        onComplete()
    }

    private func createOnboardingAccount() {
        let finalName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = finalName.isEmpty ? selectedAccountType.localizedName : finalName

        let account = Account(
            name: name,
            currencyCode: accountCurrency.rawValue,
            colorHex: AppConstants.defaultColorHex,
            iconName: iconName(for: selectedAccountType),
            type: selectedAccountType.rawValue
        )
        modelContext.insert(account)

        // Set initial balance if in full control mode and amount > 0
        if !expensesOnlyMode {
            let cleanedText = initialBalanceText.replacingOccurrences(of: ",", with: ".")
            if let amount = Double(cleanedText), amount != 0 {
                let signedAmount = balanceIsPositive ? amount : -amount
                if let sub = InitialBalanceService.findBalanceAdjustmentSubcategory(context: modelContext) {
                    _ = InitialBalanceService.setInitialBalance(
                        amount: signedAmount,
                        for: account,
                        subcategory: sub,
                        allTransactions: [],
                        context: modelContext
                    )
                } else {
                    #if DEBUG
                    print("OnboardingView: Balance adjustment subcategory not found — initial balance not set")
                    #endif
                }
            }
        }
    }

    private func createOnboardingBudget() {
        guard let catIndex = selectedBudgetCategoryIndex else { return }

        let cleanedText = budgetAmountText.replacingOccurrences(of: ",", with: ".")
        guard let budgetAmount = Double(cleanedText), budgetAmount > 0 else { return }

        // Get the category info from preview
        let cats = budgetCategories
        guard catIndex < cats.count else { return }
        let catInfo = cats[catIndex]

        // Find the real Category by name in context (just seeded)
        let categoryName = catInfo.name
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { category in
                category.name == categoryName
            }
        )

        do {
            let categories = try modelContext.fetch(descriptor)
            guard let category = categories.first else {
                #if DEBUG
                print("OnboardingView: Could not find category '\(categoryName)' for budget")
                #endif
                return
            }

            // Get all subcategories for this category
            let subcategories = category.subcategories ?? []

            let budget = Budget(
                currencyCode: accountCurrency.rawValue,
                limitAmount: budgetAmount,
                category: category,
                name: category.name,
                periodType: "monthly",
                subcategories: subcategories
            )
            modelContext.insert(budget)
            #if DEBUG
            print("OnboardingView: Created budget '\(category.name)' with limit \(budgetAmount)")
            #endif
        } catch {
            #if DEBUG
            print("OnboardingView: Error finding category for budget: \(error)")
            #endif
        }
    }

    private func createDefaultNotifications() {
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

        // Create all default notifications as inactive
        let allDefaults = NotificationItem.createDefaults()
        var inserted = 0

        for notification in allDefaults {
            guard !existingTypes.contains(notification.typeRaw) else { continue }
            notification.isActive = false
            modelContext.insert(notification)
            inserted += 1
        }

        #if DEBUG
        if inserted > 0 {
            print("OnboardingView: Created \(inserted) notification types (all inactive)")
        }
        #endif
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
        CategoryInfo(name: L10n.Category.finance, colorHex: AppConstants.defaultColorHex, iconName: "banknote.fill"),
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
    OnboardingView {}
}
