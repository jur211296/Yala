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
    /// Raw value para SubcategoryNature (esencial, prioritaria, opcional, sin_clasificacion)
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

    // 1. Comprobar si ya existen categorías (secondary defense)
    let existingCategoriesCount: Int
    do {
        let descriptor = FetchDescriptor<Category>()
        let categories = try modelContext.fetch(descriptor)
        existingCategoriesCount = categories.count
    } catch {
        // Si hay error al leer, preferimos no tocar nada para no
        // corromper datos ni crear semilla en un estado incierto.
        #if DEBUG
        print("CategorySeed: Error leyendo categorías existentes: \(error)")
        #endif
        return
    }

    guard existingCategoriesCount == 0 else {
        // Ya hay categorías, no ejecutamos semilla otra vez.
        #if DEBUG
        print("CategorySeed: Semilla NO ejecutada (ya existen categorías).")
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
