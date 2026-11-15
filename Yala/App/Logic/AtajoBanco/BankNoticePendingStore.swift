//
//  BankNoticePendingStore.swift
//  Yala
//
//  Cola cross-launch (App Group) de avisos del banco leídos por la acción de Atajos y pendientes de convertirse en
//  borrador. Mismo molde que `ApplePayPendingStore` y `SiriPendingStore`: la acción corre en segundo plano (con el iPhone
//  bloqueado, medido en la prueba B0) y NO toca SwiftData; la app crea el borrador al abrir (`BankNoticeDraftService`).
//
//  Una key por aviso, NO una lista: `UserDefaults` no tiene compare-and-swap entre procesos, y un read-modify-write de una
//  lista compartida perdería o duplicaría avisos cuando la acción y la app escriben a la vez.
//
//  La purgan las fronteras de cuenta (`AppGroupInboundPurge`) y la drena solo `InboundCaptureDrain`, como las otras dos.
//

import Foundation

/// Un aviso pendiente. Lleva el texto tal cual y lo que se leyó en el teléfono al recibirlo.
nonisolated struct BankNoticePendingEntry: Codable, Equatable {
    /// Identidad estable: nombra la key en el App Group.
    var id: UUID = UUID()
    /// El texto que entregó la automatización («título␤cuerpo»). Es el `rawText` del borrador.
    let rawText: String
    /// El banco del atajo instalado o el que nombra el texto; `nil` si ninguno.
    let bank: BankNoticeBank?
    /// Lo que leyeron las reglas o el modelo del iPhone en el proceso de la acción.
    let reading: BankNoticeReading
    /// Momento en que llegó el aviso (segundos desde 1970). Es la fecha del borrador.
    let receivedAt: Double
}

enum BankNoticePendingStore {

    nonisolated static let keyPrefix = "bankNoticePending."

    nonisolated static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)
    }

    nonisolated static func append(
        _ entry: BankNoticePendingEntry,
        defaults: UserDefaults? = BankNoticePendingStore.appGroupDefaults
    ) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(entry)
            defaults.set(data, forKey: keyPrefix + entry.id.uuidString)
        } catch {
            #if DEBUG
            print("BankNoticePendingStore: Error encoding entry: \(error)")
            #endif
        }
    }

    /// Lee la cola SIN borrarla, por orden de llegada. La app borra después de guardar (consume-after-save). Lo que no
    /// decodifica bajo una key nuestra se descarta aquí, para no reintentarlo en bucle.
    nonisolated static func peekAll(
        defaults: UserDefaults? = BankNoticePendingStore.appGroupDefaults
    ) -> [(key: String, entry: BankNoticePendingEntry)] {
        guard let defaults else { return [] }
        var result: [(key: String, entry: BankNoticePendingEntry)] = []
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(keyPrefix) {
            guard let data = value as? Data else {
                defaults.removeObject(forKey: key)
                continue
            }
            do {
                result.append((key, try JSONDecoder().decode(BankNoticePendingEntry.self, from: data)))
            } catch {
                #if DEBUG
                print("BankNoticePendingStore: Error decoding entry at \(key): \(error)")
                #endif
                defaults.removeObject(forKey: key)
            }
        }
        return result.sorted { $0.entry.receivedAt < $1.entry.receivedAt }
    }

    nonisolated static func remove(
        keys: [String],
        defaults: UserDefaults? = BankNoticePendingStore.appGroupDefaults
    ) {
        guard let defaults else { return }
        for key in keys { defaults.removeObject(forKey: key) }
    }
}
