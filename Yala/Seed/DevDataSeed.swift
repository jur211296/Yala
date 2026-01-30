//
//  DevDataSeed.swift
//  Yala
//
//  Semilla de datos de desarrollo para testing.
//  Solo se ejecuta en builds DEBUG.
//
//  -------------------------------------------------------------------------
//  IMPORTANTE:
//  - Este archivo solo se compila y ejecuta en DEBUG builds
//  - Proporciona datos de prueba completos: cuentas, tags, presupuestos,
//    favoritos, suscripciones, pagos planificados y transacciones históricas
//  - Ejecutado opcionalmente desde el onboarding
//  -------------------------------------------------------------------------
//

#if DEV_BUILD

import Foundation
import SwiftData

// MARK: - Internal Data Structures

/// Definición de una cuenta para el seed
private struct AccountSeedDefinition {
    let name: String
    let currencyCode: String
    let colorHex: String
    let iconName: String
    let type: String  // "General", "Efectivo", "Cuenta corriente", "Cuenta de ahorros"
}

/// Definición de un tag para el seed
private struct TagSeedDefinition {
    let name: String
    let colorHex: String
    let iconName: String
}

/// Definición de un presupuesto para el seed
private struct BudgetSeedDefinition {
    let name: String
    let periodType: String  // "daily", "monthly", "yearly"
    let limitAmount: Double
    let subcategoryName: String  // Nombre de la subcategoría a la que se asigna
}

/// Definición de un favorito para el seed
private struct FavoriteSeedDefinition {
    let name: String
    let transactionType: String  // "expense" or "income"
    let amount: Double?
    let subcategoryName: String
    let note: String?
}

/// Definición de una suscripción para el seed
private struct SubscriptionSeedDefinition {
    let name: String
    let amount: Double
    let dayOfMonth: Int
    let subcategoryName: String
}

/// Definición de un pago planificado para el seed
private struct ScheduledPaymentSeedDefinition {
    let name: String
    let amount: Double
    let dayOfMonth: Int
    let subcategoryName: String
    let note: String?
}

// MARK: - Seed Data Definitions

private let devAccountDefinitions: [AccountSeedDefinition] = [
    AccountSeedDefinition(
        name: "BCP Cuenta Corriente",
        currencyCode: "PEN",
        colorHex: "#0A84FF",
        iconName: "building.columns.fill",
        type: "Cuenta corriente"
    ),
    AccountSeedDefinition(
        name: "BBVA Ahorros USD",
        currencyCode: "USD",
        colorHex: "#30D158",
        iconName: "banknote.fill",
        type: "Cuenta de ahorros"
    ),
    AccountSeedDefinition(
        name: "Efectivo",
        currencyCode: "PEN",
        colorHex: "#FF9F0A",
        iconName: "wallet.pass.fill",
        type: "Efectivo"
    ),
]

private let devTagDefinitions: [TagSeedDefinition] = [
    TagSeedDefinition(name: "Trabajo", colorHex: "#0A84FF", iconName: "briefcase.fill"),
    TagSeedDefinition(name: "Personal", colorHex: "#30D158", iconName: "person.fill"),
    TagSeedDefinition(name: "Urgente", colorHex: "#FF375F", iconName: "exclamationmark.circle.fill"),
    TagSeedDefinition(name: "Familia", colorHex: "#FF9F0A", iconName: "house.fill"),
    TagSeedDefinition(name: "Vacaciones", colorHex: "#BF5AF2", iconName: "airplane"),
]

private let devBudgetDefinitions: [BudgetSeedDefinition] = [
    // Mensuales (4)
    BudgetSeedDefinition(
        name: "Alimentación mensual",
        periodType: "monthly",
        limitAmount: 1200.0,
        subcategoryName: "Supermercados y bodegas"
    ),
    BudgetSeedDefinition(
        name: "Entretenimiento mensual",
        periodType: "monthly",
        limitAmount: 300.0,
        subcategoryName: "Streaming y plataformas"
    ),
    BudgetSeedDefinition(
        name: "Transporte mensual",
        periodType: "monthly",
        limitAmount: 250.0,
        subcategoryName: "Transporte público"
    ),
    BudgetSeedDefinition(
        name: "Hogar mensual",
        periodType: "monthly",
        limitAmount: 800.0,
        subcategoryName: "Servicios del hogar"
    ),
    // Diario (1)
    BudgetSeedDefinition(
        name: "Café diario",
        periodType: "daily",
        limitAmount: 15.0,
        subcategoryName: "Restaurantes"
    ),
    // Anuales (2)
    BudgetSeedDefinition(
        name: "Vacaciones anuales",
        periodType: "yearly",
        limitAmount: 5000.0,
        subcategoryName: "Viajes y vacaciones"
    ),
    BudgetSeedDefinition(
        name: "Regalos fin de año",
        periodType: "yearly",
        limitAmount: 2000.0,
        subcategoryName: "Regalos y detalles"
    ),
]

private let devFavoriteDefinitions: [FavoriteSeedDefinition] = [
    FavoriteSeedDefinition(
        name: "Uber/Taxi",
        transactionType: "expense",
        amount: nil,
        subcategoryName: "Taxis y apps",
        note: nil
    ),
    FavoriteSeedDefinition(
        name: "Supermercado Metro",
        transactionType: "expense",
        amount: nil,
        subcategoryName: "Supermercados y bodegas",
        note: nil
    ),
    FavoriteSeedDefinition(
        name: "Café favorito",
        transactionType: "expense",
        amount: 12.0,
        subcategoryName: "Restaurantes",
        note: "Café latte grande"
    ),
    FavoriteSeedDefinition(
        name: "Almuerzo trabajo",
        transactionType: "expense",
        amount: 25.0,
        subcategoryName: "Restaurantes",
        note: nil
    ),
]

private let devSubscriptionDefinitions: [SubscriptionSeedDefinition] = [
    // Día 1 (2 comparten)
    SubscriptionSeedDefinition(
        name: "Netflix",
        amount: 44.90,
        dayOfMonth: 1,
        subcategoryName: "Streaming y plataformas"
    ),
    SubscriptionSeedDefinition(
        name: "Spotify",
        amount: 19.90,
        dayOfMonth: 1,
        subcategoryName: "Streaming y plataformas"
    ),
    // Otros días
    SubscriptionSeedDefinition(
        name: "Amazon Prime",
        amount: 35.00,
        dayOfMonth: 10,
        subcategoryName: "Streaming y plataformas"
    ),
    SubscriptionSeedDefinition(
        name: "Gym",
        amount: 150.00,
        dayOfMonth: 15,
        subcategoryName: "Fitness y actividad física"
    ),
    SubscriptionSeedDefinition(
        name: "iCloud Storage",
        amount: 10.90,
        dayOfMonth: 25,
        subcategoryName: "Suscripciones de utilidad"
    ),
]

private let devScheduledPaymentDefinitions: [ScheduledPaymentSeedDefinition] = [
    ScheduledPaymentSeedDefinition(
        name: "Alquiler",
        amount: 1500.00,
        dayOfMonth: 5,
        subcategoryName: "Alquiler o hipoteca",
        note: "Pago mensual de alquiler"
    ),
    ScheduledPaymentSeedDefinition(
        name: "Internet",
        amount: 99.00,
        dayOfMonth: 8,
        subcategoryName: "Servicios del hogar",
        note: "Movistar 300 Mbps"
    ),
    ScheduledPaymentSeedDefinition(
        name: "Luz y agua",
        amount: 180.00,
        dayOfMonth: 12,
        subcategoryName: "Servicios del hogar",
        note: nil
    ),
    ScheduledPaymentSeedDefinition(
        name: "Teléfono",
        amount: 55.00,
        dayOfMonth: 20,
        subcategoryName: "Telefonía y comunicaciones",
        note: "Plan móvil Claro"
    ),
    ScheduledPaymentSeedDefinition(
        name: "Seguro del hogar",
        amount: 120.00,
        dayOfMonth: 28,
        subcategoryName: "Seguro del hogar",
        note: "Póliza mensual"
    ),
]

// MARK: - Main Seed Function

/// Ejecuta la semilla de datos de desarrollo solo si está habilitado.
/// Esta función crea cuentas, tags, presupuestos, favoritos, suscripciones,
/// pagos planificados y transacciones históricas para facilitar el testing.
///
/// - Parameters:
///   - context: ModelContext de SwiftData
///   - preferredCurrency: Moneda preferida del usuario (para conversiones)
func seedDevDataIfEnabled(in context: ModelContext, preferredCurrency: CurrencyCode) {
    print("DevDataSeed: Iniciando semilla de datos de desarrollo...")

    // Create accounts
    let createdAccounts = createDevAccounts(in: context)
    print("DevDataSeed: \(createdAccounts.count) cuentas creadas")

    // Create tags
    let createdTags = createDevTags(in: context)
    print("DevDataSeed: \(createdTags.count) etiquetas creadas")

    // Create budgets (requires subcategories from category seed)
    let createdBudgets = createDevBudgets(in: context, preferredCurrency: preferredCurrency)
    print("DevDataSeed: \(createdBudgets.count) presupuestos creados")

    // Create favorite payments
    let createdFavorites = createDevFavorites(in: context)
    print("DevDataSeed: \(createdFavorites.count) favoritos creados")

    // Create subscriptions
    let createdSubscriptions = createDevSubscriptions(in: context, preferredCurrency: preferredCurrency)
    print("DevDataSeed: \(createdSubscriptions.count) suscripciones creadas")

    // Create scheduled payments
    let createdScheduledPayments = createDevScheduledPayments(in: context, preferredCurrency: preferredCurrency)
    print("DevDataSeed: \(createdScheduledPayments.count) pagos planificados creados")

    // Generate historical transactions (8a: from subscriptions and scheduled payments)
    let transactionsFromScheduled = generateScheduledPaymentTransactions(
        in: context,
        subscriptions: createdSubscriptions,
        scheduledPayments: createdScheduledPayments,
        accounts: createdAccounts,
        preferredCurrency: preferredCurrency
    )
    print("DevDataSeed: \(transactionsFromScheduled) transacciones generadas desde pagos/suscripciones")

    // Generate varied daily transactions (8b: groceries, cafes, transport, etc.)
    let variedTransactions = generateVariedDailyTransactions(
        in: context,
        accounts: createdAccounts,
        tags: createdTags,
        preferredCurrency: preferredCurrency
    )
    print("DevDataSeed: \(variedTransactions) transacciones variadas generadas")

    // Save all changes
    do {
        try context.save()
        print("DevDataSeed: Semilla de datos completada exitosamente.")
    } catch {
        print("DevDataSeed: Error al guardar: \(error)")
    }
}

// MARK: - Account Creation

/// Crea las cuentas de desarrollo
private func createDevAccounts(in context: ModelContext) -> [Account] {
    var accounts: [Account] = []

    for definition in devAccountDefinitions {
        let account = Account(
            name: definition.name,
            currencyCode: definition.currencyCode,
            colorHex: definition.colorHex,
            iconName: definition.iconName,
            type: definition.type,
            accountNumber: nil,
            adjustmentMode: "Ajustar por registro",
            excludeFromStatistics: false,
            isArchived: false
        )
        context.insert(account)
        accounts.append(account)
    }

    return accounts
}

// MARK: - Tag Creation

/// Crea los tags de desarrollo
private func createDevTags(in context: ModelContext) -> [Tag] {
    var tags: [Tag] = []

    for definition in devTagDefinitions {
        let tag = Tag(
            name: definition.name,
            colorHex: definition.colorHex,
            iconName: definition.iconName,
            isActive: true,
            createdAt: Date()
        )
        context.insert(tag)
        tags.append(tag)
    }

    return tags
}

// MARK: - Budget Creation

/// Crea los presupuestos de desarrollo
/// Requiere que las categorías seed ya existan
private func createDevBudgets(in context: ModelContext, preferredCurrency: CurrencyCode) -> [Budget] {
    var budgets: [Budget] = []

    for definition in devBudgetDefinitions {
        // Buscar la subcategoría por nombre
        let subcategoryName = definition.subcategoryName
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == subcategoryName }
        )

        guard let subcategory = try? context.fetch(subcategoryDescriptor).first else {
            print("DevDataSeed: Warning - Subcategoría '\(subcategoryName)' no encontrada para presupuesto '\(definition.name)'")
            continue
        }

        let budget = Budget(
            currencyCode: preferredCurrency.rawValue,
            limitAmount: definition.limitAmount,
            name: definition.name,
            periodType: definition.periodType,
            subcategories: [subcategory],
            isActive: true,
            createdAt: Date()
        )
        context.insert(budget)
        budgets.append(budget)
    }

    return budgets
}

// MARK: - Favorite Payment Creation

/// Crea los pagos favoritos de desarrollo
private func createDevFavorites(in context: ModelContext) -> [FavoritePayment] {
    var favorites: [FavoritePayment] = []

    for definition in devFavoriteDefinitions {
        // Buscar la subcategoría por nombre
        let subcategoryName = definition.subcategoryName
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == subcategoryName }
        )

        guard let subcategory = try? context.fetch(subcategoryDescriptor).first else {
            print("DevDataSeed: Warning - Subcategoría '\(subcategoryName)' no encontrada para favorito '\(definition.name)'")
            continue
        }

        let favorite = FavoritePayment(
            name: definition.name,
            transactionType: definition.transactionType,
            amount: definition.amount,
            note: definition.note,
            account: nil,
            subcategory: subcategory,
            displayOrder: favorites.count
        )
        context.insert(favorite)
        favorites.append(favorite)
    }

    return favorites
}

// MARK: - Subscription Creation

/// Crea las suscripciones de desarrollo (paymentCategory = "subscription")
private func createDevSubscriptions(in context: ModelContext, preferredCurrency: CurrencyCode) -> [ScheduledPayment] {
    var subscriptions: [ScheduledPayment] = []

    let calendar = Calendar.current
    let today = Date()

    for definition in devSubscriptionDefinitions {
        // Buscar la subcategoría por nombre
        let subcategoryName = definition.subcategoryName
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == subcategoryName }
        )

        guard let subcategory = try? context.fetch(subcategoryDescriptor).first else {
            print("DevDataSeed: Warning - Subcategoría '\(subcategoryName)' no encontrada para suscripción '\(definition.name)'")
            continue
        }

        // Calcular nextDueDate: próximo día del mes especificado
        let currentDay = calendar.component(.day, from: today)
        var nextDueDate: Date
        if currentDay < definition.dayOfMonth {
            // Este mes
            nextDueDate = calendar.date(bySetting: .day, value: definition.dayOfMonth, of: today) ?? today
        } else {
            // Próximo mes
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) ?? today
            nextDueDate = calendar.date(bySetting: .day, value: definition.dayOfMonth, of: nextMonth) ?? today
        }

        let subscription = ScheduledPayment(
            name: definition.name,
            note: nil,
            amount: definition.amount,
            currencyCode: preferredCurrency.rawValue,
            transactionType: "expense",
            account: nil,
            subcategory: subcategory,
            isRecurring: true,
            recurrenceType: "monthly",
            recurrenceInterval: 1,
            nextDueDate: nextDueDate,
            dayOfMonth: definition.dayOfMonth,
            paymentCategory: "subscription",
            notifyOnDueDate: true,
            notifyDaysBefore: 1
        )
        context.insert(subscription)
        subscriptions.append(subscription)
    }

    return subscriptions
}

// MARK: - Scheduled Payment Creation

/// Crea los pagos planificados de desarrollo (paymentCategory = "recurring")
private func createDevScheduledPayments(in context: ModelContext, preferredCurrency: CurrencyCode) -> [ScheduledPayment] {
    var scheduledPayments: [ScheduledPayment] = []

    let calendar = Calendar.current
    let today = Date()

    for definition in devScheduledPaymentDefinitions {
        // Buscar la subcategoría por nombre
        let subcategoryName = definition.subcategoryName
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == subcategoryName }
        )

        guard let subcategory = try? context.fetch(subcategoryDescriptor).first else {
            print("DevDataSeed: Warning - Subcategoría '\(subcategoryName)' no encontrada para pago planificado '\(definition.name)'")
            continue
        }

        // Calcular nextDueDate: próximo día del mes especificado
        let currentDay = calendar.component(.day, from: today)
        var nextDueDate: Date
        if currentDay < definition.dayOfMonth {
            // Este mes
            nextDueDate = calendar.date(bySetting: .day, value: definition.dayOfMonth, of: today) ?? today
        } else {
            // Próximo mes
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) ?? today
            nextDueDate = calendar.date(bySetting: .day, value: definition.dayOfMonth, of: nextMonth) ?? today
        }

        let scheduledPayment = ScheduledPayment(
            name: definition.name,
            note: definition.note,
            amount: definition.amount,
            currencyCode: preferredCurrency.rawValue,
            transactionType: "expense",
            account: nil,
            subcategory: subcategory,
            isRecurring: true,
            recurrenceType: "monthly",
            recurrenceInterval: 1,
            nextDueDate: nextDueDate,
            dayOfMonth: definition.dayOfMonth,
            paymentCategory: "recurring",
            notifyOnDueDate: true,
            notifyDaysBefore: 3
        )
        context.insert(scheduledPayment)
        scheduledPayments.append(scheduledPayment)
    }

    return scheduledPayments
}

// MARK: - Historical Transaction Generation (8a)

/// Genera transacciones históricas basadas en suscripciones y pagos planificados
/// Período: Nov-Dic 2024 + Todo 2025 + Ene 2026 hasta hoy
private func generateScheduledPaymentTransactions(
    in context: ModelContext,
    subscriptions: [ScheduledPayment],
    scheduledPayments: [ScheduledPayment],
    accounts: [Account],
    preferredCurrency: CurrencyCode
) -> Int {
    let calendar = Calendar.current
    let today = Date()

    // Definir rango de fechas: Nov 1, 2024 hasta hoy
    let startDate = calendar.date(from: DateComponents(year: 2024, month: 11, day: 1))!

    var transactionCount = 0
    let allScheduled = subscriptions + scheduledPayments

    // Seleccionar cuenta por defecto (primera cuenta de la moneda preferida)
    guard let defaultAccount = accounts.first(where: { $0.currencyCode == preferredCurrency.rawValue }) ?? accounts.first else {
        print("DevDataSeed: No hay cuentas disponibles para generar transacciones")
        return 0
    }

    // Para cada pago/suscripción, generar transacciones históricas
    for payment in allScheduled {
        guard let dayOfMonth = payment.dayOfMonth,
              let subcategory = payment.subcategory else {
            continue
        }

        // Generar transacciones mensuales desde startDate hasta hoy
        var currentDate = startDate
        while currentDate <= today {
            // Crear fecha para el día específico del mes
            let targetDay = min(dayOfMonth, calendar.range(of: .day, in: .month, for: currentDate)?.count ?? 28)
            if let transactionDate = calendar.date(bySetting: .day, value: targetDay, of: currentDate),
               transactionDate <= today {

                let transaction = TransactionItem(
                    date: transactionDate,
                    amount: payment.amount,
                    currencyCode: payment.currencyCode,
                    note: nil,
                    category: subcategory.category,
                    subcategory: subcategory,
                    account: defaultAccount,
                    exchangeRate: 1.0,
                    amountInPreferredCurrency: payment.amount,
                    preferredCurrencyCode: preferredCurrency.rawValue,
                    isExchangeRateProvisional: false
                )
                context.insert(transaction)
                transactionCount += 1
            }

            // Avanzar al siguiente mes
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? today.addingTimeInterval(86400 * 365)
        }
    }

    return transactionCount
}

// MARK: - Varied Daily Transactions (8b)

/// Genera transacciones variadas del día a día
/// Objetivo: 30-50 transacciones por mes
private func generateVariedDailyTransactions(
    in context: ModelContext,
    accounts: [Account],
    tags: [Tag],
    preferredCurrency: CurrencyCode
) -> Int {
    let calendar = Calendar.current
    let today = Date()

    // Definir rango de fechas: Nov 1, 2024 hasta hoy
    let startDate = calendar.date(from: DateComponents(year: 2024, month: 11, day: 1))!

    var transactionCount = 0

    // Definir tipos de transacciones variadas con sus subcategorías
    let variedTransactionTemplates: [(subcategoryName: String, amountRange: ClosedRange<Double>, frequency: Int)] = [
        // Alimentación (más frecuentes)
        ("Supermercados y bodegas", 50...200, 8),  // ~8 por mes
        ("Restaurantes", 15...60, 12),              // ~12 por mes
        ("Delivery", 25...80, 6),                   // ~6 por mes

        // Transporte (frecuentes)
        ("Taxis y apps", 10...35, 10),              // ~10 por mes
        ("Transporte público", 3...8, 15),          // ~15 por mes

        // Compras (moderado)
        ("Farmacia y botiquín", 20...100, 3),       // ~3 por mes
        ("Ropa y calzado", 80...300, 2),            // ~2 por mes
        ("Tecnología y accesorios", 100...500, 1),  // ~1 por mes

        // Entretenimiento (moderado)
        ("Bares y salidas sociales", 40...120, 4),  // ~4 por mes
        ("Deportes y recreación", 30...100, 2),     // ~2 por mes

        // Personal (menos frecuente)
        ("Cuidado personal y belleza", 30...80, 2), // ~2 por mes
        ("Hobbies y gaming", 50...200, 1),          // ~1 por mes
    ]

    // Fetch todas las subcategorías necesarias
    var subcategoryMap: [String: Subcategory] = [:]
    for template in variedTransactionTemplates {
        let subcategoryName = template.subcategoryName
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == subcategoryName }
        )
        if let subcategory = try? context.fetch(descriptor).first {
            subcategoryMap[subcategoryName] = subcategory
        }
    }

    // Seleccionar cuenta por defecto
    guard let defaultAccount = accounts.first(where: { $0.currencyCode == preferredCurrency.rawValue }) ?? accounts.first else {
        return 0
    }

    // Generar transacciones mes por mes
    var currentMonth = startDate
    while currentMonth <= today {
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(byAdding: .month, value: 1, to: currentMonth)!) ?? today

        // Para cada tipo de transacción, generar según frecuencia
        for template in variedTransactionTemplates {
            guard let subcategory = subcategoryMap[template.subcategoryName] else { continue }

            // Generar N transacciones en el mes
            for _ in 0..<template.frequency {
                // Fecha aleatoria en el mes
                let dayOffset = Int.random(in: 0...min(27, calendar.component(.day, from: monthEnd) - 1))
                guard let transactionDate = calendar.date(byAdding: .day, value: dayOffset, to: currentMonth),
                      transactionDate <= today else {
                    continue
                }

                // Monto aleatorio en el rango
                let amount = Double.random(in: template.amountRange)
                let roundedAmount = round(amount * 100) / 100

                // Tag aleatorio (30% de probabilidad)
                let randomTags = Bool.random() && Double.random(in: 0...1) < 0.3 && !tags.isEmpty ? [tags.randomElement()!] : []

                let transaction = TransactionItem(
                    date: transactionDate,
                    amount: roundedAmount,
                    currencyCode: preferredCurrency.rawValue,
                    note: nil,
                    category: subcategory.category,
                    subcategory: subcategory,
                    account: defaultAccount,
                    tags: randomTags,
                    exchangeRate: 1.0,
                    amountInPreferredCurrency: roundedAmount,
                    preferredCurrencyCode: preferredCurrency.rawValue,
                    isExchangeRateProvisional: false
                )
                context.insert(transaction)
                transactionCount += 1
            }
        }

        // Avanzar al siguiente mes
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? today.addingTimeInterval(86400 * 365)
    }

    return transactionCount
}

#endif
