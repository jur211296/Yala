//
//  OnboardingView.swift
//  Yala
//
//  Conversational onboarding flow: binary decisions.
//  1. Name, 2. Purpose (binary), 3. Accounts (binary, skip if expensesOnly),
//  4. Account type (skip if not fullControl), 5. Name + currency,
//  6. Balance (skip if expensesOnly), 7. Confirmation, 8. Categories, 9. Privacy.
//

import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .largeTitle) private var completionIconSize: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var appIconSize: CGFloat = 120
    @ScaledMetric(relativeTo: .body) private var categoryIconSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var notifIconSize: CGFloat = 52
    @ScaledMetric(relativeTo: .largeTitle) private var privacyIconSize: CGFloat = 100

    // User preferences (saved on completion)
    @State private var userName: String = ""
    @State private var selectedCurrency: CurrencyCode = CurrencyDefaults.detectCurrencyFromRegion()
    @State private var loadSeedCategories: Bool = true

    // Step navigation
    @State private var currentStep: Step = .name
    @State private var navigatingForward: Bool = true

    // Purpose & accounts (binary decisions)
    @State private var selectedUsageMode: UsageMode = .dayToDay
    @State private var selectedMindset: String = "patrimonial"

    /// Derived from selectedUsageMode — true when user chose "varias cuentas"
    private var wantsSeparateAccounts: Bool { selectedUsageMode == .fullControl }

    private var expensesOnlyMode: Bool { selectedUsageMode == .expensesOnly }

    private enum UsageMode {
        case expensesOnly, dayToDay, fullControl
    }

    // Animation state for category grid
    @State private var showCategoryIcons: Bool = false

    // Account setup state
    @State private var selectedAccountType: AccountType = .general
    @State private var accountName: String = ""
    @State private var accountCurrency: CurrencyCode = CurrencyDefaults.detectCurrencyFromRegion()
    @State private var initialBalanceText: String = ""
    @State private var balanceIsPositive: Bool = true
    @State private var showCurrencyPicker: Bool = false
    @State private var showBalanceGuide: Bool = false
    @State private var calcFieldState = BalanceCalculatorFieldState()
    @FocusState private var accountNameFocused: Bool
    @State private var lastAutoName: String = ""

    // Budget state (preserved for completeOnboarding — budget step removed from flow)
    @State private var wantsBudget: Bool = false
    @State private var selectedBudgetCategoryIndex: Int? = nil
    @State private var budgetAmountText: String = ""

    var onComplete: () -> Void

    // MARK: - Step Definition

    private enum Step: Int, CaseIterable {
        case name = 0
        case purpose = 1       // "¿Qué te gustaría hacer?" (binary)
        case accounts = 2      // "¿Cómo organizas?" (binary) — skip if expensesOnly
        case accountType = 3   // "¿Cuál es tu primera cuenta?" — skip if not fullControl
        case currencyName = 4
        case balance = 5       // skip if expensesOnly
        case categories = 6
        case confirmation = 7  // Resumen + privacidad (último paso)
    }

    /// Account types for fullControl picker (no .general — separate accounts have real types)
    private let fullControlAccountTypes: [AccountType] = [.checking, .savings, .creditCard, .cash]

    // MARK: - Step Navigation

    private var skippedSteps: Set<Step> {
        if expensesOnlyMode {
            return [.accounts, .accountType, .balance]
        } else if selectedUsageMode == .dayToDay {
            return [.accountType]
        }
        return []
    }

    private var effectiveSteps: [Step] {
        Step.allCases.filter { !skippedSteps.contains($0) }
    }

    private var effectiveTotalSteps: Int { effectiveSteps.count }

    private var effectiveStepIndex: Int {
        effectiveSteps.firstIndex(of: currentStep) ?? 0
    }

    private func nextStep(after step: Step) -> Step? {
        guard let idx = effectiveSteps.firstIndex(of: step),
              idx + 1 < effectiveSteps.count else { return nil }
        return effectiveSteps[idx + 1]
    }

    private func previousStep(before step: Step) -> Step? {
        guard let idx = effectiveSteps.firstIndex(of: step), idx > 0 else { return nil }
        return effectiveSteps[idx - 1]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            progressIndicator
                .padding(.top, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)

            Group {
                switch currentStep {
                case .name: nameStep
                case .purpose: purposeStep
                case .accounts: accountsStep
                case .accountType: accountTypeStep
                case .currencyName: currencyNameStep
                case .balance: balanceStep
                case .categories: categoriesStep
                case .confirmation: confirmationStep
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: navigatingForward ? .trailing : .leading),
                removal: .move(edge: navigatingForward ? .leading : .trailing)
            ))
        }
        .safeAreaInset(edge: .bottom) {
            floatingNavigationButtons
        }
        .background(.thBackground)
        .onTapGesture {
            dismissKeyboard()
        }
        .task {
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
                    selectedMindset = "cashFlow"
                } else if defaults.string(forKey: "financialMindset") == "cashFlow" {
                    // cashFlow = separate accounts
                    selectedUsageMode = .fullControl
                    selectedMindset = "cashFlow"
                } else {
                    // patrimonial or default = single account
                    selectedUsageMode = .dayToDay
                    selectedMindset = "patrimonial"
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

    // MARK: - Step 1: Name

    private var nameStep: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    Spacer()

                    Image(uiImage: UIImage(named: "IconOriginal@3x") ?? UIImage())
                        .resizable()
                        .scaledToFit()
                        .frame(width: appIconSize, height: appIconSize)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .accessibilityHidden(true)

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
                            .textContentType(.nickname)
                            .font(DS.Typography.body)
                            .padding(DS.Spacing.md)
                            .background(.thCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .accessibilityIdentifier("onboarding_name_field")
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                            )

                        Text(L10n.Onboarding.nameHint)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.xl)

                    Spacer()
                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Step 2: Purpose (binary)

    private var purposeStep: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "target")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(Color.electricIndigo)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityHidden(true)

                        Text(L10n.Onboarding.purposeTitle)
                            .font(DS.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xl)

                    VStack(spacing: DS.Spacing.sm) {
                        binaryCard(
                            isSelected: !expensesOnlyMode,
                            icon: "dollarsign.circle",
                            title: L10n.Onboarding.purposeControl,
                            description: L10n.Onboarding.purposeControlDesc,
                            accessibilityId: "onboarding_purpose_control"
                        ) {
                            if expensesOnlyMode {
                                selectedUsageMode = .dayToDay
                            }
                        }

                        binaryCard(
                            isSelected: expensesOnlyMode,
                            icon: "list.bullet.clipboard",
                            title: L10n.Onboarding.purposeExpenses,
                            description: L10n.Onboarding.purposeExpensesDesc,
                            accessibilityId: "onboarding_purpose_expenses"
                        ) {
                            selectedUsageMode = .expensesOnly
                            selectedMindset = "cashFlow"
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)

                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Step 3: Accounts (binary)

    private var accountsStep: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(Color.electricIndigo)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityHidden(true)

                        Text(L10n.Onboarding.accountsTitle)
                            .font(DS.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xl)

                    VStack(spacing: DS.Spacing.sm) {
                        binaryCard(
                            isSelected: !wantsSeparateAccounts,
                            icon: "creditcard",
                            title: L10n.Onboarding.accountsSingle,
                            description: L10n.Onboarding.accountsSingleDesc,
                            accessibilityId: "onboarding_accounts_single"
                        ) {
                            selectedUsageMode = .dayToDay
                            selectedMindset = "patrimonial"
                            selectedAccountType = .general
                        }

                        binaryCard(
                            isSelected: wantsSeparateAccounts,
                            icon: "rectangle.stack",
                            title: L10n.Onboarding.accountsMultiple,
                            description: L10n.Onboarding.accountsMultipleDesc,
                            accessibilityId: "onboarding_accounts_multiple"
                        ) {
                            selectedUsageMode = .fullControl
                            selectedMindset = "cashFlow"
                            selectedAccountType = .checking
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)

                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            if !wantsSeparateAccounts {
                selectedMindset = "patrimonial"
                selectedAccountType = .general
            } else {
                selectedMindset = "cashFlow"
            }
        }
    }

    // MARK: - Reusable Binary Card

    private func binaryCard(
        isSelected: Bool,
        icon: String,
        title: String,
        description: String,
        accessibilityId: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.electricIndigo : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.electricIndigo : theme.secondaryText.opacity(0.3))
            }
            .padding(DS.Spacing.lg)
            .background(isSelected ? Color.electricIndigo.opacity(0.1) : theme.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(isSelected ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
            )
            .shadow(color: .black.opacity(theme.shadowOpacity), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
    }

    // MARK: - Step 4: Account Type (fullControl only)

    private var accountTypeStep: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "wallet.bifold")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(Color.electricIndigo)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityHidden(true)

                        Text(L10n.Onboarding.accountTypeTitle)
                            .font(DS.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text(L10n.Onboarding.accountTypeSubtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.xl)
                    }
                    .padding(.top, DS.Spacing.xl)

                    // 4 account type cards
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(fullControlAccountTypes) { type in
                            let isSelected = selectedAccountType == type
                            Button {
                                if selectedAccountType != type {
                                    selectedAccountType = type
                                    calcFieldState.reset()
                                }
                            } label: {
                                HStack(spacing: DS.Spacing.md) {
                                    Image(systemName: iconName(for: type))
                                        .font(.system(size: 22))
                                        .foregroundStyle(isSelected ? Color.electricIndigo : .secondary)
                                        .frame(width: 32)

                                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                        Text(type.localizedName)
                                            .font(DS.Typography.bodyBold)
                                            .foregroundStyle(.primary)

                                        Text(type.typeDescription)
                                            .font(DS.Typography.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(isSelected ? Color.electricIndigo : theme.secondaryText.opacity(0.3))
                                }
                                .padding(DS.Spacing.lg)
                                .background(isSelected ? Color.electricIndigo.opacity(0.1) : theme.card)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                                        .stroke(isSelected ? Color.electricIndigo.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("onboarding_account_type_\(type.rawValue)")
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)

                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Step 5: Account Name + Currency

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

    /// Suggested account name based on type and currency
    private var suggestedAccountName: String {
        let currency = accountCurrency.shortPluralName.capitalized
        if wantsSeparateAccounts {
            // "Cuenta Corriente Soles", "Ahorros Dólares", etc.
            return "\(selectedAccountType.localizedName) \(currency)"
        } else {
            // "Gastos Soles", "Gastos Dólares", etc.
            return "\(L10n.CashFlow.expense) \(currency)"
        }
    }

    private var currencyNameStep: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: wantsSeparateAccounts ? "pencil.circle" : "star.circle")
                        .font(.system(size: heroIconSize))
                        .foregroundStyle(Color.electricIndigo)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .accessibilityHidden(true)

                    Text(wantsSeparateAccounts
                         ? L10n.Onboarding.currencyNameTitleSeparate
                         : L10n.Onboarding.currencyNameTitleSingle)
                        .font(DS.Typography.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(wantsSeparateAccounts
                         ? L10n.Onboarding.currencyNameSubtitleSeparate
                         : L10n.Onboarding.currencyNameSubtitleSingle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                }
                .padding(.top, DS.Spacing.md)

                // Account name
                SectionBox(title: L10n.Onboarding.accountNameLabel) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.secondary)
                        TextField(L10n.Onboarding.accountNamePlaceholder, text: $accountName)
                            .focused($accountNameFocused)
                            .accessibilityIdentifier("onboarding_account_name")
                    }
                    .padding()
                }
                .padding(.horizontal, DS.Spacing.lg)

                // Currency
                SectionBox(title: L10n.Onboarding.accountCurrencyLabel) {
                    Button {
                        accountNameFocused = false
                        showCurrencyPicker = true
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Text(accountCurrency.flag)
                                .font(DS.Typography.title)
                            Text(accountCurrency.localizedName)
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
                .padding(.horizontal, DS.Spacing.lg)
            }
            .padding(.vertical, DS.Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            accountCurrency = selectedCurrency
            let suggested = suggestedAccountName
            if accountName.isEmpty || accountName == lastAutoName {
                accountName = suggested
                lastAutoName = suggested
            }
        }
        .sheet(isPresented: $showCurrencyPicker) {
            accountCurrencyPickerSheet
        }
    }

    // MARK: - Step 6: Balance (auto-launch calculator)

    private var balanceStep: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(Color.electricIndigo)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityHidden(true)

                        Text(L10n.Onboarding.balanceTitle)
                            .font(DS.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text(L10n.Onboarding.balanceSubtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.xl)
                    }
                    .padding(.top, DS.Spacing.md)

                    // Balance display (filled by calculator or manual input)
                    SectionBox(title: L10n.Onboarding.accountBalanceLabel) {
                        VStack(spacing: DS.Spacing.none) {
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
                                        .accessibilityIdentifier("onboarding_balance")
                                }
                            }
                            .padding()
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)

                    // Recalculate button
                    Button {
                        showBalanceGuide = true
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(DS.Typography.subheadline)
                            Text(L10n.Onboarding.accountBalanceLearnMore)
                                .font(DS.Typography.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(Color.electricIndigo)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.vertical, DS.Spacing.md)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .task {
            // Derivar mindset correcto según configuración de cuentas
            if selectedUsageMode == .dayToDay && selectedAccountType == .general {
                selectedMindset = "patrimonial"
            } else if selectedUsageMode == .fullControl {
                selectedMindset = "cashFlow"
            }

            // Auto-launch calculadora si balance vacío
            if initialBalanceText.isEmpty && !showBalanceGuide {
                do {
                    try await Task.sleep(for: .milliseconds(400))
                    showBalanceGuide = true
                } catch {
                    // Task cancelled (user navigated away) — skip auto-launch
                }
            }
        }
        .sheet(isPresented: $showBalanceGuide) {
            BalanceCalculatorSheet(
                accountType: selectedAccountType,
                mindset: selectedMindset,
                currencySymbol: accountCurrency.symbol,
                fieldState: calcFieldState,
                onUseBalance: { amount in
                    if amount >= 0 {
                        balanceIsPositive = true
                        initialBalanceText = AmountInputHelper.formatWithGrouping(amount)
                    } else {
                        balanceIsPositive = false
                        initialBalanceText = AmountInputHelper.formatWithGrouping(abs(amount))
                    }
                },
                onDismiss: { showBalanceGuide = false }
            )
        }
    }

    // MARK: - Step 7: Confirmation

    private var confirmationMotivation: String {
        switch selectedUsageMode {
        case .expensesOnly: return L10n.Onboarding.confirmMotivationExpenses
        case .dayToDay: return L10n.Onboarding.confirmMotivationDayToDay
        case .fullControl: return L10n.Onboarding.confirmMotivationFullControl
        }
    }

    private var confirmationStep: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Motivational message at top
                    Text(confirmationMotivation)
                        .font(DS.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.electricIndigo)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.top, DS.Spacing.xxxl)

                    Text(L10n.Onboarding.confirmTitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Visual summary items
                    VStack(spacing: DS.Spacing.lg) {
                        confirmItem(
                            icon: "person.fill",
                            color: Color.electricIndigo,
                            value: userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? L10n.Profile.defaultName : userName
                        )

                        confirmItem(
                            icon: iconName(for: selectedAccountType),
                            color: .hotPink,
                            value: (accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? selectedAccountType.localizedName : accountName)
                                + " · \(accountCurrency.rawValue)"
                        )

                        if !expensesOnlyMode {
                            let amount = AmountInputHelper.parseDecimal(initialBalanceText)
                            let displayAmount = amount > 0 ? (balanceIsPositive ? amount : -amount) : 0.0
                            let formattedBalance = appPreferences.currency(displayAmount,
                                currencyCode: accountCurrency.rawValue
                            )

                            confirmItem(
                                icon: "banknote",
                                color: Color.electricIndigo,
                                value: formattedBalance
                            )
                        }

                        if expensesOnlyMode {
                            confirmItem(
                                icon: "list.bullet.clipboard",
                                color: .secondary,
                                value: L10n.Onboarding.purposeExpenses
                            )
                        }

                        confirmItem(
                            icon: "folder.fill",
                            color: .orange,
                            value: loadSeedCategories
                                ? L10n.Onboarding.categoriesDefault
                                : L10n.Onboarding.categoriesCustom
                        )
                    }
                    .padding(.horizontal, DS.Spacing.xl)

                    // Privacy section — visually distinct from user data
                    VStack(spacing: DS.Spacing.md) {
                        HStack {
                            Rectangle()
                                .fill(.thSecondaryText.opacity(0.2))
                                .frame(height: 1)
                            Text(L10n.Onboarding.privacyTitle)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .layoutPriority(1)
                            Rectangle()
                                .fill(.thSecondaryText.opacity(0.2))
                                .frame(height: 1)
                        }

                        VStack(spacing: DS.Spacing.xs) {
                            privacyBullet(icon: "iphone", text: L10n.Onboarding.privacyLocal)
                            privacyBullet(icon: "eye.slash.fill", text: L10n.Onboarding.privacyNoTracking)
                            privacyBullet(icon: "person.badge.key.fill", text: L10n.Onboarding.privacyIcloud)
                            privacyBullet(icon: "lock.shield.fill", text: L10n.Onboarding.privacyNoSharing)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)

                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func confirmItem(icon: String, color: Color, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: badgeSize, height: badgeSize)

                Image(systemName: icon)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(color)
            }

            Text(value)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Step 8: Categories

    private var filteredSeedCategories: [SeedCategoryPreview.CategoryInfo] {
        if expensesOnlyMode {
            return SeedCategoryPreview.categories.filter { $0.name != L10n.Category.incomeCategory }
        }
        return SeedCategoryPreview.categories
    }

    @State private var showSubcategorySheet: Bool = false

    private var categoriesStep: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(Color.electricIndigo)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityHidden(true)

                        Text(L10n.Onboarding.categoriesTitle)
                            .font(DS.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text(L10n.Onboarding.categoriesSubtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.xl)
                    }
                    .padding(.top, DS.Spacing.md)

                    // Category icon grid (compact)
                    categoryIconsGrid
                        .padding(.horizontal, DS.Spacing.lg)

                    // Subcategory info + link
                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.Onboarding.categoriesInfo)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            showSubcategorySheet = true
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "list.bullet")
                                    .font(DS.Typography.subheadline)
                                Text(L10n.Onboarding.categoriesViewSubs)
                                    .font(DS.Typography.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(Color.electricIndigo)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DS.Spacing.xl)

                    // Selection buttons
                    VStack(spacing: DS.Spacing.sm) {
                        binaryCard(
                            isSelected: loadSeedCategories,
                            icon: "checkmark.circle",
                            title: L10n.Onboarding.categoriesYes,
                            description: L10n.Onboarding.categoriesRecommended,
                            accessibilityId: "onboarding_categories_yes"
                        ) {
                            loadSeedCategories = true
                        }

                        binaryCard(
                            isSelected: !loadSeedCategories,
                            icon: "xmark.circle",
                            title: L10n.Onboarding.categoriesNo,
                            description: "",
                            accessibilityId: "onboarding_categories_no"
                        ) {
                            loadSeedCategories = false
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.md)
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            triggerCategoryAnimation()
        }
        .sheet(isPresented: $showSubcategorySheet) {
            subcategoryPreviewSheet
        }
    }

    /// Grid of category icons with staggered animation
    private var categoryIconsGrid: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]

        return LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            ForEach(Array(filteredSeedCategories.enumerated()), id: \.element.name) { index, category in
                VStack(spacing: DS.Spacing.xs) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: category.colorHex).opacity(0.2))
                            .frame(width: notifIconSize, height: notifIconSize)

                        Image(systemName: category.iconName)
                            .font(DS.Typography.title)
                            .foregroundStyle(Color(hex: category.colorHex))
                            .accessibilityHidden(true)
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

    /// Sheet showing subcategory details
    private var subcategoryPreviewSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    ForEach(filteredSeedCategories, id: \.name) { category in
                        HStack(spacing: DS.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: category.colorHex).opacity(0.2))
                                    .frame(width: categoryIconSize, height: categoryIconSize)
                                Image(systemName: category.iconName)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(Color(hex: category.colorHex))
                            }

                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(category.name)
                                    .font(DS.Typography.bodyBold)
                                    .foregroundStyle(.primary)

                                if !category.subcategoryPreview.isEmpty {
                                    Text(category.subcategoryPreview)
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, DS.Spacing.xl)
                    }
                }
                .padding(.vertical, DS.Spacing.md)
            }
            .navigationTitle(L10n.Onboarding.categoriesTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Action.close) {
                        showSubcategorySheet = false
                    }
                }
            }
            .background(.thBackground)
        }
    }

    // MARK: - Reusable Components

    private func privacyBullet(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func triggerCategoryAnimation() {
        showCategoryIcons = false
        let reduce = reduceMotion
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            dsWithAnimation(reduce) {
                showCategoryIcons = true
            }
        }
    }

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

    // MARK: - Navigation Buttons

    private var isNextDisabled: Bool {
        switch currentStep {
        case .name:
            return userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .accountType:
            return !fullControlAccountTypes.contains(selectedAccountType)
        case .currencyName:
            return accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .balance:
            return initialBalanceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }

    private var floatingNavigationButtons: some View {
        VStack(spacing: DS.Spacing.none) {
            Rectangle()
                .fill(.thBackground)
                .mask(
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: DS.Spacing.xxl)
                .allowsHitTesting(false)

            navigationButtons
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)
                .padding(.top, DS.Spacing.sm)
                .background(.thBackground)
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: DS.Spacing.md) {
            if currentStep != .name {
                Button {
                    navigatingForward = false
                    dsWithAnimation(reduceMotion, .easeInOut(duration: 0.3)) {
                        if let prev = previousStep(before: currentStep) {
                            currentStep = prev
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
                        .shadow(color: .black.opacity(theme.shadowOpacity), radius: 6, x: 0, y: 3)
                }
            }

            YalaPrimaryButton(
                currentStep == .confirmation ? L10n.Onboarding.finish : L10n.Action.next,
                isDisabled: isNextDisabled
            ) {
                dismissKeyboard()

                if currentStep == .confirmation {
                    // Sync currency before completing
                    selectedCurrency = accountCurrency
                    completeOnboarding()
                } else if let next = nextStep(after: currentStep) {
                    navigatingForward = true
                    dsWithAnimation(reduceMotion, .easeInOut(duration: 0.3)) {
                        currentStep = next
                    }
                    if next == .categories {
                        triggerCategoryAnimation()
                    }
                }
            }
        }
    }

    // MARK: - Completion

    private func completeOnboarding() {
        let sync = PreferenceSyncService.shared

        let finalName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        sync.set(string: finalName.isEmpty ? L10n.Profile.defaultName : finalName, forKey: "userName")

        sync.set(string: selectedCurrency.rawValue, forKey: "defaultCurrencyCode")

        sync.set(string: DetailPeriod.thisMonth.rawValue, forKey: "defaultPeriod")
        sessionState.selectedPeriod = .thisMonth

        sync.set(bool: expensesOnlyMode, forKey: "expensesOnlyMode")
        sessionState.isExpensesOnlyMode = expensesOnlyMode

        // Use selectedMindset directly (set by style step or defaulted from goal)
        sync.set(string: selectedMindset, forKey: "financialMindset")
        sessionState.financialMindset = selectedMindset

        if loadSeedCategories {
            seedCategoriesIfNeeded(in: modelContext)
        }

        // A0-Bridge: idempotente, seguro de invocar siempre (chequea por isSystem flag).
        seedSystemGroupCategoriesIfNeeded(in: modelContext)

        if !loadSeedCategories && !expensesOnlyMode {
            InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: modelContext)
        }

        createOnboardingAccount()

        if wantsBudget && loadSeedCategories {
            createOnboardingBudget()
        }

        createDefaultNotifications()

        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("OnboardingView: Error saving onboarding data: \(error)")
            #endif
        }

        TelemetryService.track(.onboardingCompleted, parameters: [
            "expensesOnly": String(expensesOnlyMode),
            "usedSeedCategories": String(loadSeedCategories),
        ])

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        PreferenceSyncService.shared.signalOnboardingCompleted()

        Task {
            await ExchangeRateService.shared.forceUpdateToday(context: modelContext)
            SessionState.shared.needsExchangeRateWidgetRefresh = true
        }

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

        if !expensesOnlyMode {
            let amount = AmountInputHelper.parseDecimal(initialBalanceText)
            if amount != 0 {
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

        let budgetAmount = AmountInputHelper.parseDecimal(budgetAmountText)
        guard budgetAmount > 0 else { return }

        let cats = budgetCategories
        guard catIndex < cats.count else { return }
        let catInfo = cats[catIndex]

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

    /// Budget-eligible categories (preserved for compatibility)
    private var budgetCategories: [SeedCategoryPreview.CategoryInfo] {
        SeedCategoryPreview.categories.filter { $0.name != L10n.Category.incomeCategory }
    }

    private func createDefaultNotifications() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "notificationsSeeded") { return }
        defaults.set(true, forKey: "notificationsSeeded")

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
enum SeedCategoryPreview {
    struct CategoryInfo {
        let name: String
        let colorHex: String
        let iconName: String
        let subcategoryPreview: String
    }

    static let categories: [CategoryInfo] = [
        CategoryInfo(
            name: L10n.Category.food, colorHex: "#22C55E", iconName: "cart.fill",
            subcategoryPreview: "\(L10n.Subcategory.supermarkets), \(L10n.Subcategory.delivery), \(L10n.Subcategory.restaurants)"
        ),
        CategoryInfo(
            name: L10n.Category.shopping, colorHex: "#F59E0B", iconName: "bag.fill",
            subcategoryPreview: "\(L10n.Subcategory.clothing), \(L10n.Subcategory.personalCare), \(L10n.Subcategory.pharmacy)"
        ),
        CategoryInfo(
            name: L10n.Category.transport, colorHex: "#0EA5E9", iconName: "car.fill",
            subcategoryPreview: "\(L10n.Subcategory.publicTransport), \(L10n.Subcategory.rideshare)"
        ),
        CategoryInfo(
            name: L10n.Category.finance, colorHex: AppConstants.defaultColorHex, iconName: "banknote.fill",
            subcategoryPreview: "\(L10n.Subcategory.taxes), \(L10n.Subcategory.insurance), \(L10n.Subcategory.loans)"
        ),
        CategoryInfo(
            name: L10n.Category.housing, colorHex: "#475569", iconName: "house.fill",
            subcategoryPreview: "\(L10n.Subcategory.rent), \(L10n.Subcategory.utilities), \(L10n.Subcategory.maintenance)"
        ),
        CategoryInfo(
            name: L10n.Category.entertainment, colorHex: "#FF0080", iconName: "sparkles",
            subcategoryPreview: "\(L10n.Subcategory.streaming), \(L10n.Subcategory.bars), \(L10n.Subcategory.sports)"
        ),
        CategoryInfo(
            name: L10n.Category.personal, colorHex: "#A855F7", iconName: "person.fill",
            subcategoryPreview: "\(L10n.Subcategory.health), \(L10n.Subcategory.education), \(L10n.Subcategory.beauty)"
        ),
        CategoryInfo(
            name: L10n.Category.pets, colorHex: "#84CC16", iconName: "pawprint.fill",
            subcategoryPreview: "\(L10n.Subcategory.petFood), \(L10n.Subcategory.vet), \(L10n.Subcategory.petServices)"
        ),
        CategoryInfo(
            name: L10n.Category.vehicle, colorHex: "#64748B", iconName: "car.side.fill",
            subcategoryPreview: "\(L10n.Subcategory.fuel), \(L10n.Subcategory.vehicleMaintenance), \(L10n.Subcategory.parking)"
        ),
        CategoryInfo(
            name: L10n.Category.incomeCategory, colorHex: "#14B8A6", iconName: "arrow.down.circle.fill",
            subcategoryPreview: "\(L10n.Subcategory.salary), \(L10n.Subcategory.freelance), \(L10n.Subcategory.dividends)"
        ),
        CategoryInfo(
            name: L10n.Category.other, colorHex: "#64748B", iconName: "ellipsis.circle.fill",
            subcategoryPreview: ""
        ),
    ]
}

#Preview {
    OnboardingView {}
}
