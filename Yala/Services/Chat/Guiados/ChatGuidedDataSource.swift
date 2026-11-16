//
//  ChatGuidedDataSource.swift
//  Yala
//
//  Lo que los guiados leen de la persona: sus categorías con lo gastado, sus cuentas, las categorías de los pagos de
//  Primeros pasos, los cobros que se repiten (`RecurringProposalsSource`, el detector de Pagos planificados) y lo
//  gastado en los últimos meses para proponer el monto de un presupuesto. Solo lee.
//

import Foundation
import SwiftData

/// Una foto de lo que el guiado necesita. Se lee al abrir la tarjeta; las respuestas guardan identificadores, no esto.
struct ChatGuidedData {
    struct CategoryOption: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let icon: String
        let colorHex: String
        /// Las subcategorías que cuenta (`Subcategory.shortcutID`), las visibles: las del presupuesto.
        let subcategoryIDs: [UUID]
        let spentThisMonth: Double
    }

    struct AccountOption: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let currencyCode: String
    }

    struct SubcategoryOption: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let icon: String
        let colorHex: String
        let categoryName: String
    }

    /// Un cobro que se repite en los registros, listo para ser un pago planificado.
    struct PaymentSuggestion: Identifiable {
        var id: String { key }
        let key: String
        let name: String
        let amount: Double
        let isVariableAmount: Bool
        let frequency: ChatGuidedFrequency
        let dayOfMonth: Int?
        let weekday: Int?
        let currencyCode: String
        let accountID: PersistentIdentifier?
        let subcategoryID: PersistentIdentifier?
        let isSubscription: Bool
        let chargeCount: Int
    }

    var mainCurrency: String
    var categories: [CategoryOption] = []
    var accounts: [AccountOption] = []
    /// La cuenta que se propone: la del último registro, como el editor de pagos.
    var defaultAccountID: PersistentIdentifier?
    var paymentSubcategories: [SubcategoryOption] = []
    var suggestions: [PaymentSuggestion] = []
    /// Las monedas que se ofrecen: la principal y las de las cuentas, sin repetir.
    var currencies: [String] = []
    /// Movimientos desde el inicio del cuarto mes hacia atrás: lo gastado de este mes y de los tres anteriores.
    var transactions: [TransactionItem] = []

    func category(_ id: PersistentIdentifier) -> CategoryOption? { categories.first { $0.id == id } }
    func account(_ id: PersistentIdentifier?) -> AccountOption? { id.flatMap { id in accounts.first { $0.id == id } } }
    func subcategory(_ id: PersistentIdentifier?) -> SubcategoryOption? {
        id.flatMap { id in paymentSubcategories.first { $0.id == id } }
    }

    /// Las subcategorías que cuenta el presupuesto con estas respuestas. Vacío = todos los gastos.
    func budgetSubcategoryIDs(_ answers: ChatGuidedAnswers) -> [UUID] {
        guard answers.allExpenses == false else { return [] }
        var seen: Set<UUID> = []
        return answers.categoryIDs.flatMap { category($0)?.subcategoryIDs ?? [] }.filter { seen.insert($0).inserted }
    }
}

@MainActor
enum ChatGuidedDataSource {

    /// Lo que el detector necesita para leer la frase: los nombres de las categorías y la moneda.
    static func catalog(context: ModelContext, mainCurrency: String) -> ChatGuidedCatalog {
        var catalog = ChatGuidedCatalog(mainCurrency: mainCurrency)
        do {
            for category in try budgetCategories(context) {
                let subcategories = visibleSubcategories(of: category)
                var words = [category.name] + subcategories.map(\.name)
                words += subcategories.flatMap { CategoryEverydayWords.words(forName: $0.name) }
                let folded = words.map(ChatGuidedIntentDetector.fold).filter { !$0.isEmpty }
                catalog.categories.append(.init(id: category.persistentModelID, words: Array(Set(folded))))
            }
            let accounts = try context.fetch(FetchDescriptor<Account>())
                .filter { !$0.isArchived && !$0.isSystemAccount }
            var seen: Set<String> = []
            catalog.accountCurrencies = accounts.map { $0.currencyCode.uppercased() }.filter { seen.insert($0).inserted }
        } catch {
            #if DEBUG
            print("ChatGuidedDataSource: Error: building the catalog: \(error)")
            #endif
        }
        return catalog
    }

    /// Lo que ya se sabe antes de la primera pregunta, además de la frase: sin cobros que se repitan (o con el nombre
    /// ya dicho) no se pregunta por ellos, y con una sola cuenta tampoco por la cuenta.
    static func prepareStart(_ detection: ChatGuidedDetection, context: ModelContext,
                             now: Date = .now) -> ChatGuidedDetection {
        guard detection.kind == .scheduledPayment else { return detection }
        var prepared = detection
        if prepared.answers.suggestionKey == nil {
            var hasSuggestions = false
            if prepared.answers.paymentName == nil {
                do {
                    hasSuggestions = try !RecurringProposalsSource.load(context: context, now: now).isEmpty
                } catch {
                    #if DEBUG
                    print("ChatGuidedDataSource: Error: looking for recurring charges: \(error)")
                    #endif
                }
            }
            if !hasSuggestions { prepared.answers.suggestionKey = "" }
        }
        let viewModel = ScheduledPaymentEditorViewModel()
        viewModel.setContext(context, deletionService: EntityDeletionService.shared)
        if prepared.answers.accountID == nil, viewModel.activeAccounts.count == 1, let only = viewModel.activeAccounts.first {
            prepared.answers.accountID = only.persistentModelID
            if prepared.answers.currencyCode == nil { prepared.answers.currencyCode = only.currencyCode.uppercased() }
        }
        return prepared
    }

    /// Todo lo que pinta la tarjeta del guiado.
    static func load(_ kind: ChatGuidedKind, context: ModelContext, mainCurrency: String, now: Date = .now,
                     calendar: Calendar = .current) -> ChatGuidedData {
        var data = ChatGuidedData(mainCurrency: mainCurrency)
        let viewModel = ScheduledPaymentEditorViewModel()
        viewModel.setContext(context, deletionService: EntityDeletionService.shared)
        data.accounts = viewModel.activeAccounts.map {
            .init(id: $0.persistentModelID, name: $0.name, currencyCode: $0.currencyCode)
        }
        data.defaultAccountID = (viewModel.lastUsedAccount() ?? viewModel.activeAccounts.first)?.persistentModelID
        var seen: Set<String> = []
        data.currencies = ([mainCurrency] + data.accounts.map(\.currencyCode)).map { $0.uppercased() }
            .filter { seen.insert($0).inserted }

        switch kind {
        case .budget:
            let start = calendar.date(byAdding: .month, value: -3, to: calendar.startOfMonth(for: now)) ?? now
            do {
                data.transactions = try context.fetch(FetchDescriptor<TransactionItem>(
                    predicate: #Predicate { $0.date >= start }
                ))
                data.categories = try budgetCategories(context).map { category in
                    let ids = visibleSubcategories(of: category).map(\.shortcutID)
                    return .init(
                        id: category.persistentModelID,
                        name: category.name,
                        icon: category.iconName ?? "tag.fill",
                        colorHex: category.colorHex,
                        subcategoryIDs: ids,
                        spentThisMonth: ChatGuidedSpending.spent(
                            subcategoryIDs: ids, monthOf: now, currencyCode: mainCurrency,
                            transactions: data.transactions, calendar: calendar)
                    )
                }
            } catch {
                #if DEBUG
                print("ChatGuidedDataSource: Error: loading the budget data: \(error)")
                #endif
            }
        case .scheduledPayment:
            data.paymentSubcategories = paymentSubcategories(context)
            do {
                let items = try RecurringProposalsSource.load(context: context, now: now, calendar: calendar).prefix(4)
                data.suggestions = items.map(suggestion)
                // Una categoría que llega de un cobro y no está entre las seis también se ofrece.
                for subcategory in items.compactMap(\.liveSubcategory)
                where !data.paymentSubcategories.contains(where: { $0.id == subcategory.persistentModelID }) {
                    data.paymentSubcategories.append(option(subcategory))
                }
            } catch {
                #if DEBUG
                print("ChatGuidedDataSource: Error: loading the recurring charges: \(error)")
                #endif
            }
        }
        return data
    }

    /// La subcategoría que se toma de una búsqueda («Otra categoría»): se añade a las opciones.
    static func option(_ subcategory: Subcategory) -> ChatGuidedData.SubcategoryOption {
        .init(
            id: subcategory.persistentModelID,
            name: subcategory.name,
            icon: subcategory.iconName ?? "tag.fill",
            colorHex: subcategory.category?.colorHex ?? "#6366F1",
            categoryName: subcategory.category?.name ?? ""
        )
    }

    // MARK: - Piezas

    /// Las categorías de un presupuesto: las de Primeros pasos (gasto, visibles, de la persona, con subcategorías).
    static func budgetCategories(_ context: ModelContext) throws -> [Category] {
        try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
            .filter { !$0.isIncome && !$0.isSystem && $0.isVisible && !visibleSubcategories(of: $0).isEmpty }
    }

    static func visibleSubcategories(of category: Category) -> [Subcategory] {
        (category.subcategories ?? [])
            .filter { $0.isVisible && !$0.isAnySystem }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Las seis de Primeros pasos (alquiler, servicios, teléfono, suscripciones, gimnasio), como allí.
    private static func paymentSubcategories(_ context: ModelContext) -> [ChatGuidedData.SubcategoryOption] {
        do {
            let subcategories = try context.fetch(FetchDescriptor<Subcategory>())
                .filter { $0.isVisible && !$0.isAnySystem && $0.category?.isIncome == false }
            var result: [ChatGuidedData.SubcategoryOption] = []
            for kind in FirstScheduledPaymentFlowLogic.Kind.allCases {
                let found = subcategories.first { $0.isDefaultSeed && $0.iconName == kind.seedIcon }
                    ?? subcategories.first { $0.iconName == kind.seedIcon }
                if let found, !result.contains(where: { $0.id == found.persistentModelID }) {
                    result.append(option(found))
                }
            }
            return result
        } catch {
            #if DEBUG
            print("ChatGuidedDataSource: Error: loading the subcategories: \(error)")
            #endif
            return []
        }
    }

    private static func suggestion(_ item: RecurringProposalsSource.Item) -> ChatGuidedData.PaymentSuggestion {
        let proposal = item.proposal
        let frequency: ChatGuidedFrequency
        var day: Int?
        var weekday: Int?
        switch proposal.cadence {
        case let .monthly(typicalDay, _):
            frequency = .monthly
            day = typicalDay
        case let .weekly(value):
            frequency = .weekly
            weekday = value
        }
        return .init(
            key: proposal.key,
            name: proposal.displayName,
            amount: proposal.amount,
            isVariableAmount: proposal.isVariableAmount,
            frequency: frequency,
            dayOfMonth: day,
            weekday: weekday,
            currencyCode: proposal.currencyCode,
            accountID: item.liveAccount?.persistentModelID,
            subcategoryID: item.liveSubcategory?.persistentModelID,
            isSubscription: proposal.isSubscriptionBrand,
            chargeCount: proposal.chargeCount
        )
    }
}

/// Lo gastado y lo que se propone para un presupuesto, con la regla de Planificación.
@MainActor
enum ChatGuidedSpending {

    /// Lo gastado en el mes de `date` (vacío = todos los gastos).
    static func spent(subcategoryIDs: [UUID], monthOf date: Date, currencyCode: String,
                      transactions: [TransactionItem], calendar: Calendar) -> Double {
        TutorialPlanningMath.budgetSpent(
            subcategoryIDs: subcategoryIDs, period: .monthly, currencyCode: currencyCode,
            transactions: transactions, now: date, calendar: calendar)
    }

    /// El promedio de los tres meses cerrados anteriores; los meses sin gasto no cuentan (alguien que empezó hace
    /// poco no ve la mitad de lo que gasta). 0 si no hay ninguno.
    static func monthlyAverage(subcategoryIDs: [UUID], currencyCode: String, transactions: [TransactionItem],
                               now: Date = .now, calendar: Calendar = .current) -> Double {
        let months = (1...3).compactMap { calendar.date(byAdding: .month, value: -$0, to: calendar.startOfMonth(for: now)) }
        let totals = months.map {
            spent(subcategoryIDs: subcategoryIDs, monthOf: $0, currencyCode: currencyCode,
                  transactions: transactions, calendar: calendar)
        }.filter { $0 > 0 }
        guard !totals.isEmpty else { return 0 }
        return totals.reduce(0, +) / Double(totals.count)
    }

    /// Los montos que se proponen: lo de siempre y «un 10 % menos», redondeados y en el período elegido.
    static func suggestions(monthlyAverage: Double, period: ChatGuidedPeriod) -> (usual: Double, saving: Double)? {
        guard monthlyAverage > 0 else { return nil }
        let inPeriod: Double
        switch period {
        case .monthly: inPeriod = monthlyAverage
        case .weekly: inPeriod = monthlyAverage * 12 / 52
        case .yearly: inPeriod = monthlyAverage * 12
        }
        let usual = rounded(inPeriod)
        let saving = rounded(inPeriod * 0.9)
        guard usual > 0, saving > 0, saving < usual else { return usual > 0 ? (usual, usual) : nil }
        return (usual, saving)
    }

    /// A 5 por debajo de 100, a 10 hasta 1.000 y a 50 por encima: una cifra que se lee de un vistazo.
    static func rounded(_ value: Double) -> Double {
        let step: Double = value < 100 ? 5 : (value < 1000 ? 10 : 50)
        return max(step, (value / step).rounded() * step)
    }
}
