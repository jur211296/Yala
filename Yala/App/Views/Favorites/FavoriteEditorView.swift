//
//  FavoriteEditorView.swift
//  Yala
//
//  Editor for favorite payment templates.
//  Based on NewTransactionView but without date. Un favorito de TRANSFERENCIA se edita como tal (card 93ta): origen y
//  destino, sin categoría ni etiquetas y sin convertirlo en gasto o ingreso. Uno nuevo desde aquí sigue siendo gasto o
//  ingreso: los de transferencia nacen en el formulario de registro.
//

import SwiftData
import SwiftUI

// MARK: - Favorite Editor View

struct FavoriteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    @State private var viewModel = FavoriteEditorViewModel()

    // Editing mode
    let favorite: FavoritePayment?

    // Form state
    @State private var name: String = ""
    @State private var transactionType: TransactionType = .expense
    @State private var amountString: String = ""
    @State private var note: String = ""
    @State private var selectedAccount: Account?
    @State private var selectedDestinationAccount: Account?
    @State private var selectedSubcategory: Subcategory?
    @State private var selectedTags: [Tag] = []
    @State private var selectedNeed: SubcategoryNeed?

    // Initial values for change detection (edit mode)
    @State private var initialName: String = ""
    @State private var initialTransactionType: TransactionType = .expense
    @State private var initialAmountString: String = ""
    @State private var initialNote: String = ""
    @State private var initialAccountID: PersistentIdentifier?
    @State private var initialDestinationAccountID: PersistentIdentifier?
    @State private var initialSubcategoryID: PersistentIdentifier?
    @State private var initialTagIDs: Set<PersistentIdentifier> = []
    @State private var initialNeed: SubcategoryNeed?

    // Sheet states
    @State private var showAccountSelector = false
    @State private var showDestinationAccountSelector = false
    @State private var showSubcategorySelector = false
    @State private var showTagSelector = false
    @State private var showNeedSelector = false
    @State private var showDeleteConfirmation = false

    @ScaledMetric(relativeTo: .largeTitle) private var scaledAmountSize: CGFloat = 64 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .largeTitle) private var heroAmountSize: CGFloat = 64
    @ScaledMetric(relativeTo: .title) private var currencySymbolSize: CGFloat = 28

    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isAmountFieldFocused: Bool

    init(favorite: FavoritePayment? = nil) {
        self.favorite = favorite
        _isTransfer = State(initialValue: Self.isTransferFavorite(favorite))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.none) {
                // Transaction type selector (without transfer)
                transactionTypeSelector
                    .padding(.top, DS.Spacing.sm)

                Spacer()

                // Central content
                centralContent

                Spacer()

                // Bottom selection chips
                bottomChips
                    .padding(.bottom, favorite == nil ? DS.Spacing.lg : DS.Spacing.sm)

                // «Eliminar favorito» al fondo del editor, donde se busca (L7-14): antes solo se borraba
                // deslizando la fila o desde «Editar».
                if favorite != nil {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text(L10n.UXL7.Favorites.delete)
                            .font(DS.Typography.bodyBold)
                            .foregroundStyle(DS.Semantic.errorForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, DS.Spacing.lg)
                    .accessibilityIdentifier("favorite_editor_delete")
                }
            }
            .dismissKeyboardOnTap()
            .yalaScreenBackground(.subtle)
            .navigationTitle(favorite != nil ? L10n.Favorites.editTitle : L10n.Favorites.newTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(
                        action: { saveFavorite() },
                        isDisabled: !canSave
                    )
                }
            }
            .sheet(isPresented: $showAccountSelector) {
                AccountSelectorSheet(
                    selectedAccount: $selectedAccount,
                    title: isTransfer ? L10n.Transaction.sourceAccount : L10n.Transaction.account,
                    excludeAccount: isTransfer ? selectedDestinationAccount : nil
                )
            }
            .sheet(isPresented: $showDestinationAccountSelector) {
                AccountSelectorSheet(
                    selectedAccount: $selectedDestinationAccount,
                    title: L10n.Transaction.destinationAccount,
                    excludeAccount: selectedAccount
                )
            }
            .sheet(isPresented: $showSubcategorySelector) {
                SubcategorySelectorSheet(
                    selectedSubcategory: $selectedSubcategory,
                    transactionType: transactionType
                )
            }
            .sheet(isPresented: $showTagSelector) {
                TagSelectorSheet(selectedTags: $selectedTags)
            }
            .sheet(isPresented: $showNeedSelector) {
                NeedSelectorSheet(
                    selectedNeed: Binding(
                        get: { selectedNeed ?? selectedSubcategory?.need ?? .unclassified },
                        set: { selectedNeed = $0 }
                    )
                )
                .yalaSheetDetents([.medium])
            }
            .onChange(of: showAccountSelector) { _, isPresenting in
                if isPresenting {
                    isNameFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .onChange(of: showDestinationAccountSelector) { _, isPresenting in
                if isPresenting {
                    isNameFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .onChange(of: showSubcategorySelector) { _, isPresenting in
                if isPresenting {
                    isNameFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .onChange(of: showTagSelector) { _, isPresenting in
                if isPresenting {
                    isNameFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .onChange(of: showNeedSelector) { _, isPresenting in
                if isPresenting {
                    isNameFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
            .alert(
                L10n.Common.error,
                isPresented: Binding(
                    get: { viewModel.showSaveError },
                    set: { _ in viewModel.dismissSaveError() }
                ),
                actions: {
                    Button(L10n.Common.understood, role: .cancel) {}
                },
                message: {
                    Text(L10n.Common.saveError)
                }
            )
        }

        .alert(L10n.UXL7.Favorites.deleteConfirmTitle, isPresented: $showDeleteConfirmation) {
            Button(L10n.Action.delete, role: .destructive) {
                guard let favorite else { return }
                if viewModel.deleteFavorite(favorite) {
                    dismiss()
                }
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.UXL7.Favorites.deleteConfirmMessage)
        }
        .onAppear {
            viewModel.setContext(modelContext)
            loadFavoriteData()
            // Auto-focus name field for new favorites
            if favorite == nil {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    isNameFieldFocused = true
                }
            }
        }
        .onChange(of: selectedSubcategory) { _, newSubcategory in
            if let subcategory = newSubcategory {
                selectedNeed = subcategory.need
            } else {
                selectedNeed = nil
            }
        }
    }

    // MARK: - Transaction Type Selector (No Transfer)

    private var availableTransactionTypes: [TransactionType] {
        sessionState.isExpensesOnlyMode ? [.expense] : [.expense, .income]
    }

    /// El favorito que se edita es una transferencia (card 93ta). Se lee del FAVORITO y no del estado: un favorito de
    /// transferencia no se convierte en gasto o ingreso desde aquí. Copiado al crear la vista: «Eliminar» borra el
    /// favorito y el editor sigue presentado mientras se cierra, y en iOS 27.x leer un modelo borrado aborta (card 1w89).
    @State private var isTransfer: Bool

    /// Mira antes de leer: si quien presenta el editor lo vuelve a crear con el favorito ya borrado, el valor se ignora
    /// (manda el `@State` de la primera vez), pero la lectura correría igual.
    private static func isTransferFavorite(_ favorite: FavoritePayment?) -> Bool {
        guard let favorite, !favorite.isDeleted, favorite.modelContext != nil else { return false }
        return favorite.type == .transfer
    }

    @ViewBuilder
    private var transactionTypeSelector: some View {
        // Una transferencia no se cambia de tipo: sin selector, como el formulario cuando solo cabe un tipo
        // (`TransactionTypeSelectorView` también se esconde con uno).
        if !isTransfer { expenseIncomeSelector }
    }

    private var expenseIncomeSelector: some View {
        HStack(spacing: DS.Spacing.none) {
            ForEach(availableTransactionTypes, id: \.self) { type in
                Button {
                    dsWithAnimation(reduceMotion) {
                        transactionType = type
                        selectedSubcategory = nil
                    }
                } label: {
                    Text(type == .expense ? L10n.Transaction.expense : L10n.Transaction.income)
                        .font(DS.Typography.headline)
                        .foregroundStyle(transactionType == type ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Chip.paddingH)
                        .background {
                            if transactionType == type {
                                Capsule()
                                    .fill(type == .expense ? Color.hotPink : Color.electricIndigo)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.xs)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.08))
        )
        .padding(.horizontal, DS.Spacing.xxxxl + DS.Spacing.md)
    }

    // MARK: - Central Content

    private var centralContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            // Name field
            TextField(L10n.Favorites.namePlaceholder, text: $name)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("favorite_name_field")
                .focused($isNameFieldFocused)
                .padding(.horizontal, DS.Spacing.xxxxl)
                .tint(Color.primary)

            // Description field
            TextField(L10n.Favorites.descriptionPlaceholder, text: $note)
                .font(DS.Typography.title)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .tint(Color.primary)

            // Amount display
            amountDisplay

            // Nature chip (visible when subcategory is selected)
            if selectedSubcategory != nil, transactionType != .income, !isTransfer {
                NeedEditChip(
                    need: selectedNeed ?? selectedSubcategory?.need ?? .unclassified
                ) {
                    showNeedSelector = true
                }
                .padding(.top, DS.Spacing.sm)
            }
        }
    }

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
            Text(currencySymbol)
                .font(.system(size: currencySymbolSize, weight: .medium, design: .rounded))
                .foregroundStyle(amountColor.opacity(0.7))

            TextField("0.00", text: $amountString)
                .font(.system(size: heroAmountSize, weight: .bold, design: .rounded))
                .foregroundStyle(amountColor)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isAmountFieldFocused)
                .frame(width: 250)
                .onChange(of: isAmountFieldFocused) { _, isFocused in
                    if isFocused && (amountString == "0" || amountString == "0.00" || amountString == "0,00") {
                        amountString = ""
                    }
                    if !isFocused {
                        if !amountString.isEmpty {
                            let amount = AmountInputHelper.parseDecimal(amountString)
                            amountString = AmountInputHelper.formatWithGrouping(amount)
                        }
                    }
                }
                .onChange(of: amountString) { _, newValue in
                    let filtered = filterAmountInput(newValue)
                    if filtered != newValue {
                        amountString = filtered
                    }
                }
        }
    }

    private var currencySymbol: String {
        let code = selectedAccount?.currencyCode ?? CurrencyDefaults.defaultCode
        return appPreferences.currencyIdentifier(for: code)
    }

    private var amountColor: Color {
        // Una transferencia, con el color de su tipo, como en el formulario de registro.
        isTransfer ? TransactionType.transfer.color : Color.amountTint(isIncome: transactionType == .income)
    }

    // MARK: - Bottom Chips

    private var bottomChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) { // DS: intentional non-token value
                if isTransfer {
                    transferChips
                } else {
                    expenseIncomeChips
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
        .fadesTowardVerticalBar()
    }

    /// Origen y destino, con los mismos colores e iconos que el formulario de registro (`NewTransactionView`). Sin
    /// categoría ni etiquetas: una transferencia no las lleva.
    @ViewBuilder
    private var transferChips: some View {
        SelectionChip(
            icon: "arrow.up.circle",
            text: selectedAccount?.name ?? L10n.Transaction.origin,
            isSelected: selectedAccount != nil,
            color: selectedAccount != nil ? Color.hotPink : nil,
            fillsWhenSelected: true
        ) {
            showAccountSelector = true
        }
        .accessibilityIdentifier("favorite_editor_source_chip")

        SelectionChip(
            icon: "arrow.down.circle",
            text: selectedDestinationAccount?.name ?? L10n.Transaction.destination,
            isSelected: selectedDestinationAccount != nil,
            color: selectedDestinationAccount != nil ? Color.electricIndigo : nil,
            fillsWhenSelected: true
        ) {
            showDestinationAccountSelector = true
        }
        .accessibilityIdentifier("favorite_editor_destination_chip")
    }

    @ViewBuilder
    private var expenseIncomeChips: some View {
        // Account chip
        SelectionChip(
            icon: "creditcard",
            text: selectedAccount?.name ?? L10n.Transaction.account,
            isSelected: selectedAccount != nil,
            color: selectedAccount.map { Color(hex: $0.colorHex) }
        ) {
            showAccountSelector = true
        }

        // Subcategory chip
        SelectionChip(
            icon: "tag",
            text: selectedSubcategory?.name ?? L10n.Transaction.subcategory,
            isSelected: selectedSubcategory != nil,
            color: subcategoryChipColor
        ) {
            showSubcategorySelector = true
        }
        .accessibilityIdentifier("favorite_editor_subcategory_chip")

        // Tags chips
        if selectedTags.isEmpty {
            SelectionChip(
                icon: "number",
                text: L10n.Transaction.tags,
                isSelected: false,
                color: nil
            ) {
                showTagSelector = true
            }
        } else {
            ForEach(selectedTags, id: \.persistentModelID) { tag in
                SelectionChip(
                    icon: "number",
                    text: tag.name,
                    isSelected: true,
                    color: theme.tagChip
                ) {
                    showTagSelector = true
                }
            }
        }
    }

    private var subcategoryChipColor: Color? {
        guard let subcategory = selectedSubcategory else { return nil }
        let colorHex = subcategory.colorHex ?? subcategory.safeCategory.colorHex
        return Color(hex: colorHex)
    }

    // MARK: - Validation

    private var canSave: Bool {
        let nameValid = !name.trimmingCharacters(in: .whitespaces).isEmpty
            && FavoriteEditorTransferLogic.accountsAreValid(
                isTransfer: isTransfer, origin: selectedAccount?.persistentModelID,
                destination: selectedDestinationAccount?.persistentModelID)

        // For new favorites, just need a name
        guard favorite != nil else { return nameValid }

        // For editing, require name + changes
        return nameValid && hasChanges
    }

    private var hasChanges: Bool {
        name != initialName || transactionType != initialTransactionType
            || amountString != initialAmountString || note != initialNote
            || selectedAccount?.persistentModelID != initialAccountID
            || selectedDestinationAccount?.persistentModelID != initialDestinationAccountID
            || selectedSubcategory?.persistentModelID != initialSubcategoryID
            || Set(selectedTags.map { $0.persistentModelID }) != initialTagIDs
            || selectedNeed != initialNeed
    }

    // MARK: - Actions

    private func loadFavoriteData() {
        guard let favorite = favorite else { return }

        name = favorite.name
        transactionType = favorite.type
        if let amount = favorite.amount {
            amountString = AmountInputHelper.formatWithGrouping(amount)
        }
        note = favorite.note ?? ""
        selectedAccount = favorite.account
        selectedDestinationAccount = favorite.destinationAccount
        selectedSubcategory = favorite.subcategory
        // CSV-mirror SSOT via resolver + TagResolver.
        selectedTags = TagResolver.fetchOrEmpty(
            ids: favorite.resolvedTagIDs(scheduleBackfill: true) ?? [],
            in: modelContext,
            errorContext: "FavoriteEditorView/load"
        )
        if let needRaw = favorite.needOverride {
            selectedNeed = SubcategoryNeed(rawValue: needRaw)
        }

        // Store initial values for change detection
        initialName = name
        initialTransactionType = transactionType
        initialAmountString = amountString
        initialNote = note
        initialAccountID = selectedAccount?.persistentModelID
        initialDestinationAccountID = selectedDestinationAccount?.persistentModelID
        initialSubcategoryID = selectedSubcategory?.persistentModelID
        initialTagIDs = Set(selectedTags.map { $0.persistentModelID })
        initialNeed = selectedNeed
    }

    private func saveFavorite() {
        let saved = viewModel.saveFavorite(
            existing: favorite,
            name: name,
            transactionType: transactionType,
            amountString: amountString,
            note: note,
            account: selectedAccount,
            subcategory: selectedSubcategory,
            tags: selectedTags,
            needOverride: selectedNeed,
            destinationAccount: isTransfer ? selectedDestinationAccount : nil
        )
        if saved {
            dismiss()
        }
    }

    // MARK: - Helpers

    private func filterAmountInput(_ input: String) -> String {
        AmountInputHelper.filterAmountInput(input)
    }
}

#Preview {
    FavoriteEditorView()
}
