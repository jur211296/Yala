//
//  ChatGuidedFlowCard.swift
//  Yala
//
//  La tarjeta de un guiado de Yala IA dentro del hilo: la cabecera con sus puntos, la tarjeta del presupuesto o del
//  pago llenándose arriba (las de Primeros pasos), la pregunta y sus respuestas (las piezas de `TutorialQuestionPieces`),
//  la confirmación con «Cambiar» en cada respuesta y, al crear, la tarjeta de éxito con acceso a lo creado.
//
//  La tarjeta no decide nada: cada toque contesta por el ViewModel del chat y el motor (`ChatGuidedEngine`) elige la
//  siguiente pregunta. Lo que se escribe en un campo vive aquí solo hasta enviarlo.
//

import SwiftData
import SwiftUI

struct ChatGuidedFlowCard: View {
    let messageID: UUID
    let state: ChatGuidedFlowState
    @Bindable var viewModel: ChatAssistantViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var data: ChatGuidedData?
    @State private var amountText = ""
    @State private var nameText = ""
    @State private var otherDayText = ""
    @State private var editsOtherDay = false
    @State private var pickedCategories: [PersistentIdentifier] = []
    @State private var dateValue = Date.now
    @State private var errorText: String?
    /// «Cambia cada vez»: viaja con el monto al enviarlo.
    @State private var variableAmount = false
    @State private var showsOtherSubcategory = false
    @State private var otherSubcategory: Subcategory?
    @FocusState private var amountFocused: Bool
    @FocusState private var nameFocused: Bool
    @FocusState private var dayFocused: Bool

    private typealias G = L10n.IAGuiados
    private typealias B = L10n.PrimerosPasos23.Budget
    private typealias Pay = L10n.PrimerosPasos23.Payment
    private typealias Plan = L10n.PrimerosPasos23.Plan

    private var answers: ChatGuidedAnswers { state.answers }
    private var mainCurrency: String { CurrencyDefaults.currentPreferred }
    private var currency: String { answers.currencyCode ?? mainCurrency }

    var body: some View {
        content
            .task(id: state.id) { loadIfNeeded() }
            .onAppear(perform: syncFields)
            .onChange(of: state.step) { _, _ in syncFields() }
            .sheet(isPresented: $showsOtherSubcategory, onDismiss: applyOtherSubcategory) {
                SubcategorySelectorSheet(selectedSubcategory: $otherSubcategory, transactionType: .expense)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state.status {
        case .cancelled:
            Text(G.cancelled)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("chat_guided_cancelled")
        case .created:
            ChatGuidedSuccessCard(state: state)
        case .inProgress:
            inProgress
        }
    }

    // MARK: - En curso

    private var inProgress: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            header
            preview
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(questionTitle)
                    .font(DS.Typography.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("chat_guided_question")
                if let detail = questionDetail {
                    Text(detail)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .id(state.step)
            .transition(.opacity)
            dock
            if let errorText {
                Text(errorText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.overBudgetText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("chat_guided_error")
            }
            Button(G.notNow) { viewModel.guidedCancel(messageID: messageID) }
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("chat_guided_cancel")
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .animation(reduceMotion ? nil : DS.Animation.appear, value: state.step)
    }

    private var header: some View {
        let progress = ChatGuidedEngine.progress(state)
        return HStack(spacing: DS.Spacing.sm) {
            if !state.history.isEmpty {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    errorText = nil
                    viewModel.guidedBack(messageID: messageID)
                }
                .accessibilityIdentifier("chat_guided_back")
            }
            Image(systemName: state.kind == .budget ? "chart.pie.fill" : "calendar.badge.clock")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(theme.accentText)
                .accessibilityHidden(true)
            // El id va en el título y no en la tarjeta: puesto en un contenedor pisa el de sus botones.
            Text(state.kind == .budget ? G.budgetHeader : G.paymentHeader)
                .font(DS.Typography.headline)
                .accessibilityIdentifier("chat_guided_header")
            Spacer(minLength: DS.Spacing.sm)
            HStack(spacing: DS.Spacing.xxs) {
                ForEach(0..<progress.total, id: \.self) { offset in
                    Circle()
                        .fill(offset < progress.answered ? theme.accent : Color.primary.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.PrimerosPasos23.partOf(min(progress.answered + 1, progress.total), progress.total))
        }
    }

    // MARK: - La tarjeta de arriba

    @ViewBuilder
    private var preview: some View {
        switch state.kind {
        case .budget:
            if answers.allExpenses != nil || answers.amount != nil {
                FirstBudgetCardPreview(
                    name: budgetName,
                    isNamePlaceholder: answers.allExpenses == nil,
                    look: budgetLook,
                    caption: budgetCaption,
                    limit: answers.amount,
                    spent: budgetSpent,
                    currencyCode: currency,
                    alert: nil
                )
            }
        case .scheduledPayment:
            if answers.paymentName != nil || answers.amount != nil {
                FirstPaymentCardPreview(
                    name: answers.paymentName ?? "",
                    look: paymentLook,
                    due: paymentDue.map { TutorialPlanningMath.dueInText($0) },
                    amount: answers.amount.map(money),
                    isEstimate: answers.isVariableAmount,
                    subcategoryName: data?.subcategory(answers.subcategoryID)?.name,
                    accountName: data?.account(answers.accountID)?.name ?? "",
                    isSubscription: answers.isSubscription,
                    summary: paymentSummary
                )
            }
        }
    }

    // MARK: - La pregunta

    private var questionTitle: String {
        switch state.step {
        case .categories: G.budgetCategoriesQuestion
        case .period: B.periodQuestion
        case .amount:
            if state.kind == .scheduledPayment { G.paymentAmountQuestion } else {
                switch answers.period {
                case .weekly: B.limitQuestionWeekly
                case .yearly: B.limitQuestionYearly
                case .monthly, nil: B.limitQuestionMonthly
                }
            }
        case .currency: G.currencyQuestion
        case .suggestion: G.paymentSuggestionQuestion
        case .name: G.paymentNameQuestion
        case .frequency: G.paymentFrequencyQuestion
        case .when:
            switch answers.frequency {
            case .weekly: G.paymentWhenWeekly
            case .yearly, .once: G.paymentWhenDate
            case .monthly, nil: G.paymentWhenMonthly
            }
        case .account: G.paymentAccountQuestion
        case .subcategory: G.paymentSubcategoryQuestion
        case .confirm, .done: G.confirmQuestion
        }
    }

    private var questionDetail: String? {
        switch state.step {
        case .categories: G.budgetCategoriesSubtitle
        case .period: B.periodSubtitle
        case .amount:
            if state.kind == .budget {
                budgetAverage > 0 ? G.budgetAmountAverage(money(budgetAverage)) : B.limitRoundNumber
            } else { nil }
        case .suggestion: G.paymentSuggestionSubtitle
        case .name: G.paymentNameSubtitle
        case .confirm: G.confirmSubtitle
        default: nil
        }
    }

    // MARK: - Las respuestas

    @ViewBuilder
    private var dock: some View {
        switch state.step {
        case .categories: categoriesDock
        case .period: periodDock
        case .amount: amountDock
        case .currency: currencyDock
        case .suggestion: suggestionDock
        case .name: nameDock
        case .frequency: frequencyDock
        case .when: whenDock
        case .account: accountDock
        case .subcategory: subcategoryDock
        case .confirm: confirmDock
        case .done: EmptyView()
        }
    }

    private var categoriesDock: some View {
        VStack(spacing: DS.Spacing.md) {
            TutorialOptionButton(title: B.scopeAll, subtitle: B.scopeAllHint, icon: "chart.pie.fill",
                                 id: "chat_guided_all_expenses") {
                answer(clearing: [.categories]) {
                    $0.allExpenses = true
                    $0.categoryIDs = []
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm),
                                     count: TutorialGridColumns.count(3, dynamicTypeSize: dynamicTypeSize)),
                      spacing: DS.Spacing.sm) {
                ForEach(data?.categories ?? []) { category in
                    TutorialSelectableTile(
                        icon: category.icon,
                        color: Color(hex: category.colorHex),
                        title: category.name,
                        caption: category.spentThisMonth > 0 ? B.categoriesSpent(money(category.spentThisMonth)) : nil,
                        isOn: pickedCategories.contains(category.id),
                        id: "chat_guided_category"
                    ) { toggle(category.id) }
                }
            }
            YalaPrimaryButton(L10n.Action.continueAction) {
                let picked = pickedCategories
                answer(clearing: [.categories]) {
                    $0.allExpenses = false
                    $0.categoryIDs = picked
                }
            }
            .disabled(pickedCategories.isEmpty)
            .accessibilityIdentifier("chat_guided_categories_continue")
        }
    }

    private var periodDock: some View {
        let options: [(ChatGuidedPeriod, String, String)] = [
            (.monthly, BudgetPeriodType.monthly.localizedName, B.periodMonthlyHint),
            (.weekly, BudgetPeriodType.weekly.localizedName, B.periodWeeklyHint),
            (.yearly, BudgetPeriodType.yearly.localizedName, B.periodYearlyHint),
        ]
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(options, id: \.0) { period, title, hint in
                TutorialOptionButton(title: title, subtitle: hint, highlighted: period == .monthly,
                                     id: "chat_guided_period_\(period.rawValue)") {
                    answer(clearing: [.period]) { $0.period = period }
                }
            }
        }
    }

    private var amountDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if state.kind == .budget, let period = answers.period,
               let suggested = ChatGuidedSpending.suggestions(monthlyAverage: budgetAverage, period: period) {
                VStack(spacing: DS.Spacing.sm) {
                    TutorialOptionButton(title: money(suggested.saving), subtitle: G.budgetAmountSavingHint,
                                         icon: "leaf.fill", highlighted: true, id: "chat_guided_amount_saving") {
                        answerAmount(suggested.saving)
                    }
                    if suggested.usual != suggested.saving {
                        TutorialOptionButton(title: money(suggested.usual), subtitle: G.budgetAmountUsualHint,
                                             icon: "equal.circle.fill", id: "chat_guided_amount_usual") {
                            answerAmount(suggested.usual)
                        }
                    }
                }
            }
            HStack(spacing: DS.Spacing.sm) {
                TutorialAmountField(
                    text: $amountText,
                    currencySymbol: CurrencyCode(rawValue: currency)?.symbol ?? currency,
                    accessibilityLabel: questionTitle,
                    id: "chat_guided_amount",
                    focus: $amountFocused
                )
                TutorialSendButton(enabled: typedAmount != nil, id: "chat_guided_amount_send") {
                    if let typedAmount { answerAmount(typedAmount) }
                }
            }
            if state.kind == .scheduledPayment {
                TutorialToggleRow(title: Pay.detailsVariable, hint: Pay.detailsVariableHint, isOn: $variableAmount,
                                  id: "chat_guided_variable")
            }
        }
    }

    private var currencyDock: some View {
        FlowLayout(spacing: DS.Spacing.sm) {
            ForEach(data?.currencies ?? [mainCurrency], id: \.self) { code in
                TutorialChip(title: currencyTitle(code), isOn: answers.currencyCode == code,
                             id: "chat_guided_currency_\(code)") {
                    answer(clearing: [.currency]) { $0.currencyCode = code }
                }
            }
        }
    }

    private var suggestionDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(data?.suggestions ?? []) { suggestion in
                TutorialOptionButton(
                    title: suggestion.name,
                    subtitle: suggestionCaption(suggestion),
                    icon: "repeat",
                    id: "chat_guided_suggestion"
                ) { take(suggestion) }
            }
            TutorialOptionButton(title: G.paymentSuggestionOther, icon: "plus", id: "chat_guided_suggestion_other") {
                answer { $0.suggestionKey = "" }
            }
        }
    }

    private var nameDock: some View {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: DS.Spacing.sm) {
            TextField("", text: $nameText, prompt: Text(Pay.detailsNamePlaceholder).foregroundStyle(.tertiary))
                .font(DS.Typography.body)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { if !trimmed.isEmpty { answerName(trimmed) } }
                .padding(.horizontal, DS.Spacing.md)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                .accessibilityLabel(G.rowName)
                .accessibilityIdentifier("chat_guided_name")
            TutorialSendButton(enabled: !trimmed.isEmpty, id: "chat_guided_name_send") { answerName(trimmed) }
        }
    }

    private var frequencyDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(ChatGuidedFrequency.allCases, id: \.self) { frequency in
                TutorialOptionButton(title: frequencyTitle(frequency), highlighted: frequency == .monthly,
                                     id: "chat_guided_frequency_\(frequency.rawValue)") {
                    // Elegir la frecuencia (también la misma, desde «Cambiar») vuelve a preguntar el día.
                    answer(clearing: [.frequency, .day]) {
                        $0.frequency = frequency
                        $0.dayOfMonth = nil
                        $0.weekday = nil
                        $0.date = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var whenDock: some View {
        switch answers.frequency {
        case .weekly: weekdayDock
        case .yearly, .once: dateDock
        case .monthly, nil: monthDayDock
        }
    }

    private var monthDayDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(FirstScheduledPaymentFlowLogic.monthDayShortcuts, id: \.self) { day in
                    TutorialChip(title: "\(day)", isOn: !editsOtherDay && answers.dayOfMonth == day,
                                 id: "chat_guided_day_\(day)") {
                        answer(clearing: [.day]) { $0.dayOfMonth = day }
                    }
                }
                TutorialChip(title: Pay.whenOtherDay, isOn: editsOtherDay, id: "chat_guided_day_other") {
                    editsOtherDay = true
                    otherDayText = ""
                    dayFocused = true
                }
            }
            if editsOtherDay {
                HStack(spacing: DS.Spacing.sm) {
                    TextField("", text: $otherDayText, prompt: Text(verbatim: "18").foregroundStyle(.tertiary))
                        .font(DS.Typography.title3.weight(.semibold))
                        .keyboardType(.numberPad)
                        .focused($dayFocused)
                        .padding(.horizontal, DS.Spacing.md)
                        .frame(minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                        .accessibilityLabel(G.paymentWhenMonthly)
                        .accessibilityIdentifier("chat_guided_day_field")
                    TutorialSendButton(enabled: typedDay != nil, id: "chat_guided_day_send") {
                        if let typedDay { answer(clearing: [.day]) { $0.dayOfMonth = typedDay } }
                    }
                }
            }
        }
    }

    private var weekdayDock: some View {
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        return FlowLayout(spacing: DS.Spacing.sm) {
            ForEach(FirstScheduledPaymentFlowLogic.weekdaysMondayFirst, id: \.self) { weekday in
                TutorialChip(title: symbols[weekday - 1], isOn: answers.weekday == weekday,
                             id: "chat_guided_weekday_\(weekday)") {
                    answer(clearing: [.day]) { $0.weekday = weekday }
                }
            }
        }
    }

    private var dateDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DatePicker(G.paymentWhenDate, selection: $dateValue, in: Calendar.current.startOfDay(for: .now)...,
                       displayedComponents: .date)
                .labelsHidden()
                .accessibilityLabel(G.paymentWhenDate)
                .accessibilityIdentifier("chat_guided_date")
            YalaPrimaryButton(L10n.Action.continueAction) {
                let date = Calendar.current.startOfDay(for: dateValue)
                answer(clearing: [.day]) { $0.date = date }
            }
            .accessibilityIdentifier("chat_guided_date_continue")
        }
    }

    private var accountDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(data?.accounts ?? []) { account in
                TutorialOptionButton(
                    title: account.name,
                    subtitle: currencyTitle(account.currencyCode),
                    icon: "building.columns",
                    highlighted: account.id == data?.defaultAccountID,
                    id: "chat_guided_account"
                ) { choose(account) }
            }
        }
    }

    private var subcategoryDock: some View {
        VStack(spacing: DS.Spacing.md) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm),
                                     count: TutorialGridColumns.count(3, dynamicTypeSize: dynamicTypeSize)),
                      spacing: DS.Spacing.sm) {
                ForEach(data?.paymentSubcategories ?? []) { option in
                    TutorialSelectableTile(
                        icon: option.icon,
                        color: Color(hex: option.colorHex),
                        title: option.name,
                        caption: option.categoryName,
                        isOn: answers.subcategoryID == option.id,
                        id: "chat_guided_subcategory"
                    ) {
                        answer { $0.subcategoryID = option.id }
                    }
                }
            }
            Button(Pay.otherSubcategory) {
                otherSubcategory = nil
                showsOtherSubcategory = true
            }
            .font(DS.Typography.body.weight(.semibold))
            .foregroundStyle(.thAccentText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier("chat_guided_subcategory_other")
        }
    }

    // MARK: - Confirmación

    private var confirmDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(spacing: 0) {
                ForEach(Array(confirmRows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().padding(.leading, DS.Spacing.md) }
                    ChatGuidedConfirmRow(row: row) {
                        errorText = nil
                        viewModel.guidedEdit(messageID: messageID, step: row.step)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
            YalaPrimaryButton(state.kind == .budget ? G.confirmCreateBudget : G.confirmCreatePayment) {
                guard let data else { return }
                errorText = viewModel.createGuided(messageID: messageID, data: data)
            }
            .disabled(data == nil || !ChatGuidedEngine.canCreate(state))
            .accessibilityIdentifier("chat_guided_create")
        }
    }

    private var confirmRows: [ChatGuidedConfirmRow.Model] {
        switch state.kind {
        case .budget:
            let categories = answers.allExpenses == true
                ? B.scopeAll
                : answers.categoryIDs.compactMap { data?.category($0)?.name }.joined(separator: ", ")
            return [
                .init(step: .categories, label: G.rowCategories, value: categories,
                      saidByYou: state.prefilled.contains(.categories)),
                .init(step: .period, label: G.rowPeriod, value: periodTitle(answers.period),
                      saidByYou: state.prefilled.contains(.period)),
                .init(step: .amount, label: G.rowLimit, value: answers.amount.map(money) ?? "—",
                      saidByYou: state.prefilled.contains(.amount)),
                .init(step: .currency, label: G.rowCurrency, value: currencyTitle(currency),
                      saidByYou: state.prefilled.contains(.currency)),
            ]
        case .scheduledPayment:
            return [
                .init(step: .name, label: G.rowName, value: answers.paymentName ?? "—",
                      saidByYou: state.prefilled.contains(.name)),
                .init(step: .amount, label: G.rowAmount, value: answers.amount.map(money) ?? "—",
                      saidByYou: state.prefilled.contains(.amount)),
                .init(step: .frequency, label: G.rowWhen, value: cadenceText,
                      saidByYou: state.prefilled.contains(.frequency)),
                .init(step: .account, label: G.rowAccount, value: data?.account(answers.accountID)?.name ?? "—",
                      saidByYou: false),
                .init(step: .subcategory, label: G.rowCategory,
                      value: data?.subcategory(answers.subcategoryID)?.name ?? "—", saidByYou: false),
                .init(step: .currency, label: G.rowCurrency, value: currencyTitle(currency),
                      saidByYou: state.prefilled.contains(.currency)),
            ]
        }
    }

    // MARK: - Contestar

    private func answer(clearing fields: Set<ChatGuidedField> = [], _ change: (inout ChatGuidedAnswers) -> Void) {
        errorText = nil
        amountFocused = false
        nameFocused = false
        dayFocused = false
        editsOtherDay = false
        viewModel.answerGuided(messageID: messageID, clearing: fields, change)
    }

    private func answerAmount(_ value: Double) {
        guard ChatGuidedEngine.isValidAmount(value) else { return }
        let variable = variableAmount
        let isPayment = state.kind == .scheduledPayment
        answer(clearing: [.amount]) {
            $0.amount = value
            if isPayment { $0.isVariableAmount = variable }
        }
    }

    private func answerName(_ name: String) {
        let brand = SubscriptionBrandCatalog.match(name: name)
        answer(clearing: [.name]) {
            $0.paymentName = name
            if brand != nil { $0.isSubscription = true }
        }
    }

    private func toggle(_ id: PersistentIdentifier) {
        if let index = pickedCategories.firstIndex(of: id) {
            pickedCategories.remove(at: index)
        } else {
            pickedCategories.append(id)
        }
    }

    /// Un cobro de los registros: trae todo lo que sabe. Lo que la persona ya dijo en su frase se queda.
    private func take(_ suggestion: ChatGuidedData.PaymentSuggestion) {
        let said = state.prefilled
        answer {
            $0.suggestionKey = suggestion.key
            if !said.contains(.name) { $0.paymentName = suggestion.name }
            if !said.contains(.amount) { $0.amount = suggestion.amount }
            if !said.contains(.frequency) {
                $0.frequency = suggestion.frequency
                $0.dayOfMonth = suggestion.dayOfMonth
                $0.weekday = suggestion.weekday
            }
            if !said.contains(.currency) { $0.currencyCode = suggestion.currencyCode }
            $0.isVariableAmount = suggestion.isVariableAmount
            $0.isSubscription = $0.isSubscription || suggestion.isSubscription
            if let account = suggestion.accountID { $0.accountID = account }
            if let subcategory = suggestion.subcategoryID { $0.subcategoryID = subcategory }
        }
    }

    private func choose(_ account: ChatGuidedData.AccountOption) {
        let keepsCurrency = state.prefilled.contains(.currency)
        answer {
            $0.accountID = account.id
            if !keepsCurrency { $0.currencyCode = account.currencyCode.uppercased() }
        }
    }

    /// Al cerrarse «Otra subcategoría»: la elegida entra en las opciones y contesta.
    private func applyOtherSubcategory() {
        guard let other = otherSubcategory, !other.isDeleted, other.modelContext != nil else { return }
        let option = ChatGuidedDataSource.option(other)
        if data?.paymentSubcategories.contains(where: { $0.id == option.id }) == false {
            data?.paymentSubcategories.append(option)
        }
        answer { $0.subcategoryID = option.id }
    }

    // MARK: - Carga y campos

    private func loadIfNeeded() {
        guard data == nil, state.status == .inProgress else { return }
        data = ChatGuidedDataSource.load(state.kind, context: modelContext, mainCurrency: mainCurrency)
    }

    /// Lo escrito en los campos empieza con la respuesta que ya hay (al volver atrás o al «Cambiar»).
    private func syncFields() {
        amountText = answers.amount.map { $0.rounded() == $0 ? String(Int($0)) : String(format: "%.2f", $0) } ?? ""
        variableAmount = answers.isVariableAmount
        nameText = answers.paymentName ?? ""
        pickedCategories = answers.categoryIDs
        dateValue = answers.date ?? .now
        editsOtherDay = false
        if let day = answers.dayOfMonth, !FirstScheduledPaymentFlowLogic.monthDayShortcuts.contains(day) {
            otherDayText = "\(day)"
        }
    }

    // MARK: - Cifras y textos

    private var typedAmount: Double? {
        let value = FirstAccountFlowView.parsed(amountText)
        return ChatGuidedEngine.isValidAmount(value) ? value : nil
    }

    private var typedDay: Int? {
        Int(otherDayText).flatMap { ChatGuidedEngine.isValidMonthDay($0) ? $0 : nil }
    }

    private func money(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: currency, isEstimate: state.kind == .scheduledPayment
            && answers.isVariableAmount)
    }

    private func currencyTitle(_ code: String) -> String {
        guard let known = CurrencyCode(rawValue: code.uppercased()) else { return code }
        return "\(known.symbol) · \(code.uppercased())"
    }

    private func periodTitle(_ period: ChatGuidedPeriod?) -> String {
        guard let period, let type = BudgetPeriodType(rawValue: period.budgetPeriodRaw) else { return "—" }
        return type.localizedName
    }

    private func frequencyTitle(_ frequency: ChatGuidedFrequency) -> String {
        switch frequency {
        case .monthly: Pay.whenMonthly
        case .weekly: Pay.whenWeekly
        case .yearly: Pay.whenYearly
        case .once: Pay.whenOnce
        }
    }

    private func suggestionCaption(_ suggestion: ChatGuidedData.PaymentSuggestion) -> String {
        let amount = appPreferences.currency(suggestion.amount, currencyCode: suggestion.currencyCode,
                                             isEstimate: suggestion.isVariableAmount)
        return "\(amount) · \(frequencyTitle(suggestion.frequency))"
    }

    private var cadenceText: String {
        guard let frequency = answers.frequency else { return "—" }
        switch frequency {
        case .monthly:
            return L10n.UXL10.cadenceMonthly(interval: 1, day: answers.dayOfMonth ?? 1)
        case .weekly:
            let symbols = Calendar.current.standaloneWeekdaySymbols
            let day = answers.weekday.map { symbols[max(0, min(6, $0 - 1))] } ?? ""
            return [L10n.UXL10.cadenceWeekly(interval: 1), day].filter { !$0.isEmpty }.joined(separator: " · ")
        case .yearly:
            return L10n.UXL10.cadenceYearly(interval: 1, date: ScheduledPaymentDateText.dayMonthLong(answers.date ?? .now))
        case .once:
            return ScheduledPaymentDateText.dayMonthLong(answers.date ?? .now)
        }
    }

    // MARK: Presupuesto

    private var budgetName: String {
        guard answers.allExpenses != nil, let data else { return "" }
        return ChatGuidedCreator.suggestedBudgetName(answers, data: data)
    }

    private var budgetLook: (icon: String, color: Color) {
        if answers.allExpenses == false, answers.categoryIDs.count == 1,
           let only = answers.categoryIDs.first.flatMap({ data?.category($0) }) {
            return (only.icon, Color(hex: only.colorHex))
        }
        return ("chart.pie.fill", theme.accent)
    }

    private var budgetSubcategoryIDs: [UUID] { data?.budgetSubcategoryIDs(answers) ?? [] }

    private var budgetSpent: Double {
        guard let data, let period = answers.period,
              let type = BudgetPeriodType(rawValue: period.budgetPeriodRaw) else { return 0 }
        return TutorialPlanningMath.budgetSpent(subcategoryIDs: budgetSubcategoryIDs, period: type,
                                                currencyCode: currency, transactions: data.transactions)
    }

    private var budgetAverage: Double {
        guard let data, answers.allExpenses != nil else { return 0 }
        return ChatGuidedSpending.monthlyAverage(subcategoryIDs: budgetSubcategoryIDs, currencyCode: currency,
                                                 transactions: data.transactions)
    }

    private var budgetCaption: String {
        var caption: String
        if let limit = answers.amount {
            caption = Plan.spentOfLimit(money(budgetSpent), money(limit))
        } else if answers.allExpenses == true {
            caption = B.cardCountsAll
        } else if answers.categoryIDs.isEmpty {
            caption = B.cardPickCategories
        } else {
            caption = B.categoriesSpent(money(budgetSpent))
        }
        if answers.period != nil { caption += " · " + periodTitle(answers.period) }
        return caption
    }

    // MARK: Pago

    private var paymentLook: (icon: String, color: Color) {
        guard let option = data?.subcategory(answers.subcategoryID) else { return ("calendar.badge.clock", theme.accent) }
        return (option.icon, Color(hex: option.colorHex))
    }

    private var paymentDue: Date? {
        guard let frequency = answers.frequency,
              ChatGuidedEngine.scheduledPaymentSpec.isAnswered(.when, answers) else { return nil }
        return TutorialPlanningMath.paymentFirstDue(
            frequency: frequency.flowFrequency,
            dayOfMonth: answers.dayOfMonth ?? 1,
            weekday: answers.weekday ?? 2,
            date: answers.date ?? .now
        )
    }

    private var paymentSummary: String? {
        guard let amount = answers.amount, let frequency = answers.frequency, let due = paymentDue else { return nil }
        let amountText = appPreferences.currency(amount, currencyCode: currency, forceFullPrecision: true,
                                                 isEstimate: answers.isVariableAmount)
        return TutorialPlanningMath.paymentSummary(
            amountText: amountText, frequency: frequency.flowFrequency, dayOfMonth: answers.dayOfMonth ?? 1,
            date: answers.date ?? .now, due: due)
    }
}

// MARK: - Una fila de la confirmación

struct ChatGuidedConfirmRow: View {
    struct Model {
        let step: ChatGuidedStep
        let label: String
        let value: String
        let saidByYou: Bool
    }

    let row: Model
    let onChange: () -> Void

    var body: some View {
        AdaptiveRowStack(spacing: DS.Spacing.md, stackedSpacing: DS.Spacing.xs) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(row.label).font(DS.Typography.caption).foregroundStyle(.secondary)
                Text(row.value)
                    .font(DS.Typography.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if row.saidByYou {
                    Label(L10n.IAGuiados.confirmYouSaidIt, systemImage: "quote.bubble")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thAccentText)
                }
            }
        } trailing: {
            Button(L10n.PrimerosPasos23.Payment.change, action: onChange)
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(.thAccentText)
                .frame(minWidth: 44, minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.IAGuiados.changeA11y(row.label))
                .accessibilityIdentifier("chat_guided_change_\(row.step.rawValue)")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Éxito

/// Lo creado, con acceso directo. Cierra el chat y abre el presupuesto o el pago en Planificación.
struct ChatGuidedSuccessCard: View {
    let state: ChatGuidedFlowState

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    private var isBudget: Bool { state.kind == .budget }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.title3)
                    .foregroundStyle(theme.onAccent, theme.accent)
                    .accessibilityHidden(true)
                Text(isBudget ? L10n.IAGuiados.doneBudget : L10n.IAGuiados.donePayment)
                    .font(DS.Typography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("chat_guided_success")
            }
            if let message {
                Text(message)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: open) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(isBudget ? L10n.IAGuiados.doneSeeBudget : L10n.IAGuiados.doneSeePayment)
                        .font(DS.Typography.labelSmall)
                    Image(systemName: "arrow.right").font(DS.Typography.labelTiny)
                }
                .padding(.horizontal, DS.Spacing.md)
                .frame(minHeight: 44)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("chat_guided_open")
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(theme.card))
    }

    private var message: String? {
        if isBudget { return state.createdName.map { L10n.PrimerosPasos23.Budget.doneMessage($0) } }
        return state.createdDueDate.map { L10n.PrimerosPasos23.Payment.doneMessage(ScheduledPaymentDateText.dayMonthLong($0)) }
    }

    private func open() {
        guard let id = state.createdID else { return }
        DS.Haptic.selection()
        dismiss()
        if isBudget {
            BudgetAlertRouting.shared.request(id)
            RouterEntryGate.shared.submit(.navigate(.budgets))
        } else {
            AlertDeepLinkTarget.scheduledPayment.request(id)
            RouterEntryGate.shared.submit(.navigate(.scheduledPayments))
        }
    }
}
