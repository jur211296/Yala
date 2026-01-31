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
//  - Proporciona datos de prueba 100% realistas
//  - Cubre TODAS las subcategorías de gastos (53)
//  - Incluye 4 tipos de ingresos
//  - Distribuye transacciones entre 3 cuentas
//  - Usa monedas según cuenta (PEN, USD)
//  - Exchange rates realistas con variación temporal
//  - Notas realistas en 30% de transacciones
//  - Meses buenos/malos con variación en montos
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
    let type: String
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
    let periodType: String
    let limitAmount: Double
    let subcategoryName: String
}

/// Definición de un favorito para el seed
private struct FavoriteSeedDefinition {
    let name: String
    let transactionType: String
    let amount: Double?
    let subcategoryName: String
    let note: String?
}

/// Definición de una suscripción para el seed
private struct SubscriptionSeedDefinition {
    let name: String
    let amount: Double
    let currencyCode: String
    let dayOfMonth: Int
    let subcategoryName: String
    let accountType: String  // "BCP", "USD", "Efectivo"
}

/// Definición de un pago planificado para el seed
private struct ScheduledPaymentSeedDefinition {
    let name: String
    let amount: Double
    let currencyCode: String
    let dayOfMonth: Int
    let subcategoryName: String
    let note: String?
    let accountType: String
    let variationPercent: Double?  // ±% para servicios variables
}

/// Template de transacción variable
private struct TransactionTemplate {
    let subcategoryName: String
    let amountRange: ClosedRange<Double>
    let frequency: Int  // Transacciones por mes
    let accountDistribution: [String: Double]  // "BCP": 0.5, "Efectivo": 0.3, "USD": 0.2
    let currencyByAccount: [String: String]  // "BCP": "PEN", "USD": "USD"
    let possibleNotes: [String]
}

/// Definición de ingreso
private struct IncomeDefinition {
    let subcategoryName: String
    let baseAmount: Double
    let frequency: Double  // 1.0 = mensual, 0.5 = cada 2 meses, etc.
    let dayOfMonth: Int?  // nil = aleatorio
    let accountType: String
    let currencyCode: String
    let possibleNotes: [String]
    let variationType: IncomeVariationType
}

enum IncomeVariationType {
    case fixed  // Monto fijo
    case bonusMonths([Int])  // Meses con bonus (ej: [7, 12] = Jul, Dic)
    case random(range: ClosedRange<Double>)  // Rango aleatorio
}

// MARK: - Account Lookup Helper

/// Busca una cuenta según su tipo lógico.
/// - Parameter type: "USD" para cuenta en dólares, "BCP" para cuenta principal, "Efectivo" para efectivo
/// - Parameter accounts: Lista de cuentas disponibles
/// - Returns: La cuenta encontrada o nil
private func findAccount(byType type: String, in accounts: [Account]) -> Account? {
    switch type {
    case "USD":
        return accounts.first { $0.currencyCode == "USD" }
    case "BCP":
        return accounts.first { $0.name.contains("BCP") }
    case "Efectivo":
        return accounts.first { $0.name.contains("Efectivo") }
    default:
        return accounts.first
    }
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

// NOTA SOBRE PRESUPUESTOS:
// Algunos presupuestos están INTENCIONALMENTE configurados con límites bajos
// para que sean excedidos por las transacciones generadas. Esto permite probar:
// - Alertas de presupuesto excedido
// - Indicadores visuales de exceso (rojo vs verde)
// - Mensajes de advertencia en el dashboard
//
// Estado esperado de presupuestos:
// | Presupuesto            | Límite  | Gasto estimado | Estado esperado |
// |------------------------|---------|----------------|-----------------|
// | Alimentación mensual   | S/1200  | ~S/1500-1800   | ⚠️ Excedido     |
// | Entretenimiento        | S/300   | ~S/400-600     | ⚠️ Excedido     |
// | Transporte mensual     | S/250   | ~S/200-300     | ✅ Cerca límite |
// | Hogar mensual          | S/800   | ~S/400-500     | ✅ Bajo control |

private let devBudgetDefinitions: [BudgetSeedDefinition] = [
    BudgetSeedDefinition(
        name: "Alimentación mensual",
        periodType: "monthly",
        limitAmount: 1200.0,  // Intencionalmente bajo para probar alertas
        subcategoryName: "Supermercados y bodegas"
    ),
    BudgetSeedDefinition(
        name: "Entretenimiento mensual",
        periodType: "monthly",
        limitAmount: 300.0,  // Intencionalmente bajo para probar alertas
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
    BudgetSeedDefinition(
        name: "Café diario",
        periodType: "daily",
        limitAmount: 15.0,
        subcategoryName: "Restaurantes"
    ),
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
    SubscriptionSeedDefinition(
        name: "Netflix",
        amount: 12.99,
        currencyCode: "USD",
        dayOfMonth: 1,
        subcategoryName: "Streaming y plataformas",
        accountType: "USD"
    ),
    SubscriptionSeedDefinition(
        name: "Spotify",
        amount: 9.99,
        currencyCode: "USD",
        dayOfMonth: 1,
        subcategoryName: "Streaming y plataformas",
        accountType: "USD"
    ),
    SubscriptionSeedDefinition(
        name: "Amazon Prime",
        amount: 35.00,
        currencyCode: "PEN",
        dayOfMonth: 10,
        subcategoryName: "Streaming y plataformas",
        accountType: "BCP"
    ),
    SubscriptionSeedDefinition(
        name: "Gym",
        amount: 150.00,
        currencyCode: "PEN",
        dayOfMonth: 15,
        subcategoryName: "Fitness y actividad física",
        accountType: "BCP"
    ),
    SubscriptionSeedDefinition(
        name: "iCloud Storage",
        amount: 2.99,
        currencyCode: "USD",
        dayOfMonth: 25,
        subcategoryName: "Suscripciones de utilidad",
        accountType: "USD"
    ),
]

private let devScheduledPaymentDefinitions: [ScheduledPaymentSeedDefinition] = [
    ScheduledPaymentSeedDefinition(
        name: "Alquiler",
        amount: 1500.00,
        currencyCode: "PEN",
        dayOfMonth: 5,
        subcategoryName: "Alquiler o hipoteca",
        note: "Pago mensual de alquiler",
        accountType: "BCP",
        variationPercent: nil
    ),
    ScheduledPaymentSeedDefinition(
        name: "Internet Movistar",
        amount: 99.00,
        currencyCode: "PEN",
        dayOfMonth: 8,
        subcategoryName: "Servicios del hogar",
        note: "300 Mbps",
        accountType: "BCP",
        variationPercent: nil
    ),
    ScheduledPaymentSeedDefinition(
        name: "Luz Enel",
        amount: 120.00,
        currencyCode: "PEN",
        dayOfMonth: 12,
        subcategoryName: "Servicios del hogar",
        note: nil,
        accountType: "BCP",
        variationPercent: 0.20  // ±20%
    ),
    ScheduledPaymentSeedDefinition(
        name: "Agua Sedapal",
        amount: 60.00,
        currencyCode: "PEN",
        dayOfMonth: 12,
        subcategoryName: "Servicios del hogar",
        note: nil,
        accountType: "BCP",
        variationPercent: 0.20  // ±20%
    ),
    ScheduledPaymentSeedDefinition(
        name: "Teléfono Claro",
        amount: 55.00,
        currencyCode: "PEN",
        dayOfMonth: 20,
        subcategoryName: "Telefonía y comunicaciones",
        note: "Plan móvil",
        accountType: "BCP",
        variationPercent: nil
    ),
    ScheduledPaymentSeedDefinition(
        name: "Seguro del hogar",
        amount: 120.00,
        currencyCode: "PEN",
        dayOfMonth: 28,
        subcategoryName: "Seguro del hogar",
        note: "Póliza mensual",
        accountType: "BCP",
        variationPercent: nil
    ),
    ScheduledPaymentSeedDefinition(
        name: "AFP",
        amount: 650.00,
        currencyCode: "PEN",
        dayOfMonth: 30,
        subcategoryName: "Pensiones y aportes",
        note: "Aporte mensual",
        accountType: "BCP",
        variationPercent: nil
    ),
    ScheduledPaymentSeedDefinition(
        name: "Préstamo personal",
        amount: 450.00,
        currencyCode: "PEN",
        dayOfMonth: 15,
        subcategoryName: "Préstamos y créditos",
        note: "Cuota mensual",
        accountType: "BCP",
        variationPercent: nil
    ),
    ScheduledPaymentSeedDefinition(
        name: "Leasing auto",
        amount: 1000.00,
        currencyCode: "PEN",
        dayOfMonth: 20,
        subcategoryName: "Leasing",
        note: "Cuota mensual leasing",
        accountType: "BCP",
        variationPercent: nil
    ),
    ScheduledPaymentSeedDefinition(
        name: "Préstamo vehicular",
        amount: 750.00,
        currencyCode: "PEN",
        dayOfMonth: 25,
        subcategoryName: "Préstamo vehicular",
        note: "Cuota crédito auto",
        accountType: "BCP",
        variationPercent: nil
    ),
]

// MARK: - Income Definitions (4+ tipos)

private let devIncomeDefinitions: [IncomeDefinition] = [
    // 1. Salario (mensual fijo con aguinaldos en Jul y Dic)
    IncomeDefinition(
        subcategoryName: "Salario",
        baseAmount: 6500.00,
        frequency: 1.0,
        dayOfMonth: 30,
        accountType: "BCP",
        currencyCode: "PEN",
        possibleNotes: ["Salario mensual", "Pago mensual"],
        variationType: .bonusMonths([7, 12])  // Aguinaldo en Julio y Diciembre
    ),

    // 2. Facturación y freelance (ocasional, monto variable)
    IncomeDefinition(
        subcategoryName: "Facturación y freelance",
        baseAmount: 0,  // No usado con random
        frequency: 0.4,  // 40% de meses
        dayOfMonth: nil,
        accountType: "BCP",
        currencyCode: "PEN",
        possibleNotes: [
            "Proyecto web cliente",
            "Consultoría IT",
            "Desarrollo app móvil",
            "Diseño logo empresa",
            "Mantenimiento sistema"
        ],
        variationType: .random(range: 800...2500)
    ),

    // 3. Reembolsos (esporádico, monto variable)
    IncomeDefinition(
        subcategoryName: "Reembolsos",
        baseAmount: 0,
        frequency: 0.3,  // 30% de meses
        dayOfMonth: nil,
        accountType: "BCP",
        currencyCode: "PEN",
        possibleNotes: [
            "Reembolso gastos médicos",
            "Devolución compra defectuosa",
            "Reembolso trabajo",
            "Ajuste facturación"
        ],
        variationType: .random(range: 50...400)
    ),

    // 4. Regalos y otros ingresos (ocasional)
    IncomeDefinition(
        subcategoryName: "Regalos y otros ingresos",
        baseAmount: 0,
        frequency: 0.2,  // 20% de meses
        dayOfMonth: nil,
        accountType: "Efectivo",  // Los regalos suelen ser en efectivo
        currencyCode: "PEN",
        possibleNotes: [
            "Regalo cumpleaños",
            "Propina extraordinaria",
            "Venta artículo usado",
            "Premio sorteo"
        ],
        variationType: .random(range: 100...800)
    ),
]

// MARK: - Transaction Templates (TODAS las subcategorías de gastos)

private func createAllTransactionTemplates() -> [TransactionTemplate] {
    return [
        // ALIMENTACIÓN (4)
        TransactionTemplate(
            subcategoryName: "Delivery",
            amountRange: 25...80,
            frequency: 6,
            accountDistribution: ["BCP": 0.7, "Efectivo": 0.3],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Rappi almuerzo", "PedidosYa cena", "Uber Eats", "Delivery sushi", "Pizza familiar"]
        ),
        TransactionTemplate(
            subcategoryName: "Restaurantes",
            amountRange: 30...120,
            frequency: 10,
            accountDistribution: ["BCP": 0.8, "Efectivo": 0.2],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Almuerzo trabajo", "Cena fin de semana", "Brunch dominical", "Comida china", "Menú ejecutivo"]
        ),
        TransactionTemplate(
            subcategoryName: "Suplementos alimenticios",
            amountRange: 40...150,
            frequency: 1,
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["Proteína whey", "Vitaminas", "Omega 3", "Multivitamínico"]
        ),
        TransactionTemplate(
            subcategoryName: "Supermercados y bodegas",
            amountRange: 20...250,
            frequency: 12,
            accountDistribution: ["Efectivo": 0.6, "BCP": 0.4],
            currencyByAccount: ["Efectivo": "PEN", "BCP": "PEN"],
            possibleNotes: ["Compra semanal", "Metro", "Bodega esquina", "Plaza Vea", "Compra mensual grande"]
        ),

        // COMPRAS (7)
        TransactionTemplate(
            subcategoryName: "Cuidado personal y belleza",
            amountRange: 30...120,
            frequency: 2,
            accountDistribution: ["BCP": 0.9, "Efectivo": 0.1],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Shampoo y productos", "Cremas faciales", "Perfume", "Artículos aseo"]
        ),
        TransactionTemplate(
            subcategoryName: "Farmacia y botiquín",
            amountRange: 20...150,
            frequency: 3,
            accountDistribution: ["BCP": 0.7, "Efectivo": 0.3],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Medicamentos", "Inkafarma", "Mifarma", "Botiquín casa", "Analgésicos"]
        ),
        TransactionTemplate(
            subcategoryName: "Hogar y decoración",
            amountRange: 80...400,
            frequency: 1,
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["Cortinas nuevas", "Cuadros decorativos", "Plantas", "Organizadores", "Almohadas"]
        ),
        TransactionTemplate(
            subcategoryName: "Otros",
            amountRange: 30...200,
            frequency: 2,
            accountDistribution: ["BCP": 0.8, "Efectivo": 0.2],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Varios", "Compra emergencia", "Artículos varios"]
        ),
        TransactionTemplate(
            subcategoryName: "Regalos y detalles",
            amountRange: 50...300,
            frequency: 2,
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["Regalo cumpleaños", "Detalles familia", "Regalo amigo secreto", "Flores", "Chocolates"]
        ),
        TransactionTemplate(
            subcategoryName: "Ropa y calzado",
            amountRange: 80...500,
            frequency: 2,
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["Zapatos nuevos", "Polos trabajo", "Jeans", "Ropa sport", "Zapatillas"]
        ),
        TransactionTemplate(
            subcategoryName: "Tecnología y accesorios",
            amountRange: 100...800,
            frequency: 1,
            accountDistribution: ["BCP": 0.8, "USD": 0.2],
            currencyByAccount: ["BCP": "PEN", "USD": "USD"],
            possibleNotes: ["Auriculares Bluetooth", "Mouse gaming", "Cable USB-C", "Funda laptop", "Teclado mecánico"]
        ),

        // TRANSPORTE (3)
        TransactionTemplate(
            subcategoryName: "Movilidad ocasional",
            amountRange: 15...50,
            frequency: 4,
            accountDistribution: ["Efectivo": 0.8, "BCP": 0.2],
            currencyByAccount: ["Efectivo": "PEN", "BCP": "PEN"],
            possibleNotes: ["Scooter eléctrico", "Bicicleta compartida", "Moto taxi", "Movilidad especial"]
        ),
        TransactionTemplate(
            subcategoryName: "Taxis y apps",
            amountRange: 10...45,
            frequency: 12,
            accountDistribution: ["BCP": 0.7, "Efectivo": 0.3],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Uber trabajo", "Taxi nocturno", "Beat", "InDriver", "Cabify"]
        ),
        TransactionTemplate(
            subcategoryName: "Transporte público",
            amountRange: 2.5...8,
            frequency: 18,
            accountDistribution: ["Efectivo": 0.95, "BCP": 0.05],
            currencyByAccount: ["Efectivo": "PEN", "BCP": "PEN"],
            possibleNotes: ["Metropolitano", "Bus", "Combi", "Corredor", "Pasaje diario"]
        ),

        // FINANZAS (5)
        TransactionTemplate(
            subcategoryName: "Comisiones y cargos",
            amountRange: 5...35,
            frequency: 2,
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["Comisión transferencia", "Cargo mantenimiento", "Comisión banco", "Cargo tarjeta"]
        ),
        // Impuestos: Manejado en generateSpecialTransactions() - solo en Marzo
        // (frequency: 0 para evitar generación automática)
        TransactionTemplate(
            subcategoryName: "Seguros",
            amountRange: 80...200,
            frequency: 1,
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["Seguro vida", "Seguro salud", "Seguro SOAT", "Póliza personal"]
        ),

        // HOGAR (6) - Algunos ya en scheduled payments
        TransactionTemplate(
            subcategoryName: "Mantenimiento y reparaciones",
            amountRange: 80...400,
            frequency: 2, // 1.5 redondeado
            accountDistribution: ["BCP": 0.8, "Efectivo": 0.2],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Gasfitero", "Pintura pared", "Reparación puerta", "Electricista", "Arreglo mueble"]
        ),
        TransactionTemplate(
            subcategoryName: "Personal de apoyo",
            amountRange: 100...300,
            frequency: 2,
            accountDistribution: ["Efectivo": 0.7, "BCP": 0.3],
            currencyByAccount: ["Efectivo": "PEN", "BCP": "PEN"],
            possibleNotes: ["Limpieza casa", "Jardinero", "Ayuda doméstica", "Plomero"]
        ),

        // ENTRETENIMIENTO (8)
        TransactionTemplate(
            subcategoryName: "Bares y salidas sociales",
            amountRange: 40...180,
            frequency: 5,
            accountDistribution: ["BCP": 0.6, "Efectivo": 0.4],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Cerveza fin de semana", "After office", "Bar Barranco", "Drinks amigos", "Terraza"]
        ),
        TransactionTemplate(
            subcategoryName: "Deportes y recreación",
            amountRange: 30...150,
            frequency: 3,
            accountDistribution: ["BCP": 0.9, "Efectivo": 0.1],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Partido fútbol", "Alquiler cancha", "Clase tenis", "Entrada parque"]
        ),
        TransactionTemplate(
            subcategoryName: "Espectáculos y eventos",
            amountRange: 50...300,
            frequency: 2, // 1.5 redondeado
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["Concierto", "Teatro", "Stand up comedy", "Cine premium", "Festival"]
        ),
        TransactionTemplate(
            subcategoryName: "Fiestas y vida nocturna",
            amountRange: 80...250,
            frequency: 2,
            accountDistribution: ["BCP": 0.7, "Efectivo": 0.3],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Discoteca", "Club nocturno", "Fiesta privada", "Cover club", "Salida nocturna"]
        ),
        TransactionTemplate(
            subcategoryName: "Hobbies y gaming",
            amountRange: 50...300,
            frequency: 2,
            accountDistribution: ["BCP": 0.8, "USD": 0.2],
            currencyByAccount: ["BCP": "PEN", "USD": "USD"],
            possibleNotes: ["Juego PS5", "Steam", "Nintendo eShop", "Suscripción Xbox", "DLC juego"]
        ),
        TransactionTemplate(
            subcategoryName: "Salidas en pareja",
            amountRange: 80...250,
            frequency: 3,
            accountDistribution: ["BCP": 0.9, "Efectivo": 0.1],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Cena romántica", "Cine pareja", "Paseo Larcomar", "Café especial", "Día especial"]
        ),
        // Viajes y vacaciones: Manejado en generateSpecialTransactions() - Agosto y Diciembre
        // (frequency: 0 para evitar generación automática)

        // PERSONAL (8)
        TransactionTemplate(
            subcategoryName: "Asesorías y trámites",
            amountRange: 80...300,
            frequency: 1, // 0.5 redondeado
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["Contador", "Abogado consulta", "Trámite notarial", "Gestoría", "Asesoría legal"]
        ),
        TransactionTemplate(
            subcategoryName: "Belleza y estética",
            amountRange: 40...150,
            frequency: 2,
            accountDistribution: ["BCP": 0.8, "Efectivo": 0.2],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Corte cabello", "Barbería", "Manicure", "Spa facial", "Tratamiento estético"]
        ),
        TransactionTemplate(
            subcategoryName: "Educación y desarrollo",
            amountRange: 100...600,
            frequency: 2, // 1.5 redondeado
            accountDistribution: ["BCP": 0.9, "USD": 0.1],
            currencyByAccount: ["BCP": "PEN", "USD": "USD"],
            possibleNotes: ["Curso online Udemy", "Clase inglés", "Certificación", "Libro técnico", "Taller"]
        ),
        TransactionTemplate(
            subcategoryName: "Salud y atención médica",
            amountRange: 50...400,
            frequency: 2,
            accountDistribution: ["BCP": 0.9, "Efectivo": 0.1],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Consulta médica", "Dentista", "Exámenes laboratorio", "Oftalmólogo", "Terapia"]
        ),
        TransactionTemplate(
            subcategoryName: "Suscripciones de ocio",
            amountRange: 20...80,
            frequency: 2,
            accountDistribution: ["BCP": 0.7, "USD": 0.3],
            currencyByAccount: ["BCP": "PEN", "USD": "USD"],
            possibleNotes: ["Revista digital", "App premium", "Audible", "Kindle Unlimited", "Patreon"]
        ),

        // MASCOTAS (4)
        TransactionTemplate(
            subcategoryName: "Accesorios y juguetes",
            amountRange: 30...120,
            frequency: 1, // 0.5 redondeado
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["Juguete perro", "Collar nuevo", "Cama mascota", "Plato comedero"]
        ),
        TransactionTemplate(
            subcategoryName: "Alimentación de mascotas",
            amountRange: 80...200,
            frequency: 2,
            accountDistribution: ["BCP": 0.8, "Efectivo": 0.2],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Alimento balanceado", "Croquetas perro", "Comida gato", "Snacks mascota"]
        ),
        TransactionTemplate(
            subcategoryName: "Salud veterinaria",
            amountRange: 100...400,
            frequency: 1,
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["Veterinario revisión", "Vacunas", "Desparasitación", "Consulta urgencia", "Medicamento"]
        ),
        TransactionTemplate(
            subcategoryName: "Servicios y cuidados",
            amountRange: 40...150,
            frequency: 2, // 1.5 redondeado
            accountDistribution: ["BCP": 0.7, "Efectivo": 0.3],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Peluquería canina", "Baño mascota", "Guardería perro", "Paseador", "Grooming"]
        ),

        // VEHÍCULO (6)
        TransactionTemplate(
            subcategoryName: "Combustible",
            amountRange: 80...200,
            frequency: 4,
            accountDistribution: ["BCP": 0.9, "Efectivo": 0.1],
            currencyByAccount: ["BCP": "PEN", "Efectivo": "PEN"],
            possibleNotes: ["Gasolina 90", "Gasolina 95", "Primax", "Repsol", "Tanque lleno"]
        ),
        TransactionTemplate(
            subcategoryName: "Estacionamientos",
            amountRange: 5...30,
            frequency: 8,
            accountDistribution: ["Efectivo": 0.6, "BCP": 0.4],
            currencyByAccount: ["Efectivo": "PEN", "BCP": "PEN"],
            possibleNotes: ["Parking centro", "Estacionamiento mall", "Parqueo calle", "Valet"]
        ),
        // Leasing: Ahora manejado por devScheduledPaymentDefinitions
        TransactionTemplate(
            subcategoryName: "Mantenimiento del vehículo",
            amountRange: 150...600,
            frequency: 1, // 0.5 redondeado
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["Cambio aceite", "Revisión técnica", "Alineación balanceo", "Cambio llantas", "Frenos"]
        ),
        // Préstamo vehicular: Ahora manejado por devScheduledPaymentDefinitions
        TransactionTemplate(
            subcategoryName: "Seguro vehicular",
            amountRange: 180...250,
            frequency: 1,
            accountDistribution: ["BCP": 1.0],
            currencyByAccount: ["BCP": "PEN"],
            possibleNotes: ["SOAT", "Seguro todo riesgo", "Póliza vehicular mensual"]
        ),
    ]
}

// MARK: - Exchange Rate Helper

/// Monthly exchange rate data for realistic PEN/USD rates
private let monthlyExchangeRates: [(year: Int, month: Int, rate: Double)] = [
    // 2024
    (2024, 11, 3.75),  // Nov
    (2024, 12, 3.77),  // Dic
    // 2025
    (2025, 1, 3.76),
    (2025, 2, 3.78),
    (2025, 3, 3.77),
    (2025, 4, 3.79),
    (2025, 5, 3.78),
    (2025, 6, 3.76),
    (2025, 7, 3.75),
    (2025, 8, 3.77),
    (2025, 9, 3.78),
    (2025, 10, 3.79),
    (2025, 11, 3.77),
    (2025, 12, 3.76),
    // 2026
    (2026, 1, 3.78),
    (2026, 2, 3.77),
    (2026, 3, 3.79),
]

/// Seeds ExchangeRate entities for each month from Nov 2024 to today.
/// Uses the same format as ExchangeRateService (base USD, rates as JSON).
private func seedExchangeRates(in context: ModelContext) -> Int {
    let calendar = Calendar.current
    var count = 0

    for entry in monthlyExchangeRates {
        // Create date key in format "yyyy-MM-dd" for the first day of each month
        guard let monthDate = calendar.date(from: DateComponents(
            year: entry.year,
            month: entry.month,
            day: 1
        )) else { continue }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: monthDate)

        // Create rates dictionary with PEN rate (base is USD)
        // If base is USD, rate for PEN means 1 USD = X PEN
        let ratesDictionary: [String: Double] = ["PEN": entry.rate]

        do {
            let exchangeRate = try ExchangeRate(
                dateKey: dateKey,
                base: "USD",
                ratesDictionary: ratesDictionary,
                timestamp: monthDate
            )
            context.insert(exchangeRate)
            count += 1
        } catch {
            print("DevDataSeed: Error creating ExchangeRate for \(dateKey): \(error)")
        }
    }

    return count
}

/// Gets exchange rate for a date from seeded data (fallback to hardcoded if not found).
/// Returns the PEN/USD rate for the given date's month.
private func getExchangeRate(for date: Date, from context: ModelContext? = nil) -> Double {
    let calendar = Calendar.current
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)

    // Try to find in seeded data first
    if let entry = monthlyExchangeRates.first(where: { $0.year == year && $0.month == month }) {
        return entry.rate
    }

    // Fallback for dates outside seeded range
    return 3.77
}

// MARK: - Main Seed Function

/// Ejecuta la semilla de datos de desarrollo solo si está habilitado.
func seedDevDataIfEnabled(in context: ModelContext, preferredCurrency: CurrencyCode) {
    print("DevDataSeed: Iniciando semilla de datos de desarrollo...")

    // Seed exchange rates first (used by transaction generation)
    let exchangeRatesCount = seedExchangeRates(in: context)
    print("DevDataSeed: \(exchangeRatesCount) tipos de cambio creados")

    // Create accounts
    let createdAccounts = createDevAccounts(in: context)
    print("DevDataSeed: \(createdAccounts.count) cuentas creadas")

    // Create tags
    let createdTags = createDevTags(in: context)
    print("DevDataSeed: \(createdTags.count) etiquetas creadas")

    // Create budgets
    let createdBudgets = createDevBudgets(in: context, preferredCurrency: preferredCurrency)
    print("DevDataSeed: \(createdBudgets.count) presupuestos creados")

    // Create favorite payments
    let createdFavorites = createDevFavorites(in: context)
    print("DevDataSeed: \(createdFavorites.count) favoritos creados")

    // Create subscriptions
    let createdSubscriptions = createDevSubscriptions(in: context, accounts: createdAccounts)
    print("DevDataSeed: \(createdSubscriptions.count) suscripciones creadas")

    // Create scheduled payments
    let createdScheduledPayments = createDevScheduledPayments(in: context, accounts: createdAccounts)
    print("DevDataSeed: \(createdScheduledPayments.count) pagos planificados creados")

    // Generate income transactions (4 types)
    let incomeCount = generateIncomeTransactions(
        in: context,
        accounts: createdAccounts,
        preferredCurrency: preferredCurrency
    )
    print("DevDataSeed: \(incomeCount) transacciones de ingresos generadas")

    // Generate scheduled payment transactions (from suscriptions and scheduled payments)
    let scheduledCount = generateScheduledPaymentTransactions(
        in: context,
        subscriptions: createdSubscriptions,
        scheduledPayments: createdScheduledPayments,
        accounts: createdAccounts,
        preferredCurrency: preferredCurrency
    )
    print("DevDataSeed: \(scheduledCount) transacciones de pagos recurrentes generadas")

    // Generate varied transactions (ALL subcategories)
    let variedCount = generateVariedTransactions(
        in: context,
        accounts: createdAccounts,
        tags: createdTags,
        preferredCurrency: preferredCurrency
    )
    print("DevDataSeed: \(variedCount) transacciones variadas generadas")

    // Generate special transactions (impuestos, viajes)
    let specialCount = generateSpecialTransactions(
        in: context,
        accounts: createdAccounts,
        preferredCurrency: preferredCurrency
    )
    print("DevDataSeed: \(specialCount) transacciones especiales generadas")

    // Generate transfers between accounts
    let transferCount = generateTransfers(
        in: context,
        accounts: createdAccounts,
        preferredCurrency: preferredCurrency
    )
    print("DevDataSeed: \(transferCount) transferencias entre cuentas generadas")

    // Save all changes
    do {
        try context.save()
        let totalTransactions = incomeCount + scheduledCount + variedCount + specialCount + transferCount
        print("DevDataSeed: ✅ Semilla completada exitosamente")
        print("DevDataSeed: === Resumen de entidades creadas ===")
        print("DevDataSeed:   - Tipos de cambio: \(exchangeRatesCount)")
        print("DevDataSeed:   - Cuentas: \(createdAccounts.count)")
        print("DevDataSeed:   - Etiquetas: \(createdTags.count)")
        print("DevDataSeed:   - Presupuestos: \(createdBudgets.count)")
        print("DevDataSeed:   - Favoritos: \(createdFavorites.count)")
        print("DevDataSeed:   - Suscripciones: \(createdSubscriptions.count)")
        print("DevDataSeed:   - Pagos planificados: \(createdScheduledPayments.count)")
        print("DevDataSeed: === Resumen de transacciones ===")
        print("DevDataSeed:   - Ingresos: \(incomeCount)")
        print("DevDataSeed:   - Pagos recurrentes: \(scheduledCount)")
        print("DevDataSeed:   - Gastos variados: \(variedCount)")
        print("DevDataSeed:   - Especiales (impuestos/viajes): \(specialCount)")
        print("DevDataSeed:   - Transferencias: \(transferCount)")
        print("DevDataSeed:   - TOTAL TRANSACCIONES: \(totalTransactions)")
    } catch {
        print("DevDataSeed: ❌ Error crítico al guardar la semilla: \(error)")
        print("DevDataSeed: Las entidades creadas en memoria no se persistieron.")
        // Note: SwiftData no soporta rollback explícito, pero al no guardar,
        // las entidades no persistirán si la app se cierra
    }
}

// MARK: - Account Creation

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

private func createDevBudgets(in context: ModelContext, preferredCurrency: CurrencyCode) -> [Budget] {
    var budgets: [Budget] = []

    for definition in devBudgetDefinitions {
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == definition.subcategoryName }
        )

        guard let subcategory = try? context.fetch(subcategoryDescriptor).first else {
            print("DevDataSeed: Warning - Subcategoría '\(definition.subcategoryName)' no encontrada")
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

private func createDevFavorites(in context: ModelContext) -> [FavoritePayment] {
    var favorites: [FavoritePayment] = []

    for definition in devFavoriteDefinitions {
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == definition.subcategoryName }
        )

        guard let subcategory = try? context.fetch(subcategoryDescriptor).first else {
            print("DevDataSeed: Warning - Subcategoría '\(definition.subcategoryName)' no encontrada")
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

private func createDevSubscriptions(in context: ModelContext, accounts: [Account]) -> [ScheduledPayment] {
    var subscriptions: [ScheduledPayment] = []

    let calendar = Calendar.current
    let today = Date()

    for definition in devSubscriptionDefinitions {
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == definition.subcategoryName }
        )

        guard let subcategory = try? context.fetch(subcategoryDescriptor).first else {
            print("DevDataSeed: Warning - Subcategoría '\(definition.subcategoryName)' no encontrada")
            continue
        }

        // Buscar cuenta según tipo
        guard let account = findAccount(byType: definition.accountType, in: accounts) else {
            print("DevDataSeed: Warning - Cuenta '\(definition.accountType)' no encontrada")
            continue
        }

        // Calcular nextDueDate
        let currentDay = calendar.component(.day, from: today)
        var nextDueDate: Date
        if currentDay < definition.dayOfMonth {
            nextDueDate = calendar.date(bySetting: .day, value: definition.dayOfMonth, of: today) ?? today
        } else {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) ?? today
            nextDueDate = calendar.date(bySetting: .day, value: definition.dayOfMonth, of: nextMonth) ?? today
        }

        let subscription = ScheduledPayment(
            name: definition.name,
            note: nil,
            amount: definition.amount,
            currencyCode: definition.currencyCode,
            transactionType: "expense",
            account: account,
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

private func createDevScheduledPayments(in context: ModelContext, accounts: [Account]) -> [ScheduledPayment] {
    var scheduledPayments: [ScheduledPayment] = []

    let calendar = Calendar.current
    let today = Date()

    for definition in devScheduledPaymentDefinitions {
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == definition.subcategoryName }
        )

        guard let subcategory = try? context.fetch(subcategoryDescriptor).first else {
            print("DevDataSeed: Warning - Subcategoría '\(definition.subcategoryName)' no encontrada")
            continue
        }

        // Buscar cuenta según tipo
        guard let account = findAccount(byType: definition.accountType, in: accounts) else {
            print("DevDataSeed: Warning - Cuenta '\(definition.accountType)' no encontrada")
            continue
        }

        // Calcular nextDueDate
        let currentDay = calendar.component(.day, from: today)
        var nextDueDate: Date
        if currentDay < definition.dayOfMonth {
            nextDueDate = calendar.date(bySetting: .day, value: definition.dayOfMonth, of: today) ?? today
        } else {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) ?? today
            nextDueDate = calendar.date(bySetting: .day, value: definition.dayOfMonth, of: nextMonth) ?? today
        }

        let scheduledPayment = ScheduledPayment(
            name: definition.name,
            note: definition.note,
            amount: definition.amount,
            currencyCode: definition.currencyCode,
            transactionType: "expense",
            account: account,
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

// MARK: - Income Transaction Generation

private func generateIncomeTransactions(
    in context: ModelContext,
    accounts: [Account],
    preferredCurrency: CurrencyCode
) -> Int {
    let calendar = Calendar.current
    let today = Date()
    let startDate = calendar.date(from: DateComponents(year: 2024, month: 11, day: 1))!

    var transactionCount = 0

    // Iterar mes por mes
    var currentMonth = startDate
    while currentMonth <= today {
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(byAdding: .month, value: 1, to: currentMonth)!) ?? today

        for incomeDef in devIncomeDefinitions {
            // Determinar si este mes tiene ingreso según frecuencia
            let shouldGenerate: Bool
            if incomeDef.frequency >= 1.0 {
                shouldGenerate = true  // Mensual
            } else {
                shouldGenerate = Double.random(in: 0...1) < incomeDef.frequency
            }

            guard shouldGenerate else { continue }

            // Buscar subcategoría
            let subcategoryDescriptor = FetchDescriptor<Subcategory>(
                predicate: #Predicate { $0.name == incomeDef.subcategoryName }
            )
            guard let subcategory = try? context.fetch(subcategoryDescriptor).first else { continue }

            // Buscar cuenta
            guard let account = findAccount(byType: incomeDef.accountType, in: accounts) else { continue }

            // Determinar monto según tipo de variación
            let amount: Double
            let currentMonthNum = calendar.component(.month, from: currentMonth)

            switch incomeDef.variationType {
            case .fixed:
                amount = incomeDef.baseAmount
            case .bonusMonths(let months):
                if months.contains(currentMonthNum) {
                    amount = incomeDef.baseAmount + 3000.0  // Aguinaldo
                } else {
                    amount = incomeDef.baseAmount
                }
            case .random(let range):
                amount = Double.random(in: range)
            }

            // Determinar fecha
            let transactionDate: Date
            if let day = incomeDef.dayOfMonth {
                let targetDay = min(day, calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 28)
                transactionDate = calendar.date(bySetting: .day, value: targetDay, of: currentMonth) ?? currentMonth
            } else {
                let randomDay = Int.random(in: 15...25)
                transactionDate = calendar.date(bySetting: .day, value: randomDay, of: currentMonth) ?? currentMonth
            }

            guard transactionDate <= today else { continue }

            // Determinar nota
            let note = incomeDef.possibleNotes.randomElement()

            // Calcular exchange rate y monto en moneda preferida
            let exchangeRate: Double
            let amountInPreferred: Double
            if incomeDef.currencyCode == preferredCurrency.rawValue {
                exchangeRate = 1.0
                amountInPreferred = amount
            } else {
                exchangeRate = getExchangeRate(for: transactionDate)
                amountInPreferred = amount * exchangeRate
            }

            let transaction = TransactionItem(
                date: transactionDate,
                amount: amount,
                currencyCode: incomeDef.currencyCode,
                note: note,
                category: subcategory.category,
                subcategory: subcategory,
                account: account,
                tags: [],
                exchangeRate: exchangeRate,
                amountInPreferredCurrency: amountInPreferred,
                preferredCurrencyCode: preferredCurrency.rawValue,
                isExchangeRateProvisional: false
            )
            context.insert(transaction)
            transactionCount += 1
        }

        // Avanzar al siguiente mes
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? today.addingTimeInterval(86400 * 365)
    }

    return transactionCount
}

// MARK: - Scheduled Payment Transaction Generation

private func generateScheduledPaymentTransactions(
    in context: ModelContext,
    subscriptions: [ScheduledPayment],
    scheduledPayments: [ScheduledPayment],
    accounts: [Account],
    preferredCurrency: CurrencyCode
) -> Int {
    let calendar = Calendar.current
    let today = Date()
    let startDate = calendar.date(from: DateComponents(year: 2024, month: 11, day: 1))!

    var transactionCount = 0
    let allScheduled = subscriptions + scheduledPayments

    for payment in allScheduled {
        guard let dayOfMonth = payment.dayOfMonth,
              let subcategory = payment.subcategory,
              let account = payment.account else {
            continue
        }

        // Generar transacciones mensuales desde startDate hasta hoy
        var currentDate = startDate
        while currentDate <= today {
            let targetDay = min(dayOfMonth, calendar.range(of: .day, in: .month, for: currentDate)?.count ?? 28)
            if let transactionDate = calendar.date(bySetting: .day, value: targetDay, of: currentDate),
               transactionDate <= today {

                // Aplicar variación si existe
                var amount = payment.amount
                if let scheduledDef = devScheduledPaymentDefinitions.first(where: { $0.name == payment.name }),
                   let variation = scheduledDef.variationPercent {
                    let variationFactor = Double.random(in: (1.0 - variation)...(1.0 + variation))
                    amount = round(payment.amount * variationFactor * 100) / 100
                }

                // Calcular exchange rate y monto en moneda preferida
                let exchangeRate: Double
                let amountInPreferred: Double
                if payment.currencyCode == preferredCurrency.rawValue {
                    exchangeRate = 1.0
                    amountInPreferred = amount
                } else {
                    exchangeRate = getExchangeRate(for: transactionDate)
                    amountInPreferred = amount * exchangeRate
                }

                let transaction = TransactionItem(
                    date: transactionDate,
                    amount: amount,
                    currencyCode: payment.currencyCode,
                    note: payment.note,
                    category: subcategory.category,
                    subcategory: subcategory,
                    account: account,
                    tags: [],
                    exchangeRate: exchangeRate,
                    amountInPreferredCurrency: amountInPreferred,
                    preferredCurrencyCode: preferredCurrency.rawValue,
                    isExchangeRateProvisional: false
                )
                context.insert(transaction)
                transactionCount += 1
            }

            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? today.addingTimeInterval(86400 * 365)
        }
    }

    return transactionCount
}

// MARK: - Varied Transaction Generation

private func generateVariedTransactions(
    in context: ModelContext,
    accounts: [Account],
    tags: [Tag],
    preferredCurrency: CurrencyCode
) -> Int {
    let calendar = Calendar.current
    let today = Date()
    let startDate = calendar.date(from: DateComponents(year: 2024, month: 11, day: 1))!

    var transactionCount = 0
    let templates = createAllTransactionTemplates()

    // Obtener todas las subcategorías necesarias
    var subcategoryMap: [String: Subcategory] = [:]
    for template in templates {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == template.subcategoryName }
        )
        if let subcategory = try? context.fetch(descriptor).first {
            subcategoryMap[template.subcategoryName] = subcategory
        }
    }

    // Generar transacciones mes por mes
    var currentMonth = startDate
    while currentMonth <= today {
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(byAdding: .month, value: 1, to: currentMonth)!) ?? today

        for template in templates {
            guard template.frequency > 0 else { continue }
            guard let subcategory = subcategoryMap[template.subcategoryName] else { continue }

            // Generar N transacciones en el mes
            for _ in 0..<template.frequency {
                let dayOffset = Int.random(in: 0...min(27, calendar.component(.day, from: monthEnd) - 1))
                guard let transactionDate = calendar.date(byAdding: .day, value: dayOffset, to: currentMonth),
                      transactionDate <= today else {
                    continue
                }

                // Seleccionar cuenta según distribución
                let randomValue = Double.random(in: 0...1)
                var cumulativeProbability = 0.0
                var selectedAccountType: String = "BCP"

                for (accountType, probability) in template.accountDistribution {
                    cumulativeProbability += probability
                    if randomValue <= cumulativeProbability {
                        selectedAccountType = accountType
                        break
                    }
                }

                // Buscar cuenta física
                guard let account = findAccount(byType: selectedAccountType, in: accounts) else { continue }

                // Determinar moneda según cuenta
                let currency = template.currencyByAccount[selectedAccountType] ?? preferredCurrency.rawValue

                // Generar monto aleatorio
                let baseAmount: Double
                if currency == "USD" {
                    // Convertir rango a USD aproximadamente
                    let usdLower = template.amountRange.lowerBound / 3.75
                    let usdUpper = template.amountRange.upperBound / 3.75
                    baseAmount = Double.random(in: usdLower...usdUpper)
                } else {
                    baseAmount = Double.random(in: template.amountRange)
                }
                let amount = round(baseAmount * 100) / 100

                // Tag aleatorio (30% probabilidad real)
                let randomTags: [Tag]
                if !tags.isEmpty && Double.random(in: 0...1) < 0.30 {
                    randomTags = [tags.randomElement()!]
                } else {
                    randomTags = []
                }

                // Nota aleatoria (30% probabilidad)
                let note = Double.random(in: 0...1) < 0.3 ? template.possibleNotes.randomElement() : nil

                // Calcular exchange rate y monto en moneda preferida
                let exchangeRate: Double
                let amountInPreferred: Double
                if currency == preferredCurrency.rawValue {
                    exchangeRate = 1.0
                    amountInPreferred = amount
                } else {
                    exchangeRate = getExchangeRate(for: transactionDate)
                    if currency == "USD" {
                        amountInPreferred = amount * exchangeRate
                    } else {
                        amountInPreferred = amount / exchangeRate
                    }
                }

                let transaction = TransactionItem(
                    date: transactionDate,
                    amount: amount,
                    currencyCode: currency,
                    note: note,
                    category: subcategory.category,
                    subcategory: subcategory,
                    account: account,
                    tags: randomTags,
                    exchangeRate: exchangeRate,
                    amountInPreferredCurrency: amountInPreferred,
                    preferredCurrencyCode: preferredCurrency.rawValue,
                    isExchangeRateProvisional: false
                )
                context.insert(transaction)
                transactionCount += 1
            }
        }

        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? today.addingTimeInterval(86400 * 365)
    }

    return transactionCount
}

// MARK: - Special Transaction Generation

private func generateSpecialTransactions(
    in context: ModelContext,
    accounts: [Account],
    preferredCurrency: CurrencyCode
) -> Int {
    let calendar = Calendar.current
    let today = Date()
    let startDate = calendar.date(from: DateComponents(year: 2024, month: 11, day: 1))!

    var transactionCount = 0

    // Buscar subcategorías necesarias
    let impuestosDescriptor = FetchDescriptor<Subcategory>(
        predicate: #Predicate { $0.name == "Impuestos" }
    )
    let viajesDescriptor = FetchDescriptor<Subcategory>(
        predicate: #Predicate { $0.name == "Viajes y vacaciones" }
    )

    guard let impuestosSubcat = try? context.fetch(impuestosDescriptor).first,
          let viajesSubcat = try? context.fetch(viajesDescriptor).first,
          let bcpAccount = findAccount(byType: "BCP", in: accounts) else {
        return 0
    }

    // Generar impuestos en Marzo de cada año
    var currentMonth = startDate
    while currentMonth <= today {
        let month = calendar.component(.month, from: currentMonth)
        let year = calendar.component(.year, from: currentMonth)

        // Impuestos en Marzo
        if month == 3 {
            if let impuestosDate = calendar.date(from: DateComponents(year: year, month: 3, day: 28)),
               impuestosDate <= today {
                let amount = 450.0
                let transaction = TransactionItem(
                    date: impuestosDate,
                    amount: amount,
                    currencyCode: preferredCurrency.rawValue,
                    note: "Declaración anual impuestos",
                    category: impuestosSubcat.category,
                    subcategory: impuestosSubcat,
                    account: bcpAccount,
                    tags: [],
                    exchangeRate: 1.0,
                    amountInPreferredCurrency: amount,
                    preferredCurrencyCode: preferredCurrency.rawValue,
                    isExchangeRateProvisional: false
                )
                context.insert(transaction)
                transactionCount += 1
            }
        }

        // Viajes en Agosto (verano/vacaciones)
        if month == 8 {
            if let viajeDate = calendar.date(from: DateComponents(year: year, month: 8, day: Int.random(in: 10...20))),
               viajeDate <= today {
                let amount = Double.random(in: 800...1500)
                let roundedAmount = round(amount * 100) / 100
                let transaction = TransactionItem(
                    date: viajeDate,
                    amount: roundedAmount,
                    currencyCode: preferredCurrency.rawValue,
                    note: "Viaje vacaciones verano",
                    category: viajesSubcat.category,
                    subcategory: viajesSubcat,
                    account: bcpAccount,
                    tags: [],
                    exchangeRate: 1.0,
                    amountInPreferredCurrency: roundedAmount,
                    preferredCurrencyCode: preferredCurrency.rawValue,
                    isExchangeRateProvisional: false
                )
                context.insert(transaction)
                transactionCount += 1
            }
        }

        // Viaje adicional en Diciembre
        if month == 12 {
            if let viajeDate = calendar.date(from: DateComponents(year: year, month: 12, day: Int.random(in: 20...28))),
               viajeDate <= today {
                let amount = Double.random(in: 600...1200)
                let roundedAmount = round(amount * 100) / 100
                let transaction = TransactionItem(
                    date: viajeDate,
                    amount: roundedAmount,
                    currencyCode: preferredCurrency.rawValue,
                    note: "Viaje fin de año",
                    category: viajesSubcat.category,
                    subcategory: viajesSubcat,
                    account: bcpAccount,
                    tags: [],
                    exchangeRate: 1.0,
                    amountInPreferredCurrency: roundedAmount,
                    preferredCurrencyCode: preferredCurrency.rawValue,
                    isExchangeRateProvisional: false
                )
                context.insert(transaction)
                transactionCount += 1
            }
        }

        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? today.addingTimeInterval(86400 * 365)
    }

    return transactionCount
}

// MARK: - Transfer Generation

private func generateTransfers(
    in context: ModelContext,
    accounts: [Account],
    preferredCurrency: CurrencyCode
) -> Int {
    let calendar = Calendar.current
    let today = Date()
    let startDate = calendar.date(from: DateComponents(year: 2024, month: 11, day: 1))!

    var transactionCount = 0

    guard let bcpAccount = findAccount(byType: "BCP", in: accounts),
          let efectivoAccount = findAccount(byType: "Efectivo", in: accounts),
          let usdAccount = findAccount(byType: "USD", in: accounts) else {
        return 0
    }

    // Buscar subcategoría de transferencias para GASTOS (Otros/Transferencia entre cuentas)
    let expenseTransferDescriptor = FetchDescriptor<Subcategory>(
        predicate: #Predicate<Subcategory> {
            $0.name == "Transferencia entre cuentas" &&
            $0.category?.isIncome == false
        }
    )
    guard let expenseTransferSubcat = try? context.fetch(expenseTransferDescriptor).first else {
        print("DevDataSeed: No se encontró subcategoría de transferencia en Otros")
        return 0
    }

    // Buscar subcategoría de transferencias para INGRESOS (Ingresos/Transferencia entre cuentas)
    let incomeTransferDescriptor = FetchDescriptor<Subcategory>(
        predicate: #Predicate<Subcategory> {
            $0.name == "Transferencia entre cuentas" &&
            $0.category?.isIncome == true
        }
    )
    guard let incomeTransferSubcat = try? context.fetch(incomeTransferDescriptor).first else {
        print("DevDataSeed: No se encontró subcategoría de transferencia en Ingresos")
        return 0
    }

    // Generar transferencias mes por mes
    var currentMonth = startDate
    while currentMonth <= today {
        // 1. Retiro de efectivo (BCP → Efectivo) - 2 veces al mes
        for _ in 0..<2 {
            let dayOffset = Int.random(in: 5...25)
            guard let transferDate = calendar.date(byAdding: .day, value: dayOffset, to: currentMonth),
                  transferDate <= today else {
                continue
            }

            let amount = Double.random(in: 300...600)
            let roundedAmount = round(amount * 100) / 100

            // Transacción de salida en BCP (GASTO - usa Otros/Transferencia)
            let outTransaction = TransactionItem(
                date: transferDate,
                amount: roundedAmount,
                currencyCode: preferredCurrency.rawValue,
                note: "Retiro efectivo cajero",
                category: expenseTransferSubcat.category,
                subcategory: expenseTransferSubcat,
                account: bcpAccount,
                tags: [],
                exchangeRate: 1.0,
                amountInPreferredCurrency: roundedAmount,
                preferredCurrencyCode: preferredCurrency.rawValue,
                isExchangeRateProvisional: false
            )
            context.insert(outTransaction)
            transactionCount += 1

            // Transacción de entrada en Efectivo (INGRESO - usa Ingresos/Transferencia)
            let inTransaction = TransactionItem(
                date: transferDate,
                amount: roundedAmount,
                currencyCode: preferredCurrency.rawValue,
                note: "Retiro efectivo cajero",
                category: incomeTransferSubcat.category,
                subcategory: incomeTransferSubcat,
                account: efectivoAccount,
                tags: [],
                exchangeRate: 1.0,
                amountInPreferredCurrency: roundedAmount,
                preferredCurrencyCode: preferredCurrency.rawValue,
                isExchangeRateProvisional: false
            )
            context.insert(inTransaction)
            transactionCount += 1
        }

        // 2. Depósito de efectivo (Efectivo → BCP) - ocasional
        if Double.random(in: 0...1) < 0.5 {
            let dayOffset = Int.random(in: 10...20)
            guard let depositDate = calendar.date(byAdding: .day, value: dayOffset, to: currentMonth),
                  depositDate <= today else {
                continue
            }

            let amount = Double.random(in: 200...500)
            let roundedAmount = round(amount * 100) / 100

            // Transacción de salida en Efectivo (GASTO - usa Otros/Transferencia)
            let outTransaction = TransactionItem(
                date: depositDate,
                amount: roundedAmount,
                currencyCode: preferredCurrency.rawValue,
                note: "Depósito efectivo banco",
                category: expenseTransferSubcat.category,
                subcategory: expenseTransferSubcat,
                account: efectivoAccount,
                tags: [],
                exchangeRate: 1.0,
                amountInPreferredCurrency: roundedAmount,
                preferredCurrencyCode: preferredCurrency.rawValue,
                isExchangeRateProvisional: false
            )
            context.insert(outTransaction)
            transactionCount += 1

            // Transacción de entrada en BCP (INGRESO - usa Ingresos/Transferencia)
            let inTransaction = TransactionItem(
                date: depositDate,
                amount: roundedAmount,
                currencyCode: preferredCurrency.rawValue,
                note: "Depósito efectivo banco",
                category: incomeTransferSubcat.category,
                subcategory: incomeTransferSubcat,
                account: bcpAccount,
                tags: [],
                exchangeRate: 1.0,
                amountInPreferredCurrency: roundedAmount,
                preferredCurrencyCode: preferredCurrency.rawValue,
                isExchangeRateProvisional: false
            )
            context.insert(inTransaction)
            transactionCount += 1
        }

        // 3. Ahorro en USD (BCP PEN → BBVA USD) - ocasional
        if Double.random(in: 0...1) < 0.5 {
            let dayOffset = Int.random(in: 25...28)
            guard let savingsDate = calendar.date(byAdding: .day, value: dayOffset, to: currentMonth),
                  savingsDate <= today else {
                continue
            }

            let amountPEN = Double.random(in: 500...1500)
            let roundedAmountPEN = round(amountPEN * 100) / 100

            let exchangeRate = getExchangeRate(for: savingsDate)
            let amountUSD = round((roundedAmountPEN / exchangeRate) * 100) / 100

            // Transacción de salida en BCP (PEN) - GASTO - usa Otros/Transferencia
            let outTransaction = TransactionItem(
                date: savingsDate,
                amount: roundedAmountPEN,
                currencyCode: preferredCurrency.rawValue,
                note: "Ahorro mensual USD",
                category: expenseTransferSubcat.category,
                subcategory: expenseTransferSubcat,
                account: bcpAccount,
                tags: [],
                exchangeRate: 1.0,
                amountInPreferredCurrency: roundedAmountPEN,
                preferredCurrencyCode: preferredCurrency.rawValue,
                isExchangeRateProvisional: false
            )
            context.insert(outTransaction)
            transactionCount += 1

            // Transacción de entrada en BBVA USD (USD) - INGRESO - usa Ingresos/Transferencia
            let inTransaction = TransactionItem(
                date: savingsDate,
                amount: amountUSD,
                currencyCode: "USD",
                note: "Ahorro mensual USD",
                category: incomeTransferSubcat.category,
                subcategory: incomeTransferSubcat,
                account: usdAccount,
                tags: [],
                exchangeRate: exchangeRate,
                amountInPreferredCurrency: roundedAmountPEN,
                preferredCurrencyCode: preferredCurrency.rawValue,
                isExchangeRateProvisional: false
            )
            context.insert(inTransaction)
            transactionCount += 1
        }

        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? today.addingTimeInterval(86400 * 365)
    }

    return transactionCount
}

#endif
