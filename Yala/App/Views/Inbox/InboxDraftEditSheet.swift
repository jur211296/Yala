//
//  InboxDraftEditSheet.swift
//  Yala
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(CurrencyConverter.self) private var currencyConverter
    @Environment(DraftService.self) private var draftService
    @Environment(SessionState.self) private var sessionState

    @Bindable var draft: InboxDraft

    // ViewModel for pending drafts (to enable "Approve Next")
    @State private var viewModel = InboxDraftEditViewModel()

    // MARK: - State

    @State private var note: String = ""
    @State private var amountString: String = ""
    @State private var transactionDate: Date = Date()
    @State private var selectedAccount: Account?
    @State private var selectedSubcategory: Subcategory?
    @State private var selectedTags: [Tag] = []
    @State private var isExpense: Bool = true

    // Nature
    @State private var selectedNature: SubcategoryNature?

    // Sheet states
    @State private var showAccountSelector = false
    @State private var showSubcategorySelector = false
    @State private var showTagSelector = false
    @State private var showDatePicker = false
    @State private var showNatureSelector = false

    @ScaledMetric(relativeTo: .largeTitle) private var baseAmountSize: CGFloat = 64

    // Focus state
    @FocusState private var isNoteFieldFocused: Bool
    @FocusState private var isAmountFieldFocused: Bool

    // Raw text expansion
    @State private var showRawText = false

    // Alert states
    @State private var showApproveError = false
    @State private var approveErrorMessage = ""
    @State private var showDuplicateWarning = false
    @State private var duplicateTransaction: TransactionItem?
    @State private var shouldCreateDespiteDuplicate = false
    @State private var showDeleteConfirmation = false
    @State private var showDiscardChangesAlert = false

    // Track initial status to prevent toolbar flash on reject
    @State private var initialStatus: DraftStatus = .pending

    // Merchant Memory: track suggested subcategory to detect corrections
    @State private var merchantSuggestedSubcategory: Subcategory?

    // Track initial values to detect unsaved changes
    @State private var initialNote: String = ""
    @State private var initialAmountString: String = ""
    @State private var initialDate: Date = Date()
    @State private var initialAccount: Account?
    @State private var initialSubcategory: Subcategory?
    @State private var initialTags: [Tag] = []
    @State private var initialIsExpense: Bool = true

    // Success view state
    @State private var showSuccessView = false
    @State private var approvedTransaction: TransactionItem?
    @State private var successData: InboxApproveSuccessData?

    // Callbacks
    var onApproved: (() -> Void)?
    var onApproveNext: ((InboxDraft) -> Void)?
    var onEditTransaction: ((TransactionItem) -> Void)?

    // MARK: - Computed

    private var amount: Double? {
        Double(amountString.replacingOccurrences(of: ",", with: "."))
    }

    private var isReadyToApprove: Bool {
        selectedAccount != nil && amount != nil && selectedSubcategory != nil
    }

    private var missingFieldsText: String? {
        var missing: [String] = []
        if selectedAccount == nil { missing.append(L10n.Transaction.account) }
        if amount == nil { missing.append(L10n.Transaction.amount) }
        if selectedSubcategory == nil { missing.append(L10n.Transaction.subcategory) }
        guard !missing.isEmpty else { return nil }
        return "\(L10n.Inbox.missingLabel) \(missing.joined(separator: ", "))"
    }

    private var currencyCode: String? {
        selectedAccount?.currencyCode
    }

    private var amountColor: Color {
        guard amount != nil else { return .secondary }
        return isExpense ? Color.hotPink : Color.electricIndigo
    }

    /// Next pending draft (excluding current one)
    private var nextPendingDraft: InboxDraft? {
        viewModel.nextPendingDraft(excluding: draft)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if showSuccessView, let data = successData {
                InboxApproveSuccessView(
                    data: data,
                    hasNextDraft: nextPendingDraft != nil,
                    onEdit: {
                        if let transaction = approvedTransaction {
                            onEditTransaction?(transaction)
                        }
                        dismiss()
                    },
                    onAccept: {
                        onApproved?()
                        dismiss()
                    },
                    onApproveNext: {
                        if let next = nextPendingDraft {
                            onApproveNext?(next)
                        }
                        dismiss()
                    }
                )
            } else {
                mainNavigationStack
            }
        }
        .id(draft.persistentModelID)  // Force new view when draft changes
        .tint(Color.electricIndigo)
        .onAppear {
            viewModel.setContext(modelContext)
            // Reset success view state when appearing
            showSuccessView = false
            successData = nil
            approvedTransaction = nil
            prefillFromDraft()
        }
        .onChange(of: draft.persistentModelID) { _, _ in
            // Reset state if draft changes (shouldn't happen, but safety)
            showSuccessView = false
            successData = nil
            approvedTransaction = nil
            prefillFromDraft()
        }
        .alert(L10n.Inbox.discardChangesTitle, isPresented: $showDiscardChangesAlert) {
            Button(L10n.Inbox.discardChanges, role: .destructive) {
                dismiss()
            }
            Button(L10n.Inbox.keepEditing, role: .cancel) {}
        } message: {
            Text(L10n.Inbox.discardChangesMessage)
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
                .sheet(isPresented: $showNatureSelector) { natureSheet }
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
                .onChange(of: showNatureSelector) { _, isPresenting in
                    if isPresenting { dismissKeyboard() }
                }
                .onChange(of: selectedSubcategory) { _, newSubcategory in
                    if let subcategory = newSubcategory {
                        selectedNature = subcategory.nature
                    } else {
                        selectedNature = nil
                    }
                }
                .alert(L10n.Inbox.cannotApprove, isPresented: $showApproveError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(approveErrorMessage)
                }
                .alert(L10n.Inbox.duplicateWarningTitle, isPresented: $showDuplicateWarning) {
                    Button(L10n.Common.cancel, role: .cancel) {
                        shouldCreateDespiteDuplicate = false
                    }
                    Button(L10n.Inbox.createAnyway, role: .destructive) {
                        shouldCreateDespiteDuplicate = true
                    }
                } message: {
                    Text(L10n.Inbox.duplicateWarningMessage)
                }
                .onChange(of: showDuplicateWarning) { _, isShowing in
                    // Trigger creation after alert dismisses if user chose to proceed
                    if !isShowing && shouldCreateDespiteDuplicate {
                        shouldCreateDespiteDuplicate = false
                        createTransactionAndApprove(skipDuplicateCheck: true)
                    }
                }
                .alert(L10n.Inbox.deleteTitle, isPresented: $showDeleteConfirmation) {
                    Button(L10n.Common.cancel, role: .cancel) {}
                    Button(L10n.Inbox.delete, role: .destructive) {
                        deleteDraftPermanently()
                    }
                } message: {
                    Text(L10n.Inbox.deleteMessage)
                }
        }
    }

    private var mainContent: some View {
        ZStack {
            Color.yalaBackground
                .ignoresSafeArea()
                .dismissKeyboardOnTap()

            VStack(spacing: 0) {
                // Transaction type selector (full width, at top)
                if !sessionState.isExpensesOnlyMode {
                    transactionTypeSelector
                        .padding(.top, DS.Spacing.sm)
                }

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

    // MARK: - Transaction Type Selector

    private var transactionTypeSelector: some View {
        HStack(spacing: 0) {
            // Expense button
            Button {
                dsWithAnimation(reduceMotion) {
                    isExpense = true
                    selectedSubcategory = nil
                }
            } label: {
                Text(L10n.Transaction.expense)
                    .font(.subheadline.weight(isExpense ? .semibold : .regular))
                    .foregroundStyle(isExpense ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(isExpense ? Color.hotPink : Color.clear)
                    )
            }

            // Income button
            Button {
                dsWithAnimation(reduceMotion) {
                    isExpense = false
                    selectedSubcategory = nil
                }
            } label: {
                Text(L10n.Transaction.income)
                    .font(.subheadline.weight(!isExpense ? .semibold : .regular))
                    .foregroundStyle(!isExpense ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(!isExpense ? Color.electricIndigo : Color.clear)
                    )
            }
        }
        .padding(DS.Spacing.xs)
        .background(Capsule().fill(Color.yalaCard))
        .padding(.horizontal, DS.Spacing.lg)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            YalaToolbarButton(systemName: "xmark", label: "Cerrar") {
                if hasUnsavedChanges() {
                    showDiscardChangesAlert = true
                } else {
                    dismiss()
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if initialStatus == .rejected {
                // Rejected drafts: delete button
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Eliminar")
            } else {
                // Pending drafts: reject button only
                Button {
                    rejectDraft()
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Rechazar")
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
        SubcategorySelectorSheet(
            selectedSubcategory: $selectedSubcategory,
            transactionType: isExpense ? .expense : .income
        )
    }

    private var tagSheet: some View {
        TagSelectorSheet(selectedTags: $selectedTags)
    }

    private var dateSheet: some View {
        DatePickerSheet(selectedDate: $transactionDate)
            .presentationDetents([.medium, .large])
    }

    private var natureSheet: some View {
        NatureSelectorSheet(
            selectedNature: Binding(
                get: {
                    selectedNature ?? selectedSubcategory?.nature ?? .unclassified
                },
                set: { selectedNature = $0 }
            )
        )
        .presentationDetents([.medium])
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
                        .font(DS.Typography.label)
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

            // Category chip + Nature chip (visible when subcategory is selected)
            if let subcategory = selectedSubcategory {
                HStack(spacing: DS.Spacing.sm) {
                    // Category chip (read-only)
                    let category = subcategory.safeCategory
                    let categoryColor = Color(hex: category.colorHex)
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: category.iconName ?? "folder")
                            .font(.caption2.weight(.medium))
                        Text(category.name)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(categoryColor.opacity(0.12))
                    )

                    NatureEditChip(
                        nature: selectedNature ?? subcategory.nature
                    ) {
                        showNatureSelector = true
                    }
                }
                .padding(.top, DS.Spacing.sm)
            }

            // Source indicator
            sourceIndicator
        }
    }

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
            if let code = currencyCode {
                Text(code)
                    .font(.system(size: amountFontSize * 0.44, weight: .medium, design: .rounded))
                    .foregroundStyle(amountColor.opacity(0.7))
            }

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
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var sourceIndicator: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Source type button (tap to expand/collapse rawText)
            Button {
                if draft.rawText != nil {
                    dsWithAnimation(reduceMotion) {
                        showRawText.toggle()
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: draft.sourceIcon)
                        .font(.caption)
                    Text(sourceTypeName)
                        .font(.caption)
                    if draft.rawText != nil {
                        Image(systemName: showRawText ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.tertiary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    Capsule()
                        .fill(Color(UIColor.label).opacity(0.05))
                )
            }
            .buttonStyle(.plain)

            // Expandable rawText
            if showRawText, let rawText = draft.rawText, !rawText.isEmpty {
                Text(rawText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .frame(maxWidth: 280)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color(UIColor.label).opacity(0.03))
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    private var sourceTypeName: String {
        switch draft.sourceType {
        case .voice: return L10n.Inbox.sourceVoice
        case .receiptPhoto: return L10n.Inbox.sourceReceipt
        case .screenshotList: return L10n.Inbox.sourceScreenshotList
        case .screenshotSingle: return L10n.Inbox.sourceScreenshot
        case .emailAlert: return L10n.Inbox.sourceEmail
        case .scheduledPayment: return L10n.Inbox.sourceScheduledPayment
        case .subscription: return L10n.Inbox.sourceSubscription
        case .applePay: return L10n.Inbox.sourceApplePay
        case .automation: return L10n.Inbox.sourceAutomation
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
                    color: selectedAccount.map { Color(hex: $0.colorHex) }
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
        let isNewlyCreated = draft.newlyCreatedTagNames.contains(tag.name)

        return HStack(spacing: DS.Spacing.sm) {
            Button {
                dismissKeyboard()
                showTagSelector = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: tag.iconName)
                        .font(DS.Typography.labelSmall)
                    Text(tag.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    // Show "New" badge for newly created tags
                    if isNewlyCreated {
                        Text(L10n.Inbox.newTag)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(Capsule().fill(Color.electricIndigo))
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                dsWithAnimation(reduceMotion) {
                    selectedTags.removeAll { $0.persistentModelID == tag.persistentModelID }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(DS.Typography.label)
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
        return Color(hex: subcategory.safeCategory.colorHex)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Validation message when not ready
            if let missingText = missingFieldsText {
                Text(missingText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: DS.Spacing.md) {
                // Save button (secondary) - "Aprobar luego" - only for pending drafts
                if initialStatus == .pending {
                    Button {
                        saveDraft()
                        dismiss()
                    } label: {
                        Text(L10n.Inbox.saveLater)
                            .font(.headline)
                            .foregroundStyle(Color.electricIndigo)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.lg)
                            .background(
                                Capsule()
                                    .fill(Color.electricIndigo.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }

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
                            Capsule()
                                .fill(isReadyToApprove ? Color.electricIndigo : Color.gray)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isReadyToApprove)
                .accessibilityHint(!isReadyToApprove ? "Para aprobar, completa cuenta, monto y categoría" : "")
            }
        }
    }

    // MARK: - Helpers

    private var amountFontSize: CGFloat {
        let length = amountString.count
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
        initialStatus = draft.status
        note = draft.note
        transactionDate = draft.effectiveDate
        selectedAccount = draft.account
        selectedSubcategory = draft.subcategory
        selectedTags = draft.tags ?? []

        if let amt = draft.amount {
            amountString = String(format: "%.2f", abs(amt))
            isExpense = amt < 0
        } else {
            amountString = "0.00"
            isExpense = true // Default to expense
        }

        // Force expense in expenses-only mode
        if sessionState.isExpensesOnlyMode {
            isExpense = true
        }

        // Merchant Memory: suggest subcategory if not already set
        merchantSuggestedSubcategory = nil
        if selectedSubcategory == nil && !note.trimmingCharacters(in: .whitespaces).isEmpty {
            let merchantService = MerchantMemoryService(modelContext: modelContext)
            let suggestion = merchantService.suggest(for: note)
            switch suggestion {
            case .suggest(let subcategory), .autoAssign(let subcategory):
                selectedSubcategory = subcategory
                merchantSuggestedSubcategory = subcategory
            case .none:
                break
            }
        }

        // Save initial values for change detection
        initialNote = note
        initialAmountString = amountString
        initialDate = transactionDate
        initialAccount = selectedAccount
        initialSubcategory = selectedSubcategory
        initialTags = selectedTags
        initialIsExpense = isExpense
    }

    private func hasUnsavedChanges() -> Bool {
        // Compare current values with initial values
        if note != initialNote { return true }
        if amountString != initialAmountString { return true }
        if !Calendar.current.isDate(transactionDate, inSameDayAs: initialDate) { return true }
        if selectedAccount?.persistentModelID != initialAccount?.persistentModelID { return true }
        if selectedSubcategory?.persistentModelID != initialSubcategory?.persistentModelID { return true }
        if isExpense != initialIsExpense { return true }

        // Compare tags by ID
        let currentTagIDs = Set(selectedTags.map { $0.persistentModelID })
        let initialTagIDs = Set(initialTags.map { $0.persistentModelID })
        if currentTagIDs != initialTagIDs { return true }

        return false
    }

    private func saveDraft() {
        // Update draft properties from local state
        draft.note = note
        draft.amount = amount.map { isExpense ? -abs($0) : abs($0) }
        draft.date = transactionDate
        draft.account = selectedAccount
        draft.subcategory = selectedSubcategory
        draft.tags = selectedTags

        draftService.setContext(modelContext)
        do {
            try draftService.saveDraft(draft)
        } catch {
            #if DEBUG
            print("InboxDraftEditSheet: Error saving draft: \(error)")
            #endif
        }
    }

    private func approveDraft() {
        // Dismiss keyboard to ensure all field values are committed
        dismissKeyboard()

        guard let account = selectedAccount else {
            approveErrorMessage = L10n.Inbox.errorNoAccount
            showApproveError = true
            return
        }

        if account.isArchived {
            approveErrorMessage = L10n.Inbox.errorArchivedAccount
            showApproveError = true
            return
        }

        guard let amt = amount else {
            approveErrorMessage = L10n.Inbox.errorNoAmount
            showApproveError = true
            return
        }

        guard selectedSubcategory != nil else {
            approveErrorMessage = L10n.Inbox.errorNoSubcategory
            showApproveError = true
            return
        }

        // Check for potential duplicate
        let finalAmount = isExpense ? -abs(amt) : abs(amt)
        if let duplicate = findDuplicateTransaction(amount: finalAmount, date: transactionDate, account: account) {
            duplicateTransaction = duplicate
            showDuplicateWarning = true
            return
        }

        // No duplicate, proceed
        createTransactionAndApprove(skipDuplicateCheck: true)
    }

    private func createTransactionAndApprove(skipDuplicateCheck: Bool) {
        guard let account = selectedAccount,
              let amt = amount,
              let subcategory = selectedSubcategory else { return }

        let finalAmount = isExpense ? -abs(amt) : abs(amt)

        // Calculate amount in preferred currency for charts/statistics
        let preferredCode = CurrencyDefaults.currentPreferred
        let amountInPreferred = currencyConverter.convert(
            Decimal(finalAmount),
            from: account.currencyCode,
            to: preferredCode,
            on: transactionDate,
            context: modelContext
        )
        let exchangeRate: Double
        if abs(finalAmount) > 0.0001 {
            exchangeRate = (amountInPreferred as NSDecimalNumber).doubleValue / finalAmount
        } else {
            exchangeRate = 1.0
        }

        let transaction = TransactionItem(
            date: transactionDate,
            amount: finalAmount,
            currencyCode: account.currencyCode
        )
        transaction.note = note.isEmpty ? nil : note
        transaction.account = account
        transaction.subcategory = subcategory
        transaction.category = subcategory.safeCategory
        transaction.tags = selectedTags
        transaction.exchangeRate = abs(exchangeRate)
        transaction.amountInPreferredCurrency = (amountInPreferred as NSDecimalNumber).doubleValue
        transaction.preferredCurrencyCode = preferredCode

        // Set nature override if user changed it
        if let nature = selectedNature, nature != subcategory.nature {
            transaction.natureOverride = nature.rawValue
        }

        modelContext.insert(transaction)

        // Update draft with current values and mark as approved
        draft.note = note
        draft.amount = finalAmount
        draft.date = transactionDate
        draft.account = account
        draft.subcategory = subcategory
        draft.tags = selectedTags
        draft.status = .approved
        draft.approvedTransaction = transaction
        draft.updatedAt = Date()

        // Cache display values for when related objects might be deleted later
        draft.cachedAccountName = account.name
        draft.cachedSubcategoryName = subcategory.name
        draft.cachedCategoryColorHex = subcategory.safeCategory.colorHex
        draft.cachedSubcategoryIcon = subcategory.iconName ?? subcategory.safeCategory.iconName
        draft.cachedCurrencyCode = account.currencyCode

        // Update Merchant Memory
        if !note.trimmingCharacters(in: .whitespaces).isEmpty {
            let merchantService = MerchantMemoryService(modelContext: modelContext)
            let wasCorrection = merchantSuggestedSubcategory != nil &&
                merchantSuggestedSubcategory?.persistentModelID != subcategory.persistentModelID
            merchantService.updateMemory(
                merchantRaw: note,
                subcategory: subcategory,
                wasCorrection: wasCorrection
            )
        }

        // Update scheduled payment if this draft came from one
        ScheduledPaymentDraftService.handleDraftApproved(draft: draft, context: modelContext)

        do {
            try modelContext.save()
            WidgetDataCache.updateCache(context: modelContext)

            // Prepare success view data
            approvedTransaction = transaction
            successData = InboxApproveSuccessData(
                date: transactionDate,
                accountName: account.name,
                accountColorHex: account.colorHex,
                note: note,
                amount: finalAmount,
                currencyCode: account.currencyCode,
                subcategoryName: subcategory.name,
                categoryName: subcategory.safeCategory.name,
                categoryColorHex: subcategory.safeCategory.colorHex,
                isExpense: isExpense
            )

            // Show success view with animation
            dsWithAnimation(reduceMotion) {
                showSuccessView = true
            }
        } catch {
            #if DEBUG
            print("Error approving draft: \(error)")
            #endif
        }
    }

    /// Checks if a similar transaction already exists (same date, amount, account)
    private func findDuplicateTransaction(amount: Double, date: Date, account: Account) -> TransactionItem? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { transaction in
                transaction.date >= startOfDay &&
                transaction.date < endOfDay &&
                transaction.amount == amount
            }
        )

        let transactions: [TransactionItem]
        do {
            transactions = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("InboxDraftEditSheet: Error checking duplicates: \(error)")
            #endif
            return nil
        }

        // Check if any matches the account
        return transactions.first { $0.account?.persistentModelID == account.persistentModelID }
    }

    private func rejectDraft() {
        // Save current selections to draft before rejecting
        // (so they persist if draft is returned to pending later)
        draft.account = selectedAccount
        draft.subcategory = selectedSubcategory
        draft.tags = selectedTags
        draft.note = note
        if let amt = amount {
            draft.amount = isExpense ? -abs(amt) : abs(amt)
        }
        draft.date = transactionDate

        draftService.setContext(modelContext)
        do {
            try draftService.rejectDraft(draft)
            dismiss()
        } catch {
            #if DEBUG
            print("InboxDraftEditSheet: Error rejecting draft: \(error)")
            #endif
        }
    }

    private func deleteDraftPermanently() {
        draftService.setContext(modelContext)
        do {
            try draftService.deleteDraft(draft)
            dismiss()
        } catch {
            #if DEBUG
            print("InboxDraftEditSheet: Error deleting draft: \(error)")
            #endif
        }
    }
}

#Preview {
    InboxDraftEditSheet(draft: InboxDraft())
        .modelContainer(for: [InboxDraft.self, Account.self, Category.self, Tag.self], inMemory: true)
}
