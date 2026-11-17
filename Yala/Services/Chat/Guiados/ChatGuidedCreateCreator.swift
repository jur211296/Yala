//
//  ChatGuidedCreateCreator.swift
//  Yala
//
//  Lo que guardan los guiados de cuenta, categoría y favorito al tocar «Crear», por las mismas piezas que ya existen:
//  la cuenta por `FirstAccountCreator` (Primeros pasos), la categoría y sus subcategorías como el formulario de Ajustes
//  (`CategoriesSettingsListViewModel` + `SubcategoryDetailView`) y el favorito por `FavoriteEditorViewModel.saveFavorite`.
//

import Foundation
import SwiftData

extension ChatGuidedCreator {

    // MARK: - Cuenta

    static func createAccount(_ answers: ChatGuidedAnswers, context: ModelContext,
                              canCreateAccount: (Int) -> Bool) throws -> ChatGuidedCreation {
        guard let kind = ChatGuidedEngine.accountKind(answers),
              let currencies = answers.accountCurrencies, !currencies.isEmpty else {
            throw ChatGuidedCreationError.incomplete
        }
        let name = ChatGuidedEngine.trimmed(answers.accountName)
        guard !name.isEmpty else { throw ChatGuidedCreationError.incomplete }
        // Sin recuento no se sabe si cabe: no se crea por encima de un límite que no se pudo medir.
        guard let count = ChatGuidedDataSource.billableAccountCount(context) else { throw ChatGuidedCreationError.notSaved }
        guard canCreateAccount(count) else { throw ChatGuidedCreationError.planLimitReached }
        let taken: [Account]
        do {
            taken = try context.fetch(FetchDescriptor<Account>())
        } catch {
            #if DEBUG
            print("ChatGuidedCreator: Error: reading the account names: \(error)")
            #endif
            throw ChatGuidedCreationError.notSaved
        }
        if taken.contains(where: { !$0.isSystemAccount
            && ChatGuidedDataSource.foldedName($0.name) == ChatGuidedDataSource.foldedName(name) }) {
            throw ChatGuidedCreationError.duplicateName
        }

        var draft = FirstAccountDraft(mainCurrency: currencies[0])
        draft.kind = kind
        draft.currencies = FirstAccountFlowLogic.normalizedCurrencies(currencies)
        draft.name = name
        draft.balances = answers.accountBalances ?? [:]
        if kind.isCard {
            draft.statementDay = dayAnswer(answers.accountStatementDay)
            draft.paymentDay = dayAnswer(answers.accountPaymentDay)
            draft.reminderLead = answers.accountReminderLead.flatMap { $0 < 0 ? nil : $0 }
        }
        let account: Account
        do {
            account = try FirstAccountCreator.create(draft, suggestedName: name, in: context)
        } catch {
            #if DEBUG
            print("ChatGuidedCreator: Error: creating the account: \(error)")
            #endif
            throw ChatGuidedCreationError.notSaved
        }
        // Las opciones avanzadas, encima de lo que guarda Primeros pasos. La cuenta ya existe: si esto falla, no se
        // devuelve error (reintentar crearía otra).
        let number = ChatGuidedEngine.trimmed(answers.accountNumber)
        let excluded = answers.accountCountsInReports == false
        if !number.isEmpty || excluded {
            if !number.isEmpty { account.accountNumber = number }
            if excluded { account.excludeFromStatistics = true }
            do {
                try context.save()
                SessionState.shared.incrementDataVersion()
            } catch {
                #if DEBUG
                print("ChatGuidedCreator: Error: saving the account options: \(error)")
                #endif
            }
        }
        return ChatGuidedCreation(id: account.shortcutID, name: account.name, dueDate: nil)
    }

    /// 1…31 es ese día; 0 es «No lo sé».
    private static func dayAnswer(_ value: Int?) -> FirstAccountFlowLogic.DayAnswer? {
        guard let value else { return nil }
        return value == 0 ? .unknown : .day(value)
    }

    // MARK: - Categoría y subcategorías

    static func createCategory(_ answers: ChatGuidedAnswers, context: ModelContext) throws -> ChatGuidedCreation {
        guard let mode = answers.categoryMode else { throw ChatGuidedCreationError.incomplete }
        let names = cleanNames(answers.subcategoryNames ?? [])
        guard !names.isEmpty else { throw ChatGuidedCreationError.incomplete }
        let needs = answers.subcategoryNeeds ?? [:]
        var inserted: [any PersistentModel] = []
        let category: Category
        let newNames: [String]

        switch mode {
        case .newCategory:
            let name = ChatGuidedEngine.trimmed(answers.categoryName)
            guard !name.isEmpty, let icon = answers.categoryIcon, let color = answers.categoryColorHex else {
                throw ChatGuidedCreationError.incomplete
            }
            let existing: [Category]
            do {
                existing = try context.fetch(FetchDescriptor<Category>())
            } catch {
                #if DEBUG
                print("ChatGuidedCreator: Error: reading the categories: \(error)")
                #endif
                throw ChatGuidedCreationError.notSaved
            }
            if existing.contains(where: { ChatGuidedDataSource.foldedName($0.name) == ChatGuidedDataSource.foldedName(name) }) {
                throw ChatGuidedCreationError.duplicateName
            }
            category = Category(
                name: name, colorHex: color, isIncome: false, isDefaultSeed: false, isVisible: true,
                sortOrder: (existing.map(\.sortOrder).max() ?? 0) + 1, iconName: icon, subcategories: []
            )
            // Modo Nube I2: como `CategoriesSettingsListViewModel.createAndOpenNewCategory`.
            SyncIdentityService.captureIfEnabled(category)
            context.insert(category)
            inserted.append(category)
            newNames = names
        case .subcategories:
            guard let id = answers.parentCategoryID, let parent = context.model(for: id) as? Category,
                  !parent.isDeleted, parent.modelContext != nil else {
                throw ChatGuidedCreationError.incomplete
            }
            category = parent
            let taken = Set((parent.subcategories ?? []).map { ChatGuidedDataSource.foldedName($0.name) })
            newNames = names.filter { !taken.contains(ChatGuidedDataSource.foldedName($0)) }
            guard !newNames.isEmpty else { throw ChatGuidedCreationError.duplicateName }
        }

        // Como el formulario: heredan el color de la categoría; en una existente, también su ícono.
        var firstID: UUID?
        for (offset, name) in newNames.enumerated() {
            let need = needs[name].flatMap(SubcategoryNeed.init(rawValue:)) ?? .unclassified
            let subcategory = Subcategory(
                name: name, colorHex: category.colorHex, isDefaultSeed: false, isVisible: true, sortOrder: offset,
                natureRawValue: need.rawValue, iconName: category.iconName, category: category
            )
            context.insert(subcategory)
            inserted.append(subcategory)
            if firstID == nil { firstID = subcategory.shortcutID }
        }
        // En una categoría que ya existe, todas en orden alfabético, como al guardar una desde el formulario.
        if mode == .subcategories {
            let all = (category.subcategories ?? []).filter { !$0.isDeleted }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            for (index, subcategory) in all.enumerated() { subcategory.sortOrder = index }
        }
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("ChatGuidedCreator: Error: saving the category: \(error)")
            #endif
            // Se deshace solo lo propio: el contexto es compartido.
            for model in inserted.reversed() { context.delete(model) }
            throw ChatGuidedCreationError.notSaved
        }
        SessionState.shared.incrementDataVersion()
        return ChatGuidedCreation(id: firstID ?? UUID(), name: category.name, dueDate: nil)
    }

    /// Sin espacios de más, sin vacíos y sin repetir (sin mirar mayúsculas ni tildes).
    static func cleanNames(_ names: [String]) -> [String] {
        var seen: Set<String> = []
        return names.map { ChatGuidedEngine.trimmed($0) }
            .filter { !$0.isEmpty && seen.insert(ChatGuidedDataSource.foldedName($0)).inserted }
    }

    // MARK: - Favorito

    static func createFavorite(_ answers: ChatGuidedAnswers, context: ModelContext) throws -> ChatGuidedCreation {
        guard let type = ChatGuidedEngine.favoriteType(answers),
              let transactionType = TransactionType(rawValue: type.rawValue) else {
            throw ChatGuidedCreationError.incomplete
        }
        let name = ChatGuidedEngine.trimmed(answers.favoriteName)
        guard !name.isEmpty else { throw ChatGuidedCreationError.incomplete }
        let account = answers.accountID.flatMap { live(context.model(for: $0) as? Account) }
        let destination = type == .transfer
            ? answers.destinationAccountID.flatMap { live(context.model(for: $0) as? Account) } : nil
        let subcategory = type == .transfer
            ? nil : answers.subcategoryID.flatMap { live(context.model(for: $0) as? Subcategory) }
        let tags = (answers.tagIDs ?? []).compactMap { live(context.model(for: $0) as? Tag) }
        let need = answers.favoriteNeed.flatMap(SubcategoryNeed.init(rawValue:)) ?? subcategory?.need
        let amountText = answers.favoriteWithoutAmount == true ? "" : answers.amount.map { editorAmountText($0) } ?? ""

        let viewModel = FavoriteEditorViewModel()
        viewModel.setContext(context)
        guard viewModel.saveFavorite(
            existing: nil,
            name: name,
            transactionType: transactionType,
            amountString: amountText,
            note: ChatGuidedEngine.trimmed(answers.note),
            account: account,
            subcategory: subcategory,
            tags: tags,
            needOverride: need,
            destinationAccount: destination
        ) else {
            throw ChatGuidedCreationError.notSaved
        }
        return ChatGuidedCreation(id: UUID(), name: name, dueDate: nil)
    }

    /// El monto como lo escribiría la persona en el editor, que lo lee con la configuración regional
    /// (`AmountInputHelper.parseDecimal`): sin separador de miles y con la coma o el punto de su región.
    static func editorAmountText(_ amount: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }

    private static func live<T: PersistentModel>(_ model: T?) -> T? {
        guard let model, !model.isDeleted, model.modelContext != nil else { return nil }
        return model
    }
}
