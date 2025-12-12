//
//  CategorySeed.swift
//  Neto
//
//  FIN-18: Semilla inicial de categorías por defecto
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
}

/// Estructura interna para describir cada categoría de la semilla
private struct CategorySeedDefinition {
    let name: String
    let colorHex: String
    let isIncome: Bool
    let subcategories: [SubcategorySeedDefinition]
}

// -------------------------------------------------------------------------
// DEFINICIÓN DE LA SEMILLA (FIN-18 / Actualizado)
// -------------------------------------------------------------------------
// Ajustar únicamente si actualizamos FIN-18 y SIEMPRE bajo pedido expreso.
//

private let defaultCategorySeedDefinitions: [CategorySeedDefinition] = [
    // 1. Alimentación
    CategorySeedDefinition(
        name: "Alimentación",
        colorHex: "#22C55E",
        isIncome: false,
        subcategories: [
            SubcategorySeedDefinition(name: "Supermercados y bodegas", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Restaurantes", natureRawValue: "opcional"),
            SubcategorySeedDefinition(name: "Delivery", natureRawValue: "opcional"),
            SubcategorySeedDefinition(
                name: "Suplementos alimenticios", natureRawValue: "prioritaria"),
        ]
    ),
    // 2. Compras
    CategorySeedDefinition(
        name: "Compras",
        colorHex: "#F59E0B",
        isIncome: false,
        subcategories: [
            SubcategorySeedDefinition(name: "Hogar y decoración", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(
                name: "Tecnología y accesorios", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(
                name: "Cuidado personal y belleza", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(name: "Ropa y calzado", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(name: "Regalos y detalles", natureRawValue: "opcional"),
            SubcategorySeedDefinition(name: "Farmacia y botiquín", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Otros", natureRawValue: "opcional"),
        ]
    ),
    // 3. Transporte
    CategorySeedDefinition(
        name: "Transporte",
        colorHex: "#0EA5E9",
        isIncome: false,
        subcategories: [
            SubcategorySeedDefinition(name: "Transporte público", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Taxis y apps", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(name: "Movilidad ocasional", natureRawValue: "opcional"),
        ]
    ),
    // 4. Finanzas
    CategorySeedDefinition(
        name: "Finanzas",
        colorHex: "#6366F1",
        isIncome: false,
        subcategories: [
            SubcategorySeedDefinition(name: "Impuestos", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Seguros", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Préstamos y créditos", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Comisiones y cargos", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(name: "Asesorías y trámites", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(name: "Pensiones y aportes", natureRawValue: "esencial"),
        ]
    ),
    // 5. Hogar
    CategorySeedDefinition(
        name: "Hogar",
        colorHex: "#475569",
        isIncome: false,
        subcategories: [
            SubcategorySeedDefinition(name: "Alquiler o hipoteca", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Servicios del hogar", natureRawValue: "esencial"),
            SubcategorySeedDefinition(
                name: "Mantenimiento y reparaciones", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(name: "Seguro del hogar", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Personal de apoyo", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(name: "Otros", natureRawValue: "opcional"),
        ]
    ),
    // 6. Entretenimiento
    CategorySeedDefinition(
        name: "Entretenimiento",
        colorHex: "#FF0080",
        isIncome: false,
        subcategories: [
            SubcategorySeedDefinition(name: "Espectáculos y eventos", natureRawValue: "opcional"),
            SubcategorySeedDefinition(name: "Deportes y recreación", natureRawValue: "opcional"),
            SubcategorySeedDefinition(name: "Bares y salidas sociales", natureRawValue: "opcional"),
            SubcategorySeedDefinition(name: "Fiestas y vida nocturna", natureRawValue: "opcional"),
            SubcategorySeedDefinition(name: "Salidas en pareja", natureRawValue: "opcional"),
            SubcategorySeedDefinition(name: "Viajes y vacaciones", natureRawValue: "opcional"),
            SubcategorySeedDefinition(
                name: "Streaming y plataformas", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(name: "Hobbies y gaming", natureRawValue: "opcional"),
        ]
    ),
    // 7. Personal
    CategorySeedDefinition(
        name: "Personal",
        colorHex: "#A855F7",
        isIncome: false,
        subcategories: [
            SubcategorySeedDefinition(name: "Salud y atención médica", natureRawValue: "esencial"),
            SubcategorySeedDefinition(
                name: "Fitness y actividad física", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(name: "Belleza y estética", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(
                name: "Educación y desarrollo", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(
                name: "Suscripciones de utilidad", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(
                name: "Telefonía y comunicaciones", natureRawValue: "esencial"),
        ]
    ),
    // 8. Mascotas y animales (Nueva)
    CategorySeedDefinition(
        name: "Mascotas y animales",
        colorHex: "#84CC16",
        isIncome: false,
        subcategories: [
            SubcategorySeedDefinition(name: "Alimentación de mascotas", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Salud veterinaria", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Accesorios y juguetes", natureRawValue: "opcional"),
            SubcategorySeedDefinition(name: "Servicios y cuidados", natureRawValue: "prioritaria"),
        ]
    ),
    // 9. Vehículo
    CategorySeedDefinition(
        name: "Vehículo",
        colorHex: "#64748B",
        isIncome: false,
        subcategories: [
            SubcategorySeedDefinition(name: "Combustible", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Estacionamientos", natureRawValue: "prioritaria"),
            SubcategorySeedDefinition(
                name: "Mantenimiento del vehículo", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Préstamo vehicular", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Seguro vehicular", natureRawValue: "esencial"),
            SubcategorySeedDefinition(name: "Leasing", natureRawValue: "esencial"),
        ]
    ),
    // 10. Ingresos
    CategorySeedDefinition(
        name: "Ingresos",
        colorHex: "#00F3FF",
        isIncome: true,
        subcategories: [
            SubcategorySeedDefinition(name: "Salario", natureRawValue: "sin_clasificacion"),
            SubcategorySeedDefinition(
                name: "Facturación y freelance", natureRawValue: "sin_clasificacion"),
            SubcategorySeedDefinition(
                name: "Intereses y dividendos", natureRawValue: "sin_clasificacion"),
            SubcategorySeedDefinition(name: "Ventas", natureRawValue: "sin_clasificacion"),
            SubcategorySeedDefinition(
                name: "Alquileres recibidos", natureRawValue: "sin_clasificacion"),
            SubcategorySeedDefinition(
                name: "Ayudas y subvenciones", natureRawValue: "sin_clasificacion"),
            SubcategorySeedDefinition(name: "Reembolsos", natureRawValue: "sin_clasificacion"),
            SubcategorySeedDefinition(
                name: "Regalos y otros ingresos", natureRawValue: "sin_clasificacion"),
        ]
    ),
]

/// FIN-18
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
        print("FIN-18: Error leyendo categorías existentes: \(error)")
        return
    }

    guard existingCategoriesCount == 0 else {
        // Ya hay categorías, no ejecutamos semilla otra vez.
        print("FIN-18: Semilla NO ejecutada (ya existen categorías).")
        return
    }

    // 2. Ejecutar semilla completa de categorías y subcategorías
    print("FIN-18: Ejecutando semilla inicial de categorías por defecto...")

    for (categoryIndex, definition) in defaultCategorySeedDefinitions.enumerated() {

        // Crear categoría raíz
        let category = Category(
            name: definition.name,
            colorHex: definition.colorHex,
            isIncome: definition.isIncome,
            isDefaultSeed: true,
            isVisible: true,
            sortOrder: categoryIndex
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
                category: category
            )
            modelContext.insert(subcategory)
        }
    }

    // 3. Guardar cambios (por seguridad, aunque SwiftData suele autoguardar)
    do {
        try modelContext.save()
        print("FIN-18: Semilla de categorías creada correctamente.")
    } catch {
        print("FIN-18: Error al guardar la semilla de categorías: \(error)")
    }
}
