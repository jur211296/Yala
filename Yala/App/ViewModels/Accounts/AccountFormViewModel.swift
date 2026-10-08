//
//  AccountFormViewModel.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI
import WidgetKit

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

@MainActor
@Observable
final class AccountFormViewModel {

    // MARK: - Dependencies
    private var modelContext: ModelContext?
    var accountToEdit: Account?
    var existingNames: [String] = []
    private(set) var allTransactions: [TransactionItem] = []

    /// Lo que no es historial y también cuelga de una cuenta: se convierte con ella al cambiar su
    /// divisa (ticket `account-currency-change-leaves-scheduled-and-favorites-stale`).
    private(set) var allScheduledPayments: [ScheduledPayment] = []
    private(set) var allFavoritePayments: [FavoritePayment] = []
    /// Solo los PENDIENTES: aprobados y rechazados guardan su propia divisa.
    private(set) var pendingInboxDrafts: [InboxDraft] = []

    /// Los borradores que esta conversión ya reexpresó.
    ///
    /// **A diferencia de una transacción, un borrador no guarda divisa**: no hay estado que diga «ya
    /// está en la nueva». Sin esta marca, el re-chequeo de `saveAccount` justo después de convertir
    /// los volvía a contar como pendientes y la cuenta no se guardaba nunca; y un segundo «Convertir»
    /// los habría convertido dos veces.
    private var reexpressedDraftIDs: Set<PersistentIdentifier> = []

    // MARK: - Form State
    var name: String = ""
    var selectedType: AccountType = .general
    var accountNumber: String = ""

    // Balance - new transaction-based system
    var isPositive: Bool = true  // Sign selector for balance
    var balanceText: String = ""  // Amount without sign
    var adjustmentDate: Date = Date.now

    // Currency
    var selectedCurrency: CurrencyCode = .pen

    // Adjustment Mode
    var selectedAdjustmentMode: AdjustmentMode = .changeInitialBalance

    // Color
    var selectedColorHex: String = AppConstants.defaultColorHex
    var customColor: Color = Color(hex: "6366F1")
    var isPresentingColorPicker: Bool = false

    // Actions
    var excludeFromStatistics: Bool = false
    /// El toggle lo escribe por binding; la vista llama a `setArchived(_:)` en su `onChange` para
    /// que archivar arrastre la exclusión de estadísticas.
    var isArchived: Bool = false

    /// `true` si en ESTA edición fue archivar lo que encendió «Excluir de las estadísticas».
    ///
    /// Lo que decide si una cuenta suma es ese toggle, no estar archivada (decisión de Jürgen,
    /// 2026-10-03). Archivar solo lo enciende por el usuario y se lo dice; este flag recuerda que
    /// el cambio fue nuestro, para enseñar el aviso y para deshacerlo si desarchiva sin salir.
    private(set) var excludedByArchiving: Bool = false

    /// El aviso de «quedó excluida, puedes volver a incluirla» solo tiene sentido mientras siga
    /// siendo verdad: archivada, excluida, y excluida por archivarla.
    var showsArchiveExclusionNotice: Bool {
        excludedByArchiving && isArchived && excludeFromStatistics
    }

    /// Archivar enciende «Excluir de las estadísticas» si estaba apagado. Desarchivar en la misma
    /// edición deshace SOLO lo que hizo archivar; desarchivar una cuenta ya guardada como
    /// archivada no la re-incluye, porque el toggle sigue siendo del usuario.
    func setArchived(_ archived: Bool) {
        isArchived = archived
        if archived {
            guard !excludeFromStatistics else { return }
            excludeFromStatistics = true
            excludedByArchiving = true
        } else if excludedByArchiving {
            excludeFromStatistics = false
            excludedByArchiving = false
        }
    }

    /// El usuario tocó «Excluir de las estadísticas». Si la vuelve a incluir, la exclusión deja de
    /// ser obra de archivar: desde ahí el toggle es suyo, y desarchivar ya no lo apagará aunque
    /// después lo vuelva a encender a mano. `setArchived` solo lo enciende, así que su propio
    /// `onChange` (con `true`) no pasa por aquí.
    func excludeChanged(to excluded: Bool) {
        if !excluded { excludedByArchiving = false }
    }

    // Credit card
    var creditCardPaymentReminder: Bool = false
    var creditCardPaymentDay: Int = 1

    // MARK: - UI State
    var isShowingDeleteError: Bool = false
    var deleteErrorMessage: String = ""
    var isShowingSaveError: Bool = false
    var hasInitializedBalance: Bool = false  // Track if balance was initialized from transactions

    // MARK: - Cambio de divisa con histórico

    /// La divisa que tenía la cuenta al abrir el formulario. `nil` al crear.
    ///
    /// Se congela en el `init` y no se vuelve a tocar: es el punto de comparación para saber si el
    /// usuario ha pedido un cambio de divisa. Leer `accountToEdit.currencyCode` en su lugar no
    /// serviría — `applyBaseAccountProperties` lo sobrescribe al guardar, así que después del primer
    /// intento la pregunta «¿ha cambiado?» se respondería siempre que no.
    private let originalCurrencyCode: String?

    /// La conversión que espera un sí del usuario. `nil` = no hay nada pendiente.
    ///
    /// Espeja el patrón de `currencyToSuggestAsSecondary`: un opcional que la vista convierte en
    /// `isPresented`, en vez de un `Bool` y un payload que pueden desincronizarse.
    var pendingCurrencyConversion: PendingCurrencyConversion?

    /// Se pidió cambiar la divisa de una cuenta cuyo histórico no admite reexpresión.
    var isShowingCurrencyChangeBlocked: Bool = false

    /// La conversión está corriendo (refresco de tasas incluido). La vista tapa y bloquea la
    /// pantalla mientras: a media conversión el histórico está partido entre dos divisas.
    var isConvertingCurrency: Bool = false

    /// No se pudieron reunir las tasas que la conversión necesitaba, así que **no se convirtió nada**.
    var isShowingCurrencyRatesUnavailable: Bool = false

    /// El último `fetch` de transacciones falló. No es lo mismo que no tener ninguna.
    private(set) var didFailToLoadTransactions: Bool = false

    /// El último `fetch` de programados, favoritos o borradores falló. Bloquea igual que el de
    /// transacciones: «no hay nada que convertir» y «no pude saberlo» llevan a decisiones opuestas.
    private(set) var didFailToLoadPlans: Bool = false

    #if DEBUG
    /// Finge un fetch fallido para poder fijar con un test que el gate falla **cerrado**.
    ///
    /// Hace falta un seam porque el único camino real es que `context.fetch` lance, y un
    /// `ModelContext` in-memory sano no lanza. Sin esto, el guard que impide que un fetch roto
    /// abra la puerta al bug original sería precisamente el que ninguna aserción puede tocar.
    func _testSimulateTransactionsLoadFailure() {
        allTransactions = []
        didFailToLoadTransactions = true
    }
    #endif

    /// Lo que la confirmación necesita saber para poder redactarse sin volver a calcular nada.
    struct PendingCurrencyConversion: Equatable {
        let rowCount: Int
        let fromCurrencyCode: String
        let toCurrencyCode: String
        /// Borradores pendientes de la Bandeja que se convierten con la tasa de su fecha.
        var draftCount: Int = 0
        /// Pagos programados y favoritos con importe que pasan a la tasa de hoy.
        var planCount: Int = 0
        /// Los primeros de esos, con su importe antes y después, para enseñarlos en el aviso.
        var planPreview: [PlanPreviewItem] = []

        /// ¿Hay algo que el aviso tenga que enseñar? Sin nada, no se pregunta (decisión D6).
        var hasAnythingToConvert: Bool { rowCount > 0 || draftCount > 0 || planCount > 0 }
    }

    /// Un pago programado o favorito tal como lo enseña el aviso: «Alquiler: PEN 3.500 → USD 930».
    struct PlanPreviewItem: Equatable {
        let name: String
        let fromCurrencyCode: String
        let fromAmount: Double
        let toAmount: Double
        /// La tasa de hoy aún no era la exacta al pintar el aviso: el importe sale con «≈».
        let isEstimate: Bool
    }

    /// Cuántos programados y favoritos se enseñan con su importe en el aviso. El resto se cuenta.
    static let planPreviewLimit = 3

    // MARK: - Secondary Currency Suggestion
    var currencyToSuggestAsSecondary: CurrencyCode? = nil

    // MARK: - Computed Balance Properties

    /// Current balance calculated from all transactions
    var currentBalance: Double {
        guard let account = accountToEdit else { return 0 }
        return InitialBalanceService.currentBalance(
            for: account,
            allTransactions: allTransactions
        )
    }

    /// Existing initial balance transaction amount (for editing)
    var existingInitialBalance: Double {
        guard let account = accountToEdit else { return 0 }
        // Need to get from context, but we don't have it here
        // So we calculate: current balance - sum of non-initial transactions
        let nonInitialTransactions = allTransactions.filter {
            $0.account?.persistentModelID == account.persistentModelID
                && $0.balanceAdjustmentType != InitialBalanceService.typeInitialBalance
        }
        let otherTransactionsSum = nonInitialTransactions.reduce(0.0) { $0 + $1.amount }
        return currentBalance - otherTransactionsSum
    }

    /// The parsed balance amount from user input
    var parsedBalanceAmount: Double? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let magnitude = AmountInputHelper.parseDecimal(trimmed)
        if magnitude == 0 && trimmed != "0" && !trimmed.hasPrefix("0") { return nil }
        return isPositive ? magnitude : -magnitude
    }

    /// For "Cambiar saldo inicial" mode: what the final balance will be
    var calculatedFinalBalance: Double? {
        guard selectedAdjustmentMode == .changeInitialBalance else { return nil }
        guard let newInitial = parsedBalanceAmount else { return nil }
        // Final = Current - OldInitial + NewInitial
        let oldInitial = existingInitialBalance
        return currentBalance - oldInitial + newInitial
    }

    /// For "Ajustar por registro" mode: the adjustment amount needed
    var adjustmentAmount: Double? {
        guard selectedAdjustmentMode == .byEntry else { return nil }
        guard let targetBalance = parsedBalanceAmount else { return nil }
        return targetBalance - currentBalance
    }

    /// Whether an adjustment is needed
    var needsAdjustment: Bool {
        if selectedAdjustmentMode == .changeInitialBalance {
            guard let newInitial = parsedBalanceAmount else { return false }
            return abs(newInitial - existingInitialBalance) > 0.01
        } else {
            guard let adjustment = adjustmentAmount else { return false }
            return abs(adjustment) > 0.01
        }
    }

    // MARK: - Initialization

    init(
        accountToEdit: Account?,
        existingNames: [String],
        allTransactions: [TransactionItem] = [],
        scheduledPayments: [ScheduledPayment] = [],
        favoritePayments: [FavoritePayment] = [],
        pendingInboxDrafts: [InboxDraft] = []
    ) {
        self.accountToEdit = accountToEdit
        self.existingNames = existingNames
        self.allTransactions = allTransactions
        self.allScheduledPayments = scheduledPayments
        self.allFavoritePayments = favoritePayments
        self.pendingInboxDrafts = pendingInboxDrafts
        self.originalCurrencyCode = accountToEdit.map { normalizeCurrencyCode($0.currencyCode) }

        if let account = accountToEdit {
            self.name = account.name
            self.selectedType = AccountType(rawValue: account.type) ?? .general
            self.accountNumber = account.accountNumber ?? ""

            self.selectedCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode)) ?? .pen

            // Default to "Ajustar por registro" when editing
            self.selectedAdjustmentMode = .byEntry

            self.selectedColorHex = account.colorHex
            self.customColor = colorForHex(account.colorHex)

            self.excludeFromStatistics = account.excludeFromStatistics
            self.isArchived = account.isArchived
            self.creditCardPaymentReminder = account.creditCardPaymentReminder
            self.creditCardPaymentDay = account.creditCardPaymentDay

            // Don't pre-fill balance here - will be done in initializeBalanceIfNeeded()
            // after transactions are loaded
            self.isPositive = true
            self.balanceText = ""
        } else {
            // Creation mode - default to "Cambiar saldo inicial"
            self.selectedAdjustmentMode = .changeInitialBalance
            self.selectedColorHex = AppConstants.defaultColorHex
            self.customColor = Color(hex: "6366F1")
            self.isPositive = true
            self.balanceText = ""
        }
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadTransactions()
        loadPlans()
        initializeBalanceIfNeeded()
    }

    /// Carga lo que se convierte con la cuenta además del historial.
    ///
    /// Se filtra por cuenta en memoria, como `accountTransactions`: un `#Predicate` sobre la
    /// relación (`$0.account?.persistentModelID`) es justo la forma que SwiftData no garantiza, y
    /// estas tablas son pequeñas.
    func loadPlans() {
        guard let context = modelContext else { return }
        do {
            allScheduledPayments = try context.fetch(FetchDescriptor<ScheduledPayment>())
            allFavoritePayments = try context.fetch(FetchDescriptor<FavoritePayment>())
            let pending = DraftStatus.pending.rawValue
            pendingInboxDrafts = try context.fetch(
                FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.statusRaw == pending }))
            didFailToLoadPlans = false
        } catch {
            #if DEBUG
            print("AccountFormViewModel: Error loading plans: \(error)")
            #endif
            allScheduledPayments = []
            allFavoritePayments = []
            pendingInboxDrafts = []
            didFailToLoadPlans = true
        }
    }

    func loadTransactions() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<TransactionItem>()
        do {
            allTransactions = try context.fetch(descriptor)
            didFailToLoadTransactions = false
        } catch {
            #if DEBUG
            print("AccountFormViewModel: Error loading transactions: \(error)")
            #endif
            allTransactions = []
            // **El fallo se registra porque «no hay movimientos» y «no pude saberlo» llevan a
            // decisiones OPUESTAS.** Con la lista vacía el veredicto es `.free` y la divisa se cambia
            // sin convertir nada — que es exactamente el bug original. Un gate que se abre cuando su
            // entrada falla no es una red.
            didFailToLoadTransactions = true
        }
    }

    /// Call this after transactions are loaded to pre-fill the initial balance
    func initializeBalanceIfNeeded() {
        guard isEditing, !hasInitializedBalance else { return }

        // If the account has no initial balance transaction, show "Saldo inicial" mode
        // instead of "Ajustar por registro" — e.g., default account from onboarding
        let hasInitialBalanceTx = allTransactions.contains {
            $0.account?.persistentModelID == accountToEdit?.persistentModelID
                && $0.balanceAdjustmentType == InitialBalanceService.typeInitialBalance
        }
        if !hasInitialBalanceTx {
            selectedAdjustmentMode = .changeInitialBalance
        }

        guard !allTransactions.isEmpty else { return }

        if selectedAdjustmentMode == .changeInitialBalance {
            let existingInitial = existingInitialBalance
            isPositive = existingInitial >= 0
            balanceText = String(format: "%.2f", abs(existingInitial))
        }
        // .byEntry: balanceText stays empty — user must explicitly enter target

        hasInitializedBalance = true
    }

    /// Handle adjustment mode change — reset balanceText based on new mode semantics
    func adjustmentModeChanged() {
        guard isEditing else { return }
        if selectedAdjustmentMode == .changeInitialBalance {
            let existingInitial = existingInitialBalance
            isPositive = existingInitial >= 0
            balanceText = String(format: "%.2f", abs(existingInitial))
        } else {
            // .byEntry: clear to require explicit user input
            balanceText = ""
            isPositive = true
        }
    }

    // MARK: - Computed Properties (Validation)

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isNameValid: Bool {
        !trimmedName.isEmpty
    }

    var isNameUnique: Bool {
        let lower = trimmedName.lowercased()
        if let account = accountToEdit, account.name.lowercased() == lower {
            return true
        }
        return
            !existingNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .contains(lower)
    }

    var isCurrencyValid: Bool {
        CurrencyCode.allCases.contains(where: { $0.rawValue == selectedCurrency.rawValue })
    }

    var isBalanceValid: Bool {
        // For new accounts, must have an initial balance
        // For existing accounts, balance change is optional
        if isEditing {
            return balanceText.isEmpty || parsedBalanceAmount != nil
        } else {
            return parsedBalanceAmount != nil
        }
    }

    var canSave: Bool {
        isNameValid && isNameUnique && isCurrencyValid && isBalanceValid
    }

    var isEditing: Bool {
        accountToEdit != nil
    }

    // MARK: - Computed Properties (cambio de divisa)

    /// Las transacciones que cuelgan de la cuenta en edición.
    ///
    /// El `guard let` no es defensivo de más: sin él, `accountToEdit?.persistentModelID` vale `nil` al
    /// crear una cuenta y la comparación casaría con toda fila cuya cuenta tampoco esté resuelta
    /// —las de la ventana lazy de CloudKit—, dando por movimientos de esta cuenta los de ninguna.
    var accountTransactions: [TransactionItem] {
        guard let account = accountToEdit else { return [] }
        return allTransactions.filter {
            $0.account?.persistentModelID == account.persistentModelID
        }
    }

    /// Los pagos programados de la cuenta que se convierten con ella: los personales
    /// (`AccountCurrencyPlanLogic.convertsScheduledPayment`) que no están ya en la divisa elegida.
    var scheduledPendingReexpression: [ScheduledPayment] {
        guard let account = accountToEdit else { return [] }
        let target = normalizeCurrencyCode(selectedCurrency.rawValue)
        return allScheduledPayments.filter {
            $0.account?.persistentModelID == account.persistentModelID
                && AccountCurrencyPlanLogic.convertsScheduledPayment(isGroupPayment: $0.isGroupPayment)
                && normalizeCurrencyCode($0.currencyCode) != target
        }
    }

    /// Los favoritos de la cuenta que no están ya en la divisa elegida. Un favorito sin divisa se lee
    /// en la de la cuenta al abrir, que es la que usaba al precargarse.
    var favoritesPendingReexpression: [FavoritePayment] {
        guard let account = accountToEdit else { return [] }
        let target = normalizeCurrencyCode(selectedCurrency.rawValue)
        let fallback = originalCurrencyCode ?? target
        return allFavoritePayments.filter {
            $0.account?.persistentModelID == account.persistentModelID
                && normalizeCurrencyCode($0.currencyCode ?? fallback) != target
        }
    }

    /// Los borradores pendientes de la cuenta que se convierten con el historial (decisión D1).
    var draftsPendingReexpression: [InboxDraft] {
        guard let account = accountToEdit, isCurrencyChangeRequested else { return [] }
        return pendingInboxDrafts.filter {
            $0.account?.persistentModelID == account.persistentModelID
                && !reexpressedDraftIDs.contains($0.persistentModelID)
                && AccountCurrencyPlanLogic.convertsDraft(.init(
                    isPending: $0.status == .pending,
                    sourceType: $0.sourceType,
                    hasGroupPointer: $0.splitExpenseID != nil
                        || $0.splitSettlementID != nil
                        || $0.splitGroupZoneID != nil,
                    hasAmount: $0.amount != nil
                ))
        }
    }

    /// El usuario ha elegido una divisa distinta de la que la cuenta tenía al abrir.
    var isCurrencyChangeRequested: Bool {
        guard let original = originalCurrencyCode else { return false }
        return normalizeCurrencyCode(selectedCurrency.rawValue) != original
    }

    /// Qué se puede hacer con la divisa de esta cuenta, dado su histórico.
    var currencyChangeVerdict: AccountCurrencyChangeLogic.Verdict {
        AccountCurrencyChangeLogic.verdict(
            for: accountTransactions.map {
                AccountCurrencyChangeLogic.RowShape(
                    isTransferType: $0.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer,
                    hasTransferPairID: $0.transferPairID != nil,
                    hasSplitExpenseID: $0.splitExpenseID != nil,
                    hasSplitSettlementID: $0.splitSettlementID != nil
                )
            }
        )
    }

    /// La divisa con la que rotular importes que **todavía no se han convertido**.
    ///
    /// `currentBalance` suma los `amount` crudos, que siguen en la divisa de la cuenta hasta que el
    /// usuario confirma. Rotularlos con `selectedCurrency` —que cambia en cuanto sale del selector—
    /// enseñaba «$ 900,00» sobre novecientos soles, e invitaba a teclear un ajuste pensando en
    /// dólares. Al crear no hay cuenta detrás, así que manda lo elegido.
    var balanceDisplayCurrency: CurrencyCode {
        guard let original = originalCurrencyCode,
              let code = CurrencyCode(rawValue: original) else { return selectedCurrency }
        return code
    }

    /// Si el selector de divisa se puede abrir.
    ///
    /// Al **crear** siempre se puede: no hay histórico que desemparejar.
    var isCurrencyEditable: Bool {
        guard isEditing else { return true }
        if case .blocked = currencyChangeVerdict { return false }
        return true
    }

    /// Los motivos por los que la divisa está bloqueada, en orden estable para que el texto de la
    /// pantalla no baile entre aperturas (`Set` no tiene orden y el copy los concatena).
    var blockedCurrencyReasons: [AccountCurrencyChangeLogic.BlockReason] {
        guard case .blocked(let reasons, _) = currencyChangeVerdict else { return [] }
        return AccountCurrencyChangeLogic.BlockReason.allCases.filter { reasons.contains($0) }
    }

    /// Whether to show the adjustment mode selector (only when account already has an initial balance)
    var showAdjustmentMode: Bool {
        guard isEditing else { return false }
        return allTransactions.contains {
            $0.account?.persistentModelID == accountToEdit?.persistentModelID
                && $0.balanceAdjustmentType == InitialBalanceService.typeInitialBalance
        }
    }

    var colorOptions: [String] {
        ["#FF0080", "#D62246", "#FF7F11", "#4CB963", "#6366F1", "#1B065E", "#0F172A"]
    }

    // MARK: - Actions

    func updateColorFromCustom() {
        selectedColorHex = hexString(from: customColor)
        isPresentingColorPicker = false
    }

    /// Guarda la cuenta. Devuelve `false` si no se guardó nada.
    ///
    /// **`false` ya no significa solo «error»**: también significa «esto necesita que el usuario diga
    /// algo antes». Los dos casos nuevos dejan su propio estado publicado
    /// (`pendingCurrencyConversion`, `isShowingCurrencyChangeBlocked`) y la vista, que ya distinguía
    /// entre cerrar y no cerrar, se limita a no cerrar — igual que hacía con `canSave == false`.
    func saveAccount(context: ModelContext) -> Bool {
        guard canSave else { return false }
        guard passesCurrencyChangeGate() else { return false }

        let trimmedAccountNumber = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find the balance adjustment subcategory
        let subcategory = InitialBalanceService.findBalanceAdjustmentSubcategory(context: context)

        if let account = accountToEdit {
            // Update account properties
            applyBaseAccountProperties(to: account, trimmedAccountNumber: trimmedAccountNumber)

            // Handle balance adjustment if specified
            if let balanceValue = parsedBalanceAmount, needsAdjustment, let sub = subcategory {
                if selectedAdjustmentMode == .changeInitialBalance {
                    _ = InitialBalanceService.setInitialBalance(
                        amount: balanceValue,
                        for: account,
                        subcategory: sub,
                        allTransactions: allTransactions,
                        context: context
                    )
                } else {
                    _ = InitialBalanceService.createAdjustment(
                        targetBalance: balanceValue,
                        currentBalance: currentBalance,
                        for: account,
                        subcategory: sub,
                        date: adjustmentDate,
                        context: context
                    )
                }
            }
        } else {
            // Create new account
            let newAccount = Account(
                name: trimmedName,
                currencyCode: normalizeCurrencyCode(selectedCurrency.rawValue),
                colorHex: selectedColorHex,
                iconName: iconName(for: selectedType),
                type: selectedType.rawValue,
                accountNumber: trimmedAccountNumber.isEmpty ? nil : trimmedAccountNumber,
                adjustmentMode: selectedAdjustmentMode.rawValue,
                excludeFromStatistics: excludeFromStatistics,
                isArchived: isArchived
            )
            if selectedType == .creditCard {
                newAccount.creditCardPaymentReminder = creditCardPaymentReminder
                newAccount.creditCardPaymentDay = creditCardPaymentDay
            }
            context.insert(newAccount)

            // Create initial balance transaction if amount specified
            if let initialAmount = parsedBalanceAmount, let sub = subcategory {
                _ = InitialBalanceService.setInitialBalance(
                    amount: initialAmount,
                    for: newAccount,
                    subcategory: sub,
                    allTransactions: [],
                    context: context
                )
            }
        }

        // Force save to ensure @Query observers are notified of changes
        do {
            try context.save()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
        } catch {
            isShowingSaveError = true
            return false
        }

        // Suggest adding currency as secondary if applicable
        suggestSecondaryCurrencyIfNeeded()

        return true
    }

    // MARK: - Cambio de divisa con histórico

    /// Las filas de la cuenta que siguen estampadas en una divisa distinta de la elegida.
    ///
    /// Es el estado real, no una intención: por eso sirve a la vez para decidir si hay que preguntar
    /// y para saber si ya se convirtió. Un `Bool` «el usuario ya dijo que sí» respondería que sí
    /// aunque la conversión hubiera fallado a medias, que es justo el caso en el que no se debe
    /// guardar la cuenta con la divisa nueva.
    var rowsPendingReexpression: [TransactionItem] {
        let target = normalizeCurrencyCode(selectedCurrency.rawValue)
        return accountTransactions.filter { normalizeCurrencyCode($0.currencyCode) != target }
    }

    /// ¿Puede el guardado seguir adelante con la divisa elegida?
    ///
    /// **Está aquí a propósito, aunque la vista ya impida abrir el selector cuando está bloqueado.**
    /// El gate de la vista es comodidad —no llevar al usuario a un callejón— y el de aquí es la red:
    /// si mañana otra pantalla reusa este ViewModel, o el selector deja de gatearse en un refactor,
    /// el histórico sigue sin poder desemparejarse. Un guard puesto solo en la capa que se ve es un
    /// guard medio puesto.
    private func passesCurrencyChangeGate() -> Bool {
        guard isEditing, isCurrencyChangeRequested else { return true }

        // Sin saber qué cuelga de la cuenta no se puede decidir nada, y la lista vacía de un fetch
        // fallido se lee igual que una cuenta sin movimientos. Se bloquea.
        guard !didFailToLoadTransactions, !didFailToLoadPlans else {
            isShowingCurrencyChangeBlocked = true
            return false
        }

        switch currencyChangeVerdict {
        case .blocked:
            isShowingCurrencyChangeBlocked = true
            return false

        case .free, .needsConversion:
            // **`.free` ya no es «cambia sin preguntar»**: una cuenta sin movimientos puede tener un
            // alquiler programado o un favorito, y sus importes también se reescriben. Se pregunta en
            // cuanto hay ALGO que convertir; sin nada, la divisa se cambia como siempre (D6).
            let pending = makePendingConversion()
            guard pending.hasAnythingToConvert else { return true }
            // El saldo tecleado solo se descarta cuando hay MOVIMIENTOS que reexpresar (lo de abajo).
            // Sin ellos —solo programados, favoritos o borradores— no hay nada contra lo que compararlo
            // y borrarlo perdía el saldo inicial que la persona acababa de escribir.
            guard pending.rowCount > 0 else {
                pendingCurrencyConversion = pending
                return false
            }
            // **El importe tecleado en la sección de saldo se descarta al pedir la conversión.**
            // `balanceText` está en la divisa VIEJA —lo escribió el usuario, o lo plantó
            // `adjustmentModeChanged` desde `existingInitialBalance`— mientras que `currentBalance` y
            // `existingInitialBalance` pasan a leer los importes ya convertidos. Dejarlo puesto hace
            // que `needsAdjustment` compare 1.000 (soles) contra 266,67 (dólares) y meta un ajuste de
            // saldo de +733 que el usuario nunca vio en pantalla, o que `setInitialBalance` reescriba
            // el saldo inicial multiplicado por el tipo de cambio. La sección va deshabilitada en la
            // vista mientras hay cambio de divisa pendiente; esto es la mitad que no depende de la UI.
            balanceText = ""
            pendingCurrencyConversion = pending
            return false
        }
    }

    /// Lo que la confirmación va a enseñar: cuántos movimientos y borradores, y los programados y
    /// favoritos con su importe antes y después.
    ///
    /// Los importes «después» salen de `AccountCurrencyMigrationService.convertToday`, la MISMA
    /// función que los escribe al confirmar: si el aviso calculara por otro camino, la persona
    /// confirmaría una cifra y se guardaría otra. Si la tasa de hoy aún no es la exacta, el importe
    /// sale con «≈» y la conversión real espera a traerla (decisión D2).
    func makePendingConversion(now: Date = .now) -> PendingCurrencyConversion {
        let target = normalizeCurrencyCode(selectedCurrency.rawValue)
        let source = originalCurrencyCode ?? target

        let scheduled = scheduledPendingReexpression.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        let favorites = favoritesPendingReexpression
            .filter { $0.amount != nil }
            .sorted { $0.displayOrder < $1.displayOrder }
        // El recuento no depende del contexto: sin él no habría vista previa, pero la pregunta tiene
        // que salir igual — un recuento a cero cambiaría la divisa sin convertir nada.
        let planCount = scheduled.count + favorites.count

        var preview: [PlanPreviewItem] = []
        if let context = modelContext ?? accountToEdit?.modelContext {
            for payment in scheduled {
                guard preview.count < Self.planPreviewLimit else { break }
                let from = normalizeCurrencyCode(payment.currencyCode)
                let result = AccountCurrencyMigrationService.convertToday(
                    payment.amount, from: from, to: target, context: context, now: now)
                preview.append(PlanPreviewItem(
                    name: payment.name,
                    fromCurrencyCode: from,
                    fromAmount: payment.amount,
                    toAmount: (result.to as NSDecimalNumber).doubleValue,
                    isEstimate: !result.isExact
                ))
            }
            for favorite in favorites {
                guard preview.count < Self.planPreviewLimit else { break }
                guard let amount = favorite.amount else { continue }
                let from = normalizeCurrencyCode(favorite.currencyCode ?? source)
                let result = AccountCurrencyMigrationService.convertToday(
                    amount, from: from, to: target, context: context, now: now)
                preview.append(PlanPreviewItem(
                    name: favorite.name,
                    fromCurrencyCode: from,
                    fromAmount: amount,
                    toAmount: (result.to as NSDecimalNumber).doubleValue,
                    isEstimate: !result.isExact
                ))
            }
        }

        return PendingCurrencyConversion(
            rowCount: rowsPendingReexpression.count,
            fromCurrencyCode: source,
            toCurrencyCode: target,
            draftCount: draftsPendingReexpression.count,
            planCount: planCount,
            planPreview: preview
        )
    }

    /// El usuario ha confirmado: refresca las tasas, reexpresa el histórico y guarda la cuenta.
    ///
    /// Devuelve `true` si la cuenta quedó guardada (la vista cierra el formulario).
    ///
    /// **El `pending` entra por parámetro y no se lee del estado.** SwiftUI escribe `false` en el
    /// `isPresented` del alert al pulsar CUALQUIER botón de `actions`, así que un cuerpo `async` que
    /// leyera `pendingCurrencyConversion` correría contra ese setter y podría encontrárselo ya en
    /// `nil`. Con el dato viajando en la llamada, el orden deja de importar.
    ///
    /// Por lo mismo, la divisa destino se toma de `pending` y se **reafirma** en `selectedCurrency`
    /// antes de guardar: si algo la hubiera revertido durante el `await`, `saveAccount` escribiría la
    /// divisa vieja sobre un histórico ya convertido — el bug de este ticket, creado por su arreglo.
    ///
    /// **Las tasas antes que los importes**, y por el mismo motivo que en el cambio de divisa
    /// preferida: convertir sobre tasas que no están todavía sella un importe con lo que hubiera —en
    /// el caso normal, `1.0`— y repoblarlas después **no vuelve a convertir nada**.
    func confirmCurrencyConversion(
        _ pending: PendingCurrencyConversion,
        context: ModelContext
    ) async -> Bool {
        pendingCurrencyConversion = nil
        isConvertingCurrency = true
        defer { isConvertingCurrency = false }

        if let code = CurrencyCode(rawValue: pending.toCurrencyCode) {
            selectedCurrency = code
        }

        let ratesReady = await AccountCurrencyMigrationService.prepareRates(
            rows: rowsPendingReexpression,
            extra: planRateNeeds(),
            to: pending.toCurrencyCode,
            context: context
        )
        guard ratesReady else {
            // Sin las tasas del día de cada fila, convertir escribiría en la columna cruda un número
            // salido de la tabla estática —y esa columna no tiene reparador—. Se prefiere no hacer
            // nada y decirlo.
            isShowingCurrencyRatesUnavailable = true
            cancelCurrencyConversion()
            return false
        }

        // **Refetch DESPUÉS del `await`, y no antes.** `allTransactions` se cargó al abrir el
        // formulario, y el refresco de tasas hace red: en esa ventana el sync puede haber escrito en
        // el store una fila nueva de esta cuenta. Convertir sobre el snapshot viejo la dejaría en la
        // divisa anterior, y el gate volvería a leer el mismo array congelado y la daría por
        // convertida. Es lo que ya hace `CurrencyChangeService`, que fetchea fresco justo antes.
        loadTransactions()
        loadPlans()
        guard !didFailToLoadTransactions, !didFailToLoadPlans else {
            isShowingSaveError = true
            cancelCurrencyConversion()
            return false
        }

        // **El veredicto se vuelve a pedir ANTES de convertir, no solo en `saveAccount`.** En la
        // ventana del `await` el sync puede traer una transferencia o un gasto de grupo de esta
        // cuenta: el gate de `saveAccount` lo bloquearía, pero DESPUÉS de haber reescrito en memoria
        // historial, programados y borradores, que el siguiente guardado (o el autosave) persistiría
        // bajo la divisa vieja. Un borrador no lleva etiqueta de divisa: ese daño sería invisible.
        if case .blocked = currencyChangeVerdict {
            isShowingCurrencyChangeBlocked = true
            return false
        }

        // **Se vuelve a medir la cobertura con lo refetcheado**: en la ventana del `await` el sync
        // pudo traer un programado en una tercera divisa o un borrador de otra fecha, y convertirlo
        // sin su tasa lo sellaría con la tabla estática. Sin red no hay nada que esperar: si falta,
        // no se convierte nada, como el historial (D2).
        guard AccountCurrencyMigrationService.missingRateDates(
            rows: rowsPendingReexpression,
            extra: planRateNeeds(),
            to: pending.toCurrencyCode,
            context: context
        ).isEmpty else {
            isShowingCurrencyRatesUnavailable = true
            cancelCurrencyConversion()
            return false
        }

        // Los borradores y los programados se leen ANTES de convertir el historial: sus filtros
        // comparan contra la divisa elegida, y no cambian con él, pero así el orden no depende de eso.
        let drafts = draftsPendingReexpression
        let scheduled = scheduledPendingReexpression
        let favorites = favoritesPendingReexpression
        let source = originalCurrencyCode ?? pending.fromCurrencyCode

        AccountCurrencyMigrationService.convertHistory(
            rows: rowsPendingReexpression,
            to: pending.toCurrencyCode,
            context: context
        )
        AccountCurrencyMigrationService.convertPendingDrafts(
            drafts, from: source, to: pending.toCurrencyCode, context: context)
        reexpressedDraftIDs.formUnion(drafts.map(\.persistentModelID))
        AccountCurrencyMigrationService.convertPlans(
            scheduled: scheduled,
            favorites: favorites,
            fallbackSourceCode: source,
            to: pending.toCurrencyCode,
            context: context
        )

        return saveAccount(context: context)
    }

    /// Las fechas y divisas que piden los borradores (su fecha, en la divisa de la cuenta) y los
    /// programados y favoritos (hoy, en su divisa).
    private func planRateNeeds() -> AccountCurrencyMigrationService.RateNeeds {
        var needs = AccountCurrencyMigrationService.RateNeeds()
        let source = originalCurrencyCode ?? normalizeCurrencyCode(selectedCurrency.rawValue)
        let drafts = draftsPendingReexpression
        if !drafts.isEmpty {
            needs.currencies.insert(source)
            for draft in drafts { needs.dates.insert(draft.date ?? draft.createdAt) }
        }
        for payment in scheduledPendingReexpression {
            needs.currencies.insert(normalizeCurrencyCode(payment.currencyCode))
        }
        for favorite in favoritesPendingReexpression where favorite.amount != nil {
            needs.currencies.insert(normalizeCurrencyCode(favorite.currencyCode ?? source))
        }
        return needs
    }

    /// Descarta el cambio de divisa y deja el formulario como estaba al abrirlo.
    ///
    /// Sin esto, cancelar la confirmación dejaría el selector enseñando la divisa nueva sobre una
    /// cuenta que sigue en la vieja: el siguiente Guardar volvería a preguntar y el usuario no
    /// tendría forma de ver cuál es la divisa de verdad.
    func cancelCurrencyConversion() {
        pendingCurrencyConversion = nil
        if let original = originalCurrencyCode,
           let code = CurrencyCode(rawValue: original) {
            selectedCurrency = code
        }
    }

    /// Apply common account properties (shared between create and update paths)
    private func applyBaseAccountProperties(to account: Account, trimmedAccountNumber: String) {
        account.name = trimmedName
        account.currencyCode = normalizeCurrencyCode(selectedCurrency.rawValue)
        account.colorHex = selectedColorHex
        account.iconName = iconName(for: selectedType)
        account.type = selectedType.rawValue
        account.accountNumber = trimmedAccountNumber.isEmpty ? nil : trimmedAccountNumber
        account.adjustmentMode = selectedAdjustmentMode.rawValue
        account.excludeFromStatistics = excludeFromStatistics
        account.isArchived = isArchived
        account.creditCardPaymentReminder = selectedType == .creditCard ? creditCardPaymentReminder : false
        account.creditCardPaymentDay = selectedType == .creditCard ? creditCardPaymentDay : 1
    }

    /// Suggest adding the saved currency as secondary if it differs from preferred
    private func suggestSecondaryCurrencyIfNeeded() {
        let savedCurrency = normalizeCurrencyCode(selectedCurrency.rawValue)
        let preferred = CurrencyDefaults.currentPreferred
        guard savedCurrency != preferred, let code = CurrencyCode(rawValue: savedCurrency) else { return }
        let raw = UserDefaults.standard.string(forKey: "secondaryCurrencies") ?? ""
        let existing = raw.split(separator: ",").map(String.init)
        if existing.count < 2, !existing.contains(savedCurrency) {
            currencyToSuggestAsSecondary = code
        }
    }

    func deleteAccount(context: ModelContext) -> Bool {
        guard let account = accountToEdit else { return false }
        context.delete(account)
        return true
    }

    // MARK: - Helpers

    private func hexString(from color: Color) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var success = false

        #if canImport(UIKit)
            let uiColor = UIColor(color)
            success = uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
            let nsColor = NSColor(color)
            if let rgbColor = nsColor.usingColorSpace(.sRGB) {
                rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                success = true
            }
        #endif

        if success {
            let r = Int(red * 255)
            let g = Int(green * 255)
            let b = Int(blue * 255)
            return String(format: "#%02X%02X%02X", r, g, b)
        } else {
            return selectedColorHex
        }
    }
}
