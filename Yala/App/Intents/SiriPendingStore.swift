//
//  SiriPendingStore.swift
//  Yala
//
//  Cola cross-launch (App Group) de dictados de Siri pendientes de materializar como `InboxDraft`.
//
//  El `SiriNaturalEntryIntent` corre en background y NO debe tocar SwiftData: abrir un 2º
//  `ModelContainer` sobre el store de la app deja una ventana de reconciliación que vacía la UI
//  hasta un cold launch (ver `Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`). En vez de
//  guardar el `InboxDraft`, el intent hace SOLO el parseo LLM (red, sin base de datos) y encola
//  aquí el resultado CRUDO; la app crea los borradores al abrir (`SiriDraftService`, gateado por la
//  quiescencia del import de CloudKit). Espeja el patrón de `ApplePayPendingStore`.
//
//  **Una key por dictado, NO una lista.** El `append` corre en el proceso del intent y el
//  `peekAll`/`remove` en el de la app; `UserDefaults`/CFPreferences no tiene compare-and-swap
//  cross-process, así que un read-modify-write de UNA lista compartida perdería o duplicaría
//  dictados cuando ambos procesos escriben a la vez. Con una key única por dictado cada operación
//  toca su propia key (atómica por-key) → sin lost-update. Un dictado puede producir N
//  transacciones, así que la key almacena el LOTE completo (`transactions`) + el texto original.
//

import Foundation

/// Un dictado de Siri pendiente de convertirse en `InboxDraft`(s). Datos CRUDOS del parseo LLM
/// (sin resolver cuenta/subcategoría contra la base de datos): ese matching final lo hace la app
/// en `SiriDraftService`. `transactions` ya viene filtrado por el intent (solo las que tienen
/// `amount`), así que la app no re-aplica el quality gate.
nonisolated struct SiriPendingEntry: Codable, Equatable {
    /// Identidad estable: nombra la key en App Group y sirve de clave de idempotencia.
    var id: UUID = UUID()
    /// El texto completo dictado (ej. "50 en café y 100 en uber"). Es el `rawText` de cada draft.
    let rawText: String
    /// Las transacciones parseadas por el LLM (o el fallback offline), una por gasto/ingreso.
    let transactions: [ParsedTransaction]
    /// Momento del dictado (segundos desde 1970). Fecha de fallback si el parseo no dio una.
    let savedAt: Double
}

/// Cola en App Group UserDefaults, una key por dictado. `nonisolated` — se escribe desde el proceso
/// del intent (fuera del main actor). `defaults` inyectable para tests aislados.
enum SiriPendingStore {

    /// Prefijo de las keys por-dictado en el App Group.
    nonisolated static let keyPrefix = "siriPending."

    private nonisolated static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)
    }

    /// Encola un dictado bajo su propia key única. Cross-process seguro: cada `set` toca una key
    /// distinta, sin read-modify-write de una lista compartida.
    nonisolated static func append(
        _ entry: SiriPendingEntry,
        defaults: UserDefaults? = SiriPendingStore.appGroupDefaults
    ) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(entry)
            defaults.set(data, forKey: keyPrefix + entry.id.uuidString)
        } catch {
            #if DEBUG
            print("SiriPendingStore: Error encoding pending entry: \(error)")
            #endif
        }
    }

    /// Lee todos los dictados encolados SIN borrarlos, ordenados por fecha. La app procesa y luego
    /// llama `remove` con las keys realmente materializadas (consume-after-save): un crash antes del
    /// `save()` NO pierde el dictado; a lo sumo se reprocesa en el próximo arranque → borrador
    /// duplicado (recuperable), nunca pérdida silenciosa. Los valores corruptos bajo una key nuestra
    /// se descartan aquí (no reintentar en bucle).
    nonisolated static func peekAll(
        defaults: UserDefaults? = SiriPendingStore.appGroupDefaults
    ) -> [(key: String, entry: SiriPendingEntry)] {
        guard let defaults else { return [] }
        var result: [(key: String, entry: SiriPendingEntry)] = []
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(keyPrefix) {
            guard let data = value as? Data else {
                defaults.removeObject(forKey: key)   // no-Data corrupto → descartar
                continue
            }
            do {
                let entry = try JSONDecoder().decode(SiriPendingEntry.self, from: data)
                result.append((key, entry))
            } catch {
                #if DEBUG
                print("SiriPendingStore: Error decoding pending entry at \(key): \(error)")
                #endif
                defaults.removeObject(forKey: key)   // JSON corrupto → descartar (no bucle)
            }
        }
        return result.sorted { $0.entry.savedAt < $1.entry.savedAt }
    }

    /// Borra las keys ya materializadas (tras un `save()` exitoso). Idempotente.
    nonisolated static func remove(
        keys: [String],
        defaults: UserDefaults? = SiriPendingStore.appGroupDefaults
    ) {
        guard let defaults else { return }
        for key in keys { defaults.removeObject(forKey: key) }
    }
}
