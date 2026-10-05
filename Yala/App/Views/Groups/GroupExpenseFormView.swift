//
//  GroupExpenseFormView.swift
//  Yala
//
//  Formulario de creación/edición de gastos compartidos.
//  Propuesta B de `group-expense-views-redesign`: arriba lo de siempre (grupo, fecha,
//  descripción y monto); debajo, quién pagó con avatares y el reparto en la misma pantalla
//  (`GroupSplitEditorCard`), sin hojas aparte para pagador ni división.
//

import SwiftUI
import SwiftData

/// Cómo se muestra el chip de contexto de grupo (debajo del segmented control).
/// `.hidden` (default) preserva el form original; `.readOnly` muestra el grupo sin
/// permitir cambiarlo (dentro del detalle de un grupo); `.editable` permite tocarlo
/// para cambiar de grupo (al crear un gasto desde el FAB del tab Grupos).
enum GroupContextChipMode {
    case hidden
    case readOnly
    case editable(() -> Void)
}

/// Plantilla de prellenado para crear un gasto de grupo "como favorito" — p.ej. al aprobar
/// un pago planificado de grupo desde el Inbox. El VM la aplica en `onAppear` vía `applyTemplate`.
struct GroupExpensePrefillTemplate {
    let totalAmount: Double
    let currencyCode: String
    let splitType: SplitType
    let participantIDs: [UUID]
    /// Valor crudo por participante según el modo (%/monto/partes). Vacío en `.equal`.
    let values: [UUID: Double]
    let description: String
    let accountPrefill: Account?
    /// Fecha del origen (el draft), NO la de la conversión.
    ///
    /// **Sin valor por defecto a propósito.** El bug que cierra este campo era justo su ausencia:
    /// `GroupExpenseViewModel.date` arranca en `.now`, así que un borrador de hace tres días se
    /// convertía en un gasto de grupo fechado HOY, y el usuario no tenía forma de notarlo salvo
    /// mirando la fecha. Un default `.now` aquí cumpliría la letra y dejaría el mismo agujero
    /// abierto para cualquier productor nuevo, en silencio: los DOS que existen hoy
    /// (`InboxView.loadGroupScheduledContext` y `loadConversionContext`, vía
    /// `DraftToGroupExpenseTemplateLogic`) nacieron con él. Quien añada un tercero tiene que
    /// decidir qué fecha corresponde, y el compilador se lo va a exigir.
    let date: Date
}

struct GroupExpenseFormView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Input

    let group: SplitGroup
    let members: [SplitMember]
    let memberNameLookup: [String: String]
    /// Chip de contexto de grupo debajo del segmented control. Default `.hidden`.
    let groupChip: GroupContextChipMode
    let expenseToEdit: SplitExpense?
    let existingShares: [SplitShare]
    let onSave: () -> Void
    /// Borra el gasto en edición. `nil` cuando el usuario no puede borrar (no se
    /// muestra el botón). El sheet cierra siempre tras confirmar — el resultado
    /// (éxito o alert de error) lo maneja la vista padre.
    let onDelete: ((SplitExpense) -> Void)?
    /// F4: plantilla de prellenado para crear desde un pago planificado de grupo (nil = flujo normal).
    let initialTemplate: GroupExpensePrefillTemplate?
    /// F4: callback con el `SplitExpense.id` creado tras `save()` exitoso — cierra el ciclo del
    /// pago planificado. Default nil → no afecta callers existentes.
    let onExpenseCreated: ((String) -> Void)?
    /// Flujos manuales (default `true`) muestran `GroupExpenseSuccessView` tras guardar (crear/editar).
    /// Los flujos de Inbox pasan `false` para conservar su cierre directo con su propia semántica.
    let presentsSuccessScreen: Bool

    // MARK: - State

    @State private var viewModel: GroupExpenseViewModel
    @FocusState private var focusedField: ExpenseField?

    // Sheets
    @State private var showCurrencyPicker = false
    @State private var showDatePicker = false
    @State private var showSubcategorySelector = false
    @State private var showAccountSelector = false  // M6 Caso A
    // Grupos de 2: hoja de cuatro opciones rápidas, desde «Opciones rápidas» del reparto.
    @State private var showTwoPersonSplit = false
    // Gate de monto: abrir las opciones rápidas con monto 0 no abre la hoja — muestra un
    // alert pidiendo ingresar el monto primero.
    @State private var showAmountRequiredAlert = false

    // Opt-out: alert post-save cuando bridge effective OFF + Caso A.
    @State private var pendingOptInExpenseID: String?
    @State private var showOptInAlert: Bool = false

    // Pantalla de éxito (solo flujos manuales; ver `presentsSuccessScreen`).
    @State private var showSuccessScreen = false
    @State private var successData: GroupExpenseSuccessData?
    /// Gate: el prefill (edición/plantilla) corre una sola vez, no al volver de la pantalla
    /// de éxito — así "Editar" conserva lo editado y "Crear otro" mantiene el form limpio.
    @State private var didInitialPrefill = false

    // Borrado del gasto desde el toolbar (solo en modo edición).
    @State private var showDeleteConfirmation = false

    // Red: presenta cualquier `viewModel.saveError` que hoy moriría mudo (grupo congelado
    // por migración, carrera pull-congela-mientras-guardas, o cualquier otro throw del save).
    @State private var showSaveErrorAlert = false

    // Amount scaling
    @ScaledMetric(relativeTo: .largeTitle) private var baseAmountSize: CGFloat = 56 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .body) private var payerAvatarSize: CGFloat = 44 // A11Y-DT: @ScaledMetric

    /// Parte abierta bajo la frase «Pagado por · dividido»; `nil` = las dos plegadas.
    @State private var expandedSection: ExpandedSection?

    // MARK: - Init

    init(
        group: SplitGroup,
        members: [SplitMember],
        memberNameLookup: [String: String],
        groupChip: GroupContextChipMode = .hidden,
        expenseToEdit: SplitExpense? = nil,
        existingShares: [SplitShare] = [],
        initialTemplate: GroupExpensePrefillTemplate? = nil,
        onSave: @escaping () -> Void,
        onExpenseCreated: ((String) -> Void)? = nil,
        presentsSuccessScreen: Bool = true,
        onDelete: ((SplitExpense) -> Void)? = nil
    ) {
        self.group = group
        self.members = members
        self.memberNameLookup = memberNameLookup
        self.groupChip = groupChip
        self.expenseToEdit = expenseToEdit
        self.existingShares = existingShares
        self.initialTemplate = initialTemplate
        self.onSave = onSave
        self.onExpenseCreated = onExpenseCreated
        self.presentsSuccessScreen = presentsSuccessScreen
        self.onDelete = onDelete

        let vm = GroupExpenseViewModel(group: group, members: members, memberNameLookup: memberNameLookup)
        self._viewModel = State(initialValue: vm)
    }

    // MARK: - Body

    var body: some View {
        if showSuccessScreen, let data = successData {
            GroupExpenseSuccessView(
                data: data,
                onAccept: {
                    onSave()
                    dismiss()
                },
                onCreateAnother: { resetForAnother() },
                onEdit: {
                    dsWithAnimation(reduceMotion) {
                        showSuccessScreen = false
                        successData = nil
                    }
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else {
            formView
                .transition(.opacity)
        }
    }

    private var formView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    centralContent
                        .padding(.horizontal, DS.Spacing.lg)

                    whoPaysCard
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.xl)

                    bottomChips
                }
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: DS.Spacing.none) {
                    migratedFrozenHint

                    registerButton
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.top, DS.Spacing.sm)
                        .padding(.bottom, DS.Spacing.md)
                }
                .background(.thBackground)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(viewModel.isEditMode ? L10n.Groups.Expense.editTitle : L10n.Groups.Expense.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                if viewModel.isEditMode, onDelete != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .fontWeight(.medium)
                                .foregroundStyle(DS.Semantic.errorForeground)
                        }
                        .accessibilityLabel(L10n.Action.delete)
                        .accessibilityIdentifier("group_expense_delete")
                        .buttonBorderShape(.circle)
                    }
                }
            }
            .alert(L10n.Groups.Bridge.optoutAlertTitle, isPresented: $showOptInAlert) {
                Button(L10n.Groups.Bridge.optoutAlertYes) { confirmOptIn() }
                Button(L10n.Groups.Bridge.optoutAlertNo, role: .cancel) { declineOptIn() }
            } message: {
                Text(L10n.Groups.Bridge.optoutAlertBody)
            }
            .alert(L10n.Groups.Expense.amountRequiredTitle, isPresented: $showAmountRequiredAlert) {
                Button(L10n.Common.understood, role: .cancel) { }
            } message: {
                Text(L10n.Groups.Expense.amountRequiredMessage)
            }
            .alert(L10n.Common.error, isPresented: $showSaveErrorAlert) {
                Button(L10n.Common.ok, role: .cancel) { viewModel.saveError = nil }
            } message: {
                // NUNCA pipear `error.localizedDescription` a la UI (review H-2): varios casos de
                // GroupExpenseServiceError alcanzables (.saveFailed/.inactiveMember) son dev-strings
                // en inglés sin localizar. Mensaje SIEMPRE localizado: freeze → movedToBackend
                // (la carrera pull-congela-mientras-guardas); resto → genérico.
                Text(group.isMigratedFrozen
                    ? L10n.Groups.Errors.movedToBackend
                    : L10n.Groups.Errors.actionFailed)
            }
            .confirmationDialog(
                L10n.Action.delete,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Action.delete, role: .destructive) {
                    if let expense = expenseToEdit {
                        onDelete?(expense)
                        dismiss()
                    }
                }
                .accessibilityIdentifier("group_expense_delete_confirm")
            }
            .onAppear {
                viewModel.setContext(modelContext)
                // Prefill una sola vez: al volver de la pantalla de éxito (edit/crear otro) el
                // form se remonta y este onAppear vuelve a correr — no debe re-prellenar.
                if !didInitialPrefill {
                    didInitialPrefill = true
                    if let expense = expenseToEdit {
                        viewModel.prefill(from: expense, shares: existingShares)
                    } else if let template = initialTemplate {
                        viewModel.applyTemplate(template)
                    }
                }
                // Nunca autoenfocamos el monto: el form abre sin teclado (decisión de UX).
                // M6: defensa profundidad — si VM no resolvió current user (members no cargados),
                // canSave queda bloqueado pero el form sigue navegable.
                #if DEBUG
                if !viewModel.isReady {
                    print("GroupExpenseFormView: VM not ready (currentUserMemberID nil) — canSave will block save")
                }
                #endif
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $viewModel.date)
                }
            .sheet(isPresented: $showCurrencyPicker) {
                // NavigationStack para que el .toolbar con la "X" de CurrencySelectorView
                // se renderice (sin barra de navegación no hay dónde colocarlo).
                NavigationStack {
                    CurrencySelectorView(selectedCurrency: currencyCodeBinding)
                }
                .yalaSheetDetents([.large])
            }
            .sheet(isPresented: $showAccountSelector) {
                // M6: filtrado por moneda para que la cuenta seleccionada siempre sea compatible.
                AccountSelectorSheet(
                    selectedAccount: $viewModel.selectedAccount,
                    title: L10n.Transaction.account,
                    currencyFilter: viewModel.currencyCode,
                    sizing: .mediumFirst
                )
            }
            .sheet(isPresented: $showSubcategorySelector) {
                SubcategorySelectorSheet(
                    selectedSubcategory: $viewModel.selectedSubcategory,
                    transactionType: .expense,
                    sizing: .mediumFirst
                )
            }
            // Grupos de 2: cuatro opciones rápidas. «Más opciones» cierra la hoja y despliega el
            // reparto completo en el formulario.
            .sheet(isPresented: $showTwoPersonSplit) {
                GroupTwoPersonSplitView(viewModel: viewModel) {
                    showTwoPersonSplit = false
                    expandedSection = .split
                }
            }
            // M6: si user cambia moneda y la cuenta seleccionada deja de ser compatible,
            // se limpia. El form vuelve a pedir cuenta antes de guardar (canSave bloquea).
            .onChange(of: viewModel.currencyCode) { _, _ in
                viewModel.resetAccountIfIncompatible()
            }
        }
    }

    // MARK: - Central Content

    private var centralContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Grupo y fecha en una sola línea pequeña: son contexto, no lo que se edita.
            HStack(spacing: DS.Spacing.sm) {
                groupContextChip
                dateChip
            }
            .padding(.top, DS.Spacing.lg)
            descriptionField
                .padding(.top, DS.Spacing.sm)
            amountDisplay
        }
    }

    // MARK: - Date Chip

    private var dateChip: some View {
        Button {
            showDatePicker = true
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "calendar")
                    .font(DS.Typography.caption)
                Text(dateChipText)
                    .font(DS.Typography.subheadline)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Capsule())
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        // El chip no era alcanzable desde XCUITest, y sin él la FECHA del prellenado no se podía
        // afirmar: es el campo del bug que `GroupExpensePrefillTemplate.date` existe para impedir
        // (un borrador de hace tres días convirtiéndose en un gasto fechado HOY). El label expone
        // `dateChipText`, así que un test puede distinguir «Hoy» de una fecha real.
        .accessibilityIdentifier("group_expense_date_chip")
        .accessibilityLabel(dateChipText)
    }

    private var dateChipText: String {
        if Calendar.current.isDateInToday(viewModel.date) { return L10n.Date.today }
        if Calendar.current.isDateInYesterday(viewModel.date) { return L10n.Date.yesterday }
        return viewModel.date.formatted(.dateTime.day().month(.abbreviated))
    }

    // MARK: - Description Field

    private var descriptionField: some View {
        TextField(L10n.Groups.Expense.descriptionPlaceholder, text: $viewModel.expenseDescription)
            .font(DS.Typography.title)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .textContentType(.none)
            .autocorrectionDisabled(false)
            .focused($focusedField, equals: .description)
            .frame(maxWidth: 280)
            .tint(Color.primary)
            .accessibilityLabel(L10n.Groups.Expense.descriptionPlaceholder)
            .accessibilityIdentifier("group_expense_description")
    }

    // MARK: - Amount Display

    private var amountFontSize: CGFloat {
        let length = viewModel.amountString.count
        let ratio: CGFloat
        switch length {
        case 0...7: ratio = 1.0
        case 8...9: ratio = 54.0 / 64.0
        case 10...11: ratio = 46.0 / 64.0
        case 12...13: ratio = 38.0 / 64.0
        default: ratio = 32.0 / 64.0
        }
        return baseAmountSize * ratio
    }

    private var amountDisplay: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            currencyChip

            TextField("0.00", text: $viewModel.amountString)
                .font(.system(size: amountFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .amount)
                .accessibilityIdentifier("group_expense_amount")
                .fixedSize(horizontal: true, vertical: false)
                .onChange(of: focusedField) { _, newFocus in
                    if newFocus == .amount
                        && (viewModel.amountString == "0" || viewModel.amountString == "0.00" || viewModel.amountString == "0,00")
                    {
                        viewModel.amountString = ""
                    }
                    if newFocus != .amount {
                        if viewModel.amountString.isEmpty {
                            viewModel.amountString = "0.00"
                        } else {
                            viewModel.amountString = AmountInputHelper.formatWithGrouping(viewModel.amount)
                        }
                    }
                }
                .onChange(of: viewModel.amountString) { _, newValue in
                    let filtered = AmountInputHelper.filterAmountInput(newValue)
                    if filtered != newValue {
                        viewModel.amountString = filtered
                    }
                }
        }
    }

    // MARK: - Currency Chip

    /// Respeta `appPreferences.currencyDisplayFormat`: `.symbol` muestra "S/"/"£"/"$",
    /// `.code` muestra "PEN"/"GBP"/"USD".
    private var displayedCurrency: String {
        switch appPreferences.currencyDisplayFormat {
        case .symbol: return CurrencyCode.symbol(for: viewModel.currencyCode)
        case .code: return viewModel.currencyCode
        }
    }

    private var currencyChip: some View {
        Button {
            dismissKeyboard()
            showCurrencyPicker = true
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Text(displayedCurrency)
                    .font(DS.Typography.headline)
                Image(systemName: "chevron.down")
                    .font(DS.Typography.labelSmall)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.FormRow.paddingV)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(.thCard))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Groups.Expense.currency)
    }

    // MARK: - Group Context Chip

    /// Chip debajo del segmented control que muestra (y opcionalmente cambia) el grupo
    /// del gasto. Editable al crear desde el FAB del tab; solo lectura dentro del detalle.
    @ViewBuilder
    private var groupContextChip: some View {
        switch groupChip {
        case .hidden:
            EmptyView()
        case .readOnly:
            groupChipLabel(showsChevron: false)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("group_expense_group_chip")
                .accessibilityLabel("\(L10n.Groups.groupLabel): \(group.name)")
        case .editable(let onTap):
            Button {
                dismissKeyboard()
                onTap()
            } label: {
                groupChipLabel(showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("group_expense_group_chip")
            .accessibilityLabel("\(L10n.Groups.groupLabel): \(group.name)")
        }
    }

    private func groupChipLabel(showsChevron: Bool) -> some View {
        // Sin cápsula: es contexto. El a11y label conserva «Grupo: <nombre>».
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: group.iconName)
                .font(DS.Typography.caption)
                .foregroundStyle(Color(hex: group.colorHex))
            Text(group.name)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .contentShape(Rectangle())
    }

    // MARK: - Pagado por · Reparto (frase + secciones plegables)

    /// Qué parte está abierta debajo de la frase. Una a la vez: abrir una pliega la otra.
    private enum ExpandedSection { case payer, split }

    private var memberColors: [String: Color] {
        GroupMemberPalette.colors(
            for: members.map { $0.id.uuidString },
            currentMemberID: viewModel.currentUserMemberID,
            names: memberNameLookup
        )
    }

    /// Quién pagó y cómo se reparte, dicho en una frase (molde de Splitwise, feedback del
    /// 2026-10-04: menos ruido a primera vista). En grupos de 3+, «Pagado por [Ana] y dividido
    /// [en partes iguales]» con las dos piezas tocables; cada una abre su parte debajo. En grupos
    /// de 2, una sola pastilla con la frase entera que abre las cuatro opciones rápidas; «Más
    /// opciones» despliega el reparto completo. La cuenta del Caso A va siempre a la vista: es lo
    /// único que deja Guardar apagado en un gasto que pagaste tú.
    private var whoPaysCard: some View {
        let colors = memberColors
        return VStack(spacing: DS.Spacing.lg) {
            if viewModel.isTwoPersonGroup && expandedSection == nil {
                twoPersonSentence
            } else {
                splitSentence
            }

            if viewModel.isAccountRequired {
                accountRow
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(.thCard)
                    )
            }

            if expandedSection == .payer {
                payerPicker(colors: colors)
                    .transition(.opacity)
            }

            if expandedSection == .split {
                GroupSplitEditorCard(
                    viewModel: viewModel,
                    onRequestQuickOptions: viewModel.isTwoPersonGroup ? { openQuickOptions() } : nil
                )
                .padding(DS.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .fill(.thCard)
                )
                .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_expense_paidby_card")
    }

    private func toggle(_ section: ExpandedSection) {
        dismissKeyboard()
        dsWithAnimation(reduceMotion) {
            expandedSection = expandedSection == section ? nil : section
        }
    }

    /// Nombre del pagador dentro de la frase: «ti» para el usuario actual («Pagado por ti»).
    private var payerSentenceName: String {
        guard !viewModel.paidByMemberID.isEmpty else { return "—" }
        if viewModel.paidByMemberID == viewModel.currentUserMemberID { return L10n.Groups.Member.youObject }
        return memberNameLookup[viewModel.paidByMemberID] ?? "—"
    }

    /// Grupos de 3+: «Pagado por [Ana] y dividido [en partes iguales]». Si no cabe en una línea,
    /// pasa a dos, partida por la «y».
    private var splitSentence: some View {
        let payerPiece = HStack(spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Expense.paidByTitle)
                .foregroundStyle(.secondary)
            sentenceToken(
                text: payerSentenceName,
                isOpen: expandedSection == .payer,
                warning: false,
                identifier: "group_expense_paidby_row",
                a11yLabel: "\(L10n.Groups.Expense.paidByTitle): \(payerSentenceName)"
            ) { toggle(.payer) }
        }
        let splitPiece = HStack(spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Expense.andDividedLabel)
                .foregroundStyle(.secondary)
            sentenceToken(
                text: viewModel.splitType.inlineLabel,
                isOpen: expandedSection == .split,
                warning: !viewModel.isSharesBalanced,
                identifier: "group_expense_split_row",
                a11yLabel: "\(L10n.Groups.Expense.dividedLabel): \(viewModel.splitType.displayName)"
            ) { toggle(.split) }
        }
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.sm) { payerPiece; splitPiece }
            VStack(spacing: DS.Spacing.sm) { payerPiece; splitPiece }
        }
        .font(DS.Typography.body)
        .frame(maxWidth: .infinity)
    }

    /// Una pieza tocable de la frase. Abierta, en el color del tema.
    private func sentenceToken(
        text: String,
        isOpen: Bool,
        warning: Bool,
        identifier: String,
        a11yLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xxs) {
                Text(text)
                    .lineLimit(1)
                if warning {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(Color.hotPink)
                        .accessibilityHidden(true)
                }
            }
            // En reposo, el tinte del tema (se ve tocable); abierta, el tema sólido (se está
            // editando). Decisión de Jürgen, 2026-10-04.
            .foregroundStyle(isOpen ? Color.white : theme.accent)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(Capsule().fill(isOpen ? theme.accent : theme.accent.opacity(0.18)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11yLabel)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    /// Grupos de 2: la frase entera en una pastilla. Abre las cuatro opciones rápidas.
    private var twoPersonSentence: some View {
        let text = "\(L10n.Groups.Expense.paidByTitle) \(payerSentenceName) \(L10n.Groups.Expense.andDividedLabel) \(viewModel.splitType.inlineLabel)"
        return Button {
            openQuickOptions()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Text(text)
                    .multilineTextAlignment(.center)
                if !viewModel.isSharesBalanced {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(Color.hotPink)
                        .accessibilityHidden(true)
                }
            }
            .font(DS.Typography.body)
            .foregroundStyle(theme.accent)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(theme.accent.opacity(0.18)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(text)
        .accessibilityHint(L10n.Groups.Expense.TwoPerson.quickOptions)
        .accessibilityIdentifier("group_expense_quick_options")
    }

    /// Avatares para elegir quién pagó.
    private func payerPicker(colors: [String: Color]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: DS.Spacing.lg) {
                ForEach(members, id: \.id) { member in
                    payerOption(member, color: colors[member.id.uuidString] ?? theme.accent)
                }
            }
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.lg)
        }
        // El anillo del elegido sobresale del avatar: sin esto el scroll lo recorta.
        .scrollClipDisabled()
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(.thCard)
        )
    }

    private func openQuickOptions() {
        openSplitIfAmountValid { showTwoPersonSplit = true }
    }

    private func payerOption(_ member: SplitMember, color: Color) -> some View {
        let id = member.id.uuidString
        let isSelected = viewModel.paidByMemberID == id
        let name = payerDisplayName(member)
        return Button {
            dismissKeyboard()
            viewModel.paidByMemberID = id
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.2))
                        .frame(width: payerAvatarSize, height: payerAvatarSize)
                    Text(String(member.resolvedDisplayName.prefix(1)).uppercased())
                        .font(DS.Typography.headline)
                        .foregroundStyle(isSelected ? Color.white : color)
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(color, lineWidth: 2)
                            .padding(-DS.Spacing.xs)
                    }
                }
                Text(name)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: payerAvatarSize + DS.Spacing.xl)
            }
            .opacity(member.isActive ? 1 : 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("group_expense_payer_\(member.resolvedDisplayName)")
    }

    /// Cuenta de la que salió el pago. Sin cuenta, la fila lo pide en el color de aviso:
    /// es lo único que deja Guardar apagado en un gasto que pagaste tú.
    private var accountRow: some View {
        let account = viewModel.selectedAccount
        let isMissing = account == nil
        return Button {
            dismissKeyboard()
            showAccountSelector = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "creditcard")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(account.map { Color(hex: $0.colorHex) } ?? Color.secondary)
                    .accessibilityHidden(true)
                Text(L10n.Transaction.account)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: DS.Spacing.sm)
                if isMissing {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(Color.hotPink)
                        .accessibilityHidden(true)
                }
                Text(account?.name ?? L10n.Validation.selectAccount)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("group_expense_account_row")
    }

    /// «Tú» para el usuario actual (sin paréntesis: aquí es el nombre); el resto, su nombre.
    private func payerDisplayName(_ member: SplitMember) -> String {
        if member.id.uuidString == viewModel.currentUserMemberID { return L10n.Groups.Member.youName }
        return memberNameLookup[member.id.uuidString] ?? member.resolvedDisplayName
    }

    // MARK: - Bottom Chips

    private var bottomChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                // La cuenta (Caso A) vive en la tarjeta «Pagado por»; aquí queda la subcategoría,
                // que es opcional.
                SelectionChip(
                    icon: "tag",
                    text: viewModel.selectedSubcategory?.name ?? L10n.Transaction.subcategory,
                    isSelected: viewModel.selectedSubcategory != nil,
                    color: subcategoryChipColor
                ) {
                    dismissKeyboard()
                    showSubcategorySelector = true
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    private var subcategoryChipColor: Color? {
        guard let sub = viewModel.selectedSubcategory else { return nil }
        return Color(hex: sub.safeCategory.colorHex)
    }

    // MARK: - Register Button

    /// El botón Guardar está habilitado solo si el VM puede guardar Y el grupo NO está
    /// congelado por migración. La lectura de `group.isMigratedFrozen` sobre el @Model vivo
    /// es reactiva: un pull que congele el grupo con el composer abierto voltea el botón solo.
    private var saveButtonEnabled: Bool {
        viewModel.canSave && !group.isMigratedFrozen
    }

    private var registerButton: some View {
        Button {
            handleSave()
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.headline)
                    Text(L10n.Action.save)
                        .font(DS.Typography.headline)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(saveButtonEnabled ? theme.accent : DS.Semantic.disabledForeground.opacity(0.4))
        .controlSize(.large)
        .disabled(!saveButtonEnabled || viewModel.isSaving)
        .accessibilityIdentifier("group_expense_save")
        .dsAnimation(.easeInOut(duration: 0.2), value: saveButtonEnabled, reduceMotion: reduceMotion)
    }

    // MARK: - Migrated Frozen Hint

    /// Banner compacto (molde de `MigratedGroupBanner` del detalle) sobre el botón Guardar
    /// cuando el grupo está congelado por migración: explica por qué no se puede guardar y
    /// remite a volver a entrar. Reusa `Groups.Migrated.bannerBody` (0 keys nuevas).
    @ViewBuilder
    private var migratedFrozenHint: some View {
        if group.isMigratedFrozen {
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(DS.Typography.label)
                    .foregroundStyle(DS.Semantic.warningForeground)
                Text(L10n.Groups.Migrated.bannerBody)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                Spacer(minLength: DS.Spacing.none)
            }
            .padding(DS.Spacing.md)
            .background(DS.Semantic.warningBackground, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .accessibilityElement(children: .combine)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    // MARK: - Actions

    private func handleSave() {
        dismissKeyboard()
        // Quien quedó sin valor en %/monto/partes no participa. Antes lo hacía el cierre de la
        // hoja de división; con el reparto en el formulario, se hace al guardar.
        viewModel.purgeEmptyParticipants()
        guard viewModel.save() else {
            // El save falló (throw atrapado en el VM). Presenta el error en vez de morir mudo:
            // cubre el grupo congelado por migración, la carrera pull-congela-mientras-guardas
            // y cualquier otro saveError. Sin esto el botón quedaba activo sin feedback alguno.
            if viewModel.saveError != nil {
                DS.Haptic.warning()
                showSaveErrorAlert = true
            }
            return
        }
        DS.Haptic.success()

        // F4: pago planificado de grupo — cierra el ciclo (marca pagado, avanza fecha, vincula
        // scheduledPaymentID en la TX real, borra el draft) en cuanto el SplitExpense existe,
        // independiente del alert opt-in de abajo. No-op para callers normales (callback nil).
        if let createdID = viewModel.lastCreatedExpenseID {
            onExpenseCreated?(createdID)
        }

        // Flujo Inbox (`presentsSuccessScreen == false`): comportamiento original — sin pantalla
        // de éxito. El opt-in (Caso A + bridge OFF) sigue gateando el dismiss.
        guard presentsSuccessScreen else {
            if optInApplies {
                pendingOptInExpenseID = viewModel.lastCreatedExpenseID
                showOptInAlert = true
                return
            }
            onSave()
            dismiss()
            return
        }

        // Flujo manual: construir el payload (crear o editar) y mostrar la pantalla de éxito.
        successData = buildSuccessData()

        // Opt-out: si Caso A + bridge OFF + creación, primero el alert; al resolver, se presenta
        // la pantalla de éxito (ver `resolveAfterOptIn`). El alert vive en `formView`, que sigue
        // montado (aún no activamos `showSuccessScreen`).
        if optInApplies {
            pendingOptInExpenseID = viewModel.lastCreatedExpenseID
            showOptInAlert = true
            return
        }

        presentSuccess()
    }

    /// Opt-out: Caso A + bridge effective OFF + creación (no edit). NO en una sesión solo-grupos: ahí el
    /// bridge es M5 puro (par virtual, sin TX real) y el invitado minimal no tiene cuentas
    /// personales donde registrar — consistente con `isAccountRequired` y el gate Caso C de
    /// `SettlementFormView`. Solo aplica en creación (`lastCreatedExpenseID != nil`).
    private var optInApplies: Bool {
        !viewModel.effectiveBridgeEnabled
            && !viewModel.isGroupsOnlySession
            && viewModel.isCaseA
            && viewModel.lastCreatedExpenseID != nil
    }

    /// Presenta la pantalla de éxito tras un pequeño delay (deja asentar el teclado/estado),
    /// espejando `NewTransactionView.showTransactionSuccess`.
    private func presentSuccess() {
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            dsWithAnimation(reduceMotion) {
                showSuccessScreen = true
            }
        }
    }

    /// Construye el payload de la pantalla de éxito desde el estado actual del VM (post-save).
    private func buildSuccessData() -> GroupExpenseSuccessData {
        let shares = viewModel.calculatedShares ?? []
        let participants = shares.map { share in
            GroupExpenseSuccessData.Participant(
                id: share.memberID,
                name: memberNameLookup[share.memberID] ?? "—",
                amount: share.amount
            )
        }
        let debt = GroupExpenseSuccessLogic.debt(
            total: viewModel.amount,
            shares: shares,
            currentUserMemberID: viewModel.currentUserMemberID,
            paidByMemberID: viewModel.paidByMemberID
        )
        return GroupExpenseSuccessData(
            groupName: group.name,
            groupColorHex: group.colorHex,
            date: viewModel.date,
            description: viewModel.expenseDescription,
            totalAmount: viewModel.amount,
            currencyCode: viewModel.currencyCode,
            paidByName: memberNameLookup[viewModel.paidByMemberID] ?? "—",
            paidByIsMe: viewModel.isCaseA,
            subcategoryName: viewModel.subcategoryName,
            accountName: viewModel.isCaseA ? viewModel.selectedAccount?.name : nil,
            accountColorHex: viewModel.isCaseA ? viewModel.selectedAccount?.colorHex : nil,
            splitType: viewModel.splitType,
            participants: participants,
            debt: debt,
            // `viewModel.isEditMode` ya es true aquí incluso tras CREAR (save() vincula
            // editingExpense al gasto nuevo). El discriminante de ESTE save es
            // lastCreatedExpenseID: non-nil solo en la rama de creación.
            isEditMode: viewModel.lastCreatedExpenseID == nil
        )
    }

    /// "Crear otro gasto": reinicia el VM a un form limpio del mismo grupo y vuelve al formulario.
    /// El gate `didInitialPrefill` (ya `true`) evita que el `onAppear` re-prellene.
    private func resetForAnother() {
        let vm = GroupExpenseViewModel(group: group, members: members, memberNameLookup: memberNameLookup)
        vm.setContext(modelContext)
        viewModel = vm
        dsWithAnimation(reduceMotion) {
            showSuccessScreen = false
            successData = nil
        }
    }

    /// Crea el draft opt-in y continúa. Llamado desde el alert "Sí".
    private func confirmOptIn() {
        guard let expenseID = pendingOptInExpenseID else { return }
        do {
            try DraftService.shared.createGroupExpenseOptInDraft(
                splitExpenseID: expenseID,
                groupZoneID: group.cloudKitZoneID
            )
        } catch {
            #if DEBUG
            print("GroupExpenseFormView: createGroupExpenseOptInDraft failed: \(error)")
            #endif
        }
        pendingOptInExpenseID = nil
        resolveAfterOptIn()
    }

    /// User dice "No" al alert opt-in: continúa sin crear draft.
    private func declineOptIn() {
        pendingOptInExpenseID = nil
        resolveAfterOptIn()
    }

    /// Tras resolver el alert opt-in: en flujo manual presenta la pantalla de éxito; en flujo
    /// Inbox mantiene el cierre directo original.
    private func resolveAfterOptIn() {
        if presentsSuccessScreen {
            presentSuccess()
        } else {
            onSave()
            dismiss()
        }
    }

    /// Abre las opciones rápidas (`open`) solo si ya hay un monto válido. Con monto 0
    /// muestra el alert pidiéndolo: dividir 0 no tiene sentido (los montos por persona
    /// quedarían en 0).
    private func openSplitIfAmountValid(_ open: () -> Void) {
        dismissKeyboard()
        guard viewModel.isAmountValid else {
            showAmountRequiredAlert = true
            return
        }
        open()
    }

    private func dismissKeyboard() {
        focusedField = nil
    }

    // MARK: - Helpers

    private var currencyCodeBinding: Binding<CurrencyCode> {
        Binding(
            get: { CurrencyCode(rawValue: viewModel.currencyCode) ?? .usd },
            set: { viewModel.currencyCode = $0.rawValue }
        )
    }
}

// MARK: - Focus Field

private enum ExpenseField: Hashable {
    case amount
    case description
}
