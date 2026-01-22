//
//  InboxDraftEditSheet.swift
//  Neto
//
//  Sheet para editar un draft de la bandeja de entrada.
//  Mismo diseño que NewTransactionView pero prefilled desde el draft.
//  Fase 8: Registro Inteligente - Subfase 8.2
//

import SwiftData
import SwiftUI

struct InboxDraftEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    @Query(sort: \Category.sortOrder, order: .forward) private var categories: [Category]
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]
    @Query(filter: #Predicate<Subcategory> { $0.isVisible }) private var subcategories: [Subcategory]

    @Bindable var draft: InboxDraft

    // MARK: - State

    @State private var note: String = ""
    @State private var amountString: String = ""
    @State private var transactionDate: Date = Date()
    @State private var selectedAccount: Account?
    @State private var selectedSubcategory: Subcategory?
    @State private var selectedTags: [Tag] = []

    // Sheet states
    @State private var showAccountSelector = false
    @State private var showSubcategorySelector = false
    @State private var showTagSelector = false
    @State private var showDatePicker = false

    // Focus state
    @FocusState private var isNoteFieldFocused: Bool
    @FocusState private var isAmountFieldFocused: Bool

    // Alert states
    @State private var showApproveError = false
    @State private var approveErrorMessage = ""

    // Callback for when draft is approved
    var onApproved: (() -> Void)?

    // MARK: - Computed

    private var amount: Double? {
        Double(amountString.replacingOccurrences(of: ",", with: "."))
    }

    private var isReadyToApprove: Bool {
        selectedAccount != nil && amount != nil && selectedSubcategory != nil
    }

    private var currencyCode: String {
        selectedAccount?.currencyCode ?? "PEN"
    }

    private var amountColor: Color {
        guard let amt = amount else { return .secondary }
        return amt >= 0 ? Color.electricIndigo : Color.hotPink
    }

    // MARK: - Body

    var body: some View {
        mainNavigationStack
            .tint(Color.electricIndigo)
            .onAppear {
                prefillFromDraft()
            }
    }

    private var mainNavigationStack: some View {
        NavigationStack {
            mainContent
                .navigationTitle(L10n.Inbox.editDraft)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(isPresented: $showAccountSelector) { accountSheet }
                .sheet(isPresented: $showSubcategorySelector) { subcategorySheet }
                .sheet(isPresented: $showTagSelector) { tagSheet }
                .sheet(isPresented: $showDatePicker) { dateSheet }
                .onChange(of: showAccountSelector) { _, isPresenting in
                    if isPresenting { dismissKeyboard() }
                }
                .onChange(of: showSubcategorySelector) { _, isPresenting in
                    if isPresenting { dismissKeyboard() }
                }
                .onChange(of: showTagSelector) { _, isPresenting in
                    if isPresenting { dismissKeyboard() }
                }
                .onChange(of: showDatePicker) { _, isPresenting in
                    if isPresenting { dismissKeyboard() }
                }
                .alert(L10n.Inbox.cannotApprove, isPresented: $showApproveError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(approveErrorMessage)
                }
        }
    }

    private var mainContent: some View {
        ZStack {
            Color.netoBackground
                .ignoresSafeArea()
                .dismissKeyboardOnTap()

            VStack(spacing: 0) {
                Spacer()
                centralContent
                Spacer()
                bottomChips
                    .padding(.bottom, DS.Spacing.lg)
                actionButtons
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xxl)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            NetoToolbarButton(systemName: "xmark") {
                dismiss()
            }
        }
    }

    private var accountSheet: some View {
        AccountSelectorSheet(
            selectedAccount: $selectedAccount,
            title: L10n.Transaction.account
        )
    }

    private var subcategorySheet: some View {
        let transactionType: TransactionType = (amount ?? 0) >= 0 ? .income : .expense
        return SubcategorySelectorSheet(
            selectedSubcategory: $selectedSubcategory,
            transactionType: transactionType
        )
    }

    private var tagSheet: some View {
        TagSelectorSheet(selectedTags: $selectedTags)
    }

    private var dateSheet: some View {
        DatePickerSheet(selectedDate: $transactionDate)
            .presentationDetents([.medium, .large])
    }

    // MARK: - Central Content

    private var centralContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            // Date chip
            Button {
                showDatePicker = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                    Text(dateChipText)
                        .font(.callout.weight(.medium))
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

            // Note field
            TextField(L10n.Transaction.description, text: $note)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .textContentType(.none)
                .autocorrectionDisabled(false)
                .focused($isNoteFieldFocused)
                .frame(maxWidth: 280)
                .tint(Color(UIColor.label))

            // Amount display
            amountDisplay

            // Source indicator
            sourceIndicator
        }
    }

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
            Text(currencyCode)
                .font(.system(size: amountFontSize * 0.44, weight: .medium, design: .rounded))
                .foregroundStyle(amountColor.opacity(0.7))

            TextField("0.00", text: $amountString)
                .font(.system(size: amountFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(amountColor)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isAmountFieldFocused)
                .fixedSize(horizontal: true, vertical: false)
                .onChange(of: isAmountFieldFocused) { _, isFocused in
                    if isFocused && (amountString == "0" || amountString == "0.00") {
                        amountString = ""
                    }
                    if !isFocused {
                        if amountString.isEmpty {
                            amountString = "0.00"
                        } else if let amt = Double(amountString.replacingOccurrences(of: ",", with: ".")) {
                            amountString = String(format: "%.2f", abs(amt))
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

    private var sourceIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: draft.sourceIcon)
                .font(.caption)
            Text(sourceTypeName)
                .font(.caption)
        }
        .foregroundStyle(.tertiary)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            Capsule()
                .fill(Color(UIColor.label).opacity(0.05))
        )
    }

    private var sourceTypeName: String {
        switch draft.sourceType {
        case .voice: return L10n.Inbox.sourceVoice
        case .receiptPhoto: return L10n.Inbox.sourceReceipt
        case .screenshotList: return L10n.Inbox.sourceScreenshotList
        case .screenshotSingle: return L10n.Inbox.sourceScreenshot
        case .emailAlert: return L10n.Inbox.sourceEmail
        }
    }

    // MARK: - Bottom Chips

    private var bottomChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                // Account chip
                SelectionChip(
                    icon: "creditcard",
                    text: selectedAccount?.name ?? L10n.Transaction.account,
                    isSelected: selectedAccount != nil,
                    color: selectedAccount != nil ? Color(hex: selectedAccount!.colorHex) : nil
                ) {
                    dismissKeyboard()
                    showAccountSelector = true
                }

                // Subcategory chip
                SelectionChip(
                    icon: "tag",
                    text: selectedSubcategory?.name ?? L10n.Transaction.subcategory,
                    isSelected: selectedSubcategory != nil,
                    color: subcategoryChipColor
                ) {
                    dismissKeyboard()
                    showSubcategorySelector = true
                }

                // Tags
                if selectedTags.isEmpty {
                    SelectionChip(
                        icon: "number",
                        text: L10n.Transaction.tags,
                        isSelected: false,
                        color: nil
                    ) {
                        dismissKeyboard()
                        showTagSelector = true
                    }
                } else {
                    ForEach(selectedTags, id: \.persistentModelID) { tag in
                        tagChip(for: tag)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    private func tagChip(for tag: Tag) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                dismissKeyboard()
                showTagSelector = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: tag.iconName)
                        .font(.system(size: 14, weight: .medium))
                    Text(tag.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Button {
                withAnimation {
                    selectedTags.removeAll { $0.persistentModelID == tag.persistentModelID }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.tagChipColor)
        .padding(.horizontal, DS.FormRow.paddingV)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            Capsule().fill(Color.tagChipColor.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(Color.tagChipColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var subcategoryChipColor: Color? {
        guard let subcategory = selectedSubcategory else { return nil }
        return Color(hex: subcategory.category.colorHex)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: DS.Spacing.md) {
            // Save button (secondary)
            Button {
                saveDraft()
                dismiss()
            } label: {
                Text(L10n.Action.save)
                    .font(.headline)
                    .foregroundStyle(Color.electricIndigo)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(Color.electricIndigo.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)

            // Approve button (primary)
            Button {
                approveDraft()
            } label: {
                Text(L10n.Inbox.approve)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(isReadyToApprove ? Color.electricIndigo : Color.gray)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isReadyToApprove)
        }
    }

    // MARK: - Helpers

    private var amountFontSize: CGFloat {
        let length = amountString.count
        switch length {
        case 0...7: return 64
        case 8...9: return 54
        case 10...11: return 46
        case 12...13: return 38
        default: return 32
        }
    }

    private var dateChipText: String {
        if Calendar.current.isDateInToday(transactionDate) {
            return L10n.Date.today
        } else if Calendar.current.isDateInYesterday(transactionDate) {
            return L10n.Date.yesterday
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = AppLocale.current
            return formatter.string(from: transactionDate)
        }
    }

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
            if String(secondChar) == decimalSeparator { break }
            result = String(result.dropFirst())
        }

        return result
    }

    private func dismissKeyboard() {
        isNoteFieldFocused = false
        isAmountFieldFocused = false
    }

    // MARK: - Actions

    private func prefillFromDraft() {
        note = draft.note
        transactionDate = draft.effectiveDate
        selectedAccount = draft.account
        selectedSubcategory = draft.subcategory
        selectedTags = draft.tags

        if let amt = draft.amount {
            amountString = String(format: "%.2f", abs(amt))
        } else {
            amountString = "0.00"
        }
    }

    private func saveDraft() {
        draft.note = note
        draft.amount = amount.map { draft.amount ?? 0 >= 0 ? abs($0) : -abs($0) } ?? draft.amount
        draft.date = transactionDate
        draft.account = selectedAccount
        draft.subcategory = selectedSubcategory
        draft.tags = selectedTags
        draft.updatedAt = Date()

        // Update needsUserInput
        var needs: [String] = []
        if selectedAccount == nil { needs.append("account") }
        if selectedSubcategory == nil { needs.append("subcategory") }
        if amount == nil { needs.append("amount") }
        draft.needsUserInput = needs

        do {
            try modelContext.save()
        } catch {
            print("Error saving draft: \(error)")
        }
    }

    private func approveDraft() {
        guard let account = selectedAccount else {
            approveErrorMessage = L10n.Inbox.errorNoAccount
            showApproveError = true
            return
        }

        guard let amt = amount else {
            approveErrorMessage = L10n.Inbox.errorNoAmount
            showApproveError = true
            return
        }

        guard let subcategory = selectedSubcategory else {
            approveErrorMessage = L10n.Inbox.errorNoSubcategory
            showApproveError = true
            return
        }

        // Create TransactionItem
        let transaction = TransactionItem(
            date: transactionDate,
            amount: amt >= 0 ? amt : -abs(amt),
            currencyCode: account.currencyCode
        )
        transaction.note = note.isEmpty ? nil : note
        transaction.account = account
        transaction.subcategory = subcategory
        transaction.category = subcategory.category
        transaction.tags = selectedTags

        modelContext.insert(transaction)

        // Update draft status
        draft.status = .approved
        draft.updatedAt = Date()

        do {
            try modelContext.save()
            onApproved?()
            dismiss()
        } catch {
            print("Error approving draft: \(error)")
        }
    }
}

#Preview {
    InboxDraftEditSheet(draft: InboxDraft())
        .modelContainer(for: [InboxDraft.self, Account.self, Category.self, Tag.self], inMemory: true)
}
