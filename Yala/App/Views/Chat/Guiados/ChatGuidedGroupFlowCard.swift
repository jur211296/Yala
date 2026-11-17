//
//  ChatGuidedGroupFlowCard.swift
//  Yala
//
//  La tarjeta de los guiados de Grupos dentro del hilo de Yala IA: crear un grupo, anotar una deuda de antes y repartir
//  un gasto. Mismo molde que `ChatGuidedCreateFlowCard` (cabecera con sus puntos, lo que se arma llenándose arriba, la
//  pregunta, sus respuestas y «Revisa antes de crear» con «Cambiar»). La tarjeta no decide nada: cada toque contesta por
//  el ViewModel del chat y el motor elige la siguiente pregunta.
//

import SwiftData
import SwiftUI

struct ChatGuidedGroupFlowCard: View {
    let messageID: UUID
    let state: ChatGuidedFlowState
    @Bindable var viewModel: ChatAssistantViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var data: ChatGuidedData?
    @State private var errorText: String?
    @State private var nameText = ""
    @State private var descriptionText = ""
    @State private var amountText = ""
    @State private var dateValue = Date.now
    @State private var pickedPeople: [String] = []
    /// «Un monto para cada uno»: lo que se va escribiendo, una fila por persona.
    @State private var exactRows: [ExactRow] = []
    /// «¿Cómo lo dividen?»: el modo que se está armando (solo algunos o un monto a cada uno) antes de «Continuar».
    @State private var splitDraft: ChatGuidedSplitMode?
    @State private var showsCurrencyPicker = false
    @State private var currencyPick: CurrencyCode = .usd
    @State private var currencyAtOpen: CurrencyCode?
    @State private var showsCategoryPicker = false
    @State private var pickedSubcategory: Subcategory?
    @State private var isCreating = false
    @FocusState private var focused: Field?
    @FocusState private var amountFocused: Bool

    private enum Field: Hashable { case name, description, exact(String) }

    struct ExactRow: Identifiable, Equatable {
        /// `SplitMember.id.uuidString`.
        let id: String
        let name: String
        var text = ""
    }

    private typealias G = L10n.IAGuiados

    private var answers: ChatGuidedAnswers { state.answers }
    /// Mientras el grupo se crea en el servidor no se toca nada: ni «Atrás», ni «Cambiar», ni un segundo «Crear».
    private var isBusy: Bool { isCreating || viewModel.groupCreationsInFlight.contains(messageID) }
    private var group: ChatGuidedGroupOption? { data?.group(answers.groupZoneID) }
    private var currency: String { (answers.currencyCode ?? group?.currencyCode ?? CurrencyDefaults.currentPreferred).uppercased() }

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
                .disabled(isBusy)
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
        // Lo elegido en la hoja contesta al cerrarla: preparar el selector con la moneda de ahora no es elegirla.
        .sheet(isPresented: $showsCurrencyPicker, onDismiss: applyPickedCurrency) {
            CurrencyPickerSheet(selectedCurrency: $currencyPick)
        }
        .sheet(isPresented: $showsCategoryPicker, onDismiss: applyCategory) {
            SubcategorySelectorSheet(selectedSubcategory: $pickedSubcategory, transactionType: .expense)
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
                .disabled(isBusy)
                .accessibilityIdentifier("chat_guided_back")
            }
            Image(systemName: Self.headerIcon(state.kind))
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(theme.accentText)
                .accessibilityHidden(true)
            Text(Self.headerTitle(state.kind))
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
        case .groupOpeningBalance: "clock.arrow.circlepath"
        case .groupExpense: "divide.circle.fill"
        default: "person.3.fill"
        }
    }

    static func headerTitle(_ kind: ChatGuidedKind) -> String {
        switch kind {
        case .groupOpeningBalance: L10n.IAGuiados.debtHeader
        case .groupExpense: L10n.IAGuiados.expenseHeader
        default: L10n.IAGuiados.groupHeader
        }
    }

    // MARK: - Lo que se arma, arriba

    @ViewBuilder
    private var preview: some View {
        switch state.kind {
        case .group:
            if let purpose = answers.groupPurpose { groupPreview(purpose) }
        case .groupOpeningBalance:
            if let group { previewCard(icon: group.iconName, colorHex: group.colorHex, title: group.name,
                                       caption: debtSentence) }
        case .groupExpense:
            if let group {
                previewCard(icon: group.iconName, colorHex: group.colorHex,
                            title: answers.expenseDescription ?? group.name,
                            caption: [group.name, payerCaption].compactMap { $0 }.joined(separator: " · "),
                            trailing: answers.amount.map(money))
            }
        default:
            EmptyView()
        }
    }

    private func groupPreview(_ purpose: ChatGuidedGroupPurpose) -> some View {
        let name = answers.groupName ?? ""
        return previewCard(icon: purpose.iconName, colorHex: purpose.colorHex,
                           title: name.isEmpty ? Self.purposeTitle(purpose) : name,
                           caption: answers.groupSplitType.flatMap(SplitType.init(rawValue:))?.displayName,
                           isPlaceholder: name.isEmpty)
    }

    private func previewCard(icon: String, colorHex: String, title: String, caption: String?,
                             trailing: String? = nil, isPlaceholder: Bool = false) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.headline)
                .foregroundStyle(theme.onFill(Color(hex: colorHex)))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(hex: colorHex)))
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(isPlaceholder ? .secondary : .primary)
                if let caption, !caption.isEmpty {
                    Text(caption).font(DS.Typography.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DS.Spacing.sm)
            if let trailing { Text(trailing).font(DS.Typography.headline) }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(theme.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: - La pregunta

    private var questionTitle: String {
        switch state.step {
        case .groupPurpose: G.groupPurposeQuestion
        case .groupName: G.groupNameQuestion
        case .groupYourName: G.groupYourNameQuestion
        case .groupCurrencyMode: G.groupCurrencyModeQuestion
        case .groupCurrency, .currency: G.groupCurrencyQuestion
        case .groupSplit: G.groupSplitQuestion
        case .groupSimplify: G.groupSimplifyQuestion
        case .groupPick: G.groupPickQuestion
        case .debtDebtor: G.debtDebtorQuestion
        case .debtCreditor: G.debtCreditorQuestion(name(answers.debtorMemberID))
        case .debtAmount: G.debtAmountQuestion
        case .debtDate: G.debtDateQuestion
        case .expenseDescription: G.expenseDescriptionQuestion
        case .expenseAmount: G.expenseAmountQuestion
        case .expensePayer: G.expensePayerQuestion
        case .expenseSplit: G.expenseSplitQuestion
        case .expenseAccount: G.expenseAccountQuestion
        case .expenseCategory: G.expenseCategoryQuestion
        case .expenseDate: G.expenseDateQuestion
        case .advanced: G.advancedQuestion
        default: G.confirmQuestion
        }
    }

    private var questionDetail: String? {
        switch state.step {
        case .groupPurpose: G.groupPurposeSubtitle
        case .groupYourName: G.groupYourNameSubtitle
        case .groupSplit: G.groupSplitSubtitle
        case .groupSimplify: G.groupSimplifySubtitle
        case .debtDebtor: G.debtDebtorSubtitle
        case .expenseAccount: G.expenseAccountSubtitle
        case .advanced: G.advancedSubtitle
        case .confirm: G.confirmSubtitle
        default: nil
        }
    }

    // MARK: - Las respuestas

    @ViewBuilder
    private var dock: some View {
        switch state.step {
        case .groupPurpose: purposeDock
        case .groupName:
            textEntry(text: $nameText, prompt: Self.nameExample(answers.groupPurpose), field: .name,
                      id: "chat_guided_name") { name in answer(clearing: [.name]) { $0.groupName = name } }
        case .groupYourName:
            textEntry(text: $nameText, prompt: G.groupYourNamePlaceholder, field: .name, id: "chat_guided_your_name") { name in
                answer { $0.groupDisplayName = name }
            }
        case .groupCurrencyMode: currencyModeDock
        case .groupCurrency, .currency: currencyDock
        case .groupSplit: groupSplitDock
        case .groupSimplify:
            optionPair(yes: G.groupSimplifyYes, no: G.groupSimplifyNo, current: answers.groupSimplifyDebts ?? true,
                       id: "chat_guided_simplify") { simplify in answer { $0.groupSimplifyDebts = simplify } }
        case .groupPick: groupPickDock
        case .debtDebtor:
            membersDock(excluding: nil, selected: answers.debtorMemberID, id: "chat_guided_debtor") { member in
                answer(clearing: [.debtor]) { answers in
                    answers.debtorMemberID = member
                    if answers.creditorMemberID == member { answers.creditorMemberID = nil }
                    if let group { answers = ChatGuidedDataSource.completeTwoPersonDebt(answers, group: group) }
                }
            }
        case .debtCreditor:
            membersDock(excluding: answers.debtorMemberID, selected: answers.creditorMemberID,
                        id: "chat_guided_creditor") { member in
                answer(clearing: [.creditor]) { $0.creditorMemberID = member }
            }
        case .debtAmount, .expenseAmount: amountDock
        case .debtDate, .expenseDate: dateDock
        case .expenseDescription:
            textEntry(text: $descriptionText, prompt: G.expenseDescriptionPlaceholder, field: .description,
                      id: "chat_guided_description") { text in answer(clearing: [.description]) { $0.expenseDescription = text } }
        case .expensePayer:
            membersDock(excluding: nil, selected: answers.payerMemberID, id: "chat_guided_payer") { member in
                answer(clearing: [.payer]) { $0.payerMemberID = member }
            }
        case .expenseSplit: splitDock
        case .expenseAccount: accountDock
        case .expenseCategory: categoryDock
        case .advanced: advancedDock
        case .confirm: confirmDock
        default: EmptyView()
        }
    }

    // MARK: Crear un grupo

    private var purposeDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(ChatGuidedGroupPurpose.allCases, id: \.self) { purpose in
                TutorialOptionButton(title: Self.purposeTitle(purpose), icon: purpose.iconName,
                                     tint: Color(hex: purpose.colorHex), highlighted: answers.groupPurpose == purpose,
                                     id: "chat_guided_purpose_\(purpose.rawValue)") {
                    answer { $0.groupPurpose = purpose }
                }
            }
        }
    }

    private var currencyModeDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            TutorialOptionButton(title: G.groupCurrencyEach, subtitle: G.groupCurrencyEachHint, icon: "dollarsign.arrow.circlepath",
                                 highlighted: answers.groupSingleCurrency == false, id: "chat_guided_currency_each") {
                answer(clearing: [.currency]) { $0.groupSingleCurrency = false }
            }
            TutorialOptionButton(title: G.groupCurrencyOne, subtitle: G.groupCurrencyOneHint, icon: "equal.circle.fill",
                                 highlighted: answers.groupSingleCurrency == true, id: "chat_guided_currency_one") {
                answer(clearing: [.currency]) { $0.groupSingleCurrency = true }
            }
        }
    }

    private var currencyDock: some View {
        FlowLayout(spacing: DS.Spacing.sm) {
            ForEach(currencyOptions, id: \.self) { code in
                TutorialChip(title: currencyTitle(code), isOn: currency == code, id: "chat_guided_currency_\(code)") {
                    chooseCurrency(code)
                }
            }
            TutorialChip(title: L10n.PrimerosPasos23.Account.addCurrency, id: "chat_guided_currency_other") {
                currencyPick = CurrencyCode(rawValue: currency) ?? .usd
                currencyAtOpen = currencyPick
                showsCurrencyPicker = true
            }
        }
    }

    private var groupSplitDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(SplitType.allCases) { type in
                TutorialOptionButton(title: type.displayName, subtitle: Self.splitHint(type),
                                     highlighted: answers.groupSplitType == type.rawValue,
                                     id: "chat_guided_split_type_\(type.rawValue)") {
                    answer { $0.groupSplitType = type.rawValue }
                }
            }
        }
    }

    // MARK: Deuda y gasto

    private var groupPickDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(data?.groups ?? []) { option in
                TutorialOptionButton(title: option.name, subtitle: option.members.map(\.name).joined(separator: ", "),
                                     icon: option.iconName, tint: Color(hex: option.colorHex),
                                     highlighted: answers.groupZoneID == option.id, id: "chat_guided_group") {
                    chooseGroup(option)
                }
            }
        }
    }

    private func membersDock(excluding: String?, selected: String?, id: String,
                             choose: @escaping (String) -> Void) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach((group?.members ?? []).filter { $0.id != excluding }) { member in
                TutorialOptionButton(title: member.isMe ? G.youMember : member.name,
                                     icon: member.isMe ? "person.crop.circle.fill" : "person.fill",
                                     highlighted: selected == member.id, id: id) { choose(member.id) }
            }
        }
    }

    private var amountDock: some View {
        HStack(spacing: DS.Spacing.sm) {
            TutorialAmountField(
                text: $amountText,
                currencySymbol: CurrencyCode(rawValue: currency)?.symbol ?? currency,
                accessibilityLabel: questionTitle,
                id: "chat_guided_amount",
                focus: $amountFocused
            )
            TutorialSendButton(enabled: typedAmount != nil, id: "chat_guided_amount_send") {
                guard let typedAmount else { return }
                answer(clearing: [.amount]) { answers in
                    answers.amount = typedAmount
                    // Otro total deja de cuadrar con los montos de cada uno: se vuelve a preguntar el reparto.
                    if answers.splitMode == .exact { answers.splitMode = nil }
                }
            }
        }
    }

    private var dateDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            TutorialOptionButton(title: G.valueToday, icon: "calendar", highlighted: answers.groupDate == nil,
                                 id: "chat_guided_date_today") {
                answer { $0.groupDate = nil }
            }
            DatePicker(G.rowDate, selection: $dateValue, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.compact)
                .font(DS.Typography.body)
                .accessibilityIdentifier("chat_guided_date_picker")
            YalaPrimaryButton(L10n.Action.continueAction) {
                let date = dateValue
                answer { $0.groupDate = Calendar.current.isDateInToday(date) ? nil : date }
            }
            .accessibilityIdentifier("chat_guided_date_continue")
        }
    }

    private var splitDock: some View {
        let members = group?.members ?? []
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            TutorialOptionButton(
                title: G.splitAll,
                subtitle: equalEachText(count: members.count),
                icon: "person.3.fill",
                highlighted: answers.splitMode == .equalAll && splitDraft == nil,
                id: "chat_guided_split_all"
            ) {
                splitDraft = nil
                answer(clearing: [.participants]) { answers in
                    answers.splitMode = .equalAll
                    answers.participantIDs = nil
                    answers.exactShares = nil
                }
            }
            TutorialOptionButton(title: G.splitSome, icon: "person.2.fill",
                                 highlighted: (splitDraft ?? answers.splitMode) == .equalSome,
                                 id: "chat_guided_split_some") {
                startDraft(.equalSome)
            }
            TutorialOptionButton(title: G.splitExact, icon: "list.number",
                                 highlighted: (splitDraft ?? answers.splitMode) == .exact,
                                 id: "chat_guided_split_exact") {
                startDraft(.exact)
            }
            if splitDraft == .equalSome { someDraft(members) }
            if splitDraft == .exact { exactDraft(members) }
        }
    }

    private func someDraft(_ members: [ChatGuidedGroupOption.Member]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(members) { member in
                    TutorialChip(title: member.isMe ? G.youMember : member.name, isOn: pickedPeople.contains(member.id),
                                 id: "chat_guided_person") { togglePerson(member.id) }
                }
            }
            if !pickedPeople.isEmpty, let amount = answers.amount {
                Text(G.splitEach(money(amount / Double(pickedPeople.count))))
                    .font(DS.Typography.caption).foregroundStyle(.secondary)
            }
            YalaPrimaryButton(L10n.Action.continueAction) {
                let picked = members.map(\.id).filter(pickedPeople.contains)
                splitDraft = nil
                answer(clearing: [.participants]) { answers in
                    answers.splitMode = picked.count == members.count ? .equalAll : .equalSome
                    answers.participantIDs = picked.count == members.count ? nil : picked
                    answers.exactShares = nil
                }
            }
            .disabled(pickedPeople.isEmpty)
            .accessibilityIdentifier("chat_guided_split_some_continue")
        }
    }

    private func exactDraft(_ members: [ChatGuidedGroupOption.Member]) -> some View {
        let total = answers.amount ?? 0
        let assigned = exactRows.compactMap { FirstAccountFlowView.parsed($0.text).map(ChatGuidedEngine.cents) }.reduce(0, +)
        let remaining = total - assigned
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach($exactRows) { $row in
                HStack(spacing: DS.Spacing.sm) {
                    Text(row.name)
                        .font(DS.Typography.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: DS.Spacing.xs) {
                        Text(CurrencyCode(rawValue: currency)?.symbol ?? currency)
                            .font(DS.Typography.subheadline).foregroundStyle(.secondary)
                        TextField("", text: $row.text, prompt: Text(verbatim: "0").foregroundStyle(.tertiary))
                            .font(DS.Typography.body.weight(.semibold))
                            .amountKeyboard()
                            .focused($focused, equals: .exact(row.id))
                            .frame(maxWidth: 110)
                            .accessibilityLabel(row.name)
                            .accessibilityIdentifier("chat_guided_exact_amount")
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                }
            }
            Text(abs(remaining) < 0.005 ? G.splitBalanced : (remaining > 0 ? G.splitMissing(money(remaining))
                                                                              : G.splitOver(money(-remaining))))
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(abs(remaining) < 0.005 ? Color.secondary : Color.overBudgetText)
                .accessibilityIdentifier("chat_guided_split_remaining")
            YalaPrimaryButton(L10n.Action.continueAction) { answerExact() }
                .disabled(abs(remaining) >= 0.005 || assigned <= 0)
                .accessibilityIdentifier("chat_guided_split_exact_continue")
        }
    }

    @ViewBuilder
    private var accountDock: some View {
        let options = (data?.accounts ?? []).filter { $0.currencyCode.uppercased() == currency }
        if options.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(G.expenseNoAccount(currencyTitle(currency)))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("chat_guided_no_account")
                // La moneda va antes que la cuenta: sin respuesta, se vuelve a preguntar.
                TutorialOptionButton(title: G.expenseOtherCurrency, icon: "dollarsign.arrow.circlepath",
                                     id: "chat_guided_account_other_currency") {
                    answer(clearing: [.currency]) { answers in
                        answers.currencyCode = nil
                        answers.accountID = nil
                    }
                }
            }
        } else {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(options) { account in
                    TutorialOptionButton(title: account.name, icon: "creditcard.fill",
                                         highlighted: answers.accountID == account.id, id: "chat_guided_account") {
                        answer { $0.accountID = account.id }
                    }
                }
            }
        }
    }

    private var categoryDock: some View {
        VStack(spacing: DS.Spacing.sm) {
            TutorialOptionButton(title: answers.expenseSubcategoryName ?? G.expenseCategoryPick, icon: "square.grid.2x2.fill",
                                 highlighted: answers.expenseSubcategoryName != nil, id: "chat_guided_category_pick") {
                pickedSubcategory = nil
                showsCategoryPicker = true
            }
            TutorialOptionButton(title: G.valueNoCategory, highlighted: answers.expenseSubcategoryName == nil,
                                 id: "chat_guided_category_none") {
                answer { $0.expenseSubcategoryName = nil }
            }
        }
    }

    // MARK: Los de siempre

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
                           send: @escaping (String) -> Void) -> some View {
        let trimmed = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: DS.Spacing.sm) {
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(.tertiary))
                .font(DS.Typography.body)
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
            if state.kind == .groupOpeningBalance, let sentence = debtSentence {
                Text(sentence)
                    .font(DS.Typography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("chat_guided_debt_sentence")
            }
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
            .disabled(isBusy)
            if state.kind == .groupOpeningBalance,
               let replaced = ChatGuidedCreator.openingBalanceToReplace(answers, context: modelContext) {
                Label(G.debtReplaces(money(replaced.amount, code: replaced.currencyCode)), systemImage: "arrow.triangle.2.circlepath")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("chat_guided_debt_replaces")
            }
            YalaPrimaryButton(createTitle) { create() }
                .disabled(data == nil || isBusy || !ChatGuidedEngine.canCreate(state))
                .accessibilityIdentifier("chat_guided_create")
            if isBusy {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    private var createTitle: String {
        switch state.kind {
        case .groupOpeningBalance: G.confirmSaveDebt
        case .groupExpense: G.confirmSaveExpense
        default: G.confirmCreateGroup
        }
    }

    private var confirmRows: [ChatGuidedConfirmRow.Model] {
        let said = state.prefilled
        let asked = Set(ChatGuidedEngine.askedSteps(state.kind, answers: answers))
        var rows: [ChatGuidedConfirmRow.Model] = []
        func add(_ step: ChatGuidedStep, _ label: String, _ value: String, _ field: ChatGuidedField? = nil) {
            guard asked.contains(step) else { return }
            rows.append(.init(step: step, label: label, value: value, saidByYou: field.map(said.contains) ?? false))
        }
        switch state.kind {
        case .group:
            add(.groupPurpose, G.rowPurpose, answers.groupPurpose.map { Self.purposeTitle($0) } ?? "—")
            add(.groupName, G.rowName, answers.groupName ?? "—", .name)
            add(.groupYourName, G.rowYourName, answers.groupDisplayName ?? "—")
            if asked.contains(.groupCurrencyMode) {
                add(.groupCurrencyMode, G.rowCurrency,
                    answers.groupSingleCurrency == true ? G.valueOneCurrency(currencyTitle(currency)) : G.groupCurrencyEach,
                    .currency)
            }
            // «Todo en una moneda»: cuál, con su propio «Cambiar».
            add(.groupCurrency, G.rowCurrency, currencyTitle(currency), .currency)
            add(.groupSplit, G.rowSplitDefault,
                answers.groupSplitType.flatMap(SplitType.init(rawValue:))?.displayName ?? "—")
        case .groupOpeningBalance:
            add(.groupPick, G.rowGroup, group?.name ?? "—", .group)
            add(.debtDebtor, G.rowDebtor, name(answers.debtorMemberID), .debtor)
            add(.debtCreditor, G.rowCreditor, name(answers.creditorMemberID), .creditor)
            add(.debtAmount, G.rowAmount, answers.amount.map(money) ?? "—", .amount)
            add(.currency, G.rowCurrency, currencyTitle(currency))
        case .groupExpense:
            add(.groupPick, G.rowGroup, group?.name ?? "—", .group)
            add(.expenseDescription, G.rowDescription, answers.expenseDescription ?? "—", .description)
            add(.expenseAmount, G.rowAmount, answers.amount.map(money) ?? "—", .amount)
            add(.expensePayer, G.rowPayer, name(answers.payerMemberID), .payer)
            add(.expenseSplit, G.rowSplit, splitText, .participants)
            add(.expenseAccount, G.rowAccount, data?.account(answers.accountID)?.name ?? "—")
            add(.currency, G.rowCurrency, currencyTitle(currency))
        default:
            break
        }
        rows.append(.init(step: .advanced, label: G.rowAdvanced,
                          value: answers.wantsAdvanced == true ? G.valueReviewed : G.valueDefaults, saidByYou: false))
        if answers.wantsAdvanced == true {
            for step in asked where step.isAdvancedOption {
                switch step {
                case .groupSimplify:
                    add(step, G.rowSimplify, answers.groupSimplifyDebts == false ? G.valueNo : G.valueYes)
                case .debtDate, .expenseDate:
                    add(step, G.rowDate, answers.groupDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? G.valueToday)
                case .expenseCategory:
                    add(step, G.rowCategory, answers.expenseSubcategoryName ?? G.valueNoCategory)
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
        amountFocused = false
        viewModel.answerGuided(messageID: messageID, clearing: fields, change)
    }

    private func create() {
        guard let data, !isBusy else { return }
        if state.kind == .group {
            isCreating = true
            Task { @MainActor in
                errorText = await viewModel.createGuidedGroup(messageID: messageID)
                isCreating = false
            }
        } else {
            errorText = viewModel.createGuided(messageID: messageID, data: data)
        }
    }

    /// Otro grupo cambia la moneda y las personas: lo que dependía de las de antes se vuelve a preguntar.
    private func chooseGroup(_ option: ChatGuidedGroupOption) {
        answer(clearing: [.group]) { answers in
            guard answers.groupZoneID != option.id else { return }
            answers.groupZoneID = option.id
            answers.currencyCode = option.currencyCode
            answers.debtorMemberID = nil
            answers.creditorMemberID = nil
            answers.payerMemberID = nil
            answers.splitMode = nil
            answers.participantIDs = nil
            answers.exactShares = nil
            answers.accountID = nil
        }
    }

    private func chooseCurrency(_ code: String) {
        guard state.step == .currency || state.step == .groupCurrency else { return }
        let normalized = code.uppercased()
        if data?.currencies.contains(normalized) == false { data?.currencies.append(normalized) }
        answer(clearing: [.currency]) { $0.currencyCode = normalized }
    }

    private func applyPickedCurrency() {
        defer { currencyAtOpen = nil }
        guard let opened = currencyAtOpen, currencyPick != opened else { return }
        chooseCurrency(currencyPick.rawValue)
    }

    private func startDraft(_ mode: ChatGuidedSplitMode) {
        DS.Haptic.selection()
        errorText = nil
        splitDraft = mode
        let members = group?.members ?? []
        if pickedPeople.isEmpty { pickedPeople = answers.participantIDs ?? members.map(\.id) }
        if mode == .exact {
            exactRows = members.map { member in
                ExactRow(id: member.id, name: member.isMe ? G.youMember : member.name,
                         text: answers.exactShares?[member.id].map(ChatGuidedCreateFlowCard.amountText) ?? "")
            }
        }
    }

    private func togglePerson(_ id: String) {
        DS.Haptic.selection()
        if let index = pickedPeople.firstIndex(of: id) { pickedPeople.remove(at: index) } else { pickedPeople.append(id) }
    }

    private func answerExact() {
        var shares: [String: Double] = [:]
        for row in exactRows {
            if let value = FirstAccountFlowView.parsed(row.text).map(ChatGuidedEngine.cents), value > 0 {
                shares[row.id] = value
            }
        }
        let participants = exactRows.map(\.id).filter { shares[$0] != nil }
        splitDraft = nil
        answer(clearing: [.participants]) { answers in
            answers.splitMode = .exact
            answers.participantIDs = participants
            answers.exactShares = shares
        }
    }

    /// Al cerrarse el selector de categoría: la elegida contesta.
    private func applyCategory() {
        guard let picked = pickedSubcategory, !picked.isDeleted, picked.modelContext != nil else { return }
        let name = picked.name
        answer { $0.expenseSubcategoryName = name }
    }

    // MARK: - Carga y campos

    private func loadIfNeeded() {
        guard data == nil, state.status == .inProgress else { return }
        var loaded = ChatGuidedDataSource.load(state.kind, context: modelContext, mainCurrency: CurrencyDefaults.currentPreferred)
        var seen = Set(loaded.currencies)
        for code in ["USD", "EUR"] where seen.insert(code).inserted { loaded.currencies.append(code) }
        data = loaded
    }

    /// Lo escrito en los campos empieza con la respuesta que ya hay (al volver atrás o al «Cambiar»).
    private func syncFields() {
        nameText = state.step == .groupYourName ? (answers.groupDisplayName ?? "") : (answers.groupName ?? "")
        descriptionText = answers.expenseDescription ?? ""
        amountText = answers.amount.map(ChatGuidedCreateFlowCard.amountText) ?? ""
        dateValue = answers.groupDate ?? .now
        pickedPeople = answers.participantIDs ?? []
        exactRows = []
        splitDraft = nil
    }

    // MARK: - Textos

    private var typedAmount: Double? {
        guard let value = FirstAccountFlowView.parsed(amountText).map(ChatGuidedEngine.cents),
              ChatGuidedEngine.isValidAmount(value) else { return nil }
        return value
    }

    private func name(_ memberID: String?) -> String {
        guard let member = group?.member(memberID) else { return "—" }
        return member.isMe ? G.youMember : member.name
    }

    /// «Luis le debe S/ 120 a Ana», «Te debe…», «Le debes…».
    private var debtSentence: String? {
        guard let debtor = group?.member(answers.debtorMemberID) else { return nil }
        let amount = answers.amount.map(money) ?? "…"
        guard let creditor = group?.member(answers.creditorMemberID) else { return nil }
        if debtor.isMe { return G.debtSentenceYouOwe(amount, creditor.name) }
        if creditor.isMe { return G.debtSentenceOwesYou(debtor.name, amount) }
        return G.debtSentence(debtor.name, amount, creditor.name)
    }

    private var payerCaption: String? {
        guard answers.payerMemberID != nil else { return nil }
        return G.paidBy(name(answers.payerMemberID))
    }

    private var splitText: String {
        switch answers.splitMode {
        case .equalAll: return G.splitAll
        case .equalSome:
            let names = (answers.participantIDs ?? []).map { name($0) }
            return G.splitSomeValue(names.joined(separator: ", "))
        case .exact:
            let parts = (answers.participantIDs ?? []).compactMap { id in
                answers.exactShares?[id].map { "\(name(id)) \(money($0))" }
            }
            return parts.joined(separator: " · ")
        case nil: return "—"
        }
    }

    private func equalEachText(count: Int) -> String? {
        guard count > 0, let amount = answers.amount else { return nil }
        return G.splitEachPeople(count, money(amount / Double(count)))
    }

    private var currencyOptions: [String] {
        var seen: Set<String> = []
        return ([currency] + (data?.currencies ?? [])).map { $0.uppercased() }.filter { seen.insert($0).inserted }
    }

    private func currencyTitle(_ code: String) -> String {
        let symbol = CurrencyCode(rawValue: code)?.symbol ?? code
        return symbol == code ? code : "\(code) · \(symbol)"
    }

    private func money(_ value: Double) -> String { money(value, code: currency) }

    private func money(_ value: Double, code: String) -> String {
        appPreferences.currency(value, currencyCode: code)
    }

    static func purposeTitle(_ purpose: ChatGuidedGroupPurpose) -> String {
        switch purpose {
        case .trip: L10n.IAGuiados.groupPurposeTrip
        case .home: L10n.IAGuiados.groupPurposeHome
        case .couple: L10n.IAGuiados.groupPurposeCouple
        case .friends: L10n.IAGuiados.groupPurposeFriends
        case .other: L10n.IAGuiados.groupPurposeOther
        }
    }

    static func nameExample(_ purpose: ChatGuidedGroupPurpose?) -> String {
        switch purpose {
        case .trip: L10n.IAGuiados.groupNameExampleTrip
        case .home: L10n.IAGuiados.groupNameExampleHome
        case .couple: L10n.IAGuiados.groupNameExampleCouple
        case .friends: L10n.IAGuiados.groupNameExampleFriends
        case .other, nil: L10n.IAGuiados.groupNameExampleOther
        }
    }

    static func splitHint(_ type: SplitType) -> String {
        switch type {
        case .equal: L10n.IAGuiados.groupSplitEqualHint
        case .percentage: L10n.IAGuiados.groupSplitPercentageHint
        case .exact: L10n.IAGuiados.groupSplitExactHint
        case .shares: L10n.IAGuiados.groupSplitSharesHint
        }
    }
}
