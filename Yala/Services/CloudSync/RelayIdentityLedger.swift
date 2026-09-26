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
//  El ADOPT también lo siembra (ticket `adopt-window-late-leader-identity-export-can-duplicate-after-the-remount`): su espejo
//  sigue vivo del reconcile de huérfanas al remonte, y ahí no hay reconcile de `done` que restaure. Deja la marca del adopt
//  (`markAdoptPin`) y el runtime, al arrancar tras el remonte, devuelve las identidades por este registro
//  (`CloudSyncEngine.restoreAdoptedRelayIdentitiesIfPinned`) y lo marca para retirar.
//
//  Y al lado, las identidades que el backend CONOCÍA cuando terminó el reconcile del adopt (ticket
//  `adopt-window-late-imports-overwrite-newer-cloud-edits`): lo que el espejo importe de ellas hasta el remonte no lo traduce
//  el drain, porque subiría con un HLC fresco y pisaría por LWW las ediciones más nuevas de la nube; el pull trae su versión.
//  Vive y muere con el registro: la siembra lo quita, el adopt lo escribe después, y la retirada y la vuelta atrás lo borran.
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
    /// de retirada, la del adopt y lo que el backend conocía en el adopt: sembrar es empezar una migración o un adopt, y el
    /// adopt vuelve a poner lo suyo después.
    /// Sin quitarla, una marca del adopt que sobrevivió a una salida haría que el runtime retirara el registro de una ida.
    /// LANZA si no puede leer el que había o escribir el nuevo.
    static func merge(_ entries: [String: UUID], into url: URL) throws {
        for marker in [retireMarkerURL(for: url), adoptPinURL(for: url), adoptBackendKnownURL(for: url)]
        where FileManager.default.fileExists(atPath: marker.path) {
            try FileManager.default.removeItem(at: marker)
        }
        guard !entries.isEmpty else { return }
        var ledger = try load(from: url)
        let before = ledger
        ledger.merge(entries) { _, new in new }
        guard ledger != before else { return }
        let data = try JSONEncoder().encode(ledger)
        try data.write(to: url, options: .atomic)
    }

    /// Borra el registro, sus dos marcas y lo que el backend conocía en el adopt, si existen.
    static func remove(at url: URL) throws {
        for file in [url, retireMarkerURL(for: url), adoptPinURL(for: url), adoptBackendKnownURL(for: url)]
        where FileManager.default.fileExists(atPath: file.path) {
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

    /// La marca «lo sembró un adopt y el runtime tiene que restaurar con él al arrancar tras el remonte»: un fichero vacío
    /// al lado. La pone `runAdoptOrphanReconcile` después de sembrar; la quita el runtime cuando la restauración termina.
    static func markAdoptPin(_ url: URL) throws {
        try Data().write(to: adoptPinURL(for: url), options: .atomic)
    }

    static func isAdoptPinned(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: adoptPinURL(for: url).path)
    }

    static func clearAdoptPin(_ url: URL) throws {
        let marker = adoptPinURL(for: url)
        guard FileManager.default.fileExists(atPath: marker.path) else { return }
        try FileManager.default.removeItem(at: marker)
    }

    private static func adoptPinURL(for url: URL) -> URL {
        url.appendingPathExtension("adopt")
    }

    // MARK: - Lo que el backend conocía al terminar el adopt (ticket `adopt-window-late-imports-overwrite-newer-cloud-edits`)

    /// Guarda las identidades que el backend conocía, vivas o borradas, según la enumeración del reconcile del adopt. Reemplaza
    /// lo que hubiera: cada pasada del reconcile enumera otra vez. LANZA si no puede escribir.
    static func writeAdoptBackendKnown(_ ids: Set<UUID>, for url: URL) throws {
        let data = try JSONEncoder().encode(ids.map(\.uuidString).sorted())
        try data.write(to: adoptBackendKnownURL(for: url), options: .atomic)
    }

    /// Lo que el backend conocía en el adopt. Sin fichero es vacío; un fichero que no se deja leer o decodificar LANZA.
    static func loadAdoptBackendKnown(for url: URL) throws -> Set<UUID> {
        let file = adoptBackendKnownURL(for: url)
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let raw = try JSONDecoder().decode([String].self, from: Data(contentsOf: file))
        var ids = Set<UUID>()
        for string in raw {
            guard let id = UUID(uuidString: string) else { throw CocoaError(.coderReadCorrupt) }
            ids.insert(id)
        }
        return ids
    }

    /// Quita lo que el backend conocía, si existe. LANZA si no puede borrarlo.
    static func clearAdoptBackendKnown(for url: URL) throws {
        let file = adoptBackendKnownURL(for: url)
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        try FileManager.default.removeItem(at: file)
    }

    static func hasAdoptBackendKnown(for url: URL) -> Bool {
        FileManager.default.fileExists(atPath: adoptBackendKnownURL(for: url).path)
    }

    private static func adoptBackendKnownURL(for url: URL) -> URL {
        url.appendingPathExtension("backend-known")
    }
}
