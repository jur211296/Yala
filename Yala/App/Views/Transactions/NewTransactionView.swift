//
//  NewTransactionView.swift
//  Yala
//
//  Created by Yala - New Transaction Form.
//

import SwiftData
import SwiftUI

// MARK: - New Transaction View

/// Vista minimalista para registrar una nueva transacción
struct NewTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState
    @Environment(AppPreferences.self) private var appPreferences

    @State private var viewModel = NewTransactionViewModel()
    @FocusState private var isNoteFieldFocused: Bool
    @FocusState private var isAmountFieldFocused: Bool

    // Autocomplete mention state
    @State private var currentMentionState: MentionState?

    // Success screen state
    @State private var showSuccessScreen = false
    @State private var successData: TransactionSuccessData?
    @State private var isCreatingAnother = false
    @State private var isEditingFromSuccess = false
    @State private var isDuplicating = false

    @ScaledMetric(relativeTo: .largeTitle) private var baseAmountSize: CGFloat = 64 // A11Y-DT: @ScaledMetric

    // Split calculator state
    @State private var splitFieldState = SplitCalculatorFieldState()

    // A0-Bridge V2.0: cached fetch del draft pendiente (evita re-fetch en hot path).
    @State private var cachedPendingGroupDraft: InboxDraft?

    // Quick action states
    @State private var showSavedToast = false
    @State private var savedToastMessage = ""
    @State private var duplicateAnimationVisible = true

    // Notification primer
    @State private var showingNotificationPrimer = false

    // Prefill parameters
    let prefillAccountID: PersistentIdentifier?
    let prefillCategoryID: PersistentIdentifier?
    let prefillSubcategoryName: String?
    let prefillFromChatDraft: ChatDraftPrefill?

    // Transaction being edited (if any)
    let transactionToEdit: TransactionItem?

    init(
        prefillAccountID: PersistentIdentifier? = nil,
        prefillCategoryID: PersistentIdentifier? = nil,
        prefillSubcategoryName: String? = nil,
        prefillFromChatDraft: ChatDraftPrefill? = nil,
        transactionToEdit: TransactionItem? = nil
    ) {
        self.prefillAccountID = prefillAccountID
        self.prefillCategoryID = prefillCategoryID
        self.prefillSubcategoryName = prefillSubcategoryName
        self.prefillFromChatDraft = prefillFromChatDraft
        self.transactionToEdit = transactionToEdit
    }

    // MARK: - A0-Bridge V2.0 Read-Only Mode (P1-3)

    /// True si la TX en edición viene del bridge de grupos (no editable manualmente).
    private var isBridgedReadOnly: Bool {
        guard let tx = transactionToEdit else { return false }
        return tx.splitExpenseID != nil || tx.splitSettlementID != nil
    }

    /// M6: True si la TX bridgeada es Caso A (cuenta personal real, no virtual).
    /// En este caso el form permite **edit parcial** — campos personales editables
    /// (cuenta/note/subcat/tags), campos del grupo read-only (monto/fecha/moneda/tipo).
    private var isBridgedCasoA: Bool {
        guard let tx = transactionToEdit,
              tx.splitExpenseID != nil,
              let account = tx.account,
              !account.isSystemAccount
        else { return false }
        return true
    }

    /// Hidrata `cachedPendingGroupDraft` una vez al aparecer (evita fetch en hot path del body).
    private func loadPendingGroupDraftIfNeeded() {
        guard isBridgedReadOnly,
              let splitID = transactionToEdit?.splitExpenseID,
              cachedPendingGroupDraft == nil else { return }
        let descriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == splitID && $0.subcategory == nil }
        )
        do {
            cachedPendingGroupDraft = try modelContext.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("NewTransactionView: pending group draft fetch failed: \(error)")
            #endif
            cachedPendingGroupDraft = nil
        }
    }

    @ViewBuilder
    private var bridgedTxReadOnlyBanner: some View {
        if let tx = transactionToEdit, isBridgedReadOnly {
            let pendingDraft = cachedPendingGroupDraft
            let message: String = {
                if pendingDraft != nil {
                    return L10n.Groups.Bridge.assignFromInbox
                } else if tx.splitSettlementID != nil {
                    return L10n.Groups.Bridge.editSettlementInGroup
                } else if isBridgedCasoA {
                    // M6: Caso A — edit parcial habilitado para campos personales.
                    return L10n.Groups.Bridge.editPartialBanner
                } else {
                    return L10n.Groups.Bridge.editFromGroup
                }
            }()
            let ctaLabel: String = pendingDraft != nil
                ? L10n.Inbox.openInbox
                : L10n.Groups.Detail.openGroup

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(DS.Typography.body)
                        .foregroundStyle(.thAccent)
                    Text(message)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                Button {
                    handleBridgedCTA(hasPendingDraft: pendingDraft != nil)
                } label: {
                    Text(ctaLabel)
                        .font(DS.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.thAccent)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(.thCard))
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.sm)
        }
    }

    private func handleBridgedCTA(hasPendingDraft: Bool) {
        dismiss()
        if hasPendingDraft {
            RouterEntryGate.shared.submit(.navigate(.inbox))
        } else if let zoneID = transactionToEdit?.splitGroupZoneID {
            // Si tenemos zoneID, intentar deeplink directo al grupo.
            RouterEntryGate.shared.submit(.navigate(.groupDetail(groupID: zoneID)))
        } else {
            // Fallback: lista genérica de grupos.
            RouterEntryGate.shared.submit(.navigate(.groups))
        }
    }

    var body: some View {
        if showSuccessScreen, let data = successData {
            TransactionSuccessView(
                data: data,
                onAccept: {
                    if viewModel.showNotificationPrimer {
                        showingNotificationPrimer = true
                    } else {
                        dismiss()
                    }
                },
                onCreateAnother: {
                    // Reset form for new transaction
                    let newViewModel = NewTransactionViewModel()
                    newViewModel.setContext(modelContext)
                    // Re-apply prefill account so "create another" keeps the same account context
                    if let accountID = prefillAccountID {
                        let allSubs = newViewModel.categories.flatMap { $0.subcategories ?? [] }
                        newViewModel.prefill(
                            accountID: accountID,
                            categoryID: nil,
                            subcategoryName: nil,
                            accounts: newViewModel.accounts,
                            subcategories: allSubs
                        )
                    }
                    viewModel = newViewModel
                    isCreatingAnother = true
                    dsWithAnimation(reduceMotion) {
                        showSuccessScreen = false
                        successData = nil
                    }
                },
                onEdit: {
                    // Go back to form with current data (flag prevents prefillFromContext from resetting)
                    isEditingFromSuccess = true
                    dsWithAnimation(reduceMotion) {
                        showSuccessScreen = false
                        successData = nil
                    }
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .sheet(isPresented: $showingNotificationPrimer, onDismiss: { dismiss() }) {
                NotificationPrimerSheet()
            }
        } else {
            transactionFormView
                .transition(.opacity)
        }
    }

    private var transactionFormView: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.none) {
                    // P1-3: oculto en read-only (no se cambia el tipo de TX bridgeada).
                    if !isBridgedReadOnly {
                        transactionTypeSelector
                            .padding(.top, DS.Spacing.sm)
                    }

                    // P1-3: banner CTA contextual cuando la TX es bridgeada.
                    bridgedTxReadOnlyBanner

                    // Contextual guide for new users (oculto en read-only).
                    if !isBridgedReadOnly {
                        ContextualGuideBanner.transaction()
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.top, DS.Spacing.xs)
                    }

                    // Resto del form: disabled granular según tipo bridged (M5 vs M6 Caso A).
                    Group {
                        Spacer()

                        // Central content area: campos del grupo (monto/fecha/tipo) — always
                        // disabled si bridged (M5 + M6 Caso A: el grupo es la fuente de verdad).
                        centralContent
                            .disabled(isBridgedReadOnly)
                            .opacity(isBridgedReadOnly ? 0.5 : 1.0)

                        Spacer()

                        // Bottom selection chips: campos personales (cuenta/subcat/tags) —
                        // M6 Caso A los habilita. M5 puro (Caso B/settlements) sigue disabled.
                        bottomChips
                            .disabled(isBridgedReadOnly && !isBridgedCasoA)
                            .opacity(isBridgedReadOnly && !isBridgedCasoA ? 0.5 : 1.0)
                            .padding(.bottom, DS.Spacing.lg)

                        // Register button: M6 Caso A puede guardar cambios personales (solo
                        // toca campos personales en SwiftData, no invoca service del grupo).
                        registerButton
                            .disabled(isBridgedReadOnly && !isBridgedCasoA)
                            .opacity(isBridgedReadOnly && !isBridgedCasoA ? 0.5 : 1.0)
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.bottom, DS.Spacing.xxl)
                    }
                }
            .scaleEffect(duplicateAnimationVisible ? 1.0 : 0.92)
            .opacity(duplicateAnimationVisible ? 1.0 : 0.0)
            .dismissKeyboardOnTap()
            .yalaScreenBackground(.subtle)
            .navigationTitle(
                (transactionToEdit != nil && !isDuplicating)
                    ? L10n.Transaction.editTransaction : L10n.Transaction.newTransaction
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }

                if !isBridgedReadOnly {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.showFavoritesSheet = true
                        } label: {
                            Image(systemName: "star.fill")
                                .font(DS.Typography.body)
                                .foregroundStyle(Color.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.Accessibility.favoriteTemplates)
                        .tint(Color.primary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAccountSelector) {
                // M6: en edit Caso A bridgeado, limitar a cuentas de la misma moneda del expense
                // (la moneda viene del grupo y no es editable desde aquí — read-only).
                AccountSelectorSheet(
                    selectedAccount: $viewModel.selectedAccount,
                    title: L10n.Transaction.account,
                    currencyFilter: isBridgedCasoA ? transactionToEdit?.currencyCode : nil
                )
                .onChange(of: viewModel.selectedAccount) { _, newAccount in
                    if let account = newAccount {
                        viewModel.currencyCode = account.currencyCode
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSourceAccountSelector) {
                AccountSelectorSheet(
                    selectedAccount: $viewModel.sourceAccount,
                    title: L10n.Transaction.sourceAccount,
                    excludeAccount: viewModel.destinationAccount
                )
            }
            .sheet(isPresented: $viewModel.showDestinationAccountSelector) {
                AccountSelectorSheet(
                    selectedAccount: $viewModel.destinationAccount,
                    title: L10n.Transaction.destinationAccount,
                    excludeAccount: viewModel.sourceAccount
                )
            }
            .sheet(isPresented: $viewModel.showSubcategorySelector) {
                SubcategorySelectorSheet(
                    selectedSubcategory: $viewModel.selectedSubcategory,
                    transactionType: viewModel.transactionType
                )
            }
            .sheet(isPresented: $viewModel.showTagSelector) {
                TagSelectorSheet(selectedTags: $viewModel.selectedTags)
            }
            .sheet(isPresented: $viewModel.showFavoritesSheet) {
                FavoritesListView(mode: .select) { favorite in
                    prefillFromFavorite(favorite)
                }
            }
            .sheet(isPresented: $viewModel.showDatePicker) {
                DatePickerSheet(selectedDate: $viewModel.transactionDate)
                    .onChange(of: viewModel.transactionDate) { _, _ in
                        Task {
                            await viewModel.loadExchangeRate(context: modelContext)
                        }
                    }
            }
            .sheet(isPresented: $viewModel.showNeedSelector) {
                NeedSelectorSheet(
                    selectedNeed: Binding(
                        get: {
                            viewModel.selectedNeed ?? viewModel.selectedSubcategory?.need
                                ?? .unclassified
                        },
                        set: { viewModel.selectedNeed = $0 }
                    )
                )
                .presentationDetents(DS.Adaptive.sheetDetents([.medium]))
            }
            .onChange(of: viewModel.showAccountSelector) { _, isPresenting in
                if isPresenting {
                    isNoteFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .onChange(of: viewModel.showSourceAccountSelector) { _, isPresenting in
                if isPresenting {
                    isNoteFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .onChange(of: viewModel.showDestinationAccountSelector) { _, isPresenting in
                if isPresenting {
                    isNoteFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .onChange(of: viewModel.showSubcategorySelector) { _, isPresenting in
                if isPresenting {
                    isNoteFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .onChange(of: viewModel.showTagSelector) { _, isPresenting in
                if isPresenting {
                    isNoteFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .onChange(of: viewModel.showFavoritesSheet) { _, isPresenting in
                if isPresenting {
                    isNoteFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .onChange(of: viewModel.showDatePicker) { _, isPresenting in
                if isPresenting {
                    isNoteFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .onChange(of: viewModel.showNeedSelector) { _, isPresenting in
                if isPresenting {
                    isNoteFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .alert(
                L10n.Alert.confirmDelete,
                isPresented: $viewModel.showDeleteConfirmation
            ) {
                Button(L10n.Action.cancel, role: .cancel) {}
                Button(L10n.Action.delete, role: .destructive) {
                    deleteTransaction()
                }
            } message: {
                Text(L10n.Alert.deleteWarning)
            }
            .alert(
                L10n.Validation.futureDateTitle,
                isPresented: $viewModel.showFutureDateAlert
            ) {
                Button(L10n.Common.understood, role: .cancel) {}
            } message: {
                Text(L10n.Validation.futureDateMessage)
            }
            .alert(
                L10n.Common.error,
                isPresented: Binding(
                    get: { viewModel.saveError != nil },
                    set: { if !$0 { viewModel.saveError = nil } }
                )
            ) {
                Button(L10n.Common.understood, role: .cancel) {}
            } message: {
                Text(viewModel.saveError ?? "")
            }
            .sheet(isPresented: $viewModel.showSaveAsFavoriteSheet) {
                favoriteSheetContent
            }
            .sheet(isPresented: $viewModel.showSaveAsRecurringSheet) {
                recurringSheetContent
            }
            .sheet(isPresented: $viewModel.showSplitCalculator) {
                splitCalculatorSheetContent
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text(savedToastMessage)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(Capsule().fill(Color.secondary.opacity(0.2)))
                        .padding(.bottom, DS.Spacing.xxxl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }

        .onAppear {
            viewModel.setContext(modelContext)
            prefillFromContext()
            loadPendingGroupDraftIfNeeded()
            // Force expense type in expenses-only mode
            if sessionState.isExpensesOnlyMode {
                viewModel.transactionType = .expense
            }
            // Auto-focus field based on user preference (only for new transactions)
            if transactionToEdit == nil, appPreferences.autoFocusField != .none {
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    switch appPreferences.autoFocusField {
                    case .none: break
                    case .amount: isAmountFieldFocused = true
                    case .description: isNoteFieldFocused = true
                    }
                }
            }
        }
        .onChange(of: viewModel.sourceAccount) { _, _ in
            Task {
                await viewModel.loadExchangeRate(context: modelContext)
            }
        }
        .onChange(of: viewModel.destinationAccount) { _, _ in
            Task {
                await viewModel.loadExchangeRate(context: modelContext)
            }
        }
    }

    // MARK: - Transaction Type Selector

    private var transactionTypeSelector: some View {
        TransactionTypeSelectorView(
            selectedType: $viewModel.transactionType,
            availableTypes: sessionState.isExpensesOnlyMode ? [.expense] : TransactionType.allCases,
            onTypeChange: { type in
                viewModel.selectedSubcategory = nil
                if type == .transfer {
                    viewModel.prepareForTransfer(allAccounts: viewModel.accounts)
                    Task {
                        await viewModel.loadExchangeRate(context: modelContext)
                    }
                }
            }
        )
    }

    // MARK: - Central Content

    private var centralContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            // Date chip - above description
            Button {
                viewModel.showDatePicker = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(DS.Typography.label)
                    Text(dateChipText)
                        .font(DS.Typography.label)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                )
            }
            .buttonStyle(.plain)

            // Note field with mention detection and popover autocomplete
            VStack(spacing: DS.Spacing.xs) {
                TextField(L10n.Transaction.description, text: $viewModel.note)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .textContentType(.none)
                    .autocorrectionDisabled(false)
                    .focused($isNoteFieldFocused)
                    .frame(maxWidth: 280)
                    .tint(Color.primary)
                    .onChange(of: viewModel.note) { _, newValue in
                        dsWithAnimation(reduceMotion) {
                            // Disable #!@ shortcuts for transfers
                            if viewModel.isTransfer {
                                currentMentionState = nil
                            } else {
                                currentMentionState = MentionState.detect(in: newValue)
                            }
                        }
                    }
                    .popover(isPresented: showAutocompletePopover, arrowEdge: .bottom) {
                        autocompletePopoverContent
                            .presentationCompactAdaptation(.popover)
                    }

                // Shortcut hint (hidden for transfers)
                if !viewModel.isTransfer {
                    Text(L10n.Transaction.descriptionHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Amount display (Standard or Transfer)
            if viewModel.needsExchangeRate {
                transferAmountDisplay
            } else {
                amountDisplay
            }

            // Exchange rate chip (shown when currency differs from preferred, not for transfers)
            // Use viewModel.currencyCode (transaction's currency), NOT effectiveCurrencyCode (account's currency)
            // This handles cases where transaction is in USD but account is in PEN
            if !viewModel.isTransfer,
               viewModel.currencyCode != appPreferences.defaultCurrencyCode.rawValue,
               viewModel.exchangeRate != 1.0 {
                exchangeRateChip
            }

            // Split indicator chip
            if viewModel.hasSplitData, let desc = viewModel.splitDescription {
                Button { viewModel.showSplitCalculator = true } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "percent")
                            .font(DS.Typography.labelTiny)
                        Text(desc)
                            .font(DS.Typography.labelSmall)
                    }
                    .foregroundStyle(.secondary)
                    .opacity(viewModel.isSplitStale ? 0.5 : 1.0)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .padding(.top, DS.Spacing.sm)
                .accessibilityIdentifier("new_transaction_split_chip")
            }

            // Category chip + Nature chip (visible when subcategory is selected, not for transfers)
            if !viewModel.isTransfer, let subcategory = viewModel.selectedSubcategory {
                HStack(spacing: DS.Spacing.sm) {
                    // Category chip (read-only, styled like NeedEditChip)
                    let category = subcategory.safeCategory
                    let categoryColor = Color(hex: category.colorHex)
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: category.iconName ?? "folder")
                            .font(DS.Typography.labelTiny)
                            .accessibilityHidden(true)
                        Text(category.name)
                            .font(DS.Typography.labelTiny)
                    }
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, DS.Chip.paddingH)
                    .padding(.vertical, DS.Chip.paddingV)
                    .background(
                        Capsule().fill(categoryColor.opacity(0.12))
                    )

                    if viewModel.transactionType != .income {
                        NeedEditChip(
                            need: viewModel.selectedNeed ?? subcategory.need
                        ) {
                            viewModel.showNeedSelector = true
                        }
                    }

                    if transactionToEdit?.scheduledPaymentID != nil {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(.purple)
                            .padding(DS.Spacing.xs)
                            .accessibilityHidden(true)
                            .background(
                                Circle().fill(.purple.opacity(0.12))
                            )
                    }
                }
                .padding(.top, DS.Spacing.sm)
            }

            // Quick actions bar
            quickActionsBar
                .padding(.top, DS.Spacing.lg)
        }
        .onChange(of: viewModel.selectedSubcategory) { _, newSubcategory in
            // Sync nature when subcategory changes
            if let subcategory = newSubcategory {
                viewModel.selectedNeed = subcategory.need
            } else {
                viewModel.selectedNeed = nil
            }
        }
    }

    /// Dynamic font size for amount based on length (scales with Dynamic Type via baseAmountSize)
    private var amountFontSize: CGFloat {
        let length = viewModel.amountString.count
        let ratio: CGFloat
        switch length {
        case 0...7: ratio = 1.0       // 64pt base
        case 8...9: ratio = 54.0 / 64.0
        case 10...11: ratio = 46.0 / 64.0
        case 12...13: ratio = 38.0 / 64.0
        default: ratio = 32.0 / 64.0
        }
        return baseAmountSize * ratio
    }

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
            if let symbol = currencySymbol {
                Text(symbol)
                    .font(.system(size: amountFontSize * 0.44, weight: .medium, design: .rounded))
                    .foregroundStyle(viewModel.amountColor.opacity(0.7))
                    .contentTransition(.numericText())
            }

            TextField("0.00", text: $viewModel.amountString)
                .font(.system(size: amountFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(viewModel.amountColor)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isAmountFieldFocused)
                .accessibilityIdentifier("new_transaction_amount")
                .fixedSize(horizontal: true, vertical: false)  // Dynamic width based on content
                .onChange(of: isAmountFieldFocused) { _, isFocused in
                    // When field gets focus and value is just "0" or "0.00", clear it
                    if isFocused
                        && (viewModel.amountString == "0" || viewModel.amountString == "0.00" || viewModel.amountString == "0,00")
                    {
                        viewModel.amountString = ""
                    }
                    // When field loses focus
                    if !isFocused {
                        if viewModel.amountString.isEmpty {
                            viewModel.amountString = "0.00"
                        } else {
                            viewModel.amountString = AmountInputHelper.formatWithGrouping(viewModel.amount)
                        }
                    }
                }
                .onChange(of: viewModel.amountString) { _, newValue in
                    // Filter to only allow digits and one decimal separator
                    let filtered = filterAmountInput(newValue)
                    if filtered != newValue {
                        viewModel.amountString = filtered
                    }
                    // Mark split as stale only on manual edits
                    if isAmountFieldFocused && viewModel.hasSplitData {
                        viewModel.isSplitStale = true
                    }
                }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .animation(.easeInOut(duration: DS.Animation.fast), value: viewModel.transactionType)
    }

    private func filterAmountInput(_ input: String) -> String {
        AmountInputHelper.filterAmountInput(input)
    }

    /// Currency display for amount field - respects user preference (code vs symbol)
    private var currencySymbol: String? {
        guard viewModel.effectiveAccount != nil else { return nil }
        return appPreferences.currencyIdentifier(for: viewModel.effectiveCurrencyCode)
    }

    /// Exchange rate chip showing the converted amount and rate
    /// Format: "≈ S/ 38.99 (TC: 3.8900)" or "≈ PEN 38.99 (TC: 3.8900)" based on user preference
    private var exchangeRateChip: some View {
        let rate = viewModel.exchangeRate
        let amount = viewModel.amount
        let convertedAmount = amount * rate

        let currencyDisplay = appPreferences.currencyIdentifier(for: appPreferences.defaultCurrencyCode.rawValue)

        // Format converted amount (no decimals if whole number, otherwise 2 decimals)
        let formattedAmount: String
        if convertedAmount.truncatingRemainder(dividingBy: 1) == 0 {
            formattedAmount = String(format: "%.0f", convertedAmount)
        } else {
            formattedAmount = String(format: "%.2f", convertedAmount)
        }

        let formattedRate = String(format: "%.4f", rate)

        return Text("≈ \(currencyDisplay) \(formattedAmount) (TC: \(formattedRate))")
            .font(DS.Typography.labelSmall)
            .foregroundStyle(.thSecondaryText)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                Capsule().fill(.thSecondaryText.opacity(0.1))
            )
            .padding(.top, DS.Spacing.sm)
    }

    // MARK: - Quick Actions Bar

    private var quickActionsBar: some View {
        HStack(spacing: DS.Spacing.xl) {
            // Duplicate (only in edit mode)
            if transactionToEdit != nil {
                quickActionButton(
                    icon: "doc.on.doc",
                    label: L10n.Action.duplicate
                ) {
                    duplicateTransaction()
                }
                .disabled(isBridgedCasoA)  // M6: duplicar TX bridgeada generaría TX huérfana sin splitExpenseID
                .opacity(isBridgedCasoA ? 0.4 : 1.0)
            }

            // Delete (only in edit mode)
            if transactionToEdit != nil {
                quickActionButton(
                    icon: "trash",
                    label: L10n.Action.delete
                ) {
                    viewModel.showDeleteConfirmation = true
                }
                .disabled(isBridgedCasoA)  // M6: delete reaparece como draft via próximo sync. Bloqueamos.
                .opacity(isBridgedCasoA ? 0.4 : 1.0)
            }

            // Split calculator (only for expenses)
            if viewModel.transactionType == .expense {
                quickActionButton(
                    icon: "percent",
                    label: L10n.Action.calculate
                ) {
                    viewModel.showSplitCalculator = true
                }
                .accessibilityIdentifier("new_transaction_split_action")
            }

            // Save as favorite
            quickActionButton(
                icon: "star",
                label: L10n.Action.favorite
            ) {
                viewModel.showSaveAsFavoriteSheet = true
            }
            .accessibilityIdentifier("new_transaction_favorite_action")

            // Save as recurring
            quickActionButton(
                icon: "repeat",
                label: L10n.Action.recurring
            ) {
                if viewModel.canSave {
                    viewModel.showSaveAsRecurringSheet = true
                } else {
                    viewModel.showValidationErrors = true
                    showToast(L10n.Validation.completeFieldsFirst)
                }
            }
        }
    }

    private func quickActionButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(.thCard)
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    )
                Text(label)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(BouncyButtonStyle())
    }

    // MARK: - Sheet Content (extracted to help type-checker)

    private var favoriteSheetContent: some View {
        SaveAsFavoriteSheet(
            transactionType: viewModel.transactionType,
            amount: viewModel.amount,
            note: viewModel.note,
            account: viewModel.selectedAccount,
            subcategory: viewModel.selectedSubcategory,
            tags: viewModel.selectedTags,
            needOverride: viewModel.selectedNeed,
            currencyCode: viewModel.effectiveCurrencyCode,
            onSaved: { message in
                showToast(message)
            }
        )
    }

    private var recurringSheetContent: some View {
        ScheduledPaymentEditorView(
            payment: nil,
            prefill: ScheduledPaymentPrefill(
                transactionType: viewModel.transactionType.rawValue,
                amount: AmountInputHelper.formatWithGrouping(viewModel.amount),
                note: viewModel.note,
                account: viewModel.selectedAccount,
                subcategory: viewModel.selectedSubcategory,
                tagIDs: Set(viewModel.selectedTags.map { $0.persistentModelID }),
                needOverride: viewModel.selectedNeed,
                currencyCode: viewModel.effectiveCurrencyCode,
                transactionDate: viewModel.transactionDate
            ),
            onSaved: { paymentID in
                handleRecurringSaved(paymentID: paymentID)
            }
        )
    }

    private var splitCalculatorSheetContent: some View {
        SplitCalculatorSheet(
            currencySymbol: viewModel.effectiveAccount != nil
                ? CurrencyCode(rawValue: viewModel.effectiveCurrencyCode)?.symbol ?? viewModel.effectiveCurrencyCode
                : nil,
            fieldState: splitFieldState,
            onUseSplit: { amount, splitType, totalAmount, myValue, divisor in
                viewModel.applySplitResult(
                    amount: amount,
                    splitType: splitType,
                    totalAmount: totalAmount,
                    myValue: myValue,
                    divisor: divisor
                )
            },
            onDismiss: {
                viewModel.showSplitCalculator = false
            }
        )
        .onAppear {
            // Prefill from existing split data if editing
            if let total = viewModel.splitTotalAmount,
               let type = viewModel.splitType,
               let myValue = viewModel.splitMyValue {
                splitFieldState.prefill(
                    totalAmount: total,
                    splitType: type,
                    myValue: myValue,
                    divisor: viewModel.splitDivisor
                )
            } else if viewModel.amount > 0 && !viewModel.hasSplitData {
                // Prefill total from current amount for new splits
                splitFieldState.prefillTotal(viewModel.amount)
                // Apply last used defaults
                if let lastType = UserDefaults.standard.string(forKey: "lastSplitType"),
                   let type = SplitType(rawValue: lastType) {
                    splitFieldState.splitType = type
                    if type == .percentage {
                        let lastPct = UserDefaults.standard.double(forKey: "lastSplitPercentage")
                        if lastPct > 0 {
                            splitFieldState.percentageText = lastPct == lastPct.rounded()
                                ? String(Int(lastPct))
                                : String(format: "%.1f", lastPct)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bottom Chips

    private var bottomChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                // Account chip (or source/dest for transfers)
                if viewModel.isTransfer {
                    // Source account chip - pink
                    SelectionChip(
                        icon: "arrow.up.circle",
                        text: viewModel.sourceAccount?.name ?? L10n.Transaction.origin,
                        isSelected: viewModel.sourceAccount != nil,
                        color: viewModel.sourceAccount != nil ? Color.hotPink : nil
                    ) {
                        dismissKeyboard()
                        viewModel.showSourceAccountSelector = true
                    }

                    // Destination account chip - purple
                    SelectionChip(
                        icon: "arrow.down.circle",
                        text: viewModel.destinationAccount?.name ?? L10n.Transaction.destination,
                        isSelected: viewModel.destinationAccount != nil,
                        color: viewModel.destinationAccount != nil ? Color.electricIndigo : nil
                    ) {
                        dismissKeyboard()
                        viewModel.showDestinationAccountSelector = true
                    }

                    // Transfer accounts validation message
                    if case .invalid(let message) = viewModel.accountValidation {
                        Text(message)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Semantic.errorForeground)
                    }
                } else {
                    SelectionChip(
                        icon: "creditcard",
                        text: viewModel.selectedAccount?.name ?? L10n.Transaction.account,
                        isSelected: viewModel.selectedAccount != nil,
                        color: viewModel.selectedAccount.map { Color(hex: $0.colorHex) }
                    ) {
                        dismissKeyboard()
                        viewModel.showAccountSelector = true
                    }
                    .accessibilityIdentifier("new_transaction_account_chip")
                }

                // Subcategory chip (not for transfers) - uses category color when selected
                if !viewModel.isTransfer {
                    SelectionChip(
                        icon: "tag",
                        text: viewModel.selectedSubcategory?.name ?? L10n.Transaction.subcategory,
                        isSelected: viewModel.selectedSubcategory != nil,
                        color: subcategoryChipColor
                    ) {
                        dismissKeyboard()
                        viewModel.showSubcategorySelector = true
                    }
                    .accessibilityIdentifier("new_transaction_subcategory_chip")
                }

                // Tags - individual chip per tag or default chip (not for transfers)
                if !viewModel.isTransfer {
                    if viewModel.selectedTags.isEmpty {
                        // Default chip when no tags selected
                        SelectionChip(
                            icon: "number",
                            text: L10n.Transaction.tags,
                            isSelected: false,
                            color: nil
                        ) {
                            dismissKeyboard()
                            viewModel.showTagSelector = true
                        }
                    } else {
                        // Individual chip for each selected tag with remove button inside
                        // Styled to match SelectionChip size
                        ForEach(viewModel.selectedTags, id: \.persistentModelID) { tag in
                            HStack(spacing: DS.Spacing.sm) {
                                // Tag content (tappable to open selector)
                                Button {
                                    dismissKeyboard()
                                    viewModel.showTagSelector = true
                                } label: {
                                    HStack(spacing: DS.Spacing.sm) {
                                        Image(systemName: tag.iconName)
                                            .font(DS.Typography.labelSmall)
                                        Text(tag.name)
                                            .font(DS.Typography.label)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)

                                // Remove button (X)
                                Button {
                                    dsWithAnimation(reduceMotion) {
                                        viewModel.selectedTags.removeAll { $0.persistentModelID == tag.persistentModelID }
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(DS.Typography.label)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(L10n.Accessibility.deleteTag)
                            }
                            .foregroundStyle(.thTagChip)
                            .padding(.horizontal, DS.FormRow.paddingV)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(
                                Capsule().fill(.thTagChip.opacity(0.12))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(.thTagChip.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale.current
        return f
    }()

    private var dateChipText: String {
        if Calendar.current.isDateInToday(viewModel.transactionDate) {
            return L10n.Date.today
        } else if Calendar.current.isDateInYesterday(viewModel.transactionDate) {
            return L10n.Date.yesterday
        } else {
            return Self.shortDateFormatter.string(from: viewModel.transactionDate)
        }
    }

    private var transferAccountsText: String {
        if let source = viewModel.sourceAccount, let dest = viewModel.destinationAccount {
            return "\(source.name) → \(dest.name)"
        } else if let source = viewModel.sourceAccount {
            return "\(source.name) → ?"
        } else {
            return L10n.Panel.accounts
        }
    }

    /// Text for the tags chip - comma-separated list of tag names
    private var tagsChipText: String {
        if viewModel.selectedTags.isEmpty {
            return L10n.Transaction.tags
        } else {
            return viewModel.selectedTags.map { $0.name }.joined(separator: ", ")
        }
    }

    /// Color for the subcategory chip - uses the category's color when selected
    private var subcategoryChipColor: Color? {
        guard let subcategory = viewModel.selectedSubcategory else {
            return nil
        }
        // Use subcategory color if it has one, otherwise use category color
        let colorHex = subcategory.colorHex ?? subcategory.safeCategory.colorHex
        return Color(hex: colorHex)
    }

    // MARK: - Transfer Amount Display

    private var transferAmountDisplay: some View {
        TransferAmountInputView(viewModel: viewModel)
    }

    // MARK: - Autocomplete

    /// Current autocomplete suggestions based on mention state
    private var autocompleteSuggestions: [AutocompleteSuggestion] {
        guard let mentionState = currentMentionState else { return [] }

        switch mentionState.type {
        case .tag:
            return AutocompleteHelper.getTagSuggestions(
                query: mentionState.query,
                allTags: viewModel.tags,
                recentTransactions: viewModel.transactions
            )
        case .subcategory:
            return AutocompleteHelper.getSubcategorySuggestions(
                query: mentionState.query,
                allSubcategories: viewModel.subcategories,
                recentTransactions: viewModel.transactions,
                transactionType: viewModel.transactionType
            )
        case .account:
            return AutocompleteHelper.getAccountSuggestions(
                query: mentionState.query,
                allAccounts: viewModel.accounts,
                recentTransactions: viewModel.transactions
            )
        }
    }

    /// Binding to control popover visibility
    private var showAutocompletePopover: Binding<Bool> {
        Binding(
            get: { currentMentionState != nil },
            set: { if !$0 { currentMentionState = nil } }
        )
    }

    /// Content for the autocomplete popover - clean list style (max 5 items)
    private var autocompletePopoverContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            if autocompleteSuggestions.isEmpty {
                Label(L10n.Search.noResults, systemImage: "tag")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
            } else {
                ForEach(Array(autocompleteSuggestions.prefix(5))) { suggestion in
                    Button {
                        handleAutocompleteSuggestion(suggestion)
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Circle()
                                .fill(Color(hex: suggestion.colorHex))
                                .frame(width: 10, height: 10)

                            Text(suggestion.name)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .frame(minWidth: 200, idealWidth: 240)
        .background(.thCard)
    }

    /// Title for current mention type
    private var mentionTypeTitle: String {
        guard let mentionState = currentMentionState else { return "" }
        switch mentionState.type {
        case .tag: return L10n.Transaction.tags
        case .subcategory: return L10n.Widget.subcategories
        case .account: return L10n.Panel.accounts
        }
    }

    /// Handle selection of an autocomplete suggestion
    private func handleAutocompleteSuggestion(_ suggestion: AutocompleteSuggestion) {
        guard let mentionState = currentMentionState else { return }

        // Remove the trigger and query from the note
        let triggerIndex = mentionState.triggerIndex
        var newNote = viewModel.note
        newNote.removeSubrange(triggerIndex...)

        // If there's content before, add a space
        if !newNote.isEmpty && !newNote.hasSuffix(" ") {
            newNote += " "
        }

        viewModel.note = newNote
        currentMentionState = nil

        // Apply the selection based on type
        switch suggestion.type {
        case .tag:
            if let tag = suggestion.tag {
                if !viewModel.selectedTags.contains(where: {
                    $0.persistentModelID == tag.persistentModelID
                }) {
                    viewModel.selectedTags.append(tag)
                }
            }
        case .subcategory:
            if let subcategory = suggestion.subcategory {
                viewModel.selectedSubcategory = subcategory
            }
        case .account:
            if let account = suggestion.account {
                if viewModel.isTransfer {
                    if viewModel.sourceAccount == nil {
                        viewModel.sourceAccount = account
                    } else {
                        viewModel.destinationAccount = account
                    }
                } else {
                    viewModel.selectedAccount = account
                }
            }
        }
    }

    // MARK: - Register Button

    private var registerButton: some View {
        YalaPrimaryButton(
            L10n.Action.save,
            icon: "checkmark.circle.fill",
            isDisabled: !viewModel.canSave || viewModel.isSaving,
            isLoading: viewModel.isSaving,
            disabledHint: !viewModel.canSave ? L10n.Accessibility.completeFormHint : nil
        ) {
            saveTransaction()
        }
        .accessibilityIdentifier("new_transaction_save")
        .dsAnimation(.easeInOut(duration: 0.2), value: viewModel.canSave, reduceMotion: reduceMotion)
    }

    // MARK: - Actions

    /// Dismisses keyboard by clearing focus states
    private func dismissKeyboard() {
        isNoteFieldFocused = false
        isAmountFieldFocused = false
    }

    private func saveTransaction() {
        if let saved = viewModel.save(context: modelContext), let first = saved.first {
            // Mark setup checklist step 2 with practice cleanup option
            if SetupChecklistManager.shared.stepCompleted[.firstExpense] != true {
                SetupChecklistManager.shared.markCompleted(
                    .firstExpense,
                    practiceItem: PracticeCleanupItem(
                        stepID: .firstExpense,
                        itemName: first.note ?? "",
                        persistentID: first.persistentModelID
                    )
                )
            } else {
                SetupChecklistManager.shared.markCompleted(.firstExpense)
            }

            // Si la NTV se abrió desde un draft del chat, broadcastear el
            // signal para que ChatAssistantViewModel marque el card como
            // `.saved` con el ID de la transacción real.
            if let chatDraft = prefillFromChatDraft, transactionToEdit == nil {
                SessionState.shared.chatDraftSavedSignal = SessionState.ChatDraftSavedSignal(
                    messageID: chatDraft.originMessageID,
                    draftID: chatDraft.originDraftID,
                    transactionID: first.persistentModelID
                )
            }

            showTransactionSuccess()
        }
    }

    private func showTransactionSuccess() {
        DS.Haptic.success()
        dismissKeyboard()

        let account = viewModel.isTransfer ? viewModel.sourceAccount : viewModel.selectedAccount
        let destAccount = viewModel.destinationAccount

        successData = TransactionSuccessData(
            transactionType: viewModel.transactionType,
            date: viewModel.transactionDate,
            accountName: account?.name ?? L10n.Transaction.account,
            accountColorHex: account?.colorHex ?? AppConstants.defaultColorHex,
            note: viewModel.note,
            amount: Decimal(viewModel.amount),
            currencyCode: viewModel.effectiveCurrencyCode,
            subcategoryName: viewModel.selectedSubcategory?.name,
            subcategoryColorHex: viewModel.selectedSubcategory?.colorHex,
            categoryName: viewModel.selectedSubcategory?.safeCategory.name,
            categoryColorHex: viewModel.selectedSubcategory?.safeCategory.colorHex,
            tags: viewModel.selectedTags.map { ($0.name, $0.colorHex) },
            need: viewModel.selectedNeed ?? viewModel.selectedSubcategory?.need,
            isTransfer: viewModel.isTransfer,
            destinationAccountName: destAccount?.name,
            destinationAccountColorHex: destAccount?.colorHex,
            destinationAmount: Decimal(viewModel.destinationAmount),
            destinationCurrencyCode: destAccount?.currencyCode
        )

        // Delay animation to let keyboard dismiss
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            dsWithAnimation(reduceMotion) {
                showSuccessScreen = true
            }

            // Check notification primer AFTER animation completes (~800ms)
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await viewModel.checkNotificationPrimer()
        }
    }

    private func prefillFromContext() {
        // Skip prefill if user chose "Create another" - viewModel already reset
        if isCreatingAnother {
            isCreatingAnother = false
            return
        }

        // Skip prefill if returning from success screen via "Edit" - viewModel already has saved data
        if isEditingFromSuccess {
            isEditingFromSuccess = false
            return
        }

        let allSubcategories = viewModel.categories.flatMap { $0.subcategories ?? [] }

        // Reset viewModel if opening for new transaction (prevents stale data from previous edit)
        if transactionToEdit == nil && viewModel.editingTransaction != nil {
            let newViewModel = NewTransactionViewModel()
            newViewModel.setContext(modelContext)
            viewModel = newViewModel
        }

        // If we're editing an existing transaction, load all its data
        if let tx = transactionToEdit {
            viewModel.editingTransaction = tx

            // Load amount (absolute value, since we store signed amounts)
            viewModel.amountString = AmountInputHelper.formatWithGrouping(abs(tx.amount))

            // Load account
            viewModel.selectedAccount = tx.account
            viewModel.sourceAccount = tx.account
            viewModel.currencyCode = tx.currencyCode

            // Load category/subcategory
            viewModel.selectedSubcategory = tx.subcategory

            // Determine transaction type from amount sign and category
            if tx.subcategory?.safeCategory.isIncome == true || tx.amount > 0 {
                viewModel.transactionType = .income
            } else {
                viewModel.transactionType = .expense
            }

            // Load date
            viewModel.transactionDate = tx.date

            // Load tags — CSV-mirror SSOT via resolver + TagResolver.
            viewModel.selectedTags = TagResolver.fetchOrEmpty(
                ids: tx.resolvedTagIDs(scheduleBackfill: true) ?? [],
                in: modelContext,
                errorContext: "NewTransactionView/edit"
            )

            // Load note
            viewModel.note = tx.note ?? ""

            // If this is a transfer, load the paired transaction
            if let pair = TransferPartnerLookup.partner(of: tx, in: modelContext) {
                viewModel.transactionType = .transfer
                // Defensive sign assignment — si ambos amounts >= 0 (corrupción), outTx default
                // a tx; el invariante out<0/in>0 puede estar violado pero el form sigue funcional.
                let outTx: TransactionItem
                let inTx: TransactionItem
                if tx.amount < 0 {
                    outTx = tx
                    inTx = pair
                } else if pair.amount < 0 {
                    outTx = pair
                    inTx = tx
                } else {
                    // Caso degenerado: ningún amount negativo.
                    outTx = tx
                    inTx = pair
                    #if DEBUG
                    print("prefillFromContext: sign invariant violated for pairID \(tx.transferPairID ?? "?") — both amounts >= 0")
                    #endif
                }
                viewModel.sourceAccount = outTx.account
                viewModel.destinationAccount = inTx.account
                viewModel.editingTransferPair = (out: outTx, in: inTx)
                // Use absolute amount from the outflow side
                viewModel.amountString = AmountInputHelper.formatWithGrouping(abs(outTx.amount))
            } else if tx.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer, tx.transferPairID != nil {
                // Partner no local. Puede ser CloudKit sync pendiente (partner llegará pronto) o
                // genuinely orphan. NO mutar/save destructivamente aquí: clear durante sync race
                // haría que CKSyncEngine resuelva conflicto contra el partner remoto recién subido,
                // destruyendo un pair legítimo. El reconciler boot-time decide post-sync con todos
                // los datos. Dejamos el form como TX normal (transactionType asignado por sign).
                #if DEBUG
                print("prefillFromContext: transfer partner not found locally for \(tx.persistentModelID) — deferring to boot reconciler")
                #endif
            }

            // Load exchange rate (for display chip when currency differs from preferred)
            // For non-transfers: shows rate from transaction currency to preferred currency
            if tx.currencyCode != appPreferences.defaultCurrencyCode.rawValue {
                if tx.exchangeRate != 1.0 {
                    // Use stored rate
                    viewModel.exchangeRate = tx.exchangeRate
                } else {
                    // Stored rate is 1.0 but currencies differ - load from CurrencyConverter
                    if let rate = CurrencyConverter.shared.getDisplayRate(
                        from: tx.currencyCode,
                        to: appPreferences.defaultCurrencyCode.rawValue,
                        date: tx.date,
                        context: modelContext
                    ) {
                        viewModel.exchangeRate = rate
                    } else {
                        // Fallback: use static rates from CurrencyCode enum
                        if let fromCurrency = CurrencyCode(rawValue: tx.currencyCode),
                           let toCurrency = CurrencyCode(rawValue: appPreferences.defaultCurrencyCode.rawValue) {
                            let fromRate = fromCurrency.fallbackRateToUSD
                            let toRate = toCurrency.fallbackRateToUSD
                            if fromRate > 0 {
                                viewModel.exchangeRate = toRate / fromRate
                            }
                        }
                    }
                }
            }

            // Load split data
            if let splitTypeRaw = tx.splitType, let splitType = SplitType(rawValue: splitTypeRaw) {
                viewModel.splitTotalAmount = tx.splitTotalAmount
                viewModel.splitType = splitType
                viewModel.splitMyValue = tx.splitMyValue
                viewModel.splitDivisor = tx.splitDivisor
            }

            return
        }

        // Chat draft prefill takes precedence (carries amount, date, note, IDs)
        if let chatDraft = prefillFromChatDraft {
            viewModel.prefill(
                fromChatDraft: chatDraft,
                accounts: viewModel.accounts,
                subcategories: allSubcategories
            )
            return
        }

        // Only use explicitly provided prefill account (no fallback to last transaction)
        viewModel.prefill(
            accountID: prefillAccountID,
            categoryID: prefillCategoryID,
            subcategoryName: prefillSubcategoryName,
            accounts: viewModel.accounts,
            subcategories: allSubcategories
        )
    }

    private func duplicateTransaction() {
        guard transactionToEdit != nil else { return }
        TelemetryService.track(.transactionDuplicated, parameters: ["type": viewModel.transactionType.rawValue])

        // Animate form out
        dsWithAnimation(reduceMotion) {
            duplicateAnimationVisible = false
        }

        // After animation out, update state and animate back in
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            // Keep all current form data but clear the editing reference
            // This turns the form into "create new" mode with prefilled data
            viewModel.editingTransaction = nil
            viewModel.editingTransferPair = nil
            viewModel.transactionDate = Date.now

            // Mark as duplicating to update title
            isDuplicating = true

            // Animate form back in
            dsWithAnimation(reduceMotion) {
                duplicateAnimationVisible = true
            }

            // Show feedback and focus amount
            showToast(L10n.Action.duplicated)
            isNoteFieldFocused = false
            isAmountFieldFocused = true
        }
    }

    private func deleteTransaction() {
        guard let transaction = transactionToEdit else { return }
        DS.Haptic.warning()

        do {
            // If this is a transfer, also delete the paired transaction
            if transaction.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer, let pairID = transaction.transferPairID {
                let fetchPairID = pairID
                let descriptor = FetchDescriptor<TransactionItem>(
                    predicate: #Predicate { $0.transferPairID == fetchPairID }
                )
                do {
                    let pairs = try modelContext.fetch(descriptor)
                    for pair in pairs where pair.persistentModelID != transaction.persistentModelID {
                        modelContext.delete(pair)
                    }
                } catch {
                    #if DEBUG
                    print("NewTransactionView: Error fetching transfer pairs for deletion: \(error)")
                    #endif
                }
            }

            modelContext.delete(transaction)
            try modelContext.save()
            TelemetryService.track(.transactionDeleted, parameters: ["type": viewModel.transactionType.rawValue])
            WidgetDataCache.updateCache(context: modelContext)
            SessionState.shared.incrementDataVersion()
            dismiss()
        } catch {
            #if DEBUG
            print("Error deleting transaction: \(error)")
            #endif
        }
    }

    private func handleRecurringSaved(paymentID: UUID) {
        // Always save the transaction (new or edited) before linking
        let txToLink = viewModel.save(context: modelContext)?.first
        txToLink?.scheduledPaymentID = paymentID.uuidString

        // Advance nextDueDate so the system doesn't create a duplicate draft
        let paymentIDString = paymentID.uuidString
        do {
            let descriptor = FetchDescriptor<ScheduledPayment>()
            if let payment = try modelContext.fetch(descriptor).first(where: { $0.id.uuidString == paymentIDString }) {
                let calendar = Calendar.current
                if calendar.startOfDay(for: payment.nextDueDate) <= calendar.startOfDay(for: Date.now) {
                    payment.lastPaidDate = Date.now
                    ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)
                }
            }
        } catch {
            #if DEBUG
            print("NewTransactionView: Error fetching scheduled payment: \(error)")
            #endif
        }

        do {
            try modelContext.save()
            WidgetDataCache.updateCache(context: modelContext)
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("NewTransactionView: Error linking to scheduled payment: \(error)")
            #endif
        }

        showTransactionSuccess()
    }

    private func showToast(_ message: String) {
        savedToastMessage = message
        dsWithAnimation(reduceMotion) {
            showSavedToast = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            dsWithAnimation(reduceMotion) {
                showSavedToast = false
            }
        }
    }

    private func prefillFromFavorite(_ favorite: FavoritePayment) {
        // Set transaction type
        viewModel.transactionType = favorite.type

        // Set amount if available
        if let amount = favorite.amount, amount > 0 {
            viewModel.amountString = AmountInputHelper.formatWithGrouping(amount)
        }

        // Set account if available
        if let account = favorite.account {
            viewModel.selectedAccount = account
            viewModel.sourceAccount = account
            viewModel.currencyCode = account.currencyCode
        }

        // Set subcategory if available
        viewModel.selectedSubcategory = favorite.subcategory

        // Set nature override if available
        if let needRaw = favorite.needOverride {
            viewModel.selectedNeed = SubcategoryNeed(rawValue: needRaw)
        } else {
            viewModel.selectedNeed = favorite.subcategory?.need
        }

        // Set tags — CSV-mirror SSOT via resolver + TagResolver.
        viewModel.selectedTags = TagResolver.fetchOrEmpty(
            ids: favorite.resolvedTagIDs(scheduleBackfill: true) ?? [],
            in: modelContext,
            errorContext: "NewTransactionView/clone-favorite"
        )

        // Set note if available
        if let note = favorite.note, !note.isEmpty {
            viewModel.note = note
        }
    }
}

#Preview {
    NewTransactionView()
        .previewAppPreferences()
}
