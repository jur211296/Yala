//
//  FirstAccountFlowView.swift
//  Yala
//
//  Y23-07 · Paso 1 de Primeros pasos: «Crea tu primera cuenta» (prototipo oficial v35, pestaña 3 · Primera cuenta).
//  Primero la página corta «qué son las cuentas» (E2, tres partes) con «Crear mi primera cuenta» siempre a la vista;
//  después, preguntas con la tarjeta de la cuenta llenándose arriba: tipo → moneda (con líneas ANTES de guardar) →
//  nombre → saldo por moneda → (tarjeta) cierre, pago y recordatorio → ¡Lista!. Las reglas, en `FirstAccountFlowLogic`;
//  el guardado, en `FirstAccountCreator`. Fuera de alcance (ficha): número de cuenta y «Excluir de las estadísticas»,
//  que siguen en Editar cuenta.
//

import SwiftData
import SwiftUI

struct FirstAccountFlowView: View {
    typealias Logic = FirstAccountFlowLogic
    private typealias T = L10n.PrimerosPasos23.Account

    /// Al cerrar: si se creó al menos una cuenta.
    let onClose: (_ createdAny: Bool) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var showsIntro = true
    @State private var introPart = 0
    @State private var step: Logic.Step = .kind
    @State private var history: [Logic.Step] = []
    @State private var draft = FirstAccountDraft(mainCurrency: CurrencyCode.usd.rawValue)
    @State private var didSeedDraft = false
    @State private var createdCount = 0
    @State private var lastCreatedName = ""
    @State private var lastCreatedCurrencies: [String] = []
    @State private var saveFailed = false

    // Lo que se escribe en cada pregunta.
    @State private var editsName = false
    @State private var nameText = ""
    @State private var amountText = ""
    @State private var isNegative = false
    @State private var dayText = ""
    @State private var showsHelper = false
    @State private var helperValues: [String] = ["", "", ""]

    // El selector de moneda: qué hueco cambia (o `nil` = añadir una).
    @State private var currencyPickTarget: CurrencyPickTarget?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, amount, day, helper(Int) }

    private struct CurrencyPickTarget: Identifiable {
        let id = UUID()
        /// El hueco que cambia; `nil` = una moneda nueva.
        let index: Int?
        /// La moneda marcada al abrir: la del hueco, o la principal al añadir (elegir cualquier otra la suma).
        let initial: CurrencyCode
    }

    var body: some View {
        ZStack {
            if showsIntro {
                FirstAccountIntroPage(
                    part: $introPart,
                    mainCurrency: CurrencyCode(rawValue: draft.currencies.first ?? "USD") ?? .usd,
                    onBack: { onClose(false) },
                    onStart: { startQuestions() }
                )
                .transition(.opacity)
            } else {
                questions
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: showsIntro)
        .yalaScreenBackground(.panel)
        .onAppear(perform: seedDraftIfNeeded)
        // El hueco viaja en el cierre de la hoja: en el `onDismiss` de `.sheet(item:)` el `item` ya vale `nil` y la
        // moneda elegida no se aplicaba (review del lote). Cerrar sin elegir no cambia nada.
        .sheet(item: $currencyPickTarget) { target in
            FirstAccountCurrencyPicker(initial: target.initial) { code in apply(code.rawValue, to: target.index) }
        }
        .alert(L10n.Common.error, isPresented: $saveFailed) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Common.saveError)
        }
    }

    // MARK: - Preguntas

    private var questions: some View {
        VStack(spacing: DS.Spacing.md) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if !(showsHelper && focusedField != nil) {
                        FirstAccountCardPreview(draft: draft, suggestedName: suggestedName)
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(questionTitle)
                            .font(DS.Typography.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("first_account_question")
                        if let subtitle = questionSubtitle {
                            Text(subtitle)
                                .font(DS.Typography.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .id(questionIdentity)
                    .transition(.opacity)
                    dock
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
                .animation(reduceMotion ? nil : DS.Animation.appear, value: questionIdentity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) { goBack() }
                .accessibilityIdentifier("first_account_back")
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Yala").font(DS.Typography.headline)
                Text(L10n.PrimerosPasos23.Account.chatSubtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            progressDots
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
    }

    private var progressDots: some View {
        let all = allSteps
        let index = all.firstIndex(of: step) ?? 0
        return HStack(spacing: DS.Spacing.xxs) {
            ForEach(Array(all.enumerated()), id: \.offset) { offset, _ in
                Circle()
                    .fill(offset < index || step == .done ? theme.accent : Color.primary.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.PrimerosPasos23.partOf(index + 1, all.count))
    }

    private var allSteps: [Logic.Step] {
        Logic.steps(kind: draft.kind, currencyCount: draft.currencies.count, paymentDay: draft.paymentDay)
    }

    /// Cambia con la pregunta y con el saldo de cada moneda: la pregunta nueva se funde.
    private var questionIdentity: String {
        "\(step)-\(editsName)-\(showsHelper)"
    }

    // MARK: Textos de la pregunta

    private var isCard: Bool { draft.kind?.isCard == true }

    private var suggestedName: String {
        switch draft.kind {
        case .cash: return L10n.Account.AccountType.cash
        case .general: return L10n.PrimerosPasos23.Account.myMoney
        case .some(let kind): return kind.accountType.localizedName
        case nil: return ""
        }
    }

    private func currencyWord(_ code: String) -> String {
        (CurrencyCode(rawValue: code) ?? .usd).shortPluralName
    }

    private var questionTitle: String {
        switch step {
        case .kind: return T.kindQuestion
        case .currencies: return isCard ? T.currencyQuestionCard : T.currencyQuestion
        case .name:
            if editsName { return T.nameEditQuestion }
            if draft.kind?.writesOwnName == true { return T.nameQuestion }
            return T.nameSuggestQuestion(suggestedName)
        case .balance(let index):
            if showsHelper { return helperTitle }
            let two = draft.currencies.count > 1
            let word = currencyWord(draft.currencies[safe: index] ?? "USD")
            if !two { return isCard ? T.balanceQuestionCardSingle : T.balanceQuestionSingle }
            if index == 0 { return isCard ? T.balanceQuestionCardIn(word) : T.balanceQuestionIn(word) }
            return T.balanceQuestionAnd(word)
        case .statementDay: return T.statementQuestion
        case .paymentDay: return T.paymentQuestion
        case .reminder: return T.reminderQuestion
        case .done: return T.doneTitle
        }
    }

    private var questionSubtitle: String? {
        switch step {
        case .kind: return T.kindSubtitle
        case .currencies: return isCard ? T.currencySubtitleCard : T.currencySubtitle
        case .name:
            return draft.kind?.writesOwnName == true && !editsName ? T.nameSubtitleOwn : T.nameSubtitle
        case .balance:
            if showsHelper { return helperIntro }
            return isCard ? T.balanceSubtitleCard : T.balanceSubtitle
        case .statementDay: return T.statementSubtitle
        case .paymentDay: return T.paymentSubtitle
        case .reminder:
            guard draft.statementDay?.day != nil else { return T.reminderSubtitleNoStatement }
            return draft.currencies.count > 1 ? T.reminderSubtitleEachCurrency : T.reminderSubtitle
        case .done:
            let name = lastCreatedName
            guard lastCreatedCurrencies.count > 1 else { return T.doneSubtitle(name) }
            return T.doneSubtitleWith(name, Self.joinedList(lastCreatedCurrencies.map(currencyWord)))
        }
    }

    // MARK: - Lo de abajo de cada pregunta

    @ViewBuilder
    private var dock: some View {
        switch step {
        case .kind: kindOptions
        case .currencies: currencyDock
        case .name: nameDock
        case .balance(let index): showsHelper ? AnyView(helperDock(index: index)) : AnyView(balanceDock(index: index))
        case .statementDay, .paymentDay: dayDock
        case .reminder: reminderDock
        case .done: doneDock
        }
    }

    private var kindOptions: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(Logic.Kind.allCases, id: \.self) { kind in
                optionButton(
                    title: kindTitle(kind), subtitle: kindHint(kind), icon: iconName(for: kind.accountType),
                    tint: Color(hex: kind.colorHex), id: "first_account_kind_\(kind.rawValue)"
                ) {
                    draft.kind = kind
                    advance()
                }
            }
        }
    }

    private func kindTitle(_ kind: Logic.Kind) -> String {
        switch kind {
        case .cash: return L10n.Account.AccountType.cash
        case .checking: return L10n.Account.AccountType.current
        case .savings: return T.kindSavings
        case .creditCard: return L10n.Account.AccountType.creditCard
        case .general: return T.kindAllTogether
        }
    }

    private func kindHint(_ kind: Logic.Kind) -> String {
        switch kind {
        case .cash: return L10n.Onboarding.accountTypeCashHint
        case .checking: return L10n.Onboarding.accountTypeCheckingHint
        case .savings: return L10n.Onboarding.accountTypeSavingsHint
        case .creditCard: return L10n.Onboarding.accountTypeCreditHint
        case .general: return L10n.PrimerosPasos23.Account.kindAllTogetherHint
        }
    }

    private var currencyDock: some View {
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(Array(draft.currencies.enumerated()), id: \.element) { index, code in
                    HStack(spacing: DS.Spacing.xs) {
                        Button {
                            currencyPickTarget = CurrencyPickTarget(
                                index: index, initial: CurrencyCode(rawValue: code) ?? .usd)
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Text(CurrencyCode(rawValue: code)?.symbol ?? code)
                                    .font(DS.Typography.headline)
                                    .frame(minWidth: 28)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(currencyWord(code).capitalized).font(DS.Typography.subheadline.weight(.semibold))
                                    Text(verbatim: code).font(DS.Typography.caption).foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.down").font(DS.Typography.caption).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(T.currencySlot(index + 1, CurrencyCode(rawValue: code)?.localizedName ?? code))
                        .accessibilityIdentifier("first_account_currency_\(index)")
                        if index > 0 {
                            Button {
                                DS.Haptic.selection()
                                draft.currencies.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(DS.Typography.caption.weight(.bold))
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(T.removeCurrency(CurrencyCode(rawValue: code)?.localizedName ?? code))
                        }
                    }
                    .padding(.trailing, index > 0 ? DS.Spacing.xs : 0)
                    .background(Capsule().fill(theme.card))
                }
                if Logic.canAddCurrency(count: draft.currencies.count) {
                    Button {
                        currencyPickTarget = CurrencyPickTarget(
                            index: nil, initial: CurrencyCode(rawValue: draft.currencies.first ?? "USD") ?? .usd)
                    } label: {
                        Text(T.addCurrency)
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .foregroundStyle(.thAccentText)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.md)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(Capsule().strokeBorder(theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4])))
                    .accessibilityIdentifier("first_account_add_currency")
                }
            }
            YalaPrimaryButton(T.continueButton) {
                DS.Haptic.selection()
                draft.balances = [:]
                advance()
            }
            .accessibilityIdentifier("first_account_currency_continue")
                    .primerosPasosButtonText()
        }
    }

    @ViewBuilder
    private var nameDock: some View {
        if draft.kind?.writesOwnName == true || editsName {
            textEntry(
                text: $nameText, prompt: editsName ? T.namePlaceholder : T.nameExample(nameExample),
                field: .name, canSend: !nameText.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                draft.name = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
                editsName = false
                advance()
            }
        } else {
            VStack(spacing: DS.Spacing.sm) {
                optionButton(title: T.nameKeep, highlighted: true, id: "first_account_name_keep") {
                    draft.name = suggestedName
                    advance()
                }
                optionButton(title: T.nameChange, id: "first_account_name_change") {
                    nameText = ""
                    editsName = true
                    focusSoon(.name)
                }
            }
        }
    }

    private var nameExample: String {
        switch draft.kind {
        case .checking: return T.exampleChecking
        case .savings: return T.exampleSavings
        default: return T.exampleCard
        }
    }

    private func balanceDock(index: Int) -> some View {
        let code = draft.currencies[safe: index] ?? "USD"
        let first = index == 0
        let word = currencyWord(code)
        return VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                if !isCard {
                    Button {
                        isNegative.toggle()
                    } label: {
                        Text(verbatim: isNegative ? "−" : "+")
                            .font(DS.Typography.title2.weight(.bold))
                            .foregroundStyle(isNegative ? Color.hotPink : Color.primary)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(theme.card))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isNegative ? T.signNegative : T.signPositive)
                    .accessibilityIdentifier("first_account_sign")
                }
                amountField(code: code)
                sendButton(enabled: Self.parsed(amountText) != nil) { saveBalance(index: index, code: code) }
            }
            if focusedField != .amount {
                optionButton(title: T.helpMe, icon: "plusminus", highlighted: true, id: "first_account_help") {
                    helperValues = ["", "", ""]
                    showsHelper = true
                }
                optionButton(
                    title: isCard ? (first ? T.oweNothing : T.oweNothingIn(word)) : (first ? T.startAtZero : T.noneIn(word)),
                    id: "first_account_zero"
                ) {
                    draft.balances[code] = 0
                    afterBalance()
                }
            }
        }
    }

    private func amountField(code: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(CurrencyCode(rawValue: code)?.symbol ?? code)
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
            TextField("", text: $amountText, prompt: Text(verbatim: "0.00").foregroundStyle(.tertiary))
                .font(DS.Typography.title3.weight(.semibold))
                .amountKeyboard()
                .focused($focusedField, equals: .amount)
                .accessibilityLabel(L10n.PrimerosPasos23.Account.balanceFieldLabel)
                .accessibilityIdentifier("first_account_amount")
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(minHeight: 48)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
    }

    // MARK: Ayuda del saldo

    private var helperRows: [(label: String, hint: String?)] {
        switch draft.kind {
        case .creditCard: return [(T.helperLimit, T.helperLimitHint), (T.helperRemaining, T.helperRemainingHint)]
        case .general: return [(T.helperInBank, nil), (T.helperSaved, nil), (T.helperInCash, nil)]
        case .cash: return [(T.helperCashRow, nil)]
        case .checking: return [(T.helperCheckingRow, nil)]
        default: return [(T.helperSavingsRow, nil)]
        }
    }

    private var helperTitle: String {
        switch draft.kind {
        case .creditCard: return T.helperCardTitle
        case .general: return T.helperGeneralTitle
        case .cash: return T.helperCashTitle
        case .checking: return T.helperCheckingTitle
        default: return T.helperSavingsTitle
        }
    }

    private var helperIntro: String {
        switch draft.kind {
        case .creditCard: return T.helperCardIntro
        case .general: return T.helperGeneralIntro
        case .cash: return T.helperCashIntro
        case .checking: return T.helperCheckingIntro
        default: return T.helperSavingsIntro
        }
    }

    /// Lo que da la ayuda, ya en positivo (lo que tienes o lo que debes). `nil` mientras falte algo.
    private var helperResult: Double? {
        let values = helperValues.prefix(helperRows.count).map { Self.parsed($0) }
        if isCard {
            guard let limit = values[safe: 0] ?? nil, let remaining = values[safe: 1] ?? nil else { return nil }
            return Logic.cardDebt(limit: limit, remaining: remaining)
        }
        let filled = values.compactMap { $0 }
        return filled.isEmpty ? nil : Logic.helperTotal(filled)
    }

    private func helperDock(index: Int) -> some View {
        let code = draft.currencies[safe: index] ?? "USD"
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(helperRows.enumerated()), id: \.offset) { row, item in
                    HStack(spacing: DS.Spacing.md) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(item.label).font(DS.Typography.body.weight(.semibold))
                            if let hint = item.hint {
                                Text(hint).font(DS.Typography.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: DS.Spacing.sm)
                        TextField("", text: $helperValues[row], prompt: Text(verbatim: "0").foregroundStyle(.tertiary))
                            .font(DS.Typography.body.weight(.semibold))
                            .multilineTextAlignment(.trailing)
                            .amountKeyboard()
                            .focused($focusedField, equals: .helper(row))
                            .frame(maxWidth: 140)
                            .accessibilityLabel(item.label)
                            .accessibilityIdentifier("first_account_helper_\(row)")
                    }
                    .padding(DS.Spacing.md)
                    if row < helperRows.count - 1 { Divider() }
                }
            }
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))

            if isCard, let limit = Self.parsed(helperValues[0]), limit > 0 {
                let remaining = Self.parsed(helperValues[1]) ?? limit
                cardUsageBar(limit: limit, remaining: remaining, code: code)
            }
            if let result = helperResult {
                HStack {
                    Text(isCard ? T.helperResultOwe : T.helperResultHave).font(DS.Typography.subheadline)
                    Spacer()
                    Text(appPreferences.currency(result, currencyCode: code)).font(DS.Typography.headline)
                }
            }
            YalaPrimaryButton(
                helperResult.map { T.useAmount(appPreferences.currency($0, currencyCode: code)) } ?? T.useThisBalance,
                isDisabled: helperResult == nil
            ) {
                guard let result = helperResult else { return }
                draft.balances[code] = Logic.storedBalance(kind: draft.kind ?? .general, magnitude: result, isNegative: false)
                showsHelper = false
                focusedField = nil
                afterBalance()
            }
            .accessibilityIdentifier("first_account_helper_use")
                    .primerosPasosButtonText()
            Text(T.helperFootnote)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func cardUsageBar(limit: Double, remaining: Double, code: String) -> some View {
        let used = Logic.cardUsedFraction(limit: limit, remaining: remaining)
        return VStack(spacing: DS.Spacing.xs) {
            HStack {
                Text(T.helperUsed).font(DS.Typography.caption)
                Spacer()
                Text(T.helperLeft).font(DS.Typography.caption)
            }
            .foregroundStyle(.secondary)
            Capsule()
                .fill(theme.accent.opacity(0.25))
                .frame(height: 10)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule().fill(Color.hotPink).frame(width: proxy.size.width * used)
                    }
                }
            HStack {
                Text(appPreferences.currency(Logic.cardDebt(limit: limit, remaining: remaining), currencyCode: code))
                Spacer()
                Text(appPreferences.currency(remaining, currencyCode: code))
            }
            .font(DS.Typography.caption.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Días y recordatorio

    private var dayDock: some View {
        let day = Int(dayText)
        return VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(T.dayPrefix).font(DS.Typography.headline).foregroundStyle(.secondary)
                    TextField("", text: $dayText, prompt: Text(T.dayPlaceholder).foregroundStyle(.tertiary))
                        .font(DS.Typography.title3.weight(.semibold))
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .day)
                        .accessibilityLabel(T.dayFieldLabel)
                        .accessibilityIdentifier("first_account_day")
                }
                .padding(.horizontal, DS.Spacing.md)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                sendButton(enabled: day.map(Logic.isValidDay) ?? false) {
                    guard let day, Logic.isValidDay(day) else { return }
                    answerDay(.day(day))
                }
            }
            if focusedField != .day {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DS.Spacing.sm) { dayNoButtons }
                    VStack(spacing: DS.Spacing.sm) { dayNoButtons }
                }
            }
        }
    }

    @ViewBuilder
    private var dayNoButtons: some View {
        optionButton(title: L10n.PrimerosPasos23.Account.dontKnow, id: "first_account_day_unknown") { answerDay(.unknown) }
        optionButton(title: L10n.PrimerosPasos23.Account.preferNotToSay, id: "first_account_day_private") {
            answerDay(.preferNotToSay)
        }
    }

    private var reminderDock: some View {
        let options = Logic.reminderOptions(statementDay: draft.statementDay?.day)
        return VStack(spacing: DS.Spacing.sm) {
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(options, id: \.self) { lead in
                    Button {
                        chooseReminder(lead)
                    } label: {
                        Text(Self.reminderLabel(lead))
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .background(Capsule().fill(theme.card))
                    .accessibilityIdentifier("first_account_reminder_\(lead)")
                }
            }
            optionButton(title: L10n.PrimerosPasos23.Account.noReminder, id: "first_account_reminder_none") {
                draft.reminderLead = nil
                advance()
            }
        }
    }

    static func reminderLabel(_ lead: Int) -> String {
        switch lead {
        case 0: return L10n.Account.CreditCard.reminderSameDay
        case 1: return L10n.Account.CreditCard.reminderOneDayBefore
        default: return L10n.Account.CreditCard.reminderDaysBefore(lead)
        }
    }

    private var doneDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaPrimaryButton(L10n.PrimerosPasos23.Account.seeMyYala) { onClose(createdCount > 0) }
                .accessibilityIdentifier("first_account_done")
                    .primerosPasosButtonText()
            if canCreateAnother {
                Button(L10n.PrimerosPasos23.Account.createAnother) { createAnother() }
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(.thAccentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("first_account_another")
            }
        }
    }

    // MARK: - Piezas

    private func optionButton(
        title: String, subtitle: String? = nil, icon: String? = nil, tint: Color? = nil,
        highlighted: Bool = false, id: String, action: @escaping () -> Void
    ) -> some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(tint ?? theme.accentText)
                        .frame(width: 28)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title).font(DS.Typography.body.weight(.semibold)).foregroundStyle(.primary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(DS.Typography.caption).foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right").font(DS.Typography.caption).foregroundStyle(.tertiary)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .strokeBorder(highlighted ? theme.accent.opacity(0.6) : .clear, lineWidth: 1.5)
                )
        )
        .accessibilityIdentifier(id)
    }

    private func textEntry(
        text: Binding<String>, prompt: String, field: Field, canSend: Bool, send: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(.tertiary))
                .font(DS.Typography.body)
                .focused($focusedField, equals: field)
                .submitLabel(.done)
                .onSubmit { if canSend { send() } }
                .padding(.horizontal, DS.Spacing.md)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                .accessibilityIdentifier("first_account_name_field")
            sendButton(enabled: canSend, action: send)
        }
    }

    private func sendButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            Image(systemName: "arrow.up")
                .font(DS.Typography.body.weight(.bold))
                .foregroundStyle(enabled ? theme.onAccent : Color.secondary)
                .frame(width: 48, height: 48)
                .background(Circle().fill(enabled ? theme.accent : Color.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(L10n.PrimerosPasos23.Account.send)
        .accessibilityIdentifier("first_account_send")
    }

    // MARK: - Avance

    private func seedDraftIfNeeded() {
        guard !didSeedDraft else { return }
        didSeedDraft = true
        // La moneda del país ya puesta: la que la persona eligió en el alta.
        draft = FirstAccountDraft(mainCurrency: appPreferences.defaultCurrencyCode.rawValue)
    }

    private func startQuestions() {
        DS.Haptic.selection()
        history = []
        step = .kind
        showsIntro = false
    }

    private func advance() {
        let next = Logic.next(
            after: step, kind: draft.kind, currencyCount: draft.currencies.count, paymentDay: draft.paymentDay)
        // La cuenta se crea al llegar a «¡Lista!». Si falla no se avanza (sale el aviso y se puede reintentar), y si sale
        // bien la historia se vacía: volver atrás desde ahí ya no puede crearla otra vez (review del lote).
        if next == .done {
            guard createAccount() else { return }
            history = []
        } else {
            history.append(step)
        }
        prepare(next)
        step = next
    }

    /// Deja lista la entrada de la pregunta que llega.
    private func prepare(_ next: Logic.Step) {
        focusedField = nil
        showsHelper = false
        switch next {
        case .balance:
            amountText = ""
            isNegative = false
        case .statementDay, .paymentDay:
            dayText = ""
        case .name:
            nameText = ""
            editsName = false
        default:
            break
        }
    }

    private func goBack() {
        if showsHelper {
            showsHelper = false
            focusedField = nil
            return
        }
        if editsName {
            editsName = false
            return
        }
        guard step != .done, let previous = history.popLast() else {
            // Desde «¡Lista!» se cierra (la cuenta ya existe); desde la primera pregunta, la página corta (como el
            // prototipo), salvo que ya se haya creado una.
            if createdCount > 0 { onClose(true) } else { showsIntro = true }
            return
        }
        prepare(previous)
        step = previous
    }

    private func saveBalance(index: Int, code: String) {
        guard let magnitude = Self.parsed(amountText), let kind = draft.kind else { return }
        draft.balances[code] = Logic.storedBalance(kind: kind, magnitude: magnitude, isNegative: isNegative)
        afterBalance()
    }

    private func afterBalance() {
        advance()
    }

    private func answerDay(_ answer: Logic.DayAnswer) {
        if step == .statementDay {
            draft.statementDay = answer
        } else {
            draft.paymentDay = answer
        }
        advance()
    }

    /// Un recordatorio elegido pide el permiso de notificaciones si iOS nunca preguntó (Y23-17). Se guarda igual aunque
    /// se niegue, como el formulario de cuenta: si la persona activa las notificaciones después, el aviso ya está.
    private func chooseReminder(_ lead: Int) {
        DS.Haptic.selection()
        draft.reminderLead = lead
        Task { @MainActor in
            #if DEBUG
            if UITestHooks.isActive {
                advance()
                return
            }
            #endif
            await TutorialPermissionMoments.remindMeChosen()
            advance()
        }
    }

    /// Crea la cuenta. Devuelve si se creó.
    private func createAccount() -> Bool {
        do {
            let account = try FirstAccountCreator.create(draft, suggestedName: suggestedName, in: modelContext)
            createdCount += 1
            lastCreatedName = account.name
            lastCreatedCurrencies = FirstAccountFlowLogic.normalizedCurrencies(draft.currencies)
            DS.Haptic.success()
            return true
        } catch {
            #if DEBUG
            print("FirstAccountFlowView: Error: creating the account: \(error)")
            #endif
            saveFailed = true
            return false
        }
    }

    /// «Crear otra cuenta» respeta el límite del plan Free, como el resto de entradas (review del lote).
    private var canCreateAnother: Bool {
        do {
            let count = try modelContext.fetch(FetchDescriptor<Account>()).count(where: \.isBillableUserAccount)
            return FeatureGateService.shared.canCreate(.accounts, currentCount: count)
        } catch {
            #if DEBUG
            print("FirstAccountFlowView: Error: counting the accounts: \(error)")
            #endif
            return false
        }
    }

    private func createAnother() {
        DS.Haptic.selection()
        draft = FirstAccountDraft(mainCurrency: appPreferences.defaultCurrencyCode.rawValue)
        history = []
        prepare(.kind)
        step = .kind
    }

    private func apply(_ code: String, to index: Int?) {
        var codes = draft.currencies
        if let index, codes.indices.contains(index) {
            codes[index] = code
        } else {
            codes.append(code)
        }
        draft.currencies = Logic.normalizedCurrencies(codes)
    }

    private func focusSoon(_ field: Field) {
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            focusedField = field
        }
    }

    // MARK: - Ayudantes

    static func parsed(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return AmountInputHelper.parseDecimal(trimmed)
    }

    static func secondCurrencySuggestion(main: String) -> CurrencyCode {
        main == CurrencyCode.usd.rawValue ? .eur : .usd
    }

    /// «soles y dólares», «soles, dólares y euros».
    static func joinedList(_ words: [String]) -> String {
        ListFormatter.localizedString(byJoining: words)
    }
}

// MARK: - Tarjeta de la cuenta, llenándose arriba

struct FirstAccountCardPreview: View {
    let draft: FirstAccountDraft
    let suggestedName: String

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    private typealias T = L10n.PrimerosPasos23.Account

    private var isCard: Bool { draft.kind?.isCard == true }

    private func amountText(_ code: String) -> String {
        guard let value = draft.balances[code] else { return "—" }
        return appPreferences.currency(abs(value), currencyCode: code).prefixedIfNegative(isNegative(value))
    }

    private func isNegative(_ value: Double) -> Bool { !isCard && value < 0 }

    var body: some View {
        let main = draft.currencies.first ?? "USD"
        let kindColor = draft.kind.map { Color(hex: $0.colorHex) } ?? Color.secondary.opacity(0.3)
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: draft.kind.map { iconName(for: $0.accountType) } ?? "questionmark")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(kindColor))
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(draft.name.isEmpty ? T.cardPlaceholderName : draft.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(draft.name.isEmpty ? .secondary : .primary)
                    Text(typeLine)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(balanceCaption(main))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                Text(amountText(main))
                    .font(DS.Typography.title2.weight(.bold))
                    .foregroundStyle(isCard && (draft.balances[main] ?? 0) != 0 ? Color.hotPink : .primary)
                    .contentTransition(.numericText())
            }
            ForEach(Array(draft.currencies.dropFirst()), id: \.self) { code in
                HStack {
                    Text(T.cardLine((CurrencyCode(rawValue: code) ?? .usd).shortPluralName))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(amountText(code)).font(DS.Typography.subheadline.weight(.semibold))
                }
            }
            if isCard, let daysLine {
                Text(daysLine)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(theme.card))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("first_account_card")
    }

    private var typeLine: String {
        guard let kind = draft.kind else { return T.cardPlaceholderType }
        let symbols = draft.currencies.map { CurrencyCode(rawValue: $0)?.symbol ?? $0 }.joined(separator: " + ")
        return "\(kind.accountType.localizedName) · \(symbols)"
    }

    private func balanceCaption(_ main: String) -> String {
        let word = (CurrencyCode(rawValue: main) ?? .usd).shortPluralName
        if draft.currencies.count > 1 {
            return isCard ? T.cardOweIn(word) : T.cardBalanceIn(word)
        }
        return isCard ? T.cardOwe : T.cardBalance
    }

    private var daysLine: String? {
        var parts: [String] = []
        if let day = draft.statementDay?.day { parts.append(T.cardClosesOn(day)) }
        if let day = draft.paymentDay?.day { parts.append(T.cardPayBy(day)) }
        if let lead = draft.reminderLead, draft.paymentDay?.day != nil {
            parts.append(T.cardReminds(FirstAccountFlowView.reminderLabel(lead).lowercased()))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private extension String {
    func prefixedIfNegative(_ negative: Bool) -> String { negative ? "−" + self : self }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// El selector de moneda de la app con la elección de partida: solo avisa si se elige otra.
private struct FirstAccountCurrencyPicker: View {
    let onPick: (CurrencyCode) -> Void
    @State private var selection: CurrencyCode

    init(initial: CurrencyCode, onPick: @escaping (CurrencyCode) -> Void) {
        _selection = State(initialValue: initial)
        self.onPick = onPick
    }

    var body: some View {
        CurrencyPickerSheet(selectedCurrency: $selection)
            .onChange(of: selection) { _, code in onPick(code) }
    }
}
