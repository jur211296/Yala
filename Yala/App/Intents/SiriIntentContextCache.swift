//
//  SiriIntentContextCache.swift
//  Yala
//
//  Caché en App Group del contexto que `SiriNaturalEntryIntent` necesita para parsear SIN tocar
//  SwiftData. El intent corre en background y no puede abrir el store de la app (deja una ventana
//  de reconciliación que vacía la UI — ver `Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`),
//  pero el parseo LLM sí necesita la lista de subcategorías del usuario para elegir el nombre
//  exacto. La app mantiene esta caché (la escribe en bootstrap y al volver a foreground); el intent
//  la LEE (`read()`, `nonisolated`).
//
//  Stale ≠ incorrecto: el matching final de subcategoría/cuenta lo hace la app en `SiriDraftService`
//  contra los datos VIVOS. La caché solo (1) guía al LLM, (2) alimenta la divisa del snippet cuando
//  el parseo no infiere una, y (3) permite el aviso hablado "no hay cuentas" sin abrir el store.
//

import Foundation
import SwiftData

/// Snapshot del contexto del usuario relevante para el parseo del intent de Siri.
/// `nonisolated`: DTO cross-proceso — lo lee el intent (`nonisolated`) y lo escribe la app. Sin
/// esto su conformance Codable queda main-actor-isolated bajo `SWIFT_DEFAULT_ACTOR_ISOLATION`.
nonisolated struct SiriIntentContext: Codable {
    let expenseSubcategories: [String]
    let incomeSubcategories: [String]
    /// Divisa por defecto del usuario (`appPreferences.defaultCurrencyCode.rawValue`) — display del
    /// snippet cuando el LLM no infiere `currencyHint`.
    let defaultCurrency: String
    /// Si el usuario tiene ≥1 cuenta real (no de sistema). El intent lo usa para el aviso hablado.
    let hasRealAccount: Bool
}

enum SiriIntentContextCache {

    /// Key única (App Group) con el snapshot JSON. Hardcodeada, como en `SiriPendingStore` /
    /// `ApplePayPendingStore` (no es una preferencia de usuario, es IPC entre procesos).
    nonisolated static let storageKey = "siriIntentContext"

    private nonisolated static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)
    }

    /// Lee el snapshot cacheado. `nonisolated` — lo invoca el intent desde su proceso background.
    /// `nil` si aún no se escribió (primer uso post-instalación) o el valor está corrupto.
    nonisolated static func read(
        defaults: UserDefaults? = SiriIntentContextCache.appGroupDefaults
    ) -> SiriIntentContext? {
        guard let defaults, let data = defaults.data(forKey: storageKey) else { return nil }
        do {
            return try JSONDecoder().decode(SiriIntentContext.self, from: data)
        } catch {
            #if DEBUG
            print("SiriIntentContextCache: Error decoding context: \(error)")
            #endif
            return nil
        }
    }

    /// Escritura de bajo nivel (IO puro). `nonisolated` para testear sin main actor.
    nonisolated static func write(
        _ context: SiriIntentContext,
        defaults: UserDefaults? = SiriIntentContextCache.appGroupDefaults
    ) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(context)
            defaults.set(data, forKey: storageKey)
        } catch {
            #if DEBUG
            print("SiriIntentContextCache: Error encoding context: \(error)")
            #endif
        }
    }

    /// Recalcula el snapshot desde el store y lo persiste. La llama la app (bootstrap / foreground);
    /// barato: dos fetches ligeros. `defaultCurrency` se pasa desde `appPreferences` para no acoplar
    /// la caché con `AppPreferences`.
    @MainActor
    static func refresh(context: ModelContext, defaultCurrency: String) {
        let (expense, income) = DraftBuilder.fetchVisibleSubcategoryNames(context: context)

        let hasRealAccount: Bool
        do {
            let count = try context.fetchCount(
                FetchDescriptor<Account>(predicate: #Predicate<Account> { $0.isSystemAccount == false })
            )
            hasRealAccount = count > 0
        } catch {
            #if DEBUG
            print("SiriIntentContextCache: Error fetching account count: \(error)")
            #endif
            // Sin señal fiable → asumir que sí hay cuentas (no bloquear a Siri por un fetch fallido).
            hasRealAccount = true
        }

        write(SiriIntentContext(
            expenseSubcategories: expense,
            incomeSubcategories: income,
            defaultCurrency: defaultCurrency,
            hasRealAccount: hasRealAccount
        ))
    }
}
