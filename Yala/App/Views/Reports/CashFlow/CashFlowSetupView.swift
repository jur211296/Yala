//
//  CashFlowSetupView.swift
//  Yala
//
//  Setup view for creating a cash flow plan from suggested lines.
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

    /// El saldo con el que nace el plan. `nil` = el de las cuentas (lo de hoy); un número = lo que escribió la persona.
    @State private var typedStartingBalance: Double?
    @State private var showStartingBalanceSheet = false
    @State private var showVariableLines = false
    @State private var editingLine: SuggestedLine?

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

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

    private var startingBalance: Double { typedStartingBalance ?? todayBalance.amount }

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

    private var netFlow: Double { selectedIncome - selectedExpense }

    private var allSelected: Bool {
        viewModel.suggestedLines.allSatisfy(\.isSelected)
    }

    private var incomeLines: [SuggestedLine] {
        viewModel.suggestedLines.filter(\.isIncome)
    }

    private var recurringExpenseLines: [SuggestedLine] {
        viewModel.suggestedLines.filter { !$0.isIncome && $0.isRecurring }
    }

    private var variableExpenseLines: [SuggestedLine] {
        viewModel.suggestedLines.filter { !$0.isIncome && !$0.isRecurring }
    }

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
                    if !recurringExpenseLines.isEmpty || !variableExpenseLines.isEmpty {
                        expenseSection
                    }
                    summarySection
                    createButton
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .yalaSafeBottomPadding()
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
        }
        .sheet(item: $editingLine) { line in
            CashFlowMethodPickerSheet(
                line: line,
                currencyCode: currencyCode,
                viewModel: viewModel
            )
        }
        .sheet(isPresented: $showStartingBalanceSheet) {
            CashFlowStartingBalanceSheet(
                title: L10n.UXL18.startTitle,
                initialAmount: startingBalance,
                initialDate: nil,
                todayBalance: todayBalance.accountCount > 0 ? todayBalance : nil,
                currencyCode: currencyCode,
                showsDate: false
            ) { amount, _ in
                typedStartingBalance = amount
            }
        }
    }

    // MARK: - ¿Con cuánto empiezas? (L18-5 / L18-10)

    private var startingBalanceCaption: String {
        if typedStartingBalance != nil { return L10n.UXL18.startCaptionTyped }
        switch todayBalance.accountCount {
        case 0: return L10n.UXL18.startCaptionNone
        case 1: return L10n.UXL18.startCaptionOne
        default: return L10n.UXL18.startCaption(todayBalance.accountCount)
        }
    }

    private var startingBalanceHero: some View {
        HeroHeader {
            HeroHeaderLabel(text: L10n.UXL18.startTitle)
                .accessibilityIdentifier("cashflow_setup_view")
        } period: {
            EmptyView()
        } content: {
            AmountText(
                value: startingBalance,
                currencyCode: currencyCode,
                font: DS.Typography.panelHeroAmount,
                secondaryFont: DS.Typography.panelHeroAmountSecondary,
                isEstimate: typedStartingBalance == nil && todayBalance.isApproximate
            )
            .accessibilityIdentifier("cashflow_setup_starting_amount")
            HStack(spacing: DS.Spacing.xs) {
                Text(startingBalanceCaption)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                Button {
                    showStartingBalanceSheet = true
                } label: {
                    Text(L10n.UXL18.startChange)
                        .font(DS.Typography.caption.weight(.semibold))
                        .foregroundStyle(theme.accentText)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cashflow_setup_change_starting")
            }
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
            linesCard(lines)
        }
    }

    private func linesCard(_ lines: [SuggestedLine]) -> some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(lines) { line in
                suggestedLineRow(line)
                if line.id != lines.last?.id {
                    Divider()
                        .padding(.leading, DS.Spacing.lg + 40 + DS.Spacing.md)
                }
            }
        }
        .solidCard()
    }

    /// «Lo que sale»: lo que se repite a la vista y los gastos que cambian, plegados en una fila que se despliega.
    private var expenseSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionTitle(L10n.UXL18.sectionOut)
            if !recurringExpenseLines.isEmpty {
                linesCard(recurringExpenseLines)
            }
            if !variableExpenseLines.isEmpty {
                variableLinesRow
                if showVariableLines {
                    linesCard(variableExpenseLines)
                        .transition(.opacity)
                }
            }
        }
    }

    private var variableLinesRow: some View {
        Button {
            withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                showVariableLines.toggle()
            }
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
            summaryRow(label: L10n.UXL18.summaryIncome, amount: selectedIncome,
                       tint: Color.amountTint(isIncome: true))
            summaryRow(label: L10n.UXL18.summaryExpense, amount: selectedExpense, tint: .primary)
            Divider()
            summaryRow(
                label: netFlow >= 0 ? L10n.UXL18.summarySurplus : L10n.UXL18.summaryShortfall,
                amount: abs(netFlow),
                tint: .primary,
                isBold: true
            )
        }
        .padding(DS.Spacing.lg)
        .solidCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cashflow_setup_summary")
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
            viewModel.createPlan(startingBalance: startingBalance)
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
