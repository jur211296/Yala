//
//  FavoriteEditorView.swift
//  Neto
//
//  Editor for favorite payment templates.
//  Based on NewTransactionView but without date and transfer options.
//

import SwiftData
import SwiftUI

// MARK: - Favorite Editor View

struct FavoriteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]
    @Query(filter: #Predicate<Subcategory> { $0.isVisible }) private var subcategories:
        [Subcategory]
    @Query(sort: \FavoritePayment.displayOrder, order: .forward) private var existingFavorites:
        [FavoritePayment]

    // Editing mode
    let favorite: FavoritePayment?

    // Form state
    @State private var name: String = ""
    @State private var transactionType: TransactionType = .expense
    @State private var amountString: String = ""
    @State private var note: String = ""
    @State private var selectedAccount: Account?
    @State private var selectedSubcategory: Subcategory?
    @State private var selectedTags: [Tag] = []
    @State private var selectedNature: SubcategoryNature?

    // Initial values for change detection (edit mode)
    @State private var initialName: String = ""
    @State private var initialTransactionType: TransactionType = .expense
    @State private var initialAmountString: String = ""
    @State private var initialNote: String = ""
    @State private var initialAccountID: PersistentIdentifier?
    @State private var initialSubcategoryID: PersistentIdentifier?
    @State private var initialTagIDs: Set<PersistentIdentifier> = []
    @State private var initialNature: SubcategoryNature?

    // Sheet states
    @State private var showAccountSelector = false
    @State private var showSubcategorySelector = false
    @State private var showTagSelector = false
    @State private var showNatureSelector = false

    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isAmountFieldFocused: Bool

    init(favorite: FavoritePayment? = nil) {
        self.favorite = favorite
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.netoBackground
                    .ignoresSafeArea()
                    .dismissKeyboardOnTap()

                VStack(spacing: 0) {
                    // Transaction type selector (without transfer)
                    transactionTypeSelector
                        .padding(.top, 8)

                    Spacer()

                    // Central content
                    centralContent

                    Spacer()

                    // Bottom selection chips
                    bottomChips
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle(favorite != nil ? L10n.Favorites.editTitle : L10n.Favorites.newTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NetoSaveButton(
                        action: { saveFavorite() },
                        isDisabled: !canSave
                    )
                }
            }
            .sheet(isPresented: $showAccountSelector) {
                AccountSelectorSheet(
                    selectedAccount: $selectedAccount,
                    title: L10n.Transaction.account
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
            .sheet(isPresented: $showNatureSelector) {
                NatureSelectorSheet(
                    selectedNature: Binding(
                        get: { selectedNature ?? selectedSubcategory?.nature ?? .unclassified },
                        set: { selectedNature = $0 }
                    )
                )
                .presentationDetents([.medium])
            }
            .onChange(of: showAccountSelector) { _, isPresenting in
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
            .onChange(of: showNatureSelector) { _, isPresenting in
                if isPresenting {
                    isNameFieldFocused = false
                    isAmountFieldFocused = false
                }
            }
        }
        .tint(Color.electricIndigo)
        .onAppear {
            loadFavoriteData()
            // Auto-focus name field for new favorites
            if favorite == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNameFieldFocused = true
                }
            }
        }
        .onChange(of: selectedSubcategory) { _, newSubcategory in
            if let subcategory = newSubcategory {
                selectedNature = subcategory.nature
            } else {
                selectedNature = nil
            }
        }
    }

    // MARK: - Transaction Type Selector (No Transfer)

    private var transactionTypeSelector: some View {
        HStack(spacing: 0) {
            ForEach([TransactionType.expense, TransactionType.income], id: \.self) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        transactionType = type
                        selectedSubcategory = nil
                    }
                } label: {
                    Text(type == .expense ? L10n.Transaction.expense : L10n.Transaction.income)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(transactionType == type ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
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
                .fill(Color(UIColor.label).opacity(0.08))
        )
        .padding(.horizontal, 60)
    }

    // MARK: - Central Content

    private var centralContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            // Name field
            TextField(L10n.Favorites.namePlaceholder, text: $name)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .focused($isNameFieldFocused)
                .padding(.horizontal, 40)
                .tint(Color(UIColor.label))

            // Description field
            TextField(L10n.Favorites.descriptionPlaceholder, text: $note)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .tint(Color(UIColor.label))

            // Amount display
            amountDisplay

            // Nature chip (visible when subcategory is selected)
            if selectedSubcategory != nil {
                NatureEditChip(
                    nature: selectedNature ?? selectedSubcategory?.nature ?? .unclassified
                ) {
                    showNatureSelector = true
                }
                .padding(.top, 8)
            }
        }
    }

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(currencySymbol)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(amountColor.opacity(0.7))

            TextField("0.00", text: $amountString)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(amountColor)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isAmountFieldFocused)
                .frame(width: 250)
                .onChange(of: isAmountFieldFocused) { _, isFocused in
                    if isFocused && (amountString == "0" || amountString == "0.00") {
                        amountString = ""
                    }
                    if !isFocused {
                        if amountString.isEmpty {
                            amountString = ""
                        } else if let amount = Double(amountString) {
                            amountString = String(format: "%.2f", amount)
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
        selectedAccount?.currencyCode ?? CurrencyDefaults.defaultCode
    }

    private var amountColor: Color {
        transactionType == .income ? Color.electricIndigo : Color.hotPink
    }

    // MARK: - Bottom Chips

    private var bottomChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Account chip
                SelectionChip(
                    icon: "creditcard",
                    text: selectedAccount?.name ?? L10n.Transaction.account,
                    isSelected: selectedAccount != nil,
                    color: selectedAccount != nil ? Color(hex: selectedAccount!.colorHex) : nil
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
                            color: Color.tagChipColor
                        ) {
                            showTagSelector = true
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var subcategoryChipColor: Color? {
        guard let subcategory = selectedSubcategory else { return nil }
        let colorHex = subcategory.colorHex ?? subcategory.category.colorHex
        return Color(hex: colorHex)
    }

    // MARK: - Validation

    private var canSave: Bool {
        let nameValid = !name.trimmingCharacters(in: .whitespaces).isEmpty

        // For new favorites, just need a name
        guard favorite != nil else { return nameValid }

        // For editing, require name + changes
        return nameValid && hasChanges
    }

    private var hasChanges: Bool {
        name != initialName || transactionType != initialTransactionType
            || amountString != initialAmountString || note != initialNote
            || selectedAccount?.persistentModelID != initialAccountID
            || selectedSubcategory?.persistentModelID != initialSubcategoryID
            || Set(selectedTags.map { $0.persistentModelID }) != initialTagIDs
            || selectedNature != initialNature
    }

    // MARK: - Actions

    private func loadFavoriteData() {
        guard let favorite = favorite else { return }

        name = favorite.name
        transactionType = favorite.type
        if let amount = favorite.amount {
            amountString = String(format: "%.2f", amount)
        }
        note = favorite.note ?? ""
        selectedAccount = favorite.account
        selectedSubcategory = favorite.subcategory
        selectedTags = favorite.tags
        if let natureRaw = favorite.natureOverride {
            selectedNature = SubcategoryNature(rawValue: natureRaw)
        }

        // Store initial values for change detection
        initialName = name
        initialTransactionType = transactionType
        initialAmountString = amountString
        initialNote = note
        initialAccountID = selectedAccount?.persistentModelID
        initialSubcategoryID = selectedSubcategory?.persistentModelID
        initialTagIDs = Set(selectedTags.map { $0.persistentModelID })
        initialNature = selectedNature
    }

    private func saveFavorite() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let amount: Double? = amountString.isEmpty ? nil : Double(amountString)
        let natureOverride: String? =
            selectedNature != selectedSubcategory?.nature
            ? selectedNature?.rawValue
            : nil

        if let existing = favorite {
            // Update existing
            existing.name = trimmedName
            existing.transactionType = transactionType.rawValue
            existing.amount = amount
            existing.note = note.isEmpty ? nil : note
            existing.account = selectedAccount
            existing.subcategory = selectedSubcategory
            existing.tags = selectedTags
            existing.natureOverride = natureOverride
            existing.currencyCode = selectedAccount?.currencyCode
        } else {
            // Create new
            let newFavorite = FavoritePayment(
                name: trimmedName,
                transactionType: transactionType.rawValue,
                amount: amount,
                note: note.isEmpty ? nil : note,
                account: selectedAccount,
                subcategory: selectedSubcategory,
                tags: selectedTags,
                natureOverride: natureOverride,
                currencyCode: selectedAccount?.currencyCode,
                displayOrder: existingFavorites.count
            )
            modelContext.insert(newFavorite)
        }

        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helpers

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

        while result.hasPrefix("0") && result.count > 1 {
            let secondChar = result[result.index(after: result.startIndex)]
            if String(secondChar) == decimalSeparator {
                break
            }
            result = String(result.dropFirst())
        }

        return result
    }
}

#Preview {
    FavoriteEditorView()
}
