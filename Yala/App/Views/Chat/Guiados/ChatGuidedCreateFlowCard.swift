//
//  ChatGuidedCreateFlowCard.swift
//  Yala
//
//  La tarjeta de los guiados de cuenta, categoría y favorito dentro del hilo de Yala IA. Mismo molde que
//  `ChatGuidedFlowCard` (cabecera con sus puntos, lo creado llenándose arriba, la pregunta, sus respuestas, «Revisa antes
//  de crear» con «Cambiar» en cada fila) y las piezas de Primeros pasos. La tarjeta no decide nada: cada toque contesta
//  por el ViewModel del chat y el motor elige la siguiente pregunta.
//

import SwiftData
import SwiftUI

struct ChatGuidedCreateFlowCard: View {
    let messageID: UUID
    let state: ChatGuidedFlowState
    @Bindable var viewModel: ChatAssistantViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var data: ChatGuidedData?
    @State private var takenCategoryNames: Set<String> = []
    @State private var errorText: String?
    @State private var nameText = ""
    @State private var editsName = false
    @State private var amountText = ""
    @State private var noteText = ""
    @State private var numberText = ""
    @State private var subcategoryText = ""
    @State private var pickedCurrencies: [String] = []
    /// El saldo que se va escribiendo, una fila por moneda de la cuenta.
    @State private var balanceRows: [BalanceRow] = []
    @State private var pickedNames: [String] = []
    @State private var pickedNeeds: [String: String] = [:]
    @State private var pickedTags: [PersistentIdentifier] = []
    @State private var iconValue = "tag.fill"
    @State private var colorValue = ChatGuidedCategoryLook.colors[0]
    @State private var showsIconPicker = false
    @State private var showsCurrencyPicker = false
    @State private var currencyPick: CurrencyCode = .usd
    @State private var showsOtherSubcategory = false
    @State private var otherSubcategory: Subcategory?
    @State private var isAskingPermission = false
    @FocusState private var focused: Field?
    @FocusState private var amountFieldFocused: Bool

    private enum Field: Hashable { case name, amount, note, number, subcategory, balance(String) }

    struct BalanceRow: Identifiable, Equatable {
        /// El código de la moneda.
        let id: String
        var text = ""
        var isNegative = false
    }

    private typealias G = L10n.IAGuiados
    private typealias T = L10n.PrimerosPasos23.Account
    private typealias Logic = FirstAccountFlowLogic

    private var answers: ChatGuidedAnswers { state.answers }
    private var mainCurrency: String { CurrencyDefaults.currentPreferred }

    var body: some View {
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
        .task(id: state.id) { loadIfNeeded() }
        .onAppear(perform: syncFields)
        .onChange(of: state.step) { _, _ in syncFields() }
        .sheet(isPresented: $showsCurrencyPicker) {
            CurrencyPickerSheet(selectedCurrency: $currencyPick)
        }
        .onChange(of: currencyPick) { _, code in addCurrency(code.rawValue) }
        .sheet(isPresented: $showsIconPicker) {
            IconColorPickerSheet(selectedIconName: $iconValue, selectedColorHex: $colorValue)
        }
        .sheet(isPresented: $showsOtherSubcategory, onDismiss: applyOtherSubcategory) {
            SubcategorySelectorSheet(selectedSubcategory: $otherSubcategory,
                                     transactionType: favoriteType == .income ? .income : .expense)
        }
    }

    // MARK: - Cabecera

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
            Image(systemName: Self.headerIcon(state.kind))
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(theme.accentText)
                .accessibilityHidden(true)
            Text(headerTitle)
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

    static func headerIcon(_ kind: ChatGuidedKind) -> String {
        switch kind {
        case .account: "building.columns.fill"
        case .category: "square.grid.2x2.fill"
        case .favorite: "star.fill"
        case .budget: "chart.pie.fill"
        case .scheduledPayment: "calendar.badge.clock"
        case .group, .groupOpeningBalance, .groupExpense: ChatGuidedGroupFlowCard.headerIcon(kind)
        }
    }

    private var headerTitle: String {
        switch state.kind {
        case .account: G.accountHeader
        case .category: answers.categoryMode == .subcategories ? G.subcategoriesHeader : G.categoryHeader
        case .favorite: G.favoriteHeader
        case .budget: G.budgetHeader
        case .scheduledPayment: G.paymentHeader
        case .group, .groupOpeningBalance, .groupExpense: ChatGuidedGroupFlowCard.headerTitle(state.kind)
        }
    }

    // MARK: - Lo creado, llenándose arriba

    @ViewBuilder
    private var preview: some View {
        switch state.kind {
        case .account:
            if accountKind != nil {
                FirstAccountCardPreview(draft: accountDraft, suggestedName: suggestedAccountName)
            }
        case .category:
            if answers.categoryMode != nil, categoryPreviewName != nil || !currentNames.isEmpty {
                categoryPreview
            }
        case .favorite:
            if favoriteType != nil { favoritePreview }
        case .budget, .scheduledPayment, .group, .groupOpeningBalance, .groupExpense:
            EmptyView()
        }
    }

    private var categoryPreview: some View {
        let parent = data?.parent(answers.parentCategoryID)
        let icon = answers.categoryMode == .subcategories ? parent?.icon ?? "tag.fill" : (answers.categoryIcon ?? iconValue)
        let color = answers.categoryMode == .subcategories
            ? parent?.colorHex ?? ChatGuidedCategoryLook.colors[0] : (answers.categoryColorHex ?? colorValue)
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.onFill(Color(hex: color)))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(hex: color)))
                Text(categoryPreviewName ?? G.categoryHeader)
                    .font(DS.Typography.headline)
                    .foregroundStyle(categoryPreviewName == nil ? .secondary : .primary)
            }
            if !currentNames.isEmpty {
                FlowLayout(spacing: DS.Spacing.xs) {
                    ForEach(currentNames, id: \.self) { name in
                        Text(name)
                            .font(DS.Typography.caption.weight(.semibold))
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(Capsule().fill(Color(hex: color).opacity(0.15)))
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(theme.card))
        .accessibilityElement(children: .combine)
    }

    private var favoritePreview: some View {
        let subcategory = data?.favoriteSubcategory(answers.subcategoryID)
        let isTransfer = favoriteType == .transfer
        let color = isTransfer ? Color.secondary : subcategory.map { Color(hex: $0.colorHex) } ?? Color.secondary.opacity(0.3)
        let caption = [subcategory?.name, data?.account(answers.accountID)?.name,
                       isTransfer ? data?.account(answers.destinationAccountID).map { "→ \($0.name)" } : nil]
            .compactMap { $0 }.joined(separator: " · ")
        return HStack(spacing: DS.Spacing.md) {
            Image(systemName: isTransfer ? "arrow.left.arrow.right" : subcategory?.icon ?? "star.fill")
                .font(DS.Typography.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(color))
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(answers.favoriteName ?? subcategory?.name ?? G.favoriteHeader)
                    .font(DS.Typography.headline)
                    .foregroundStyle(answers.favoriteName == nil ? .secondary : .primary)
                if !caption.isEmpty {
                    Text(caption).font(DS.Typography.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: DS.Spacing.sm)
            Text(favoriteAmountText)
                .font(DS.Typography.headline)
                .foregroundStyle(answers.favoriteWithoutAmount == true ? .secondary : .primary)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(theme.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: - La pregunta

    private var questionTitle: String {
        switch state.step {
        case .accountKind: G.accountKindQuestion
        case .accountCurrencies: isCard ? T.currencyQuestionCard : T.currencyQuestion
        case .accountName:
            accountKind?.writesOwnName == true || editsName ? T.nameQuestion : T.nameSuggestQuestion(suggestedAccountName)
        case .accountBalance:
            if accountCurrencies.count > 1 { isCard ? G.accountBalanceEachCard : G.accountBalanceEach }
            else { isCard ? T.balanceQuestionCardSingle : T.balanceQuestionSingle }
        case .accountStatementDay: T.statementQuestion
        case .accountPaymentDay: T.paymentQuestion
        case .accountReminder: T.reminderQuestion
        case .accountNumber: G.accountNumberQuestion
        case .accountStats: G.accountStatsQuestion
        case .categoryMode: G.categoryModeQuestion
        case .categoryParent: G.categoryParentQuestion
        case .categoryName: G.categoryNameQuestion
        case .categoryLook: G.categoryLookQuestion
        case .categorySubcategories: G.categorySubcategoriesQuestion(categoryPreviewName ?? G.categoryHeader)
        case .categoryNeeds: G.categoryNeedsQuestion
        case .favoriteType: G.favoriteTypeQuestion
        case .favoriteSubcategory: G.favoriteSubcategoryQuestion
        case .favoriteAccount:
            switch favoriteType {
            case .income: G.favoriteAccountIncomeQuestion
            case .transfer: G.favoriteAccountFromQuestion
            case .expense, nil: G.favoriteAccountQuestion
            }
        case .favoriteDestination: G.favoriteDestinationQuestion
        case .favoriteAmount: G.favoriteAmountQuestion
        case .favoriteName: G.favoriteNameQuestion
        case .favoriteNeed: G.favoriteNeedQuestion
        case .favoriteTags: G.favoriteTagsQuestion
        case .favoriteNote: G.favoriteNoteQuestion
        case .advanced: G.advancedQuestion
        default: G.confirmQuestion
        }
    }

    private var questionDetail: String? {
        switch state.step {
        case .accountKind: G.accountKindSubtitle
        case .accountCurrencies: isCard ? T.currencySubtitleCard : T.currencySubtitle
        case .accountName: accountKind?.writesOwnName == true && !editsName ? T.nameSubtitleOwn : T.nameSubtitle
        case .accountBalance: isCard ? T.balanceSubtitleCard : T.balanceSubtitle
        case .accountStatementDay: T.statementSubtitle
        case .accountPaymentDay: T.paymentSubtitle
        case .accountReminder:
            (answers.accountStatementDay ?? 0) == 0 ? T.reminderSubtitleNoStatement
                : (accountCurrencies.count > 1 ? T.reminderSubtitleEachCurrency : T.reminderSubtitle)
        case .accountNumber: G.accountNumberSubtitle
        case .categoryName: G.categoryNameSubtitle
        case .categoryLook: G.categoryLookSubtitle
        case .categorySubcategories: G.categorySubcategoriesSubtitle
        case .categoryNeeds: G.categoryNeedsSubtitle
        case .favoriteSubcategory: G.favoriteSubcategorySubtitle
        case .favoriteName: G.favoriteNameSubtitle
        case .advanced: G.advancedSubtitle
        case .confirm: G.confirmSubtitle
        default: nil
        }
    }

    // MARK: - Las respuestas

    @ViewBuilder
    private var dock: some View {
        switch state.step {
        case .accountKind: accountKindDock
        case .accountCurrencies: currenciesDock
        case .accountName: accountNameDock
        case .accountBalance: balanceDock
        case .accountStatementDay: dayDock(current: answers.accountStatementDay) { day in
            answer { $0.accountStatementDay = day }
        }
        case .accountPaymentDay: dayDock(current: answers.accountPaymentDay) { day in
            answer { $0.accountPaymentDay = day }
        }
        case .accountReminder: reminderDock
        case .accountNumber: numberDock
        case .accountStats:
            optionPair(yes: G.accountStatsYes, no: G.accountStatsNo, current: answers.accountCountsInReports ?? true,
                       id: "chat_guided_stats") { counts in answer { $0.accountCountsInReports = counts } }
        case .categoryMode: categoryModeDock
        case .categoryParent: parentDock
        case .categoryName: categoryNameDock
        case .categoryLook: lookDock
        case .categorySubcategories: subcategoriesDock
        case .categoryNeeds: needsDock
        case .favoriteType: favoriteTypeDock
        case .favoriteSubcategory: favoriteSubcategoryDock
        case .favoriteAccount: accountsDock(excluding: nil) { id in answer { $0.accountID = id } }
        case .favoriteDestination: accountsDock(excluding: answers.accountID) { id in
            answer { $0.destinationAccountID = id }
        }
        case .favoriteAmount: favoriteAmountDock
        case .favoriteName: favoriteNameDock
        case .favoriteNeed: favoriteNeedDock
        case .favoriteTags: tagsDock
        case .favoriteNote: noteDock
        case .advanced: advancedDock
        case .confirm: confirmDock
        default: EmptyView()
        }
    }

    // MARK: Cuenta

    private var accountKindDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(Logic.Kind.allCases, id: \.self) { kind in
                TutorialOptionButton(
                    title: FirstAccountFlowView.kindTitle(kind), subtitle: FirstAccountFlowView.kindHint(kind),
                    icon: iconName(for: kind.accountType), tint: Color(hex: kind.colorHex),
                    highlighted: accountKind == kind, id: "chat_guided_account_kind_\(kind.rawValue)"
                ) {
                    answer(clearing: [.accountKind]) { $0.accountKind = kind.rawValue }
                }
            }
        }
    }

    private var currenciesDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(currencyOptions, id: \.self) { code in
                    TutorialChip(title: currencyTitle(code), isOn: pickedCurrencies.contains(code),
                                 id: "chat_guided_currency_\(code)") { toggleCurrency(code) }
                }
                if Logic.canAddCurrency(count: pickedCurrencies.count) {
                    TutorialChip(title: T.addCurrency, id: "chat_guided_currency_other") {
                        currencyPick = CurrencyCode(rawValue: pickedCurrencies.first ?? mainCurrency) ?? .usd
                        showsCurrencyPicker = true
                    }
                }
            }
            YalaPrimaryButton(T.continueButton) {
                let picked = Logic.normalizedCurrencies(pickedCurrencies)
                answer(clearing: [.currency]) {
                    $0.accountCurrencies = picked
                    // Lo dicho para una moneda que ya no está se va; lo de las que siguen, se queda.
                    $0.accountBalances = $0.accountBalances?.filter { picked.contains($0.key) }
                    if $0.accountBalances?.isEmpty == true { $0.accountBalances = nil }
                }
            }
            .disabled(pickedCurrencies.isEmpty)
            .accessibilityIdentifier("chat_guided_currencies_continue")
        }
    }

    @ViewBuilder
    private var accountNameDock: some View {
        if accountKind?.writesOwnName == true || editsName {
            textEntry(text: $nameText, prompt: editsName ? T.namePlaceholder
                      : T.nameExample(FirstAccountFlowView.nameExample(for: accountKind)),
                      field: .name, id: "chat_guided_name") { answerAccountName($0) }
        } else {
            VStack(spacing: DS.Spacing.sm) {
                TutorialOptionButton(title: T.nameKeep, highlighted: true, id: "chat_guided_name_keep") {
                    answerAccountName(suggestedAccountName)
                }
                TutorialOptionButton(title: T.nameChange, id: "chat_guided_name_change") {
                    nameText = ""
                    editsName = true
                    errorText = nil
                }
            }
        }
    }

    private var balanceDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach($balanceRows) { $row in
                HStack(spacing: DS.Spacing.sm) {
                    if !isCard {
                        Button {
                            row.isNegative.toggle()
                        } label: {
                            Text(verbatim: row.isNegative ? "−" : "+")
                                .font(DS.Typography.title2.weight(.bold))
                                .foregroundStyle(row.isNegative ? Color.hotPink : Color.primary)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(theme.card))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(row.isNegative ? T.signNegative : T.signPositive)
                        .accessibilityIdentifier("chat_guided_balance_sign_\(row.id)")
                    }
                    HStack(spacing: DS.Spacing.xs) {
                        Text(CurrencyCode(rawValue: row.id)?.symbol ?? row.id)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.secondary)
                        TextField("", text: $row.text, prompt: Text(verbatim: "0.00").foregroundStyle(.tertiary))
                            .font(DS.Typography.title3.weight(.semibold))
                            .amountKeyboard()
                            .focused($focused, equals: .balance(row.id))
                            .accessibilityLabel("\(T.balanceFieldLabel) \(currencyTitle(row.id))")
                            .accessibilityIdentifier("chat_guided_balance_\(row.id)")
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                }
            }
            YalaPrimaryButton(T.continueButton) { answerBalances(zero: false) }
                .disabled(!balancesAreValid)
                .accessibilityIdentifier("chat_guided_balance_continue")
            TutorialOptionButton(title: isCard ? T.oweNothing : T.startAtZero, id: "chat_guided_balance_zero") {
                answerBalances(zero: true)
            }
        }
    }

    private func dayDock(current: Int?, choose: @escaping (Int) -> Void) -> some View {
        let columns = TutorialGridColumns.count(7, dynamicTypeSize: dynamicTypeSize)
        return VStack(spacing: DS.Spacing.md) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.xs), count: columns),
                      spacing: DS.Spacing.xs) {
                ForEach(1...31, id: \.self) { day in
                    Button {
                        DS.Haptic.selection()
                        choose(day)
                    } label: {
                        Text(verbatim: "\(day)")
                            .font(DS.Typography.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .foregroundStyle(current == day ? theme.onAccent : Color.primary)
                            .background(RoundedRectangle(cornerRadius: DS.Radius.md)
                                .fill(current == day ? theme.accent : theme.card))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chat_guided_day_\(day)")
                }
            }
            TutorialOptionButton(title: T.dontKnow, highlighted: current == 0, id: "chat_guided_day_unknown") { choose(0) }
        }
    }

    private var reminderDock: some View {
        let statement = (answers.accountStatementDay ?? 0) == 0 ? nil : answers.accountStatementDay
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(Logic.reminderOptions(statementDay: statement), id: \.self) { lead in
                TutorialOptionButton(title: FirstAccountFlowView.reminderLabel(lead),
                                     highlighted: answers.accountReminderLead == lead,
                                     id: "chat_guided_account_reminder_\(lead)") { chooseReminder(lead) }
            }
            TutorialOptionButton(title: T.noReminder, highlighted: answers.accountReminderLead == -1,
                                 id: "chat_guided_account_reminder_none") { chooseReminder(-1) }
        }
        .disabled(isAskingPermission)
    }

    private var numberDock: some View {
        textEntry(text: $numberText, prompt: "1234", field: .number, id: "chat_guided_account_number",
                  keyboard: .numberPad) { number in
            answer { $0.accountNumber = String(number.prefix(4)) }
        }
    }

    // MARK: Categoría

    private var categoryModeDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            TutorialOptionButton(title: G.categoryModeNew, subtitle: G.categoryModeNewHint, icon: "plus.square.fill",
                                 highlighted: answers.categoryMode == .newCategory, id: "chat_guided_category_new") {
                answer(clearing: [.categoryMode]) { $0.categoryMode = .newCategory }
            }
            TutorialOptionButton(title: G.categoryModeSub, subtitle: G.categoryModeSubHint, icon: "square.grid.2x2",
                                 highlighted: answers.categoryMode == .subcategories, id: "chat_guided_category_sub") {
                answer(clearing: [.categoryMode]) { $0.categoryMode = .subcategories }
            }
        }
    }

    private var parentDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(data?.categoryParents ?? []) { parent in
                TutorialOptionButton(title: parent.name, icon: parent.icon, tint: Color(hex: parent.colorHex),
                                     highlighted: answers.parentCategoryID == parent.id, id: "chat_guided_parent") {
                    answer(clearing: [.parentCategory]) { $0.parentCategoryID = parent.id }
                }
            }
        }
    }

    private var categoryNameDock: some View {
        textEntry(text: $nameText, prompt: G.categoryNamePlaceholder, field: .name, id: "chat_guided_name") { name in
            guard !takenCategoryNames.contains(ChatGuidedDataSource.foldedName(name)) else {
                errorText = G.categoryNameTaken
                return
            }
            // El ícono se propone por el nombre mientras la persona no haya elegido otro.
            if answers.categoryIcon == nil { iconValue = ChatGuidedCategoryLook.suggestedIcon(for: name) }
            answer(clearing: [.name]) { $0.categoryName = name }
        }
    }

    private var lookDock: some View {
        let icons = [ChatGuidedCategoryLook.suggestedIcon(for: answers.categoryName ?? "")]
            + ChatGuidedCategoryLook.icons
        var seen: Set<String> = []
        let unique = icons.filter { seen.insert($0).inserted }
        let columns = TutorialGridColumns.count(6, dynamicTypeSize: dynamicTypeSize)
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.xs), count: columns),
                      spacing: DS.Spacing.xs) {
                ForEach(unique, id: \.self) { icon in
                    Button {
                        DS.Haptic.selection()
                        iconValue = icon
                    } label: {
                        Image(systemName: icon)
                            .font(DS.Typography.headline)
                            .foregroundStyle(iconValue == icon ? theme.onFill(Color(hex: colorValue)) : Color.primary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: DS.Radius.md)
                                .fill(iconValue == icon ? Color(hex: colorValue) : theme.card))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(icon)
                    .accessibilityAddTraits(iconValue == icon ? .isSelected : [])
                    .accessibilityIdentifier("chat_guided_icon")
                }
            }
            HStack(spacing: DS.Spacing.sm) {
                ForEach(ChatGuidedCategoryLook.colors, id: \.self) { hex in
                    Button {
                        DS.Haptic.selection()
                        colorValue = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().strokeBorder(Color.primary, lineWidth: colorValue == hex ? 3 : 0))
                            .frame(minWidth: 36, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hex)
                    .accessibilityAddTraits(colorValue == hex ? .isSelected : [])
                    .accessibilityIdentifier("chat_guided_color")
                }
            }
            Button(G.categoryLookOther) { showsIconPicker = true }
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.thAccentText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("chat_guided_icon_other")
            YalaPrimaryButton(L10n.Action.continueAction) {
                let icon = iconValue
                let color = colorValue
                answer {
                    $0.categoryIcon = icon
                    $0.categoryColorHex = color
                }
            }
            .accessibilityIdentifier("chat_guided_look_continue")
        }
    }

    private var subcategoriesDock: some View {
        let typed = subcategoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if !pickedNames.isEmpty {
                FlowLayout(spacing: DS.Spacing.sm) {
                    ForEach(pickedNames, id: \.self) { name in
                        Button {
                            DS.Haptic.selection()
                            pickedNames.removeAll { $0 == name }
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Text(name).font(DS.Typography.subheadline.weight(.semibold))
                                Image(systemName: "xmark").font(DS.Typography.caption.weight(.bold))
                            }
                            .padding(.horizontal, DS.Spacing.md)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(theme.card))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(G.subcategoryRemove(name))
                        .accessibilityIdentifier("chat_guided_subcategory_name")
                    }
                }
            }
            HStack(spacing: DS.Spacing.sm) {
                TextField("", text: $subcategoryText,
                          prompt: Text(G.subcategoryPlaceholder).foregroundStyle(.tertiary))
                    .font(DS.Typography.body)
                    .focused($focused, equals: .subcategory)
                    .submitLabel(.done)
                    .onSubmit(addSubcategory)
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                    .accessibilityLabel(G.subcategoryAdd)
                    .accessibilityIdentifier("chat_guided_subcategory_field")
                Button(action: addSubcategory) {
                    Image(systemName: "plus")
                        .font(DS.Typography.headline)
                        .foregroundStyle(typed.isEmpty ? Color.secondary : theme.onAccent)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(typed.isEmpty ? theme.card : theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(typed.isEmpty)
                .accessibilityLabel(G.subcategoryAdd)
                .accessibilityIdentifier("chat_guided_subcategory_add")
            }
            YalaPrimaryButton(L10n.Action.continueAction) {
                let names = pickedNames
                answer(clearing: [.subcategories]) {
                    $0.subcategoryNames = names
                    $0.subcategoryNeeds = $0.subcategoryNeeds?.filter { names.contains($0.key) }
                }
            }
            .disabled(pickedNames.isEmpty)
            .accessibilityIdentifier("chat_guided_subcategories_continue")
        }
    }

    private var needsDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(answers.subcategoryNames ?? [], id: \.self) { name in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(name).font(DS.Typography.subheadline.weight(.semibold))
                    FlowLayout(spacing: DS.Spacing.xs) {
                        ForEach([SubcategoryNeed.essential, .priority, .optional], id: \.self) { need in
                            TutorialChip(title: need.displayName, isOn: pickedNeeds[name] == need.rawValue,
                                         id: "chat_guided_need_\(need.rawValue)") {
                                pickedNeeds[name] = pickedNeeds[name] == need.rawValue ? nil : need.rawValue
                            }
                        }
                    }
                }
            }
            YalaPrimaryButton(L10n.Action.continueAction) {
                let needs = pickedNeeds
                answer { $0.subcategoryNeeds = needs.isEmpty ? nil : needs }
            }
            .accessibilityIdentifier("chat_guided_needs_continue")
        }
    }

    // MARK: Favorito

    private var favoriteTypeDock: some View {
        let options: [(ChatGuidedFavoriteType, String, String, String)] = [
            (.expense, G.favoriteTypeExpense, G.favoriteTypeExpenseHint, "cart.fill"),
            (.income, G.favoriteTypeIncome, G.favoriteTypeIncomeHint, "arrow.down.circle.fill"),
            (.transfer, G.favoriteTypeTransfer, G.favoriteTypeTransferHint, "arrow.left.arrow.right"),
        ]
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(options, id: \.0) { type, title, hint, icon in
                TutorialOptionButton(title: title, subtitle: hint, icon: icon, highlighted: favoriteType == type,
                                     id: "chat_guided_favorite_type_\(type.rawValue)") {
                    answer(clearing: [.favoriteType]) { answers in
                        // Una subcategoría de gasto no vale para un ingreso (ni al revés): se vuelve a preguntar.
                        if answers.favoriteType != type.rawValue { answers.subcategoryID = nil }
                        answers.favoriteType = type.rawValue
                    }
                }
            }
        }
    }

    private var favoriteSubcategoryDock: some View {
        VStack(spacing: DS.Spacing.md) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm),
                                     count: TutorialGridColumns.count(3, dynamicTypeSize: dynamicTypeSize)),
                      spacing: DS.Spacing.sm) {
                ForEach(subcategoryOptions) { option in
                    TutorialSelectableTile(icon: option.icon, color: Color(hex: option.colorHex), title: option.name,
                                           caption: option.categoryName, isOn: answers.subcategoryID == option.id,
                                           id: "chat_guided_subcategory") {
                        answer(clearing: [.subcategories]) { $0.subcategoryID = option.id }
                    }
                }
            }
            Button(L10n.PrimerosPasos23.Payment.otherSubcategory) {
                otherSubcategory = nil
                showsOtherSubcategory = true
            }
            .font(DS.Typography.body.weight(.semibold))
            .foregroundStyle(.thAccentText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier("chat_guided_subcategory_other")
        }
    }

    private func accountsDock(excluding: PersistentIdentifier?,
                              choose: @escaping (PersistentIdentifier) -> Void) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach((data?.accounts ?? []).filter { $0.id != excluding }) { account in
                TutorialOptionButton(title: account.name, subtitle: currencyTitle(account.currencyCode),
                                     icon: "building.columns",
                                     highlighted: account.id == (excluding == nil ? answers.accountID : answers.destinationAccountID),
                                     id: "chat_guided_account") { choose(account.id) }
            }
        }
    }

    private var favoriteAmountDock: some View {
        let code = data?.account(answers.accountID)?.currencyCode ?? mainCurrency
        let typed = FirstAccountFlowView.parsed(amountText)
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                TutorialAmountField(text: $amountText, currencySymbol: CurrencyCode(rawValue: code)?.symbol ?? code,
                                    accessibilityLabel: questionTitle, id: "chat_guided_amount",
                                    focus: $amountFieldFocused)
                TutorialSendButton(enabled: ChatGuidedEngine.isValidAmount(typed), id: "chat_guided_amount_send") {
                    guard let typed, ChatGuidedEngine.isValidAmount(typed) else { return }
                    answer(clearing: [.amount]) {
                        $0.amount = typed
                        $0.favoriteWithoutAmount = false
                    }
                }
            }
            TutorialOptionButton(title: G.valueVariable, subtitle: G.favoriteAmountVariableHint, icon: "pencil",
                                 highlighted: answers.favoriteWithoutAmount == true, id: "chat_guided_amount_variable") {
                answer(clearing: [.amount]) {
                    $0.amount = nil
                    $0.favoriteWithoutAmount = true
                }
            }
        }
    }

    private var favoriteNameDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if !favoriteNameIdeas.isEmpty {
                FlowLayout(spacing: DS.Spacing.sm) {
                    ForEach(favoriteNameIdeas, id: \.self) { idea in
                        TutorialChip(title: idea, id: "chat_guided_name_idea") { answer(clearing: [.name]) { $0.favoriteName = idea } }
                    }
                }
            }
            textEntry(text: $nameText, prompt: T.namePlaceholder, field: .name, id: "chat_guided_name") { name in
                answer(clearing: [.name]) { $0.favoriteName = name }
            }
        }
    }

    private var favoriteNeedDock: some View {
        let current = answers.favoriteNeed.flatMap(SubcategoryNeed.init(rawValue:)) ?? subcategoryNeed
        return VStack(spacing: DS.Spacing.sm) {
            ForEach([SubcategoryNeed.essential, .priority, .optional], id: \.self) { need in
                TutorialOptionButton(title: need.displayName, subtitle: need.description, highlighted: current == need,
                                     id: "chat_guided_need_\(need.rawValue)") {
                    answer { $0.favoriteNeed = need.rawValue }
                }
            }
        }
    }

    private var tagsDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(data?.tags ?? []) { tag in
                    TutorialChip(title: tag.name, isOn: pickedTags.contains(tag.id), id: "chat_guided_pick_tag") {
                        if let index = pickedTags.firstIndex(of: tag.id) { pickedTags.remove(at: index) } else { pickedTags.append(tag.id) }
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

    private var noteDock: some View {
        textEntry(text: $noteText, prompt: G.paymentNotePlaceholder, field: .note, id: "chat_guided_note") { note in
            answer { $0.note = note }
        }
    }

    // MARK: Los dos de siempre

    private var advancedDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            TutorialOptionButton(title: G.advancedNo, icon: "checkmark", highlighted: true, id: "chat_guided_advanced_no") {
                errorText = nil
                viewModel.guidedAdvanced(messageID: messageID, wants: false)
            }
            TutorialOptionButton(title: G.advancedYes, icon: "slider.horizontal.3", id: "chat_guided_advanced_yes") {
                errorText = nil
                viewModel.guidedAdvanced(messageID: messageID, wants: true)
            }
        }
    }

    private func optionPair(yes: String, no: String, current: Bool, id: String,
                            choose: @escaping (Bool) -> Void) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            TutorialOptionButton(title: yes, highlighted: current, id: "\(id)_yes") { choose(true) }
            TutorialOptionButton(title: no, highlighted: !current, id: "\(id)_no") { choose(false) }
        }
    }

    private func textEntry(text: Binding<String>, prompt: String, field: Field, id: String,
                           keyboard: UIKeyboardType = .default, send: @escaping (String) -> Void) -> some View {
        let trimmed = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: DS.Spacing.sm) {
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(.tertiary))
                .font(DS.Typography.body)
                .keyboardType(keyboard)
                .focused($focused, equals: field)
                .submitLabel(.done)
                .onSubmit { if !trimmed.isEmpty { send(trimmed) } }
                .padding(.horizontal, DS.Spacing.md)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                .accessibilityLabel(questionTitle)
                .accessibilityIdentifier(id)
            TutorialSendButton(enabled: !trimmed.isEmpty, id: "\(id)_send") { send(trimmed) }
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
            YalaPrimaryButton(createTitle) {
                guard let data else { return }
                errorText = viewModel.createGuided(messageID: messageID, data: data)
            }
            .disabled(data == nil || !ChatGuidedEngine.canCreate(state))
            .accessibilityIdentifier("chat_guided_create")
        }
    }

    private var createTitle: String {
        switch state.kind {
        case .account: G.confirmCreateAccount
        case .category: answers.categoryMode == .subcategories ? G.confirmCreateSubcategories : G.confirmCreateCategory
        case .favorite: G.confirmSaveFavorite
        case .budget: G.confirmCreateBudget
        case .scheduledPayment: G.confirmCreatePayment
        case .group, .groupOpeningBalance, .groupExpense: G.confirmCreateGroup
        }
    }

    private var confirmRows: [ChatGuidedConfirmRow.Model] {
        let said = state.prefilled
        var rows: [ChatGuidedConfirmRow.Model] = []
        let asked = Set(ChatGuidedEngine.askedSteps(state.kind, answers: answers))
        func add(_ step: ChatGuidedStep, _ label: String, _ value: String, _ field: ChatGuidedField? = nil) {
            guard asked.contains(step) || step == .accountCurrencies else { return }
            rows.append(.init(step: step, label: label, value: value, saidByYou: field.map(said.contains) ?? false))
        }
        switch state.kind {
        case .account:
            add(.accountKind, G.rowAccountType, accountKind.map { FirstAccountFlowView.kindTitle($0) } ?? "—", .accountKind)
            add(.accountCurrencies, G.rowCurrencies, accountCurrencies.map(currencyTitle).joined(separator: ", "), .currency)
            add(.accountName, G.rowName, answers.accountName ?? "—", .name)
            add(.accountBalance, G.rowBalance, balancesText, .balance)
            add(.accountStatementDay, G.rowStatementDay, dayText(answers.accountStatementDay))
            add(.accountPaymentDay, G.rowPaymentDay, dayText(answers.accountPaymentDay))
            add(.accountReminder, G.rowReminder, (answers.accountReminderLead ?? -1) < 0
                ? G.valueNoReminder : FirstAccountFlowView.reminderLabel(answers.accountReminderLead ?? 0))
        case .category:
            add(.categoryMode, G.rowCreate, answers.categoryMode == .subcategories ? G.categoryModeSub : G.valueNewCategory,
                .categoryMode)
            add(.categoryParent, G.rowCategory, data?.parent(answers.parentCategoryID)?.name ?? "—", .parentCategory)
            add(.categoryName, G.rowName, answers.categoryName ?? "—", .name)
            add(.categoryLook, G.rowIcon, "●")
            add(.categorySubcategories, G.rowSubcategories, (answers.subcategoryNames ?? []).joined(separator: ", "),
                .subcategories)
        case .favorite:
            add(.favoriteType, G.rowType, favoriteTypeTitle, .favoriteType)
            add(.favoriteSubcategory, G.rowCategory, data?.favoriteSubcategory(answers.subcategoryID)?.name ?? "—",
                .subcategories)
            add(.favoriteAccount, G.rowAccount, data?.account(answers.accountID)?.name ?? "—")
            add(.favoriteDestination, G.rowDestination, data?.account(answers.destinationAccountID)?.name ?? "—")
            add(.favoriteAmount, G.rowAmount, favoriteAmountText, .amount)
            add(.favoriteName, G.rowName, answers.favoriteName ?? "—", .name)
        case .budget, .scheduledPayment, .group, .groupOpeningBalance, .groupExpense:
            break
        }
        rows.append(.init(step: .advanced, label: G.rowAdvanced,
                          value: answers.wantsAdvanced == true ? G.valueReviewed : G.valueDefaults, saidByYou: false))
        if answers.wantsAdvanced == true {
            for step in asked where step.isAdvancedOption {
                switch step {
                case .accountNumber:
                    let number = ChatGuidedEngine.trimmed(answers.accountNumber)
                    add(step, G.rowNumber, number.isEmpty ? G.valueNoNumber : number)
                case .accountStats:
                    add(step, G.rowReports, answers.accountCountsInReports == false ? G.valueNo : G.valueYes)
                case .categoryNeeds:
                    let needs = (answers.subcategoryNames ?? []).map { name in
                        let need = answers.subcategoryNeeds?[name].flatMap(SubcategoryNeed.init(rawValue:))
                        return "\(name): \(need?.displayName ?? G.valueUnclassified)"
                    }
                    add(step, G.rowNeeds, needs.joined(separator: " · "))
                case .favoriteNeed:
                    let need = answers.favoriteNeed.flatMap(SubcategoryNeed.init(rawValue:)) ?? subcategoryNeed
                    add(step, G.rowNeeds, need?.displayName ?? G.valueUnclassified)
                case .favoriteTags:
                    let names = (answers.tagIDs ?? []).compactMap { data?.tag($0)?.name }
                    add(step, G.rowTags, names.isEmpty ? G.valueNone : names.joined(separator: ", "))
                case .favoriteNote:
                    let note = ChatGuidedEngine.trimmed(answers.note)
                    add(step, G.rowNote, note.isEmpty ? G.valueNoNote : note)
                default:
                    break
                }
            }
        }
        return rows
    }

    // MARK: - Contestar

    private func answer(clearing fields: Set<ChatGuidedField> = [], _ change: (inout ChatGuidedAnswers) -> Void) {
        errorText = nil
        focused = nil
        amountFieldFocused = false
        editsName = false
        viewModel.answerGuided(messageID: messageID, clearing: fields, change)
    }

    private func answerAccountName(_ name: String) {
        guard !(data?.accountNames.contains(ChatGuidedDataSource.foldedName(name)) ?? false) else {
            errorText = G.accountNameTaken
            nameText = name
            editsName = true
            return
        }
        answer(clearing: [.name]) { $0.accountName = name }
    }

    private var balancesAreValid: Bool {
        balanceRows.allSatisfy { row in
            let text = row.text.trimmingCharacters(in: .whitespaces)
            return text.isEmpty || FirstAccountFlowView.parsed(text).map { $0.isFinite && $0 >= 0 } == true
        }
    }

    private func answerBalances(zero: Bool) {
        guard let kind = accountKind else { return }
        var balances: [String: Double] = [:]
        for row in balanceRows {
            let magnitude = zero ? 0 : FirstAccountFlowView.parsed(row.text) ?? 0
            balances[row.id] = Logic.storedBalance(kind: kind, magnitude: magnitude, isNegative: row.isNegative)
        }
        answer(clearing: [.balance]) { $0.accountBalances = balances }
    }

    private func toggleCurrency(_ code: String) {
        DS.Haptic.selection()
        if let index = pickedCurrencies.firstIndex(of: code) {
            pickedCurrencies.remove(at: index)
        } else if Logic.canAddCurrency(count: pickedCurrencies.count) {
            pickedCurrencies.append(code)
        }
    }

    private func addCurrency(_ code: String) {
        guard showsCurrencyPicker || state.step == .accountCurrencies else { return }
        let normalized = code.uppercased()
        if !pickedCurrencies.contains(normalized), Logic.canAddCurrency(count: pickedCurrencies.count) {
            pickedCurrencies.append(normalized)
        }
        if data?.currencies.contains(normalized) == false { data?.currencies.append(normalized) }
    }

    /// Un recordatorio pide el permiso de avisos si nunca se pidió (como Primeros pasos); «No me lo recuerdes», no.
    private func chooseReminder(_ lead: Int) {
        guard !isAskingPermission else { return }
        guard lead >= 0 else {
            answer { $0.accountReminderLead = lead }
            return
        }
        let step = state.step
        isAskingPermission = true
        Task { @MainActor in
            #if DEBUG
            if !UITestHooks.isActive { _ = await TutorialPermissionMoments.remindMeChosen() }
            #else
            _ = await TutorialPermissionMoments.remindMeChosen()
            #endif
            isAskingPermission = false
            guard viewModel.guidedState(messageID: messageID)?.step == step else { return }
            answer { $0.accountReminderLead = lead }
        }
    }

    private func addSubcategory() {
        let name = subcategoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let folded = ChatGuidedDataSource.foldedName(name)
        let taken = data?.parent(answers.parentCategoryID)?.subcategoryNames ?? []
        if answers.categoryMode == .subcategories, taken.contains(folded) {
            errorText = G.subcategoryTaken(name)
            return
        }
        errorText = nil
        DS.Haptic.selection()
        if !pickedNames.contains(where: { ChatGuidedDataSource.foldedName($0) == folded }) {
            pickedNames.append(name.prefix(1).uppercased() + name.dropFirst())
        }
        subcategoryText = ""
        focused = .subcategory
    }

    /// Al cerrarse «Otra subcategoría»: la elegida entra en las opciones y contesta.
    private func applyOtherSubcategory() {
        guard let other = otherSubcategory, !other.isDeleted, other.modelContext != nil else { return }
        let option = ChatGuidedDataSource.option(other)
        let type: ChatGuidedFavoriteType = favoriteType == .income ? .income : .expense
        if data?.favoriteSubcategory(option.id) == nil {
            data?.favoriteSubcategories[type, default: []].insert(option, at: 0)
        }
        answer(clearing: [.subcategories]) { $0.subcategoryID = option.id }
    }

    // MARK: - Carga y campos

    private func loadIfNeeded() {
        guard data == nil, state.status == .inProgress else { return }
        var loaded = ChatGuidedDataSource.load(state.kind, context: modelContext, mainCurrency: mainCurrency)
        // La subcategoría que dijo la frase puede no estar entre las más usadas: se añade.
        if state.kind == .favorite, let id = answers.subcategoryID, loaded.favoriteSubcategory(id) == nil,
           let subcategory = modelContext.model(for: id) as? Subcategory, !subcategory.isDeleted {
            let type: ChatGuidedFavoriteType = subcategory.category?.isIncome == true ? .income : .expense
            loaded.favoriteSubcategories[type, default: []].insert(ChatGuidedDataSource.option(subcategory), at: 0)
        }
        if state.kind == .category { takenCategoryNames = ChatGuidedDataSource.categoryNames(modelContext) }
        data = loaded
    }

    /// Lo escrito en los campos empieza con la respuesta que ya hay (al volver atrás o al «Cambiar»).
    private func syncFields() {
        switch state.kind {
        case .account: nameText = answers.accountName ?? ""
        case .category: nameText = answers.categoryName ?? ""
        case .favorite: nameText = answers.favoriteName ?? ""
        case .budget, .scheduledPayment, .group, .groupOpeningBalance, .groupExpense: break
        }
        editsName = false
        pickedCurrencies = answers.accountCurrencies ?? [mainCurrency.uppercased()]
        balanceRows = accountCurrencies.map { code in
            let value = answers.accountBalances?[code] ?? 0
            return BalanceRow(id: code, text: value == 0 ? "" : Self.amountText(abs(value)), isNegative: value < 0 && !isCard)
        }
        numberText = answers.accountNumber ?? ""
        pickedNames = answers.subcategoryNames ?? []
        pickedNeeds = answers.subcategoryNeeds ?? [:]
        if let icon = answers.categoryIcon { iconValue = icon }
        else if let name = answers.categoryName { iconValue = ChatGuidedCategoryLook.suggestedIcon(for: name) }
        if let color = answers.categoryColorHex { colorValue = color }
        amountText = answers.amount.map(Self.amountText) ?? ""
        noteText = answers.note ?? ""
        pickedTags = answers.tagIDs ?? []
        subcategoryText = ""
    }

    // MARK: - Cifras y textos

    private var accountKind: Logic.Kind? { ChatGuidedEngine.accountKind(answers) }
    private var isCard: Bool { accountKind?.isCard == true }
    private var accountCurrencies: [String] { answers.accountCurrencies ?? [mainCurrency.uppercased()] }
    private var suggestedAccountName: String { FirstAccountFlowView.suggestedName(for: accountKind) }
    private var favoriteType: ChatGuidedFavoriteType? { ChatGuidedEngine.favoriteType(answers) }

    private var accountDraft: FirstAccountDraft {
        var draft = FirstAccountDraft(mainCurrency: accountCurrencies.first ?? mainCurrency)
        draft.kind = accountKind
        draft.currencies = accountCurrencies
        draft.name = answers.accountName ?? ""
        draft.balances = answers.accountBalances ?? [:]
        if let day = answers.accountStatementDay { draft.statementDay = day == 0 ? .unknown : .day(day) }
        if let day = answers.accountPaymentDay { draft.paymentDay = day == 0 ? .unknown : .day(day) }
        draft.reminderLead = answers.accountReminderLead.flatMap { $0 < 0 ? nil : $0 }
        return draft
    }

    /// Las monedas que se ofrecen: las elegidas primero, luego las de Yala.
    private var currencyOptions: [String] {
        var seen: Set<String> = []
        return (pickedCurrencies + (data?.currencies ?? [mainCurrency])).map { $0.uppercased() }
            .filter { seen.insert($0).inserted }
    }

    private func currencyTitle(_ code: String) -> String {
        let symbol = CurrencyCode(rawValue: code)?.symbol ?? code
        return symbol == code ? code : "\(code) · \(symbol)"
    }

    private var balancesText: String {
        accountCurrencies.map { code in
            let value = answers.accountBalances?[code] ?? 0
            let amount = appPreferences.currency(abs(value), currencyCode: code)
            return value < 0 && !isCard ? "−\(amount)" : amount
        }.joined(separator: " · ")
    }

    private func dayText(_ day: Int?) -> String {
        guard let day else { return "—" }
        return day == 0 ? G.valueDontKnow : G.valueDay(day)
    }

    private var categoryPreviewName: String? {
        answers.categoryMode == .subcategories ? data?.parent(answers.parentCategoryID)?.name : answers.categoryName
    }

    /// Las subcategorías que se ven arriba: las de la pregunta mientras se escriben, o las ya contestadas.
    private var currentNames: [String] {
        state.step == .categorySubcategories ? pickedNames : (answers.subcategoryNames ?? [])
    }

    private var subcategoryOptions: [ChatGuidedData.SubcategoryOption] {
        let type: ChatGuidedFavoriteType = favoriteType == .income ? .income : .expense
        return data?.favoriteSubcategories[type] ?? []
    }

    private var subcategoryNeed: SubcategoryNeed? {
        guard let id = answers.subcategoryID, let subcategory = modelContext.model(for: id) as? Subcategory,
              !subcategory.isDeleted, subcategory.modelContext != nil else { return nil }
        return subcategory.need
    }

    private var favoriteTypeTitle: String {
        switch favoriteType {
        case .expense: G.favoriteTypeExpense
        case .income: G.favoriteTypeIncome
        case .transfer: G.favoriteTypeTransfer
        case nil: "—"
        }
    }

    private var favoriteAmountText: String {
        if answers.favoriteWithoutAmount == true { return G.valueVariable }
        guard let amount = answers.amount else { return "" }
        return appPreferences.currency(amount, currencyCode: data?.account(answers.accountID)?.currencyCode ?? mainCurrency)
    }

    /// Ideas de nombre: la subcategoría, y en una transferencia, «A → B».
    private var favoriteNameIdeas: [String] {
        var ideas: [String] = []
        if let name = data?.favoriteSubcategory(answers.subcategoryID)?.name { ideas.append(name) }
        if favoriteType == .transfer, let from = data?.account(answers.accountID)?.name,
           let to = data?.account(answers.destinationAccountID)?.name {
            ideas.append("\(from) → \(to)")
        }
        return ideas
    }

    /// Un monto como se escribe: sin decimales si es entero.
    nonisolated static func amountText(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
    }
}
