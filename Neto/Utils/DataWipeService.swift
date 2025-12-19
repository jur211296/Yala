//
//  DataWipeService.swift
//  Neto
//
//  Servicio central para eliminar todos los datos del usuario
//  y resembrar la app a un estado inicial.
//

import Foundation
import SwiftData

// Clase de utilidad para operaciones de borrado masivo de datos de usuario.
// Marcada como @MainActor porque ModelContext debe usarse desde el hilo principal.
@MainActor
final class DataWipeService {

    // MARK: - Punto de entrada principal
    // Llama a esta función cuando quieras vaciar los datos del usuario.
    // 1. Elimina datos de todos los modelos relevantes.
    // 2. Opcionalmente vuelve a lanzar la semilla inicial (categorías, etc.).
    static func wipeAllUserData(
        in context: ModelContext,
        reseedInitialData: Bool = true
    ) throws {
        // 1. Borrar en orden de dependencias:
        //    Primero lo que depende de cuentas / categorías (transacciones, presupuestos),
        //    luego tipos de cambio,
        //    luego cuentas,
        //    finalmente categorías y otros catálogos.

        // Eliminar todas las transacciones (dependen de cuentas, categorías, subcategorías y tags)
        try deleteAll(TransactionItem.self, in: context)

        // Eliminar todos los presupuestos (dependen de categorías)
        try deleteAll(Budget.self, in: context)

        // Eliminar todos los tags (relacionados con transacciones)
        try deleteAll(Tag.self, in: context)

        // Eliminar todos los tipos de cambio
        try deleteAll(ExchangeRate.self, in: context)

        // Eliminar todas las cuentas
        try deleteAll(Account.self, in: context)

        // Eliminar todas las subcategorías (hijas de Category)
        try deleteAll(Subcategory.self, in: context)

        // Eliminar todas las categorías
        try deleteAll(Category.self, in: context)

        // Si tienes otros modelos que son claramente "datos de usuario",
        // añádelos aquí, respetando el orden de dependencias.
        // Por ejemplo:
        // try deleteAll(Subscription.self, in: context)
        // try deleteAll(Goal.self, in: context)

        // Guardar el contexto tras el borrado masivo
        try context.save()

        // 2. Reset UserDefaults for widget configuration and exchange rates
        UserDefaults.standard.removeObject(forKey: "widgetConfigs")

        // Reset exchange rate service state so it fetches fresh data
        UserDefaults.standard.removeObject(forKey: "exchangeRate_lastHistoricalLoad")
        UserDefaults.standard.removeObject(forKey: "exchangeRate_lastTodayUpdate")

        // 3. Reseed de datos iniciales si corresponde
        if reseedInitialData {
            try reseedInitialAppState(in: context)
        }
    }

    // MARK: - Helper de borrado genérico
    // Utiliza la API de SwiftData para eliminar todas las instancias de un tipo.
    private static func deleteAll<T: PersistentModel>(
        _ model: T.Type,
        in context: ModelContext
    ) throws {
        // Si tu target iOS soporta delete(model:) úsalo para borrado masivo:
        // Esto evita tener que hacer fetch y borrar uno por uno.
        try context.delete(model: T.self)

        // Si por algún motivo no puedes usar delete(model:),
        // reemplaza esta línea por:
        //
        // let descriptor = FetchDescriptor<T>()
        // let items = try context.fetch(descriptor)
        // for item in items {
        //     context.delete(item)
        // }
    }

    // MARK: - Reseed de estado inicial
    // Encapsula aquí la lógica para volver al estado "recien instalada".
    private static func reseedInitialAppState(in context: ModelContext) throws {
        // FIN-18: Semilla inicial de categorías y subcategorías.
        // La función `seedCategoriesIfNeeded(in:)` es idempotente: si ya existen
        // categorías, no hace nada. Después de un borrado completo no debería
        // haber ninguna categoría, por lo que recreará la semilla inicial.
        seedCategoriesIfNeeded(in: context)
    }
}
