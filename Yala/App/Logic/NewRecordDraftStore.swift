//
//  NewRecordDraftStore.swift
//  Yala
//
//  El borrador de Nuevo registro sobrevive a que iOS cierre Yala (card 77j1, 2026-11-04). Hasta entonces vivía solo en
//  el ViewModel del formulario: si la persona salía a otra app a mitad de un registro e iOS cerraba Yala para liberar
//  memoria, al volver lo escrito ya no estaba.
//
//  Qué guarda: lo que la persona escribió o eligió en un registro NUEVO (no la edición de uno guardado). Las cuentas, la
//  subcategoría y las etiquetas van por su identidad estable (`shortcutID` / `Tag.id`), no por `PersistentIdentifier`:
//  al restaurar se buscan entre las que hay, y lo que ya no exista se queda vacío.
//
//  Dónde: `UserDefaults.standard`, una sola clave. Describe filas del almacén, así que se va con los dos borrados
//  (`DataWipeService.removeRowDerivedKeys`). Caduca a las 24 h: un borrador de hace días ya no es «lo que estabas
//  escribiendo».
//

import Foundation

/// Lo escrito en Nuevo registro, en una forma que se puede guardar.
struct SavedNewRecordDraft: Codable, Equatable {
    var savedAt: Date
    var type: String
    var amountString: String
    var currencyCode: String
    var accountID: UUID?
    var sourceAccountID: UUID?
    var destinationAccountID: UUID?
    var subcategoryID: UUID?
    var need: String?
    var date: Date
    var tagIDs: [UUID]
    var note: String
    var exchangeRate: Double
    var isExchangeRateManual: Bool
    var destinationAmount: Double

    /// Un borrador con algo que conservar. Abrir el formulario y salir sin tocar nada no es un borrador: lo que trae
    /// precargado (cuenta, tipo, fecha de hoy) no lo escribió nadie.
    var hasContent: Bool {
        let amount = Double(amountString.replacingOccurrences(of: ",", with: ".")) ?? 0
        return amount > 0
            || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || subcategoryID != nil
            || !tagIDs.isEmpty
    }
}

enum NewRecordDraftStore {
    static let key = "newRecord.draft.v1"
    /// Cuánto vale un borrador guardado. Pasado ese tiempo se descarta al leerlo.
    static let maxAge: TimeInterval = 24 * 60 * 60

    /// Guarda el borrador, o lo borra si no tiene nada que conservar.
    static func save(_ draft: SavedNewRecordDraft, in defaults: UserDefaults = .standard) {
        guard draft.hasContent else {
            clear(in: defaults)
            return
        }
        do {
            defaults.set(try JSONEncoder().encode(draft), forKey: key)
        } catch {
            #if DEBUG
            print("NewRecordDraftStore: Error: encoding the draft: \(error)")
            #endif
        }
    }

    /// El borrador guardado si sigue vigente a `now`. Uno caducado o ilegible se borra y devuelve `nil`.
    static func load(now: Date = .now, in defaults: UserDefaults = .standard) -> SavedNewRecordDraft? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let draft: SavedNewRecordDraft
        do {
            draft = try JSONDecoder().decode(SavedNewRecordDraft.self, from: data)
        } catch {
            #if DEBUG
            print("NewRecordDraftStore: Error: decoding the draft: \(error)")
            #endif
            clear(in: defaults)
            return nil
        }
        // Un reloj que va hacia atrás (cambio de hora a mano) no hace eterno el borrador: cuenta como caducado.
        let age = now.timeIntervalSince(draft.savedAt)
        guard age >= 0, age <= maxAge, draft.hasContent else {
            clear(in: defaults)
            return nil
        }
        return draft
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
