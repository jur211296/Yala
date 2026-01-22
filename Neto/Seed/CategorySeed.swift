//
//  CategorySeed.swift
//  Neto
//
//  Semilla inicial de categorías por defecto
//
//  -------------------------------------------------------------------------
//  IMPORTANTE (NO MODIFICAR SIN APROBACIÓN EXPLÍCITA):
//
//  - Esta estructura define la semilla oficial de categorías/subcategorías
//    con la que arranca Neto en su versión 1.0.
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

private let defaultCategorySeedDefinitions: [CategorySeedDefinition] = [
    // 1. Alimentación
    CategorySeedDefinition(
        name: "Alimentación",
        colorHex: "#22C55E",
        isIncome: false,
        iconName: "cart.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: "Delivery", natureRawValue: "opcional",
                iconName: "takeoutbag.and.cup.and.straw.fill"),
            SubcategorySeedDefinition(
                name: "Restaurantes", natureRawValue: "opcional", iconName: "fork.knife"),
            SubcategorySeedDefinition(
                name: "Suplementos alimenticios", natureRawValue: "prioritaria",
                iconName: "pill.fill"),
            SubcategorySeedDefinition(
                name: "Supermercados y bodegas", natureRawValue: "esencial", iconName: "basket.fill"
            ),
        ]
    ),
    // 2. Compras
    CategorySeedDefinition(
        name: "Compras",
        colorHex: "#F59E0B",
        isIncome: false,
        iconName: "bag.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: "Cuidado personal y belleza", natureRawValue: "prioritaria",
                iconName: "sparkles"),
            SubcategorySeedDefinition(
                name: "Farmacia y botiquín", natureRawValue: "esencial", iconName: "cross.case.fill"
            ),
            SubcategorySeedDefinition(
                name: "Hogar y decoración", natureRawValue: "prioritaria",
                iconName: "lamp.desk.fill"),
            SubcategorySeedDefinition(
                name: "Otros", natureRawValue: "opcional", iconName: "ellipsis.circle.fill"),
            SubcategorySeedDefinition(
                name: "Regalos y detalles", natureRawValue: "opcional", iconName: "gift.fill"),
            SubcategorySeedDefinition(
                name: "Ropa y calzado", natureRawValue: "prioritaria", iconName: "tshirt.fill"),
            SubcategorySeedDefinition(
                name: "Tecnología y accesorios", natureRawValue: "prioritaria",
                iconName: "laptopcomputer"),
        ]
    ),
    // 3. Transporte
    CategorySeedDefinition(
        name: "Transporte",
        colorHex: "#0EA5E9",
        isIncome: false,
        iconName: "car.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: "Movilidad ocasional", natureRawValue: "opcional", iconName: "figure.walk"),
            SubcategorySeedDefinition(
                name: "Taxis y apps", natureRawValue: "prioritaria", iconName: "car.fill"),
            SubcategorySeedDefinition(
                name: "Transporte público", natureRawValue: "esencial", iconName: "bus.fill"),
        ]
    ),
    // 4. Finanzas
    CategorySeedDefinition(
        name: "Finanzas",
        colorHex: "#6366F1",
        isIncome: false,
        iconName: "banknote.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: "Comisiones y cargos", natureRawValue: "prioritaria", iconName: "percent"),
            SubcategorySeedDefinition(
                name: "Impuestos", natureRawValue: "esencial", iconName: "doc.text.fill"),
            SubcategorySeedDefinition(
                name: "Pensiones y aportes", natureRawValue: "esencial",
                iconName: "building.columns.fill"),
            SubcategorySeedDefinition(
                name: "Préstamos y créditos", natureRawValue: "esencial",
                iconName: "creditcard.fill"),
            SubcategorySeedDefinition(
                name: "Seguros", natureRawValue: "esencial", iconName: "shield.fill"),
        ]
    ),
    // 5. Hogar
    CategorySeedDefinition(
        name: "Hogar",
        colorHex: "#475569",
        isIncome: false,
        iconName: "house.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: "Alquiler o hipoteca", natureRawValue: "esencial", iconName: "key.fill"),
            SubcategorySeedDefinition(
                name: "Mantenimiento y reparaciones", natureRawValue: "prioritaria",
                iconName: "wrench.and.screwdriver.fill"),
            SubcategorySeedDefinition(
                name: "Otros", natureRawValue: "opcional", iconName: "ellipsis.circle.fill"),
            SubcategorySeedDefinition(
                name: "Personal de apoyo", natureRawValue: "prioritaria", iconName: "person.2.fill"),
            SubcategorySeedDefinition(
                name: "Seguro del hogar", natureRawValue: "esencial",
                iconName: "house.and.flag.fill"),
            SubcategorySeedDefinition(
                name: "Servicios del hogar", natureRawValue: "esencial", iconName: "bolt.fill"),
        ]
    ),
    // 6. Entretenimiento
    CategorySeedDefinition(
        name: "Entretenimiento",
        colorHex: "#FF0080",
        isIncome: false,
        iconName: "sparkles",
        subcategories: [
            SubcategorySeedDefinition(
                name: "Bares y salidas sociales", natureRawValue: "opcional",
                iconName: "wineglass.fill"),
            SubcategorySeedDefinition(
                name: "Deportes y recreación", natureRawValue: "opcional",
                iconName: "sportscourt.fill"),
            SubcategorySeedDefinition(
                name: "Espectáculos y eventos", natureRawValue: "opcional", iconName: "ticket.fill"),
            SubcategorySeedDefinition(
                name: "Fiestas y vida nocturna", natureRawValue: "opcional",
                iconName: "party.popper.fill"),
            SubcategorySeedDefinition(
                name: "Hobbies y gaming", natureRawValue: "opcional",
                iconName: "gamecontroller.fill"),
            SubcategorySeedDefinition(
                name: "Salidas en pareja", natureRawValue: "opcional", iconName: "heart.fill"),
            SubcategorySeedDefinition(
                name: "Streaming y plataformas", natureRawValue: "prioritaria",
                iconName: "play.tv.fill"),
            SubcategorySeedDefinition(
                name: "Viajes y vacaciones", natureRawValue: "opcional", iconName: "airplane"),
        ]
    ),
    // 7. Personal
    CategorySeedDefinition(
        name: "Personal",
        colorHex: "#A855F7",
        isIncome: false,
        iconName: "person.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: "Asesorías y trámites", natureRawValue: "prioritaria",
                iconName: "doc.on.clipboard.fill"),
            SubcategorySeedDefinition(
                name: "Belleza y estética", natureRawValue: "prioritaria", iconName: "comb.fill"),
            SubcategorySeedDefinition(
                name: "Educación y desarrollo", natureRawValue: "prioritaria", iconName: "book.fill"
            ),
            SubcategorySeedDefinition(
                name: "Fitness y actividad física", natureRawValue: "prioritaria",
                iconName: "figure.run"),
            SubcategorySeedDefinition(
                name: "Salud y atención médica", natureRawValue: "esencial", iconName: "stethoscope"
            ),
            SubcategorySeedDefinition(
                name: "Suscripciones de ocio", natureRawValue: "opcional",
                iconName: "play.circle.fill"),
            SubcategorySeedDefinition(
                name: "Suscripciones de utilidad", natureRawValue: "prioritaria",
                iconName: "app.badge.fill"),
            SubcategorySeedDefinition(
                name: "Telefonía y comunicaciones", natureRawValue: "esencial",
                iconName: "phone.fill"),
        ]
    ),
    // 8. Mascotas y animales
    CategorySeedDefinition(
        name: "Mascotas y animales",
        colorHex: "#84CC16",
        isIncome: false,
        iconName: "pawprint.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: "Accesorios y juguetes", natureRawValue: "opcional",
                iconName: "tennisball.fill"),
            SubcategorySeedDefinition(
                name: "Alimentación de mascotas", natureRawValue: "esencial",
                iconName: "pawprint.fill"),
            SubcategorySeedDefinition(
                name: "Salud veterinaria", natureRawValue: "esencial", iconName: "cross.vial.fill"),
            SubcategorySeedDefinition(
                name: "Servicios y cuidados", natureRawValue: "prioritaria", iconName: "scissors"),
        ]
    ),
    // 9. Vehículo
    CategorySeedDefinition(
        name: "Vehículo",
        colorHex: "#64748B",
        isIncome: false,
        iconName: "car.side.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: "Combustible", natureRawValue: "esencial", iconName: "fuelpump.fill"),
            SubcategorySeedDefinition(
                name: "Estacionamientos", natureRawValue: "prioritaria",
                iconName: "parkingsign.circle.fill"),
            SubcategorySeedDefinition(
                name: "Leasing", natureRawValue: "esencial", iconName: "doc.richtext.fill"),
            SubcategorySeedDefinition(
                name: "Mantenimiento del vehículo", natureRawValue: "esencial",
                iconName: "wrench.fill"),
            SubcategorySeedDefinition(
                name: "Préstamo vehicular", natureRawValue: "esencial", iconName: "creditcard.fill"),
            SubcategorySeedDefinition(
                name: "Seguro vehicular", natureRawValue: "esencial",
                iconName: "car.badge.gearshape.fill"),
        ]
    ),
    // 10. Ingresos
    CategorySeedDefinition(
        name: "Ingresos",
        colorHex: "#14B8A6",
        isIncome: true,
        iconName: "arrow.down.circle.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: "Alquileres recibidos", natureRawValue: "sin_clasificacion",
                iconName: "building.2.fill"),
            SubcategorySeedDefinition(
                name: "Ayudas y subvenciones", natureRawValue: "sin_clasificacion",
                iconName: "hand.raised.fill"),
            SubcategorySeedDefinition(
                name: "Facturación y freelance", natureRawValue: "sin_clasificacion",
                iconName: "doc.text.fill"),
            SubcategorySeedDefinition(
                name: "Intereses y dividendos", natureRawValue: "sin_clasificacion",
                iconName: "chart.line.uptrend.xyaxis"),
            SubcategorySeedDefinition(
                name: "Reembolsos", natureRawValue: "sin_clasificacion",
                iconName: "arrow.uturn.backward.circle.fill"),
            SubcategorySeedDefinition(
                name: "Regalos y otros ingresos", natureRawValue: "sin_clasificacion",
                iconName: "giftcard.fill"),
            SubcategorySeedDefinition(
                name: "Salario", natureRawValue: "sin_clasificacion", iconName: "briefcase.fill"),
            SubcategorySeedDefinition(
                name: "Ventas", natureRawValue: "sin_clasificacion",
                iconName: "dollarsign.circle.fill"),
            SubcategorySeedDefinition(
                name: "Transferencia entre cuentas", natureRawValue: "sin_clasificacion",
                iconName: "arrow.left.arrow.right"),
        ]
    ),
    // 11. Otros (neutral category for system/adjustment transactions)
    CategorySeedDefinition(
        name: "Otros",
        colorHex: "#64748B",
        isIncome: false,
        iconName: "ellipsis.circle.fill",
        subcategories: [
            SubcategorySeedDefinition(
                name: "Ajustes de saldo", natureRawValue: "sin_clasificacion",
                iconName: "plus.forwardslash.minus"),
            SubcategorySeedDefinition(
                name: "Transferencia entre cuentas", natureRawValue: "sin_clasificacion",
                iconName: "arrow.left.arrow.right")
        ]
    ),
]

/// Ejecuta la semilla de categorías/subcategorías solo si todavía no existe
/// ninguna categoría en la base.
///
/// Reglas importantes:
/// - Si ya hay al menos una `Category`, la función NO hace nada.
/// - No borra ni modifica categorías existentes.
/// - No debe llamarse manualmente desde otros puntos sin revisar impacto.
func seedCategoriesIfNeeded(in modelContext: ModelContext) {

    // 1. Comprobar si ya existen categorías
    let existingCategoriesCount: Int
    do {
        let descriptor = FetchDescriptor<Category>()
        let categories = try modelContext.fetch(descriptor)
        existingCategoriesCount = categories.count
    } catch {
        // Si hay error al leer, preferimos no tocar nada para no
        // corromper datos ni crear semilla en un estado incierto.
        print("CategorySeed: Error leyendo categorías existentes: \(error)")
        return
    }

    guard existingCategoriesCount == 0 else {
        // Ya hay categorías, no ejecutamos semilla otra vez.
        print("CategorySeed: Semilla NO ejecutada (ya existen categorías).")
        return
    }

    // 2. Ejecutar semilla completa de categorías y subcategorías
    print("CategorySeed: Ejecutando semilla inicial de categorías por defecto...")

    for (categoryIndex, definition) in defaultCategorySeedDefinitions.enumerated() {

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
        print("CategorySeed: Semilla de categorías creada correctamente.")
    } catch {
        print("CategorySeed: Error al guardar la semilla de categorías: \(error)")
    }
}
