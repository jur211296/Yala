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

    private enum UsageMode: String {
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
    @State private var balanceMode: BalanceMode = .manual
    @State private var calcFieldState = BalanceCalculatorFieldState()

    private enum BalanceMode {
        case manual, guided
    }
    @FocusState private var accountNameFocused: Bool
    @State private var lastAutoName: String = ""
    /// Snapshot del currency cuando se abre el picker — permite detectar cambio
    /// y disparar `onboardingCurrencyPicked` solo si user efectivamente eligió.
    @State private var currencyAtPickerOpen: CurrencyCode? = nil

    // Budget state (preserved for completeOnboarding — budget step removed from flow)
    @State private var wantsBudget: Bool = false
    @State private var selectedBudgetCategoryIndex: Int? = nil
    @State private var budgetAmountText: String = ""

    /// Optional prefilled data from iCloud restore (A4 Welcome Restore rama B).
    /// Cuando != nil, popula campos en `.task` y amplía `skippedSteps` automáticamente.
    let prefilledData: ICloudAccountSummary?
    /// Background visual del flow. `.heroFlow` (default) = continuidad post-Welcome
    /// con gradient indigo→negro y texto blanco rígido. `.themedPanel` =
    /// FullModeActivation, adapta al tema del user.
    let backgroundStyle: OnboardingBackgroundStyle
    /// Modo del flow para telemetría. NO afecta layout.
    let mode: OnboardingFlowMode
    var onComplete: () -> Void
    /// X cancel total en cualquier step. Usado por FullModeActivationView para
    /// permitir abortar la activación del modo completo desde cualquier punto.
    var onCancel: (() -> Void)? = nil
    /// Chevron back en step 1. Solo se setea cuando el OnboardingView viene
    /// del flow Welcome — descarta state silenciosamente y vuelve al Hero.
    var onCancelFromStep1: (() -> Void)? = nil

    init(prefilledData: ICloudAccountSummary? = nil,
         backgroundStyle: OnboardingBackgroundStyle = .heroFlow,
         mode: OnboardingFlowMode = .initial,
         onCancel: (() -> Void)? = nil,
         onCancelFromStep1: (() -> Void)? = nil,
         onComplete: @escaping () -> Void) {
        self.prefilledData = prefilledData
        self.backgroundStyle = backgroundStyle
        self.mode = mode
        self.onCancel = onCancel
        self.onCancelFromStep1 = onCancelFromStep1
        self.onComplete = onComplete
    }

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

        /// String estable para telemetría — desacoplado del rawValue Int.
        var trackingName: String {
            switch self {
            case .name:         return "name"
            case .purpose:      return "purpose"
            case .accounts:     return "accounts"
            case .accountType:  return "accountType"
            case .currencyName: return "currencyName"
            case .balance:      return "balance"
            case .categories:   return "categories"
            case .confirmation: return "confirmation"
            }
        }
    }

    /// Account types for fullControl picker (no .general — separate accounts have real types)
    private let fullControlAccountTypes: [AccountType] = [.checking, .savings, .creditCard, .cash]

    /// Color de tint del icono por tipo de cuenta. Diferenciado para que el user
    /// asocie visualmente cada tipo con un color distinto, restringido a la
    /// paleta R3 (sin indigo/cyan) para coherencia con el flow heroFlow.
    private func iconTint(for type: AccountType) -> Color {
        switch type {
        case .checking:   return .hotPink
        case .savings:    return .priorityNeed
        case .creditCard: return .priorityNeedNew
        case .cash:       return .essentialNeed
        default:          return .hotPink
        }
    }

    // MARK: - Step Navigation

    /// Steps a saltar derivados del flow interno (binary decisions del user).
    private var usageModeSkippedSteps: Set<Step> {
        if expensesOnlyMode {
            return [.accounts, .accountType, .balance]
        } else if selectedUsageMode == .dayToDay {
            return [.accountType]
        }
        return []
    }

    /// Steps a saltar derivados de prefilled iCloud data (A4 rama B).
    /// Si el user ya tiene cuentas en iCloud, no preguntamos por crear una; etc.
    private var prefilledSkippedSteps: Set<Step> {
        guard let summary = prefilledData else { return [] }
        var skip: Set<Step> = []
        if summary.userName != nil { skip.insert(.name) }
        if summary.accountsCount > 0 {
            skip.insert(.accounts)
            skip.insert(.accountType)
            skip.insert(.balance)
        }
        if summary.primaryCurrencyCode != nil { skip.insert(.currencyName) }
        if summary.categoriesCount > 0 { skip.insert(.categories) }
        // .purpose y .confirmation siempre visibles (tracking + resumen final).
        return skip
    }

    private var skippedSteps: Set<Step> {
        usageModeSkippedSteps.union(prefilledSkippedSteps)
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

    // MARK: - Style helpers (background-aware)

    /// `.heroFlow` usa paleta blanca rígida sobre indigo→negro; `.themedPanel`
    /// hereda los tokens del tema del user. Tipos concretos `Color` (no
    /// `AnyShapeStyle`) reducen typecheck pressure en body invocations.
    private var primaryTextStyle: Color {
        backgroundStyle == .heroFlow ? .white : theme.primaryText
    }

    private var secondaryTextStyle: Color {
        backgroundStyle == .heroFlow ? .white.opacity(0.7) : theme.secondaryText
    }

    private var mutedTextStyle: Color {
        backgroundStyle == .heroFlow ? .white.opacity(0.4) : .secondary.opacity(0.6)
    }

    private var cardStroke: Color {
        switch backgroundStyle {
        case .heroFlow:    return Color.white.opacity(0.1)
        case .themedPanel: return theme.cardBorder
        }
    }

    /// Color de acento para selección de cards (stroke 2pt). Hero icons y
    /// titles usan `primaryTextStyle` directamente — accent solo señala
    /// estado seleccionado, no jerarquía visual.
    private var styleAccentColor: Color {
        switch backgroundStyle {
        case .heroFlow:    return Color.electricIndigo
        case .themedPanel: return theme.accent
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            OnboardingFlowScreen(style: backgroundStyle) { logoTopSpacing in
                VStack(spacing: DS.Spacing.none) {
                    Group {
                        switch currentStep {
                        case .name: nameStep(logoTopSpacing: logoTopSpacing)
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
            }
            .safeAreaInset(edge: .bottom) {
                floatingNavigationButtons
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingToolbarButton
                }
                ToolbarItem(placement: .principal) {
                    progressIndicator
                }
            }
            .onTapGesture {
                dismissKeyboard()
            }
        }
        .task {
            // Telemetría de mount: started (funnel inicio) + stepViewed Step 1
            // (drop-off por step). Por separado son correctos: started=mount,
            // stepViewed=visit a step.
            TelemetryService.track(
                .onboardingStarted,
                parameters: OnboardingTelemetryEventBuilder.paramsForStarted(
                    mode: mode,
                    prefilled: prefilledData != nil
                )
            )
            TelemetryService.track(
                .onboardingStepViewed,
                parameters: OnboardingTelemetryEventBuilder.paramsForStepViewed(
                    step: currentStep.trackingName,
                    stepIndex: effectiveSteps.firstIndex(of: currentStep) ?? 0,
                    totalSteps: effectiveTotalSteps,
                    mode: mode
                )
            )

            let defaults = UserDefaults.standard
            if let name = OnboardingPrefillResolver.resolveUserName(
                prefilled: prefilledData,
                defaultsName: defaults.string(forKey: "userName")
            ) {
                userName = name
            }
            if let raw = OnboardingPrefillResolver.resolveCurrencyCode(
                prefilled: prefilledData,
                defaultsCode: defaults.string(forKey: "defaultCurrencyCode")
            ), let currency = CurrencyCode(rawValue: raw) {
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
                    .fill(progressCapsuleColor(active: step <= effectiveStepIndex))
                    .frame(width: step == effectiveStepIndex ? 24 : 8, height: 8)
                    .dsAnimation(.spring(response: 0.3), value: effectiveStepIndex, reduceMotion: reduceMotion)
            }
        }
    }

    /// Bifurca activo+inactivo según background. En heroFlow ambos son blancos
    /// (rígido + opacity bajo); en themedPanel hereda accent + secondaryText
    /// con la misma opacity para coherencia con el resto de tabs/progress.
    private func progressCapsuleColor(active: Bool) -> Color {
        switch (backgroundStyle, active) {
        case (.heroFlow, true):     return Color.white
        case (.heroFlow, false):    return Color.white.opacity(0.2)
        case (.themedPanel, true):  return theme.accent
        case (.themedPanel, false): return theme.secondaryText.opacity(0.2)
        }
    }

    /// Toolbar leading button. En `.heroFlow`: X cancel solo si Step 1 vino del
    /// Welcome (`onCancelFromStep1`), chevron back en Steps 2-8. En `.themedPanel`:
    /// X cancel total siempre (FullModeActivation requiere escape persistente).
    @ViewBuilder
    private var leadingToolbarButton: some View {
        switch (backgroundStyle, currentStep) {
        case (.heroFlow, .name):
            if let cancel = onCancelFromStep1 {
                YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                    trackCancelled()
                    cancel()
                }
            }
        case (.heroFlow, _):
            YalaToolbarButton(systemName: "chevron.backward", label: L10n.Action.back, action: goBack)
        case (.themedPanel, _):
            if let cancel = onCancel {
                YalaToolbarButton(systemName: "xmark", label: L10n.Action.cancel) {
                    trackCancelled()
                    cancel()
                }
            }
        }
    }

    private func trackCancelled() {
        TelemetryService.track(
            .onboardingCancelled,
            parameters: OnboardingTelemetryEventBuilder.paramsForCancelled(
                atStep: currentStep.trackingName,
                mode: mode
            )
        )
    }

    /// Navega un step atrás con la animación canónica del flow Welcome.
    /// Llamado por el chevron del toolbar (`.heroFlow`) y la back capsule
    /// del bottom (`.themedPanel`). Dispara telemetría ANTES del withAnimation.
    private func goBack() {
        guard let prev = previousStep(before: currentStep) else { return }

        TelemetryService.track(
            .onboardingBackTapped,
            parameters: OnboardingTelemetryEventBuilder.paramsForBackTapped(
                fromStep: currentStep.trackingName,
                mode: mode
            )
        )
        TelemetryService.track(
            .onboardingStepViewed,
            parameters: OnboardingTelemetryEventBuilder.paramsForStepViewed(
                step: prev.trackingName,
                stepIndex: effectiveSteps.firstIndex(of: prev) ?? 0,
                totalSteps: effectiveTotalSteps,
                mode: mode
            )
        )

        navigatingForward = false
        dsWithAnimation(reduceMotion, .easeInOut(duration: 0.3)) {
            currentStep = prev
        }
    }

    // MARK: - Step 1: Name

    /// `logoTopSpacing` proviene del wrapper `OnboardingFlowScreen` y anchora
    /// el logo a la misma altura visual que `WelcomeFlowContainer`. Logo 128pt
    /// solo en `.heroFlow` (FullMode skipea Step 1 vía prefilled y nunca pasa
    /// por aquí; el branch `.themedPanel` queda como fallback defensivo).
    private func nameStep(logoTopSpacing: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if backgroundStyle == .heroFlow {
                    Spacer(minLength: logoTopSpacing)
                    Image("YalaLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 128)
                        .colorMultiply(.white)
                        .accessibilityHidden(true)
                } else {
                    Spacer(minLength: DS.Spacing.xl)
                    Image(uiImage: UIImage(named: "IconOriginal@3x") ?? UIImage())
                        .resizable()
                        .scaledToFit()
                        .frame(width: appIconSize, height: appIconSize)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .accessibilityHidden(true)
                }

                VStack(spacing: DS.Spacing.sm) {
                    Text(L10n.Onboarding.welcomeTitle)
                        .font(DS.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(primaryTextStyle)
                        .multilineTextAlignment(.center)

                    Text(L10n.Onboarding.welcomeSubtitle)
                        .font(DS.Typography.body)
                        .foregroundStyle(secondaryTextStyle)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                }
                .padding(.top, DS.Spacing.md)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(L10n.Onboarding.nameLabel)
                        .font(DS.Typography.label)
                        .foregroundStyle(secondaryTextStyle)

                    TextField(L10n.Onboarding.namePlaceholder, text: $userName)
                        .textContentType(.nickname)
                        .font(DS.Typography.body)
                        .foregroundStyle(primaryTextStyle)
                        .padding(DS.Spacing.md)
                        .background(.thCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .accessibilityIdentifier("onboarding_name_field")
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(cardStroke, lineWidth: 1)
                        )

                    Text(L10n.Onboarding.nameHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(mutedTextStyle)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.md)

                Spacer(minLength: DS.Spacing.xl)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Step 2: Purpose (binary)

    private var purposeStep: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "target")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(primaryTextStyle)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityHidden(true)

                        Text(L10n.Onboarding.purposeTitle)
                            .font(DS.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(primaryTextStyle)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xl)

                    VStack(spacing: DS.Spacing.sm) {
                        binaryCard(
                            isSelected: !expensesOnlyMode,
                            icon: "dollarsign.circle",
                            iconColor: .priorityNeed,
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
                            iconColor: .essentialNeed,
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
                            .foregroundStyle(primaryTextStyle)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityHidden(true)

                        Text(L10n.Onboarding.accountsTitle)
                            .font(DS.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(primaryTextStyle)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xl)

                    VStack(spacing: DS.Spacing.sm) {
                        binaryCard(
                            isSelected: !wantsSeparateAccounts,
                            icon: "creditcard",
                            iconColor: .hotPink,
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
                            iconColor: .priorityNeedNew,
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

    /// Card de selección estilo capabilityCard del AI Onboarding: icono con halo
    /// gradient, sin checkmark/circle, selección visualizada con stroke 2pt
    /// `styleAccentColor`. Background siempre `.thCard` — bifurca correctamente
    /// entre `.heroFlow` (translúcido sobre dark) y `.themedPanel` (themed).
    private func binaryCard(
        isSelected: Bool,
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        accessibilityId: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold)) // A11Y-DT: card icon
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(primaryTextStyle)

                    Text(description)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(secondaryTextStyle)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(isSelected ? styleAccentColor : cardStroke, lineWidth: isSelected ? 2 : 1)
            )
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
                            .foregroundStyle(primaryTextStyle)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityHidden(true)

                        Text(L10n.Onboarding.accountTypeTitle)
                            .font(DS.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(primaryTextStyle)
                            .multilineTextAlignment(.center)

                        Text(L10n.Onboarding.accountTypeSubtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(secondaryTextStyle)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.xl)
                    }
                    .padding(.top, DS.Spacing.xl)

                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(fullControlAccountTypes) { type in
                            binaryCard(
                                isSelected: selectedAccountType == type,
                                icon: iconName(for: type),
                                iconColor: iconTint(for: type),
                                title: type.localizedName,
                                description: type.typeDescription,
                                accessibilityId: "onboarding_account_type_\(type.rawValue)"
                            ) {
                                if selectedAccountType != type {
                                    selectedAccountType = type
                                    calcFieldState.reset()
                                }
                            }
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
                        .foregroundStyle(primaryTextStyle)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .accessibilityHidden(true)

                    Text(wantsSeparateAccounts
                         ? L10n.Onboarding.currencyNameTitleSeparate
                         : L10n.Onboarding.currencyNameTitleSingle)
                        .font(DS.Typography.title)
                        .fontWeight(.bold)
                        .foregroundStyle(primaryTextStyle)
                        .multilineTextAlignment(.center)

                    Text(wantsSeparateAccounts
                         ? L10n.Onboarding.currencyNameSubtitleSeparate
                         : L10n.Onboarding.currencyNameSubtitleSingle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(secondaryTextStyle)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                }
                .padding(.top, DS.Spacing.md)

                // Account name
                OnboardingFieldSection(
                    title: L10n.Onboarding.accountNameLabel,
                    titleStyle: secondaryTextStyle
                ) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "pencil")
                            .foregroundStyle(secondaryTextStyle)
                        TextField(L10n.Onboarding.accountNamePlaceholder, text: $accountName)
                            .focused($accountNameFocused)
                            .accessibilityIdentifier("onboarding_account_name")
                            .foregroundStyle(primaryTextStyle)
                    }
                    .padding()
                }
                .padding(.horizontal, DS.Spacing.lg)

                // Currency
                OnboardingFieldSection(
                    title: L10n.Onboarding.accountCurrencyLabel,
                    titleStyle: secondaryTextStyle
                ) {
                    Button {
                        accountNameFocused = false
                        currencyAtPickerOpen = accountCurrency
                        showCurrencyPicker = true
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Text(accountCurrency.flag)
                                .font(DS.Typography.title)
                            Text(accountCurrency.localizedName)
                                .font(DS.Typography.body)
                                .foregroundStyle(primaryTextStyle)
                            Spacer()
                            Text(accountCurrency.rawValue)
                                .foregroundStyle(secondaryTextStyle)
                            Image(systemName: "chevron.right")
                                .font(DS.Typography.caption)
                                .foregroundStyle(mutedTextStyle)
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
        .sheet(isPresented: $showCurrencyPicker, onDismiss: {
            // Track solo si user efectivamente cambió la divisa en el sheet.
            if let initial = currencyAtPickerOpen, initial != accountCurrency {
                TelemetryService.track(
                    .onboardingCurrencyPicked,
                    parameters: ["currency": accountCurrency.rawValue]
                )
            }
            currencyAtPickerOpen = nil
        }) {
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
                            .foregroundStyle(primaryTextStyle)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityHidden(true)

                        Text(L10n.Onboarding.balanceTitle)
                            .font(DS.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(primaryTextStyle)
                            .multilineTextAlignment(.center)

                        Text(L10n.Onboarding.balanceSubtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(secondaryTextStyle)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.xl)
                    }
                    .padding(.top, DS.Spacing.md)

                    // Live preview del monto formateado — eyecatcher emocional.
                    // `.numericText()` trasiciona los dígitos; el currency symbol y
                    // el signo "-" son estáticos (jitter aceptable al cambiar signo).
                    balanceLivePreview
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.sm)

                    // Dos opciones (manual vs guided) + form/hint contextual
                    VStack(spacing: DS.Spacing.sm) {
                        binaryCard(
                            isSelected: balanceMode == .manual,
                            icon: "pencil",
                            iconColor: .priorityNeed,
                            title: L10n.Onboarding.balanceManualOption,
                            description: L10n.Onboarding.balanceManualHint,
                            accessibilityId: "onboarding_balance_manual"
                        ) {
                            balanceMode = .manual
                        }

                        if balanceMode == .manual {
                            manualBalanceForm
                        }

                        binaryCard(
                            isSelected: balanceMode == .guided,
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: .hotPink,
                            title: L10n.Onboarding.accountBalanceLearnMore,
                            description: L10n.Onboarding.balanceGuideHint,
                            accessibilityId: "onboarding_balance_guided"
                        ) {
                            balanceMode = .guided
                            showBalanceGuide = true
                        }

                        if balanceMode == .guided && initialBalanceText.isEmpty {
                            balanceIncompleteHint
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)

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

    /// Preview en vivo del monto formateado en la moneda elegida.
    /// Una sola `.animation()` con key compuesto `(text, sign)` evita stacking
    /// de modifiers que invalidaban dos veces por keystroke (ver review #balance).
    private var balanceLivePreview: some View {
        let trimmed = initialBalanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmpty = trimmed.isEmpty
        let amount = AmountInputHelper.parseDecimal(initialBalanceText)
        let signed = balanceIsPositive ? amount : -amount
        let formatted = isEmpty
            ? "\(accountCurrency.symbol) 0"
            : appPreferences.currency(signed, currencyCode: accountCurrency.rawValue)

        return Text(formatted)
            .font(DS.Typography.largeTitle)
            .fontWeight(.semibold)
            .foregroundStyle(isEmpty ? mutedTextStyle : primaryTextStyle)
            .contentTransition(.numericText())
            .animation(.smooth(duration: 0.3), value: formatted)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(formatted)
    }

    /// Form de input manual expandido bajo la card `.manual`. Sign segmented +
    /// TextField gigante con currency symbol. Se monta sólo si el user eligió
    /// el modo manual — el `.guided` lo colapsa.
    private var manualBalanceForm: some View {
        OnboardingFieldSection(
            title: L10n.Onboarding.accountBalanceLabel,
            titleStyle: secondaryTextStyle
        ) {
            VStack(spacing: DS.Spacing.none) {
                HStack(spacing: DS.Spacing.md) {
                    Text(L10n.Account.sign)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(secondaryTextStyle)
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
                            .foregroundStyle(secondaryTextStyle)
                        TextField("0", text: $initialBalanceText)
                            .font(DS.Typography.largeTitle)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(primaryTextStyle)
                            .accessibilityIdentifier("onboarding_balance")
                    }
                }
                .padding()
            }
        }
    }

    /// Hint amber bajo la card `.guided` cuando el user cerró el sheet sin
    /// completar el cálculo. Re-tappear la card reabre el calculator.
    private var balanceIncompleteHint: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DS.Typography.subheadline)
                .foregroundStyle(Color.essentialNeed)
                .accessibilityHidden(true)
            Text(L10n.Onboarding.balanceGuidedIncompleteHint)
                .font(DS.Typography.caption)
                .foregroundStyle(Color.essentialNeed)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.top, DS.Spacing.xxs)
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
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Header tipográfico estilo Apple Settings — sin Circle/sparkles.
                VStack(spacing: DS.Spacing.sm) {
                    Text(confirmationMotivation)
                        .font(DS.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(primaryTextStyle)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)

                    Text(L10n.Onboarding.confirmTitle)
                        .font(DS.Typography.body)
                        .foregroundStyle(secondaryTextStyle)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.xl)

                // Lista compacta con dividers internos (UNA card grande con
                // rows separadas por Rectangle bifurcado por background).
                confirmItemsCard
                    .padding(.horizontal, DS.Spacing.xl)

                // Privacy → grid 2x2 cards individuales con copys cortos.
                privacyGrid
                    .padding(.horizontal, DS.Spacing.xl)

                Spacer(minLength: DS.Spacing.lg)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Items resumen en lista compacta tipo Apple Settings: rows separadas
    /// por Rectangle 1pt bifurcado (heroFlow vs themedPanel) — Divider()
    /// default es invisible sobre indigo translúcido.
    private var confirmItemsCard: some View {
        VStack(spacing: 0) {
            confirmItem(
                icon: "person.fill",
                color: .hotPink,
                value: userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? L10n.Profile.defaultName : userName
            )
            rowDivider
            confirmItem(
                icon: iconName(for: selectedAccountType),
                color: .hotPink,
                value: (accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? selectedAccountType.localizedName : accountName)
                    + " · \(accountCurrency.rawValue)"
            )

            if !expensesOnlyMode {
                rowDivider
                let amount = AmountInputHelper.parseDecimal(initialBalanceText)
                let displayAmount = amount > 0 ? (balanceIsPositive ? amount : -amount) : 0.0
                let formattedBalance = appPreferences.currency(displayAmount,
                    currencyCode: accountCurrency.rawValue
                )
                confirmItem(
                    icon: "banknote",
                    color: .priorityNeed,
                    value: formattedBalance
                )
            }

            if expensesOnlyMode {
                rowDivider
                confirmItem(
                    icon: "list.bullet.clipboard",
                    color: .essentialNeed,
                    value: L10n.Onboarding.purposeExpenses
                )
            }

            rowDivider
            confirmItem(
                icon: "folder.fill",
                color: .priorityNeed,
                value: loadSeedCategories
                    ? L10n.Onboarding.categoriesDefault
                    : L10n.Onboarding.categoriesCustom
            )
        }
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
    }

    /// Divider 1pt bifurcado: en heroFlow `Color(.separator)` se pierde sobre
    /// indigo translúcido — usar white opacity 0.1. Padding leading alinea el
    /// divider con el inicio del Text del row (después del icon halo).
    private var rowDivider: some View {
        let iconColumnWidth = DS.Spacing.md + badgeSize + DS.Spacing.md
        return Rectangle()
            .fill(backgroundStyle == .heroFlow ? Color.white.opacity(0.1) : Color(.separator))
            .frame(height: 1)
            .padding(.leading, iconColumnWidth)
    }

    private var privacyGrid: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Onboarding.privacyTitle)
                .font(DS.Typography.bodyBold)
                .foregroundStyle(primaryTextStyle)
                .padding(.horizontal, DS.Spacing.xs)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                privacyCard(icon: "iphone", text: L10n.Onboarding.privacyLocalShort)
                privacyCard(icon: "eye.slash.fill", text: L10n.Onboarding.privacyNoTrackingShort)
                privacyCard(icon: "person.badge.key.fill", text: L10n.Onboarding.privacyIcloudShort)
                privacyCard(icon: "lock.shield.fill", text: L10n.Onboarding.privacyNoSharingShort)
            }
        }
    }

    /// Row individual de la lista compacta — sin background propio (la card
    /// `confirmItemsCard` lo envuelve con `.thCard` + cardStroke).
    private func confirmItem(icon: String, color: Color, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: badgeSize, height: badgeSize)

                Image(systemName: icon)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(color)
            }

            Text(value)
                .font(DS.Typography.headline)
                .foregroundStyle(primaryTextStyle)

            Spacer()
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                            .foregroundStyle(primaryTextStyle)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityHidden(true)

                        Text(L10n.Onboarding.categoriesTitle)
                            .font(DS.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(primaryTextStyle)
                            .multilineTextAlignment(.center)

                        Text(L10n.Onboarding.categoriesSubtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(secondaryTextStyle)
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
                            .foregroundStyle(secondaryTextStyle)
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
                            .foregroundStyle(styleAccentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DS.Spacing.xl)

                    // Selection buttons
                    VStack(spacing: DS.Spacing.sm) {
                        binaryCard(
                            isSelected: loadSeedCategories,
                            icon: "checkmark.circle",
                            iconColor: .priorityNeed,
                            title: L10n.Onboarding.categoriesYes,
                            description: L10n.Onboarding.categoriesRecommended,
                            accessibilityId: "onboarding_categories_yes"
                        ) {
                            loadSeedCategories = true
                        }

                        binaryCard(
                            isSelected: !loadSeedCategories,
                            icon: "xmark.circle",
                            iconColor: .secondary,
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

        let circleOpacity: Double = (backgroundStyle == .heroFlow ? 0.25 : 0.2)

        return LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            ForEach(Array(filteredSeedCategories.enumerated()), id: \.element.name) { index, category in
                VStack(spacing: DS.Spacing.xs) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: category.colorHex).opacity(circleOpacity))
                            .frame(width: categoryIconSize, height: categoryIconSize)

                        Image(systemName: category.iconName)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(Color(hex: category.colorHex))
                            .accessibilityHidden(true)
                    }

                    Text(category.name)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(secondaryTextStyle)
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

    /// Mini-card del grid 2x2 de privacidad — VStack icon + text breve, card
    /// individual `.thCard` + cardStroke. Iconos privacidad mantienen tints
    /// neutros (no aplica R3 — son contexto distinto a las cards de selección).
    private func privacyCard(icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold)) // A11Y-DT: privacy card
                .foregroundStyle(secondaryTextStyle)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(secondaryTextStyle)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(cardStroke, lineWidth: 1)
        )
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

    /// Footer del flow. En `.heroFlow`: solo CTA único (back vive en toolbar).
    /// En `.themedPanel`: back capsule + CTA + fade gradient (el PanelBackground
    /// puede ser claro y necesita la separación visual).
    private var floatingNavigationButtons: some View {
        VStack(spacing: DS.Spacing.none) {
            if backgroundStyle == .themedPanel {
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
            }

            navigationButtons
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)
                .padding(.top, DS.Spacing.sm)
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: DS.Spacing.md) {
            // Back capsule SOLO en .themedPanel — heroFlow tiene back en toolbar
            if backgroundStyle == .themedPanel && currentStep != .name {
                Button {
                    goBack()
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
                currentStep == .confirmation ? L10n.Onboarding.startUsingYala : L10n.Action.next,
                isDisabled: isNextDisabled
            ) {
                advance()
            }
        }
    }

    /// Avanza al siguiente step (o completa el onboarding si es el último).
    /// Dispara picks del step que dejamos (state final efectivo, evita ruido
    /// de picks parciales) + stepViewed del próximo step ANTES del withAnimation.
    private func advance() {
        dismissKeyboard()
        trackPickIfApplicable(forStep: currentStep)

        if currentStep == .confirmation {
            // Sync currency before completing
            selectedCurrency = accountCurrency
            completeOnboarding()
            return
        }

        guard let next = nextStep(after: currentStep) else { return }

        TelemetryService.track(
            .onboardingStepViewed,
            parameters: OnboardingTelemetryEventBuilder.paramsForStepViewed(
                step: next.trackingName,
                stepIndex: effectiveSteps.firstIndex(of: next) ?? 0,
                totalSteps: effectiveTotalSteps,
                mode: mode
            )
        )

        navigatingForward = true
        dsWithAnimation(reduceMotion, .easeInOut(duration: 0.3)) {
            currentStep = next
        }
        if next == .categories {
            triggerCategoryAnimation()
        }
    }

    /// Dispara el evento de pick del step que estamos dejando, leyendo el state
    /// final del view (no el handler — evita disparar 3 veces si user toca
    /// `control → expenses → control` antes de avanzar).
    private func trackPickIfApplicable(forStep step: Step) {
        switch step {
        case .purpose:
            TelemetryService.track(
                .onboardingPurposePicked,
                parameters: ["purpose": selectedUsageMode.rawValue]
            )
        case .accounts:
            TelemetryService.track(
                .onboardingAccountsPicked,
                parameters: ["accounts": wantsSeparateAccounts ? "multiple" : "single"]
            )
        case .accountType:
            TelemetryService.track(
                .onboardingAccountTypePicked,
                parameters: ["type": selectedAccountType.rawValue]
            )
        case .categories:
            TelemetryService.track(
                .onboardingCategoriesPicked,
                parameters: ["loadSeed": String(loadSeedCategories)]
            )
        default:
            break
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
            "mode": mode.rawValue,
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

// MARK: - Field Section (background-aware reemplazo de SectionBox)

/// Sustituto de `SectionBox(title:)` para el flow Onboarding. Label arriba con
/// estilo proporcionado por el owner (background-aware) + content envuelto en
/// `.solidCard()` modifier para fondo consistente con el resto de cards.
fileprivate struct OnboardingFieldSection<Content: View>: View {
    let title: String
    let titleStyle: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Typography.label)
                .foregroundStyle(titleStyle)
                .padding(.horizontal, DS.Spacing.xs)

            content()
                .solidCard(padding: 0, radius: DS.Radius.lg)
        }
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
