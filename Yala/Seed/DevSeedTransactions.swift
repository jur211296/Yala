//
//  DevSeedTransactions.swift
//  Yala
//
//  Creates ~4500 transactions over 2 years for dev seed data.
//

#if DEBUG
import Foundation
import SwiftData

struct DevSeedTransactions {

    /// Base PEN/USD rate — shared with DevSeedExchangeRates starting value
    static let basePenRate = 3.70

    @MainActor
    static func create(
        startDate: Date,
        endDate: Date,
        accounts: DevSeedAccounts.Result,
        tags: [Tag],
        scheduledPayments: [ScheduledPayment],
        subcategoryLookup: [String: Subcategory],
        rng: inout SeededRandom,
        progressUpdate: @escaping (Double) -> Void,
        in context: ModelContext
    ) async {
        let calendar = Calendar.current
        let principal = accounts.cuentaPrincipal
        let ahorros = accounts.ahorrosUSD

        // Build scheduled payment lookup by name
        var spByName: [String: ScheduledPayment] = [:]
        for sp in scheduledPayments {
            spByName[sp.name] = sp
        }

        // Total estimated days for progress
        let totalDays = max(1, calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 730)
        var dayIndex = 0
        var insertCount = 0

        // Helper to create and insert a transaction
        func insert(
            date: Date,
            amount: Double,
            currency: String,
            note: String?,
            sub: Subcategory?,
            account: Account,
            tagList: [Tag]? = nil,
            scheduledPaymentID: String? = nil,
            balanceAdjustmentType: String? = nil,
            transferPairID: String? = nil,
            createdAtOffset: Int = 0
        ) {
            let rate: Double
            let amountInPEN: Double
            if currency == "PEN" {
                rate = 1.0
                amountInPEN = amount
            } else {
                rate = basePenRate
                amountInPEN = amount * rate
            }

            let tx = TransactionItem(
                date: date,
                amount: amount,
                currencyCode: currency,
                note: note,
                category: sub?.category,
                subcategory: sub,
                account: account,
                tags: tagList ?? [],
                exchangeRate: currency == "PEN" ? 1.0 : rate,
                amountInPreferredCurrency: amountInPEN,
                preferredCurrencyCode: "PEN"
            )
            tx.scheduledPaymentID = scheduledPaymentID
            tx.balanceAdjustmentType = balanceAdjustmentType
            tx.transferPairID = transferPairID
            // Offset createdAt slightly for ordering within same day
            tx.createdAt = date.addingTimeInterval(Double(createdAtOffset))

            context.insert(tx)
            insertCount += 1

            // Batch save every 200 inserts
            if insertCount % 200 == 0 {
                do { try context.save() } catch {
                    print("DevSeedTransactions: Batch save error: \(error)")
                }
            }
        }

        func assignTags(_ rng: inout SeededRandom) -> [Tag]? {
            var result: [Tag] = []
            if rng.chance(0.10) { result.append(tags[0]) } // Trabajo
            if rng.chance(0.03) { result.append(tags[1]) } // Vacaciones
            if rng.chance(0.08) { result.append(tags[2]) } // Compartido
            if rng.chance(0.02) { result.append(tags[3]) } // Urgente
            if rng.chance(0.05) { result.append(tags[4]) } // Fijo
            return result.isEmpty ? nil : result
        }

        // Pre-compute localized note arrays (avoid repeated L10n lookups inside 730-day loop)
        let supermarketNotes = [L10n.DevSeed.noteSupermarket1, L10n.DevSeed.noteSupermarket2, L10n.DevSeed.noteSupermarket3, L10n.DevSeed.noteSupermarket4, L10n.DevSeed.noteSupermarket5]
        let restaurantNotes = [L10n.DevSeed.noteLunch, L10n.DevSeed.noteDinner, L10n.DevSeed.noteBrunch, L10n.DevSeed.noteMealWithFriends]
        let deliveryNotes = [L10n.DevSeed.noteDelivery1, L10n.DevSeed.noteDelivery2, L10n.DevSeed.noteDeliveryFood]
        let rideshareNotes = ["Uber", "Bolt", L10n.DevSeed.noteTaxi]
        let busNote = L10n.DevSeed.noteBus
        let travelNotes = [L10n.DevSeed.noteHotel, L10n.DevSeed.noteFlight, L10n.DevSeed.noteTour, L10n.DevSeed.noteExcursion]
        let fuelNotes = [L10n.DevSeed.noteGasStation, L10n.DevSeed.noteGasoline, L10n.DevSeed.noteFuel]
        let maintenanceNotes = [L10n.DevSeed.noteRepair, L10n.DevSeed.noteCleaning, L10n.DevSeed.notePlumber, L10n.DevSeed.noteElectrician]
        let freelanceNotes = [L10n.DevSeed.noteFreelance, L10n.DevSeed.noteConsulting, L10n.DevSeed.noteSideProject]
        let utilityNotes = [L10n.DevSeed.noteElectricity, L10n.DevSeed.noteWater, L10n.DevSeed.noteElectricityWater]
        let transferToSavings = L10n.DevSeed.noteTransferTo(L10n.DevSeed.accountSavings)
        let transferFromMain = L10n.DevSeed.noteTransferFrom(L10n.DevSeed.accountMain)

        // Iterate day by day
        var currentDate = startDate
        while currentDate <= endDate {
            let comps = calendar.dateComponents([.year, .month, .day, .weekday], from: currentDate)
            let day = comps.day!
            let month = comps.month!
            let weekday = comps.weekday! // 1=Sun, 7=Sat
            let isWeekend = weekday == 1 || weekday == 7
            var orderInDay = 0

            // Seasonal multiplier
            let entertainmentMultiplier: Double
            if month == 12 || month == 1 { entertainmentMultiplier = 1.5 }
            else if month >= 6 && month <= 8 { entertainmentMultiplier = 0.7 }
            else { entertainmentMultiplier = 1.0 }

            // --- Monthly fixed transactions (on specific days) ---
            // Days match DevSeedScheduledPayments definitions

            if day == 1 {
                // Salary
                insert(
                    date: currentDate, amount: 8500, currency: "PEN",
                    note: L10n.DevSeed.noteSalary,
                    sub: subcategoryLookup[L10n.Subcategory.salary],
                    account: principal,
                    tagList: [tags[0]], // Trabajo
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            if day == 3 {
                // Gym (day 3)
                insert(
                    date: currentDate, amount: -150, currency: "PEN",
                    note: L10n.DevSeed.noteGymMonthly,
                    sub: subcategoryLookup[L10n.Subcategory.fitness],
                    account: principal,
                    scheduledPaymentID: spByName[L10n.DevSeed.spGym]?.id.uuidString,
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            if day == 5 {
                // Rent (day 5)
                insert(
                    date: currentDate, amount: -2200, currency: "PEN",
                    note: L10n.DevSeed.noteRent,
                    sub: subcategoryLookup[L10n.Subcategory.rent],
                    account: principal,
                    tagList: [tags[4]], // Fijo
                    scheduledPaymentID: spByName[L10n.DevSeed.spRent]?.id.uuidString,
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            if day == 15 {
                // Phone (day 15)
                insert(
                    date: currentDate, amount: -60, currency: "PEN",
                    note: L10n.DevSeed.notePhonePlan,
                    sub: subcategoryLookup[L10n.Subcategory.phone],
                    account: principal,
                    tagList: [tags[4]], // Fijo
                    scheduledPaymentID: spByName[L10n.DevSeed.spPhone]?.id.uuidString,
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            if day == 18 {
                // Spotify (day 18)
                insert(
                    date: currentDate, amount: -18, currency: "PEN",
                    note: "Spotify",
                    sub: subcategoryLookup[L10n.Subcategory.streaming],
                    account: principal,
                    scheduledPaymentID: spByName["Spotify"]?.id.uuidString,
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            if day == 20 {
                // Netflix (day 20)
                insert(
                    date: currentDate, amount: -45, currency: "PEN",
                    note: "Netflix",
                    sub: subcategoryLookup[L10n.Subcategory.streaming],
                    account: principal,
                    scheduledPaymentID: spByName["Netflix"]?.id.uuidString,
                    createdAtOffset: orderInDay
                )
                orderInDay += 1

                // Utilities (luz/agua) (day 20)
                let utilAmount = rng.nextDouble(in: 80...200)
                insert(
                    date: currentDate, amount: -utilAmount.rounded(), currency: "PEN",
                    note: rng.pick(from: utilityNotes),
                    sub: subcategoryLookup[L10n.Subcategory.utilities],
                    account: principal,
                    tagList: [tags[4]], // Fijo
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            if day == 22 {
                // iCloud+ (day 22)
                insert(
                    date: currentDate, amount: -10, currency: "PEN",
                    note: "iCloud+",
                    sub: subcategoryLookup[L10n.Subcategory.utilitySubs],
                    account: principal,
                    scheduledPaymentID: spByName["iCloud+"]?.id.uuidString,
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            if day == 25 {
                // Internet (day 25)
                insert(
                    date: currentDate, amount: -90, currency: "PEN",
                    note: L10n.DevSeed.noteInternetFiber,
                    sub: subcategoryLookup[L10n.Subcategory.utilities],
                    account: principal,
                    tagList: [tags[4]], // Fijo
                    scheduledPaymentID: spByName[L10n.DevSeed.spInternet]?.id.uuidString,
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            if day == 28 {
                // Insurance (day 28)
                insert(
                    date: currentDate, amount: -180, currency: "PEN",
                    note: L10n.DevSeed.noteInsuranceMonthly,
                    sub: subcategoryLookup[L10n.Subcategory.insurance],
                    account: principal,
                    tagList: [tags[4]], // Fijo
                    scheduledPaymentID: spByName[L10n.DevSeed.spInsurance]?.id.uuidString,
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // --- Weekly variable transactions ---

            // Supermarket: 2-3x/week (spread across weekdays)
            let supermarketDays = [1, 3, 6] // Mon-ish, Wed-ish, Sat-ish
            if supermarketDays.contains(weekday) || (weekday == 4 && rng.chance(0.4)) {
                let amount = rng.nextDouble(in: 50...200).rounded()
                insert(
                    date: currentDate, amount: -amount, currency: "PEN",
                    note: rng.pick(from: supermarketNotes),
                    sub: subcategoryLookup[L10n.Subcategory.supermarkets],
                    account: principal,
                    tagList: assignTags(&rng),
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // Restaurants: 1-2x/week (weekend bias)
            if (isWeekend && rng.chance(0.65)) || (!isWeekend && rng.chance(0.15)) {
                let amount = rng.nextDouble(in: 30...120).rounded()
                insert(
                    date: currentDate, amount: -amount, currency: "PEN",
                    note: rng.pick(from: restaurantNotes),
                    sub: subcategoryLookup[L10n.Subcategory.restaurants],
                    account: principal,
                    tagList: assignTags(&rng),
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // Delivery: 1-2x/week
            if rng.chance(0.22) {
                let amount = rng.nextDouble(in: 20...60).rounded()
                insert(
                    date: currentDate, amount: -amount, currency: "PEN",
                    note: rng.pick(from: deliveryNotes),
                    sub: subcategoryLookup[L10n.Subcategory.delivery],
                    account: principal,
                    tagList: assignTags(&rng),
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // Transport: 5-6x/week (not Sunday usually)
            if weekday != 1 || rng.chance(0.3) {
                let amount = rng.nextDouble(in: 5...30).rounded()
                let isRideshare = rng.chance(0.4)
                insert(
                    date: currentDate, amount: -amount, currency: "PEN",
                    note: isRideshare ? rng.pick(from: rideshareNotes) : busNote,
                    sub: subcategoryLookup[isRideshare ? L10n.Subcategory.rideshare : L10n.Subcategory.publicTransport],
                    account: principal,
                    tagList: assignTags(&rng),
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // Entertainment: 1-2x/week (weekend bias, seasonal)
            let entChance = (isWeekend ? 0.5 : 0.1) * entertainmentMultiplier
            if rng.chance(entChance) {
                let amount = rng.nextDouble(in: 20...150).rounded()
                let subKeys = [
                    L10n.Subcategory.bars, L10n.Subcategory.sports,
                    L10n.Subcategory.shows, L10n.Subcategory.hobbies,
                ]
                insert(
                    date: currentDate, amount: -amount, currency: "PEN",
                    note: nil,
                    sub: subcategoryLookup[rng.pick(from: subKeys)],
                    account: principal,
                    tagList: assignTags(&rng),
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // Travel (Dec-Jan summer season)
            if (month == 12 || month == 1) && isWeekend && rng.chance(0.15) {
                let amount = rng.nextDouble(in: 100...500).rounded()
                insert(
                    date: currentDate, amount: -amount, currency: "PEN",
                    note: rng.pick(from: travelNotes),
                    sub: subcategoryLookup[L10n.Subcategory.travel],
                    account: principal,
                    tagList: [tags[1]], // Vacaciones
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // Shopping: 1-2x/week
            if rng.chance(0.2) {
                let amount = rng.nextDouble(in: 20...200).rounded()
                let subKeys = [
                    L10n.Subcategory.clothing, L10n.Subcategory.tech,
                    L10n.Subcategory.personalCare, L10n.Subcategory.gifts,
                    L10n.Subcategory.otherShopping,
                ]
                insert(
                    date: currentDate, amount: -amount, currency: "PEN",
                    note: nil,
                    sub: subcategoryLookup[rng.pick(from: subKeys)],
                    account: principal,
                    tagList: assignTags(&rng),
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // --- Monthly sporadic ---

            // Personal (health/beauty/education): 1-3x/month
            if rng.chance(0.07) {
                let amount = rng.nextDouble(in: 30...300).rounded()
                let subKeys = [
                    L10n.Subcategory.health, L10n.Subcategory.beauty,
                    L10n.Subcategory.education,
                ]
                insert(
                    date: currentDate, amount: -amount, currency: "PEN",
                    note: nil,
                    sub: subcategoryLookup[rng.pick(from: subKeys)],
                    account: principal,
                    tagList: assignTags(&rng),
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // Pets: 2-4x/month
            if rng.chance(0.1) {
                let amount = rng.nextDouble(in: 20...150).rounded()
                let subKeys = [
                    L10n.Subcategory.petFood, L10n.Subcategory.vet,
                    L10n.Subcategory.petServices, L10n.Subcategory.petAccessories,
                ]
                insert(
                    date: currentDate, amount: -amount, currency: "PEN",
                    note: nil,
                    sub: subcategoryLookup[rng.pick(from: subKeys)],
                    account: principal,
                    tagList: assignTags(&rng),
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // Vehicle fuel: 4-6x/month
            if rng.chance(0.17) {
                let amount = rng.nextDouble(in: 50...120).rounded()
                insert(
                    date: currentDate, amount: -amount, currency: "PEN",
                    note: rng.pick(from: fuelNotes),
                    sub: subcategoryLookup[L10n.Subcategory.fuel],
                    account: principal,
                    tagList: assignTags(&rng),
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // Housing maintenance: 0-1x/month
            if rng.chance(0.03) {
                let amount = rng.nextDouble(in: 50...300).rounded()
                insert(
                    date: currentDate, amount: -amount, currency: "PEN",
                    note: rng.pick(from: maintenanceNotes),
                    sub: subcategoryLookup[L10n.Subcategory.maintenance],
                    account: principal,
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // Freelance income (USD account): 1-2x/month
            if rng.chance(0.05) {
                let amount = rng.nextDouble(in: 200...800).rounded()
                insert(
                    date: currentDate, amount: amount, currency: "USD",
                    note: rng.pick(from: freelanceNotes),
                    sub: subcategoryLookup[L10n.Subcategory.freelance],
                    account: ahorros,
                    tagList: [tags[0]], // Trabajo
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // Transfers (~2/month): PEN out → USD in
            if day == 10 || day == 25 {
                let penAmount = rng.nextDouble(in: 500...1000).rounded()
                let usdAmount = (penAmount / basePenRate).rounded()
                let pairID = UUID().uuidString

                // Outflow (PEN)
                insert(
                    date: currentDate, amount: -penAmount, currency: "PEN",
                    note: transferToSavings,
                    sub: subcategoryLookup[L10n.Subcategory.accountTransferOther],
                    account: principal,
                    balanceAdjustmentType: TransactionType.transfer.rawValue,
                    transferPairID: pairID,
                    createdAtOffset: orderInDay
                )
                orderInDay += 1

                // Inflow (USD)
                insert(
                    date: currentDate, amount: usdAmount, currency: "USD",
                    note: transferFromMain,
                    sub: subcategoryLookup[L10n.Subcategory.accountTransfer],
                    account: ahorros,
                    balanceAdjustmentType: TransactionType.transfer.rawValue,
                    transferPairID: pairID,
                    createdAtOffset: orderInDay
                )
                orderInDay += 1
            }

            // --- Progress update ---
            dayIndex += 1
            if dayIndex % 15 == 0 {
                let progress = Double(dayIndex) / Double(totalDays)
                progressUpdate(progress)
                await Task.yield()
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        // Final save
        do { try context.save() } catch {
            print("DevSeedTransactions: Final save error: \(error)")
        }
    }

    // MARK: - Initial Balances

    @MainActor
    static func createInitialBalances(
        startDate: Date,
        accounts: DevSeedAccounts.Result,
        subcategoryLookup: [String: Subcategory],
        in context: ModelContext
    ) {
        guard let balanceSub = subcategoryLookup[L10n.Subcategory.balanceAdjustment] else {
            print("DevSeedTransactions: Balance adjustment subcategory not found")
            return
        }

        // Cuenta Principal: S/5,000 initial balance
        let penTx = TransactionItem(
            date: startDate,
            amount: 5000,
            currencyCode: "PEN",
            note: L10n.Account.initialBalanceNote,
            category: balanceSub.category,
            subcategory: balanceSub,
            account: accounts.cuentaPrincipal,
            exchangeRate: 1.0,
            amountInPreferredCurrency: 5000,
            preferredCurrencyCode: "PEN"
        )
        penTx.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        penTx.createdAt = startDate
        context.insert(penTx)

        // Ahorros USD: $2,000 initial balance
        let usdTx = TransactionItem(
            date: startDate,
            amount: 2000,
            currencyCode: "USD",
            note: L10n.Account.initialBalanceNote,
            category: balanceSub.category,
            subcategory: balanceSub,
            account: accounts.ahorrosUSD,
            exchangeRate: basePenRate,
            amountInPreferredCurrency: 2000 * basePenRate,
            preferredCurrencyCode: "PEN"
        )
        usdTx.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        usdTx.createdAt = startDate
        context.insert(usdTx)
    }

    // MARK: - Desync Fixtures (XCUI clasificación income/expense por categoría)

    /// Set MÍNIMO y determinista para `IncomeExpenseClassificationUITests`: 4 TX en
    /// `Date.now` (cae en cualquier período por defecto — hoy/semana/mes/año) donde DOS
    /// tienen el signo del monto CONTRARIO a su categoría (income con monto negativo,
    /// expense con monto positivo). La regla canónica (`TransactionClassificationLogic.isIncome`)
    /// clasifica por CATEGORÍA, no por signo, con acumulación signed (un monto de signo
    /// contrario reduce el bucket). Valores elegidos para que el bucket CORRECTO (fix) y
    /// el INCORRECTO (bug por-signo) den totales DISTINTOS y sin colisión de dígitos:
    ///   fix (por categoría):   Ingresos = 600 − 100 = 500 · Gastos = 500 − 200 = 300
    ///   bug (por signo):       Ingresos = 600 + 200 = 800 · Gastos = 100 + 500 = 600
    /// Moneda = la de display (`currencyCode`) con `amountInPreferredCurrency = amount`
    /// (sin FX): así income/expense usan el valor signed CRUDO en ambas superficies —
    /// Registros (usa `amountInPreferredCurrency` directo) e Insights (vía CashFlowCalculator,
    /// que usa el crudo sólo si `preferredCurrencyCode == currencyCode` de display).
    @MainActor
    static func createDesyncFixtures(
        account: Account,
        subcategoryLookup: [String: Subcategory],
        currencyCode: String,
        in context: ModelContext
    ) {
        let now = Date.now
        let salary = subcategoryLookup[L10n.Subcategory.salary]           // categoría income
        let restaurants = subcategoryLookup[L10n.Subcategory.restaurants] // categoría expense

        func insert(amount: Double, sub: Subcategory?) {
            let tx = TransactionItem(
                date: now,
                amount: amount,
                currencyCode: currencyCode,
                note: nil,
                category: sub?.category,
                subcategory: sub,
                account: account,
                exchangeRate: 1.0,
                amountInPreferredCurrency: amount,
                preferredCurrencyCode: currencyCode
            )
            tx.createdAt = now
            context.insert(tx)
        }

        insert(amount: 600, sub: salary)        // income normal (categoría income, monto +)
        insert(amount: -100, sub: salary)       // DESYNC: categoría income, monto NEGATIVO
        insert(amount: -500, sub: restaurants)  // gasto normal (categoría expense, monto −)
        insert(amount: 200, sub: restaurants)   // DESYNC: categoría expense, monto POSITIVO

        do { try context.save() } catch {
            print("DevSeedTransactions: Desync fixtures save error: \(error)")
        }
    }

    // MARK: - Dead-pointer fixture (AC-c fantasma)

    /// Constantes que Mini y los unit tests comparten. La nota viaja al
    /// `accessibilityLabel` de `record_row` (`note, amount, …`).
    enum DeadPointerUITestSeed {
        static let profile = "dead-pointer"
        static let note = "Dead group pointer"
        static let unresolvedExpenseIDString = "DEAD0000-0000-4000-8000-000000000001"
        static let amount: Double = -42
    }

    /// Planta el estado que `NewTransactionView.resolveBridgedPointer` trata como puntero
    /// MUERTO: `bridgedPointerResolves = found || !isFresh` sale `false`.
    ///
    /// **Por qué un grupo legacy asentado, y no un backend.** El editor no toma un fetch
    /// vacío por «no existe» a secas: exige que la zona sea fresca. Un `SplitGroup` del
    /// canal backend en uitest queda `.backendChannelIdle` (no hay pull) ⇒ `isFresh == false`
    /// ⇒ el puntero se trata como VIVO y Borrar/Duplicar se apagan — justo el bug. Una zona
    /// asentada SIN canal concede `.fresh` (Fase 3). El barrido de huérfanas no la toca
    /// (`belongsToBackendChannel` es el primer guard). `LegacyGroupsRetirement.retire`
    /// corre en el MISMO boot (tras `awaitPersonalStoreReady`) y nilea el puntero:
    /// AppBootstrapper salta ese retire solo bajo DEBUG + `-uitest` + perfil
    /// `dead-pointer`. `-uitest-reset` no basta.
    ///
    /// **No se setea `isBackendGroup = true`.** Eso es a propósito y va pinneado: el seed
    /// `.grupos` lo pone por C3, y copiarlo aquí reabriría el caso.
    @MainActor
    static func createDeadPointerFixture(
        account: Account,
        currencyCode: String,
        in context: ModelContext
    ) {
        let group = SplitGroup(
            name: "Dead pointer zone",
            currencyCode: currencyCode,
            isOwner: true
        )
        group.initialMemberImportStartedAt = nil
        context.insert(group)

        let tx = TransactionItem(
            date: Date.now,
            amount: DeadPointerUITestSeed.amount,
            currencyCode: currencyCode,
            note: DeadPointerUITestSeed.note,
            account: account,
            exchangeRate: 1.0,
            amountInPreferredCurrency: DeadPointerUITestSeed.amount,
            preferredCurrencyCode: currencyCode
        )
        tx.splitExpenseID = DeadPointerUITestSeed.unresolvedExpenseIDString
        tx.splitGroupZoneID = group.cloudKitZoneID
        tx.createdAt = Date.now
        context.insert(tx)

        do { try context.save() } catch {
            print("DevSeedTransactions: Dead pointer fixture save error: \(error)")
        }
    }
}
#endif
