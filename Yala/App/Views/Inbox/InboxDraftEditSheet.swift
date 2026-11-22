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
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @Bindable var draft: InboxDraft

    // ViewModel for pending drafts (to enable "Approve Next")
    @State private var viewModel = InboxDraftEditViewModel()

    // MARK: - State

    @ScaledMetric(relativeTo: .largeTitle) private var baseAmountSize: CGFloat = 64 // A11Y-DT: @ScaledMetric

    @State private var note: String = ""
    @State private var amountString: String = ""
    @State private var transactionDate: Date = Date.now
    @State private var selectedAccount: Account?
    @State private var selectedSubcategory: Subcategory?
    @State private var selectedTags: [Tag] = []
    @State private var isExpense: Bool = true

    // Nature
    @State private var selectedNeed: SubcategoryNeed?

    // Sheet states
    @State private var showAccountSelector = false
    @State private var showSubcategorySelector = false
    @State private var showTagSelector = false
    @State private var showDatePicker = false
    @State private var showNeedSelector = false

    // Focus state
    @FocusState private var isNoteFieldFocused: Bool
    @FocusState private var isAmountFieldFocused: Bool

    // Raw text expansion
    @State private var showRawText = false

    /// La tarjeta de la cuenta elegida, con sus líneas (la principal primero). Vacía si no tiene líneas. La cápsula de
    /// moneda las ofrece: elegir una moneda es elegir su línea (hoja B1; antes, las pastillas PEN · USD).
    @State private var cardMembers: [Account] = []

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
    @State private var initialDate: Date = Date.now
    @State private var initialAccount: Account?
    @State private var initialSubcategory: Subcategory?
    @State private var initialTags: [Tag] = []
    @State private var initialIsExpense: Bool = true

    // Success view state
    @State private var showSuccessView = false
    @State private var approvedTransaction: TransactionItem?
    @State private var successData: InboxApproveSuccessData?
    /// «Aprobar y hacer recurrente» (encargo del 15-nov): el aprobado sigue en el editor de recurrentes prellenado, en
    /// esta misma hoja, con el registro como primer pago.
    @State private var approvesIntoRecurring = false
    @State private var recurringRecord: TransactionItem?

    // Group conversion: grupos elegibles resueltos en .task (solo para gastos puntuales pendientes).
    // Vacío = no ofrecer la acción "Convertir a gasto compartido".
    @State private var eligibleGroups: [SplitGroup] = []
    /// El grupo elegido en el chip de grupo (22-nov-2026): con él, «Guardar» convierte el borrador en gasto de ese grupo.
    @State private var chosenGroupID: UUID?

    // Callbacks
    var onApproved: (() -> Void)?
    var onApproveNext: ((InboxDraft) -> Void)?
    var onEditTransaction: ((TransactionItem) -> Void)?
    /// Redirige el draft (gasto personal puntual) a un gasto compartido de grupo en vez de
    /// aprobarlo como `TransactionItem`. `groups` = grupos elegibles ya resueltos (≥1). `InboxView`
    /// es dueño del ruteo (1 grupo → form directo; >1 → picker). Ver Approach A del feature.
    var onConvertToGroupExpense: ((InboxDraft, [SplitGroup]) -> Void)?
    /// Abierto desde un pago planificado para pagar una fecha concreta (UX 2.2 · L10-9, L10-11): el título dice qué fecha
    /// se paga («Pagar ahora el del 18 de octubre»), y al guardar vuelve al detalle del pago, sin la pantalla de éxito ni
    /// «Aprobar siguiente», que llevaban a otros borradores de la Bandeja.
    var payNowTitle: String?

    // MARK: - Computed

    private var amount: Double? {
        let value = AmountInputHelper.parseDecimal(amountString)
        return value > 0 ? value : nil
    }

    private var isReadyToApprove: Bool {
        selectedAccount != nil && amount != nil && selectedSubcategory != nil
    }

    /// El grupo del chip, si sigue entre los elegibles.
    private var chosenGroup: SplitGroup? {
        guard let chosenGroupID else { return nil }
        return eligibleGroups.first { $0.id == chosenGroupID }
    }

    /// «Guardar»: con grupo, solo el monto (la cuenta y la categoría se eligen en el gasto de grupo).
    private var canSave: Bool {
        InboxDraftGroupChipLogic.canSave(
            hasChosenGroup: chosenGroup != nil, hasAmount: amount != nil, isReadyToApprove: isReadyToApprove)
    }

    private var missingFieldsText: String? {
        var missing: [String] = []
        let hasGroup = chosenGroup != nil
        if !hasGroup, selectedAccount == nil { missing.append(L10n.Transaction.account) }
        if amount == nil { missing.append(L10n.Transaction.amount) }
        if !hasGroup, selectedSubcategory == nil { missing.append(L10n.Transaction.subcategory) }
        guard !missing.isEmpty else { return nil }
        return "\(L10n.Inbox.missingLabel) \(missing.joined(separator: ", "))"
    }

    private var currencySymbol: String? {
        guard let code = selectedAccount?.currencyCode else { return nil }
        return appPreferences.currencyIdentifier(for: code)
    }

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

    /// El color del monto de los tres formularios de registro (registro unificado): rosa el gasto, turquesa el ingreso.
    /// Antes, el gasto salía en blanco aquí y en rosa en Nuevo registro. Sin monto, el «0.00» es el ejemplo gris del campo
    /// (`prompt`): el color de un campo con foco no cambia hasta salir de él (`swiftui-ds.md`).
    private var amountColor: Color {
        Color.recordFormAmount(isIncome: !isExpense)
    }

    /// Next pending draft (excluding current one)
    private var nextPendingDraft: InboxDraft? {
        viewModel.nextPendingDraft(excluding: draft)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let recurringRecord {
                RecurringFromRecordSheet(record: recurringRecord)
            } else if showSuccessView, let data = successData {
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
        .task(id: draft.persistentModelID) {
            // Resuelve los grupos elegibles SOLO si el draft es un candidato barato (gasto
            // puntual pendiente): evita el fetch de grupos en ingresos/fuentes no convertibles.
            // El gate fino (isExpense vivo, monto) se evalúa en el botón, no aquí.
            guard DraftConversionEligibilityLogic.convertibleSources.contains(draft.sourceType),
                  draft.status == .pending else {
                eligibleGroups = []
                return
            }
            do {
                eligibleGroups = try GroupService.shared.eligibleGroupsForExpense(context: modelContext)
            } catch {
                #if DEBUG
                print("InboxDraftEditSheet: error fetching eligible groups for conversion: \(error)")
                #endif
                eligibleGroups = []
            }
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
                .navigationTitle(formTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .task(id: selectedAccount?.persistentModelID) { loadCardMembers() }
                .sheet(isPresented: $showAccountSelector) { accountSheet }
                .sheet(isPresented: $showSubcategorySelector) { subcategorySheet }
                .sheet(isPresented: $showTagSelector) { tagSheet }
                .sheet(isPresented: $showDatePicker) { dateSheet }
                .sheet(isPresented: $showNeedSelector) { needSheet }
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
                .onChange(of: showNeedSelector) { _, isPresenting in
                    if isPresenting { dismissKeyboard() }
                }
                .onChange(of: selectedSubcategory) { _, newSubcategory in
                    if let subcategory = newSubcategory {
                        selectedNeed = subcategory.need
                    } else {
                        selectedNeed = nil
                    }
                }
                .alert(L10n.Inbox.cannotApprove, isPresented: $showApproveError) {
                    Button(L10n.Common.ok, role: .cancel) {}
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
                    .accessibilityIdentifier("draft_editor_delete_confirm")
                } message: {
                    Text(L10n.Inbox.deleteMessage)
                }
        }
    }

    private var mainContent: some View {
        // Con los selectores en dos filas (registro unificado) la pantalla crece: va en el molde del scroll con alto mínimo
        // de Nuevo registro (`swiftui-ds.md`), que cuando cabe reparte igual con los `Spacer`s y no desplaza.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    // Sin el segmentado Gasto | Ingreso: el tipo se cambia en el título, como en Nuevo registro (B1).
                    Spacer()
                    centralContent
                    Spacer()
                    bottomChips
                        .padding(.bottom, DS.Spacing.lg)
                    actionButtons
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.bottom, DS.Spacing.xxl)
                }
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .dismissKeyboardOnTap()
        }
        // Sheet full-height (presentado sin detents desde InboxView) → .subtle.
        // El `.partialSheet` (subtle solo si la ventana fuerza `.large`) es solo para
        // detents parciales; aquí dejaba ver el gris de sistema del sheet en iPhone.
        .yalaScreenBackground(.subtle)
    }

    // MARK: - Título con el tipo (hoja B1)

    /// «Editar gasto» / «Editar ingreso»; desde «Pagar ahora», el título de esa fecha.
    private var formTitle: String {
        payNowTitle ?? NewRecordTitleLogic.title(type: isExpense ? .expense : .income, mode: .edit)
    }

    /// El título abre el menú Gasto | Ingreso, como en Nuevo registro: no en «solo gastos» ni desde «Pagar ahora».
    private var opensTypeMenu: Bool {
        payNowTitle == nil && !sessionState.isExpensesOnlyMode
    }

    @ViewBuilder
    private var typeTitle: some View {
        let label = HStack(spacing: DS.Spacing.xs) {
            Text(formTitle)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if opensTypeMenu {
                Image(systemName: "chevron.down")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        if opensTypeMenu {
            Menu {
                ForEach([TransactionType.expense, .income], id: \.self) { type in
                    Button {
                        chooseType(type)
                    } label: {
                        if (type == .expense) == isExpense {
                            Label(type.displayName, systemImage: "checkmark")
                        } else {
                            Label(type.displayName, systemImage: type.iconName)
                        }
                    }
                    .accessibilityIdentifier("draft_editor_type_\(type.rawValue)")
                }
            } label: {
                label
                    .padding(.horizontal, DS.Spacing.sm)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // En la barra un `Menu` toma el tinte índigo del tema: primary, como en Nuevo registro (Jürgen, 20-nov).
            .tint(Color.primary)
            .accessibilityLabel(NuevoRegistroB1Text.string("title.a11yChangeType"))
            .accessibilityValue(formTitle)
            .accessibilityIdentifier("draft_editor_type_menu")
        } else {
            label
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// Lo que hacía el segmentado: otro tipo vacía la subcategoría (la de un gasto no vale para un ingreso).
    private func chooseType(_ type: TransactionType) {
        let wantsExpense = type == .expense
        guard wantsExpense != isExpense else { return }
        DS.Haptic.selection()
        dsWithAnimation(reduceMotion) {
            isExpense = wantsExpense
            selectedSubcategory = nil
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                if hasUnsavedChanges() {
                    showDiscardChangesAlert = true
                } else {
                    dismiss()
                }
            }
        }
        ToolbarItem(placement: .principal) {
            typeTitle
        }
        ToolbarItem(placement: .topBarTrailing) {
            if initialStatus == .rejected {
                // Rejected drafts: delete button
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(DS.Semantic.errorForeground)
                }
                .accessibilityLabel(L10n.Action.delete)
            } else if payNowTitle == nil, offersRecurringInMenu || canDiscard || canDeleteForever {
                // Pendiente: lo que destruye va en un menú «⋯» con texto, y arriba queda una sola X, la que cierra
                // (UX 2.2 · L4-5, variante 2). Antes era una ⓧ roja sin texto que se leía como «cerrar» o «borrar».
                // «Guardar y hacer recurrente» vive aquí desde el 22-nov-2026 (antes, un enlace bajo «Guardar»).
                Menu {
                    if offersRecurringInMenu {
                        Button {
                            approvesIntoRecurring = true
                            approveDraft()
                        } label: {
                            Label(L10n.RecurringFromRecord.approveAndMakeRecurring, systemImage: "repeat")
                        }
                        .disabled(!isReadyToApprove)
                        .accessibilityHint(!isReadyToApprove ? L10n.Accessibility.approveCompleteHint : "")
                        .accessibilityIdentifier("inbox_approve_and_make_recurring_button")
                    }
                    if canDiscard {
                        Button {
                            rejectDraft()
                        } label: {
                            Label(L10n.Inbox.discardToArchived, systemImage: "archivebox")
                        }
                        .accessibilityIdentifier("draft_editor_discard")
                    }
                    if canDeleteForever {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label(L10n.Inbox.deleteForever, systemImage: "trash")
                        }
                        .accessibilityIdentifier("draft_editor_delete_forever")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                // «···» en primary, como en Nuevo registro (Jürgen, 20-nov).
                .tint(Color.primary)
                .accessibilityLabel(L10n.Common.moreOptions)
                .accessibilityIdentifier("draft_editor_more")
            }
        }
    }

    /// Lo que el servicio deja hacer con este borrador: el menú no ofrece lo que `DraftService` rechazaría sin decir
    /// nada (un gasto de grupo solo se quita desde su grupo; la marca viva de una liquidación y el aviso de importe
    /// cambiado no se borran). Mismas condiciones que `rejectDraft` y `deleteDraft`.
    private var canDiscard: Bool { !draft.sourceType.blocksInboxDismissal }

    /// «Guardar y hacer recurrente» (encargo del 15-nov): aprueba como siempre y sigue en el editor de recurrentes con el
    /// registro como primer pago. No en lo que ya viene de un recurrente, desde «Pagar ahora» ni con un grupo elegido.
    private var offersRecurringInMenu: Bool {
        InboxDraftGroupChipLogic.offersRecurringInMenu(
            offersRecurring: payNowTitle == nil && RecurringFromRecordLogic.offersApproveAndMakeRecurring(
                sourceType: draft.sourceType,
                sourceScheduledPaymentID: draft.sourceScheduledPaymentID,
                isPending: initialStatus == .pending
            ),
            hasChosenGroup: chosenGroup != nil
        )
    }

    private var canDeleteForever: Bool {
        !draft.sourceType.blocksInboxDismissal && !draft.isLiveSettlementApprovalMark
            && !draft.isSettlementAmountChangeNotice
    }

    private var accountSheet: some View {
        AccountSelectorSheet(
            selectedAccount: $selectedAccount,
            title: L10n.Transaction.account,
            // Elegir otra tarjeta conserva la divisa que ya tenía el borrador (entrega 3); la tarjeta de la propia línea
            // vuelve a su principal (card y1z6, `AccountSelectorViewModel.selection`).
            routingCurrency: selectedAccount?.currencyCode
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

    /// La misma hoja de fecha que Nuevo registro, con los atajos Hoy / Ayer / Anteayer (registro unificado).
    private var dateSheet: some View {
        DatePickerSheet(selectedDate: $transactionDate, quickPick: true)
    }

    private var needSheet: some View {
        NeedSelectorSheet(
            selectedNeed: Binding(
                get: {
                    selectedNeed ?? selectedSubcategory?.need ?? .unclassified
                },
                set: { selectedNeed = $0 }
            )
        )
        .yalaSheetDetents([.medium])
    }

    // MARK: - Central Content

    /// Como la hoja B1 de Nuevo registro: la descripción, el monto con la cápsula de moneda a su izquierda, la subcategoría
    /// bajo el monto con «● Categoría · ● Necesidad ▾» y, debajo, de dónde viene el borrador. La fecha baja a la fila de
    /// abajo, con la cuenta y el «#».
    private var centralContent: some View {
        VStack(spacing: DS.Spacing.xl) {
            TextField(L10n.Transaction.description, text: $note)
                .recordDescriptionStyle()
                .autocorrectionDisabled(false)
                .focused($isNoteFieldFocused)
                .accessibilityIdentifier("draft_editor_note")

            amountDisplay
                .padding(.horizontal, DS.Spacing.lg)

            subcategoryBlock

            // Source indicator
            sourceIndicator
        }
    }

    /// La subcategoría rellena de su color y, elegida, su categoría y su necesidad (en un gasto) con puntito (B1).
    private var subcategoryBlock: some View {
        VStack(spacing: DS.Spacing.sm) {
            SelectionChip(
                icon: "tag",
                text: selectedSubcategory?.name ?? L10n.Transaction.subcategory,
                isSelected: selectedSubcategory != nil,
                color: subcategoryChipColor,
                isMissing: amount != nil && selectedSubcategory == nil,
                fillsWhenSelected: true
            ) {
                dismissKeyboard()
                showSubcategorySelector = true
            }
            .padding(.horizontal, DS.Spacing.xl)
            .accessibilityIdentifier("draft_editor_subcategory_chip")

            if let subcategory = selectedSubcategory {
                CategoryNeedLine(
                    category: subcategory.safeCategory,
                    need: isExpense ? (selectedNeed ?? subcategory.need) : nil,
                    onNeedTap: { showNeedSelector = true }
                )
                .padding(.horizontal, DS.Spacing.xl)
            }
        }
    }

    /// La moneda del borrador es la de su cuenta (o la principal, sin cuenta). Con una tarjeta de varias monedas, la cápsula
    /// abre sus líneas; si no, no abre nada.
    private var displayCurrencyCode: String {
        selectedAccount?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue
    }

    private var currencyOptions: [AmountCurrencyOption] {
        cardMembers.map { AmountCurrencyOption(currencyCode: $0.currencyCode.uppercased(), accountCount: 1) }
    }

    private func chooseCardLine(_ code: String) {
        guard let member = cardMembers.first(where: { $0.currencyCode.uppercased() == code.uppercased() }) else { return }
        DS.Haptic.selection()
        selectedAccount = member
    }

    private func loadCardMembers() {
        guard let account = selectedAccount else {
            cardMembers = []
            return
        }
        do {
            let all = try modelContext.fetch(FetchDescriptor<Account>())
            let card = AccountCardLogic.liveMembers(of: account.shortcutID, nodes: all.map { AccountLineNode($0) })
            cardMembers = card.count > 1
                ? card.compactMap { node in all.first { $0.shortcutID == node.id } }
                : []
        } catch {
            #if DEBUG
            print("InboxDraftEditSheet: Error: fetch de cuentas de la tarjeta: \(error)")
            #endif
            cardMembers = []
        }
    }

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            AmountCurrencyCapsule(
                label: appPreferences.currencyIdentifier(for: displayCurrencyCode),
                options: currencyOptions,
                current: displayCurrencyCode.uppercased(),
                identifierPrefix: "draft_editor",
                onChoose: chooseCardLine
            )

            TextField("", text: $amountString, prompt: Text(verbatim: "0.00").foregroundStyle(.tertiary))
                .font(.system(size: amountFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(amountColor)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isAmountFieldFocused)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityIdentifier("draft_editor_amount")
                .onChange(of: isAmountFieldFocused) { _, isFocused in
                    if isFocused && (amountString == "0" || amountString == "0.00" || amountString == "0,00") {
                        amountString = ""
                    }
                    if !isFocused {
                        if amountString.isEmpty || AmountInputHelper.parseDecimal(amountString) == 0 {
                            amountString = ""
                        } else {
                            let amt = AmountInputHelper.parseDecimal(amountString)
                            amountString = AmountInputHelper.formatWithGrouping(abs(amt))
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
                        .font(DS.Typography.caption)
                    Text(sourceTypeName)
                        .font(DS.Typography.caption)
                    if draft.rawText != nil {
                        Image(systemName: showRawText ? "chevron.up" : "chevron.down")
                            .font(DS.Typography.captionSmall)
                    }
                }
                .foregroundStyle(.tertiary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                )
            }
            .buttonStyle(.plain)

            // Expandable rawText
            if showRawText, let rawText = draft.rawText, !rawText.isEmpty {
                Text(rawText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .frame(maxWidth: 280)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    private var sourceTypeName: String { draft.sourceDisplayName }

    // MARK: - Bottom Chips

    /// La fila de abajo de la hoja B1, siempre en una línea: Hoy · Cuenta · # · Grupo. Sin grupo elegido, si «Grupo» no
    /// cabe, el chip enseña solo su ícono. Con un grupo elegido enseña su nombre y, si no cabe, encoge con la cuenta
    /// (truncan los dos). Si aún no cabe, encoge la cuenta y trunca su nombre. Una tarjeta con varias monedas dice la
    /// tarjeta; su línea la elige la cápsula de moneda. Lo que falta para aprobar, con el borde de acento.
    @ViewBuilder
    private var bottomChips: some View {
        Group {
            if chosenGroup != nil {
                bottomChipRow(groupIconOnly: false)
            } else {
                ViewThatFits(in: .horizontal) {
                    bottomChipRow(groupIconOnly: false)
                    bottomChipRow(groupIconOnly: true)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .onChange(of: isExpense) { _, _ in releaseGroupIfItNoLongerFits() }
    }

    private var showsGroupChip: Bool {
        InboxDraftGroupChipLogic.showsChip(
            sourceType: draft.sourceType,
            isExpense: isExpense,
            hasEligibleGroups: !eligibleGroups.isEmpty,
            status: initialStatus,
            isPayingNow: payNowTitle != nil,
            hasChosenGroup: chosenGroup != nil
        )
    }

    private func bottomChipRow(groupIconOnly: Bool) -> some View {
        OneLineChipRow(spacing: DS.Spacing.sm) {
            RecordDateValueChip(text: dateChipText) {
                dismissKeyboard()
                showDatePicker = true
            }
            .accessibilityIdentifier("draft_editor_date_chip")

            RecordValueChip(
                icon: "creditcard",
                iconColor: selectedAccount.map { Color(hex: $0.colorHex) },
                text: cardMembers.first?.name ?? selectedAccount?.name ?? L10n.Transaction.account,
                isSet: selectedAccount != nil,
                isMissing: amount != nil && selectedAccount == nil
            ) {
                dismissKeyboard()
                showAccountSelector = true
            }
            .accessibilityIdentifier("draft_editor_account_chip")
            .shrinksInChipRow()

            // «#» con su número; un punto si Yala IA creó alguna de sus etiquetas («Nueva»).
            TagCountChip(
                tags: selectedTags,
                marksNew: selectedTags.contains { draft.newlyCreatedTagNames.contains($0.name) }
            ) {
                dismissKeyboard()
                showTagSelector = true
            }
            .accessibilityIdentifier("draft_editor_tags_chip")

            // El grupo (22-nov-2026, sustituye a «Convertir a gasto compartido»): elegido aquí, «Guardar» lo convierte.
            if showsGroupChip {
                groupChip(iconOnly: groupIconOnly)
                    .shrinksInChipRow(chosenGroup != nil)
            }
        }
    }

    /// El chip de grupo: un menú con los grupos donde se puede apuntar el gasto y, con uno elegido, «Sin grupo».
    private func groupChip(iconOnly: Bool) -> some View {
        let chosen = chosenGroup
        return Menu {
            ForEach(eligibleGroups, id: \.id) { group in
                Button {
                    chooseGroup(group.id)
                } label: {
                    if group.id == chosen?.id {
                        Label(group.name, systemImage: "checkmark")
                    } else {
                        Text(group.name)
                    }
                }
            }
            if chosen != nil {
                Divider()
                Button {
                    chooseGroup(nil)
                } label: {
                    Label(L10n.BandejaChipGrupo.none, systemImage: "person")
                }
                .accessibilityIdentifier("draft_editor_group_none")
            }
        } label: {
            RecordValueChipLabel(
                icon: "person.2",
                iconColor: chosen.map { Color(hex: $0.colorHex) },
                text: iconOnly ? nil : (chosen?.name ?? L10n.BandejaChipGrupo.chip),
                isSet: chosen != nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.BandejaChipGrupo.chip)
        .accessibilityValue(chosen?.name ?? "")
        .accessibilityHint(L10n.BandejaChipGrupo.chipHint)
        .accessibilityIdentifier("draft_editor_group_chip")
    }

    private func chooseGroup(_ id: UUID?) {
        DS.Haptic.selection()
        chosenGroupID = id
    }

    /// Un ingreso no se comparte: al pasar a ingreso, el grupo elegido se suelta.
    private func releaseGroupIfItNoLongerFits() {
        guard chosenGroupID != nil else { return }
        if !InboxDraftGroupChipLogic.keepsChosenGroup(
            chosenGroupID, isExpense: isExpense, eligibleGroupIDs: Set(eligibleGroups.map(\.id))) {
            chosenGroupID = nil
        }
    }

    private var subcategoryChipColor: Color? {
        guard let subcategory = selectedSubcategory else { return nil }
        return Color(hex: subcategory.safeCategory.colorHex)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Un borrador descartado dice que lo está y desde cuándo (UX 2.2 · L4-9): antes se abría con un solo
            // «Aprobar» y nada decía que estaba en Archivados.
            if initialStatus == .rejected {
                Label(L10n.Inbox.discardedOn(Self.discardedDateFormatter.string(from: draft.updatedAt)), systemImage: "archivebox")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("inbox_discarded_on")
            }

            // Validation message when not ready
            if let missingText = missingFieldsText {
                Text(missingText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Semantic.errorForeground)
            }

            HStack(spacing: DS.Spacing.md) {
                // Save button (secondary) - "Aprobar luego" - only for pending drafts. Desde un pago planificado no: dejaría
                // en la Bandeja un borrador de una fecha que la persona venía a pagar ahora (L10-11).
                if initialStatus == .pending && payNowTitle == nil {
                    Button {
                        saveDraft()
                        dismiss()
                    } label: {
                        Text(L10n.Inbox.saveLater)
                            .font(DS.Typography.headline)
                            .foregroundStyle(theme.accentText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.lg)
                            .background(
                                Capsule()
                                    .fill(theme.accent.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }

                // Descartado: «Volver a pendientes» junto a «Guardar» (UX 2.2 · L4-9). Guarda lo editado y lo devuelve
                // a la lista de pendientes.
                if initialStatus == .rejected {
                    Button {
                        returnToPending()
                    } label: {
                        Text(L10n.Inbox.returnToPending)
                            .font(DS.Typography.headline)
                            .foregroundStyle(theme.accentText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.lg)
                            .background(
                                Capsule()
                                    .fill(theme.accent.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("inbox_return_to_pending_button")
                }

                // «Guardar». Con un grupo elegido en el chip, convierte el borrador en gasto de ese grupo (crea un
                // SplitExpense en vez de un TransactionItem personal): no exige subcategoría ni cuenta personal (se
                // eligen en el form de grupo), así que un borrador de Apple Pay sin clasificar también puede ir a un
                // grupo. «Guardar y hacer recurrente» está en el menú «…» (22-nov-2026).
                YalaPrimaryButton(
                    L10n.Inbox.approve,
                    isDisabled: !canSave
                ) {
                    if let group = chosenGroup {
                        convertToGroup(group)
                    } else {
                        approvesIntoRecurring = false
                        approveDraft()
                    }
                }
                .accessibilityHint(!canSave ? L10n.Accessibility.approveCompleteHint : "")
                .accessibilityIdentifier("inbox_approve_button")
            }
        }
    }

    /// El flujo de convertir a compartido de siempre, ya con el grupo elegido: `saveDraft()` primero para que el form de
    /// grupo se prellene con lo editado; quien presenta la hoja abre el form directo (un solo grupo). Si se cancela el
    /// form, el borrador queda igual.
    private func convertToGroup(_ group: SplitGroup) {
        saveDraft()
        onConvertToGroupExpense?(draft, [group])
        dismiss()
    }

    // MARK: - Helpers

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = AppLocale.current
        return f
    }()

    private var dateChipText: String {
        if Calendar.current.isDateInToday(transactionDate) {
            return L10n.Date.today
        } else if Calendar.current.isDateInYesterday(transactionDate) {
            return L10n.Date.yesterday
        } else {
            return Self.mediumDateFormatter.string(from: transactionDate)
        }
    }

    private func filterAmountInput(_ input: String) -> String {
        AmountInputHelper.filterAmountInput(input)
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
        // CSV-mirror SSOT via resolver + TagResolver.
        selectedTags = TagResolver.fetchOrEmpty(
            ids: draft.resolvedTagIDs(scheduleBackfill: true) ?? [],
            in: modelContext,
            errorContext: "InboxDraftEditSheet/prefill"
        )

        if let amt = draft.amount {
            amountString = AmountInputHelper.formatWithGrouping(abs(amt))
            isExpense = amt < 0
        } else {
            amountString = ""
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
            let suggestion = merchantService.suggest(for: note, isExpense: isExpense)
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
        if chosenGroup != nil { return true }

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
        draft.setTags(from: selectedTags)

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
            DS.Haptic.error()
            showApproveError = true
            return
        }

        if account.isArchived {
            approveErrorMessage = L10n.Inbox.errorArchivedAccount
            DS.Haptic.error()
            showApproveError = true
            return
        }

        guard let amt = amount else {
            approveErrorMessage = L10n.Inbox.errorNoAmount
            DS.Haptic.error()
            showApproveError = true
            return
        }

        guard selectedSubcategory != nil else {
            approveErrorMessage = L10n.Inbox.errorNoSubcategory
            DS.Haptic.error()
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
        let outcome = currencyConverter.convertChecked(
            Decimal(finalAmount),
            from: account.currencyCode,
            to: preferredCode,
            on: transactionDate,
            context: modelContext
        )
        let amountInPreferred = outcome.amount
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
        transaction.setTags(from: selectedTags)
        transaction.exchangeRate = abs(exchangeRate)
        transaction.amountInPreferredCurrency = (amountInPreferred as NSDecimalNumber).doubleValue
        transaction.preferredCurrencyCode = preferredCode
        transaction.isExchangeRateProvisional = !outcome.quality.isExact

        // Set nature override if user changed it
        if let need = selectedNeed, need != subcategory.need {
            transaction.needOverride = need.rawValue
        }

        modelContext.insert(transaction)

        // Update draft with current values and mark as approved
        draft.note = note
        draft.amount = finalAmount
        draft.date = transactionDate
        draft.account = account
        draft.subcategory = subcategory
        draft.setTags(from: selectedTags)
        draft.status = .approved
        draft.approvedTransaction = transaction
        draft.updatedAt = Date.now

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
        let createsAnOwnRecord = DraftService.approvalCreatesAnOwnRecord(draft)

        do {
            try modelContext.save()
            WidgetDataCache.updateCache(context: modelContext)
            SessionState.shared.incrementDataVersion()
            // Telemetría del usuario nuevo (card 4b7h): el primer gasto o ingreso propio, si no era de prueba. Este
            // «Aprobar» crea el registro aquí mismo, sin pasar por `DraftService.approveDraft`.
            if createsAnOwnRecord { NewUserMetrics.created(.firstExpense) }

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
            DS.Haptic.success()

            // «Aprobar y hacer recurrente»: sin pantalla de éxito; la hoja pasa al editor de recurrentes. La Bandeja
            // ya sabe que se aprobó (al cerrarse, se cierra si no quedan pendientes, como tras «Listo»).
            if approvesIntoRecurring {
                approvesIntoRecurring = false
                onApproved?()
                recurringRecord = transaction
                return
            }

            // Desde un pago planificado se vuelve a su detalle: ni pantalla de éxito ni «Aprobar siguiente» (L10-11).
            if payNowTitle != nil {
                onApproved?()
                dismiss()
                return
            }
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

    /// Checks if a similar transaction already exists (same date, amount, account). El criterio es el de toda la Bandeja
    /// (`InboxDuplicateCheck`); aquí una lectura fallida deja guardar, como siempre: la persona está mirando el borrador.
    private func findDuplicateTransaction(amount: Double, date: Date, account: Account) -> TransactionItem? {
        do {
            return try InboxDuplicateCheck.findDuplicate(amount: amount, date: date, account: account, in: modelContext)
        } catch {
            #if DEBUG
            print("InboxDraftEditSheet: Error checking duplicates: \(error)")
            #endif
            return nil
        }
    }

    private func rejectDraft() {
        // Save current selections to draft before rejecting
        // (so they persist if draft is returned to pending later)
        draft.account = selectedAccount
        draft.subcategory = selectedSubcategory
        draft.setTags(from: selectedTags)
        draft.note = note
        if let amt = amount {
            draft.amount = isExpense ? -abs(amt) : abs(amt)
        }
        draft.date = transactionDate

        draftService.setContext(modelContext)
        do {
            try draftService.rejectDraft(draft)
            // Descartar desde el editor, una vez hecho (card C4; mapa de `DS.Haptic`).
            DS.Haptic.warning()
            dismiss()
            showDiscardedNotice()
        } catch {
            #if DEBUG
            print("InboxDraftEditSheet: Error rejecting draft: \(error)")
            #endif
        }
    }

    /// «Lo moviste a Archivados · Deshacer» (UX 2.2 · L4-5). Sobrevive al cierre del editor: desde la voz, la persona
    /// vuelve al Panel y el aviso le dice dónde quedó el gasto. «Deshacer» lo devuelve a pendientes.
    private func showDiscardedNotice() {
        let draft = draft
        let draftService = draftService
        let context = modelContext
        DraftDiscardUndoNotice.show {
            // Si en esos segundos se borró o cambió de estado por otro camino, no hay nada que deshacer.
            guard !draft.isDeleted, draft.status == .rejected else { return }
            draftService.setContext(context)
            do {
                // La Bandeja abierta lo vuelve a enseñar sola: su lista lee el estado de cada borrador.
                try draftService.returnToPending(draft)
                // Deshacer, solo si de verdad se deshizo (card C3; mapa de `DS.Haptic`).
                DS.Haptic.success()
            } catch {
                #if DEBUG
                print("InboxDraftEditSheet: Error undoing discard: \(error)")
                #endif
            }
        }
    }

    /// Mes entero («17 de octubre»): la abreviatura termina en punto en español y con el punto de la frase salía
    /// «17 oct.. Está» (medido en el simulador).
    private static let discardedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter
    }()

    /// Devuelve el descartado a pendientes con lo editado (UX 2.2 · L4-9).
    private func returnToPending() {
        saveDraft()
        draftService.setContext(modelContext)
        do {
            try draftService.returnToPending(draft)
            dismiss()
        } catch {
            #if DEBUG
            print("InboxDraftEditSheet: Error returning draft to pending: \(error)")
            #endif
        }
    }

    private func deleteDraftPermanently() {
        draftService.setContext(modelContext)
        do {
            try draftService.deleteDraft(draft)
            DS.Haptic.warning()
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
