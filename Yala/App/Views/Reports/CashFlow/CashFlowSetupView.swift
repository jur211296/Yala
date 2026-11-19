//
//  CashFlowSetupView.swift
//  Yala
//
//  Setup view for creating a cash flow plan from suggested lines.
//
//  S5 del replanteo (18-nov-2026, encargo `2026-11-18-flujo-crear-plan`): fuera «¿Con cuánto empiezas?» (P5: el plan
//  parte del saldo de las cuentas, sin cifra a mano); las líneas llegan a la subcategoría, agrupadas bajo su categoría
//  con cabecera plegable, y al crear cada límite queda fijo con la cifra calculada (P4). Lógica en
//  `CrearPlan/FlujoCrearPlanLogica.swift`.
//
//  Auditoría UX 2.2 · lote 18 decidido:
//  - L18-5 (opción C, variante 2) + L18-10 (C): arriba, «¿Con cuánto empiezas?» con lo que la persona tiene hoy en sus
//    cuentas ya puesto (el plan ya no nace en S/ 0); la lista se parte en lo que entra, lo que sale cada mes (a la vista)
//    y «Gastos que cambian» (plegados), y debajo cuánto sobra al mes.
//  - L18-6 (C): una sola explicación en esta pantalla, el aviso con el texto corregido; la guía de 4 pasos se fue.
//  - Alineación con el resto de la app (lienzo «Una sola Yala», sin pregunta): la cifra grande de arriba es la de los
//    heros, los títulos de sección van sin mayúsculas («Lo que entra», «Lo que sale»), icono de 40 y montos en blanco
//    salvo lo que entra.
//

import SwiftUI
import SwiftData

struct CashFlowSetupView: View {

    // MARK: - Properties

    @Bindable var viewModel: CashFlowPlanViewModel
    let transactions: [TransactionItem]
    let scheduledPayments: [ScheduledPayment]
    let categories: [Category]
    let accounts: [Account]
    let currencyCode: String

    @State private var showVariableLines = false
    /// Las categorías plegadas en el armado (`FlujoCrearPlanLogica.Grupo.id`). Al abrir, todas desplegadas.
    @State private var collapsedGroups: Set<String> = []
    @State private var editingLine: SuggestedLine?
    /// Decisión 33 de 2.3: lo que la persona contestó a «¿Cuánto recibes al mes?» (`nil` = nada escrito) y si contestó
    /// «Aún no lo sé».
    @State private var typedIncome: Double?
    @State private var incomeUnknown = false
    @State private var showIncomeSheet = false

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Computed

    /// Lo de hoy en las cuentas. Se calcula al aparecer y cuando cambian los movimientos, no en cada repintado: recorre
    /// todos los movimientos.
    @State private var todayBalance = CashFlowSetupLogic.TodayBalance(amount: 0, accountCount: 0, isApproximate: false)

    private func refreshTodayBalance() {
        todayBalance = CashFlowSetupLogic.todayBalance(
            accounts: accounts, transactions: transactions, currencyCode: currencyCode,
            includeGroups: appPreferences.includeGroupsInPanelTotal
        )
    }

    private var selectedIncome: Double {
        viewModel.suggestedLines
            .filter { $0.isSelected && $0.isIncome }
            .reduce(0) { $0 + $1.suggestedAmount }
    }

    private var selectedExpense: Double {
        viewModel.suggestedLines
            .filter { $0.isSelected && !$0.isIncome }
            .reduce(0) { $0 + $1.suggestedAmount }
    }

    /// Sin ninguna línea de ingreso que sugerir, el armado pregunta el ingreso antes de dar el resumen.
    private var asksForIncome: Bool {
        CashFlowSetupLogic.asksForIncome(suggestedIncomeLines: incomeLines.count, suggestedLines: viewModel.suggestedLines.count)
    }

    /// Hasta que la persona escribe su ingreso o dice «Aún no lo sé», no hay resumen ni «Crear mi plan».
    private var awaitsIncomeAnswer: Bool { asksForIncome && typedIncome == nil && !incomeUnknown }

    private var summaryOutcome: CashFlowSetupLogic.SummaryOutcome {
        CashFlowSetupLogic.summaryOutcome(
            suggestedIncome: selectedIncome, expense: selectedExpense,
            asksForIncome: asksForIncome, typedIncome: typedIncome
        )
    }

    private var allSelected: Bool {
        viewModel.suggestedLines.allSatisfy(\.isSelected)
    }

    private var incomeLines: [SuggestedLine] {
        viewModel.suggestedLines.filter(\.isIncome)
    }

    /// Los grupos de gasto: a la vista los que tienen alguna línea que se repite; plegados en «Gastos que cambian», el
    /// resto (L18-5, ahora por categoría).
    private var expenseGroups: [FlujoCrearPlanLogica.Grupo] {
        FlujoCrearPlanLogica.agrupar(viewModel.suggestedLines.filter { !$0.isIncome })
    }

    private var recurringExpenseGroups: [FlujoCrearPlanLogica.Grupo] { expenseGroups.filter(\.seRepite) }

    private var variableExpenseGroups: [FlujoCrearPlanLogica.Grupo] { expenseGroups.filter { !$0.seRepite } }

    private var variableExpenseLines: [SuggestedLine] { variableExpenseGroups.flatMap(\.lineas) }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                startingBalanceHero
                bannerSection
                if viewModel.suggestedLines.isEmpty {
                    emptyState
                } else {
                    if !allSelected {
                        selectAllButton
                    }
                    if !incomeLines.isEmpty {
                        lineSection(title: L10n.UXL18.sectionIn, lines: incomeLines)
                    }
                    if asksForIncome {
                        incomeQuestion
                    }
                    if !expenseGroups.isEmpty {
                        expenseSection
                    }
                    if !awaitsIncomeAnswer {
                        summarySection
                        fixedLimitsNote
                        createButton
                    }
                }
            }
            // Implícita en el contenedor común: en una pestaña un `withAnimation` no anima (card oxyr).
            .animation(reduceMotion ? nil : DS.Animation.appear, value: showVariableLines)
            .animation(reduceMotion ? nil : DS.Animation.appear, value: collapsedGroups)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .yalaSafeBottomPadding()
            // Ventana ancha: el armado del plan a 700 pt, centrado (decisión 7 de la revisión 2.3).
            .readableColumn()
        }
        .onChange(of: transactions.count) { _, _ in refreshTodayBalance() }
        .onAppear {
            refreshTodayBalance()
            viewModel.generateSuggestions(
                transactions: transactions,
                scheduledPayments: scheduledPayments,
                categories: categories,
                currencyCode: currencyCode
            )
            // El detalle llega siempre a la subcategoría (ajuste de Jürgen del 18-nov).
            viewModel.suggestedLines = FlujoCrearPlanLogica.porSubcategoria(viewModel.suggestedLines)
        }
        .sheet(item: $editingLine) { line in
            CashFlowMethodPickerSheet(
                line: line,
                currencyCode: currencyCode,
                viewModel: viewModel
            )
        }
        .sheet(isPresented: $showIncomeSheet) {
            CashFlowStartingBalanceSheet(
                title: L10n.UXL18.incomeQuestionTitle,
                initialAmount: typedIncome ?? 0,
                initialDate: nil,
                todayBalance: nil,
                currencyCode: currencyCode,
                showsDate: false
            ) { amount, _ in
                typedIncome = amount > 0 ? amount : nil
            }
        }
    }

    // MARK: - ¿Cuánto recibes al mes? (decisión 33 de 2.3, opción A)

    /// La primera semana el sueldo aún no está en el historial: en vez de un resumen con «Te faltan al mes», se pregunta
    /// lo único que una semana de datos no puede adivinar. «Aún no lo sé» deja seguir sin bloquear.
    private var incomeQuestion: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.UXL18.incomeQuestionTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.UXL18.incomeQuestionBody)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                showIncomeSheet = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    AmountText(
                        value: typedIncome ?? 0,
                        currencyCode: currencyCode,
                        font: DS.Typography.title3.monospacedDigit(),
                        tint: typedIncome == nil ? .color(Color(uiColor: .tertiaryLabel)) : .color(Color.amountTint(isIncome: true))
                    )
                    Spacer(minLength: DS.Spacing.sm)
                    Image(systemName: "pencil")
                        .font(DS.Typography.body)
                        .foregroundStyle(theme.accentText)
                        .accessibilityHidden(true)
                }
                .padding(DS.Spacing.md)
                .background(theme.background, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.UXL18.incomeQuestionTitle)
            .accessibilityIdentifier("cashflow_setup_income_amount")
            if typedIncome == nil && !incomeUnknown {
                Button {
                    incomeUnknown = true
                } label: {
                    Text(L10n.UXL18.incomeQuestionUnknown)
                        .font(DS.Typography.label.weight(.semibold))
                        .foregroundStyle(theme.accentText)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cashflow_setup_income_unknown")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cashflow_setup_income_question")
    }

    // MARK: - Tienes hoy (P5 del replanteo: se parte del saldo de las cuentas)

    /// La cifra del Panel, sin «Cambiar»: el plan parte de lo que hay en las cuentas y no de un número escrito a mano.
    private var startingBalanceHero: some View {
        HeroHeader {
            HeroHeaderLabel(text: L10n.FlujoCrearPlan.tienesHoy)
                .accessibilityIdentifier("cashflow_setup_view")
        } period: {
            EmptyView()
        } content: {
            AmountText(
                value: todayBalance.amount,
                currencyCode: currencyCode,
                font: DS.Typography.panelHeroAmount,
                secondaryFont: DS.Typography.panelHeroAmountSecondary,
                isEstimate: todayBalance.isApproximate
            )
            .accessibilityIdentifier("cashflow_setup_starting_amount")
            Text(L10n.FlujoCrearPlan.pie(cuentas: todayBalance.accountCount))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("cashflow_setup_starting_caption")
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Aviso (L18-6: la única explicación de esta pantalla)

    private var bannerSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(DS.Typography.headline)
                .foregroundStyle(theme.accentText)
                .frame(width: 36, height: 36)
                .background(theme.accent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.CashFlowPlan.bannerTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                Text(L10n.CashFlowPlan.bannerBody)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                // El plan alimenta «Ver proyectado» (card «Mejorar el flujo de caja para que nutra el Flujo proyectado»).
                Text(L10n.ProjectedFlow.setupNote)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cashflow_setup_banner")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        YalaEmptyState(
            icon: "arrow.left.arrow.right",
            title: L10n.CashFlowPlan.emptyState,
            message: L10n.CashFlowPlan.emptyStateMessage
        )
        .padding(.top, DS.Spacing.xxl)
    }

    // MARK: - Select All

    private var selectAllButton: some View {
        Button {
            viewModel.selectAllSuggestedLines()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.body)
                Text(L10n.CashFlowPlan.selectAll)
                    .font(DS.Typography.body)
                    .fontWeight(.medium)
            }
            .foregroundStyle(theme.accentText)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Secciones

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(DS.Typography.title3.weight(.bold))
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }

    private func lineSection(title: String, lines: [SuggestedLine]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionTitle(title)
            groupCards(FlujoCrearPlanLogica.agrupar(lines))
        }
    }

    /// Una tarjeta por categoría: la cabecera con la suma de lo elegido y, desplegadas, sus subcategorías.
    private func groupCards(_ groups: [FlujoCrearPlanLogica.Grupo]) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(groups) { group in
                VStack(spacing: DS.Spacing.none) {
                    groupHeader(group)
                    if !collapsedGroups.contains(group.id) {
                        ForEach(group.lineas) { line in
                            Divider()
                                .padding(.leading, DS.Spacing.lg + 40 + DS.Spacing.md)
                            suggestedLineRow(line)
                        }
                    }
                }
                .solidCard()
            }
        }
    }

    private func groupHeader(_ group: FlujoCrearPlanLogica.Grupo) -> some View {
        let isCollapsed = collapsedGroups.contains(group.id)
        let name = group.categoria?.name ?? L10n.FlujoCrearPlan.sinCategoria
        let iconName = group.categoria?.iconName ?? "tag.fill"
        let colorHex = group.categoria?.colorHex ?? AppConstants.defaultColorHex
        let isIncome = group.lineas.first?.isIncome ?? false
        return Button {
            // Lo anima la implícita del `VStack` del `body` (card oxyr).
            if isCollapsed { collapsedGroups.remove(group.id) } else { collapsedGroups.insert(group.id) }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: iconName)
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(hex: colorHex)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(name)
                        .font(DS.Typography.label.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(L10n.FlujoCrearPlan.elegidas(group.elegidas, de: group.lineas.count))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                    // A tamaños de accesibilidad el importe baja a su línea: al lado partía el nombre («Ingre-sos»).
                    if dynamicTypeSize.isAccessibilitySize {
                        groupAmount(group, isIncome: isIncome)
                    }
                }
                Spacer(minLength: DS.Spacing.xs)
                if !dynamicTypeSize.isAccessibilitySize {
                    groupAmount(group, isIncome: isIncome)
                }
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isCollapsed ? L10n.FlujoCrearPlan.plegado : L10n.FlujoCrearPlan.desplegado)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("cashflow_setup_group")
    }

    private func groupAmount(_ group: FlujoCrearPlanLogica.Grupo, isIncome: Bool) -> some View {
        AmountText(
            value: group.totalElegido,
            currencyCode: currencyCode,
            font: DS.Typography.label.weight(.semibold).monospacedDigit(),
            tint: .color(Color.amountTint(isIncome: isIncome))
        )
    }

    /// «Lo que sale»: lo que se repite a la vista y los gastos que cambian, plegados en una fila que se despliega.
    private var expenseSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionTitle(L10n.UXL18.sectionOut)
            if !recurringExpenseGroups.isEmpty {
                groupCards(recurringExpenseGroups)
            }
            if !variableExpenseGroups.isEmpty {
                variableLinesRow
                if showVariableLines {
                    groupCards(variableExpenseGroups)
                        .transition(.opacity)
                }
            }
        }
    }

    private var variableLinesRow: some View {
        Button {
            // Lo anima la implícita del `VStack` del `body` (card oxyr).
            showVariableLines.toggle()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.UXL18.variableTitle(variableExpenseLines.count))
                        .font(DS.Typography.label.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(L10n.UXL18.variableCaption(
                        CashFlowSetupLogic.variableExamples(variableExpenseLines.map(\.name))
                    ))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.sm)
                Text(showVariableLines ? L10n.UXL18.variableHide : L10n.UXL18.variableShow)
                    .font(DS.Typography.label.weight(.semibold))
                    .foregroundStyle(theme.accentText)
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .solidCard()
        .accessibilityIdentifier("cashflow_setup_variable_toggle")
    }

    // MARK: - Line Row

    private func suggestedLineRow(_ line: SuggestedLine) -> some View {
        let index = viewModel.suggestedLines.firstIndex(where: { $0.id == line.id })
        let iconName = line.subcategory?.iconName ?? line.category?.iconName ?? "tag.fill"
        let colorHex = line.subcategory?.colorHex ?? line.category?.colorHex ?? AppConstants.defaultColorHex

        return HStack(spacing: DS.Spacing.md) {
            Button {
                if let index {
                    viewModel.suggestedLines[index].isSelected.toggle()
                }
            } label: {
                Image(systemName: line.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(line.isSelected ? theme.accentText : .secondary)
                    .font(DS.Typography.headline)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(line.name)
            .accessibilityAddTraits(line.isSelected ? .isSelected : [])

            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(DS.Typography.label)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(line.name)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(line.scheduledPayment != nil
                     ? L10n.CashFlowPlan.scheduled
                     : L10n.CashFlowPlan.suggestedSource(line.monthsWithActivity))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: DS.Spacing.xs)

            AmountText(
                value: line.suggestedAmount,
                currencyCode: currencyCode,
                font: DS.Typography.body.monospacedDigit(),
                tint: .color(Color.amountTint(isIncome: line.isIncome)),
                isEstimate: line.isApproximate
            )

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(DS.Typography.caption)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            editingLine = line
        }
        .accessibilityIdentifier("cashflow_setup_line")
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: DS.Spacing.sm) {
            if summaryOutcome != .incomeMissing {
                summaryRow(label: L10n.UXL18.summaryIncome, amount: selectedIncome + (typedIncome ?? 0),
                           tint: Color.amountTint(isIncome: true))
            }
            summaryRow(label: L10n.UXL18.summaryExpense, amount: selectedExpense, tint: .primary)
            Divider()
            switch summaryOutcome {
            case .surplus(let amount):
                summaryRow(label: L10n.UXL18.summarySurplus, amount: amount, tint: .primary, isBold: true)
            case .shortfall(let amount):
                summaryRow(label: L10n.UXL18.summaryShortfall, amount: amount, tint: .primary, isBold: true)
            case .incomeMissing:
                // Sin ingreso no se sabe si falta o sobra: se dice lo que falta saber, no una cifra que asusta.
                Text(L10n.UXL18.summaryIncomeMissing)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("cashflow_setup_summary_income_missing")
            }
        }
        .padding(DS.Spacing.lg)
        .solidCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cashflow_setup_summary")
    }

    /// P4: el límite es un monto fijo sembrado con el promedio, y se dice antes de crear.
    private var fixedLimitsNote: some View {
        Text(L10n.FlujoCrearPlan.limitesFijos)
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("cashflow_setup_fixed_limits_note")
    }

    private func summaryRow(label: String, amount: Double, tint: Color, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isBold ? DS.Typography.headline : DS.Typography.body)
            Spacer()
            AmountText(
                value: amount,
                currencyCode: currencyCode,
                font: (isBold ? DS.Typography.headline : DS.Typography.body).monospacedDigit(),
                tint: .color(tint)
            )
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        YalaPrimaryButton(
            L10n.CashFlowPlan.createButton,
            icon: "plus.circle.fill",
            isDisabled: viewModel.suggestedLines.filter(\.isSelected).isEmpty
        ) {
            // P4: lo calculado por promedio se guarda como monto fijo con su cifra.
            viewModel.suggestedLines = FlujoCrearPlanLogica.conLimiteFijo(viewModel.suggestedLines)
            // P5: el motor parte del saldo real de las cuentas; el campo guarda el de hoy solo como registro.
            viewModel.createPlan(
                startingBalance: todayBalance.amount,
                typedIncome: asksForIncome ? typedIncome : nil,
                incomeCategory: CashFlowSetupLogic.typedIncomeCategory(in: categories)
            )
        }
    }
}

// MARK: - Method Picker Sheet

/// El selector de cómo se calcula una línea. Lo usa crear el plan (sobre una sugerencia) y, desde L18-7, «Cómo se calcula ·
/// Cambiar» del detalle de una línea ya creada (`onApply`), en lugar de la hoja de configuración que se retiró en marzo.
struct CashFlowMethodPickerSheet: View {
    let line: SuggestedLine
    let currencyCode: String
    @Bindable var viewModel: CashFlowPlanViewModel
    /// Con una línea ya creada: qué hacer con lo elegido. `nil` = una sugerencia del asistente.
    var onApply: ((EstimationMethod, Double?) -> Void)? = nil

    @State private var selectedMethod: EstimationMethod
    @State private var manualAmountText: String = ""
    @State private var previewAmount: Double
    @State private var selectedDetent: PresentationDetent = .medium

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    init(
        line: SuggestedLine, currencyCode: String, viewModel: CashFlowPlanViewModel,
        onApply: ((EstimationMethod, Double?) -> Void)? = nil
    ) {
        self.line = line
        self.currencyCode = currencyCode
        self.viewModel = viewModel
        self.onApply = onApply
        self._selectedMethod = State(initialValue: line.estimationMethod)
        self._previewAmount = State(initialValue: line.suggestedAmount)
        if line.estimationMethod == .manual {
            // Con sus decimales: la hoja abre también líneas ya creadas, y redondear aquí cambiaba el monto al guardar.
            self._manualAmountText = State(initialValue: CashFlowStartingBalanceSheet.editableText(line.suggestedAmount))
        }
    }

    private var isLargeDetent: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        // Live amount preview
                        VStack(spacing: DS.Spacing.xs) {
                            Text(line.name)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.secondary)
                            AmountText(
                                value: previewAmount,
                                currencyCode: currencyCode,
                                font: DS.Typography.title.weight(.bold).monospacedDigit()
                            )
                                .contentTransition(.numericText())
                                .animation(.default, value: previewAmount)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Spacing.md)

                        // Methods
                        VStack(spacing: DS.Spacing.none) {
                            ForEach(availableMethods, id: \.self) { method in
                                methodRow(method: method)
                                if method != availableMethods.last {
                                    Divider().padding(.leading, DS.Spacing.xxl)
                                }
                            }
                        }
                        .solidCard()

                        // Manual amount field
                        if selectedMethod == .manual {
                            TextField("0", text: $manualAmountText)
                                .keyboardType(.decimalPad)
                                .font(DS.Typography.headline)
                                .monospacedDigit()
                                .padding(DS.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                        .fill(.thCard)
                                )
                                .onChange(of: manualAmountText) {
                                    let parsed = AmountInputHelper.parseDecimal(manualAmountText)
                                    previewAmount = parsed
                                }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                    .yalaSafeBottomPadding()
                    .dismissKeyboardOnTap()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
            .navigationTitle(L10n.CashFlowPlan.calculationMethodTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // «Monto fijo» sin cifra dejaría la línea en 0 en todos los meses.
                    YalaSaveButton(
                        action: { applyAndDismiss() },
                        isDisabled: selectedMethod == .manual && AmountInputHelper.parseDecimal(manualAmountText) <= 0
                    )
                }
            }
        }
        .yalaSheetDetents([.medium, .large], selection: $selectedDetent)
    }

    // MARK: - Helpers

    private var availableMethods: [EstimationMethod] {
        var methods: [EstimationMethod] = [.average6m, .average3m, .lastMonth, .manual]
        if line.scheduledPayment != nil {
            methods.insert(.scheduled, at: 0)
        }
        // Una línea antigua con un método que esta lista ya no ofrece lo conserva a la vista, elegido.
        if !methods.contains(line.estimationMethod) {
            methods.insert(line.estimationMethod, at: 0)
        }
        return methods
    }

    private func methodRow(method: EstimationMethod) -> some View {
        Button {
            selectedMethod = method
            recalculatePreview()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: selectedMethod == method ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedMethod == method ? theme.accentText : .secondary)
                    .font(DS.Typography.headline)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(methodDisplayName(method))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                    Text(method.descriptionText)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func recalculatePreview() {
        if selectedMethod == .manual {
            let parsed = AmountInputHelper.parseDecimal(manualAmountText)
            previewAmount = parsed
        } else {
            previewAmount = viewModel.previewAmount(for: line, method: selectedMethod)
        }
    }

    private func methodDisplayName(_ method: EstimationMethod) -> String {
        method.displayName
    }

    private func applyAndDismiss() {
        let manualAmount: Double? = manualAmountText.isEmpty ? nil : AmountInputHelper.parseDecimal(manualAmountText)
        if let onApply {
            onApply(selectedMethod, manualAmount)
        } else {
            viewModel.updateEstimationMethod(for: line.id, to: selectedMethod, manualAmount: manualAmount)
        }
        dismiss()
    }
}
