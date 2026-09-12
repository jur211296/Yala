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
    var isArchived: Bool = false

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
    }

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

    init(accountToEdit: Account?, existingNames: [String], allTransactions: [TransactionItem] = [])
    {
        self.accountToEdit = accountToEdit
        self.existingNames = existingNames
        self.allTransactions = allTransactions
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
        initializeBalanceIfNeeded()
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
        guard !didFailToLoadTransactions else {
            isShowingCurrencyChangeBlocked = true
            return false
        }

        switch currencyChangeVerdict {
        case .free:
            // Sin movimientos no hay histórico que desemparejar: la divisa se cambia y ya está.
            return true

        case .blocked:
            isShowingCurrencyChangeBlocked = true
            return false

        case .needsConversion:
            let pending = rowsPendingReexpression
            guard !pending.isEmpty else { return true }
            // **El importe tecleado en la sección de saldo se descarta al pedir la conversión.**
            // `balanceText` está en la divisa VIEJA —lo escribió el usuario, o lo plantó
            // `adjustmentModeChanged` desde `existingInitialBalance`— mientras que `currentBalance` y
            // `existingInitialBalance` pasan a leer los importes ya convertidos. Dejarlo puesto hace
            // que `needsAdjustment` compare 1.000 (soles) contra 266,67 (dólares) y meta un ajuste de
            // saldo de +733 que el usuario nunca vio en pantalla, o que `setInitialBalance` reescriba
            // el saldo inicial multiplicado por el tipo de cambio. La sección va deshabilitada en la
            // vista mientras hay cambio de divisa pendiente; esto es la mitad que no depende de la UI.
            balanceText = ""
            pendingCurrencyConversion = PendingCurrencyConversion(
                rowCount: pending.count,
                fromCurrencyCode: originalCurrencyCode ?? "",
                toCurrencyCode: normalizeCurrencyCode(selectedCurrency.rawValue)
            )
            return false
        }
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
        guard !didFailToLoadTransactions else {
            isShowingSaveError = true
            cancelCurrencyConversion()
            return false
        }

        AccountCurrencyMigrationService.convertHistory(
            rows: rowsPendingReexpression,
            to: pending.toCurrencyCode,
            context: context
        )

        return saveAccount(context: context)
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
