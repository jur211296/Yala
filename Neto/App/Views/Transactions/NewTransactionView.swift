//
//  NewTransactionView.swift
//  Neto
//
//  Created by Neto - New Transaction Form.
//

import SwiftData
import SwiftUI

// MARK: - New Transaction View

/// Vista minimalista para registrar una nueva transacción
struct NewTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    @Query(sort: \Category.sortOrder, order: .forward) private var categories: [Category]
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]
    @Query(filter: #Predicate<Subcategory> { $0.isVisible }) private var subcategories:
        [Subcategory]
    @Query(sort: \TransactionItem.date, order: .reverse) private var transactions: [TransactionItem]

    @State private var viewModel = NewTransactionViewModel()
    @FocusState private var isNoteFieldFocused: Bool
    @FocusState private var isAmountFieldFocused: Bool

    // Autocomplete mention state
    @State private var currentMentionState: MentionState?

    // Success screen state
    @State private var showSuccessScreen = false
    @State private var successData: TransactionSuccessData?

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
                    viewModel = NewTransactionViewModel()
                    showSuccessScreen = false
                    successData = nil
                },
                onEdit: {
                    // Go back to form with current data
                    showSuccessScreen = false
                    successData = nil
                }
            )
        } else {
            transactionFormView
        }
    }

    private var transactionFormView: some View {
        NavigationStack {
            ZStack {
                Color.netoBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Transaction type selector
                    transactionTypeSelector
                        .padding(.top, 8)

                    Spacer()

                    // Central content area
                    centralContent

                    Spacer()

                    // Bottom selection chips
                    bottomChips
                        .padding(.bottom, 16)

                    // Exchange rate section removed - integrated into centralContent

                    // Register button
                    registerButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle(
                transactionToEdit != nil
                    ? L10n.Transaction.editTransaction : L10n.Transaction.newTransaction
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showFavoritesSheet = true
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(UIColor.label))
                    }
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
        }
        .tint(Color.electricIndigo)
        .onAppear {
            prefillFromContext()
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
            onTypeChange: { type in
                viewModel.selectedSubcategory = nil
                if type == .transfer {
                    viewModel.prepareForTransfer(allAccounts: accounts)
                    Task {
                        await viewModel.loadExchangeRate(context: modelContext)
                    }
                }
            }
        )
    }

    // MARK: - Central Content

    private var centralContent: some View {
        VStack(spacing: 24) {
            // Date chip - above description
            Button {
                viewModel.showDatePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .medium))
                    Text(dateChipText)
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(UIColor.label).opacity(0.08))
                )
            }
            .buttonStyle(.plain)

            // Note field with mention detection and popover autocomplete
            TextField(L10n.Transaction.description, text: $viewModel.note)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .textContentType(.none)
                .autocorrectionDisabled(false)
                .focused($isNoteFieldFocused)
                .frame(maxWidth: 280)
                .tint(Color(UIColor.label))
                .onChange(of: viewModel.note) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.15)) {
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

            // Amount display (Standard or Transfer)
            if viewModel.needsExchangeRate {
                transferAmountDisplay
            } else {
                amountDisplay
            }

            // Nature chip (visible when subcategory is selected, not for transfers)
            if !viewModel.isTransfer, viewModel.selectedSubcategory != nil {
                NatureEditChip(
                    nature: viewModel.selectedNature ?? viewModel.selectedSubcategory?.nature
                        ?? .unclassified
                ) {
                    viewModel.showNatureSelector = true
                }
                .padding(.top, 8)
            }
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

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(currencySymbol)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(viewModel.amountColor.opacity(0.7))

            TextField("0.00", text: $viewModel.amountString)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(viewModel.amountColor)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isAmountFieldFocused)
                .frame(width: 250)  // Increased width for decimals
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
                        } else if let amount = Double(viewModel.amountString) {
                            // Helper to format consistent decimals
                            viewModel.amountString = String(format: "%.2f", amount)
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
    }

    /// Filters amount input to only allow numbers and one decimal with max 2 decimal places
    private func filterAmountInput(_ input: String) -> String {
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        var result = ""
        var hasDecimal = false
        var decimalCount = 0

        for char in input {
            if char.isNumber {
                if hasDecimal {
                    if decimalCount < 2 {
                        result.append(char)
                        decimalCount += 1
                    }
                } else {
                    result.append(char)
                }
            } else if String(char) == decimalSeparator || char == "." || char == "," {
                if !hasDecimal {
                    result.append(decimalSeparator.first ?? ".")
                    hasDecimal = true
                }
            }
        }

        // Remove ALL leading zeros except for "0.x" pattern
        // First, strip all leading zeros
        while result.hasPrefix("0") && result.count > 1 {
            let secondChar = result[result.index(after: result.startIndex)]
            // Keep if it's "0." pattern
            if String(secondChar) == decimalSeparator {
                break
            }
            result = String(result.dropFirst())
        }

        // Allow empty string (will be restored to "0" when field loses focus)
        return result
    }

    /// Currency code for display (PEN, USD, EUR, etc.)
    private var currencySymbol: String {
        viewModel.effectiveCurrencyCode
    }

    // MARK: - Bottom Chips

    private var bottomChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Account chip (or source/dest for transfers)
                if viewModel.isTransfer {
                    // Source account chip - pink
                    SelectionChip(
                        icon: "arrow.up.circle",
                        text: viewModel.sourceAccount?.name ?? L10n.Transaction.origin,
                        isSelected: viewModel.sourceAccount != nil,
                        color: viewModel.sourceAccount != nil ? Color.hotPink : nil
                    ) {
                        viewModel.showSourceAccountSelector = true
                    }

                    // Destination account chip - purple
                    SelectionChip(
                        icon: "arrow.down.circle",
                        text: viewModel.destinationAccount?.name ?? L10n.Transaction.destination,
                        isSelected: viewModel.destinationAccount != nil,
                        color: viewModel.destinationAccount != nil ? Color.electricIndigo : nil
                    ) {
                        viewModel.showDestinationAccountSelector = true
                    }
                } else {
                    SelectionChip(
                        icon: "creditcard",
                        text: viewModel.selectedAccount?.name ?? L10n.Transaction.account,
                        isSelected: viewModel.selectedAccount != nil,
                        color: viewModel.selectedAccount != nil
                            ? Color(hex: viewModel.selectedAccount!.colorHex) : nil
                    ) {
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
                            viewModel.showTagSelector = true
                        }
                    } else {
                        // Individual chip for each selected tag
                        ForEach(viewModel.selectedTags, id: \.persistentModelID) { tag in
                            SelectionChip(
                                icon: "number",
                                text: tag.name,
                                isSelected: true,
                                color: Color.tagChipColor
                            ) {
                                viewModel.showTagSelector = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
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
            formatter.locale = Locale(identifier: "es")
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
        let colorHex = subcategory.colorHex ?? subcategory.category.colorHex
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
                allTags: tags,
                recentTransactions: transactions
            )
        case .subcategory:
            return AutocompleteHelper.getSubcategorySuggestions(
                query: mentionState.query,
                allSubcategories: subcategories,
                recentTransactions: transactions,
                transactionType: viewModel.transactionType
            )
        case .account:
            return AutocompleteHelper.getAccountSuggestions(
                query: mentionState.query,
                allAccounts: accounts,
                recentTransactions: transactions
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
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(autocompleteSuggestions.prefix(5))) { suggestion in
                Button {
                    handleAutocompleteSuggestion(suggestion)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: suggestion.colorHex))
                            .frame(width: 10, height: 10)

                        Text(suggestion.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 220)
        .background(Color.netoCard)
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
                        .font(.system(size: 20, weight: .semibold))
                    Text(L10n.Action.save)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(viewModel.canSave ? Color.electricIndigo : Color.gray.opacity(0.4))
        .controlSize(.large)
        .disabled(!viewModel.canSave || viewModel.isSaving)
        .animation(.easeInOut(duration: 0.2), value: viewModel.canSave)
    }

    // MARK: - Actions

    private func saveTransaction() {
        if viewModel.save(context: modelContext) != nil {
            // Build success data from saved transaction
            let account = viewModel.isTransfer ? viewModel.sourceAccount : viewModel.selectedAccount
            let destAccount = viewModel.destinationAccount

            successData = TransactionSuccessData(
                transactionType: viewModel.transactionType,
                date: viewModel.transactionDate,
                accountName: account?.name ?? L10n.Transaction.account,
                accountColorHex: account?.colorHex ?? "6366F1",
                note: viewModel.note,
                amount: Decimal(viewModel.amount),
                currencyCode: viewModel.effectiveCurrencyCode,
                subcategoryName: viewModel.selectedSubcategory?.name,
                subcategoryColorHex: viewModel.selectedSubcategory?.colorHex,
                categoryName: viewModel.selectedSubcategory?.category.name,
                categoryColorHex: viewModel.selectedSubcategory?.category.colorHex,
                tags: viewModel.selectedTags.map { ($0.name, $0.colorHex) },
                nature: viewModel.selectedNature ?? viewModel.selectedSubcategory?.nature,
                isTransfer: viewModel.isTransfer,
                destinationAccountName: destAccount?.name,
                destinationAccountColorHex: destAccount?.colorHex,
                destinationAmount: Decimal(viewModel.destinationAmount),
                destinationCurrencyCode: destAccount?.currencyCode
            )
            showSuccessScreen = true
        }
    }

    private func prefillFromContext() {
        let allSubcategories = categories.flatMap { $0.subcategories }

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
            if tx.subcategory?.category.isIncome == true || tx.amount > 0 {
                viewModel.transactionType = .income
            } else {
                viewModel.transactionType = .expense
            }

            // Load date
            viewModel.transactionDate = tx.date

            // Load tags
            viewModel.selectedTags = tx.tags

            // Load note
            viewModel.note = tx.note ?? ""

            return
        }

        // If no prefill account, use account from last transaction
        var accountToUse = prefillAccountID
        if accountToUse == nil, let lastTransaction = transactions.first {
            accountToUse = lastTransaction.account?.persistentModelID
        }

        viewModel.prefill(
            accountID: accountToUse,
            categoryID: prefillCategoryID,
            subcategoryName: prefillSubcategoryName,
            accounts: accounts,
            subcategories: allSubcategories
        )
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
        viewModel.selectedTags = favorite.tags

        // Set note if available
        if let note = favorite.note, !note.isEmpty {
            viewModel.note = note
        }
    }
}

#Preview {
    NewTransactionView()
}
