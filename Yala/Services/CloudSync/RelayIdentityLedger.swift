//
//  RelayIdentityLedger.swift
//  Yala
//
//  Qué identidad de sync le dio ESTE teléfono a cada fila de identidad acuñada, por su `Z_PK` (ticket
//  `relay-row-rekeyed-then-deleted-tombstones-the-leader-identity`).
//
//  El problema: el espejo de iCloud del relevo puede cambiarle el `syncID` a una fila por debajo (la exportación tardía
//  del líder desplazado, #243). `MigrationWorkExecutor.restoreRelayIdentities` se la devuelve a las filas VIVAS, pero una
//  fila borrada antes de la restauración siguiente sale del drain con la identidad del líder (`tombstone[\.syncID]`, lo
//  que la fila llevaba al borrarse), que el backend no conoce. El borrado no llega y el movimiento reaparece.
//
//  Por qué por `Z_PK` y no por el record de CloudKit: el cambio de identidad es un update del MISMO objeto, así que su
//  `Z_PK` no cambia, y Core Data no reutiliza `Z_PK`. El record del objeto borrado solo se puede leer mientras el espejo no
//  haya exportado el borrado —segundos con red—, y del cutover al relanzamiento pueden pasar horas.
//
//  Es un fichero y no un modelo: lo leen DOS motores (el de la migración y el del runtime, instancias distintas) y tiene
//  que sobrevivir al relanzamiento del cutover. Nunca se recorta durante la migración —la entrada de una fila borrada es
//  justo la que hace falta—. Lo retira el primer drain completo DESPUÉS de que el reconcile de `done` lo marque como
//  terminado (`markRetirable`), y lo borra entero la vuelta atrás antes del cutover. Solo guarda `Z_PK` y UUIDs.
//

import Foundation
import SwiftData

@MainActor
enum RelayIdentityLedger {

    /// Dónde vive el registro en producción. Lo comparten el executor de la migración y el motor del runtime.
    static var defaultURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("relay-identity-ledger.json")
    }

    /// La clave de una fila: `Store/Entidad/Z_PK`, con el identificador del store (el host del URI `x-coredata://`). Core
    /// Data no reutiliza `Z_PK` dentro de un store, pero un wipe borra los ficheros y el store nuevo vuelve a empezar desde
    /// 1: sin el store en la clave, una entrada vieja apuntaría a una fila nueva sin relación. `nil` si no se resuelve.
    static func key(for id: PersistentIdentifier) -> String? {
        guard let uri = CKIdentityCapture.objectURI(for: id), let store = uri.host,
              let resolved = CKIdentityCapture.parseCoreDataURI(uri) else { return nil }
        return "\(store)/\(resolved.entityName)/\(resolved.zpk)"
    }

    /// Lee el registro. Sin fichero es un registro vacío; un fichero que no se deja leer o decodificar LANZA.
    static func load(from url: URL) throws -> [String: UUID] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: UUID].self, from: data)
    }

    /// Añade `entries` al registro (una clave repetida toma el valor nuevo) y solo escribe si algo cambió. Quita la marca
    /// de retirada: sembrar es empezar una migración. LANZA si no puede leer el que había o escribir el nuevo.
    static func merge(_ entries: [String: UUID], into url: URL) throws {
        if FileManager.default.fileExists(atPath: retireMarkerURL(for: url).path) {
            try FileManager.default.removeItem(at: retireMarkerURL(for: url))
        }
        guard !entries.isEmpty else { return }
        var ledger = try load(from: url)
        let before = ledger
        ledger.merge(entries) { _, new in new }
        guard ledger != before else { return }
        let data = try JSONEncoder().encode(ledger)
        try data.write(to: url, options: .atomic)
    }

    /// Borra el registro y su marca de retirada, si existen.
    static func remove(at url: URL) throws {
        for file in [url, retireMarkerURL(for: url)] where FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }

    /// La marca «la migración ya no necesita el registro»: un fichero vacío al lado. La pone el executor al cerrar el
    /// reconcile de `done`; el motor, con ella, borra el registro tras su siguiente drain completo.
    static func markRetirable(_ url: URL) throws {
        try Data().write(to: retireMarkerURL(for: url), options: .atomic)
    }

    static func isRetirable(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: retireMarkerURL(for: url).path)
    }

    private static func retireMarkerURL(for url: URL) -> URL {
        url.appendingPathExtension("retire")
    }
}
