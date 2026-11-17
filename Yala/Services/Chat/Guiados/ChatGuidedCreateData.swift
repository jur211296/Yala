//
//  ChatGuidedCreateData.swift
//  Yala
//
//  Lo que leen los guiados de cuenta, categoría y favorito: los nombres que no se repiten, las categorías donde caben
//  subcategorías nuevas y las subcategorías más usadas para un favorito. Solo lee.
//

import Foundation
import SwiftData

extension ChatGuidedDataSource {

    static func loadCreate(_ kind: ChatGuidedKind, into data: inout ChatGuidedData, context: ModelContext,
                           now: Date, calendar: Calendar) {
        switch kind {
        case .account:
            do {
                data.accountNames = Set(try context.fetch(FetchDescriptor<Account>())
                    .filter { !$0.isSystemAccount }
                    .map { foldedName($0.name) })
            } catch {
                #if DEBUG
                print("ChatGuidedDataSource: Error: loading the account names: \(error)")
                #endif
            }
            // Las monedas que se ofrecen en una cuenta: las de siempre, más dólares y euros.
            var seen = Set(data.currencies)
            for code in ["USD", "EUR"] where seen.insert(code).inserted { data.currencies.append(code) }
        case .category:
            data.categoryParents = categoryParents(context)
        case .favorite:
            data.favoriteSubcategories = favoriteSubcategories(context, now: now, calendar: calendar)
        case .budget, .scheduledPayment, .group, .groupOpeningBalance, .groupExpense:
            break
        }
    }

    /// Las categorías de gasto de la persona, en su orden: las que se pueden ampliar y cuyos nombres no se repiten.
    static func categoryParents(_ context: ModelContext) -> [ChatGuidedData.CategoryParentOption] {
        do {
            return try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
                .filter { !$0.isIncome && !$0.isSystem && $0.isVisible
                    && !CategoryRecordsMoveService.holdsSystemSubcategories($0) }
                .map { category in
                    .init(
                        id: category.persistentModelID,
                        name: category.name,
                        icon: category.iconName ?? "tag.fill",
                        colorHex: category.colorHex,
                        subcategoryNames: Set((category.subcategories ?? []).map { foldedName($0.name) })
                    )
                }
        } catch {
            #if DEBUG
            print("ChatGuidedDataSource: Error: loading the categories: \(error)")
            #endif
            return []
        }
    }

    /// Los nombres de TODAS las categorías (de gasto y de ingreso), plegados: una nueva no repite ninguno.
    static func categoryNames(_ context: ModelContext) -> Set<String> {
        do {
            return Set(try context.fetch(FetchDescriptor<Category>()).map { foldedName($0.name) })
        } catch {
            #if DEBUG
            print("ChatGuidedDataSource: Error: loading the category names: \(error)")
            #endif
            return []
        }
    }

    /// Las subcategorías de gasto y de ingreso, las más usadas en los últimos seis meses primero (hasta seis de cada).
    static func favoriteSubcategories(_ context: ModelContext, now: Date,
                                      calendar: Calendar) -> [ChatGuidedFavoriteType: [ChatGuidedData.SubcategoryOption]] {
        do {
            let subcategories = try context.fetch(FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\.sortOrder)]))
                .filter { $0.isVisible && !$0.isAnySystem && $0.category?.isVisible != false && $0.category?.isSystem != true }
            let start = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            var uses: [PersistentIdentifier: Int] = [:]
            for item in try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.date >= start })) {
                if let id = item.subcategory?.persistentModelID { uses[id, default: 0] += 1 }
            }
            func top(income: Bool) -> [ChatGuidedData.SubcategoryOption] {
                let ofType = subcategories.filter { ($0.category?.isIncome ?? false) == income }
                let ranked = ofType.enumerated().sorted { lhs, rhs in
                    let left = uses[lhs.element.persistentModelID] ?? 0
                    let right = uses[rhs.element.persistentModelID] ?? 0
                    return left != right ? left > right : lhs.offset < rhs.offset
                }
                return ranked.prefix(6).map { option($0.element) }
            }
            return [.expense: top(income: false), .income: top(income: true)]
        } catch {
            #if DEBUG
            print("ChatGuidedDataSource: Error: loading the favorite subcategories: \(error)")
            #endif
            return [:]
        }
    }

    /// Un favorito con una sola cuenta no pregunta cuál.
    static func prepareFavorite(_ detection: ChatGuidedDetection, context: ModelContext) -> ChatGuidedDetection {
        var prepared = detection
        let viewModel = ScheduledPaymentEditorViewModel()
        viewModel.setContext(context, deletionService: EntityDeletionService.shared)
        if prepared.answers.accountID == nil, viewModel.activeAccounts.count == 1, let only = viewModel.activeAccounts.first {
            prepared.answers.accountID = only.persistentModelID
        }
        return prepared
    }

    /// Las cuentas que ya cuentan para el límite del plan gratis (`Account.isBillableUserAccount`). Sin poder
    /// contarlas no se puede saber si cabe otra: `nil`.
    static func billableAccountCount(_ context: ModelContext) -> Int? {
        do {
            return try context.fetch(FetchDescriptor<Account>()).count(where: \.isBillableUserAccount)
        } catch {
            #if DEBUG
            print("ChatGuidedDataSource: Error: counting the accounts: \(error)")
            #endif
            return nil
        }
    }

    /// Un nombre para compararlo: sin mayúsculas, tildes ni espacios de más.
    static func foldedName(_ name: String) -> String {
        ChatGuidedIntentDetector.fold(name)
    }
}

/// El ícono que se propone para una categoría nueva por su nombre, y la paleta del selector de siempre.
enum ChatGuidedCategoryLook {
    /// Los colores del selector (`IconColorPickerSheet`), los más distintos entre sí.
    static let colors = ["#6366F1", "#22C55E", "#F59E0B", "#0EA5E9", "#EC4899", "#EF4444", "#8B5CF6", "#475569"]

    /// Los que se ofrecen siempre, por si el propuesto no sirve.
    static let icons = ["tag.fill", "cart.fill", "fork.knife", "car.fill", "house.fill", "heart.fill", "gift.fill",
                        "airplane", "pawprint.fill", "graduationcap.fill", "gamecontroller.fill", "figure.run"]

    private static let keywords: [(words: [String], icon: String)] = [
        (["mascota", "perro", "gato", "pets", "dog", "veterin", "haustier", "animal"], "pawprint.fill"),
        (["viaje", "vacacion", "travel", "trip", "viagem", "voyage", "reise", "viaggi", "vuelo", "flight"], "airplane"),
        (["comida", "restaurant", "food", "aliment", "cena", "almuerzo", "essen", "cibo", "eten"], "fork.knife"),
        (["super", "mercado", "compras", "grocer", "shopping", "einkauf", "spesa"], "cart.fill"),
        (["auto", "carro", "coche", "transport", "gasolina", "fuel", "taxi"], "car.fill"),
        (["casa", "hogar", "home", "house", "alquiler", "rent", "maison", "haus"], "house.fill"),
        (["salud", "health", "medic", "doctor", "farmacia", "saude", "sante", "gesundheit"], "heart.fill"),
        (["regalo", "gift", "presente", "cadeau", "geschenk"], "gift.fill"),
        (["educa", "estudio", "curso", "school", "colegio", "universidad", "study", "escola"], "graduationcap.fill"),
        (["juego", "game", "ocio", "entreten", "hobby", "spiel", "gioc"], "gamecontroller.fill"),
        (["gym", "deporte", "sport", "fitness", "gimnasio"], "figure.run"),
        (["bebe", "baby", "hijo", "nino", "kid", "child"], "figure.and.child.holdinghands"),
        (["ropa", "cloth", "moda", "fashion", "roupa", "vetement", "kleidung"], "tshirt.fill"),
        (["cafe", "coffee", "kaffee"], "cup.and.saucer.fill"),
        (["belleza", "beauty", "peluqu", "spa"], "sparkles"),
        (["tecnolog", "tech", "celular", "phone", "computer", "software"], "laptopcomputer"),
    ]

    /// El ícono de la primera palabra clave que contiene el nombre, o la etiqueta de siempre.
    static func suggestedIcon(for name: String) -> String {
        let folded = ChatGuidedIntentDetector.fold(name)
        for entry in keywords where entry.words.contains(where: { folded.contains($0) }) {
            return entry.icon
        }
        return "tag.fill"
    }
}
