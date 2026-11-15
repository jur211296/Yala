//
//  FirstScheduledPaymentFlowView.swift
//  Yala
//
//  Y23-12 · Paso 4 de Primeros pasos: «Anota tus pagos fijos» (prototipo oficial v35, pestaña 6 · Pagos planificados).
//  Primero la página corta (lo que pagas cada mes · llega a tu Bandeja · te avisamos antes); después cinco pantallas con
//  la fila del pago llenándose arriba: el tipo (seis subcategorías del seed u «Otra subcategoría», y «Es una
//  suscripción») → nombre y monto (precargado con el tipo, ejemplos y «Cambia cada vez») → cuándo → el aviso (aquí se
//  piden o reintentan las notificaciones, Y23-17) → ¿Lo ponemos en tu Panel? → ¡Listo! con «Anotar otro pago». Las
//  reglas, en `FirstScheduledPaymentFlowLogic`; el guardado, en `PrimerosPasosPlanningCreator`. Fuera de alcance (ficha):
//  «Cada N», los plazos de 2, 5, 7, 14 y 30 días y el gasto compartido, que siguen en el editor.
//

import SwiftData
import SwiftUI

struct FirstScheduledPaymentFlowView: View {
    typealias Logic = FirstScheduledPaymentFlowLogic
    private typealias T = L10n.PrimerosPasos23.Payment
    private typealias P = L10n.PrimerosPasos23.Plan

    /// Se guardó un pago. Lo apunta quien presenta la pantalla, por si su contenido se rehace antes de cerrarla.
    var onSaved: () -> Void = {}
    let onClose: (PrimerosPasosPlanningResult) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppPreferences.self) private var appPreferences

    @State private var showsIntro = true
    @State private var introPart = 0
    @State private var step: Logic.Step = .kind
    @State private var history: [Logic.Step] = []
    @State private var draft = FirstScheduledPaymentDraft()
    @State private var didLoad = false
    @State private var createdCount = 0
    @State private var lastDueDate: Date?
    @State private var saveFailed = false

    // Datos de la persona.
    @State private var kindSubcategories: [Logic.Kind: Subcategory] = [:]
    @State private var otherSubcategory: Subcategory?
    @State private var showsOtherPicker = false
    /// La de «Otra subcategoría» al abrir su hoja: cerrarla sin elegir no cambia nada.
    @State private var otherAtOpen: PersistentIdentifier?
    @State private var accountName = ""
    @State private var currencyCode = CurrencyCode.usd.rawValue

    // Lo que se escribe.
    @State private var amountText = ""
    @State private var otherDayText = ""
    @State private var editsOtherDay = false
    @State private var notificationAsk: TutorialPermissionLogic.NotificationAsk = .nothing
    @FocusState private var nameFocused: Bool
    @FocusState private var amountFocused: Bool
    @FocusState private var dayFocused: Bool

    var body: some View {
        ZStack {
            if showsIntro {
                FirstScheduledPaymentIntroPage(
                    part: $introPart,
                    currencyCode: currencyCode,
                    onBack: { onClose(.closed) },
                    onStart: startQuestions,
                    onSkip: { onClose(.skipped) }
                )
                .transition(.opacity)
            } else {
                questions.transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: showsIntro)
        .yalaScreenBackground(.panel)
        .onAppear(perform: loadIfNeeded)
        .sheet(isPresented: $showsOtherPicker, onDismiss: applyOtherSubcategory) {
            SubcategorySelectorSheet(selectedSubcategory: $otherSubcategory, transactionType: .expense)
        }
        .tutorialNotificationRetry(ask: $notificationAsk)
        .onChange(of: notificationAsk) { old, new in
            // La hoja o la alerta del aviso se cerró: sigue la pregunta del Panel.
            if old != .nothing, new == .nothing, step == .reminder { advance() }
        }
        .alert(L10n.Common.error, isPresented: $saveFailed) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Common.saveError)
        }
    }

    // MARK: - Preguntas

    private var questions: some View {
        TutorialQuestionScreen(
            subtitle: T.chatSubtitle,
            stepCount: Logic.steps.count,
            stepIndex: Logic.steps.firstIndex(of: step) ?? 0,
            isDone: step == .done,
            question: questionTitle,
            detail: questionDetail,
            identity: "\(step)-\(createdCount)",
            backID: "first_payment_back",
            onBack: goBack,
            card: {
                if step != .kind || !draft.name.isEmpty {
                    FirstPaymentCardPreview(
                        name: draft.name,
                        look: look,
                        due: dueText,
                        amount: draft.amount.map { appPreferences.currency($0, currencyCode: currencyCode) },
                        isEstimate: draft.isVariableAmount,
                        subcategoryName: selectedSubcategory?.name,
                        accountName: accountName,
                        isSubscription: draft.isSubscription,
                        summary: summary
                    )
                }
            },
            dock: { dock }
        )
    }

    private var questionTitle: String {
        switch step {
        case .kind: return T.kindQuestion
        case .details: return T.detailsQuestion
        case .when: return T.whenQuestion
        case .reminder: return T.reminderQuestion
        case .panel: return P.panelQuestion
        case .done: return P.done
        }
    }

    private var questionDetail: String? {
        switch step {
        case .kind: return T.kindSubtitle
        case .details:
            let type = draft.kind.map(kindTitle) ?? selectedSubcategory?.name ?? ""
            return accountName.isEmpty ? type : T.detailsSubtitle(type, accountName)
        case .when: return nil
        case .reminder: return T.reminderSubtitle
        case .panel: return T.panelSubtitle
        case .done: return lastDueDate.map { T.doneMessage(ScheduledPaymentDateText.dayMonthLong($0)) }
        }
    }

    @ViewBuilder
    private var dock: some View {
        switch step {
        case .kind: kindDock
        case .details: detailsDock
        case .when: whenDock
        case .reminder:
            VStack(spacing: DS.Spacing.sm) {
                TutorialOptionButton(title: T.reminderThreeDays, highlighted: true,
                                     id: "first_payment_reminder_3") { chooseReminder(.threeDaysBefore) }
                TutorialOptionButton(title: T.reminderOneDay, id: "first_payment_reminder_1") { chooseReminder(.oneDayBefore) }
                TutorialOptionButton(title: T.reminderSameDay, id: "first_payment_reminder_0") { chooseReminder(.sameDay) }
                TutorialOptionButton(title: P.noThanks, id: "first_payment_reminder_none") { chooseReminder(.none) }
            }
        case .panel:
            VStack(spacing: DS.Spacing.sm) {
                TutorialOptionButton(title: P.panelYes, subtitle: T.panelYesHint, highlighted: true, vibrates: false,
                                     id: "first_payment_panel_yes") { choosePanel(true) }
                TutorialOptionButton(title: P.panelNo, vibrates: false, id: "first_payment_panel_no") {
                    choosePanel(false)
                }
            }
        case .done:
            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(P.seePanel) { onClose(createdCount > 0 ? .created : .closed) }
                    .accessibilityIdentifier("first_payment_done")
                    .primerosPasosButtonText()
                // Los pagos planificados no tienen límite en el plan gratis (`ProFeature`).
                Button(T.doneAnother) { startAnother() }
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(.thAccentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("first_payment_another")
            }
        }
    }

    // MARK: Pantalla 1 · el tipo

    private var kindDock: some View {
        VStack(spacing: DS.Spacing.md) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm),
                                     count: TutorialGridColumns.count(3, dynamicTypeSize: dynamicTypeSize)),
                      spacing: DS.Spacing.sm) {
                ForEach(Logic.Kind.allCases.filter { kindSubcategories[$0] != nil }) { kind in
                    TutorialSelectableTile(
                        icon: kind.seedIcon,
                        color: color(of: kindSubcategories[kind]),
                        title: kindTitle(kind),
                        isOn: draft.kind == kind,
                        id: "first_payment_kind_\(kind.rawValue)"
                    ) { choose(kind) }
                }
            }
            if draft.kind == nil, let other = otherSubcategory, draft.subcategoryID == other.persistentModelID {
                otherCard(other)
            } else {
                Button(T.otherSubcategory) { openOtherPicker() }
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(.thAccentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("first_payment_other")
            }
            TutorialToggleRow(title: T.isSubscription, hint: T.isSubscriptionHint, isOn: $draft.isSubscription,
                              id: "first_payment_is_subscription")
            YalaPrimaryButton(L10n.Action.continueAction) { advance() }
                .disabled(draft.subcategoryID == nil)
                .accessibilityIdentifier("first_payment_kind_continue")
                .primerosPasosButtonText()
        }
    }

    private func otherCard(_ subcategory: Subcategory) -> some View {
        let color = color(of: subcategory)
        return Button { openOtherPicker() } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: subcategory.iconName ?? "tag.fill")
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(color))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(subcategory.name).font(DS.Typography.body.weight(.semibold)).foregroundStyle(.primary)
                    Text(subcategory.category?.name ?? "").font(DS.Typography.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Spacing.sm)
                Text(T.change).font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(.thAccentText)
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card)
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(color, lineWidth: 2))
        )
        .accessibilityIdentifier("first_payment_other_chosen")
    }

    // MARK: Pantalla 2 · nombre y monto

    private var detailsDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(T.detailsName).font(DS.Typography.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: DS.Spacing.sm) {
                    TextField("", text: $draft.name, prompt: Text(T.detailsNamePlaceholder).foregroundStyle(.tertiary))
                        .font(DS.Typography.body)
                        .focused($nameFocused)
                        .submitLabel(.next)
                        .onSubmit {
                            // El monto no está montado mientras se escribe el nombre: se enfoca cuando aparece.
                            nameFocused = false
                            focusSoon { amountFocused = true }
                        }
                        .accessibilityLabel(T.detailsName)
                        .accessibilityIdentifier("first_payment_name")
                    if !draft.name.isEmpty {
                        Button {
                            draft.name = ""
                            nameFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(T.detailsClearName)
                        .accessibilityIdentifier("first_payment_name_clear")
                    }
                }
                .padding(.leading, DS.Spacing.md)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                if let kind = draft.kind, !nameFocused, !amountFocused {
                    FlowLayout(spacing: DS.Spacing.sm) {
                        ForEach(examples(for: kind), id: \.self) { example in
                            TutorialChip(title: example, isOn: draft.name == example, id: "first_payment_example") {
                                draft.name = example
                            }
                        }
                    }
                }
            }
            if !nameFocused {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(T.detailsAmount).font(DS.Typography.caption.weight(.semibold)).foregroundStyle(.secondary)
                    // El envío va junto al campo (como el tope del presupuesto): con el teclado abierto, «Continuar» queda
                    // debajo de él.
                    HStack(spacing: DS.Spacing.sm) {
                        TutorialAmountField(
                            text: $amountText,
                            currencySymbol: CurrencyCode(rawValue: currencyCode)?.symbol ?? currencyCode,
                            accessibilityLabel: T.detailsAmount,
                            id: "first_payment_amount",
                            focus: $amountFocused
                        )
                        if amountFocused {
                            TutorialSendButton(enabled: canContinueDetails, id: "first_payment_amount_send") {
                                afterDetails()
                            }
                        }
                    }
                }
            }
            if !nameFocused && !amountFocused {
                TutorialToggleRow(title: T.detailsVariable, hint: T.detailsVariableHint, isOn: $draft.isVariableAmount,
                                  id: "first_payment_variable")
            }
            YalaPrimaryButton(L10n.Action.continueAction) { afterDetails() }
                .disabled(!canContinueDetails)
                .accessibilityIdentifier("first_payment_details_continue")
                .primerosPasosButtonText()
        }
    }

    // MARK: Pantalla 3 · cuándo

    private var whenDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(Logic.Frequency.allCases) { frequency in
                    TutorialChip(title: frequencyTitle(frequency), isOn: draft.frequency == frequency,
                                 id: "first_payment_frequency_\(frequency.rawValue)") {
                        draft.frequency = frequency
                        editsOtherDay = false
                    }
                }
            }
            switch draft.frequency {
            case .monthly: monthDayRow
            case .weekly: weekdayRow
            case .yearly, .once:
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(T.whenDate).font(DS.Typography.caption.weight(.semibold)).foregroundStyle(.secondary)
                    DatePicker(T.whenDate, selection: $draft.date, in: Calendar.current.startOfDay(for: .now)...,
                               displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("first_payment_date")
                }
            }
            YalaPrimaryButton(L10n.Action.continueAction) { afterWhen() }
                .disabled(draft.frequency == .monthly && editsOtherDay && !isValidOtherDay)
                .accessibilityIdentifier("first_payment_when_continue")
                .primerosPasosButtonText()
        }
    }

    private var canContinueDetails: Bool {
        Logic.canContinueDetails(name: draft.name, amount: FirstAccountFlowView.parsed(amountText))
    }

    private var isValidOtherDay: Bool {
        Int(otherDayText).map(Logic.isValidMonthDay) ?? false
    }

    private var monthDayRow: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(T.whenDayOfMonth).font(DS.Typography.caption.weight(.semibold)).foregroundStyle(.secondary)
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(Logic.monthDayShortcuts, id: \.self) { day in
                    TutorialChip(title: "\(day)", isOn: !editsOtherDay && draft.dayOfMonth == day,
                                 id: "first_payment_day_\(day)") {
                        editsOtherDay = false
                        dayFocused = false
                        draft.dayOfMonth = day
                    }
                }
                TutorialChip(title: T.whenOtherDay, isOn: editsOtherDay, id: "first_payment_day_other") {
                    editsOtherDay = true
                    otherDayText = ""
                    focusSoon { dayFocused = true }
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
                    .accessibilityLabel(T.whenDayOfMonth)
                    .accessibilityIdentifier("first_payment_day_field")
                    .onChange(of: otherDayText) { _, text in
                        if let day = Int(text), Logic.isValidMonthDay(day) { draft.dayOfMonth = day }
                    }
                TutorialSendButton(enabled: isValidOtherDay, id: "first_payment_day_send") { afterWhen() }
                }
            }
        }
    }

    private var weekdayRow: some View {
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(T.whenWeekday).font(DS.Typography.caption.weight(.semibold)).foregroundStyle(.secondary)
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(Logic.weekdaysMondayFirst, id: \.self) { weekday in
                    TutorialChip(title: symbols[weekday - 1], isOn: draft.weekday == weekday,
                                 id: "first_payment_weekday_\(weekday)") { draft.weekday = weekday }
                }
            }
        }
    }

    // MARK: - Tarjeta

    private var selectedSubcategory: Subcategory? {
        if let kind = draft.kind { return kindSubcategories[kind] }
        return otherSubcategory
    }

    private var look: (icon: String, color: Color) {
        (draft.kind?.seedIcon ?? selectedSubcategory?.iconName ?? "calendar.badge.clock", color(of: selectedSubcategory))
    }

    private func color(of subcategory: Subcategory?) -> Color {
        if let hex = subcategory?.category?.colorHex { return Color(hex: hex) }
        return theme.accent
    }

    /// La fecha del primer pago con lo elegido hasta ahora (la misma cuenta que el editor).
    private var firstDue: Date? {
        guard step != .kind, step != .details || draft.amount != nil else { return nil }
        let calendar = Calendar.current
        let frequency = draft.frequency
        guard frequency.isRecurring else { return calendar.startOfDay(for: draft.date) }
        return ScheduledPaymentEditorViewModel.firstDueDate(
            start: calendar.startOfDay(for: .now),
            recurrenceType: frequency.recurrenceType,
            recurrenceInterval: 1,
            dayOfMonth: frequency == .monthly ? draft.dayOfMonth : nil,
            weekdays: frequency == .weekly ? String(draft.weekday) : "",
            yearlyMonth: frequency == .yearly ? calendar.component(.month, from: draft.date) : nil,
            yearlyDay: frequency == .yearly ? calendar.component(.day, from: draft.date) : nil,
            endDate: nil
        )
    }

    private var dueText: String? {
        guard step == .when || step == .reminder || step == .panel || step == .done, let due = firstDue else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: due)).day ?? 0
        switch days {
        case ..<1: return L10n.UXL10.stateToday
        case 1: return L10n.UXL10.stateTomorrow
        default: return L10n.UXL10.stateInDays(days)
        }
    }

    /// «≈ S/ 80.00 cada mes, el día 1. Primer pago: 1 de diciembre.» (el resumen del editor).
    private var summary: String? {
        guard let amount = draft.amount, let due = dueText != nil ? firstDue : nil else { return nil }
        let amountText = appPreferences.currency(amount, currencyCode: currencyCode, forceFullPrecision: true,
                                                 isEstimate: draft.isVariableAmount)
        let dueDay = Calendar.current.isDateInToday(due) ? L10n.UXL10.today : ScheduledPaymentDateText.dayMonthLong(due)
        switch draft.frequency {
        case .once: return L10n.UXL10.summaryOnce(amountText, dueDay)
        case .monthly:
            return L10n.UXL10.summaryRecurring(amountText, L10n.UXL10.cadenceMonthly(interval: 1, day: draft.dayOfMonth), dueDay)
        case .weekly:
            return L10n.UXL10.summaryRecurring(amountText, L10n.UXL10.cadenceWeekly(interval: 1), dueDay)
        case .yearly:
            let cadence = L10n.UXL10.cadenceYearly(interval: 1, date: ScheduledPaymentDateText.dayMonthLong(draft.date))
            return L10n.UXL10.summaryRecurring(amountText, cadence, dueDay)
        }
    }

    // MARK: - Textos

    private func kindTitle(_ kind: Logic.Kind) -> String {
        switch kind {
        case .rent: return T.kindRent
        case .utilities: return T.kindUtilities
        case .phone: return T.kindPhone
        case .utilitySubscription: return T.kindUtilitySubscription
        case .leisureSubscription: return T.kindLeisureSubscription
        case .fitness: return T.kindFitness
        }
    }

    private func prefilledName(_ kind: Logic.Kind) -> String {
        switch kind {
        case .rent: return T.nameRent
        case .utilities: return T.nameUtilities
        case .phone: return T.namePhone
        case .utilitySubscription, .leisureSubscription: return T.nameSubscription
        case .fitness: return T.nameFitness
        }
    }

    private func examples(for kind: Logic.Kind) -> [String] {
        switch kind {
        case .rent: return [T.exampleRent1, T.exampleRent2, T.exampleRent3]
        case .utilities: return [T.exampleUtilities1, T.exampleUtilities2, T.exampleUtilities3]
        case .phone: return [T.examplePhone1, T.examplePhone2, T.examplePhone3]
        case .utilitySubscription:
            return [T.exampleUtilitySubscription1, T.exampleUtilitySubscription2, T.exampleUtilitySubscription3]
        case .leisureSubscription:
            return [T.exampleLeisureSubscription1, T.exampleLeisureSubscription2, T.exampleLeisureSubscription3]
        case .fitness: return [T.exampleFitness1, T.exampleFitness2, T.exampleFitness3]
        }
    }

    private func frequencyTitle(_ frequency: Logic.Frequency) -> String {
        switch frequency {
        case .monthly: return T.whenMonthly
        case .weekly: return T.whenWeekly
        case .yearly: return T.whenYearly
        case .once: return T.whenOnce
        }
    }

    // MARK: - Avance

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        let viewModel = ScheduledPaymentEditorViewModel()
        viewModel.setContext(modelContext, deletionService: EntityDeletionService.shared)
        let account = viewModel.lastUsedAccount() ?? viewModel.activeAccounts.first
        accountName = account?.name ?? ""
        currencyCode = account?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue
        do {
            let subcategories = try modelContext.fetch(FetchDescriptor<Subcategory>())
                .filter { $0.isVisible && !$0.isAnySystem && $0.category?.isIncome == false }
            var found: [Logic.Kind: Subcategory] = [:]
            for kind in Logic.Kind.allCases {
                found[kind] = subcategories.first { $0.isDefaultSeed && $0.iconName == kind.seedIcon }
                    ?? subcategories.first { $0.iconName == kind.seedIcon }
            }
            kindSubcategories = found
        } catch {
            #if DEBUG
            print("FirstScheduledPaymentFlowView: Error: loading subcategories: \(error)")
            #endif
        }
    }

    private func startQuestions() {
        DS.Haptic.selection()
        history = []
        step = .kind
        showsIntro = false
    }

    private func advance() {
        nameFocused = false
        amountFocused = false
        dayFocused = false
        history.append(step)
        step = Logic.next(after: step)
    }

    private func goBack() {
        guard step != .done, let previous = history.popLast() else {
            if createdCount > 0 { onClose(.created) } else { showsIntro = true }
            return
        }
        nameFocused = false
        amountFocused = false
        dayFocused = false
        step = previous
    }

    private func choose(_ kind: Logic.Kind) {
        guard let subcategory = kindSubcategories[kind] else { return }
        otherSubcategory = nil
        draft.kind = kind
        draft.subcategoryID = subcategory.persistentModelID
        draft.name = prefilledName(kind)
        draft.isVariableAmount = kind.isVariableAmount
        draft.isSubscription = kind.isSubscription
    }

    private func openOtherPicker() {
        otherAtOpen = otherSubcategory?.persistentModelID
        showsOtherPicker = true
    }

    /// Al cerrarse la hoja de «Otra subcategoría»: la elegida queda como tarjeta y precarga el nombre. Cerrarla sin
    /// elegir otra no toca lo que había.
    private func applyOtherSubcategory() {
        guard let other = otherSubcategory, other.persistentModelID != otherAtOpen else { return }
        draft.kind = nil
        draft.subcategoryID = other.persistentModelID
        draft.name = other.name
        draft.isVariableAmount = false
        draft.isSubscription = false
    }

    private func afterDetails() {
        guard let amount = FirstAccountFlowView.parsed(amountText),
              Logic.canContinueDetails(name: draft.name, amount: amount) else { return }
        draft.amount = amount
        advance()
    }

    private func afterWhen() {
        if draft.frequency == .monthly, editsOtherDay {
            guard let day = Int(otherDayText), Logic.isValidMonthDay(day) else { return }
            draft.dayOfMonth = day
        }
        advance()
    }

    /// Y23-17: con un aviso elegido, si iOS nunca preguntó, la hoja de la app «¿Te avisamos antes de cada pago?» y luego
    /// el aviso de iOS; si se negó, «Activa las notificaciones» con «Ir a Configuración». Al cerrarse, sigue.
    private func chooseReminder(_ reminder: Logic.Reminder) {
        // Un segundo toque mientras se mira el permiso no avanza dos veces (se saltaría el guardado).
        guard step == .reminder, notificationAsk == .nothing else { return }
        draft.reminder = reminder
        guard reminder.wantsReminder else {
            advance()
            return
        }
        Task { @MainActor in
            #if DEBUG
            if UITestHooks.isActive {
                guard step == .reminder else { return }
                advance()
                return
            }
            #endif
            let ask = await TutorialPermissionMoments.scheduledPaymentReminderAsk(wantsReminder: true)
            guard step == .reminder, draft.reminder == reminder, notificationAsk == .nothing else { return }
            if ask == .nothing { advance() } else { notificationAsk = ask }
        }
    }

    /// La última respuesta: se guarda el pago. Si falla, se queda en la pregunta (sale el aviso y se reintenta).
    private func choosePanel(_ shows: Bool) {
        guard step == .panel else { return }
        draft.showsInPanel = shows
        do {
            let payment = try PrimerosPasosPlanningCreator.createScheduledPayment(
                draft, defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue, in: modelContext)
            lastDueDate = payment.nextDueDate
        } catch {
            #if DEBUG
            print("FirstScheduledPaymentFlowView: Error: creating the payment: \(error)")
            #endif
            saveFailed = true
            return
        }
        if shows { PrimerosPasosPlanningCreator.showInPanel(.scheduledPayments, preferences: appPreferences) }
        onSaved()
        createdCount += 1
        history = []
        DS.Haptic.success()
        step = .done
    }

    private func startAnother() {
        DS.Haptic.selection()
        draft = FirstScheduledPaymentDraft()
        otherSubcategory = nil
        amountText = ""
        otherDayText = ""
        editsOtherDay = false
        history = []
        step = .kind
    }

    private func focusSoon(_ apply: @escaping () -> Void) {
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            apply()
        }
    }
}

// MARK: - Tarjeta del pago, llenándose arriba

struct FirstPaymentCardPreview: View {
    let name: String
    let look: (icon: String, color: Color)
    let due: String?
    let amount: String?
    let isEstimate: Bool
    let subcategoryName: String?
    let accountName: String
    let isSubscription: Bool
    let summary: String?

    @Environment(\.yalaTheme) private var theme

    private typealias T = L10n.PrimerosPasos23.Payment

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            FirstPaymentRowPreview(
                name: name.isEmpty ? T.cardPlaceholder : name,
                icon: look.icon,
                color: look.color,
                due: due,
                amount: amount ?? "—",
                isEstimate: isEstimate && amount != nil
            )
            FlowLayout(spacing: DS.Spacing.xs) {
                if let subcategoryName { metaChip(icon: look.icon, text: subcategoryName) }
                if !accountName.isEmpty { metaChip(icon: "building.columns", text: accountName) }
                if isSubscription { metaChip(icon: "repeat", text: L10n.Scheduled.Category.subscription) }
            }
            if let summary {
                Text(summary)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("first_payment_summary")
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(theme.card.opacity(0.6)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("first_payment_card")
    }

    private func metaChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
    }
}
