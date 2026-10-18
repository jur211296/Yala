//
//  AccountFormView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Formulario "Configurar cuenta"

struct AccountFormView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(EntityDeletionService.self) private var deletionService
    @Environment(SessionState.self) private var sessionState

    @State private var viewModel: AccountFormViewModel
    @State private var showBalanceCalculator: Bool = false
    /// «Eliminar cuenta» pregunta antes de borrar (ticket `deleting-an-account-asks-nothing`).
    @State private var showDeleteConfirmation: Bool = false
    @State private var calcFieldState = BalanceCalculatorFieldState()
    /// La hoja «¿Qué hacemos con lo que hay dentro?» de eliminar una cuenta con movimientos: la cuenta, con su
    /// nombre y su divisa leídos al tocar «Eliminar» (la hoja se sigue pintando con la cuenta ya eliminada).
    @State private var removalTarget: AccountRemovalTarget?
    /// La hoja eliminó la cuenta: al cerrarse, se cierra también el formulario (en su `onDismiss`, no
    /// mientras la hoja sigue montada — dos `dismiss` a la vez dejan presentaciones colgadas).
    @State private var accountWasRemoved: Bool = false
    /// La X o el gesto de cerrar con algo escrito (L7-5).
    @State private var showDiscardChangesAlert: Bool = false
    /// «Más opciones» plegado al crear la cuenta (L7-4).
    @State private var showsMoreOptions: Bool = false
    /// Tarjeta con varias divisas: las hojas de añadir una línea y de vincular una cuenta existente.
    @State private var showsAddLine: Bool = false
    @State private var showsLinkAccount: Bool = false
    /// Desvincular convierte la línea en otra cuenta que cuenta para el límite Free: sin hueco, se ofrece Pro.
    @State private var showsUpgradeToUnlink: Bool = false
    @FocusState private var focusedField: Field?
    /// Abre a media altura (ticket `account-form-as-medium-detent-sheet`); se puede tirar hacia arriba.
    @State private var selectedDetent: PresentationDetent = .medium
    @Environment(\.usesLargeSheets) private var usesLargeSheets
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Con un tamaño de texto de accesibilidad, media altura enseña un solo campo: la hoja abre grande.
    private var sheetDetents: Set<PresentationDetent> {
        dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large]
    }

    /// Grande si el usuario la arrastró o si no hay medium que mostrar: la ventana ancha
    /// (`.yalaSheetDetents` presenta `[.large]`) o el texto de accesibilidad. En esos dos casos
    /// `selectedDetent` no tiene por qué dejar `.medium`.
    private var isLargeDetent: Bool {
        usesLargeSheets || !sheetDetents.contains(.medium) || selectedDetent == .large
    }

    private enum Field {
        case name, accountNumber, balance
    }

    init(existingNames: [String], accountToEdit: Account? = nil) {
        _viewModel = State(
            initialValue: AccountFormViewModel(
                accountToEdit: accountToEdit,
                existingNames: existingNames
            ))
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                        generalSection
                        ContextualGuideBanner.accountForm(accountType: viewModel.selectedType)
                        currencySection
                        // Tarjeta con varias divisas: una línea dice de qué tarjeta es; una tarjeta de crédito (o una
                        // cuenta que ya tiene líneas) enseña «Otras divisas» a la vista (decisión 3 de Jürgen).
                        if viewModel.isCurrencyLockedAsLine || viewModel.hasBrokenLink {
                            lineMembershipSection
                        } else if showsLinesUpFront {
                            cardLinesSection
                        }
                        // Recordatorio y día de pago: solo la principal, o la notificación llegaría doble.
                        if viewModel.selectedType == .creditCard && viewModel.ownsCardSettings {
                            creditCardSection
                        }
                        if usesBalanceEditor {
                            // «Editar el saldo» (pantalla 8 del rediseño, auditoría UX 2.2, L7-6).
                            balanceEditSection
                        } else {
                            if viewModel.showAdjustmentMode {
                                adjustmentSection
                            }
                            balanceSection
                        }

                        // La ayuda para calcular el saldo, con la tarjeta rosa del onboarding (L7-2, variante 1):
                        // el enlace índigo de 15 pt que había aquí no se veía, y es donde la gente se atasca.
                        if !viewModel.isEditing && !sessionState.isExpensesOnlyMode {
                            guidedBalanceCard
                        }

                        if viewModel.isEditing {
                            actionsSection
                            // En el resto de tipos, «Otras divisas» está disponible pero más discreta: al final.
                            if viewModel.canManageLines && !showsLinesUpFront {
                                cardLinesSection
                            }
                        } else {
                            // Al crear, «Archivar» no tiene sentido y «Excluir» es una decisión avanzada: va
                            // plegado bajo «Más opciones», como en el rediseño aprobado (L7-4).
                            newAccountMoreOptionsSection
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                    .dismissKeyboardOnTap()
                }
                .scrollDismissesKeyboard(.interactively)
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
            // «Nueva cuenta» o «Editar cuenta»: alta y edición compartían «Configurar cuenta» (L7-4).
            .navigationTitle(viewModel.isEditing ? L10n.Account.edit : L10n.Account.new)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        requestClose()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { saveAccount() }, isDisabled: !viewModel.canSave)
                }
            }
            .sheet(isPresented: $viewModel.isPresentingColorPicker) {
                NavigationStack {
                    VStack(spacing: DS.Spacing.xxl) {
                        ColorPicker(
                            L10n.Common.selectColor,
                            selection: $viewModel.customColor,
                            supportsOpacity: false
                        )
                        .padding()

                        Button(L10n.Common.useThisColor) {
                            viewModel.updateColorFromCustom()
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()
                    }
                    .padding()
                    .navigationTitle(L10n.Common.newColor)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showBalanceCalculator) {
                BalanceCalculatorSheet(
                    accountType: viewModel.selectedType,
                    mindset: SessionState.shared.financialMindset,
                    currencySymbol: viewModel.selectedCurrency.symbol,
                    fieldState: calcFieldState,
                    onUseBalance: { amount in
                        if amount >= 0 {
                            viewModel.isPositive = true
                            viewModel.balanceText = AmountInputHelper.formatWithGrouping(amount)
                        } else {
                            viewModel.isPositive = false
                            viewModel.balanceText = AmountInputHelper.formatWithGrouping(abs(amount))
                        }
                    },
                    onDismiss: { showBalanceCalculator = false }
                )
            }
            .sheet(isPresented: $showsAddLine) {
                AddAccountLineSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showsLinkAccount) {
                LinkAccountLineSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showsUpgradeToUnlink) {
                UpgradePromptSheet(feature: .accounts, context: .limitReached)
            }
            .onChange(of: viewModel.isPresentingColorPicker) { _, isPresenting in
                if isPresenting { focusedField = nil }
            }
            .onChange(of: viewModel.selectedType) {
                calcFieldState.reset()
            }
            .onAppear {
                // Antes del contexto: decide qué pide el campo del saldo al abrir una cuenta ya creada (L7-6).
                viewModel.editsTodayBalance = !sessionState.isExpensesOnlyMode
                viewModel.setContext(modelContext)
                // Auto-focus name field for new accounts
                if !viewModel.isEditing {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        focusedField = .name
                    }
                }
            }
        }
        .yalaSheetDetents(sheetDetents, selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .modifier(AccountRemovalPresentation(
            target: $removalTarget,
            accountWasRemoved: $accountWasRemoved,
            deleteAccount: removeAccount,
            onDismissed: removalSheetDismissed
        ))
        .alert(
            L10n.Account.deleteError,
            isPresented: $viewModel.isShowingDeleteError,
            actions: {
                Button(L10n.Common.understood, role: .cancel) {}
            },
            message: {
                Text(viewModel.deleteErrorMessage)
            }
        )
        .alert(
            L10n.Common.error,
            isPresented: $viewModel.isShowingSaveError,
            actions: {
                Button(L10n.Common.understood, role: .cancel) {}
            },
            message: {
                Text(L10n.Common.saveError)
            }
        )
        .modifier(SecondaryCurrencySuggestionAlert(
            suggestion: $viewModel.secondaryCurrencySuggestion,
            preferred: CurrencyDefaults.currentPreferred,
            onAccept: { new, old in
                acceptSecondaryCurrency(new, replacing: old)
                dismiss()
            },
            onDecline: { dismiss() }
        ))
        .modifier(DiscardAccountChangesAlert(isPresented: $showDiscardChangesAlert) { dismiss() })
        .modifier(AccountLinesAlerts(viewModel: viewModel))
        .alert(
            viewModel.pendingCurrencyConversion.map { Self.currencyConversionTitle($0) } ?? "",
            isPresented: Binding(
                get: { viewModel.pendingCurrencyConversion != nil },
                // **El setter solo cierra el alert; NO revierte la divisa.** En iOS un alert no tiene
                // gesto de descarte: se cierra pulsando un botón, y SwiftUI escribe `false` aquí al
                // pulsar CUALQUIERA de ellos — Convertir incluido. Si este setter cancelara, competiría
                // con la acción del propio botón que lo disparó. Revertir es trabajo de Cancelar, que
                // lo hace explícitamente.
                set: { if !$0 { viewModel.pendingCurrencyConversion = nil } }
            ),
            actions: {
                // El dato se lee AQUÍ, síncronamente, y viaja en la llamada: el cuerpo `async` no
                // puede depender de un estado que el setter de arriba está a punto de limpiar.
                // (Sin `accessibilityIdentifier`: dentro del closure de un `.alert` no llega al árbol
                // de accesibilidad — `docs/aprendizajes-tecnicos.md`, 2026-09-04.)
                let pending = viewModel.pendingCurrencyConversion
                Button(L10n.Account.CurrencyChange.confirmAction) {
                    guard let pending else { return }
                    confirmCurrencyConversion(pending)
                }

                Button(L10n.Common.cancel, role: .cancel) {
                    viewModel.cancelCurrencyConversion()
                }
            },
            message: {
                if let pending = viewModel.pendingCurrencyConversion {
                    Text(Self.currencyConversionMessage(pending))
                }
            }
        )
        .alert(
            L10n.Account.CurrencyChange.blockedTitle,
            isPresented: $viewModel.isShowingCurrencyChangeBlocked,
            actions: {
                Button(L10n.Common.understood, role: .cancel) {
                    viewModel.cancelCurrencyConversion()
                }
            },
            message: {
                Text(L10n.Account.CurrencyChange.blockedMessage(blockedReasonsText))
            }
        )
        .alert(
            L10n.Account.CurrencyChange.ratesUnavailableTitle,
            isPresented: $viewModel.isShowingCurrencyRatesUnavailable,
            actions: {
                Button(L10n.Common.understood, role: .cancel) {}
            },
            message: {
                Text(L10n.Account.CurrencyChange.ratesUnavailableMessage)
            }
        )
        .modifier(AccountDeleteConfirmation(
            isPresented: $showDeleteConfirmation,
            accountName: viewModel.accountToEdit?.name ?? viewModel.name,
            recordCount: viewModel.accountTransactions.count,
            onConfirm: handleDeleteTapped
        ))
        .overlay {
            if viewModel.isConvertingCurrency {
                currencyConversionOverlay
            }
        }
        // A media conversión el histórico está partido entre dos divisas: cerrar el formulario ahí
        // dejaría la cuenta en un estado que ninguna pantalla sabe leer. Y con algo escrito, el gesto de
        // cerrar pregunta antes de tirarlo, como la X (L7-5).
        .onSheetDismissAttempt(isActive: viewModel.isConvertingCurrency || viewModel.hasUnsavedChanges) {
            guard !viewModel.isConvertingCurrency else { return }
            showDiscardChangesAlert = true
        }
    }

    /// La X: con algo escrito pregunta «¿Descartar cambios?», como la Bandeja y Categorías (L7-5).
    private func requestClose() {
        if viewModel.hasUnsavedChanges {
            focusedField = nil
            showDiscardChangesAlert = true
        } else {
            dismiss()
        }
    }

    /// Edición fuera del modo «solo gastos»: el saldo se edita con la pantalla «Editar el saldo» (L7-6).
    private var usesBalanceEditor: Bool {
        viewModel.isEditing && viewModel.editsTodayBalance
    }

    // MARK: - Texto del aviso de conversión

    /// Con movimientos, el título de siempre («¿Convertir N movimientos?»); sin ellos —solo
    /// programados, favoritos o borradores—, «¿Cambiar la divisa a USD?».
    static func currencyConversionTitle(
        _ pending: AccountFormViewModel.PendingCurrencyConversion
    ) -> String {
        pending.rowCount > 0
            ? L10n.Account.CurrencyChange.confirmTitle(pending.rowCount)
            : L10n.Account.CurrencyChange.confirmTitleNoHistory(pending.toCurrencyCode)
    }

    /// El cuerpo del aviso: qué se convierte y con qué tasa (decisión D7).
    ///
    /// Va en un solo `Text` con saltos de línea: es el `message` de un `.alert`, y ahí no caben
    /// vistas propias. Los importes se rotulan con el código ISO, no con el símbolo: el aviso pone
    /// dos divisas una al lado de la otra y «$» no dice cuál de las dos es.
    static func currencyConversionMessage(
        _ pending: AccountFormViewModel.PendingCurrencyConversion
    ) -> String {
        var paragraphs: [String] = []
        // Lo primero, la cifra que la persona entiende: en cuánto queda su saldo (L7-7).
        if let balance = pending.balancePreview {
            paragraphs.append(L10n.UXL7.currencyBalanceLine(
                formatPlanAmount(balance.before, currencyCode: pending.fromCurrencyCode, isEstimate: false),
                formatPlanAmount(balance.after, currencyCode: pending.toCurrencyCode, isEstimate: !balance.isExact)
            ))
        }
        if pending.rowCount > 0 {
            var line = L10n.Account.CurrencyChange.confirmMessage(pending.fromCurrencyCode, pending.toCurrencyCode)
            // Con una cuenta recién creada, el único «registro» es el saldo de partida: se nombra (L7-7).
            if pending.includesInitialBalance {
                line += " " + L10n.UXL7.currencyIncludesInitialBalance
            }
            paragraphs.append(line)
        }
        if pending.draftCount > 0 {
            paragraphs.append(L10n.Account.CurrencyChange.draftsLine(
                pending.draftCount, pending.toCurrencyCode))
        }
        if pending.planCount > 0 {
            var lines = [L10n.Account.CurrencyChange.plansHeader(pending.toCurrencyCode)]
            for item in pending.planPreview {
                lines.append(L10n.Account.CurrencyChange.planItem(
                    item.name,
                    formatPlanAmount(item.fromAmount, currencyCode: item.fromCurrencyCode, isEstimate: false),
                    formatPlanAmount(item.toAmount, currencyCode: pending.toCurrencyCode, isEstimate: item.isEstimate)
                ))
            }
            let more = pending.planCount - pending.planPreview.count
            if more > 0 { lines.append(L10n.Account.CurrencyChange.plansMore(more)) }
            paragraphs.append(lines.joined(separator: "\n"))
        }
        // El «no se puede deshacer» ya va dentro del texto de los movimientos; sin ellos, se dice aparte.
        if pending.rowCount == 0 {
            paragraphs.append(L10n.Account.CurrencyChange.cannotUndo)
        }
        return paragraphs.joined(separator: "\n\n")
    }

    private static func formatPlanAmount(_ value: Double, currencyCode: String, isEstimate: Bool) -> String {
        CurrencyFormattingHelper.currency(
            value,
            decimals: AccountCurrencyPlanLogic.fractionDigits(for: currencyCode),
            identifier: currencyCode,
            forceSign: false,
            isEstimate: isEstimate
        )
    }

    /// Tapa la pantalla mientras se reexpresa el histórico. Espeja el overlay del cambio de divisa
    /// preferida (`CurrencySettingsView`), que resuelve el mismo problema.
    private var currencyConversionOverlay: some View {
        ZStack {
            Color.black.opacity(DS.Opacity.overlay)
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.lg) {
                ProgressView()

                Text(L10n.Account.CurrencyChange.progressTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                Text(L10n.Account.CurrencyChange.progressSubtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(DS.Spacing.xxl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .accessibilityIdentifier("account_currency_converting")
    }

    // MARK: Secciones de la vista

    private var generalSection: some View {
        SectionBox(title: L10n.Common.general) {
            VStack(spacing: DS.Spacing.none) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(L10n.Account.accountName, text: $viewModel.name)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                        .accessibilityIdentifier("account_name_field")
                }
                .padding()

                SubsectionDivider()

                AccountTypeChips(selectedType: $viewModel.selectedType)

                SubsectionDivider()

                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(L10n.Account.accountNumber, text: $viewModel.accountNumber)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($focusedField, equals: .accountNumber)
                }
                .padding()
            }
        }
    }

    private var currencySection: some View {
        SectionBox(title: L10n.Account.currency) {
            VStack(alignment: .leading, spacing: DS.Spacing.none) {
                if viewModel.isCurrencyLockedAsLine {
                    // Una línea de tarjeta no cambia de divisa: es lo que la hace línea.
                    currencyRow(showsChevron: false, currency: viewModel.balanceDisplayCurrency)
                        .accessibilityIdentifier("account_currency_locked")

                    Text(L10n.Account.Lines.currencyLocked)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .accessibilityIdentifier("account_currency_locked_reason")
                } else if viewModel.isCurrencyEditable {
                    NavigationLink {
                        CurrencySelectorView(selectedCurrency: $viewModel.selectedCurrency)
                            .swipeBack()
                    } label: {
                        currencyRow(showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("account_currency_link")

                    // La tarjeta no puede pasar a la divisa de una de sus líneas: el guardado se bloquea y aquí dice por qué.
                    if let collision = viewModel.currencyCollidingLine {
                        Text(L10n.Account.Lines.currencyCollision(collision))
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Semantic.errorForeground)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                            .padding(.bottom)
                            .accessibilityIdentifier("account_currency_line_collision")
                    }
                } else {
                    // Sin `NavigationLink`: no hay destino al que llegar, así que tampoco hay tap.
                    // El motivo va debajo y no en un alert porque se puede leer ANTES de intentarlo
                    // — un alert solo aparecería después de un toque que no lleva a ninguna parte.
                    // La divisa de la CUENTA, no `selectedCurrency`: si el bloqueo aparece por una
                    // fila que llegó por sync mientras el selector estaba abierto, enseñar la
                    // elección del usuario junto a «no se puede cambiar» afirmaría algo falso.
                    currencyRow(showsChevron: false, currency: viewModel.balanceDisplayCurrency)
                        .accessibilityIdentifier("account_currency_locked")

                    Text(L10n.Account.CurrencyChange.blockedMessage(blockedReasonsText))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .accessibilityIdentifier("account_currency_locked_reason")
                }
            }
        }
    }

    private func currencyRow(showsChevron: Bool, currency: CurrencyCode? = nil) -> some View {
        let shown = currency ?? viewModel.selectedCurrency
        return HStack(spacing: DS.Spacing.md) {
            Text(currencyInfo(for: shown).flag)
                .font(DS.Typography.title)

            Text(L10n.Account.currency)
                .font(DS.Typography.body)
                .foregroundStyle(showsChevron ? .primary : .secondary)

            Spacer()

            Text(currencyInfo(for: shown).name.capitalized)
                .foregroundStyle(.secondary)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        // Dentro del label y tras el padding: sin esto el `Spacer` deja el centro de la fila muerto y solo
        // respondían la bandera y el chevron (`swiftui-ds.md`, medido el 2026-10-17 con XCUITest).
        .contentShape(Rectangle())
    }

    /// Los motivos del bloqueo, como lista legible. El orden lo fija el ViewModel para que el texto
    /// no cambie entre aperturas.
    private var blockedReasonsText: String {
        viewModel.blockedCurrencyReasons
            .map { reason in
                switch reason {
                case .transfer: return L10n.Account.CurrencyChange.blockedReasonTransfer
                case .groupExpense: return L10n.Account.CurrencyChange.blockedReasonGroupExpense
                case .groupSettlement: return L10n.Account.CurrencyChange.blockedReasonGroupSettlement
                }
            }
            .formatted(.list(type: .and))
    }

    private var adjustmentSection: some View {
        SectionBox(title: L10n.Account.adjustment) {
            VStack(spacing: DS.Spacing.none) {
                NavigationLink {
                    AdjustmentModeSelectorView(
                        selectedAdjustmentMode: $viewModel.selectedAdjustmentMode)
                } label: {
                    HStack {
                        Text(L10n.Account.adjustment)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(viewModel.selectedAdjustmentMode.displayName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                SubsectionDivider()

                Text(viewModel.selectedAdjustmentMode.description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Date picker for "Ajustar por registro" mode
                if viewModel.selectedAdjustmentMode == .byEntry && viewModel.isEditing {
                    SubsectionDivider()

                    HStack {
                        Text(L10n.Account.adjustmentDate)
                            .font(DS.Typography.body)
                        Spacer()
                        // Hasta hoy, como en «Editar el saldo»: un ajuste fechado mañana no cuenta en el saldo de hoy.
                        DateFieldButton(
                            date: $viewModel.adjustmentDate,
                            maxDate: nil,
                            title: L10n.Account.adjustmentDate
                        )
                    }
                    .padding()
                }
            }
        }
        .onChange(of: viewModel.selectedAdjustmentMode) {
            viewModel.adjustmentModeChanged()
        }
        .disabled(viewModel.isCurrencyChangeRequested)
    }

    private var balanceSection: some View {
        SectionBox(
            title: viewModel.isEditing
                ? (viewModel.selectedAdjustmentMode == .changeInitialBalance
                    ? L10n.Account.initialBalance : L10n.Account.newBalance) : L10n.Account.initialBalance
        ) {
            VStack(spacing: DS.Spacing.none) {
                // Show current balance (read-only) when editing (hidden in expenses-only mode)
                if viewModel.isEditing && !sessionState.isExpensesOnlyMode {
                    HStack {
                        Text(L10n.Account.currentBalance)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(
                            formatAmount(
                                viewModel.currentBalance, currency: viewModel.balanceDisplayCurrency)
                        )
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                    }
                    .padding()

                    SubsectionDivider()
                }

                // Sign selector (contextual labels for credit cards)
                HStack(spacing: DS.Spacing.md) {
                    Text(L10n.Account.sign)
                        .font(DS.Typography.subheadline)
                    Spacer()
                    Picker(L10n.Account.sign, selection: $viewModel.isPositive) {
                        if viewModel.selectedType == .creditCard {
                            Text(L10n.Account.Sign.inFavor).tag(true)
                            Text(L10n.Account.Sign.consumed).tag(false)
                        } else {
                            Text(L10n.Account.positive).tag(true)
                            Text(L10n.Account.negative).tag(false)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()

                SubsectionDivider()

                // Balance input
                balanceInput(
                    caption: viewModel.selectedAdjustmentMode == .changeInitialBalance
                        ? L10n.Account.initialBalance : L10n.Account.newBalance
                )
                .padding()

                // Por qué «Guardar» sigue apagado en una cuenta nueva: falta el saldo (L7-1, molde del onboarding).
                if !viewModel.isEditing && viewModel.parsedBalanceAmount == nil {
                    Text(L10n.UXL7.balanceRequiredHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .accessibilityIdentifier("account_balance_required_hint")
                }

                // Show calculated final balance for "Cambiar saldo inicial" mode
                if viewModel.isEditing
                    && viewModel.selectedAdjustmentMode == .changeInitialBalance,
                    let finalBalance = viewModel.calculatedFinalBalance
                {
                    SubsectionDivider()

                    HStack {
                        Text(L10n.Account.finalBalance + ":")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatAmount(finalBalance, currency: viewModel.selectedCurrency))
                            .font(DS.Typography.headline)
                            .foregroundStyle(finalBalance >= 0 ? Color.primary : DS.Semantic.errorForeground)
                    }
                    .padding()
                }

                // Adjustment preview for "Ajustar por registro" mode
                if viewModel.isEditing && viewModel.selectedAdjustmentMode == .byEntry,
                    let adjustment = viewModel.adjustmentAmount, viewModel.needsAdjustment
                {
                    SubsectionDivider()

                    HStack {
                        Text(L10n.Account.adjustment + ":")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatAdjustment(adjustment, currency: viewModel.selectedCurrency))
                            .font(DS.Typography.label)
                            .foregroundStyle(adjustment >= 0 ? DS.Semantic.successForeground : DS.Semantic.errorForeground)
                    }
                    .padding()
                }
            }
        }
    }

    private var colorSection: some View {
        SectionBox(title: L10n.Common.color) {
            VStack(spacing: DS.Spacing.none) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(spacing: DS.Spacing.lg) {
                        ForEach(viewModel.colorOptions, id: \.self) { hex in
                            Button {
                                viewModel.selectedColorHex = hex
                            } label: {
                                Circle()
                                    .fill(colorForHex(hex))
                                    .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                // A11Y-DM: anillo blanco decorativo de selección sobre muestras de color arbitrarias
                                                Color.white,
                                                lineWidth: viewModel.selectedColorHex == hex ? 3 : 1)
                                    )
                                    .shadow(radius: viewModel.selectedColorHex == hex ? 4 : 0)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Circle())
                            .accessibilityLabel(L10n.Accessibility.colorOption(hex))
                        }

                        Button {
                            viewModel.isPresentingColorPicker = true
                        } label: {
                            Circle()
                                .fill(DS.Colors.borderDark)
                                .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(DS.Typography.labelSmall)
                                        .foregroundStyle(.primary)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.Accessibility.selectColor)
                    }

                    Text(L10n.Tag.colorSelected(viewModel.selectedColorHex))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }

    private var actionsSection: some View {
        SectionBox(title: L10n.Common.actions) {
            VStack(spacing: DS.Spacing.none) {
                Toggle(isOn: $viewModel.excludeFromStatistics) {
                    Text(L10n.Account.excludeFromStats)
                }
                .onChange(of: viewModel.excludeFromStatistics) { _, excluded in viewModel.excludeChanged(to: excluded) }
                .accessibilityIdentifier("account_exclude_stats_toggle")

                .padding()

                SubsectionDivider()

                Toggle(isOn: $viewModel.isArchived) {
                    Text(L10n.Account.archive)
                }
                .onChange(of: viewModel.isArchived) { _, archived in viewModel.setArchived(archived) }
                .accessibilityIdentifier("account_archive_toggle")

                .padding()

                // Avisar sin confirmar: archivar no borra nada, cambia qué suma y qué se ve en
                // Registros. El texto dice dónde se deshace: el toggle de arriba, en esta tarjeta.
                if viewModel.showsArchiveExclusionNotice {
                    Text(L10n.Account.archiveExcludedNotice)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .accessibilityIdentifier("account_archive_excluded_notice")
                }

                if viewModel.isEditing {
                    SubsectionDivider()

                    Button(role: .destructive) {
                        requestDelete()
                    } label: {
                        HStack {
                            Spacer()
                            Text(L10n.Account.delete)
                            Spacer()
                        }
                    }
                    .accessibilityIdentifier("account_delete_button")
                    .padding()
                }
            }
        }
    }

    /// El campo grande del saldo, con su rótulo encima. Lo comparten el alta y «Editar el saldo».
    private func balanceInput(caption: String) -> some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                if !caption.isEmpty {
                    Text(caption)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                ZStack(alignment: .trailing) {
                    // «Ej. 1500», como el onboarding (L7-1): el «0.00» gris se leía como un valor ya puesto.
                    if viewModel.balanceText.isEmpty {
                        Text(L10n.Onboarding.balancePlaceholder)
                            .font(DS.Typography.largeTitle)
                            .foregroundStyle(DS.Semantic.disabledForeground.opacity(DS.Opacity.overlay))
                            .accessibilityHidden(true)
                    }

                    TextField("", text: $viewModel.balanceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(DS.Typography.largeTitle)
                        .focused($focusedField, equals: .balance)
                        .accessibilityIdentifier("account_balance_field")
                }
                .onChange(of: focusedField) { _, newField in
                    let isFocused = newField == .balance
                    // When field gains focus, clear placeholder values
                    if isFocused
                        && (viewModel.balanceText == "0" || viewModel.balanceText == "0.00" || viewModel.balanceText == "0,00")
                    {
                        viewModel.balanceText = ""
                    }
                    // When field loses focus, format if has value
                    if !isFocused && !viewModel.balanceText.isEmpty {
                        let amount = AmountInputHelper.parseDecimal(viewModel.balanceText)
                        viewModel.balanceText = AmountInputHelper.formatWithGrouping(amount)
                    }
                }
                .onChange(of: viewModel.balanceText) { _, newValue in
                    let filtered = AmountInputHelper.filterAmountInput(newValue)
                    if filtered != newValue {
                        viewModel.balanceText = filtered
                    }
                }
            }
        }
    }

    /// El selector de signo, con los rótulos de tarjeta cuando toca.
    private var signPicker: some View {
        HStack(spacing: DS.Spacing.md) {
            Text(L10n.Account.sign)
                .font(DS.Typography.subheadline)
            Spacer()
            Picker(L10n.Account.sign, selection: $viewModel.isPositive) {
                if viewModel.selectedType == .creditCard {
                    Text(L10n.Account.Sign.inFavor).tag(true)
                    Text(L10n.Account.Sign.consumed).tag(false)
                } else {
                    Text(L10n.Account.positive).tag(true)
                    Text(L10n.Account.negative).tag(false)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Nueva cuenta: ayuda del saldo y «Más opciones» (L7-2, L7-4)

    /// La tarjeta rosa del onboarding («¿No sabes tu saldo? Toca aquí y te ayudamos a calcularlo»), a todo el
    /// ancho bajo la caja del saldo (L7-2, variante 1). Rosa de marca sólido, sin degradado ni halo.
    private var guidedBalanceCard: some View {
        Button {
            focusedField = nil
            showBalanceCalculator = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus.forwardslash.minus")
                        .font(.system(size: 20, weight: .semibold)) // A11Y-DT: icono de la tarjeta, como el onboarding
                        .foregroundStyle(Color.emphasisPinkFill)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L10n.Onboarding.balanceGuidedTitle)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(Color.white)
                    Text(L10n.Onboarding.balanceGuidedSubtitle)
                        .font(DS.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold)) // A11Y-DT: chevron de la tarjeta destacada
                    .foregroundStyle(Color.white)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.emphasisPinkFill)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("account_balance_guided_card")
    }

    /// Al crear: solo «Excluir de las estadísticas», plegado (L7-4). Archivar llega al editar la cuenta.
    private var newAccountMoreOptionsSection: some View {
        SectionBox(title: "") {
            VStack(spacing: DS.Spacing.none) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showsMoreOptions.toggle() }
                } label: {
                    HStack {
                        Text(L10n.Common.moreOptions)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(DS.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(showsMoreOptions ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("account_more_options")

                if showsMoreOptions {
                    SubsectionDivider()
                    Toggle(isOn: $viewModel.excludeFromStatistics) {
                        Text(L10n.Account.excludeFromStats)
                    }
                    .onChange(of: viewModel.excludeFromStatistics) { _, excluded in
                        viewModel.excludeChanged(to: excluded)
                    }
                    .accessibilityIdentifier("account_exclude_stats_toggle")
                    .padding()
                }
            }
        }
    }

    // MARK: - Editar el saldo (L7-6)

    /// La pantalla 8 del rediseño de cuentas, adelantada sola: lo que dice Yala, cuánto tiene la persona de
    /// verdad hoy, la diferencia, cómo se corrige (las dos opciones de siempre, contadas en llano) y en
    /// cuánto queda la cuenta al guardar. El cálculo vive en `AccountBalanceCorrectionLogic`.
    private var balanceEditSection: some View {
        // Con un cambio de moneda pendiente el campo se vacía al guardar y el ajuste no se aplica: enseñar la
        // diferencia o «queda en» prometería una cifra que no queda (review de L7-6). Solo el saldo de hoy.
        let correction = viewModel.isCurrencyChangeRequested ? nil : viewModel.balanceCorrection
        let fixes = correction?.needsCorrection == true
        let currency = viewModel.balanceDisplayCurrency
        return VStack(spacing: DS.Spacing.xxl) {
            SectionBox(title: L10n.UXL7.BalanceEdit.sectionTitle) {
                VStack(spacing: DS.Spacing.none) {
                    HStack {
                        Text(L10n.UXL7.BalanceEdit.yalaSays)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatAmount(viewModel.currentBalance, currency: currency))
                            .font(DS.Typography.headline)
                            .strikethrough(fixes)
                            .foregroundStyle(fixes ? Color.secondary : Color.primary)
                            .accessibilityIdentifier("account_balance_yala_says")
                    }
                    .padding()

                    SubsectionDivider()

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(L10n.UXL7.BalanceEdit.question)
                            .font(DS.Typography.bodyBold)
                            .foregroundStyle(.primary)
                        Text(L10n.UXL7.BalanceEdit.questionHint)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)

                    signPicker
                        .padding()

                    balanceInput(caption: "")
                        .padding(.horizontal)
                        .padding(.bottom)

                    if let correction {
                        SubsectionDivider()
                        if fixes {
                            HStack {
                                Text(L10n.UXL7.BalanceEdit.difference)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatAdjustment(correction.difference, currency: currency))
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(correction.difference >= 0
                                        ? DS.Semantic.successForeground : DS.Semantic.errorForeground)
                                    .accessibilityIdentifier("account_balance_difference")
                            }
                            .padding()
                        } else {
                            Text(L10n.UXL7.BalanceEdit.matches)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }
                }
            }

            if let correction, fixes {
                SectionBox(title: L10n.UXL7.BalanceEdit.howTitle) {
                    VStack(spacing: DS.Spacing.sm) {
                        correctionOption(
                            .byEntry,
                            title: L10n.UXL7.BalanceEdit.byEntryTitle,
                            description: L10n.UXL7.BalanceEdit.byEntryDesc,
                            icon: "plus.forwardslash.minus"
                        )
                        if viewModel.selectedAdjustmentMode == .byEntry {
                            HStack {
                                Text(L10n.Account.adjustmentDate)
                                    .font(DS.Typography.body)
                                Spacer()
                                // Hasta hoy: un ajuste fechado mañana no cuenta en el «Saldo hoy» de la ficha,
                                // y «Al guardar, queda en» no sería verdad hoy.
                                DateFieldButton(
                                    date: $viewModel.adjustmentDate,
                                    maxDate: nil,
                                    title: L10n.Account.adjustmentDate
                                )
                            }
                            .padding(.horizontal, DS.Spacing.sm)
                        }
                        correctionOption(
                            .changeInitialBalance,
                            title: L10n.UXL7.BalanceEdit.initialTitle,
                            description: L10n.UXL7.BalanceEdit.initialDesc,
                            icon: "flag"
                        )
                        if viewModel.selectedAdjustmentMode == .changeInitialBalance {
                            Text(L10n.UXL7.BalanceEdit.initialChange(
                                formatAmount(correction.currentInitialBalance, currency: currency),
                                formatAmount(correction.newInitialBalance, currency: currency)
                            ))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DS.Spacing.sm)
                            .accessibilityIdentifier("account_balance_initial_change")
                        }
                    }
                    .padding()
                }

                Text(L10n.UXL7.BalanceEdit.result(
                    viewModel.trimmedName.isEmpty ? (viewModel.accountToEdit?.name ?? "") : viewModel.trimmedName,
                    formatAmount(correction.resultingBalance, currency: currency)
                ))
                .font(DS.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.xs)
                .accessibilityIdentifier("account_balance_result")
            }
        }
        .onChange(of: viewModel.selectedAdjustmentMode) {
            viewModel.adjustmentModeChanged()
        }
        .disabled(viewModel.isCurrencyChangeRequested)
    }

    /// Una de las dos formas de corregir, como tarjeta: la elegida, rellena de índigo (criterio de foco).
    private func correctionOption(
        _ mode: AdjustmentMode, title: String, description: String, icon: String
    ) -> some View {
        let isSelected = viewModel.selectedAdjustmentMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectedAdjustmentMode = mode }
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(DS.Typography.headline)
                    .foregroundStyle(isSelected ? Color.white : Color.electricIndigo)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    Text(description)
                        .font(DS.Typography.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white)
                        .accessibilityHidden(true)
                }
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(isSelected ? Color.selectedIndigoFill : Color.primary.opacity(0.06))
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("account_balance_fix_\(mode == .byEntry ? "entry" : "initial")")
    }

    private var creditCardSection: some View {
        SectionBox(title: L10n.Account.CreditCard.sectionTitle) {
            VStack(spacing: DS.Spacing.none) {
                Toggle(isOn: $viewModel.creditCardPaymentReminder) {
                    Text(L10n.Account.CreditCard.paymentReminder)
                }
                .padding()

                if viewModel.creditCardPaymentReminder {
                    SubsectionDivider()

                    HStack {
                        Text(L10n.Account.CreditCard.paymentDay)
                            .foregroundStyle(.primary)
                        Spacer()
                        Picker(L10n.Account.CreditCard.paymentDay, selection: $viewModel.creditCardPaymentDay) {
                            ForEach(1...28, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Static Formatters

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        return f
    }()

    // MARK: Helpers

    private func formatAmount(_ amount: Double, currency: CurrencyCode) -> String {
        Self.currencyFormatter.currencyCode = currency.rawValue
        return Self.currencyFormatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }

    private func formatAdjustment(_ amount: Double, currency: CurrencyCode) -> String {
        let sign = amount >= 0 ? "+" : ""
        Self.currencyFormatter.currencyCode = currency.rawValue
        let formatted = Self.currencyFormatter.string(from: NSNumber(value: amount)) ?? "0.00"
        return sign + formatted
    }

    // MARK: Guardado

    private func saveAccount() {
        if viewModel.saveAccount(context: modelContext) {
            if viewModel.secondaryCurrencySuggestion == nil {
                dismiss()
            }
            // else: alert will show and dismiss after user responds
        }
    }

    /// El usuario dijo que sí: convierte y guarda.
    ///
    /// El `Task` no es decorativo — la conversión refresca tasas antes de tocar importes, y eso hace
    /// red. Cerrar solo si el guardado salió bien deja el formulario abierto cuando algo falló, que
    /// es lo mismo que hace el guardado normal.
    private func confirmCurrencyConversion(
        _ pending: AccountFormViewModel.PendingCurrencyConversion
    ) {
        Task {
            if await viewModel.confirmCurrencyConversion(pending, context: modelContext) {
                if viewModel.secondaryCurrencySuggestion == nil {
                    dismiss()
                }
            }
        }
    }

    /// Añade la moneda nueva a las que enseña el Panel, o la pone en el sitio de `old` (L7-8).
    private func acceptSecondaryCurrency(_ code: String, replacing old: String?) {
        let raw = UserDefaults.standard.string(forKey: "secondaryCurrencies") ?? ""
        let newValue = SecondaryCurrencySuggestionLogic.applying(code, replacing: old, to: raw)
        PreferenceSyncService.shared.set(string: newValue, forKey: "secondaryCurrencies")
        SessionState.shared.needsExchangeRateWidgetRefresh = true

        Task {
            // Load historical exchange rates for the new currency
            let calendar = Calendar.current
            let today = Date.now
            guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: today) else { return }
            let dateInterval = DateInterval(start: oneYearAgo, end: today)
            await ExchangeRateService.shared.forceUpdateToday(context: modelContext)
            await ExchangeRateService.shared.forceRefreshRates(for: dateInterval, context: modelContext)
            SessionState.shared.needsExchangeRateWidgetRefresh = true
        }
    }

    // MARK: - Eliminación de cuenta

    /// El toque en «Eliminar cuenta». Con algo dentro abre directamente la hoja de mover o borrar, que ya
    /// pregunta y dice qué pasa con cada cosa; vacía, pide la confirmación corta (`AccountDeleteConfirmation`).
    /// Merge 2.1 → 2.2 (2026-10-17): la alerta del lote 7 decía que los registros «quedan en Registros, sin
    /// cuenta», y con la hoja de 2.1 eso ya no pasa nunca; delante de la hoja habría sido una segunda pregunta
    /// que contradice a la primera.
    private func requestDelete() {
        guard let account = viewModel.accountToEdit else { return }
        do {
            let inventory = try AccountRemovalService.inventory(of: account, context: modelContext)
            if inventory.shape.needsQuestion {
                accountWasRemoved = false
                removalTarget = AccountRemovalTarget(
                    account: account, name: account.name, currencyCode: account.currencyCode)
            } else {
                showDeleteConfirmation = true
            }
        } catch {
            #if DEBUG
            print("AccountFormView: Error reading account inventory: \(error)")
            #endif
            viewModel.deleteErrorMessage = L10n.Account.Removal.failedUnreadable
            viewModel.isShowingDeleteError = true
        }
    }

    /// Con algo dentro (movimientos, programados, favoritos o borradores pendientes) pregunta qué hacer con ello;
    /// vacía, se elimina como siempre. Card `tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst`.
    ///
    /// Lo que cuelga se LEE del store (`AccountRemovalService.inventory`), no de las relaciones inversas, y un
    /// fallo al leer no se toma por «vacía»: se avisa y no se elimina nada.
    private func handleDeleteTapped() {
        guard let account = viewModel.accountToEdit else { return }
        deletionService.setContext(modelContext)
        do {
            let inventory = try AccountRemovalService.inventory(of: account, context: modelContext)
            if inventory.shape.needsQuestion {
                accountWasRemoved = false
                removalTarget = AccountRemovalTarget(
                    account: account, name: account.name, currencyCode: account.currencyCode)
                return
            }
            try deletionService.deleteAccount(account)
            dismiss()
        } catch AccountRemovalService.Failure.unreadable {
            viewModel.deleteErrorMessage = L10n.Account.Removal.failedUnreadable
            viewModel.isShowingDeleteError = true
        } catch {
            #if DEBUG
            print("AccountFormView: Error deleting account: \(error)")
            #endif
            viewModel.deleteErrorMessage = error.localizedDescription
            viewModel.isShowingDeleteError = true
        }
    }

    /// Elimina la cuenta y guarda todo lo que la hoja dejó en el contexto (`EntityDeletionService.deleteAccount`).
    /// Antes suelta las filas que el formulario tenía cargadas: sigue montado mientras la hoja se cierra, y su
    /// `body` no debe leer filas ya borradas.
    private func removeAccount(_ account: Account) throws {
        viewModel.releaseLoadedRows()
        deletionService.setContext(modelContext)
        try deletionService.deleteAccount(account)
    }

    /// La hoja se cerró. Si eliminó la cuenta, se cierra también el formulario; si no (cancelar, o un error que
    /// deshizo todo), el formulario vuelve a leer sus filas, que soltó antes de guardar.
    private func removalSheetDismissed() {
        if accountWasRemoved {
            accountWasRemoved = false
            dismiss()
        } else {
            viewModel.loadAccounts()
            viewModel.loadTransactions()
            viewModel.loadPlans()
        }
    }

    // MARK: - Tarjeta con varias divisas (entrega 2)

    /// «Otras divisas» va a la vista en una tarjeta de crédito, o en cualquier cuenta que ya tenga líneas.
    private var showsLinesUpFront: Bool {
        viewModel.canManageLines && (viewModel.selectedType == .creditCard || !viewModel.cardLines.isEmpty)
    }

    /// Las líneas de la tarjeta y las dos formas de añadir una: crear una nueva o vincular una cuenta que ya existe.
    private var cardLinesSection: some View {
        SectionBox(title: L10n.Account.Lines.sectionTitle) {
            VStack(alignment: .leading, spacing: DS.Spacing.none) {
                ForEach(viewModel.cardLines, id: \.persistentModelID) { line in
                    HStack(spacing: DS.Spacing.md) {
                        let code = normalizeCurrencyCode(line.currencyCode)
                        Text(currencyInfo(for: CurrencyCode(rawValue: code) ?? .usd).flag)
                            .font(DS.Typography.title)
                            .accessibilityHidden(true)
                        Text(L10n.Account.Lines.lineLabel(code))
                            .font(DS.Typography.body)
                        Spacer()
                    }
                    .padding()
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("account_line_\(normalizeCurrencyCode(line.currencyCode))")
                    SubsectionDivider()
                }

                if !viewModel.addableLineCurrencies.isEmpty {
                    lineActionRow(title: L10n.Account.Lines.add, icon: "plus.circle", id: "account_lines_add") {
                        focusedField = nil
                        showsAddLine = true
                    }
                    SubsectionDivider()
                }
                lineActionRow(title: L10n.Account.Lines.link, icon: "link", id: "account_lines_link") {
                    focusedField = nil
                    showsLinkAccount = true
                }

                if viewModel.selectedType == .creditCard {
                    Text(L10n.Account.Lines.sectionFooter)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
        }
    }

    private func lineActionRow(title: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(DS.Typography.body)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DS.Typography.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.thAccent)
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    /// Una línea: de qué tarjeta es y «Desvincular». Una cuenta con un enlace que ya no vale: por qué se ve suelta.
    private var lineMembershipSection: some View {
        SectionBox(title: L10n.Account.Lines.sectionTitle) {
            VStack(alignment: .leading, spacing: DS.Spacing.none) {
                Group {
                    if let principal = viewModel.principalOfLine {
                        Text(L10n.Account.Lines.isLineOf(
                            currencyCode: normalizeCurrencyCode(viewModel.accountToEdit?.currencyCode ?? ""),
                            cardName: principal.name))
                    } else {
                        Text(L10n.Account.Lines.broken)
                    }
                }
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .accessibilityIdentifier("account_line_membership")

                SubsectionDivider()

                Button {
                    if viewModel.unlinkFitsTheFreeLimit {
                        viewModel.unlink()
                    } else {
                        showsUpgradeToUnlink = true
                    }
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "minus.circle")
                            .accessibilityHidden(true)
                        Text(L10n.Account.Lines.unlink)
                        Spacer()
                    }
                    .foregroundStyle(.thAccent)
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("account_line_unlink")

                Text(L10n.Account.Lines.unlinkFooter)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
    }
}

// MARK: - Avisos de la tarjeta con varias divisas

/// «¿Archivar también sus líneas?» y el error de añadir, vincular o desvincular. Los botones de un `.alert` van con
/// texto fijo (`swiftui-ds.md`); lo que cambia es el título y el mensaje.
private struct AccountLinesAlerts: ViewModifier {
    @Bindable var viewModel: AccountFormViewModel

    func body(content: Content) -> some View {
        content
            .alert(L10n.Account.Lines.archiveTitle, isPresented: $viewModel.isAskingArchiveLines) {
                Button(L10n.Account.Lines.archiveAll) { viewModel.answerArchiveLines(true) }
                Button(L10n.Account.Lines.archiveOnlyCard) { viewModel.answerArchiveLines(false) }
                Button(L10n.Common.cancel, role: .cancel) { viewModel.answerArchiveLines(nil) }
            } message: {
                Text(L10n.Account.Lines.archiveMessage(viewModel.accountToEdit?.name ?? viewModel.trimmedName))
            }
            .alert(L10n.Common.error, isPresented: $viewModel.isShowingLineActionError) {
                Button(L10n.Common.understood, role: .cancel) {}
            } message: {
                Text(viewModel.lineActionError ?? "")
            }
    }
}

// MARK: - Hoja de eliminar con algo dentro

/// La cuenta que se va a eliminar, con lo que la hoja necesita leído ANTES de eliminarla.
struct AccountRemovalTarget: Identifiable {
    let account: Account
    let name: String
    let currencyCode: String
    var id: PersistentIdentifier { account.persistentModelID }
}

/// Presenta `AccountRemovalSheet` desde el formulario. Va en su propio modificador: la cadena del `body` ya es
/// larga y el compilador del CI (Xcode 26.6) deja de tiparla con un modificador más (`swiftui-ds.md`).
private struct AccountRemovalPresentation: ViewModifier {
    @Binding var target: AccountRemovalTarget?
    @Binding var accountWasRemoved: Bool
    let deleteAccount: (Account) throws -> Void
    let onDismissed: () -> Void

    func body(content: Content) -> some View {
        content.sheet(item: $target, onDismiss: onDismissed) { target in
            AccountRemovalSheet(
                account: target.account, name: target.name, currencyCode: target.currencyCode,
                deleteAccount: deleteAccount
            ) { accountWasRemoved = true }
        }
    }
}

// MARK: - Confirmación de borrado

/// La alerta de «Eliminar cuenta» para una cuenta VACÍA (`requestDelete`). Con algo dentro la pregunta es la hoja
/// de mover o borrar, así que aquí `recordCount` llega a 0 y la rama con registros no se alcanza desde la app.
///
/// Va en un modificador propio y no en la cadena del `body`, que ya lleva siete alertas: el compilador del CI
/// (Xcode 26.6) se rinde antes con cadenas largas (`swiftui-ds.md`). Los botones van con texto fijo: el
/// builder de `actions` de un `.alert` no admite etiquetas que dependan del estado.
///
struct AccountDeleteConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    let accountName: String
    let recordCount: Int
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.alert(L10n.Account.deleteConfirmTitle(accountName), isPresented: $isPresented) {
            Button(L10n.Action.delete, role: .destructive) { onConfirm() }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(Self.message(recordCount: recordCount))
        }
    }

    static func message(recordCount: Int) -> String {
        recordCount > 0
            ? L10n.Account.deleteConfirmMessage(recordCount)
            : L10n.Account.deleteConfirmMessageEmpty
    }
}
