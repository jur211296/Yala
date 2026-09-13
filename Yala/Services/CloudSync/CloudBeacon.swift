//
//  CloudBeacon.swift
//  Yala
//
//  Faro iCloud-KV del Modo Nube (§g.4-faro v8): escribe TEMPRANO — al reclamar la cuenta, NO al marcador
//  CloudKit — que ESTE Apple ID ya activó el modo nube y con qué proveedor. Cierra el hueco de
//  "provider-mismatch" durante toda la ventana del cutover: un 2º device que firme con OTRO proveedor lo
//  detecta ANTES de sembrar una 2ª cuenta divergente (variante B de `AccountClaimDecision`).
//
//  `NSUbiquitousKeyValueStore` (iCloud key-value, sincroniza cross-device del MISMO Apple ID). El store se
//  INYECTA (`BeaconKeyValueStore`) para tests sin iCloud. SIN PII: el `sub` de la cuenta viaja como un hash
//  SHA-256 truncado NO reversible (no el `sub` en claro, no email, no token).
//

import CryptoKit
import Foundation

// MARK: - Store inyectable

/// Superficie mínima del KV store que usa el faro (inyectable para tests). `NSUbiquitousKeyValueStore` la
/// implementa vía la extensión de abajo.
protocol BeaconKeyValueStore: AnyObject {
    func setBool(_ value: Bool, forKey key: String)
    func setString(_ value: String, forKey key: String)
    func setDouble(_ value: Double, forKey key: String)
    func bool(forKey key: String) -> Bool
    func string(forKey key: String) -> String?
    func double(forKey key: String) -> Double
    func removeObject(forKey key: String)
    @discardableResult func synchronize() -> Bool
}

// La conformance del store CRUDO vive en `OwnerKeyValueStore.swift`, que es el único fichero del árbol
// autorizado a nombrarlo (frontera M1, 2026-08-12). Aquí solo se consume el protocolo.

// MARK: - CloudBeacon

@MainActor
final class CloudBeacon {

    /// Claves del faro (namespaced). WIRE-STABLE (un rename rompería la lectura cross-device).
    enum Keys {
        static let linked = "yala.cloud.accountLinked"
        static let provider = "yala.cloud.accountProvider"
        /// Hash SHA-256 truncado del `sub` (no reversible, sin PII).
        static let accountHash = "yala.cloud.accountHash"
        static let linkedAt = "yala.cloud.accountLinkedAt"
    }

    private let store: BeaconKeyValueStore

    /// Producción: la fachada del iCloud-KV, no el store crudo — un solo sitio nombra
    /// `NSUbiquitousKeyValueStore` en todo el árbol. Inyectable en tests.
    init(store: BeaconKeyValueStore = OwnerKeyValueStore.shared) {
        self.store = store
    }

    /// Escribe el faro `cloudAccountLinked=true` + proveedor + hash-de-cuenta + timestamp (§g.4-faro v8,
    /// TEMPRANO — en el efecto `.writeBeacon` del claim). `accountSub` nil/vacío → sin hash (el faro sigue
    /// siendo útil: linked + provider). `now` inyectado para determinismo.
    func writeCloudAccountLinked(provider: String, accountSub: String?, now: Date) {
        #if DEBUG
        // Seam `-uitest-fake-beacon`: con el faro fingido, la corrida no escribe en el iCloud-KV real.
        if UITestHooks.fakeBeaconProvider != nil { return }
        #endif
        store.setBool(true, forKey: Keys.linked)
        store.setString(provider, forKey: Keys.provider)
        if let sub = accountSub, !sub.isEmpty {
            store.setString(Self.hash(sub), forKey: Keys.accountHash)
        }
        store.setDouble(now.timeIntervalSince1970, forKey: Keys.linkedAt)
        store.synchronize()
    }

    /// Limpia el faro `cloudAccountLinked` (§g.4-faro, efecto `.clearCloudBeacon` de la reversa I11). Remueve
    /// las 4 keys + `synchronize()` — simétrico a `writeCloudAccountLinked`. Tras revertir a iCloud el device
    /// ya NO tiene una cuenta nube vinculada: dejar el faro puesto haría que un 2º device firmara "cuenta nube
    /// activa" para un Apple ID que ya volvió a CloudKit.
    func clearCloudAccountLinked() {
        #if DEBUG
        // Seam `-uitest-fake-beacon`: con el faro fingido, la corrida tampoco borra el iCloud-KV real.
        if UITestHooks.fakeBeaconProvider != nil { return }
        #endif
        for key in [Keys.linked, Keys.provider, Keys.accountHash, Keys.linkedAt] {
            store.removeObject(forKey: key)
        }
        store.synchronize()
    }

    // Lecturas (para el consumidor de variante-B / panel).
    //
    // Seam DEBUG-only `-uitest-fake-beacon <método>` (paso 6): finge un faro LEÍDO —linked, con ese método y
    // sin hash— para el XCUITest de «Crear otra cuenta». Molde de `CloudAuthService.hasSession`: en release
    // el `#if` no existe y el cuerpo es byte-idéntico. **No persiste nada, a propósito**: con el seam activo
    // la escritura y el borrado de arriba son no-op, así que la corrida ni deja un faro en el iCloud-KV del
    // simulador ni le borra el que tuviera (la regla del seam que persiste, `.claude/rules/testing.md`). Alcanza
    // a TODOS los lectores del faro, no solo al Welcome: por eso vive detrás de un arg que solo pasa su test.
    // Ver `UITestHooks.fakeBeaconProvider`.
    var isCloudAccountLinked: Bool {
        #if DEBUG
        if UITestHooks.fakeBeaconProvider != nil { return true }
        #endif
        return store.bool(forKey: Keys.linked)
    }
    var linkedProvider: String? {
        #if DEBUG
        if let fingido = UITestHooks.fakeBeaconProvider { return fingido }
        #endif
        return store.string(forKey: Keys.provider)
    }
    var accountHash: String? {
        #if DEBUG
        if UITestHooks.fakeBeaconProvider != nil { return nil }
        #endif
        return store.string(forKey: Keys.accountHash)
    }

    /// Hash SHA-256 del `sub`, truncado a 16 hex chars (no reversible, sin PII).
    static func hash(_ sub: String) -> String {
        let digest = SHA256.hash(data: Data(sub.utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
    }
}
