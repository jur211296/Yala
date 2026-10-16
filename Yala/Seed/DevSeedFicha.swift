//
//  DevSeedFicha.swift
//  Yala
//
//  Perfil `ficha` (`-uitest-seed ficha`): una sola persona para todas las capturas y el vídeo de la ficha de la App
//  Store, en el idioma y la divisa de la app. Lo usa el molde de `ficha-app-store/`, que lanza la app con el idioma, la
//  región y la divisa de cada ficha (`-defaultCurrencyCode`) y con el reloj en el 13-oct-2026: ese día la vida personal
//  de `realista` da las cifras que citan los textos de las capturas (4,686 del mes, 470 que quedan en Comer fuera,
//  «19 días», Teléfono en 2 días y Spotify en 5).
//
//  Encima de `realista`, que sigue escribiendo en soles:
//  - la vida personal pasa a la divisa principal (mismas cifras, como `relabelPersonalDataToMXN` con factor 1);
//  - la cuenta de ahorros en dólares pasa a ser la cuenta en divisa extranjera de la ficha, con su saldo exacto, y lo
//    que deja de valer en la divisa principal lo recupera la cuenta principal en la misma fecha: el total de «Tus
//    finanzas» y su tendencia quedan como en la ficha en soles (con la cuenta extranjera pequeña salía negativo);
//  - Teléfono y Spotify cuestan lo que dice la ficha de esa divisa;
//  - dos cuentas más en la divisa principal, efectivo y tarjeta de crédito, para la captura de «Tus cuentas» (sus
//    chips dicen efectivo, tarjeta y ahorro);
//  - los grupos los siembra `DevSeedGroups.createFicha`.
//  Los textos van por L10n (`L10n.DevSeed.Ficha`); lo que cambia por divisa, en `Cifras`.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedFicha {

    /// Lo que cambia con la divisa principal. Una divisa nueva (EUR para de/fr/it, JPY para ja) es una fila más en
    /// `cifras(forMainCurrency:)`; sin fila, sale la de soles con las cifras sin escalar.
    struct Cifras: Equatable {
        /// Multiplica los gastos del viaje en la divisa principal: en reales, 240/360 y te deben 380.
        let groupFactor: Double
        /// Divisa de la otra mitad de los gastos del viaje (en Lisboa, euros). Nil: el viaje entero en la principal.
        let groupSecondaryCurrency: String?
        /// La cuenta en divisa extranjera y su saldo exacto (todo el historial).
        let foreignCurrency: String
        let foreignBalance: Double
        /// Importe mensual de Teléfono y de Spotify en la divisa principal.
        let phone: Double
        let spotify: Double
        /// Saldo de la cuenta de efectivo y deuda de la tarjeta de crédito (negativa: «a pagar»), en la principal.
        let cash: Double
        let cardDebt: Double
        /// El importe de «Pizza con amigos» que escribe el vídeo y contesta Yala IA (`-uitest-chat-reply pizza`).
        let pizza: Double
    }

    static func cifras(forMainCurrency code: String) -> Cifras {
        switch code {
        case "USD":
            return Cifras(groupFactor: 1, groupSecondaryCurrency: "EUR", foreignCurrency: "EUR",
                          foreignBalance: 1_850, phone: 65, spotify: 11.99,
                          cash: 140, cardDebt: -612.40, pizza: 28)
        case "BRL":
            return Cifras(groupFactor: 2, groupSecondaryCurrency: nil, foreignCurrency: "USD",
                          foreignBalance: 3_615, phone: 59.90, spotify: 21.90,
                          cash: 320, cardDebt: -1_480.90, pizza: 90)
        default:
            return Cifras(groupFactor: 1, groupSecondaryCurrency: "USD", foreignCurrency: "USD",
                          foreignBalance: 33_615, phone: 60, spotify: 18,
                          cash: 380, cardDebt: -1_284.30, pizza: 280)
        }
    }

    /// Divisa en la que escribe el generador de `realista`.
    static let seedCurrency = "PEN"

    /// Unidades de `to` por unidad de `from`, con la tabla de respaldo (por dólar). Solo para la semilla.
    static func rate(from: String, to: String) -> Double {
        let perUSD = CurrencyCode.fallbackRates
        guard let fromPerUSD = perUSD[from], let toPerUSD = perUSD[to], fromPerUSD > 0 else { return 1 }
        return toPerUSD / fromPerUSD
    }

    // MARK: - Vida personal

    /// Pasa la vida personal de `realista` a la ficha de `mainCurrency`. Corre después del generador y antes de los
    /// grupos.
    @MainActor
    static func adaptPersonalData(in context: ModelContext, mainCurrency main: String) {
        let cifras = cifras(forMainCurrency: main)
        do {
            try context.save()
            if main != seedCurrency {
                try relabelSeedCurrency(to: main, in: context)
            }
            try retargetForeignAccount(cifras, mainCurrency: main, in: context)
            try repriceScheduledPayments(cifras, in: context)
            try addEverydayAccounts(cifras, mainCurrency: main, in: context)
            try context.save()
        } catch {
            print("DevSeedFicha: Error adapting personal data to \(main): \(error)")
        }
    }

    /// Los soles del generador pasan a `main` con las mismas cifras: cuentas, registros, presupuestos, pagos
    /// planificados, borradores y la fila de tipos de cambio (si `main` no está, se deriva de la de soles).
    @MainActor
    private static func relabelSeedCurrency(to main: String, in context: ModelContext) throws {
        let pen = seedCurrency
        for account in try context.fetch(FetchDescriptor<Account>()) where account.currencyCode == pen {
            account.currencyCode = main
        }
        for tx in try context.fetch(FetchDescriptor<TransactionItem>()) {
            if tx.currencyCode == pen { tx.currencyCode = main }
            if tx.preferredCurrencyCode == pen { tx.preferredCurrencyCode = main }
        }
        for budget in try context.fetch(FetchDescriptor<Budget>()) where budget.currencyCode == pen {
            budget.currencyCode = main
        }
        for payment in try context.fetch(FetchDescriptor<ScheduledPayment>()) where payment.currencyCode == pen {
            payment.currencyCode = main
        }
        for draft in try context.fetch(FetchDescriptor<InboxDraft>()) where draft.cachedCurrencyCode == pen {
            draft.cachedCurrencyCode = main
        }
        // La fila es por dólar. El dólar es la base y ya está; otra divisa sigue el paseo aleatorio del sol.
        let penPerMain = rate(from: main, to: pen)
        for entry in try context.fetch(FetchDescriptor<ExchangeRate>()) {
            var rates = entry.decodedRates()
            guard rates[main] == nil, let penRate = rates[pen], penPerMain > 0 else { continue }
            rates[main] = (penRate / penPerMain * 10_000).rounded() / 10_000
            entry.rates = try DevSeedExchangeRates.encodeScale8StringFaceBlob(rates)
        }
    }

    /// La cuenta de ahorros en dólares del generador pasa a ser la cuenta en divisa extranjera de la ficha: otro nombre
    /// («Travel EUR»), otra divisa y su historia reescalada para que el saldo sea exactamente el de la ficha. Si ya lo
    /// es y la divisa no cambia (la ficha en soles), no se toca nada.
    ///
    /// **El total de cada día no cambia.** En soles, esa cuenta valía 33,615 × 3,7 y sostenía el total de «Tus finanzas»
    /// y su tendencia, que sube; en una ficha con la cuenta extranjera pequeña el total salía negativo y bajando. Así
    /// que todo lo que la cuenta deja de valer en la divisa principal pasa a la principal en la misma fecha: los
    /// ingresos freelance se mudan a la principal con su valor, la pata de cada transferencia en la principal pasa a
    /// valer lo que llega al otro lado, y el saldo inicial compensa el suyo.
    @MainActor
    private static func retargetForeignAccount(_ cifras: Cifras, mainCurrency main: String, in context: ModelContext) throws {
        let savingsName = L10n.DevSeed.accountSavings
        let accounts = try context.fetch(FetchDescriptor<Account>())
        guard let account = accounts.first(where: { $0.name == savingsName }),
              let mainAccount = accounts.first(where: { $0.name == L10n.DevSeed.accountMain })
        else {
            print("DevSeedFicha: Error: faltan las cuentas «\(savingsName)» o «\(L10n.DevSeed.accountMain)» del generador")
            return
        }
        let foreign = cifras.foreignCurrency
        let newName = L10n.DevSeed.Ficha.accountForeign(foreign)
        let transactions = account.transactions ?? []
        let balance = transactions.reduce(0) { $0 + $1.amount }
        if account.currencyCode == foreign, abs(balance - cifras.foreignBalance) < 0.005 {
            account.name = newName
            try renameTransferNotes(from: savingsName, to: newName, in: context)
            return
        }

        let isTransfer: (TransactionItem) -> Bool = { $0.transferPairID != nil }
        let isInitial: (TransactionItem) -> Bool = { $0.balanceAdjustmentType == InitialBalanceService.typeInitialBalance }
        // 1 · Los ingresos de la cuenta (freelance) se mudan a la principal con el valor que tenían en la principal.
        for tx in transactions where !isTransfer(tx) && !isInitial(tx) {
            tx.account = mainAccount
            tx.currencyCode = main
            tx.amount = tx.amountInPreferredCurrency
            tx.exchangeRate = 1
            tx.preferredCurrencyCode = main
        }
        // 2 · Lo que queda (saldo inicial y transferencias) se reescala hasta el saldo de la ficha.
        let kept = transactions.filter { isTransfer($0) || isInitial($0) }
        let keptBalance = kept.reduce(0) { $0 + $1.amount }
        guard abs(keptBalance) > 0.005 else { return }
        let factor = cifras.foreignBalance / keptBalance
        let mainPerForeign = rate(from: foreign, to: main)
        var worthBefore: [ObjectIdentifier: Double] = [:]
        var total = 0.0
        for tx in kept {
            worthBefore[ObjectIdentifier(tx)] = tx.amountInPreferredCurrency
            tx.amount = (tx.amount * factor * 100).rounded() / 100
            tx.currencyCode = foreign
            tx.exchangeRate = mainPerForeign
            tx.preferredCurrencyCode = main
            total += tx.amount
        }
        // El redondeo a céntimos deja un resto: lo absorbe el saldo inicial, para que el saldo sea el de la ficha.
        let rest = ((cifras.foreignBalance - total) * 100).rounded() / 100
        if rest != 0, let initial = kept.first(where: isInitial) {
            initial.amount = ((initial.amount + rest) * 100).rounded() / 100
        }
        // La tasa es la de la propia semilla, como la del generador: definitiva por construcción. Se dice en voz alta
        // (`isExchangeRateProvisional`) en cada escritura del convertido, que es lo que vigila `ManualWriteRateQualityTests`.
        for tx in kept {
            tx.amountInPreferredCurrency = (tx.amount * mainPerForeign * 100).rounded() / 100
            tx.isExchangeRateProvisional = false
        }
        // 3 · La principal recupera, en la misma fecha, lo que la extranjera dejó de valer.
        let mainTransactions = mainAccount.transactions ?? []
        for tx in kept {
            let lost = (worthBefore[ObjectIdentifier(tx)] ?? 0) - tx.amountInPreferredCurrency
            if let pairID = tx.transferPairID {
                // La pata que sale de la principal vale lo que llega: la transferencia queda neutra.
                guard let leg = mainTransactions.first(where: { $0.transferPairID == pairID }) else { continue }
                leg.amount = ((leg.amount + lost) * 100).rounded() / 100
                leg.amountInPreferredCurrency = leg.amount
                leg.isExchangeRateProvisional = false
            } else if let mainInitial = mainTransactions.first(where: isInitial) {
                mainInitial.amount = ((mainInitial.amount + lost) * 100).rounded() / 100
                mainInitial.amountInPreferredCurrency = mainInitial.amount
                mainInitial.isExchangeRateProvisional = false
            }
        }
        account.currencyCode = foreign
        account.name = newName
        try renameTransferNotes(from: savingsName, to: newName, in: context)
    }

    /// «Transferencia a Ahorros USD» pasa a «Transfer to Travel EUR»: la nota la escribió el generador con el nombre viejo.
    @MainActor
    private static func renameTransferNotes(from oldName: String, to newName: String, in context: ModelContext) throws {
        guard oldName != newName else { return }
        let oldNote = L10n.DevSeed.noteTransferTo(oldName)
        let newNote = L10n.DevSeed.noteTransferTo(newName)
        for tx in try context.fetch(FetchDescriptor<TransactionItem>()) where tx.note == oldNote {
            tx.note = newNote
        }
    }

    /// Efectivo y tarjeta de crédito en la divisa principal, cada una con su saldo inicial en la fecha del de la cuenta
    /// principal: la curva del Saldo se desplaza entera y no salta ningún día. Sus nombres son los del tipo de cuenta
    /// en el idioma de la app («Cash», «Dinheiro»), que es lo que dicen los chips de la captura. Si ya están, no se
    /// vuelven a crear.
    @MainActor
    private static func addEverydayAccounts(_ cifras: Cifras, mainCurrency main: String, in context: ModelContext) throws {
        let accounts = try context.fetch(FetchDescriptor<Account>())
        guard let mainAccount = accounts.first(where: { $0.name == L10n.DevSeed.accountMain }),
              let mainInitial = (mainAccount.transactions ?? []).first(where: {
                  $0.balanceAdjustmentType == InitialBalanceService.typeInitialBalance
              })
        else {
            print("DevSeedFicha: Error: falta la cuenta «\(L10n.DevSeed.accountMain)» o su saldo inicial")
            return
        }
        let nuevas: [(name: String, type: AccountType, icon: String, color: String, balance: Double)] = [
            (L10n.Account.AccountType.cash, .cash, "banknote.fill", "#10B981", cifras.cash),
            (L10n.Account.AccountType.creditCard, .creditCard, "creditcard.fill", "#F59E0B", cifras.cardDebt),
        ]
        for nueva in nuevas where !accounts.contains(where: { $0.name == nueva.name }) {
            let account = Account(name: nueva.name, currencyCode: main, colorHex: nueva.color,
                                  iconName: nueva.icon, type: nueva.type.rawValue)
            context.insert(account)
            let initial = TransactionItem(
                date: mainInitial.date, amount: nueva.balance, currencyCode: main, note: mainInitial.note,
                category: mainInitial.category, subcategory: mainInitial.subcategory, account: account,
                exchangeRate: 1, amountInPreferredCurrency: nueva.balance, preferredCurrencyCode: main
            )
            initial.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
            initial.createdAt = mainInitial.createdAt
            initial.isExchangeRateProvisional = false
            context.insert(initial)
        }
    }

    /// Teléfono y Spotify cuestan lo de la ficha, y sus cargos pasados también, para que el historial cuadre con el pago.
    @MainActor
    private static func repriceScheduledPayments(_ cifras: Cifras, in context: ModelContext) throws {
        let prices = [L10n.DevSeed.spPhone: cifras.phone, "Spotify": cifras.spotify]
        let payments = try context.fetch(FetchDescriptor<ScheduledPayment>())
        let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
        for payment in payments {
            guard let price = prices[payment.name] else { continue }
            payment.amount = price
            let paymentID = payment.id.uuidString
            for tx in transactions where tx.scheduledPaymentID == paymentID {
                tx.amount = -price
                tx.amountInPreferredCurrency = -price
                tx.isExchangeRateProvisional = false
            }
        }
    }
}
#endif
