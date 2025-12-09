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

/// Estructura interna para describir cada categoría de la semilla
private struct CategorySeedDefinition {
    let name: String
    let colorHex: String
    let isIncome: Bool
    let subcategories: [String]
}

// -------------------------------------------------------------------------
// DEFINICIÓN DE LA SEMILLA (FIN-18)
// -------------------------------------------------------------------------
// Ajustar únicamente si actualizamos FIN-18 y SIEMPRE bajo pedido expreso.
//

private let defaultCategorySeedDefinitions: [CategorySeedDefinition] = [
    CategorySeedDefinition(
        name: "Alimentación",
        colorHex: "#FF9F0A", // naranja asociada a comida
        isIncome: false,
        subcategories: [
            "Restaurantes",
            "Supermercados y bodegas",
            "Delivery",
            "Suplementos alimenticios"
        ]
    ),
    CategorySeedDefinition(
        name: "Compras",
        colorHex: "#5E5CE6", // morado asociado a compras/retail
        isIncome: false,
        subcategories: [
            "Artículos del hogar",
            "Electrónica y accesorios",
            "Salud y belleza",
            "Ropa y calzado",
            "Regalos",
            "Farmacias",
            "Otros"
        ]
    ),
    CategorySeedDefinition(
        name: "Transporte",
        colorHex: "#0A84FF", // azul asociado a movilidad
        isIncome: false,
        subcategories: [
            "Transporte público",
            "Taxi",
            "Movilidad ocasional"
        ]
    ),
    CategorySeedDefinition(
        name: "Finanzas",
        colorHex: "#1C3556", // azul oscuro asociado a finanzas
        isIncome: false,
        subcategories: [
            "Impuestos",
            "Seguros",
            "Préstamos",
            "Multas",
            "Asesorías",
            "Cargos y comisiones",
            "Pensiones"
        ]
    ),
    CategorySeedDefinition(
        name: "Hogar",
        colorHex: "#FFD60A", // amarillo cálido asociado al hogar
        isIncome: false,
        subcategories: [
            "Alquiler",
            "Hipoteca",
            "Servicios",
            "Mantenimiento y reparaciones",
            "Seguro del hogar",
            "Personal de apoyo",
            "Otros"
        ]
    ),
    CategorySeedDefinition(
        name: "Entretenimiento",
        colorHex: "#FF375F", // rojo/rosado asociado a ocio
        isIncome: false,
        subcategories: [
            "Espectáculos y eventos",
            "Deportes y recreación",
            "Bares y salidas con amigos",
            "Fiestas y discotecas",
            "Salidas en pareja",
            "Viajes y vacaciones",
            "Streaming y suscripciones",
            "Hobbies"
        ]
    ),
    CategorySeedDefinition(
        name: "Personal",
        colorHex: "#30D158", // verde asociado a bienestar personal
        isIncome: false,
        subcategories: [
            "Salud y atención médica",
            "Bienestar físico y fitness",
            "Bienestar y estética personal",
            "Educación y desarrollo personal",
            "Suscripciones de utilidad",
            "Comunicaciones y telefonía"
        ]
    ),
    CategorySeedDefinition(
        name: "Vehículo",
        colorHex: "#64D2FF", // celeste asociado a vehículo/movilidad
        isIncome: false,
        subcategories: [
            "Combustible",
            "Estacionamiento",
            "Mantenimiento",
            "Préstamos",
            "Seguro del vehículo",
            "Leasing"
        ]
    ),
    CategorySeedDefinition(
        name: "Ingresos",
        colorHex: "#32D74B", // verde brillante asociado a ingresos/dinero
        isIncome: true,
        subcategories: [
            "Salario",
            "Facturación y freelance",
            "Intereses y dividendos",
            "Ventas",
            "Alquileres recibidos",
            "Ayudas y subvenciones",
            "Reembolsos",
            "Regalos y otros ingresos"
        ]
    )
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
        for (subIndex, subName) in definition.subcategories.enumerated() {
            let subcategory = Subcategory(
                name: subName,
                colorHex: nil,
                isDefaultSeed: true,
                isVisible: true,
                sortOrder: subIndex,
                natureRawValue: nil,
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
