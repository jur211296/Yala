//
//  WelcomeConversationView.swift
//  Yala
//
//  Bienvenida 2.3 · Y23-04 · la conversación de tres preguntas que sustituye al onboarding de ocho pasos en el alta.
//  Yala pregunta una cosa a la vez; la tarjeta «Tu Yala» se llena arriba con cada respuesta. Al terminar guarda lo
//  mismo que el alta de siempre —nombre, moneda, modo, categorías por defecto, avisos— y llama a `onComplete`, que es
//  la llegada (Y23-05). Con «Solo gastos» crea además la cuenta de gastos, como hoy.
//
//  Reglas de la ficha: Reducir movimiento deja solo fundidos; VoiceOver no avanza solo (cada pregunta espera a una
//  respuesta, y el «escribiendo…» no se usa con VoiceOver); texto grande no corta (todo en un scroll).
//

import SwiftData
import SwiftUI

struct WelcomeConversationView: View {
    typealias Step = WelcomeConversationLogic.Step
    typealias Tracking = WelcomeConversationLogic.Tracking

    /// El nombre que trae Google o Apple, si lo trae. Con iCloud llega `nil` y el nombre se escribe.
    let providerName: String?
    /// Dónde vivirán los datos: el pie de la tarjeta («En tu iCloud» / «En tu cuenta de Yala»).
    let livesInYalaAccount: Bool
    /// Lo que trajo un resumen de iCloud, si lo hay: nombre y moneda propuestos.
    var prefilledData: ICloudAccountSummary? = nil
    /// «Atrás» en la primera pregunta: vuelve a la bienvenida sin guardar nada.
    var onCancel: (() -> Void)? = nil
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var step: Step = .name
    /// «Yala está escribiendo…» entre pregunta y pregunta (no con VoiceOver ni con Reducir movimiento).
    @State private var typing = false
    @State private var name: String?
    @State private var currency: CurrencyCode?
    @State private var tracking: Tracking?
    /// «Prefiero otro nombre»: cambia la propuesta por el campo.
    @State private var wantsTypedName = false
    @State private var typedName = ""
    @State private var explained = false
    @State private var showCurrencyPicker = false
    @State private var pickedCurrency: CurrencyCode = CurrencyDefaults.detectCurrencyFromRegion()
    @State private var hasCompleted = false
    @FocusState private var nameFieldFocused: Bool
    @AccessibilityFocusState private var questionFocused: Bool

    private let regionCurrency = CurrencyDefaults.detectCurrencyFromRegion()

    private var proposedName: String? {
        WelcomeConversationLogic.proposedName(providerName: providerName, restoredName: prefilledData?.userName)
    }

    /// La moneda propuesta (review adversarial): la del iCloud restaurado si la trae, o la de la región. Antes solo se
    /// ofrecía la región y quien restauraba en euros tenía que buscar la suya, y el selector no contaba volver a tocar
    /// la marcada.
    private var proposedCurrency: (currency: CurrencyCode, fromRegion: Bool) {
        WelcomeConversationLogic.proposedCurrency(restoredCode: prefilledData?.primaryCurrencyCode, region: regionCurrency)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        card
                        questionZone
                            .id("question")
                        // Con texto de accesibilidad las respuestas van dentro del scroll (review adversarial): fijas
                        // abajo, con tres botones con detalle, no cabían en un iPhone pequeño o girado.
                        if dynamicTypeSize.isAccessibilitySize {
                            dock
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: step) { _, _ in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo("question", anchor: .top) }
                }
            }
        }
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
            if !dynamicTypeSize.isAccessibilitySize {
                dock
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.sm)
            }
        }
        .background { WelcomeF2Background().ignoresSafeArea() }
        .preferredColorScheme(.dark)
        .onAppear(perform: prefill)
        // «Otra moneda»: el selector de siempre. Cuenta como respuesta solo si la persona eligió una.
        .sheet(isPresented: $showCurrencyPicker, onDismiss: {
            guard step == .currency, currencyPickedInSheet else { return }
            answerCurrency(pickedCurrency)
        }) {
            NavigationStack {
                CurrencySelectorView(selectedCurrency: $pickedCurrency)
            }
            .onChange(of: pickedCurrency) { _, _ in currencyPickedInSheet = true }
        }
    }

    /// El selector deja la moneda en `pickedCurrency`; solo cuenta como respuesta si la persona la tocó.
    @State private var currencyPickedInSheet = false

    // MARK: - Cabecera

    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            if step == .name, let onCancel {
                Button(action: onCancel) {
                    Image(systemName: "chevron.left")
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Action.back)
                .accessibilityIdentifier("welcome_chat_back")
            }
            Image(systemName: "sparkles")
                .font(DS.Typography.bodyBold)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.electricIndigo, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Yala").font(DS.Typography.bodyBold).foregroundStyle(.white)
                Text(L10n.Conversation.subtitle).font(DS.Typography.caption).foregroundStyle(.white.opacity(0.65))
            }
            .accessibilityElement(children: .combine)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Tarjeta «Tu Yala»

    private var card: some View {
        let filled = WelcomeConversationLogic.filledRows(name: name, currency: currency, tracking: tracking)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(L10n.Conversation.cardTitle).font(DS.Typography.headline).foregroundStyle(.white)
                Spacer()
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(0..<3, id: \.self) { dot in
                        Circle()
                            .fill(dot < filled ? Color.neonCyan : Color.white.opacity(0.2))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityHidden(true)
            }
            cardRow("person.fill", L10n.Conversation.rowName, name, isNow: step == .name, id: "welcome_chat_row_name")
            cardRow("dollarsign.circle.fill", L10n.Conversation.rowCurrency, currency.map(currencyLabel),
                    isNow: step == .currency, id: "welcome_chat_row_currency")
            cardRow("list.bullet", L10n.Conversation.rowTracking, tracking.map(trackingLabel),
                    isNow: step == .tracking, id: "welcome_chat_row_tracking")
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: livesInYalaAccount ? "person.crop.circle" : "icloud.fill").accessibilityHidden(true)
                Text(livesInYalaAccount ? L10n.Welcome.New.cloudTitle : L10n.Welcome.New.privateTitle)
            }
            .font(DS.Typography.caption)
            .foregroundStyle(.white.opacity(0.6))
            .padding(.top, DS.Spacing.xs)
        }
        .padding(DS.Spacing.md)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .strokeBorder(filled == 3 ? Color.neonCyan.opacity(0.6) : .white.opacity(0.1), lineWidth: 1)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: filled)
        .accessibilityElement(children: .contain)
    }

    private func cardRow(_ icon: String, _ label: String, _ value: String?, isNow: Bool, id: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(value != nil ? Color.neonCyan : .white.opacity(0.5))
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(label).font(DS.Typography.caption).foregroundStyle(.white.opacity(0.6))
                if let value {
                    Text(value).font(DS.Typography.bodyBold).foregroundStyle(.white)
                        .transition(.opacity)
                } else {
                    Capsule().fill(.white.opacity(isNow ? 0.35 : 0.15)).frame(width: 64, height: 6)
                        .padding(.vertical, DS.Spacing.xs)
                        .accessibilityHidden(true)
                }
            }
            Spacer()
            if value != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.neonCyan)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { "\(label): \($0)" } ?? "\(label): \(L10n.Conversation.pending)")
        .accessibilityIdentifier(id)
    }

    // MARK: - Pregunta

    @ViewBuilder
    private var questionZone: some View {
        if typing {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(.white.opacity(0.6)).frame(width: 7, height: 7) }
            }
            .padding(DS.Spacing.md)
            .background(.white.opacity(0.1), in: Capsule())
            .accessibilityLabel(L10n.Conversation.typing)
            .transition(.opacity)
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(Array(lead.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(DS.Typography.body)
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(question)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($questionFocused)
                    .accessibilityIdentifier("welcome_chat_question")
                if step == .tracking, explained {
                    explanation
                }
            }
            .id(step)
            .transition(.opacity)
        }
    }

    /// Lo que va antes de la pregunta (saludo), por paso.
    private var lead: [String] {
        switch step {
        // «Prefiero otro nombre» deja solo la pregunta, como el prototipo.
        case .name: wantsTypedName ? [] : [L10n.Conversation.hello]
        case .currency: [L10n.Conversation.niceToMeet(name ?? "")]
        case .tracking: []
        case .done: [name.map { L10n.Conversation.readyNamed($0) } ?? L10n.Conversation.ready]
        }
    }

    private var question: String {
        switch step {
        case .name:
            if let proposedName, !wantsTypedName { return L10n.Conversation.askProposedName(proposedName) }
            return L10n.Conversation.askName
        case .currency: return L10n.Conversation.askCurrency
        case .tracking: return L10n.Conversation.askTracking
        case .done: return L10n.Conversation.yourYalaIsReady
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Conversation.incomeAndExpenses).font(DS.Typography.bodyBold)
                Text(L10n.Conversation.incomeAndExpensesExplained).font(DS.Typography.subheadline).opacity(0.75)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Conversation.expensesOnly).font(DS.Typography.bodyBold)
                Text(L10n.Conversation.expensesOnlyExplained).font(DS.Typography.subheadline).opacity(0.75)
            }
        }
        .foregroundStyle(.white)
        .fixedSize(horizontal: false, vertical: true)
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("welcome_chat_explanation")
        .transition(.opacity)
    }

    // MARK: - Respuestas

    @ViewBuilder
    private var dock: some View {
        if typing {
            Color.clear.frame(height: 56)
        } else {
            VStack(spacing: DS.Spacing.sm) {
                switch step {
                case .name:
                    if let proposedName, !wantsTypedName {
                        option(L10n.Conversation.yesCallMe(proposedName), highlighted: true, id: "welcome_chat_name_yes") {
                            answerName(proposedName)
                        }
                        option(L10n.Conversation.otherName, id: "welcome_chat_name_other") {
                            wantsTypedName = true
                            nameFieldFocused = true
                        }
                    } else {
                        nameField
                    }
                case .currency:
                    ForEach(WelcomeConversationLogic.currencyOptions(region: proposedCurrency.currency), id: \.self) { option in
                        self.option(currencyLabel(option),
                                    detail: option == proposedCurrency.currency && proposedCurrency.fromRegion
                                        ? L10n.Conversation.byRegion : nil,
                                    highlighted: option == proposedCurrency.currency,
                                    id: "welcome_chat_currency_\(option.rawValue.lowercased())") {
                            answerCurrency(option)
                        }
                    }
                    option(L10n.Conversation.otherCurrency, id: "welcome_chat_currency_other") {
                        currencyPickedInSheet = false
                        showCurrencyPicker = true
                    }
                case .tracking:
                    option(L10n.Conversation.incomeAndExpenses, id: "welcome_chat_tracking_both") { answerTracking(.incomeAndExpenses) }
                    option(L10n.Conversation.expensesOnly, id: "welcome_chat_tracking_expenses") { answerTracking(.expensesOnly) }
                    if !explained {
                        Button {
                            DS.Haptic.selection()
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { explained = true }
                        } label: {
                            Text(L10n.Conversation.whatsTheDifference)
                                .font(DS.Typography.subheadlineEmphasized)
                                .foregroundStyle(Color.neonCyan)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("welcome_chat_difference")
                    }
                case .done:
                    YalaPrimaryButton(L10n.Conversation.enterYala) { complete() }
                        .accessibilityIdentifier("welcome_chat_enter")
                }
            }
        }
    }

    private var nameField: some View {
        HStack(spacing: DS.Spacing.sm) {
            TextField("", text: $typedName, prompt: Text(L10n.Conversation.namePlaceholder).foregroundStyle(.white.opacity(0.45)))
                .font(DS.Typography.body)
                .foregroundStyle(.white)
                .textContentType(.givenName)
                .submitLabel(.send)
                .focused($nameFieldFocused)
                .onSubmit(sendTypedName)
                .padding(.horizontal, DS.Spacing.md)
                .frame(minHeight: 50)
                .background(.white.opacity(0.1), in: Capsule())
                .accessibilityIdentifier("welcome_chat_name_field")
            Button(action: sendTypedName) {
                Image(systemName: "arrow.up")
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(WelcomeConversationLogic.acceptedName(typedName) == nil ? .white.opacity(0.4) : .black)
                    .frame(width: 50, height: 50)
                    .background(WelcomeConversationLogic.acceptedName(typedName) == nil ? .white.opacity(0.15) : .white,
                                in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(WelcomeConversationLogic.acceptedName(typedName) == nil)
            .accessibilityLabel(L10n.Conversation.send)
            .accessibilityIdentifier("welcome_chat_name_send")
        }
    }

    private func option(_ title: String, detail: String? = nil, highlighted: Bool = false, id: String,
                        action: @escaping () -> Void) -> some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title).font(DS.Typography.bodyBold)
                    if let detail {
                        Text(detail).font(DS.Typography.caption).opacity(0.7)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right").font(DS.Typography.caption).opacity(0.6).accessibilityHidden(true)
            }
            .foregroundStyle(highlighted ? Color.black : .white)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(highlighted ? Color.white : Color.white.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    // MARK: - Avance

    private func sendTypedName() {
        guard let accepted = WelcomeConversationLogic.acceptedName(typedName) else { return }
        nameFieldFocused = false
        answerName(accepted)
    }

    private func answerName(_ value: String) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { name = value }
        advance()
    }

    private func answerCurrency(_ value: CurrencyCode) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { currency = value }
        advance()
    }

    private func answerTracking(_ value: Tracking) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { tracking = value }
        advance()
    }

    /// La siguiente pregunta. Con VoiceOver o Reducir movimiento sale sin el «escribiendo…»; con VoiceOver, el foco va
    /// a la pregunta nueva (no avanza solo: espera a la respuesta).
    private func advance() {
        let next = WelcomeConversationLogic.step(after: step)
        recordStepReached(next)
        if voiceOver || reduceMotion {
            step = next
            if next == .done { DS.Haptic.success() }
            Task { @MainActor in questionFocused = true }
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) { typing = true }
        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(650))
            } catch {
                #if DEBUG
                print("WelcomeConversationView: Error: \(error)")
                #endif
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                typing = false
                step = next
            }
            if next == .done { DS.Haptic.success() }
        }
    }

    /// Embudo del alta: el paso al que se llegó, con los nombres del onboarding de siempre.
    private func recordStepReached(_ reached: Step) {
        guard let feature = MetricsUseFeature.onboardingStep(trackingName: reached.trackingName) else { return }
        MetricsService.used(feature)
    }

    private func prefill() {
        recordStepReached(.name)
        if let raw = prefilledData?.primaryCurrencyCode, let code = CurrencyCode(rawValue: raw) {
            pickedCurrency = code
        }
    }

    // MARK: - Etiquetas

    private func currencyLabel(_ code: CurrencyCode) -> String {
        code == .usd ? L10n.Conversation.dollars : code.shortPluralName.capitalized
    }

    private func trackingLabel(_ value: Tracking) -> String {
        switch value {
        case .incomeAndExpenses: L10n.Conversation.incomeAndExpenses
        case .expensesOnly: L10n.Conversation.expensesOnly
        }
    }

    // MARK: - Guardar

    /// Lo mismo que el alta de siempre (`OnboardingView.completeOnboarding`), sin la cuenta ni el saldo: la primera
    /// cuenta es el paso 1 de «Primeros pasos». Con «Solo gastos», la cuenta de gastos que Yala crea sola.
    private func complete() {
        guard !hasCompleted, let tracking else { return }
        hasCompleted = true
        let chosenCurrency = currency ?? proposedCurrency.currency
        WelcomeConversationCommit.commit(
            name: name, currency: chosenCurrency, tracking: tracking,
            context: modelContext, sessionState: sessionState)
        onComplete()
    }
}

/// La escritura del alta de la conversación, aparte de la vista para poder probarla con un contexto en memoria.
enum WelcomeConversationCommit {
    @MainActor
    static func commit(name: String?, currency: CurrencyCode, tracking: WelcomeConversationLogic.Tracking,
                       context: ModelContext, sessionState: SessionState) {
        let sync = PreferenceSyncService.shared
        let finalName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        sync.set(string: finalName.isEmpty ? L10n.Profile.defaultName : finalName, forKey: "userName")
        sync.set(string: currency.rawValue, forKey: "defaultCurrencyCode")
        sync.set(string: DetailPeriod.thisMonth.rawValue, forKey: "defaultPeriod")
        sessionState.selectedPeriod = .thisMonth
        let expensesOnly = tracking == .expensesOnly
        sync.set(bool: expensesOnly, forKey: "expensesOnlyMode")
        sessionState.isExpensesOnlyMode = expensesOnly
        sync.set(string: tracking.mindset, forKey: "financialMindset")
        sessionState.financialMindset = tracking.mindset

        writeStore(currency: currency, tracking: tracking, context: context)

        do {
            try context.save()
            DS.Haptic.success()
        } catch {
            #if DEBUG
            print("WelcomeConversationCommit: Error saving onboarding data: \(error)")
            #endif
        }

        MetricsService.localRegistrationCompleted(mode: OnboardingFlowMode.initial.rawValue)
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        PreferenceSyncService.shared.signalOnboardingCompleted()

        Task {
            await ExchangeRateService.shared.forceUpdateToday(context: context)
            SessionState.shared.needsExchangeRateWidgetRefresh = true
        }
    }

    /// Lo que el alta deja en el almacén: categorías por defecto siempre, la cuenta de gastos con «Solo gastos» y los
    /// tipos de aviso. Aparte de las preferencias para probarlo con un contexto en memoria.
    @MainActor
    static func writeStore(currency: CurrencyCode, tracking: WelcomeConversationLogic.Tracking, context: ModelContext) {
        // Las categorías van siempre por defecto: «Prefiero crearlas yo» salió del alta.
        _ = seedDefaultCategoriesOnUserRequest(in: context)

        if tracking.createsExpensesAccount {
            let accountName = OnboardingAccountNameLogic.suggestedName(
                mode: .expensesOnly,
                accountTypeName: AccountType.general.localizedName,
                currencyName: currency.shortPluralName.capitalized,
                allTogetherFormat: L10n.Onboarding.accountNameAllTogetherFormat,
                expensesWord: L10n.CashFlow.expense)
            context.insert(Account(
                name: accountName,
                currencyCode: currency.rawValue,
                colorHex: AppConstants.defaultColorHex,
                iconName: iconName(for: .general),
                type: AccountType.general.rawValue))
        }

        OnboardingDefaultNotifications.seedIfNeeded(in: context)
    }
}
