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
    @State private var removedSubcategories: Set<UUID> = []
    @State private var budgetStart = Date.now
    @State private var budgetEnd = Date.now
    /// «Cada N días / semanas / meses».
    @State private var everyCount = 2
    @State private var everyUnit: ChatGuidedFrequency = .weekly
    @State private var pickedAccounts: [PersistentIdentifier] = []
    @State private var pickedTags: [PersistentIdentifier] = []
    @State private var noteText = ""
    @State private var budgetNameText = ""
    @State private var endDateValue = Date.now
    /// Mientras iOS contesta el permiso de avisos, el segundo toque no contesta dos veces.
    @State private var isAskingPermission = false
    @FocusState private var amountFocused: Bool
    @FocusState private var nameFocused: Bool
    @FocusState private var dayFocused: Bool
    @FocusState private var noteFocused: Bool

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
            // Cuenta, categoría y favorito tienen su propia tarjeta, con el mismo molde.
            if Self.isGroupKind(state.kind) {
                ChatGuidedGroupFlowCard(messageID: messageID, state: state, viewModel: viewModel)
            } else if Self.hasOwnCard(state.kind) {
                ChatGuidedCreateFlowCard(messageID: messageID, state: state, viewModel: viewModel)
            } else {
                inProgress
            }
        }
    }

    static func hasOwnCard(_ kind: ChatGuidedKind) -> Bool {
        kind == .account || kind == .category || kind == .favorite
    }

    /// Crear un grupo, la deuda de antes y el gasto de grupo: su tarjeta es `ChatGuidedGroupFlowCard`.
    static func isGroupKind(_ kind: ChatGuidedKind) -> Bool {
        kind == .group || kind == .groupOpeningBalance || kind == .groupExpense
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
            if state.step.isAdvancedOption {
                Button(G.skip) { answer { _ in } }
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(.thAccentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(isAskingPermission)
                    .accessibilityIdentifier("chat_guided_skip")
            }
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
        case .account, .category, .favorite, .group, .groupOpeningBalance, .groupExpense:
            EmptyView()
        }
    }

    // MARK: - La pregunta

    private var questionTitle: String {
        switch state.step {
        case .categories: G.budgetCategoriesQuestion
        case .subcategories: B.subcategoriesQuestion
        case .period: B.periodQuestion
        case .dates: B.datesQuestion
        case .amount:
            if state.kind == .scheduledPayment { G.paymentAmountQuestion } else {
                switch answers.period {
                case .weekly: B.limitQuestionWeekly
                case .yearly: B.limitQuestionYearly
                case .once: B.limitQuestionOnce
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
            case .daily: G.paymentWhenStart
            case .monthly, nil: G.paymentWhenMonthly
            }
        case .account: G.paymentAccountQuestion
        case .subcategory: G.paymentSubcategoryQuestion
        case .advanced: G.advancedQuestion
        case .budgetName: G.budgetNameQuestion
        case .budgetAlerts: B.alertQuestion
        case .budgetAccounts: G.budgetAccountsQuestion
        case .budgetTags: G.budgetTagsQuestion
        case .budgetShared: G.budgetSharedQuestion
        case .budgetPanel, .paymentPanel: Plan.panelQuestion
        case .paymentSubscription: G.paymentSubscriptionQuestion
        case .paymentReminder: Pay.reminderQuestion
        case .paymentEnd: G.paymentEndQuestion
        case .paymentNote: G.paymentNoteQuestion
        case .paymentTags: G.paymentTagsQuestion
        case .confirm, .done: G.confirmQuestion
        // Los de cuenta, categoría y favorito los pinta `ChatGuidedCreateFlowCard`.
        default: G.confirmQuestion
        }
    }

    private var questionDetail: String? {
        switch state.step {
        case .categories: G.budgetCategoriesSubtitle
        case .subcategories: B.subcategoriesSubtitle
        case .period: B.periodSubtitle
        case .dates: B.datesSubtitle
        case .amount:
            if state.kind == .budget {
                budgetAverage > 0 ? G.budgetAmountAverage(money(budgetAverage)) : B.limitRoundNumber
            } else { nil }
        case .suggestion: G.paymentSuggestionSubtitle
        case .name: G.paymentNameSubtitle
        case .advanced: G.advancedSubtitle
        case .budgetName: data.map { G.budgetNameSubtitle(ChatGuidedCreator.suggestedBudgetName(suggestedNameAnswers, data: $0)) }
        case .budgetAlerts: B.alertSubtitle
        case .budgetAccounts: G.budgetAccountsSubtitle
        case .budgetTags: G.budgetTagsSubtitle
        case .budgetPanel: B.panelSubtitle
        case .paymentPanel: Pay.panelSubtitle
        case .paymentSubscription: Pay.isSubscriptionHint
        case .paymentReminder: Pay.reminderSubtitle
        case .confirm: G.confirmSubtitle
        default: nil
        }
    }

    // MARK: - Las respuestas

    @ViewBuilder
    private var dock: some View {
        switch state.step {
        case .categories: categoriesDock
        case .subcategories: subcategoriesDock
        case .period: periodDock
        case .dates: budgetDatesDock
        case .amount: amountDock
        case .currency: currencyDock
        case .suggestion: suggestionDock
        case .name: nameDock
        case .frequency: frequencyDock
        case .when: whenDock
        case .account: accountDock
        case .subcategory: subcategoryDock
        case .advanced: advancedDock
        case .budgetName: budgetNameDock
        case .budgetAlerts: budgetAlertsDock
        case .budgetAccounts: accountsPickerDock
        case .budgetTags, .paymentTags: tagsPickerDock
        case .budgetShared:
            yesNoDock(yes: G.budgetSharedYes, no: G.budgetSharedNo, current: answers.includeSharedExpenses ?? true,
                      id: "chat_guided_shared") { value in answer { $0.includeSharedExpenses = value } }
        case .budgetPanel, .paymentPanel:
            yesNoDock(yes: Plan.panelYes, no: Plan.panelNo, current: answers.showsInPanel ?? false,
                      id: "chat_guided_panel") { value in answer { $0.showsInPanel = value } }
        case .paymentSubscription:
            yesNoDock(yes: G.paymentSubscriptionYes, no: G.paymentSubscriptionNo, current: answers.isSubscription,
                      id: "chat_guided_subscription") { value in answer { $0.isSubscription = value } }
        case .paymentReminder: reminderDock
        case .paymentEnd: endDateDock
        case .paymentNote: noteDock
        case .confirm: confirmDock
        case .done: EmptyView()
        default: EmptyView()
        }
    }

    private var categoriesDock: some View {
        VStack(spacing: DS.Spacing.md) {
            TutorialOptionButton(title: B.scopeAll, subtitle: B.scopeAllHint, icon: "chart.pie.fill",
                                 id: "chat_guided_all_expenses") {
                answer(clearing: [.categories, .subcategories]) {
                    $0.allExpenses = true
                    $0.categoryIDs = []
                    $0.removedSubcategoryIDs = nil
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
                let unchanged = picked == answers.categoryIDs && answers.allExpenses == false
                answer(clearing: unchanged ? [.categories] : [.categories, .subcategories]) {
                    $0.allExpenses = false
                    $0.categoryIDs = picked
                    // Otras categorías: «¿Algo que no quieras contar?» se vuelve a preguntar.
                    if !unchanged { $0.removedSubcategoryIDs = nil }
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
            (.once, B.periodOnce, B.periodOnceHint),
        ]
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(options, id: \.0) { period, title, hint in
                TutorialOptionButton(title: title, subtitle: hint, highlighted: period == .monthly,
                                     id: "chat_guided_period_\(period.rawValue)") {
                    answer(clearing: [.period]) {
                        $0.period = period
                        // Las fechas solo valen para «Una sola vez»: elegirla (también desde «Cambiar») las pregunta.
                        $0.budgetStart = nil
                        $0.budgetEnd = nil
                    }
                }
            }
        }
    }

    // MARK: ¿Algo que no quieras contar? y fechas

    private var subcategoriesDock: some View {
        let chosen = answers.categoryIDs.compactMap { data?.category($0) }
        return VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ForEach(chosen) { category in
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Label {
                        Text(category.name).font(DS.Typography.subheadline.weight(.semibold))
                    } icon: {
                        Circle().fill(Color(hex: category.colorHex)).frame(width: 10, height: 10)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.xs),
                                             count: TutorialGridColumns.count(4, dynamicTypeSize: dynamicTypeSize)),
                              spacing: DS.Spacing.sm) {
                        ForEach(category.subcategories) { sub in
                            TutorialSubcategoryCircle(
                                name: sub.name, icon: sub.icon, color: Color(hex: category.colorHex),
                                isOn: !removedSubcategories.contains(sub.id), id: "chat_guided_subcategory_chip"
                            ) {
                                if removedSubcategories.contains(sub.id) {
                                    removedSubcategories.remove(sub.id)
                                } else {
                                    removedSubcategories.insert(sub.id)
                                }
                            }
                        }
                    }
                }
            }
            YalaPrimaryButton(L10n.Action.continueAction) {
                let removed = Array(removedSubcategories)
                answer(clearing: [.subcategories]) { $0.removedSubcategoryIDs = removed }
            }
            .disabled(!FirstBudgetFlowLogic.canContinueSubcategories(
                scope: .categories, chosen: chosen.map(\.subcategoryIDs), removed: removedSubcategories))
            .accessibilityIdentifier("chat_guided_subcategories_continue")
        }
    }

    private var budgetDatesDock: some View {
        VStack(spacing: DS.Spacing.md) {
            VStack(spacing: 0) {
                DatePicker(B.datesFrom, selection: $budgetStart, displayedComponents: .date)
                    .padding(DS.Spacing.md)
                    .accessibilityIdentifier("chat_guided_dates_from")
                Divider()
                DatePicker(B.datesTo, selection: $budgetEnd, in: budgetStart..., displayedComponents: .date)
                    .padding(DS.Spacing.md)
                    .accessibilityIdentifier("chat_guided_dates_to")
            }
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
            YalaPrimaryButton(L10n.Action.continueAction) {
                let calendar = Calendar.current
                let start = calendar.startOfDay(for: budgetStart)
                let end = calendar.startOfDay(for: max(budgetEnd, budgetStart))
                answer { 
                    $0.budgetStart = start
                    $0.budgetEnd = end
                }
            }
            .accessibilityIdentifier("chat_guided_dates_continue")
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
            ForEach([ChatGuidedFrequency.monthly, .weekly, .daily, .yearly, .once], id: \.self) { frequency in
                TutorialOptionButton(title: frequencyTitle(frequency), highlighted: frequency == .monthly,
                                     id: "chat_guided_frequency_\(frequency.rawValue)") {
                    chooseFrequency(frequency, interval: 1)
                }
            }
            everyRow
        }
    }

    /// «Cada cierto tiempo»: cada N días, semanas o meses, en la misma pregunta.
    private var everyRow: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(G.paymentEveryTitle).font(DS.Typography.body.weight(.semibold))
                Text(G.paymentEverySubtitle).font(DS.Typography.caption).foregroundStyle(.secondary)
            }
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach([(ChatGuidedFrequency.daily, G.paymentEveryDays), (.weekly, G.paymentEveryWeeks),
                         (.monthly, G.paymentEveryMonths)], id: \.0) { unit, title in
                    TutorialChip(title: title, isOn: everyUnit == unit, id: "chat_guided_every_\(unit.rawValue)") {
                        everyUnit = unit
                    }
                }
            }
            HStack(spacing: DS.Spacing.sm) {
                Stepper(value: $everyCount, in: 2...99) {
                    Text(everyText)
                        .font(DS.Typography.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityLabel(G.paymentEveryCount)
                .accessibilityValue(everyText)
                .accessibilityIdentifier("chat_guided_every_count")
                TutorialSendButton(enabled: true, id: "chat_guided_every_send") {
                    chooseFrequency(everyUnit, interval: everyCount)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
    }

    private var everyText: String {
        switch everyUnit {
        case .daily: L10n.UXL10.cadenceDaily(interval: everyCount)
        case .weekly: L10n.UXL10.cadenceWeekly(interval: everyCount)
        default: G.paymentEveryMonthsCount(everyCount)
        }
    }

    /// Elegir la frecuencia (también la misma, desde «Cambiar») vuelve a preguntar el día.
    private func chooseFrequency(_ frequency: ChatGuidedFrequency, interval: Int) {
        answer(clearing: [.frequency, .day]) {
            $0.frequency = frequency
            $0.interval = interval > 1 ? interval : nil
            $0.dayOfMonth = nil
            $0.weekday = nil
            $0.date = nil
            if frequency == .once { $0.endDate = nil }
        }
    }

    @ViewBuilder
    private var whenDock: some View {
        switch answers.frequency {
        case .weekly: weekdayDock
        case .yearly, .once, .daily: dateDock
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

    // MARK: - Opciones avanzadas

    private var advancedDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            TutorialOptionButton(title: G.advancedNo, icon: "checkmark", highlighted: true, id: "chat_guided_advanced_no") {
                answerAdvanced(false)
            }
            TutorialOptionButton(title: G.advancedYes, icon: "slider.horizontal.3", id: "chat_guided_advanced_yes") {
                answerAdvanced(true)
            }
        }
    }

    private var budgetNameDock: some View {
        let trimmed = budgetNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: DS.Spacing.sm) {
            TextField("", text: $budgetNameText, prompt: Text(B.namePlaceholder).foregroundStyle(.tertiary))
                .font(DS.Typography.body)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { if !trimmed.isEmpty { answerBudgetName(trimmed) } }
                .padding(.horizontal, DS.Spacing.md)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                .accessibilityLabel(G.rowName)
                .accessibilityIdentifier("chat_guided_budget_name")
            TutorialSendButton(enabled: !trimmed.isEmpty, id: "chat_guided_budget_name_send") {
                answerBudgetName(trimmed)
            }
        }
    }

    private var budgetAlertsDock: some View {
        let current = answers.budgetAlert
        return VStack(spacing: DS.Spacing.sm) {
            TutorialOptionButton(title: B.alertAt75, subtitle: B.alertAt75Hint, highlighted: current == .at75And100,
                                 id: "chat_guided_alert_75") { chooseAlert(.at75And100) }
            TutorialOptionButton(title: B.alertAt100, highlighted: current == .at100, id: "chat_guided_alert_100") {
                chooseAlert(.at100)
            }
            TutorialOptionButton(title: Plan.noThanks, highlighted: current == ChatGuidedBudgetAlert.none,
                                 id: "chat_guided_alert_none") { chooseAlert(.none) }
        }
        .disabled(isAskingPermission)
    }

    private var reminderDock: some View {
        let current = answers.reminder
        let options: [(ChatGuidedReminder, String)] = [
            (.threeDaysBefore, Pay.reminderThreeDays), (.oneDayBefore, Pay.reminderOneDay),
            (.sameDay, Pay.reminderSameDay), (.none, Plan.noThanks),
        ]
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(options, id: \.0) { reminder, title in
                TutorialOptionButton(title: title, highlighted: current == reminder,
                                     id: "chat_guided_reminder_\(reminder.rawValue)") { chooseReminder(reminder) }
            }
        }
        .disabled(isAskingPermission)
    }

    /// Varias cuentas a la vez; ninguna = todas.
    private var accountsPickerDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(data?.budgetAccounts ?? []) { account in
                    TutorialChip(title: account.name, isOn: pickedAccounts.contains(account.id),
                                 id: "chat_guided_pick_account") { togglePicked(account.id, in: &pickedAccounts) }
                }
            }
            YalaPrimaryButton(L10n.Action.continueAction) {
                let picked = pickedAccounts
                answer { $0.accountIDs = picked.isEmpty ? nil : picked }
            }
            .accessibilityIdentifier("chat_guided_pick_accounts_continue")
        }
    }

    /// Varias etiquetas a la vez; ninguna = sin filtro (presupuesto) o sin etiquetas (pago).
    private var tagsPickerDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(data?.tags ?? []) { tag in
                    TutorialChip(title: tag.name, isOn: pickedTags.contains(tag.id), id: "chat_guided_pick_tag") {
                        togglePicked(tag.id, in: &pickedTags)
                    }
                }
            }
            YalaPrimaryButton(L10n.Action.continueAction) {
                let picked = pickedTags
                answer { $0.tagIDs = picked.isEmpty ? nil : picked }
            }
            .accessibilityIdentifier("chat_guided_pick_tags_continue")
        }
    }

    private func yesNoDock(yes: String, no: String, current: Bool, id: String,
                           choose: @escaping (Bool) -> Void) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            TutorialOptionButton(title: yes, highlighted: current, id: "\(id)_yes") { choose(true) }
            TutorialOptionButton(title: no, highlighted: !current, id: "\(id)_no") { choose(false) }
        }
    }

    private var endDateDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            TutorialOptionButton(title: G.paymentEndNever, icon: "infinity", highlighted: answers.endDate == nil,
                                 id: "chat_guided_end_never") { answer { $0.endDate = nil } }
            DatePicker(G.paymentEndQuestion, selection: $endDateValue,
                       in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                .labelsHidden()
                .accessibilityLabel(G.paymentEndQuestion)
                .accessibilityIdentifier("chat_guided_end_date")
            YalaPrimaryButton(G.paymentEndUntil) {
                let date = Calendar.current.startOfDay(for: endDateValue)
                answer { $0.endDate = date }
            }
            .accessibilityIdentifier("chat_guided_end_until")
        }
    }

    private var noteDock: some View {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: DS.Spacing.sm) {
            TextField("", text: $noteText, prompt: Text(G.paymentNotePlaceholder).foregroundStyle(.tertiary))
                .font(DS.Typography.body)
                .focused($noteFocused)
                .submitLabel(.done)
                .onSubmit { if !trimmed.isEmpty { answer { $0.note = trimmed } } }
                .padding(.horizontal, DS.Spacing.md)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                .accessibilityLabel(G.rowNote)
                .accessibilityIdentifier("chat_guided_note")
            TutorialSendButton(enabled: !trimmed.isEmpty, id: "chat_guided_note_send") {
                answer { $0.note = trimmed }
            }
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
        var rows: [ChatGuidedConfirmRow.Model]
        switch state.kind {
        case .budget:
            let categories = answers.allExpenses == true
                ? B.scopeAll
                : answers.categoryIDs.compactMap { data?.category($0)?.name }.joined(separator: ", ")
            rows = [
                .init(step: .categories, label: G.rowCategories, value: categories,
                      saidByYou: state.prefilled.contains(.categories)),
            ]
            if answers.allExpenses == false {
                rows.append(.init(step: .subcategories, label: G.rowSubcategories, value: subcategoriesValue,
                                  saidByYou: state.prefilled.contains(.subcategories)))
            }
            rows.append(.init(step: .period, label: G.rowPeriod, value: periodTitle(answers.period),
                              saidByYou: state.prefilled.contains(.period)))
            if answers.period == .once {
                rows.append(.init(step: .dates, label: G.rowDates, value: budgetDatesText, saidByYou: false))
            }
            rows += [
                .init(step: .amount, label: G.rowLimit, value: answers.amount.map(money) ?? "—",
                      saidByYou: state.prefilled.contains(.amount)),
                .init(step: .currency, label: G.rowCurrency, value: currencyTitle(currency),
                      saidByYou: state.prefilled.contains(.currency)),
            ]
        case .scheduledPayment:
            rows = [
                .init(step: .name, label: G.rowName, value: answers.paymentName ?? "—",
                      saidByYou: state.prefilled.contains(.name)),
                .init(step: .amount, label: G.rowAmount, value: answers.amount.map(money) ?? "—",
                      saidByYou: state.prefilled.contains(.amount)),
                .init(step: .frequency, label: G.rowWhen, value: cadenceText,
                      saidByYou: state.prefilled.contains(.frequency)),
                .init(step: .account, label: G.rowAccount, value: data?.account(answers.accountID)?.name ?? "—",
                      saidByYou: false),
                .init(step: .subcategory, label: G.rowCategory,
                      value: data?.subcategory(answers.subcategoryID)?.name ?? "—",
                      saidByYou: state.prefilled.contains(.subcategories)),
                .init(step: .currency, label: G.rowCurrency, value: currencyTitle(currency),
                      saidByYou: state.prefilled.contains(.currency)),
            ]
        case .account, .category, .favorite, .group, .groupOpeningBalance, .groupExpense:
            rows = []
        }
        rows.append(.init(step: .advanced, label: G.rowAdvanced,
                          value: answers.wantsAdvanced == true ? G.valueReviewed : G.valueDefaults, saidByYou: false))
        if answers.wantsAdvanced == true {
            rows += ChatGuidedEngine.askedSteps(state.kind, answers: answers)
                .filter(\.isAdvancedOption)
                .compactMap(advancedRow)
        }
        return rows
    }

    private func advancedRow(_ step: ChatGuidedStep) -> ChatGuidedConfirmRow.Model? {
        let value: String
        let label: String
        switch step {
        case .budgetName:
            label = G.rowName
            value = budgetName
        case .budgetAlerts:
            label = G.rowAlerts
            switch answers.budgetAlert ?? (appPreferences.budgetAlertsEnabled ? .at75And100 : .none) {
            case .at75And100: value = G.valueAlert75
            case .at100: value = G.valueAlert100
            case .none: value = G.valueNoAlerts
            }
        case .budgetAccounts:
            label = G.rowAccounts
            let names = (answers.accountIDs ?? []).compactMap { data?.account($0)?.name }
            value = names.isEmpty ? G.valueAll : names.joined(separator: ", ")
        case .budgetTags, .paymentTags:
            label = G.rowTags
            let names = (answers.tagIDs ?? []).compactMap { data?.tag($0)?.name }
            value = names.isEmpty ? G.valueNone : names.joined(separator: ", ")
        case .budgetShared:
            label = G.rowShared
            value = (answers.includeSharedExpenses ?? true) ? G.valueYes : G.valueNo
        case .budgetPanel, .paymentPanel:
            label = G.rowPanel
            value = answers.showsInPanel == true ? G.valueYes : G.valueNo
        case .paymentSubscription:
            label = G.rowSubscription
            value = answers.isSubscription ? G.valueYes : G.valueNo
        case .paymentReminder:
            label = G.rowReminder
            switch answers.reminder ?? .threeDaysBefore {
            case .threeDaysBefore: value = G.valueReminder3
            case .oneDayBefore: value = G.valueReminder1
            case .sameDay: value = G.valueReminderSame
            case .none: value = G.valueNoReminder
            }
        case .paymentEnd:
            label = G.rowEnd
            value = answers.endDate.map { ScheduledPaymentDateText.dayMonthLong($0) } ?? G.paymentEndNever
        case .paymentNote:
            label = G.rowNote
            value = (answers.note ?? "").isEmpty ? G.valueNoNote : (answers.note ?? "")
        default:
            return nil
        }
        return .init(step: step, label: label, value: value, saidByYou: false)
    }

    private var subcategoriesValue: String {
        let total = answers.categoryIDs.reduce(0) { $0 + (data?.category($1)?.subcategoryIDs.count ?? 0) }
        let counted = budgetSubcategoryIDs.count
        return counted >= total ? G.valueAll : G.valueSomeOf(counted, total)
    }

    private var budgetDatesText: String {
        guard let start = answers.budgetStart, let end = answers.budgetEnd else { return "—" }
        return "\(ScheduledPaymentDateText.dayMonthLong(start)) – \(ScheduledPaymentDateText.dayMonthLong(end))"
    }

    // MARK: - Contestar

    private func answer(clearing fields: Set<ChatGuidedField> = [], _ change: (inout ChatGuidedAnswers) -> Void) {
        errorText = nil
        amountFocused = false
        nameFocused = false
        dayFocused = false
        noteFocused = false
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

    private func answerAdvanced(_ wants: Bool) {
        errorText = nil
        viewModel.guidedAdvanced(messageID: messageID, wants: wants)
    }

    private func answerBudgetName(_ name: String) {
        answer { $0.budgetName = name }
    }

    private func togglePicked(_ id: PersistentIdentifier, in list: inout [PersistentIdentifier]) {
        if let index = list.firstIndex(of: id) { list.remove(at: index) } else { list.append(id) }
    }

    /// Un aviso pide el permiso de iOS si nunca se pidió (como Primeros pasos); «No, gracias» no pide nada.
    private func chooseAlert(_ alert: ChatGuidedBudgetAlert) {
        guard !isAskingPermission else { return }
        guard alert != .none else {
            answer { $0.budgetAlert = alert }
            return
        }
        askPermission { allowed in
            answer {
                $0.budgetAlert = alert
                $0.notificationsAllowed = allowed
            }
        }
    }

    private func chooseReminder(_ reminder: ChatGuidedReminder) {
        guard !isAskingPermission else { return }
        guard reminder != .none else {
            answer { $0.reminder = reminder }
            return
        }
        askPermission { allowed in
            answer {
                $0.reminder = reminder
                $0.notificationsAllowed = allowed
            }
        }
    }

    private func askPermission(_ then: @escaping (Bool) -> Void) {
        let step = state.step
        isAskingPermission = true
        Task { @MainActor in
            var allowed = true
            #if DEBUG
            if !UITestHooks.isActive { allowed = await TutorialPermissionMoments.remindMeChosen() }
            #else
            allowed = await TutorialPermissionMoments.remindMeChosen()
            #endif
            isAskingPermission = false
            // Si mientras tanto la tarjeta cambió de pregunta, la respuesta ya no es de esta. Se lee el estado vivo del
            // hilo: `state` es la copia que capturó esta tarea.
            guard viewModel.guidedState(messageID: messageID)?.step == step else { return }
            then(allowed)
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
        guard data == nil, state.status == .inProgress, !Self.hasOwnCard(state.kind) else { return }
        var loaded = ChatGuidedDataSource.load(state.kind, context: modelContext, mainCurrency: mainCurrency)
        // La subcategoría que dijo la frase («la luz») puede no estar entre las seis de Primeros pasos: se añade.
        if let id = answers.subcategoryID, loaded.subcategory(id) == nil,
           let subcategory = modelContext.model(for: id) as? Subcategory, !subcategory.isDeleted {
            loaded.paymentSubcategories.insert(ChatGuidedDataSource.option(subcategory), at: 0)
        }
        data = loaded
    }

    /// Las respuestas sin el nombre elegido: el que se propone.
    private var suggestedNameAnswers: ChatGuidedAnswers {
        var plain = answers
        plain.budgetName = nil
        return plain
    }

    /// Lo escrito en los campos empieza con la respuesta que ya hay (al volver atrás o al «Cambiar»).
    private func syncFields() {
        amountText = answers.amount.map { $0.rounded() == $0 ? String(Int($0)) : String(format: "%.2f", $0) } ?? ""
        variableAmount = answers.isVariableAmount
        nameText = answers.paymentName ?? ""
        pickedCategories = answers.categoryIDs
        dateValue = answers.date ?? .now
        removedSubcategories = Set(answers.removedSubcategoryIDs ?? [])
        budgetStart = answers.budgetStart ?? .now
        budgetEnd = answers.budgetEnd ?? Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
        if let frequency = answers.frequency, answers.effectiveInterval > 1, frequency != .yearly {
            everyUnit = frequency
            everyCount = answers.effectiveInterval
        }
        pickedAccounts = answers.accountIDs ?? []
        pickedTags = answers.tagIDs ?? []
        noteText = answers.note ?? ""
        budgetNameText = answers.budgetName ?? ""
        endDateValue = answers.endDate ?? Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
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
        case .daily: L10n.UXL10.cadenceDaily(interval: 1)
        }
    }

    private func suggestionCaption(_ suggestion: ChatGuidedData.PaymentSuggestion) -> String {
        let amount = appPreferences.currency(suggestion.amount, currencyCode: suggestion.currencyCode,
                                             isEstimate: suggestion.isVariableAmount)
        return "\(amount) · \(frequencyTitle(suggestion.frequency))"
    }

    private var cadenceText: String {
        guard let frequency = answers.frequency else { return "—" }
        let every = answers.effectiveInterval
        switch frequency {
        case .monthly:
            return L10n.UXL10.cadenceMonthly(interval: every, day: answers.dayOfMonth ?? 1)
        case .weekly:
            let symbols = Calendar.current.standaloneWeekdaySymbols
            let day = answers.weekday.map { symbols[max(0, min(6, $0 - 1))] } ?? ""
            return [L10n.UXL10.cadenceWeekly(interval: every), day].filter { !$0.isEmpty }.joined(separator: " · ")
        case .yearly:
            return L10n.UXL10.cadenceYearly(interval: every, date: ScheduledPaymentDateText.dayMonthLong(answers.date ?? .now))
        case .once:
            return ScheduledPaymentDateText.dayMonthLong(answers.date ?? .now)
        case .daily:
            return L10n.UXL10.cadenceDaily(interval: every)
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
                                                currencyCode: currency, transactions: data.transactions,
                                                startDate: answers.budgetStart, endDate: answers.budgetEnd)
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
        let calendar = Calendar.current
        let date = answers.date ?? .now
        guard frequency.isRecurring else { return calendar.startOfDay(for: date) }
        // La misma cuenta que el editor, con «cada N» y la fecha de inicio de «cada N días».
        return ScheduledPaymentEditorViewModel.firstDueDate(
            start: calendar.startOfDay(for: frequency == .daily ? date : .now),
            recurrenceType: frequency.recurrenceType,
            recurrenceInterval: answers.effectiveInterval,
            dayOfMonth: frequency == .monthly ? answers.dayOfMonth : nil,
            weekdays: frequency == .weekly ? String(answers.weekday ?? 2) : "",
            yearlyMonth: frequency == .yearly ? calendar.component(.month, from: date) : nil,
            yearlyDay: frequency == .yearly ? calendar.component(.day, from: date) : nil,
            endDate: nil
        )
    }

    private var paymentSummary: String? {
        guard let amount = answers.amount, let frequency = answers.frequency, let due = paymentDue else { return nil }
        let amountText = appPreferences.currency(amount, currencyCode: currency, forceFullPrecision: true,
                                                 isEstimate: answers.isVariableAmount)
        let dueDay = Calendar.current.isDateInToday(due) ? L10n.UXL10.today : ScheduledPaymentDateText.dayMonthLong(due)
        guard frequency.isRecurring else { return L10n.UXL10.summaryOnce(amountText, dueDay) }
        return L10n.UXL10.summaryRecurring(amountText, cadenceText, dueDay)
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

/// Lo creado, con acceso directo. El presupuesto y el pago cierran el chat y se abren en Planificación; la cuenta, en su
/// ficha del Panel. Las categorías y los favoritos abren su lista de Ajustes en una hoja encima del chat.
struct ChatGuidedSuccessCard: View {
    let state: ChatGuidedFlowState

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences
    @State private var listSheet: ChatGuidedCreatedList?
    @State private var inviteTarget: ChatGuidedInviteTarget?

    private typealias G = L10n.IAGuiados

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.title3)
                    .foregroundStyle(theme.onAccent, theme.accent)
                    .accessibilityHidden(true)
                Text(title)
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
            if state.kind == .group, state.createdZoneID != nil {
                YalaPrimaryButton(G.doneInvite, action: openInvite)
                    .accessibilityIdentifier("chat_guided_invite")
            }
            Button(action: open) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(openTitle)
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
        .sheet(item: $listSheet) { list in ChatGuidedCreatedListSheet(list: list) }
        .sheet(item: $inviteTarget) { target in
            GroupCreatedInviteSheet(group: target.group, members: target.members)
        }
    }

    private var isSubcategories: Bool { state.answers.categoryMode == .subcategories }

    private var title: String {
        switch state.kind {
        case .budget: G.doneBudget
        case .scheduledPayment: G.donePayment
        case .account: G.doneAccount
        case .category: isSubcategories ? G.doneSubcategories : G.doneCategory
        case .favorite: G.doneFavorite
        case .group: G.doneGroup
        case .groupOpeningBalance: G.doneDebt
        case .groupExpense: G.doneExpense
        }
    }

    private var openTitle: String {
        switch state.kind {
        case .budget: G.doneSeeBudget
        case .scheduledPayment: G.doneSeePayment
        case .account: G.doneSeeAccount
        case .category: G.doneSeeCategories
        case .favorite: G.doneSeeFavorites
        case .group, .groupOpeningBalance, .groupExpense: G.doneSeeGroup
        }
    }

    private var message: String? {
        switch state.kind {
        case .budget: return state.createdName.map { L10n.PrimerosPasos23.Budget.doneMessage($0) }
        case .scheduledPayment:
            return state.createdDueDate.map { L10n.PrimerosPasos23.Payment.doneMessage(ScheduledPaymentDateText.dayMonthLong($0)) }
        case .account: return state.createdName.map { G.doneAccountMessage($0) }
        case .category:
            // En subcategorías, la primera nueva es la que se usa al registrar.
            let name = isSubcategories ? state.answers.subcategoryNames?.first : state.createdName
            return name.map { G.doneCategoryMessage($0) }
        case .favorite: return G.doneFavoriteMessage
        case .group: return G.doneGroupMessage
        case .groupOpeningBalance: return state.createdName.map { G.doneDebtMessage($0) }
        case .groupExpense:
            return state.answers.amount.map { amount in
                G.doneExpenseMessage(appPreferences.currency(amount, currencyCode: state.answers.currencyCode ?? ""),
                                     state.createdName ?? "")
            }
        }
    }

    private func open() {
        DS.Haptic.selection()
        switch state.kind {
        case .category:
            listSheet = .categories
            return
        case .favorite:
            listSheet = .favorites
            return
        case .group, .groupOpeningBalance, .groupExpense:
            // El grupo, por el mismo camino que abrir uno desde un aviso (`.groupDetail` con su zona).
            guard let zoneID = state.createdZoneID else { return }
            dismiss()
            RouterEntryGate.shared.submit(.navigate(.groupDetail(groupID: zoneID)))
            return
        case .budget, .scheduledPayment, .account:
            break
        }
        guard let id = state.createdID else { return }
        dismiss()
        switch state.kind {
        case .budget:
            BudgetAlertRouting.shared.request(id)
            RouterEntryGate.shared.submit(.navigate(.budgets))
        case .scheduledPayment:
            AlertDeepLinkTarget.scheduledPayment.request(id)
            RouterEntryGate.shared.submit(.navigate(.scheduledPayments))
        case .account:
            // La ficha de la cuenta en el Panel, por el mismo camino que el aviso de la tarjeta (`shortcutID`).
            AlertDeepLinkTarget.account.request(id)
            RouterEntryGate.shared.submit(.navigate(.panel))
        case .category, .favorite, .group, .groupOpeningBalance, .groupExpense:
            break
        }
    }

    /// Un grupo recién creado: la hoja «Invitar» de siempre, con su dueño como único miembro.
    private func openInvite() {
        DS.Haptic.selection()
        guard let zoneID = state.createdZoneID else { return }
        do {
            let groups = try modelContext.fetch(FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneID }))
            guard let group = groups.first(where: { !$0.isHiddenForAll }) else { return }
            let members = try GroupService.shared.fetchMembers(for: group, context: modelContext).filter(\.isActive)
            inviteTarget = ChatGuidedInviteTarget(group: group, members: members)
        } catch {
            #if DEBUG
            print("ChatGuidedSuccessCard: Error: loading the new group: \(error)")
            #endif
        }
    }
}

/// El grupo recién creado para la hoja «Invitar».
struct ChatGuidedInviteTarget: Identifiable {
    let id = UUID()
    let group: SplitGroup
    let members: [SplitMember]
}

/// La lista de Ajustes que abre «Ver tus categorías» o «Ver tus favoritos».
enum ChatGuidedCreatedList: String, Identifiable {
    case categories
    case favorites

    var id: String { rawValue }
}

/// La lista de Ajustes en una hoja encima del chat: lo creado se ve, se edita con su formulario y se vuelve al chat.
struct ChatGuidedCreatedListSheet: View {
    let list: ChatGuidedCreatedList

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch list {
                case .categories: CategoriesSettingsListView()
                case .favorites: FavoritesListView(mode: .manage)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.IAGuiados.closeSheet) { dismiss() }
                        .accessibilityIdentifier("chat_guided_list_close")
                }
            }
        }
    }
}
