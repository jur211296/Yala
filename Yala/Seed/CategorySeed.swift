//
//  CategorySeed.swift
//  Yala
//
//  Semilla inicial de categorías por defecto
//
//  -------------------------------------------------------------------------
//  IMPORTANTE (NO MODIFICAR SIN APROBACIÓN EXPLÍCITA):
//
//  - Esta estructura define la semilla oficial de categorías/subcategorías
//    con la que arranca Yala en su versión 1.0.
//  - Cualquier cambio en nombres, estructura o contenido debe tratarse
//    como un cambio de producto y SOLO hacerse si el Product Owner (Jürgen)
//    lo solicita explícitamente.
//  - La función `seedCategoriesIfNeeded` está diseñada para:
//
//      * Ejecutarse automáticamente al arranque (pantalla Panel).
//      * Crear la semilla SOLO si todavía no existen categorías.
//      * NO duplicar ni borrar categorías que el usuario haya creado.
//
//  -------------------------------------------------------------------------
//

import Foundation
import SwiftData

/// Estructura interna para describir cada subcategoría de la semilla
private struct SubcategorySeedDefinition {
    let name: String
    /// Raw value para SubcategoryNeed (esencial, prioritaria, opcional, sin_clasificacion)
    /// Si es nil, se asumirá sin_clasificacion (o lógica por defecto).
    let natureRawValue: String?
    /// Nombre del icono SF Symbol
    let iconName: String?
}

/// Estructura interna para describir cada categoría de la semilla
private struct CategorySeedDefinition {
    let name: String
    let colorHex: String
    let isIncome: Bool
    /// Nombre del icono SF Symbol
    let iconName: String?
    let subcategories: [SubcategorySeedDefinition]
}

// -------------------------------------------------------------------------
// DEFINICIÓN DE LA SEMILLA
// -------------------------------------------------------------------------
// Ajustar únicamente bajo pedido expreso del Product Owner.
//
// Los nombres usan L10n para localización automática según el idioma del usuario.
//

private func defaultCategorySeedDefinitions() -> [CategorySeedDefinition] {
    [
    // 1. Alimentación
    CategorySeedDefinition(
        name: L10n.Category.food,
        colorHex: "#22C55E",
        isIncome: false,
        iconName: "cart.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: L10n.Subcategory.delivery, natureRawValue: "opcional",
                iconName: "takeoutbag.and.cup.and.straw.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.restaurants, natureRawValue: "opcional", iconName: "fork.knife"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.supplements, natureRawValue: "prioritaria",
                iconName: "pill.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.supermarkets, natureRawValue: "esencial", iconName: "basket.fill"
            ),
        ]
    ),
    // 2. Compras
    CategorySeedDefinition(
        name: L10n.Category.shopping,
        colorHex: "#F59E0B",
        isIncome: false,
        iconName: "bag.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: L10n.Subcategory.personalCare, natureRawValue: "prioritaria",
                iconName: "sparkles"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.pharmacy, natureRawValue: "esencial", iconName: "cross.case.fill"
            ),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.homeDecor, natureRawValue: "prioritaria",
                iconName: "lamp.desk.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.otherShopping, natureRawValue: "opcional", iconName: "ellipsis.circle.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.gifts, natureRawValue: "opcional", iconName: "gift.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.clothing, natureRawValue: "prioritaria", iconName: "tshirt.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.tech, natureRawValue: "prioritaria",
                iconName: "laptopcomputer"),
        ]
    ),
    // 3. Transporte
    CategorySeedDefinition(
        name: L10n.Category.transport,
        colorHex: "#0EA5E9",
        isIncome: false,
        iconName: "car.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: L10n.Subcategory.occasionalMobility, natureRawValue: "opcional", iconName: "figure.walk"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.rideshare, natureRawValue: "prioritaria", iconName: "car.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.publicTransport, natureRawValue: "esencial", iconName: "bus.fill"),
        ]
    ),
    // 4. Finanzas
    CategorySeedDefinition(
        name: L10n.Category.finance,
        colorHex: "#6366F1",
        isIncome: false,
        iconName: "banknote.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: L10n.Subcategory.fees, natureRawValue: "prioritaria", iconName: "percent"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.taxes, natureRawValue: "esencial", iconName: "doc.text.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.pensions, natureRawValue: "esencial",
                iconName: "building.columns.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.loans, natureRawValue: "esencial",
                iconName: "creditcard.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.insurance, natureRawValue: "esencial", iconName: "shield.fill"),
        ]
    ),
    // 5. Hogar
    CategorySeedDefinition(
        name: L10n.Category.housing,
        colorHex: "#475569",
        isIncome: false,
        iconName: "house.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: L10n.Subcategory.rent, natureRawValue: "esencial", iconName: "key.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.maintenance, natureRawValue: "prioritaria",
                iconName: "wrench.and.screwdriver.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.otherHousing, natureRawValue: "opcional", iconName: "ellipsis.circle.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.supportStaff, natureRawValue: "prioritaria", iconName: "person.2.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.homeInsurance, natureRawValue: "esencial",
                iconName: "house.and.flag.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.utilities, natureRawValue: "esencial", iconName: "bolt.fill"),
        ]
    ),
    // 6. Entretenimiento
    CategorySeedDefinition(
        name: L10n.Category.entertainment,
        colorHex: "#FF0080",
        isIncome: false,
        iconName: "sparkles",
        subcategories: [
            SubcategorySeedDefinition(
                name: L10n.Subcategory.bars, natureRawValue: "opcional",
                iconName: "wineglass.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.sports, natureRawValue: "opcional",
                iconName: "sportscourt.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.shows, natureRawValue: "opcional", iconName: "ticket.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.nightlife, natureRawValue: "opcional",
                iconName: "party.popper.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.hobbies, natureRawValue: "opcional",
                iconName: "gamecontroller.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.coupleDates, natureRawValue: "opcional", iconName: "heart.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.streaming, natureRawValue: "prioritaria",
                iconName: "play.tv.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.travel, natureRawValue: "opcional", iconName: "airplane"),
        ]
    ),
    // 7. Personal
    CategorySeedDefinition(
        name: L10n.Category.personal,
        colorHex: "#A855F7",
        isIncome: false,
        iconName: "person.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: L10n.Subcategory.consulting, natureRawValue: "prioritaria",
                iconName: "doc.on.clipboard.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.beauty, natureRawValue: "prioritaria", iconName: "comb.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.education, natureRawValue: "prioritaria", iconName: "book.fill"
            ),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.fitness, natureRawValue: "prioritaria",
                iconName: "figure.run"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.health, natureRawValue: "esencial", iconName: "stethoscope"
            ),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.leisureSubs, natureRawValue: "opcional",
                iconName: "play.circle.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.utilitySubs, natureRawValue: "prioritaria",
                iconName: "app.badge.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.phone, natureRawValue: "esencial",
                iconName: "phone.fill"),
        ]
    ),
    // 8. Mascotas y animales
    CategorySeedDefinition(
        name: L10n.Category.pets,
        colorHex: "#84CC16",
        isIncome: false,
        iconName: "pawprint.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: L10n.Subcategory.petAccessories, natureRawValue: "opcional",
                iconName: "tennisball.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.petFood, natureRawValue: "esencial",
                iconName: "pawprint.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.vet, natureRawValue: "esencial", iconName: "cross.vial.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.petServices, natureRawValue: "prioritaria", iconName: "scissors"),
        ]
    ),
    // 9. Vehículo
    CategorySeedDefinition(
        name: L10n.Category.vehicle,
        colorHex: "#64748B",
        isIncome: false,
        iconName: "car.side.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: L10n.Subcategory.fuel, natureRawValue: "esencial", iconName: "fuelpump.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.parking, natureRawValue: "prioritaria",
                iconName: "parkingsign.circle.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.leasing, natureRawValue: "esencial", iconName: "doc.richtext.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.vehicleMaintenance, natureRawValue: "esencial",
                iconName: "wrench.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.vehicleLoan, natureRawValue: "esencial", iconName: "creditcard.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.vehicleInsurance, natureRawValue: "esencial",
                iconName: "car.badge.gearshape.fill"),
        ]
    ),
    // 10. Ingresos
    CategorySeedDefinition(
        name: L10n.Category.incomeCategory,
        colorHex: "#14B8A6",
        isIncome: true,
        iconName: "arrow.down.circle.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: L10n.Subcategory.rentalIncome, natureRawValue: "sin_clasificacion",
                iconName: "building.2.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.subsidies, natureRawValue: "sin_clasificacion",
                iconName: "hand.raised.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.freelance, natureRawValue: "sin_clasificacion",
                iconName: "doc.text.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.dividends, natureRawValue: "sin_clasificacion",
                iconName: "chart.line.uptrend.xyaxis"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.refunds, natureRawValue: "sin_clasificacion",
                iconName: "arrow.uturn.backward.circle.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.giftIncome, natureRawValue: "sin_clasificacion",
                iconName: "giftcard.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.salary, natureRawValue: "sin_clasificacion", iconName: "briefcase.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.sales, natureRawValue: "sin_clasificacion",
                iconName: "dollarsign.circle.fill"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.accountTransfer, natureRawValue: "sin_clasificacion",
                iconName: "arrow.left.arrow.right"),
        ]
    ),
    // 11. Otros (neutral category for system/adjustment transactions)
    CategorySeedDefinition(
        name: L10n.Category.other,
        colorHex: "#64748B",
        isIncome: false,
        iconName: "ellipsis.circle.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: L10n.Subcategory.balanceAdjustment, natureRawValue: "sin_clasificacion",
                iconName: "plus.forwardslash.minus"),
            SubcategorySeedDefinition(
                name: L10n.Subcategory.accountTransferOther, natureRawValue: "sin_clasificacion",
                iconName: "arrow.left.arrow.right")
        ]
    ),
    ]
}

/// Ejecuta la semilla de categorías/subcategorías solo si todavía no existe
/// ninguna categoría en la base.
///
/// Reglas importantes:
/// - Si ya hay al menos una `Category`, la función NO hace nada.
/// - No borra ni modifica categorías existentes.
/// - No debe llamarse manualmente desde otros puntos sin revisar impacto.
func seedCategoriesIfNeeded(in modelContext: ModelContext) {

    // 0. Flag guard — prevents TOCTOU race with CloudKit sync
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: "seedCategoriesExecuted") {
        #if DEBUG
        print("CategorySeed: Semilla ya ejecutada anteriormente (flag).")
        #endif
        return
    }

    // 1. Comprobar si ya existen categorías de usuario (secondary defense).
    //    Excluye categorías system (A0-Bridge `seedSystemGroupCategoriesIfNeeded` corre en
    //    bootstrap y crea "Grupos"/"Cobros de grupos" antes del onboarding). Contarlas aquí
    //    abortaría el seed default y rompería el flow de saldo inicial (no se crearía
    //    "Ajuste de saldo" → setInitialBalance falla silenciosamente en onboarding).
    let existingCategoriesCount: Int
    do {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { !$0.isSystem }
        )
        existingCategoriesCount = try modelContext.fetchCount(descriptor)
    } catch {
        // Si hay error al leer, preferimos no tocar nada para no
        // corromper datos ni crear semilla en un estado incierto.
        #if DEBUG
        print("CategorySeed: Error leyendo categorías existentes: \(error)")
        #endif
        return
    }

    guard existingCategoriesCount == 0 else {
        // Ya hay categorías de usuario, no ejecutamos semilla otra vez.
        #if DEBUG
        print("CategorySeed: Semilla NO ejecutada (ya existen categorías de usuario).")
        #endif
        // Set flag so we don't check the DB again next launch
        defaults.set(true, forKey: "seedCategoriesExecuted")
        return
    }

    // 2. Set flag BEFORE inserting — wins race vs CloudKit delivering same categories
    defaults.set(true, forKey: "seedCategoriesExecuted")

    // 3. Ejecutar semilla completa de categorías y subcategorías
    #if DEBUG
    print("CategorySeed: Ejecutando semilla inicial de categorías por defecto...")
    #endif

    let definitions = defaultCategorySeedDefinitions()

    for (categoryIndex, definition) in definitions.enumerated() {

        // Crear categoría raíz
        let category = Category(
            name: definition.name,
            colorHex: definition.colorHex,
            isIncome: definition.isIncome,
            isDefaultSeed: true,
            isVisible: true,
            sortOrder: categoryIndex,
            iconName: definition.iconName
        )
        modelContext.insert(category)

        // Crear subcategorías asociadas
        for (subIndex, subDef) in definition.subcategories.enumerated() {
            let subcategory = Subcategory(
                name: subDef.name,
                colorHex: nil,
                isDefaultSeed: true,
                isVisible: true,
                sortOrder: subIndex,
                natureRawValue: subDef.natureRawValue,
                iconName: subDef.iconName,
                category: category
            )
            modelContext.insert(subcategory)
        }
    }

    // 3. Guardar cambios (por seguridad, aunque SwiftData suele autoguardar)
    do {
        try modelContext.save()
        #if DEBUG
        print("CategorySeed: Semilla de categorías creada correctamente.")
        #endif
    } catch {
        #if DEBUG
        print("CategorySeed: Error al guardar la semilla de categorías: \(error)")
        #endif
    }
}

// -------------------------------------------------------------------------
// MARK: - A0-Bridge: Categorías y Subcategorías Sistema para Grupos
// -------------------------------------------------------------------------
//
// Estas categorías y subcategorías son creadas por separado de la semilla
// principal porque deben aplicarse también a usuarios existentes que ya
// tienen `seedCategoriesExecuted = true`. Usan flag separado
// `seedSystemGroupCategoriesExecuted` y son idempotentes por nombre.
//
// **Propósito**: representar contablemente operaciones de grupos en la
// cuenta virtual `Grupos [moneda]` con subcategorías que respetan la
// dicotomía income/expense de Yala.

private struct SystemSubcategoryDefinition {
    let name: String
    let role: String  // identificador estable independiente del nombre L10n
}

private struct SystemCategoryDefinition {
    let name: String
    let colorHex: String
    let isIncome: Bool
    let iconName: String
    let role: String
    let subcategories: [SystemSubcategoryDefinition]
}

/// Roles estables (independientes de localización) para identificar entidades sistema.
/// Usados por `GroupBridgeSystemEntities.systemSubcategory(role:)` (F3).
enum GroupBridgeSystemRole {
    static let categoryGroups = "groups"
    static let categoryGroupCollections = "groupCollections"
    static let subcategoryLoanToGroups = "loanToGroups"
    static let subcategoryLoanCollection = "loanCollection"
    static let subcategorySettlementPayment = "settlementPayment"
    static let subcategorySettlementSent = "settlementSent"
    static let subcategorySettlementReceived = "settlementReceived"
}

private func systemGroupCategoryDefinitions() -> [SystemCategoryDefinition] {
    [
        // Categoría sistema EXPENSE
        SystemCategoryDefinition(
            name: L10n.Category.System.groups,
            colorHex: "#7C3AED",
            isIncome: false,
            iconName: "person.2.fill",
            role: GroupBridgeSystemRole.categoryGroups,
            subcategories: [
                SystemSubcategoryDefinition(
                    name: L10n.Subcategory.System.loanCollection,
                    role: GroupBridgeSystemRole.subcategoryLoanCollection
                ),
                SystemSubcategoryDefinition(
                    name: L10n.Subcategory.System.settlementSent,
                    role: GroupBridgeSystemRole.subcategorySettlementSent
                ),
            ]
        ),
        // Categoría sistema INCOME
        SystemCategoryDefinition(
            name: L10n.Category.System.groupCollections,
            colorHex: "#10B981",
            isIncome: true,
            iconName: "tray.and.arrow.down.fill",
            role: GroupBridgeSystemRole.categoryGroupCollections,
            subcategories: [
                SystemSubcategoryDefinition(
                    name: L10n.Subcategory.System.loanToGroups,
                    role: GroupBridgeSystemRole.subcategoryLoanToGroups
                ),
                SystemSubcategoryDefinition(
                    name: L10n.Subcategory.System.settlementPayment,
                    role: GroupBridgeSystemRole.subcategorySettlementPayment
                ),
                SystemSubcategoryDefinition(
                    name: L10n.Subcategory.System.settlementReceived,
                    role: GroupBridgeSystemRole.subcategorySettlementReceived
                ),
            ]
        ),
    ]
}

/// Crea las 2 Categories sistema + 5 Subcategorías sistema del bridge A0
/// si todavía no existen. Idempotente: chequea por `isSystem == true` antes de crear.
///
/// Llamada en `AppBootstrapper.bootstrap()` después de `seedCategoriesIfNeeded`.
/// Backfill seguro para users con seed previo.
///
/// `defaults` parameter permite inyectar UserDefaults isolado para tests.
/// En producción se usa `.standard`.
func seedSystemGroupCategoriesIfNeeded(
    in modelContext: ModelContext,
    defaults: UserDefaults = .standard
) {
    let flagKey = "seedSystemGroupCategoriesExecuted"

    // Flag guard contra TOCTOU race con CloudKit sync
    if defaults.bool(forKey: flagKey) {
        // Defensa secundaria: verificar que las categorías sistema realmente existen.
        // Si flag=true pero entidades faltan (edge case borrado manual), permitir re-seed.
        let existingCount = (try? modelContext.fetchCount(
            FetchDescriptor<Category>(predicate: #Predicate { $0.isSystem == true })
        )) ?? 0
        if existingCount > 0 {
            #if DEBUG
            print("CategorySeed: System groups categorías ya existen (flag + count=\(existingCount)).")
            #endif
            return
        }
        // Flag inconsistente con DB → continuar y reseed.
    }

    let definitions = systemGroupCategoryDefinitions()

    do {
        // Primary defense: chequear si ya hay alguna categoría sistema (cualquiera de las 2)
        // por nombre (idempotencia por nombre).
        let allCategories = try modelContext.fetch(FetchDescriptor<Category>())
        let existingNames = Set(allCategories.map(\.name))

        for definition in definitions {
            let categoryExists = existingNames.contains(definition.name)
            let category: Category
            if categoryExists, let existing = allCategories.first(where: { $0.name == definition.name }) {
                category = existing
                // Asegurar flag isSystem aunque ya exista (recuperación de inconsistencias)
                if !category.isSystem {
                    category.isSystem = true
                }
                // Backfill defensive: re-aplica el iconName canónico si difiere del seed
                // (necesario para users con la cat creada con un SF Symbol obsoleto).
                if category.iconName != definition.iconName {
                    category.iconName = definition.iconName
                }
            } else {
                category = Category(
                    name: definition.name,
                    colorHex: definition.colorHex,
                    isIncome: definition.isIncome,
                    isDefaultSeed: true,
                    isVisible: true,
                    sortOrder: 100, // sortOrder alto para que vayan al final
                    iconName: definition.iconName,
                    isSystem: true
                )
                modelContext.insert(category)
            }

            // Crear subcategorías faltantes
            let existingSubNames = Set((category.subcategories ?? []).map(\.name))
            for (subIndex, subDef) in definition.subcategories.enumerated() {
                if existingSubNames.contains(subDef.name) {
                    // Asegurar isSystem en subcat existente
                    if let existing = category.subcategories?.first(where: { $0.name == subDef.name }), !existing.isSystem {
                        existing.isSystem = true
                    }
                    continue
                }
                let subcategory = Subcategory(
                    name: subDef.name,
                    colorHex: nil,
                    isDefaultSeed: true,
                    isVisible: true,
                    sortOrder: subIndex,
                    natureRawValue: "sin_clasificacion",
                    iconName: nil,
                    isSystem: true,
                    category: category
                )
                modelContext.insert(subcategory)
            }
        }

        try modelContext.save()
        defaults.set(true, forKey: flagKey)

        #if DEBUG
        print("CategorySeed: Semilla system groups creada correctamente.")
        #endif
    } catch {
        #if DEBUG
        print("CategorySeed: Error al guardar semilla system groups: \(error)")
        #endif
    }
}
