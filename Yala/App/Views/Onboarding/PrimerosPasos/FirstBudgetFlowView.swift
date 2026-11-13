//
//  FirstBudgetFlowView.swift
//  Yala
//
//  Y23-11 · Paso 3 de Primeros pasos: «Crea tu primer presupuesto» (prototipo oficial v35, pestaña 5 · Primer
//  presupuesto). Primero la página corta (tres partes: un tope, tú eliges qué cuenta, Yala te avisa); después, preguntas
//  con la tarjeta del presupuesto llenándose arriba: ¿Qué gastos cuenta? → (¿Cuáles? → ¿Algo que no quieras contar?) →
//  ¿Cada cuánto se renueva? → (fechas) → tope → nombre → avisos → ¿Lo ponemos en tu Panel? → ¡Listo!. Las reglas, en
//  `FirstBudgetFlowLogic`; el guardado, en `PrimerosPasosPlanningCreator`. Fuera de alcance (ficha): cuentas, etiquetas,
//  necesidad, gastos de grupo, 50 %/90 % y personalizar, que siguen en Editar presupuesto, y sugerir el monto.
//

import SwiftData
import SwiftUI

/// Cómo termina un flujo de los pasos 3 y 4.
enum PrimerosPasosPlanningResult: Equatable {
    /// Se guardó al menos uno.
    case created
    /// «Omitir este paso».
    case skipped
    /// Se cerró sin guardar ni omitir: el mazo sigue en el paso.
    case closed
}

struct FirstBudgetFlowView: View {
    typealias Logic = FirstBudgetFlowLogic
    private typealias T = L10n.PrimerosPasos23.Budget
    private typealias P = L10n.PrimerosPasos23.Plan

    /// Se guardó el presupuesto. Lo apunta quien presenta la pantalla, por si su contenido se rehace antes de cerrarla.
    var onSaved: () -> Void = {}
    let onClose: (PrimerosPasosPlanningResult) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppPreferences.self) private var appPreferences

    @State private var showsIntro = true
    @State private var introPart = 0
    @State private var step: Logic.Step = .scope
    @State private var history: [Logic.Step] = []
    @State private var draft = FirstBudgetDraft(currencyCode: CurrencyCode.usd.rawValue)
    @State private var didLoad = false
    @State private var created = false
    @State private var saveFailed = false
    /// Se pidió y concedió el permiso de notificaciones para el aviso: al guardar, se encienden las alertas de presupuesto.
    @State private var enablesBudgetAlerts = false

    // Datos de la persona.
    @State private var categories: [Category] = []
    @State private var transactions: [TransactionItem] = []
    @State private var chosenCategories: [PersistentIdentifier] = []
    @State private var removedSubcategories: Set<UUID> = []

    // Lo que se escribe.
    @State private var limitText = ""
    @State private var editsName = false
    @State private var nameText = ""
    @FocusState private var limitFocused: Bool
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            if showsIntro {
                FirstBudgetIntroPage(
                    part: $introPart,
                    examples: categories,
                    currencyCode: draft.currencyCode,
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
        .alert(L10n.Common.error, isPresented: $saveFailed) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Common.saveError)
        }
    }

    // MARK: - Preguntas

    private var allSteps: [Logic.Step] { Logic.steps(scope: draft.scope, period: draft.period) }

    private var questions: some View {
        TutorialQuestionScreen(
            subtitle: T.chatSubtitle,
            stepCount: allSteps.count,
            stepIndex: allSteps.firstIndex(of: step) ?? 0,
            isDone: step == .done,
            question: questionTitle,
            detail: questionDetail,
            identity: "\(step)-\(editsName)",
            backID: "first_budget_back",
            onBack: goBack,
            card: {
                if step != .categories && step != .subcategories {
                    FirstBudgetCardPreview(
                        name: draft.name.isEmpty ? (draft.scope == nil ? "" : suggestedName) : draft.name,
                        isNamePlaceholder: draft.name.isEmpty,
                        look: cardLook,
                        caption: cardCaption,
                        limit: draft.limit,
                        spent: spentInDraft,
                        currencyCode: draft.currencyCode,
                        alert: draft.alert
                    )
                }
            },
            dock: { dock }
        )
    }

    private var questionTitle: String {
        switch step {
        case .scope: return T.scopeQuestion
        case .categories: return T.categoriesQuestion
        case .subcategories: return T.subcategoriesQuestion
        case .period: return T.periodQuestion
        case .dates: return T.datesQuestion
        case .limit:
            switch draft.period ?? .monthly {
            case .weekly: return T.limitQuestionWeekly
            case .yearly: return T.limitQuestionYearly
            case .unique: return T.limitQuestionOnce
            case .monthly: return T.limitQuestionMonthly
            }
        case .name: return editsName ? T.nameEditQuestion : T.nameQuestion(suggestedName)
        case .alert: return T.alertQuestion
        case .panel: return P.panelQuestion
        case .done: return P.done
        }
    }

    private var questionDetail: String? {
        switch step {
        case .scope: return T.scopeSubtitle
        case .categories: return T.categoriesSubtitle
        case .subcategories: return T.subcategoriesSubtitle
        case .period: return T.periodSubtitle
        case .dates: return T.datesSubtitle
        case .limit:
            let spent = spentThisMonth(subcategoryIDs: currentSubcategoryIDs)
            return spent > 0 ? T.limitSpentSoFar(money(spent)) : T.limitRoundNumber
        case .name: return T.nameSubtitle
        case .alert: return T.alertSubtitle
        case .panel: return T.panelSubtitle
        case .done: return draft.showsInPanel == true ? T.doneMessagePanel(draft.name) : T.doneMessage(draft.name)
        }
    }

    @ViewBuilder
    private var dock: some View {
        switch step {
        case .scope:
            VStack(spacing: DS.Spacing.sm) {
                TutorialOptionButton(title: T.scopeAll, subtitle: T.scopeAllHint, icon: "chart.pie.fill",
                                     id: "first_budget_scope_all") { chooseScope(.all) }
                TutorialOptionButton(title: T.scopeCategories, subtitle: T.scopeCategoriesHint, icon: "square.grid.2x2.fill",
                                     highlighted: true, id: "first_budget_scope_categories") { chooseScope(.categories) }
            }
        case .categories: categoriesDock
        case .subcategories: subcategoriesDock
        case .period: periodDock
        case .dates: datesDock
        case .limit: limitDock
        case .name: nameDock
        case .alert:
            VStack(spacing: DS.Spacing.sm) {
                TutorialOptionButton(title: T.alertAt75, subtitle: T.alertAt75Hint, highlighted: true,
                                     id: "first_budget_alert_75") { chooseAlert(.at75And100) }
                TutorialOptionButton(title: T.alertAt100, id: "first_budget_alert_100") { chooseAlert(.at100) }
                TutorialOptionButton(title: P.noThanks, id: "first_budget_alert_none") { chooseAlert(.none) }
            }
        case .panel:
            VStack(spacing: DS.Spacing.sm) {
                TutorialOptionButton(title: P.panelYes, subtitle: T.panelYesHint, highlighted: true, vibrates: false,
                                     id: "first_budget_panel_yes") { choosePanel(true) }
                TutorialOptionButton(title: P.panelNo, vibrates: false, id: "first_budget_panel_no") {
                    choosePanel(false)
                }
            }
        case .done:
            YalaPrimaryButton(P.seePanel) { onClose(created ? .created : .closed) }
                .accessibilityIdentifier("first_budget_done")
                .primerosPasosButtonText()
        }
    }

    // MARK: ¿Cuáles? y ¿Algo que no quieras contar?

    private var categoriesDock: some View {
        VStack(spacing: DS.Spacing.md) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm),
                                     count: TutorialGridColumns.count(3, dynamicTypeSize: dynamicTypeSize)),
                      spacing: DS.Spacing.sm) {
                ForEach(categories) { category in
                    let spent = spentThisMonth(subcategoryIDs: subcategoryIDs(of: category))
                    TutorialSelectableTile(
                        icon: category.iconName ?? "tag.fill",
                        color: Color(hex: category.colorHex),
                        title: category.name,
                        caption: spent > 0 ? T.categoriesSpent(money(spent)) : nil,
                        isOn: chosenCategories.contains(category.persistentModelID),
                        id: "first_budget_category"
                    ) { toggle(category) }
                }
            }
            YalaPrimaryButton(L10n.Action.continueAction) { afterCategories() }
                .disabled(chosenCategories.isEmpty)
                .accessibilityIdentifier("first_budget_categories_continue")
                .primerosPasosButtonText()
        }
    }

    private var subcategoriesDock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ForEach(chosenCategoryModels) { category in
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Label {
                        Text(category.name).font(DS.Typography.subheadline.weight(.semibold))
                    } icon: {
                        Circle().fill(Color(hex: category.colorHex)).frame(width: 10, height: 10)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.xs),
                                             count: TutorialGridColumns.count(4, dynamicTypeSize: dynamicTypeSize)),
                              spacing: DS.Spacing.sm) {
                        ForEach(visibleSubcategories(of: category)) { sub in
                            subcategoryCircle(sub, color: Color(hex: category.colorHex))
                        }
                    }
                }
            }
            YalaPrimaryButton(L10n.Action.continueAction) { advance() }
                .disabled(!Logic.canContinueSubcategories(
                    scope: draft.scope, chosen: chosenSubcategoryGroups, removed: removedSubcategories))
                .accessibilityIdentifier("first_budget_subcategories_continue")
                .primerosPasosButtonText()
        }
    }

    private func subcategoryCircle(_ sub: Subcategory, color: Color) -> some View {
        let isOn = !removedSubcategories.contains(sub.shortcutID)
        return Button {
            DS.Haptic.selection()
            if isOn { removedSubcategories.insert(sub.shortcutID) } else { removedSubcategories.remove(sub.shortcutID) }
        } label: {
            VStack(spacing: DS.Spacing.xxs) {
                Image(systemName: sub.iconName ?? "circle.fill")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(isOn ? Color.white : color)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(isOn ? color : color.opacity(0.15)))
                    .overlay(alignment: .topTrailing) {
                        if isOn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.white, color)
                                .offset(x: 4, y: -4)
                        }
                    }
                    .accessibilityHidden(true)
                Text(sub.name)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(isOn ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("first_budget_subcategory")
    }

    // MARK: Período, fechas, tope y nombre

    private var periodDock: some View {
        let options: [(BudgetPeriodType, String, String)] = [
            (.monthly, BudgetPeriodType.monthly.localizedName, T.periodMonthlyHint),
            (.weekly, BudgetPeriodType.weekly.localizedName, T.periodWeeklyHint),
            (.yearly, BudgetPeriodType.yearly.localizedName, T.periodYearlyHint),
            (.unique, T.periodOnce, T.periodOnceHint),
        ]
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(options, id: \.0) { period, title, hint in
                TutorialOptionButton(title: title, subtitle: hint, highlighted: period == .monthly,
                                     id: "first_budget_period_\(period.rawValue)") { choosePeriod(period) }
            }
        }
    }

    private var datesDock: some View {
        VStack(spacing: DS.Spacing.md) {
            VStack(spacing: 0) {
                DatePicker(T.datesFrom, selection: $draft.startDate, displayedComponents: .date)
                    .padding(DS.Spacing.md)
                Divider()
                DatePicker(T.datesTo, selection: $draft.endDate, in: draft.startDate..., displayedComponents: .date)
                    .padding(DS.Spacing.md)
            }
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
            YalaPrimaryButton(L10n.Action.continueAction) { afterDates() }
                .disabled(!Logic.isValidRange(start: draft.startDate, end: draft.endDate))
                .accessibilityIdentifier("first_budget_dates_continue")
                .primerosPasosButtonText()
        }
    }

    private var limitDock: some View {
        let value = FirstAccountFlowView.parsed(limitText)
        return HStack(spacing: DS.Spacing.sm) {
            TutorialAmountField(
                text: $limitText,
                currencySymbol: CurrencyCode(rawValue: draft.currencyCode)?.symbol ?? draft.currencyCode,
                accessibilityLabel: questionTitle,
                id: "first_budget_limit",
                focus: $limitFocused
            )
            TutorialSendButton(enabled: Logic.isValidLimit(value), id: "first_budget_limit_send") {
                guard let value, Logic.isValidLimit(value) else { return }
                draft.limit = value
                advance()
            }
        }
    }

    @ViewBuilder
    private var nameDock: some View {
        if editsName {
            let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
            HStack(spacing: DS.Spacing.sm) {
                TextField("", text: $nameText, prompt: Text(T.namePlaceholder).foregroundStyle(.tertiary))
                    .font(DS.Typography.body)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { if !trimmed.isEmpty { chooseName(trimmed) } }
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                    .accessibilityIdentifier("first_budget_name_field")
                TutorialSendButton(enabled: !trimmed.isEmpty, id: "first_budget_name_send") { chooseName(trimmed) }
            }
        } else {
            VStack(spacing: DS.Spacing.sm) {
                TutorialOptionButton(title: T.nameYes, highlighted: true, id: "first_budget_name_yes") {
                    chooseName(suggestedName)
                }
                TutorialOptionButton(title: T.nameOther, id: "first_budget_name_other") {
                    nameText = ""
                    editsName = true
                    focusSoon { nameFocused = true }
                }
            }
        }
    }

    // MARK: - Tarjeta

    private var chosenCategoryModels: [Category] {
        chosenCategories.compactMap { id in categories.first { $0.persistentModelID == id } }
    }

    private var chosenSubcategoryGroups: [[UUID]] {
        chosenCategoryModels.map { subcategoryIDs(of: $0) }
    }

    private var currentSubcategoryIDs: [UUID] {
        Logic.subcategoryIDs(scope: draft.scope, chosen: chosenSubcategoryGroups, removed: removedSubcategories)
    }

    private var suggestedName: String {
        Logic.suggestedName(
            scope: draft.scope,
            categoryNames: chosenCategoryModels.map(\.name),
            allExpenses: T.nameAllExpenses,
            joined: { T.nameJoined($0, $1) },
            fallback: T.nameFallback
        )
    }

    /// Icono y color: el de la categoría si es una sola; si no, la tarta del acento.
    private var cardLook: (icon: String, color: Color) {
        if draft.scope == .categories, chosenCategoryModels.count == 1, let only = chosenCategoryModels.first {
            return (only.iconName ?? "tag.fill", Color(hex: only.colorHex))
        }
        return ("chart.pie.fill", theme.accent)
    }

    private var cardCaption: String {
        var caption: String
        if let limit = draft.limit {
            caption = P.spentOfLimit(money(spentInDraft), money(limit))
        } else {
            switch draft.scope {
            case .all: caption = T.cardCountsAll
            case .categories:
                caption = chosenCategories.isEmpty
                    ? T.cardPickCategories
                    : T.categoriesSpent(money(spentThisMonth(subcategoryIDs: currentSubcategoryIDs)))
            case nil: caption = T.scopeQuestion
            }
        }
        if let period = draft.period {
            caption += " · " + (period == .unique ? T.periodOnce : period.localizedName)
        }
        return caption
    }

    // MARK: - Lo gastado

    private var spentInDraft: Double {
        guard let scope = draft.scope else { return 0 }
        let ids = scope == .all ? [] : currentSubcategoryIDs
        return spent(subcategoryIDs: ids, period: draft.period ?? .monthly)
    }

    /// Lo gastado este mes con estas subcategorías (vacío = todos los gastos): la misma regla que Planificación
    /// (`BudgetsViewModel.calculateSpending`), sobre un presupuesto de prueba que no se guarda.
    private func spentThisMonth(subcategoryIDs: [UUID]) -> Double {
        spent(subcategoryIDs: subcategoryIDs, period: .monthly)
    }

    private func spent(subcategoryIDs: [UUID], period: BudgetPeriodType) -> Double {
        // Sin nombre a propósito: un presupuesto sin filtros CON nombre dispara el canario `budgetFiltersAppearEmpty`.
        let probe = Budget(
            currencyCode: draft.currencyCode,
            limitAmount: 1,
            periodType: period.rawValue,
            startDate: period == .unique ? draft.startDate : nil,
            endDate: period == .unique ? draft.endDate : nil,
            subcategoryIDs: CSVMirrorCodec.encode(subcategoryIDs)
        )
        let interval = BudgetPeriodInterval.current(for: probe, now: .now, calendar: .current)
        return BudgetsViewModel.calculateSpending(budget: probe, transactions: transactions, interval: interval)
    }

    private func money(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: draft.currencyCode)
    }

    // MARK: - Avance

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        draft = FirstBudgetDraft(currencyCode: appPreferences.defaultCurrencyCode.rawValue)
        let calendar = Calendar.current
        draft.endDate = calendar.date(byAdding: .day, value: 14, to: calendar.startOfDay(for: .now)) ?? .now
        do {
            let all = try modelContext.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
            categories = all.filter { !$0.isIncome && !$0.isSystem && $0.isVisible && !visibleSubcategories(of: $0).isEmpty }
        } catch {
            #if DEBUG
            print("FirstBudgetFlowView: Error: loading categories: \(error)")
            #endif
        }
        loadTransactions(since: calendar.date(from: calendar.dateComponents([.year], from: .now)) ?? .now)
    }

    private func loadTransactions(since start: Date) {
        let descriptor = FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.date >= start })
        do {
            transactions = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("FirstBudgetFlowView: Error: loading records: \(error)")
            #endif
        }
    }

    private func visibleSubcategories(of category: Category) -> [Subcategory] {
        (category.subcategories ?? [])
            .filter { $0.isVisible && !$0.isAnySystem }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func subcategoryIDs(of category: Category) -> [UUID] {
        visibleSubcategories(of: category).map(\.shortcutID)
    }

    private func startQuestions() {
        DS.Haptic.selection()
        history = []
        step = .scope
        showsIntro = false
    }

    private func advance() {
        let next = Logic.next(after: step, scope: draft.scope, period: draft.period)
        limitFocused = false
        nameFocused = false
        history.append(step)
        step = next
    }

    private func goBack() {
        if editsName {
            editsName = false
            return
        }
        guard !created, let previous = history.popLast() else {
            if created { onClose(.created) } else { showsIntro = true }
            return
        }
        limitFocused = false
        nameFocused = false
        step = previous
    }

    private func chooseScope(_ scope: Logic.Scope) {
        draft.scope = scope
        if scope == .all {
            chosenCategories = []
            removedSubcategories = []
        }
        advance()
    }

    private func toggle(_ category: Category) {
        if let index = chosenCategories.firstIndex(of: category.persistentModelID) {
            chosenCategories.remove(at: index)
        } else {
            chosenCategories.append(category.persistentModelID)
        }
    }

    private func afterCategories() {
        guard !chosenCategories.isEmpty else { return }
        // Lo quitado de una categoría que ya no está elegida no cuenta.
        let stillChosen = Set(chosenSubcategoryGroups.joined())
        removedSubcategories = removedSubcategories.filter { stillChosen.contains($0) }
        advance()
    }

    private func choosePeriod(_ period: BudgetPeriodType) {
        draft.period = period
        advance()
        if period != .unique { limitFocused = false }
    }

    private func afterDates() {
        let calendar = Calendar.current
        draft.startDate = calendar.startOfDay(for: draft.startDate)
        draft.endDate = calendar.startOfDay(for: draft.endDate)
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: .now)) ?? .now
        loadTransactions(since: min(yearStart, draft.startDate))
        advance()
    }

    private func chooseName(_ name: String) {
        draft.name = name
        editsName = false
        draft.subcategoryIDs = currentSubcategoryIDs
        advance()
    }

    /// Elegir un aviso pide el permiso de iOS si nunca se pidió (Y23-17) y, si queda permitido, enciende las alertas de
    /// presupuesto de Ajustes (como el editor). «No, gracias» no pide nada.
    private func chooseAlert(_ alert: Logic.Alert) {
        // Un segundo toque mientras se espera el permiso no avanza dos veces (se saltaría el guardado).
        guard step == .alert else { return }
        draft.alert = alert
        enablesBudgetAlerts = false
        guard alert.isEnabled else {
            advance()
            return
        }
        Task { @MainActor in
            var allowed = true
            #if DEBUG
            if !UITestHooks.isActive { allowed = await TutorialPermissionMoments.remindMeChosen() }
            #else
            allowed = await TutorialPermissionMoments.remindMeChosen()
            #endif
            guard step == .alert, draft.alert == alert else { return }
            enablesBudgetAlerts = allowed
            advance()
        }
    }

    /// La última respuesta: se guarda el presupuesto. Si falla, se queda en la pregunta (sale el aviso y se reintenta).
    private func choosePanel(_ shows: Bool) {
        guard !created, step == .panel else { return }
        draft.showsInPanel = shows
        draft.subcategoryIDs = currentSubcategoryIDs
        do {
            try PrimerosPasosPlanningCreator.createBudget(draft, in: modelContext)
        } catch {
            #if DEBUG
            print("FirstBudgetFlowView: Error: creating the budget: \(error)")
            #endif
            saveFailed = true
            return
        }
        // Como el editor: el interruptor de Ajustes se enciende si el aviso quedó permitido.
        if enablesBudgetAlerts { appPreferences.budgetAlertsEnabled = true }
        if shows { PrimerosPasosPlanningCreator.showInPanel(.budgets, preferences: appPreferences) }
        onSaved()
        created = true
        history = []
        DS.Haptic.success()
        step = .done
    }

    private func focusSoon(_ apply: @escaping () -> Void) {
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            apply()
        }
    }
}

// MARK: - Tarjeta del presupuesto, llenándose arriba

/// La tarjeta del presupuesto (como `BudgetRowView`): icono, nombre, «S/ X de S/ Y · Mensual», lo que queda y la barra.
struct FirstBudgetCardPreview: View {
    let name: String
    let isNamePlaceholder: Bool
    let look: (icon: String, color: Color)
    let caption: String
    let limit: Double?
    let spent: Double
    let currencyCode: String
    let alert: FirstBudgetFlowLogic.Alert?
    var header: String? = nil

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    private typealias T = L10n.PrimerosPasos23.Budget
    private typealias P = L10n.PrimerosPasos23.Plan

    private var isOver: Bool { (limit ?? 0) > 0 && spent > (limit ?? 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let header {
                Text(header).font(DS.Typography.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            // A tamaños de accesibilidad lo que queda baja bajo el nombre, como en `BudgetRowView`.
            AdaptiveRowStack(spacing: DS.Spacing.md, stackedSpacing: DS.Spacing.sm) {
                Image(systemName: look.icon)
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(look.color))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(name.isEmpty ? T.cardPlaceholder : name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(isNamePlaceholder ? .secondary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(caption)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } trailing: {
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    Text(isOver ? P.youWentOver : P.youHaveLeft)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                    Text(limit.map { appPreferences.currency(abs($0 - spent), currencyCode: currencyCode) } ?? "—")
                        .font(DS.Typography.headline)
                        .foregroundStyle(isOver ? Color.overBudgetText : .primary)
                }
            }
            ProgressView(value: progress)
                .tint(isOver ? Color.hotPink : look.color)
                .accessibilityHidden(true)
            if let alert, alert.isEnabled {
                Text(alert == .at75And100 ? T.cardAlert75 : T.cardAlert100)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thAccentText)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(theme.card))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("first_budget_card")
    }

    private var progress: Double {
        guard let limit, limit > 0 else { return 0 }
        return min(1, max(0, spent / limit))
    }
}

/// El botón de enviar de una respuesta escrita (la flecha hacia arriba).
struct TutorialSendButton: View {
    let enabled: Bool
    let id: String
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
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
        .accessibilityIdentifier(id)
    }
}
