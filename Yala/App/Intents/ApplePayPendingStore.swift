//
//  ApplePayPendingStore.swift
//  Yala
//
//  Cola cross-launch (App Group) de gastos de Apple Pay pendientes de materializar.
//
//  El `ApplePayTransactionIntent` corre en background (pantalla bloqueada) y NO debe tocar
//  SwiftData: abrir un 2º `ModelContainer` sobre el store de la app deja una ventana de
//  reconciliación que vacía la UI hasta un cold launch (ver
//  `Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`). En vez de guardar el `InboxDraft`,
//  el intent encola aquí los datos CRUDOS del pago y la app crea el borrador al abrir
//  (`ApplePayDraftService`, gateado por la quiescencia del import de CloudKit).
//
//  **Una key por pago, NO una lista.** El `append` corre en el proceso del intent y el
//  `peekAll`/`remove` en el de la app; `UserDefaults`/CFPreferences no tiene compare-and-swap
//  cross-process, así que un read-modify-write de UNA lista compartida perdería o duplicaría
//  pagos cuando ambos procesos escriben a la vez. Con una key única por pago cada operación
//  toca su propia key (atómica por-key) → sin lost-update. Espeja el patrón de valor-por-key de
//  `LastUsedAccountStore` / `PendingIntentSaveSignal`.
//

import Foundation

/// Un gasto de Apple Pay pendiente de convertirse en `InboxDraft`. Datos CRUDOS (sin resolver
/// contra la base de datos): el parseo/matching final lo hace la app en `ApplePayDraftService`.
/// `nonisolated`: es un DTO puro que se codifica/decodifica desde el proceso del intent (fuera
/// del main actor); sin esto su conformance Codable quedaría MainActor-isolated (error en Swift 6).
nonisolated struct ApplePayPendingExpense: Codable, Equatable {
    /// Identidad estable: nombra la key en App Group y sirve de clave de idempotencia.
    var id: UUID = UUID()
    /// El string de monto tal como lo envía la automatización de Wallet (ej. "$32.04", "S/ 25,90").
    let rawAmount: String
    /// El comercio, si la automatización lo conectó.
    let merchant: String?
    /// Momento del pago (segundos desde 1970). Es la fecha del gasto en el borrador.
    let savedAt: Double
}

/// Cola en App Group UserDefaults, una key por pago. `nonisolated` — se escribe desde el proceso
/// del intent (fuera del main actor). `defaults` inyectable para tests aislados.
enum ApplePayPendingStore {

    /// Prefijo de las keys por-pago en el App Group.
    nonisolated static let keyPrefix = "applePayPending."

    private nonisolated static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)
    }

    /// Encola un gasto bajo su propia key única. Cross-process seguro: cada `set` toca una key
    /// distinta, sin read-modify-write de una lista compartida.
    nonisolated static func append(
        _ expense: ApplePayPendingExpense,
        defaults: UserDefaults? = ApplePayPendingStore.appGroupDefaults
    ) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(expense)
            defaults.set(data, forKey: keyPrefix + expense.id.uuidString)
        } catch {
            #if DEBUG
            print("ApplePayPendingStore: Error encoding pending expense: \(error)")
            #endif
        }
    }

    /// Lee todos los pagos encolados SIN borrarlos, ordenados por fecha del pago. La app procesa
    /// y luego llama `remove` con las keys realmente materializadas (consume-after-save): un
    /// crash antes del `save()` NO pierde el pago; a lo sumo se reprocesa en el próximo arranque
    /// → borrador duplicado (recuperable), nunca pérdida silenciosa de un gasto.
    /// Los valores corruptos bajo una key nuestra se descartan aquí (no reintentar en bucle).
    nonisolated static func peekAll(
        defaults: UserDefaults? = ApplePayPendingStore.appGroupDefaults
    ) -> [(key: String, expense: ApplePayPendingExpense)] {
        guard let defaults else { return [] }
        var result: [(key: String, expense: ApplePayPendingExpense)] = []
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(keyPrefix) {
            guard let data = value as? Data else {
                defaults.removeObject(forKey: key)   // no-Data corrupto → descartar
                continue
            }
            do {
                let expense = try JSONDecoder().decode(ApplePayPendingExpense.self, from: data)
                result.append((key, expense))
            } catch {
                #if DEBUG
                print("ApplePayPendingStore: Error decoding pending expense at \(key): \(error)")
                #endif
                defaults.removeObject(forKey: key)   // JSON corrupto → descartar (no bucle)
            }
        }
        return result.sorted { $0.expense.savedAt < $1.expense.savedAt }
    }

    /// Borra las keys ya materializadas (tras un `save()` exitoso). Idempotente.
    nonisolated static func remove(
        keys: [String],
        defaults: UserDefaults? = ApplePayPendingStore.appGroupDefaults
    ) {
        guard let defaults else { return }
        for key in keys { defaults.removeObject(forKey: key) }
    }
}
