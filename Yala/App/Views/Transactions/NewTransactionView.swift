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
    @Environment(\.yalaTheme) private var theme

    @AppStorage("defaultCurrencyCode") private var preferredCurrencyCode: String = CurrencyCode.pen.rawValue
    @AppStorage("currencyDisplayFormat") private var currencyDisplayFormat: String = "code"

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

    @ScaledMetric(relativeTo: .largeTitle) private var baseAmountSize: CGFloat = 64

    // Quick action states
    @State private var showSavedToast = false
    @State private var savedToastMessage = ""
    @State private var duplicateAnimationVisible = true

    // Prefill parameters
    let prefillAccountID: PersistentIdentifier?
    let prefillCategoryID: PersistentIdentifier?
    let prefillSubcategoryName: String?

    // Transaction being edited (if any)
    let transactionToEdit: TransactionItem?

    init(
        prefillAccountID: PersistentIdentifier? = nil,
        prefillCategoryID: PersistentIdentifier? = nil,
        prefillSubcategoryName: String? = nil,
        transactionToEdit: TransactionItem? = nil
    ) {
        self.prefillAccountID = prefillAccountID
        self.prefillCategoryID = prefillCategoryID
        self.prefillSubcategoryName = prefillSubcategoryName
        self.transactionToEdit = transactionToEdit
    }

    var body: some View {
        if showSuccessScreen, let data = successData {
            TransactionSuccessView(
                data: data,
                onAccept: {
                    dismiss()
                },
                onCreateAnother: {
                    // Reset form for new transaction
                    let newViewModel = NewTransactionViewModel()
                    newViewModel.setContext(modelContext)
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
        } else {
            transactionFormView
                .transition(.opacity)
        }
    }

    private var transactionFormView: some View {
        NavigationStack {
            ZStack {
                theme.background
                    .ignoresSafeArea()
                    .dismissKeyboardOnTap()

                VStack(spacing: DS.Spacing.none) {
                    // Transaction type selector
                    transactionTypeSelector
                        .padding(.top, DS.Spacing.sm)

                    Spacer()

                    // Central content area
                    centralContent

                    Spacer()

                    // Bottom selection chips
                    bottomChips
                        .padding(.bottom, DS.Spacing.lg)

                    // Exchange rate section removed - integrated into centralContent

                    // Register button
                    registerButton
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.bottom, DS.Spacing.xxl)
                }
                .scaleEffect(duplicateAnimationVisible ? 1.0 : 0.92)
                .opacity(duplicateAnimationVisible ? 1.0 : 0.0)
            }
            .navigationTitle(
                (transactionToEdit != nil && !isDuplicating)
                    ? L10n.Transaction.editTransaction : L10n.Transaction.newTransaction
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: "Cerrar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showFavoritesSheet = true
                    } label: {
                        Image(systemName: "star.fill")
                            .font(DS.Typography.body)
                            .foregroundStyle(Color(UIColor.label))
                    }
                    .accessibilityLabel("Plantillas favoritas")
                    .tint(Color(UIColor.label))
                }
            }
            .sheet(isPresented: $viewModel.showAccountSelector) {
                AccountSelectorSheet(
                    selectedAccount: $viewModel.selectedAccount,
                    title: L10n.Transaction.account
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
                    title: L10n.Transaction.sourceAccount
                )
            }
            .sheet(isPresented: $viewModel.showDestinationAccountSelector) {
                AccountSelectorSheet(
                    selectedAccount: $viewModel.destinationAccount,
                    title: L10n.Transaction.destinationAccount
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
                    .presentationDetents([.medium, .large])
                    .onChange(of: viewModel.transactionDate) { _, _ in
                        Task {
                            await viewModel.loadExchangeRate(context: modelContext)
                        }
                    }
            }
            .sheet(isPresented: $viewModel.showNatureSelector) {
                NatureSelectorSheet(
                    selectedNature: Binding(
                        get: {
                            viewModel.selectedNature ?? viewModel.selectedSubcategory?.nature
                                ?? .unclassified
                        },
                        set: { viewModel.selectedNature = $0 }
                    )
                )
                .presentationDetents([.medium])
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
            .onChange(of: viewModel.showNatureSelector) { _, isPresenting in
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
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text(savedToastMessage)
                        .font(DS.Typography.label)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(Capsule().fill(Color(UIColor.darkGray)))
                        .padding(.bottom, DS.Spacing.xxxl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }

        .onAppear {
            viewModel.setContext(modelContext)
            prefillFromContext()
            // Force expense type in expenses-only mode
            if sessionState.isExpensesOnlyMode {
                viewModel.transactionType = .expense
            }
            // Auto-focus amount field only for new transactions (not editing)
            if transactionToEdit == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isAmountFieldFocused = true
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
                        .fill(Color(UIColor.label).opacity(0.08))
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
                    .tint(Color(UIColor.label))
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
               viewModel.currencyCode != preferredCurrencyCode,
               viewModel.exchangeRate != 1.0 {
                exchangeRateChip
            }

            // Category chip + Nature chip (visible when subcategory is selected, not for transfers)
            if !viewModel.isTransfer, let subcategory = viewModel.selectedSubcategory {
                HStack(spacing: DS.Spacing.sm) {
                    // Category chip (read-only, styled like NatureEditChip)
                    let category = subcategory.safeCategory
                    let categoryColor = Color(hex: category.colorHex)
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: category.iconName ?? "folder")
                            .font(DS.Typography.labelTiny)
                        Text(category.name)
                            .font(DS.Typography.labelTiny)
                    }
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, DS.Chip.paddingH)
                    .padding(.vertical, DS.Chip.paddingV)
                    .background(
                        Capsule().fill(categoryColor.opacity(0.12))
                    )

                    NatureEditChip(
                        nature: viewModel.selectedNature ?? subcategory.nature
                    ) {
                        viewModel.showNatureSelector = true
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
                viewModel.selectedNature = subcategory.nature
            } else {
                viewModel.selectedNature = nil
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
                .fixedSize(horizontal: true, vertical: false)  // Dynamic width based on content
                .onChange(of: isAmountFieldFocused) { _, isFocused in
                    // When field gets focus and value is just "0" or "0.00", clear it
                    if isFocused
                        && (viewModel.amountString == "0" || viewModel.amountString == "0.00")
                    {
                        viewModel.amountString = ""
                    }
                    // When field loses focus
                    if !isFocused {
                        if viewModel.amountString.isEmpty {
                            viewModel.amountString = "0.00"
                        } else {
                            let sep = Locale.current.decimalSeparator ?? "."
                            viewModel.amountString = String(format: "%.2f", viewModel.amount)
                                .replacingOccurrences(of: ".", with: sep)
                        }
                    }
                }
                .onChange(of: viewModel.amountString) { _, newValue in
                    // Filter to only allow digits and one decimal separator
                    let filtered = filterAmountInput(newValue)
                    if filtered != newValue {
                        viewModel.amountString = filtered
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
        let code = viewModel.effectiveCurrencyCode
        if let currency = CurrencyCode(rawValue: code) {
            return currencyDisplayFormat == "symbol" ? currency.symbol : currency.rawValue
        }
        return code
    }

    /// Exchange rate chip showing the converted amount and rate
    /// Format: "≈ S/ 38.99 (TC: 3.8900)" or "≈ PEN 38.99 (TC: 3.8900)" based on user preference
    private var exchangeRateChip: some View {
        let rate = viewModel.exchangeRate
        let amount = viewModel.amount
        let convertedAmount = amount * rate

        // Get preferred currency display based on user setting
        let currencyDisplay: String
        if let currency = CurrencyCode(rawValue: preferredCurrencyCode) {
            currencyDisplay = currencyDisplayFormat == "symbol" ? currency.symbol : currency.rawValue
        } else {
            currencyDisplay = preferredCurrencyCode
        }

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
            }

            // Delete (only in edit mode)
            if transactionToEdit != nil {
                quickActionButton(
                    icon: "trash",
                    label: L10n.Action.delete
                ) {
                    viewModel.showDeleteConfirmation = true
                }
            }

            // Save as favorite
            quickActionButton(
                icon: "star",
                label: L10n.Action.favorite
            ) {
                viewModel.showSaveAsFavoriteSheet = true
            }

            // Save as recurring
            quickActionButton(
                icon: "repeat",
                label: L10n.Action.recurring
            ) {
                viewModel.showSaveAsRecurringSheet = true
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
            natureOverride: viewModel.selectedNature,
            currencyCode: viewModel.effectiveCurrencyCode,
            onSaved: { message in
                showToast(message)
            }
        )
    }

    private var recurringSheetContent: some View {
        SaveAsRecurringSheet(
            transactionType: viewModel.transactionType,
            amount: viewModel.amount,
            note: viewModel.note,
            account: viewModel.selectedAccount,
            subcategory: viewModel.selectedSubcategory,
            tags: viewModel.selectedTags,
            natureOverride: viewModel.selectedNature,
            currencyCode: viewModel.effectiveCurrencyCode,
            transactionDate: viewModel.transactionDate,
            onSaved: { message in
                showToast(message)
            }
        )
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
                                .accessibilityLabel("Eliminar etiqueta")
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

    private var dateChipText: String {
        if Calendar.current.isDateInToday(viewModel.transactionDate) {
            return L10n.Date.today
        } else if Calendar.current.isDateInYesterday(viewModel.transactionDate) {
            return L10n.Date.yesterday
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            formatter.locale = Locale.current
            return formatter.string(from: viewModel.transactionDate)
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
            get: { !autocompleteSuggestions.isEmpty },
            set: { if !$0 { currentMentionState = nil } }
        )
    }

    /// Content for the autocomplete popover - clean list style (max 5 items)
    private var autocompletePopoverContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
        .padding(.vertical, DS.Spacing.sm)
        .frame(width: 220)
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
        Button {
            saveTransaction()
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
        .tint(viewModel.canSave ? theme.accent : DS.Semantic.disabledForeground.opacity(0.4))
        .controlSize(.large)
        .disabled(!viewModel.canSave || viewModel.isSaving)
        .accessibilityHint(!viewModel.canSave ? "Para guardar, completa monto, cuenta y categoría" : "")
        .dsAnimation(.easeInOut(duration: 0.2), value: viewModel.canSave, reduceMotion: reduceMotion)
    }

    // MARK: - Actions

    /// Dismisses keyboard by clearing focus states
    private func dismissKeyboard() {
        isNoteFieldFocused = false
        isAmountFieldFocused = false
    }

    private func saveTransaction() {
        if viewModel.save(context: modelContext) != nil {
            DS.Haptic.success()
            // Dismiss keyboard first
            dismissKeyboard()

            // Build success data from saved transaction
            let account = viewModel.isTransfer ? viewModel.sourceAccount : viewModel.selectedAccount
            let destAccount = viewModel.destinationAccount

            successData = TransactionSuccessData(
                transactionType: viewModel.transactionType,
                date: viewModel.transactionDate,
                accountName: account?.name ?? L10n.Transaction.account,
                accountColorHex: account?.colorHex ?? "6366F1",
                note: viewModel.note,
                amount: Decimal(string: viewModel.amountString.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")) ?? 0,
                currencyCode: viewModel.effectiveCurrencyCode,
                subcategoryName: viewModel.selectedSubcategory?.name,
                subcategoryColorHex: viewModel.selectedSubcategory?.colorHex,
                categoryName: viewModel.selectedSubcategory?.safeCategory.name,
                categoryColorHex: viewModel.selectedSubcategory?.safeCategory.colorHex,
                tags: viewModel.selectedTags.map { ($0.name, $0.colorHex) },
                nature: viewModel.selectedNature ?? viewModel.selectedSubcategory?.nature,
                isTransfer: viewModel.isTransfer,
                destinationAccountName: destAccount?.name,
                destinationAccountColorHex: destAccount?.colorHex,
                destinationAmount: Decimal(viewModel.destinationAmount),
                destinationCurrencyCode: destAccount?.currencyCode
            )

            // Delay animation to let keyboard dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                dsWithAnimation(reduceMotion) {
                    showSuccessScreen = true
                }
            }
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
            viewModel.amountString = String(format: "%.2f", abs(tx.amount))

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

            // Load tags
            viewModel.selectedTags = tx.tags ?? []

            // Load note
            viewModel.note = tx.note ?? ""

            // If this is a transfer, load the paired transaction
            if tx.balanceAdjustmentType == "transfer", let pairID = tx.transferPairID {
                let fetchPairID = pairID
                let descriptor = FetchDescriptor<TransactionItem>(
                    predicate: #Predicate { $0.transferPairID == fetchPairID }
                )
                if let pairs = try? modelContext.fetch(descriptor) {
                    let pair = pairs.first { $0.persistentModelID != tx.persistentModelID }
                    if let pair {
                        viewModel.transactionType = .transfer
                        // Determine which is out (negative) and which is in (positive)
                        let outTx = tx.amount < 0 ? tx : pair
                        let inTx = tx.amount < 0 ? pair : tx
                        viewModel.sourceAccount = outTx.account
                        viewModel.destinationAccount = inTx.account
                        viewModel.editingTransferPair = (out: outTx, in: inTx)
                        // Use absolute amount from the outflow side
                        viewModel.amountString = String(format: "%.2f", abs(outTx.amount))
                    }
                }
            }

            // Load exchange rate (for display chip when currency differs from preferred)
            // For non-transfers: shows rate from transaction currency to preferred currency
            if tx.currencyCode != preferredCurrencyCode {
                if tx.exchangeRate != 1.0 {
                    // Use stored rate
                    viewModel.exchangeRate = tx.exchangeRate
                } else {
                    // Stored rate is 1.0 but currencies differ - load from CurrencyConverter
                    if let rate = CurrencyConverter.shared.getDisplayRate(
                        from: tx.currencyCode,
                        to: preferredCurrencyCode,
                        date: tx.date,
                        context: modelContext
                    ) {
                        viewModel.exchangeRate = rate
                    } else {
                        // Fallback: use static rates from CurrencyCode enum
                        if let fromCurrency = CurrencyCode(rawValue: tx.currencyCode),
                           let toCurrency = CurrencyCode(rawValue: preferredCurrencyCode) {
                            let fromRate = fromCurrency.fallbackRateToUSD
                            let toRate = toCurrency.fallbackRateToUSD
                            if fromRate > 0 {
                                viewModel.exchangeRate = toRate / fromRate
                            }
                        }
                    }
                }
            }

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

        // Animate form out
        dsWithAnimation(reduceMotion) {
            duplicateAnimationVisible = false
        }

        // After animation out, update state and animate back in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Keep all current form data but clear the editing reference
            // This turns the form into "create new" mode with prefilled data
            viewModel.editingTransaction = nil
            viewModel.editingTransferPair = nil

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
            if transaction.balanceAdjustmentType == "transfer", let pairID = transaction.transferPairID {
                let fetchPairID = pairID
                let descriptor = FetchDescriptor<TransactionItem>(
                    predicate: #Predicate { $0.transferPairID == fetchPairID }
                )
                if let pairs = try? modelContext.fetch(descriptor) {
                    for pair in pairs where pair.persistentModelID != transaction.persistentModelID {
                        modelContext.delete(pair)
                    }
                }
            }

            modelContext.delete(transaction)
            try modelContext.save()
            WidgetDataCache.updateCache(context: modelContext)
            SessionState.shared.incrementDataVersion()
            dismiss()
        } catch {
            #if DEBUG
            print("Error deleting transaction: \(error)")
            #endif
        }
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
            viewModel.amountString = String(format: "%.2f", amount)
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
        if let natureRaw = favorite.natureOverride {
            viewModel.selectedNature = SubcategoryNature(rawValue: natureRaw)
        } else {
            viewModel.selectedNature = favorite.subcategory?.nature
        }

        // Set tags
        viewModel.selectedTags = favorite.tags ?? []

        // Set note if available
        if let note = favorite.note, !note.isEmpty {
            viewModel.note = note
        }
    }
}

#Preview {
    NewTransactionView()
}
