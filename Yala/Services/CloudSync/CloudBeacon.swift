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

extension NSUbiquitousKeyValueStore: BeaconKeyValueStore {
    func setBool(_ value: Bool, forKey key: String) { set(value, forKey: key) }
    func setString(_ value: String, forKey key: String) { set(value, forKey: key) }
    func setDouble(_ value: Double, forKey key: String) { set(value, forKey: key) }
    // `bool(forKey:)`/`string(forKey:)`/`double(forKey:)`/`synchronize()` ya existen en la API nativa.
}

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

    /// Producción: el store iCloud-KV por defecto. Inyectable en tests.
    init(store: BeaconKeyValueStore = NSUbiquitousKeyValueStore.default) {
        self.store = store
    }

    /// Escribe el faro `cloudAccountLinked=true` + proveedor + hash-de-cuenta + timestamp (§g.4-faro v8,
    /// TEMPRANO — en el efecto `.writeBeacon` del claim). `accountSub` nil/vacío → sin hash (el faro sigue
    /// siendo útil: linked + provider). `now` inyectado para determinismo.
    func writeCloudAccountLinked(provider: String, accountSub: String?, now: Date) {
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
        for key in [Keys.linked, Keys.provider, Keys.accountHash, Keys.linkedAt] {
            store.removeObject(forKey: key)
        }
        store.synchronize()
    }

    // Lecturas (para el consumidor de variante-B / panel).
    var isCloudAccountLinked: Bool { store.bool(forKey: Keys.linked) }
    var linkedProvider: String? { store.string(forKey: Keys.provider) }
    var accountHash: String? { store.string(forKey: Keys.accountHash) }

    /// Hash SHA-256 del `sub`, truncado a 16 hex chars (no reversible, sin PII).
    static func hash(_ sub: String) -> String {
        let digest = SHA256.hash(data: Data(sub.utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
    }
}
